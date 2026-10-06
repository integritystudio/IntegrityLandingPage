/**
 * Staff read routes for the observability dashboard's admin customer view
 * (observability-toolkit dashboard backlog, ADMIN-CV-GATEWAY-READ, option A).
 *
 * `GET /v1/admin/orgs` lists every org, and `GET /v1/admin/orgs/:id/*` serves the four
 * customer read payloads for any org. The customer routes cannot do this: access there is
 * membership-only, and every `/v1/orgs/:id/*` request reserves a quota unit and writes a
 * `usage_events` row, so a staff read would spend the customer's month and appear on their
 * own Usage page. These routes are dispatched outside that branch, so they do none of it.
 *
 * Three rules hold on every handler here:
 * - Staff only, decided here from `STAFF_USER_IDS`. The dashboard's own `isStaff` check is
 *   presentation; this is the enforcement.
 * - Read-only, and the same loaders as the customer routes, so the payloads match byte for
 *   byte (`role` is `null` on billing-status, because a staff caller holds no membership).
 * - One `audit_log` row per org opened, not per poll (`recordAdminOrgView`).
 */
import { ok, forbidden, notFound, serviceUnavailable } from '../../../lib/http';
import { requireBearerToken } from '../../../lib/http/request';
import { parseApiKey } from '../../../lib/api-keys';
import { createSupabaseClient, type SupabaseClient } from '../../../lib/supabase';
import type { Organization } from '../../../lib/types';
import { resolveJwtRateLimited, resolveUserId, type LoadResult, type UserTokenOptions } from '../lib/helpers';
import { recordAdminOrgView } from '../lib/admin-view-audit';
import { ADMIN_ORG_ROUTES, type AdminOrgRouteName } from '../lib/org-routes';
import { loadBillingStatus } from './orgs';
import { loadEntitlements, loadQuotaStatus, loadUsageSummary } from './usage';

export interface AdminRouteOptions extends UserTokenOptions {
  supabaseUrl: string;
  serviceRoleKey: string;
  /**
   * `STAFF_USER_IDS`: a JSON array of `users.id` UUIDs. Absent, empty or malformed means
   * nobody is staff, so every route here answers 403 — fail closed, as the dashboard's
   * copy of the list does.
   */
  staffUserIds?: string;
  waitUntil?: (promise: Promise<unknown>) => void;
}

export interface AdminOrgRouteOptions extends AdminRouteOptions {
  doNamespace: DurableObjectNamespace;
}

/** What `GET /v1/admin/orgs` lists per org. The dashboard hub's org directory reads these five. */
export type AdminOrgSummary = Pick<Organization, 'id' | 'name' | 'slug' | 'billing_status' | 'current_plan'>;

/** The billing routes refuse keys the same way; a key-authenticated caller gets a reason, not a JWT-shaped 401. */
export const ADMIN_API_KEYS_REFUSED = 'Admin routes require a user session; API keys are not accepted';
export const ADMIN_STAFF_ONLY = 'Staff access required';
export const ADMIN_ORG_SELECT = 'id, name, slug, billing_status, current_plan';
const ORG_EXISTS_SELECT = 'id';
/** The hub shows the whole directory in one dropdown, so it arrives sorted. */
const ADMIN_ORG_ORDER = { column: 'name', ascending: true } as const;
const ADMIN_ORG_PATH_TEMPLATE = '/v1/admin/orgs/:id';

type StaffResult = { ok: true; sub: string; userId: string } | { ok: false; error: Response };

/** Parse `STAFF_USER_IDS` — fail closed on malformed input, as the dashboard Worker does. */
export function parseStaffUserIds(raw: string | undefined): Set<string> {
  if (!raw) return new Set();
  try {
    const parsed: unknown = JSON.parse(raw);
    return Array.isArray(parsed) ? new Set(parsed.filter((v): v is string => typeof v === 'string')) : new Set();
  } catch {
    console.error('[admin] STAFF_USER_IDS is not valid JSON — treating as empty allowlist');
    return new Set();
  }
}

/**
 * The caller must hold a user session (never an API key) whose `users.id` is on the staff
 * list. The per-identity throttle applies, as on the other routes with no org quota.
 */
async function resolveStaff(request: Request, opts: AdminRouteOptions, sb: SupabaseClient): Promise<StaffResult> {
  const tokenResult = requireBearerToken(request);
  if (!tokenResult.ok) return tokenResult;
  if (parseApiKey(tokenResult.token).ok) return { ok: false, error: forbidden(ADMIN_API_KEYS_REFUSED) };

  const auth = await resolveJwtRateLimited(request, opts);
  if (!auth.ok) return auth;

  const user = await resolveUserId(auth.sub, sb);
  if (!user.ok) return user;

  if (!parseStaffUserIds(opts.staffUserIds).has(user.userId)) {
    return { ok: false, error: forbidden(ADMIN_STAFF_ONLY) };
  }
  return { ok: true, sub: auth.sub, userId: user.userId };
}

/**
 * The customer routes never meet an unknown org — the membership check refuses it first —
 * so their loaders answer one with empty usage, a plan-less entitlement map or a 500. A
 * staff caller can name any id, so each org route checks first and answers 404.
 */
async function orgExists(sb: SupabaseClient, orgId: string): Promise<LoadResult<true>> {
  const result = await sb.query<{ id: string }>('organizations', {
    select: ORG_EXISTS_SELECT,
    filters: [{ column: 'id', operator: 'eq', value: orgId }],
    limit: 1,
  });
  if (!result.ok) return { ok: false, error: serviceUnavailable('Organizations query failed') };
  if (result.data.length === 0) return { ok: false, error: notFound('Organization not found') };
  return { ok: true, data: true };
}

function adminRouteLabel(name: AdminOrgRouteName): string {
  return `${ADMIN_ORG_ROUTES[name].method} ${ADMIN_ORG_PATH_TEMPLATE}${ADMIN_ORG_ROUTES[name].subPath}`;
}

/** Staff check, org check, and the per-view audit row, in that order; the loaders run after. */
async function authorizeOrgView(
  request: Request,
  orgId: string,
  route: AdminOrgRouteName,
  opts: AdminRouteOptions,
  sb: SupabaseClient,
): Promise<{ ok: true } | { ok: false; error: Response }> {
  const staff = await resolveStaff(request, opts, sb);
  if (!staff.ok) return staff;

  const exists = await orgExists(sb, orgId);
  if (!exists.ok) return exists;

  const audit = recordAdminOrgView(sb, opts.rateLimitKv, {
    userId: staff.userId,
    sub: staff.sub,
    orgId,
    route: adminRouteLabel(route),
  });
  if (opts.waitUntil) opts.waitUntil(audit);
  else await audit;

  return { ok: true };
}

/** `GET /v1/admin/orgs` — every org, for the hub's directory. Not an org view, so no audit row. */
export async function handleAdminListOrgs(request: Request, opts: AdminRouteOptions): Promise<Response> {
  const sb = createSupabaseClient(opts.supabaseUrl, opts.serviceRoleKey);
  const staff = await resolveStaff(request, opts, sb);
  if (!staff.ok) return staff.error;

  const result = await sb.query<AdminOrgSummary & Record<string, unknown>>('organizations', {
    select: ADMIN_ORG_SELECT,
    order: ADMIN_ORG_ORDER,
  });
  if (!result.ok) return serviceUnavailable('Organizations query failed');

  return ok({ organizations: result.data });
}

export async function handleAdminOrgBillingStatus(request: Request, orgId: string, opts: AdminRouteOptions): Promise<Response> {
  const sb = createSupabaseClient(opts.supabaseUrl, opts.serviceRoleKey);
  const access = await authorizeOrgView(request, orgId, 'billingStatus', opts, sb);
  if (!access.ok) return access.error;

  const billing = await loadBillingStatus(sb, orgId, null);
  return billing.ok ? ok(billing.data) : billing.error;
}

export async function handleAdminUsageSummary(request: Request, orgId: string, opts: AdminRouteOptions): Promise<Response> {
  const sb = createSupabaseClient(opts.supabaseUrl, opts.serviceRoleKey);
  const access = await authorizeOrgView(request, orgId, 'usageSummary', opts, sb);
  if (!access.ok) return access.error;

  const summary = await loadUsageSummary(sb, orgId);
  return summary.ok ? ok(summary.data) : summary.error;
}

export async function handleAdminOrgEntitlements(request: Request, orgId: string, opts: AdminRouteOptions): Promise<Response> {
  const sb = createSupabaseClient(opts.supabaseUrl, opts.serviceRoleKey);
  const access = await authorizeOrgView(request, orgId, 'entitlements', opts, sb);
  if (!access.ok) return access.error;

  const entitlements = await loadEntitlements(sb, orgId);
  return entitlements.ok ? ok(entitlements.data) : entitlements.error;
}

export async function handleAdminQuotaStatus(request: Request, orgId: string, opts: AdminOrgRouteOptions): Promise<Response> {
  const sb = createSupabaseClient(opts.supabaseUrl, opts.serviceRoleKey);
  const access = await authorizeOrgView(request, orgId, 'quotaStatus', opts, sb);
  if (!access.ok) return access.error;

  return ok(await loadQuotaStatus(opts.doNamespace, orgId));
}
