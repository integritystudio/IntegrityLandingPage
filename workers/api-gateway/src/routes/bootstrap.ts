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
type UsageSnapshot = BootstrapResponse['usage_snapshot'];

/**
 * Returned when the usage aggregate cannot be read. `unavailable` is what distinguishes it
 * from a genuine zero — without it a failed query and a brand-new account are byte-identical
 * in the response, which is how a database problem reads as "no usage".
 */
const USAGE_UNAVAILABLE: UsageSnapshot = {
  month_to_date_units: 0,
  current_minute_remaining: null,
  unavailable: true,
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

  // A partial resolution is also a referential-integrity problem, and it used to pass silently
  // because only the zero case was logged: a user with three memberships and two surviving org
  // rows would just see two organizations. Serving the rest is still the right behaviour — one
  // dangling membership should not lock the account out — but it must not be invisible.
  if (orgsResult.data.length !== orgIds.size) {
    const missing = [...orgIds].filter((id) => !orgsResult.data.some((org) => org.id === id));
    console.error(
      `[bootstrap] user ${userId} has ${orgIds.size} membership(s) but ${orgsResult.data.length} org row(s); missing: ${missing.join(', ')}`,
    );
  }

  // No `as OrgRole` cast here. Every org came back from an `in` filter over the membership
  // org IDs, so a missing role is unreachable — but a cast would fabricate one if that ever
  // stopped holding, and an undefined role silently serialises to an absent field rather than
  // failing. Dropping the entry instead keeps the invariant "every org listed has a role".
  const orgs: (Organization & { role: OrgRole })[] = orgsResult.data.flatMap((org) => {
    const role = roleByOrgId.get(org.id);
    if (!role) {
      console.error(`[bootstrap] org ${org.id} returned for user ${userId} with no matching membership role`);
      return [];
    }
    return [{ ...org, role }];
  });

  if (orgs.length === 0) {
    return { ok: false, error: notFound('No organization data found') };
  }

  const requested = orgIdHeader ? orgs.find((o) => o.id === orgIdHeader) : undefined;
  const activeOrgId = requested?.id ?? orgs[0].id;

  return { ok: true, orgs, activeOrgId };
}

async function loadUsageSnapshot(orgId: string, sb: SupabaseClient): Promise<UsageSnapshot> {
  const now = new Date();
  // YYYY-MM-DD of the first day of the current calendar month, in UTC.
  // Built by formatting the UTC parts rather than via `new Date(y, m, 1).toISOString()`:
  // that constructor reads its arguments as *local* time, so in any zone ahead of UTC local
  // midnight on the 1st is still the previous month in UTC — it renders as the 30th/31st and
  // this filter then sweeps that day's buckets into the month-to-date total. Workers run in
  // UTC, so the old form happened to be correct in production while being wrong on any
  // developer machine east of UTC. Pinned by a test that runs under Asia/Tokyo.
  const monthStart = `${now.getUTCFullYear()}-${String(now.getUTCMonth() + 1).padStart(2, '0')}-01`;

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
    return USAGE_UNAVAILABLE;
  }

  const month_to_date_units = result.data.reduce(
    (sum, row) => sum + (typeof row.total_quantity === 'number' ? row.total_quantity : 0),
    0,
  );

  return { month_to_date_units, current_minute_remaining: null };
}

async function buildBootstrapPayload(
  userId: string,
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
    // `id` is the internal users.id, matching what GET /v1/me returns for the same user.
    // It deliberately is not the Auth0 sub: two endpoints describing one user must not
    // disagree about which key `id` means — conflating those two is what made an Auth0
    // subject reach a uuid column and silently return an empty account.
    user: { id: userId, email: userEmail },
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

  const { sub } = jwtResult.payload;
  if (!sub) return unauthorized('JWT missing sub claim');

  const sb = createSupabaseClient(opts.supabaseUrl, opts.serviceRoleKey);

  // Both the internal id and the email come from the users row. The email is not read from
  // the JWT: an Auth0 access token for a custom audience carries no `email` claim even when
  // `email` is in the requested scope, so `payload.email` is always undefined here and the
  // previous `?? ''` fallback meant this field shipped permanently blank.
  const userResult = await resolveUserId(sub, sb);
  if (!userResult.ok) return userResult.error;

  const contextResult = await loadOrgContext(
    userResult.userId,
    request.headers.get('x-org-id'),
    sb,
  );
  if (!contextResult.ok) return contextResult.error;

  const payload = await buildBootstrapPayload(
    userResult.userId,
    userResult.email,
    contextResult.orgs,
    contextResult.activeOrgId,
    sb,
  );
  if (!payload) return serverError('Failed to build bootstrap response');

  return ok(payload);
}
