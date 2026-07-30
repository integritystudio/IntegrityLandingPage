import { ok, unauthorized, notFound, serverError } from '../../../lib/http';
import { requireBearerToken } from '../../../lib/http/request';
import { verifyJwt } from '../../../lib/auth';
import { createSupabaseClient, type SupabaseClient } from '../../../lib/supabase';
import type { Organization, OrgRole, OrgMembership, Entitlement, UsageBucket, BootstrapResponse } from '../../../lib/types';
import { auth0VerifyParams, resolveUserId, buildEntitlementMap, type UserTokenOptions } from '../lib/helpers';

export interface BootstrapHandlerOptions extends UserTokenOptions {
  supabaseUrl: string;
  serviceRoleKey: string;
}

type UsageBucketRow = UsageBucket & Record<string, unknown>;

const EMPTY_USAGE: { month_to_date_units: number; current_minute_remaining: number | null } = {
  month_to_date_units: 0,
  current_minute_remaining: null,
};

async function loadOrgContext(
  userId: string,
  orgIdHeader: string | null,
  sb: SupabaseClient,
): Promise<
  | { ok: true; orgs: (Organization & { role: OrgRole })[]; activeOrgId: string }
  | { ok: false; error: Response }
> {
  const membershipResult = await sb.query<OrgMembership>('organization_memberships', {
    select: 'organization_id, role',
    filters: [
      { column: 'user_id', operator: 'eq', value: userId },
      { column: 'status', operator: 'eq', value: 'active' },
    ],
  });

  if (!membershipResult.ok) {
    console.error('[bootstrap] Failed to fetch memberships:', membershipResult.error);
    return { ok: false, error: serverError('Failed to load organizations') };
  }

  if (membershipResult.data.length === 0) {
    return { ok: false, error: notFound('No active organization memberships found') };
  }

  const memberships = membershipResult.data;
  const orgIds = new Set(memberships.map((m) => m.organization_id));
  const roleByOrgId = new Map(memberships.map((m) => [m.organization_id, m.role]));

  const orgsResult = await sb.query<Organization>('organizations', {
    select: 'id, slug, name, billing_status, current_plan, quota_version',
    filters: [{ column: 'id', operator: 'in', value: [...orgIds] }],
  });

  if (!orgsResult.ok) {
    console.error('[bootstrap] Failed to fetch organizations:', orgsResult.error);
    return { ok: false, error: serverError('Failed to load organization details') };
  }

  if (orgsResult.data.length === 0) {
    console.error(
      `[bootstrap] user ${userId} has ${memberships.length} membership(s) but no matching org rows`,
    );
    return { ok: false, error: notFound('No organization data found') };
  }

  const orgs: (Organization & { role: OrgRole })[] = orgsResult.data.map((org) => ({
    ...org,
    role: roleByOrgId.get(org.id) as OrgRole,
  }));

  const requested = orgIdHeader ? orgs.find((o) => o.id === orgIdHeader) : undefined;
  const activeOrgId = requested?.id ?? orgs[0].id;

  return { ok: true, orgs, activeOrgId };
}

async function loadUsageSnapshot(
  orgId: string,
  sb: SupabaseClient,
): Promise<{ month_to_date_units: number; current_minute_remaining: number | null }> {
  const now = new Date();
  // YYYY-MM-DD of the first day of the current calendar month.
  const monthStart = new Date(now.getFullYear(), now.getMonth(), 1)
    .toISOString()
    .split('T')[0];

  // usage_buckets_daily holds pre-aggregated daily totals per metric_key.
  // Summing total_quantity across all rows for the current month gives MTD units.
  // current_minute_remaining is owned by the Quota Durable Object and is not
  // accessible here; callers should fetch it separately from /v1/orgs/:id/quota/status.
  const result = await sb.query<UsageBucketRow>('usage_buckets_daily', {
    select: 'total_quantity',
    filters: [
      { column: 'organization_id', operator: 'eq', value: orgId },
      { column: 'bucket_date', operator: 'gte', value: monthStart },
    ],
  });

  if (!result.ok) {
    console.error('[bootstrap] Failed to fetch usage snapshot:', result.error);
    return EMPTY_USAGE;
  }

  const month_to_date_units = result.data.reduce(
    (sum, row) => sum + (typeof row.total_quantity === 'number' ? row.total_quantity : 0),
    0,
  );

  return { month_to_date_units, current_minute_remaining: null };
}

async function buildBootstrapPayload(
  authSub: string,
  userEmail: string,
  orgs: (Organization & { role: OrgRole })[],
  activeOrgId: string,
  sb: SupabaseClient,
): Promise<BootstrapResponse | null> {
  const [entitlementResult, usage] = await Promise.all([
    sb.query<Entitlement>('entitlements', {
      filters: [{ column: 'organization_id', operator: 'eq', value: activeOrgId }],
    }),
    loadUsageSnapshot(activeOrgId, sb),
  ]);

  if (!entitlementResult.ok) {
    console.error('[bootstrap] Failed to fetch entitlements:', entitlementResult.error);
    return null;
  }

  return {
    user: { id: authSub, email: userEmail },
    organizations: orgs,
    active_org_id: activeOrgId,
    entitlements: buildEntitlementMap(entitlementResult.data),
    usage_snapshot: usage,
  };
}

export async function handleBootstrap(
  request: Request,
  opts: BootstrapHandlerOptions,
): Promise<Response> {
  const tokenResult = requireBearerToken(request);
  if (!tokenResult.ok) return tokenResult.error;

  const { key, issuerUrl, audience } = auth0VerifyParams(opts);
  const jwtResult = await verifyJwt(tokenResult.token, key, { issuerUrl, audience });
  if (!jwtResult.ok) return jwtResult.error;

  const { sub, email } = jwtResult.payload;
  if (!sub) return unauthorized('JWT missing sub claim');

  const sb = createSupabaseClient(opts.supabaseUrl, opts.serviceRoleKey);

  const userResult = await resolveUserId(sub, sb);
  if (!userResult.ok) return userResult.error;

  const contextResult = await loadOrgContext(
    userResult.userId,
    request.headers.get('x-org-id'),
    sb,
  );
  if (!contextResult.ok) return contextResult.error;

  const payload = await buildBootstrapPayload(
    sub,
    email ?? '',
    contextResult.orgs,
    contextResult.activeOrgId,
    sb,
  );
  if (!payload) return serverError('Failed to build bootstrap response');

  return ok(payload);
}
