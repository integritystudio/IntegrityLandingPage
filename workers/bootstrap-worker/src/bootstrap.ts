import { notFound, serverError } from '../../lib/http';
import { createSupabaseClient } from '../../lib/supabase';
import type {
  Organization,
  OrgRole,
  OrgMembership,
  Entitlement,
  UsageBucket,
  BootstrapResponse,
} from '../../lib/types';

// OrgRow extends Organization so the query result maps directly without casts.
interface OrgRow extends Organization {
  [key: string]: unknown;
}

// UsageBucketRow extends UsageBucket so the query result maps directly.
type UsageBucketRow = UsageBucket & Record<string, unknown>;

const EMPTY_USAGE = {
  month_to_date_units: 0,
  current_minute_remaining: null as number | null,
};

/** Coerce a single-or-array Supabase result into a typed array. */
function normalizeRows<T>(data: T[] | T | null): T[] {
  if (data == null) return [];
  return Array.isArray(data) ? data : [data];
}

export async function loadOrgContext(
  userId: string,
  orgIdHeader: string | null,
  supabaseUrl: string,
  serviceRoleKey: string,
): Promise<
  | { ok: true; orgs: (Organization & { role: OrgRole })[]; activeOrgId: string }
  | { ok: false; error: Response }
> {
  const sb = createSupabaseClient(supabaseUrl, serviceRoleKey);

  const membershipResult = await sb.query<OrgMembership>(
    'organization_memberships',
    {
      select: 'organization_id, role',
      filters: [
        { column: 'user_id', operator: 'eq', value: userId },
        { column: 'status', operator: 'eq', value: 'active' },
      ],
    },
  );

  if (!membershipResult.ok) {
    console.error('Failed to fetch memberships:', membershipResult.error);
    return { ok: false, error: serverError('Failed to load organizations') };
  }

  const memberships = normalizeRows(membershipResult.data);

  if (memberships.length === 0) {
    return { ok: false, error: notFound('No active organization memberships found') };
  }

  const orgsResult = await sb.query<OrgRow>('organizations', {
    select: 'id, slug, name, billing_status, current_plan, quota_version',
  });

  if (!orgsResult.ok) {
    console.error('Failed to fetch organizations:', orgsResult.error);
    return { ok: false, error: serverError('Failed to load organization details') };
  }

  const orgIds = new Set(memberships.map((m) => m.organization_id));
  const roleByOrgId = new Map(memberships.map((m) => [m.organization_id, m.role]));

  const orgs: (Organization & { role: OrgRole })[] = normalizeRows(orgsResult.data)
    .filter((org) => orgIds.has(org.id))
    .map((org) => ({ ...org, role: roleByOrgId.get(org.id) as OrgRole }));

  // Guard: membership rows exist but no matching organization row (referential integrity gap).
  if (orgs.length === 0) {
    console.error(
      `loadBootstrapData: user ${userId} has ${memberships.length} membership(s) but no matching org rows`,
    );
    return { ok: false, error: notFound('No organization data found') };
  }

  const requested = orgIdHeader ? orgs.find((o) => o.id === orgIdHeader) : undefined;
  const activeOrgId = requested?.id ?? orgs[0].id;

  return { ok: true, orgs, activeOrgId };
}

export async function loadEntitlements(
  orgId: string,
  supabaseUrl: string,
  serviceRoleKey: string,
): Promise<Record<string, boolean | number | null> | null> {
  const sb = createSupabaseClient(supabaseUrl, serviceRoleKey);

  const result = await sb.query<Entitlement>('entitlements', {
    filters: [{ column: 'organization_id', operator: 'eq', value: orgId }],
  });

  if (!result.ok) {
    console.error('Failed to fetch entitlements:', result.error);
    return null;
  }

  const map: Record<string, boolean | number | null> = {};
  for (const ent of normalizeRows(result.data)) {
    if (!ent.enabled) {
      map[ent.feature_key] = false;
      continue;
    }
    map[ent.feature_key] = ent.hard_limit ?? ent.soft_limit ?? true;
  }

  return map;
}

export async function loadUsageSnapshot(
  orgId: string,
  supabaseUrl: string,
  serviceRoleKey: string,
): Promise<{ month_to_date_units: number; current_minute_remaining: number | null }> {
  const sb = createSupabaseClient(supabaseUrl, serviceRoleKey);

  const now = new Date();
  // YYYY-MM-DD of the first day of the current calendar month.
  const monthStart = new Date(now.getFullYear(), now.getMonth(), 1)
    .toISOString()
    .split('T')[0];

  // usage_buckets_daily holds pre-aggregated daily totals per metric_key.
  // Summing total_quantity across all rows for the current month gives MTD units.
  // current_minute_remaining is owned by the Quota Durable Object which is not
  // accessible from bootstrap-worker; callers should fetch it from /quota/status.
  const result = await sb.query<UsageBucketRow>('usage_buckets_daily', {
    select: 'total_quantity',
    filters: [
      { column: 'organization_id', operator: 'eq', value: orgId },
      { column: 'bucket_date', operator: 'gte', value: monthStart },
    ],
  });

  if (!result.ok) {
    console.error('Failed to fetch usage snapshot:', result.error);
    return EMPTY_USAGE;
  }

  const month_to_date_units = result.data.reduce(
    (sum, row) => sum + (typeof row.total_quantity === 'number' ? row.total_quantity : 0),
    0,
  );

  return { month_to_date_units, current_minute_remaining: null };
}

export async function buildBootstrapResponse(
  userId: string,
  userEmail: string,
  orgs: (Organization & { role: OrgRole })[],
  activeOrgId: string,
  supabaseUrl: string,
  serviceRoleKey: string,
): Promise<BootstrapResponse | null> {
  const [entitlements, usage] = await Promise.all([
    loadEntitlements(activeOrgId, supabaseUrl, serviceRoleKey),
    loadUsageSnapshot(activeOrgId, supabaseUrl, serviceRoleKey),
  ]);

  if (!entitlements) {
    return null;
  }

  return {
    user: { id: userId, email: userEmail },
    organizations: orgs,
    active_org_id: activeOrgId,
    entitlements,
    usage_snapshot: usage,
  };
}
