import { ok, forbidden, unauthorized, serverError } from '../../../lib/http';
import { requireBearerToken } from '../../../lib/http/request';
import { verifyJwt, supabaseJwtKey } from '../../../lib/auth';
import { verifyApiKey, parseApiKey } from '../../../lib/api-keys';
import { createSupabaseClient, type SupabaseClient } from '../../../lib/supabase';
import type { OrgMembership, Entitlement, UsageBucket as UsageBucketBase } from '../../../lib/types';
import { buildEntitlementMap } from '../lib/helpers';
import { getQuotaStatus } from '../lib/quota';
import type { AuthResult } from '../../../lib/types/handler-options';

// SupabaseRow requires an index signature; UsageBucketBase does not include one.
type UsageBucket = UsageBucketBase & Record<string, unknown>;

interface UsageHandlerOptions {
  jwtSecret?: string;
  hmacSecret: string;
  supabaseUrl: string;
  serviceRoleKey: string;
  jwtIssuerUrl?: string;
}

interface QuotaStatusHandlerOptions extends UsageHandlerOptions {
  doNamespace: DurableObjectNamespace;
}


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
    const keyResult = await verifyApiKey(token, opts.hmacSecret, sb);
    if (!keyResult.ok) return keyResult;
    return { ok: true, type: 'api_key', userId: keyResult.userId, organizationId: keyResult.organizationId };
  }

  // Otherwise treat as JWT
  const jwtResult = await verifyJwt(token, supabaseJwtKey(opts), { issuerUrl: opts.jwtIssuerUrl });
  if (!jwtResult.ok) return jwtResult;
  if (!jwtResult.payload.sub) return { ok: false, error: unauthorized('JWT missing sub claim') };
  return { ok: true, type: 'jwt', sub: jwtResult.payload.sub };
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
      { column: 'user_id', operator: 'eq', value: auth.sub },
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

  const now = new Date();
  const monthStart = new Date(now.getFullYear(), now.getMonth(), 1).toISOString().split('T')[0];

  const result = await sb.query<UsageBucket>('usage_buckets_daily', {
    select: 'organization_id, bucket_date, metric_key, total_quantity, request_count, avg_latency_ms',
    filters: [
      { column: 'organization_id', operator: 'eq', value: orgId },
      { column: 'bucket_date', operator: 'gte', value: monthStart },
    ],
    order: { column: 'bucket_date', ascending: false },
  });

  if (!result.ok) {
    return serverError('Failed to load usage data');
  }

  return ok({ org_id: orgId, period_start: monthStart, buckets: result.data });
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

  const result = await sb.query<Entitlement>('entitlements', {
    filters: [{ column: 'organization_id', operator: 'eq', value: orgId }],
  });

  if (!result.ok) {
    return serverError('Failed to load entitlements');
  }

  const entitlements = buildEntitlementMap(result.data);

  return ok({ org_id: orgId, entitlements });
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

  try {
    const status = await getQuotaStatus(opts.doNamespace, orgId);
    return ok({ org_id: orgId, ...status });
  } catch {
    // Fail-open: if DO is unavailable, return uninitialized status
    return ok({ org_id: orgId, status: 'uninitialized' });
  }
}
