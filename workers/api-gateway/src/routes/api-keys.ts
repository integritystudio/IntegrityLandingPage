import { ok, created, forbidden, notFound, serverError, badRequest } from '../../../lib/http';
import { generateApiKey, hashApiKeySecret } from '../../../lib/api-keys';
import { safeParseJson, isJsonRequest } from '../../../lib/http/request';
import { zodValidationError } from '../../../lib/validation';
import { CreateApiKeyBodySchema, type CreateApiKeyBody } from '../../../lib/types/request-bodies';
import { createSupabaseClient, type SupabaseClient } from '../../../lib/supabase';
import type { OrgMembership, ApiKey, OrgRole } from '../../../lib/types';
import { resolveJwt, writeAuditLog, auth0VerifyParams, requireHmacSecret, type UserTokenOptions } from '../lib/helpers';

interface ApiKeysHandlerOptions extends UserTokenOptions {
  hmacSecret?: string;
  supabaseUrl: string;
  serviceRoleKey: string;
}

/** Roles that may create or revoke org API keys (viewers and billing-only roles excluded). */
const API_KEY_ROLES: OrgRole[] = ['owner', 'admin', 'member'];

async function assertOrgMembership(
  userId: string,
  orgId: string,
  sb: SupabaseClient,
): Promise<{ ok: true; membership: OrgMembership } | { ok: false; error: Response }> {
  const result = await sb.query<OrgMembership>('organization_memberships', {
    select: 'organization_id, user_id, role, status',
    filters: [
      { column: 'user_id', operator: 'eq', value: userId },
      { column: 'organization_id', operator: 'eq', value: orgId },
      { column: 'status', operator: 'eq', value: 'active' },
    ],
    limit: 1,
  });

  if (!result.ok || result.data.length === 0) {
    return { ok: false, error: forbidden('Not a member of this organization') };
  }

  return { ok: true, membership: result.data[0] };
}

async function lookupUserByAuth0Id(
  auth0Id: string,
  sb: SupabaseClient,
): Promise<{ id: string } | null> {
  const result = await sb.query<{ id: string; auth0_id: string }>('users', {
    select: 'id, auth0_id',
    filters: [{ column: 'auth0_id', operator: 'eq', value: auth0Id }],
    limit: 1,
  });

  if (!result.ok || result.data.length === 0) return null;
  return result.data[0];
}

export async function handleCreateApiKey(
  request: Request,
  orgId: string,
  opts: ApiKeysHandlerOptions,
): Promise<Response> {
  const auth = await resolveJwt(request, auth0VerifyParams(opts));
  if (!auth.ok) return auth.error;

  const sb = createSupabaseClient(opts.supabaseUrl, opts.serviceRoleKey);

  // organization_memberships.user_id is the internal uuid, not the Auth0 sub, so the
  // user row has to be resolved before membership can be checked.
  const user = await lookupUserByAuth0Id(auth.sub, sb);
  if (!user) return notFound('User not found');

  const membershipResult = await assertOrgMembership(user.id, orgId, sb);
  if (!membershipResult.ok) return membershipResult.error;

  if (!API_KEY_ROLES.includes(membershipResult.membership.role)) {
    return forbidden('Insufficient role to manage API keys');
  }

  // The body is optional: a bodiless request mints a key named 'Default' with no expiry.
  let body: CreateApiKeyBody = {};
  if (isJsonRequest(request)) {
    const raw = await safeParseJson(request);
    if (!raw.ok) return badRequest('Invalid JSON body');
    const parsed = CreateApiKeyBodySchema.safeParse(raw.data);
    if (!parsed.success) return zodValidationError(parsed.error);
    body = parsed.data;
  }

  // Minting a key whose hash cannot be reproduced would create an unusable credential,
  // so refuse before generating rather than storing a hash keyed on nothing.
  const hmac = requireHmacSecret(opts.hmacSecret);
  if (!hmac.ok) return hmac.error;

  const { token, prefix, secret } = generateApiKey();
  const hash = await hashApiKeySecret(secret, hmac.hmacSecret);

  const keyName = body.name ?? 'Default';

  const insertResult = await sb.insert(
    'api_keys',
    {
      user_id: user.id,
      organization_id: orgId,
      prefix,
      hash,
      name: keyName,
      tier: 'starter',
      status: 'active',
      expires_at: body.expires_at ?? null,
    },
    { returning: 'representation' },
  );

  if (!insertResult.ok || !Array.isArray(insertResult.data) || insertResult.data.length === 0) {
    console.error('Failed to insert api key:', insertResult);
    return serverError('Failed to create API key');
  }

  const inserted = insertResult.data[0] as ApiKey;

  await writeAuditLog(sb, {
    organization_id: orgId,
    actor_user_id: user.id,
    action: 'api_key.created',
    target_type: 'api_key',
    target_id: String(inserted.id),
    new_values: { name: keyName, tier: 'starter', prefix },
  });

  return created({
    id: inserted.id,
    name: keyName,
    prefix,
    tier: 'starter',
    status: 'active',
    expires_at: body.expires_at ?? null,
    created_at: inserted.created_at,
    // Token shown ONCE — never stored, must be saved by caller
    token,
  });
}

export async function handleRevokeApiKey(
  request: Request,
  orgId: string,
  keyId: string,
  opts: ApiKeysHandlerOptions,
): Promise<Response> {
  const auth = await resolveJwt(request, auth0VerifyParams(opts));
  if (!auth.ok) return auth.error;

  const sb = createSupabaseClient(opts.supabaseUrl, opts.serviceRoleKey);

  const user = await lookupUserByAuth0Id(auth.sub, sb);
  if (!user) return notFound('User not found');

  const membershipResult = await assertOrgMembership(user.id, orgId, sb);
  if (!membershipResult.ok) return membershipResult.error;

  if (!API_KEY_ROLES.includes(membershipResult.membership.role)) {
    return forbidden('Insufficient role to manage API keys');
  }

  const keyResult = await sb.query<ApiKey>('api_keys', {
    filters: [
      { column: 'id', operator: 'eq', value: keyId },
      { column: 'organization_id', operator: 'eq', value: orgId },
    ],
    limit: 1,
  });

  if (!keyResult.ok || keyResult.data.length === 0) {
    return notFound('API key not found');
  }

  // Delegate to the api-keys-revoke edge function, which atomically revokes in
  // the DB and deletes the AUTH KV record. The gateway cannot write that KV
  // namespace directly, so without this call a "revoked" key keeps authenticating
  // to obtool-ingest and obtool-api until the KV record expires (CR64).
  const fnRes = await fetch(
    `${opts.supabaseUrl}/functions/v1/api-keys-revoke`,
    {
      method: 'POST',
      headers: {
        apikey: opts.serviceRoleKey,
        Authorization: `Bearer ${opts.serviceRoleKey}`,
        'Content-Type': 'application/json',
      },
      body: JSON.stringify({ keyId }),
    },
  ).catch(() => null);

  if (!fnRes?.ok) {
    const errText = fnRes ? await fnRes.text().catch(() => '') : '';
    console.error(`[api-keys/revoke] edge function returned ${fnRes?.status ?? 'network error'}: ${errText}`);
    return serverError('Failed to revoke API key');
  }

  const fnBody = await fnRes.json().catch(() => ({})) as { revoked?: boolean; warning?: string };

  await writeAuditLog(sb, {
    organization_id: orgId,
    action: 'api_key.revoked',
    target_type: 'api_key',
    target_id: keyId,
    new_values: { status: 'revoked' },
    metadata: { actor_auth0_id: auth.sub, kv_warning: fnBody.warning ?? null },
  });

  const revokedAt = new Date().toISOString();
  return ok({ id: keyId, status: 'revoked', revoked_at: revokedAt });
}
