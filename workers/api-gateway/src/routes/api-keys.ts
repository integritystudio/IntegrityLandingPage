import { ok, created, forbidden, notFound, serverError, badRequest } from '../../../lib/http';
import { generateApiKey, hashApiKeySecret } from '../../../lib/api-keys';
import { createSupabaseClient, type SupabaseClient } from '../../../lib/supabase';
import type { OrgMembership, ApiKey, OrgRole } from '../../../lib/types';
import { supabaseJwtKey } from '../../../lib/auth';
import { resolveJwt, writeAuditLog } from '../lib/helpers';

interface ApiKeysHandlerOptions {
  jwtSecret?: string;
  hmacSecret: string;
  supabaseUrl: string;
  serviceRoleKey: string;
  jwtIssuerUrl?: string;
}

/** Roles that may create or revoke org API keys (viewers and billing-only roles excluded). */
const API_KEY_ROLES: OrgRole[] = ['owner', 'admin', 'member'];

interface CreateApiKeyBody {
  name?: string;
  expires_at?: string;
}

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
  const auth = await resolveJwt(request, supabaseJwtKey(opts), opts.jwtIssuerUrl);
  if (!auth.ok) return auth.error;

  const sb = createSupabaseClient(opts.supabaseUrl, opts.serviceRoleKey);

  const membershipResult = await assertOrgMembership(auth.sub, orgId, sb);
  if (!membershipResult.ok) return membershipResult.error;

  if (!API_KEY_ROLES.includes(membershipResult.membership.role)) {
    return forbidden('Insufficient role to manage API keys');
  }

  const user = await lookupUserByAuth0Id(auth.sub, sb);
  if (!user) return notFound('User not found');

  let body: CreateApiKeyBody = {};
  if (request.headers.get('content-type')?.includes('application/json')) {
    try {
      body = await request.json() as CreateApiKeyBody;
    } catch {
      return badRequest('Invalid JSON body');
    }
  }

  const { token, prefix, secret } = generateApiKey();
  const hash = await hashApiKeySecret(secret, opts.hmacSecret);

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
  const auth = await resolveJwt(request, supabaseJwtKey(opts), opts.jwtIssuerUrl);
  if (!auth.ok) return auth.error;

  const sb = createSupabaseClient(opts.supabaseUrl, opts.serviceRoleKey);

  const membershipResult = await assertOrgMembership(auth.sub, orgId, sb);
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

  const revokedAt = new Date().toISOString();

  const updateResult = await sb.update(
    'api_keys',
    { status: 'revoked', revoked_at: revokedAt },
    [{ column: 'id', operator: 'eq', value: keyId }],
    { returning: 'representation' },
  );

  if (!updateResult.ok) {
    return serverError('Failed to revoke API key');
  }

  await writeAuditLog(sb, {
    organization_id: orgId,
    action: 'api_key.revoked',
    target_type: 'api_key',
    target_id: keyId,
    new_values: { status: 'revoked', revoked_at: revokedAt },
    metadata: { actor_auth0_id: auth.sub },
  });

  return ok({ id: keyId, status: 'revoked', revoked_at: revokedAt });
}
