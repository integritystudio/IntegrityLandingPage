import { ok, forbidden, notFound, serverError } from '../../../lib/http';
import { requireBearerToken } from '../../../lib/http/request';
import { verifyJwt } from '../../../lib/auth';
import { createSupabaseClient, type SupabaseClient } from '../../../lib/supabase';
import type { Organization, OrgRole, OrgMembership, Entitlement } from '../../../lib/types';

interface OrgsHandlerOptions {
  jwtSecret: string;
  supabaseUrl: string;
  serviceRoleKey: string;
  _sbOverride?: SupabaseClient;
}

const BILLING_ROLES: OrgRole[] = ['owner', 'billing_admin'];

function buildEntitlementMap(rows: Entitlement[]): Record<string, boolean | number | null> {
  const map: Record<string, boolean | number | null> = {};
  for (const ent of rows) {
    if (!ent.enabled) {
      map[ent.feature_key] = false;
      continue;
    }
    map[ent.feature_key] = ent.hard_limit ?? ent.soft_limit ?? true;
  }
  return map;
}

async function resolveJwt(
  request: Request,
  jwtSecret: string,
): Promise<{ ok: true; sub: string } | { ok: false; error: Response }> {
  const tokenResult = requireBearerToken(request);
  if (!tokenResult.ok) return tokenResult;
  const jwtResult = await verifyJwt(tokenResult.token, jwtSecret);
  if (!jwtResult.ok) return jwtResult;
  if (!jwtResult.payload.sub) {
    const { unauthorized } = await import('../../../lib/http');
    return { ok: false, error: unauthorized('JWT missing sub claim') };
  }
  return { ok: true, sub: jwtResult.payload.sub };
}

async function loadUserMemberships(
  userId: string,
  sb: SupabaseClient,
): Promise<OrgMembership[]> {
  const result = await sb.query<OrgMembership>('organization_memberships', {
    select: 'organization_id, user_id, role, status',
    filters: [
      { column: 'user_id', operator: 'eq', value: userId },
      { column: 'status', operator: 'eq', value: 'active' },
    ],
  });
  if (!result.ok || !Array.isArray(result.data)) return [];
  return result.data;
}

async function loadOrgsForMemberships(
  memberships: OrgMembership[],
  sb: SupabaseClient,
): Promise<Array<Organization & { role: OrgRole }>> {
  if (memberships.length === 0) return [];

  const orgIds = new Set(memberships.map((m) => m.organization_id));
  const roleByOrgId = new Map(memberships.map((m) => [m.organization_id, m.role]));

  const result = await sb.query<Organization>('organizations', {
    select: 'id, slug, name, billing_status, current_plan, quota_version',
  });

  if (!result.ok || !Array.isArray(result.data)) return [];

  return result.data
    .filter((org) => orgIds.has(org.id))
    .map((org) => ({ ...org, role: roleByOrgId.get(org.id) as OrgRole }));
}

export async function handleListOrgs(
  request: Request,
  opts: OrgsHandlerOptions,
): Promise<Response> {
  const auth = await resolveJwt(request, opts.jwtSecret);
  if (!auth.ok) return auth.error;

  const sb = opts._sbOverride ?? createSupabaseClient(opts.supabaseUrl, opts.serviceRoleKey);
  const memberships = await loadUserMemberships(auth.sub, sb);

  if (memberships.length === 0) {
    return ok({ organizations: [] });
  }

  const orgs = await loadOrgsForMemberships(memberships, sb);
  return ok({ organizations: orgs });
}

export async function handleOrgDashboard(
  request: Request,
  orgId: string,
  opts: OrgsHandlerOptions,
): Promise<Response> {
  const auth = await resolveJwt(request, opts.jwtSecret);
  if (!auth.ok) return auth.error;

  const sb = opts._sbOverride ?? createSupabaseClient(opts.supabaseUrl, opts.serviceRoleKey);
  const memberships = await loadUserMemberships(auth.sub, sb);
  const membership = memberships.find((m) => m.organization_id === orgId);
  if (!membership) return forbidden('Not a member of this organization');

  const orgResult = await sb.query<Organization>('organizations', {
    select: 'id, slug, name, billing_status, current_plan, quota_version',
    filters: [{ column: 'id', operator: 'eq', value: orgId }],
    limit: 1,
  });

  if (!orgResult.ok || !Array.isArray(orgResult.data) || orgResult.data.length === 0) {
    return notFound('Organization not found');
  }

  const org = orgResult.data[0];

  const entResult = await sb.query<Entitlement>('entitlements', {
    filters: [{ column: 'organization_id', operator: 'eq', value: orgId }],
  });

  const entitlements = buildEntitlementMap(
    entResult.ok && Array.isArray(entResult.data) ? entResult.data : [],
  );

  return ok({
    org,
    role: membership.role,
    entitlements,
  });
}

export async function handleOrgBillingStatus(
  request: Request,
  orgId: string,
  opts: OrgsHandlerOptions,
): Promise<Response> {
  const auth = await resolveJwt(request, opts.jwtSecret);
  if (!auth.ok) return auth.error;

  const sb = opts._sbOverride ?? createSupabaseClient(opts.supabaseUrl, opts.serviceRoleKey);
  const memberships = await loadUserMemberships(auth.sub, sb);
  const membership = memberships.find((m) => m.organization_id === orgId);
  if (!membership) return forbidden('Not a member of this organization');

  const orgResult = await sb.query<Organization>('organizations', {
    select: 'id, billing_status, current_plan, quota_version',
    filters: [{ column: 'id', operator: 'eq', value: orgId }],
    limit: 1,
  });

  if (!orgResult.ok || !Array.isArray(orgResult.data) || orgResult.data.length === 0) {
    return serverError('Failed to load organization');
  }

  const org = orgResult.data[0];

  return ok({
    org_id: orgId,
    billing_status: org.billing_status,
    current_plan: org.current_plan,
    quota_version: org.quota_version,
    role: membership.role,
  });
}
