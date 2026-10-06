import { ok, forbidden, unauthorized, serverError } from '../../../lib/http';
import { requireBearerToken } from '../../../lib/http/request';
import { verifyJwt } from '../../../lib/auth';
import { verifyApiKey, parseApiKey } from '../../../lib/api-keys';
import { createSupabaseClient, type SupabaseClient } from '../../../lib/supabase';
import type { OrgMembership, Entitlement, UsageBucket as UsageBucketBase } from '../../../lib/types';
import type { EntitlementMap } from '../../../lib/entitlements';
import { buildEntitlementMap, loadOrgPlan, auth0VerifyParams, resolveUserId, requireHmacSecret, type UserTokenOptions, type LoadResult } from '../lib/helpers';
import { getQuotaStatus, type QuotaStatusResponse } from '../lib/quota';
import type { AuthResult } from '../../../lib/types/handler-options';

// SupabaseRow requires an index signature; UsageBucketBase does not include one.
type UsageBucket = UsageBucketBase & Record<string, unknown>;

interface UsageHandlerOptions extends UserTokenOptions {
  hmacSecret?: string;
  supabaseUrl: string;
  serviceRoleKey: string;
}

interface QuotaStatusHandlerOptions extends UsageHandlerOptions {
  doNamespace: DurableObjectNamespace;
}

export interface UsageSummaryPayload {
  org_id: string;
  period_start: string;
  buckets: UsageBucket[];
}

export interface EntitlementsPayload {
  org_id: string;
  entitlements: EntitlementMap;
}

/** `getQuotaStatus`'s answer, or the fail-open marker when the Durable Object is unavailable. */
export type QuotaStatusPayload =
  | ({ org_id: string } & QuotaStatusResponse)
  | { org_id: string; status: 'uninitialized' };

const USAGE_BUCKET_SELECT = 'organization_id, bucket_date, metric_key, total_quantity, request_count, avg_latency_ms';

async function resolveAuth(
  request: Request,
  opts: UsageHandlerOptions,
  sb: SupabaseClient,
): Promise<AuthResult> {
  const tokenResult = requireBearerToken(request);
  if (!tokenResult.ok) return tokenResult;

  const { token } = tokenResult;

  // If the token looks like an API key, try that path first
  const parsedKey = parseApiKey(token);
  if (parsedKey.ok) {
    const secret = requireHmacSecret(opts.hmacSecret);
    if (!secret.ok) return secret;
    const keyResult = await verifyApiKey(token, secret.hmacSecret, sb);
    if (!keyResult.ok) return keyResult;
    return { ok: true, type: 'api_key', userId: keyResult.userId, organizationId: keyResult.organizationId };
  }

  // Otherwise treat as JWT
  const { key, issuerUrl, audience } = auth0VerifyParams(opts);
  const jwtResult = await verifyJwt(token, key, { issuerUrl, audience });
  if (!jwtResult.ok) return jwtResult;
  if (!jwtResult.payload.sub) return { ok: false, error: unauthorized('JWT missing sub claim') };
  // Resolve to the internal users.id here so both auth branches expose a UUID and the
  // membership filters below cannot be handed an Auth0 sub by mistake.
  const user = await resolveUserId(jwtResult.payload.sub, sb);
  if (!user.ok) return user;
  return { ok: true, type: 'jwt', sub: jwtResult.payload.sub, userId: user.userId };
}

async function assertOrgAccess(
  auth: AuthResult & { ok: true },
  orgId: string,
  sb: SupabaseClient,
): Promise<{ ok: true } | { ok: false; error: Response }> {
  if (!auth.ok) return { ok: false, error: unauthorized() };

  if (auth.type === 'api_key') {
    if (auth.organizationId !== orgId) return { ok: false, error: forbidden('API key does not belong to this organization') };
    return { ok: true };
  }

  // JWT path: check membership
  const result = await sb.query<OrgMembership>('organization_memberships', {
    select: 'organization_id, user_id, role, status',
    filters: [
      { column: 'user_id', operator: 'eq', value: auth.userId },
      { column: 'organization_id', operator: 'eq', value: orgId },
      { column: 'status', operator: 'eq', value: 'active' },
    ],
    limit: 1,
  });

  if (!result.ok || result.data.length === 0) {
    return { ok: false, error: forbidden('Not a member of this organization') };
  }

  return { ok: true };
}

/** The first day of the current UTC month, `YYYY-MM-01` — the window every usage read covers. */
function usageMonthStart(now: Date): string {
  // TS06: use UTC methods so the boundary is the same regardless of the server's local offset.
  return `${now.getUTCFullYear()}-${String(now.getUTCMonth() + 1).padStart(2, '0')}-01`;
}

/**
 * The month-to-date usage buckets for an org. Shared by `GET /v1/orgs/:id/usage/summary`
 * and its staff twin; authorisation is the caller's.
 */
export async function loadUsageSummary(sb: SupabaseClient, orgId: string): Promise<LoadResult<UsageSummaryPayload>> {
  const monthStart = usageMonthStart(new Date());

  const result = await sb.query<UsageBucket>('usage_buckets_daily', {
    select: USAGE_BUCKET_SELECT,
    filters: [
      { column: 'organization_id', operator: 'eq', value: orgId },
      { column: 'bucket_date', operator: 'gte', value: monthStart },
    ],
    order: { column: 'bucket_date', ascending: false },
  });

  if (!result.ok) {
    return { ok: false, error: serverError('Failed to load usage data') };
  }

  return { ok: true, data: { org_id: orgId, period_start: monthStart, buckets: result.data } };
}

/** An org's plan projection overlaid with its explicit `entitlements` rows (UA01). */
export async function loadEntitlements(sb: SupabaseClient, orgId: string): Promise<LoadResult<EntitlementsPayload>> {
  const [result, plan] = await Promise.all([
    sb.query<Entitlement>('entitlements', {
      filters: [{ column: 'organization_id', operator: 'eq', value: orgId }],
    }),
    loadOrgPlan(sb, orgId),
  ]);

  if (!result.ok) {
    return { ok: false, error: serverError('Failed to load entitlements') };
  }

  return { ok: true, data: { org_id: orgId, entitlements: buildEntitlementMap(result.data, plan) } };
}

/**
 * The quota Durable Object's `/status` for an org. A read, never a reservation: the
 * reservation happens in `enforceOrgQuota`, which the router runs for the customer
 * route and skips for the staff twin.
 */
export async function loadQuotaStatus(doNamespace: DurableObjectNamespace, orgId: string): Promise<QuotaStatusPayload> {
  try {
    const status = await getQuotaStatus(doNamespace, orgId);
    return { org_id: orgId, ...status };
  } catch {
    // Fail-open: if DO is unavailable, return uninitialized status
    return { org_id: orgId, status: 'uninitialized' };
  }
}

export async function handleUsageSummary(
  request: Request,
  orgId: string,
  opts: UsageHandlerOptions,
): Promise<Response> {
  const sb = createSupabaseClient(opts.supabaseUrl, opts.serviceRoleKey);

  const auth = await resolveAuth(request, opts, sb);
  if (!auth.ok) return auth.error;

  const access = await assertOrgAccess(auth, orgId, sb);
  if (!access.ok) return access.error;

  const summary = await loadUsageSummary(sb, orgId);
  return summary.ok ? ok(summary.data) : summary.error;
}

export async function handleOrgEntitlements(
  request: Request,
  orgId: string,
  opts: UsageHandlerOptions,
): Promise<Response> {
  const sb = createSupabaseClient(opts.supabaseUrl, opts.serviceRoleKey);

  const auth = await resolveAuth(request, opts, sb);
  if (!auth.ok) return auth.error;

  const access = await assertOrgAccess(auth, orgId, sb);
  if (!access.ok) return access.error;

  const entitlements = await loadEntitlements(sb, orgId);
  return entitlements.ok ? ok(entitlements.data) : entitlements.error;
}

export async function handleQuotaStatus(
  request: Request,
  orgId: string,
  opts: QuotaStatusHandlerOptions,
): Promise<Response> {
  const sb = createSupabaseClient(opts.supabaseUrl, opts.serviceRoleKey);

  const auth = await resolveAuth(request, opts, sb);
  if (!auth.ok) return auth.error;

  const access = await assertOrgAccess(auth, orgId, sb);
  if (!access.ok) return access.error;

  return ok(await loadQuotaStatus(opts.doNamespace, orgId));
}
