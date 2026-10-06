import { describe, it, expect, vi, afterEach, beforeAll } from 'vitest';
import {
  handleAdminListOrgs,
  handleAdminOrgBillingStatus,
  handleAdminUsageSummary,
  handleAdminOrgEntitlements,
  handleAdminQuotaStatus,
  parseStaffUserIds,
  ADMIN_API_KEYS_REFUSED,
  ADMIN_STAFF_ONLY,
  ADMIN_ORG_SELECT,
} from './admin';
import { handleOrgBillingStatus } from './orgs';
import { handleUsageSummary, handleOrgEntitlements, handleQuotaStatus } from './usage';
import {
  createSupabaseFetchStub,
  createdRows,
  httpError,
  okRows,
  TEST_SERVICE_ROLE_KEY,
  TEST_SUPABASE_URL,
  type RouteResponder,
  type SupabaseFetchStub,
} from '../../../lib/test-helpers/supabase-fetch-stub';
import { createAuth0JwtFixture, TEST_AUTH0_OPTS, type Auth0JwtFixture } from '../../../lib/test-helpers/auth0-jwt-stub';
import { resetIdentityRateLimit } from '../lib/rate-limit';
import { resetAdminViewAudit } from '../lib/admin-view-audit';

const ORG_ID = 'org-id-1';
const OTHER_ORG_ID = 'org-id-2';
const STAFF_SUB = 'auth0|staff';
const STAFF_USER_ID = 'user-staff';
const MEMBER_SUB = 'auth0|member';
const MEMBER_USER_ID = 'user-member';
const API_KEY_TOKEN = 'int_live_abc12345_0123456789abcdef';

const ORG_ROW = { id: ORG_ID, slug: 'acme', name: 'Acme', billing_status: 'active', current_plan: 'growth', quota_version: 1, stripe_customer_id: 'cus_123' };
const OTHER_ORG_ROW = { id: OTHER_ORG_ID, slug: 'zeta', name: 'Zeta', billing_status: 'inactive', current_plan: 'starter', quota_version: 0, stripe_customer_id: null };

// Mirrors the live `plans` row for growth, as usage.test.ts does.
const GROWTH_PLAN = {
  key: 'growth',
  monthly_units: 500000,
  requests_per_minute: 600,
  concurrent_jobs: 5,
  features: { alerts: true, usage_dashboard: true, compliance_summary: true },
};

const QUOTA_PAYLOAD = {
  orgId: ORG_ID,
  planKey: 'growth',
  quotaVersion: 2,
  minuteLimit: 60,
  monthlyLimit: 500000,
  minuteUsed: 5,
  monthlyUsed: 12345,
  minuteWindowExpiresIn: 45000,
};

const opts = {
  ...TEST_AUTH0_OPTS,
  supabaseUrl: TEST_SUPABASE_URL,
  serviceRoleKey: TEST_SERVICE_ROLE_KEY,
  staffUserIds: JSON.stringify([STAFF_USER_ID]),
};

/** The customer routes' options: same tenant and database, no staff list. */
const customerOpts = {
  ...TEST_AUTH0_OPTS,
  supabaseUrl: TEST_SUPABASE_URL,
  serviceRoleKey: TEST_SERVICE_ROLE_KEY,
};

let jwt: Auth0JwtFixture;

beforeAll(async () => {
  jwt = await createAuth0JwtFixture();
});

afterEach(() => {
  resetIdentityRateLimit();
  resetAdminViewAudit();
  vi.unstubAllGlobals();
  vi.restoreAllMocks();
});

/**
 * The staff user and the org member both resolve through `users`; the stub answers the
 * lookup by sub so one fixture serves both callers.
 */
function usersRoute(): RouteResponder {
  return (req) => {
    const sub = req.url.searchParams.get('auth0_id');
    const row = sub === `eq.${STAFF_SUB}` ? { id: STAFF_USER_ID } : sub === `eq.${MEMBER_SUB}` ? { id: MEMBER_USER_ID } : null;
    return new Response(JSON.stringify(row ? [row] : []), { status: 200, headers: { 'content-type': 'application/json' } });
  };
}

function stubSupabase(routes: Record<string, RouteResponder>): SupabaseFetchStub {
  const stub = createSupabaseFetchStub({
    'GET users': usersRoute(),
    'GET organizations': okRows([ORG_ROW]),
    'POST audit_log': createdRows([]),
    ...routes,
  });
  vi.stubGlobal('fetch', jwt.wrap(stub.fetch));
  return stub;
}

/** The data every org route can need, so the parity rows below share one fixture. */
const orgDataRoutes = (): Record<string, RouteResponder> => ({
  'GET usage_buckets_daily': okRows([
    { organization_id: ORG_ID, bucket_date: '2026-03-01', metric_key: 'requests', total_quantity: 1234, request_count: 100, avg_latency_ms: 45 },
  ]),
  'GET entitlements': okRows([
    { organization_id: ORG_ID, feature_key: 'api_keys_max', enabled: true, hard_limit: 10, soft_limit: null },
  ]),
  'GET plans': okRows([GROWTH_PLAN]),
});

const memberRoutes = (): Record<string, RouteResponder> => ({
  'GET organization_memberships': okRows([{ organization_id: ORG_ID, user_id: MEMBER_USER_ID, role: 'owner', status: 'active' }]),
});

const makeDoNamespace = (statusPayload: unknown) => ({
  idFromName: vi.fn().mockReturnValue('stub-id'),
  get: vi.fn().mockReturnValue({
    fetch: vi.fn().mockResolvedValue(new Response(JSON.stringify(statusPayload), { status: 200 })),
  }),
} as unknown as DurableObjectNamespace);

const authed = (path: string, token: string) =>
  new Request(`https://api.test${path}`, { method: 'GET', headers: { authorization: `Bearer ${token}` } });

const staffRequest = async (path: string) => authed(path, await jwt.sign({ sub: STAFF_SUB, email: 'staff@test.com' }));
const memberRequest = async (path: string) => authed(path, await jwt.sign({ sub: MEMBER_SUB, email: 'member@test.com' }));

const ADMIN_PATH = `/v1/admin/orgs/${ORG_ID}`;

/** Every org route, so the access rules below are asserted on each rather than on one. */
const ORG_ROUTES = [
  ['billing-status', (req: Request, orgId = ORG_ID) => handleAdminOrgBillingStatus(req, orgId, opts)],
  ['usage/summary', (req: Request, orgId = ORG_ID) => handleAdminUsageSummary(req, orgId, opts)],
  ['entitlements', (req: Request, orgId = ORG_ID) => handleAdminOrgEntitlements(req, orgId, opts)],
  ['quota/status', (req: Request, orgId = ORG_ID) => handleAdminQuotaStatus(req, orgId, { ...opts, doNamespace: makeDoNamespace(QUOTA_PAYLOAD) })],
] as const;

describe('parseStaffUserIds', () => {
  it.each([
    ['undefined', undefined],
    ['empty string', ''],
    ['not JSON', '{nope'],
    ['not an array', '{"a":1}'],
    ['an empty array', '[]'],
  ])('is empty for %s', (_label, raw) => {
    vi.spyOn(console, 'error').mockImplementation(() => {});
    expect(parseStaffUserIds(raw).size).toBe(0);
  });

  it('keeps only the string members', () => {
    expect([...parseStaffUserIds('["a", 1, null, "b"]')]).toEqual(['a', 'b']);
  });
});

describe('the staff gate on every admin route', () => {
  const ALL_ROUTES = [
    ['orgs', (req: Request) => handleAdminListOrgs(req, opts)],
    ...ORG_ROUTES,
  ] as const;

  it.each(ALL_ROUTES)('%s: 401 without a bearer token, touching nothing', async (_name, call) => {
    const stub = stubSupabase({});
    const res = await call(new Request(`https://api.test${ADMIN_PATH}`));
    expect(res.status).toBe(401);
    expect(stub.requests).toHaveLength(0);
  });

  it.each(ALL_ROUTES)('%s: 403 for an API key, touching nothing', async (_name, call) => {
    const stub = stubSupabase({});
    const res = await call(authed(ADMIN_PATH, API_KEY_TOKEN));
    expect(res.status).toBe(403);
    expect((await res.json() as { error: { message: string } }).error.message).toBe(ADMIN_API_KEYS_REFUSED);
    expect(stub.requests).toHaveLength(0);
  });

  // An org owner holds `dashboard.admin` on the dashboard; that must not reach here.
  it.each(ALL_ROUTES)('%s: 403 for a verified non-staff user, even an org owner', async (_name, call) => {
    const stub = stubSupabase({ ...memberRoutes(), ...orgDataRoutes() });
    const res = await call(await memberRequest(ADMIN_PATH));
    expect(res.status).toBe(403);
    expect((await res.json() as { error: { message: string } }).error.message).toBe(ADMIN_STAFF_ONLY);
    // Only the user lookup ran: no org data was read and no audit row was written.
    expect(stub.requests.map((r) => r.table)).toEqual(['users']);
  });

  it.each([
    ['unset', undefined],
    ['empty', '[]'],
    ['malformed', 'not json'],
  ])('403 for everyone when STAFF_USER_IDS is %s', async (_label, staffUserIds) => {
    vi.spyOn(console, 'error').mockImplementation(() => {});
    stubSupabase({});
    const res = await handleAdminListOrgs(await staffRequest('/v1/admin/orgs'), { ...opts, staffUserIds });
    expect(res.status).toBe(403);
  });
});

describe('GET /v1/admin/orgs', () => {
  it('lists every org with the five directory fields, sorted by name', async () => {
    const stub = stubSupabase({ 'GET organizations': okRows([ORG_ROW, OTHER_ORG_ROW]) });

    const res = await handleAdminListOrgs(await staffRequest('/v1/admin/orgs'), opts);

    expect(res.status).toBe(200);
    const body = await res.json() as { organizations: Array<Record<string, unknown>> };
    expect(body.organizations.map((o) => o.id)).toEqual([ORG_ID, OTHER_ORG_ID]);
    const params = stub.find('GET', 'organizations')!.url.searchParams;
    expect(params.get('select')).toBe(ADMIN_ORG_SELECT);
    expect(params.get('order')).toBe('name.asc');
    // A directory, not a membership list: no membership filter and no user filter.
    expect(params.get('id')).toBeNull();
    expect(stub.findAll('GET', 'organization_memberships')).toHaveLength(0);
  });

  it('writes no audit row: listing is not opening an org', async () => {
    const stub = stubSupabase({});
    await handleAdminListOrgs(await staffRequest('/v1/admin/orgs'), opts);
    expect(stub.findAll('POST', 'audit_log')).toHaveLength(0);
  });

  it('returns 503 when the query fails', async () => {
    stubSupabase({ 'GET organizations': httpError(500) });
    const res = await handleAdminListOrgs(await staffRequest('/v1/admin/orgs'), opts);
    expect(res.status).toBe(503);
  });
});

describe('the org routes for a staff caller', () => {
  it.each(ORG_ROUTES)('%s: 200 for an org the caller is not a member of, with no membership lookup', async (_name, call) => {
    const stub = stubSupabase(orgDataRoutes());
    const res = await call(await staffRequest(ADMIN_PATH));
    expect(res.status).toBe(200);
    expect(stub.findAll('GET', 'organization_memberships')).toHaveLength(0);
  });

  it.each(ORG_ROUTES)('%s: 404 for an org that does not exist', async (_name, call) => {
    const stub = stubSupabase({ 'GET organizations': okRows([]), ...orgDataRoutes() });
    const res = await call(await staffRequest(ADMIN_PATH));
    expect(res.status).toBe(404);
    expect(stub.findAll('POST', 'audit_log')).toHaveLength(0);
  });

  it.each(ORG_ROUTES)('%s: 503 when the org lookup fails', async (_name, call) => {
    stubSupabase({ 'GET organizations': httpError(500) });
    const res = await call(await staffRequest(ADMIN_PATH));
    expect(res.status).toBe(503);
  });

  it('billing-status carries role: null, since a staff caller holds no membership', async () => {
    stubSupabase({});
    const res = await handleAdminOrgBillingStatus(await staffRequest(ADMIN_PATH), ORG_ID, opts);
    const text = await res.text();
    expect(JSON.parse(text)).toEqual({
      org_id: ORG_ID,
      billing_status: 'active',
      current_plan: 'growth',
      quota_version: 1,
      role: null,
      has_billing_account: true,
    });
    expect(text).not.toContain('cus_123');
  });

  it('usage/summary reads the current UTC month, newest bucket first', async () => {
    const stub = stubSupabase(orgDataRoutes());
    const res = await handleAdminUsageSummary(await staffRequest(ADMIN_PATH), ORG_ID, opts);
    const body = await res.json() as { org_id: string; period_start: string; buckets: unknown[] };
    expect(body.org_id).toBe(ORG_ID);
    expect(body.buckets).toHaveLength(1);
    const params = stub.find('GET', 'usage_buckets_daily')!.url.searchParams;
    expect(params.get('bucket_date')).toBe(`gte.${body.period_start}`);
    expect(params.get('order')).toBe('bucket_date.desc');
  });

  it('entitlements is the plan projection overlaid with the explicit rows', async () => {
    stubSupabase(orgDataRoutes());
    const res = await handleAdminOrgEntitlements(await staffRequest(ADMIN_PATH), ORG_ID, opts);
    const body = await res.json() as { entitlements: Record<string, unknown> };
    expect(body.entitlements).toEqual({
      alerts: true,
      usage_dashboard: true,
      compliance_summary: true,
      monthly_units: 500000,
      requests_per_minute: 600,
      concurrent_jobs: 5,
      api_keys_max: 10,
    });
  });

  it('quota/status is the Durable Object status, read without a reservation', async () => {
    stubSupabase({});
    const doNamespace = makeDoNamespace(QUOTA_PAYLOAD);
    const res = await handleAdminQuotaStatus(await staffRequest(ADMIN_PATH), ORG_ID, { ...opts, doNamespace });
    const body = await res.json() as Record<string, unknown>;
    expect(body).toEqual({ org_id: ORG_ID, ...QUOTA_PAYLOAD });
    const doFetch = (doNamespace.get as ReturnType<typeof vi.fn>).mock.results[0].value.fetch as ReturnType<typeof vi.fn>;
    const [request] = doFetch.mock.calls[0] as [Request];
    expect(request.method).toBe('GET');
    expect(new URL(request.url).pathname).toBe('/status');
  });

  it('quota/status answers uninitialized when the Durable Object is unavailable', async () => {
    stubSupabase({});
    const throwingDo = {
      idFromName: vi.fn().mockReturnValue('stub-id'),
      get: vi.fn().mockReturnValue({ fetch: vi.fn().mockRejectedValue(new Error('DO unavailable')) }),
    } as unknown as DurableObjectNamespace;
    const res = await handleAdminQuotaStatus(await staffRequest(ADMIN_PATH), ORG_ID, { ...opts, doNamespace: throwingDo });
    expect(await res.json()).toEqual({ org_id: ORG_ID, status: 'uninitialized' });
  });
});

/**
 * The epic's parity requirement: each admin payload has the customer payload's keys, in the
 * customer's order, because both come from one loader. A field renamed on one side alone
 * fails here.
 */
describe('parity with the customer routes', () => {
  async function keysOf(res: Response): Promise<string[]> {
    return Object.keys(await res.json() as Record<string, unknown>);
  }

  it.each([
    ['billing-status',
      (req: Request) => handleOrgBillingStatus(req, ORG_ID, customerOpts),
      (req: Request) => handleAdminOrgBillingStatus(req, ORG_ID, opts)],
    ['usage/summary',
      (req: Request) => handleUsageSummary(req, ORG_ID, customerOpts),
      (req: Request) => handleAdminUsageSummary(req, ORG_ID, opts)],
    ['entitlements',
      (req: Request) => handleOrgEntitlements(req, ORG_ID, customerOpts),
      (req: Request) => handleAdminOrgEntitlements(req, ORG_ID, opts)],
    ['quota/status',
      (req: Request) => handleQuotaStatus(req, ORG_ID, { ...customerOpts, doNamespace: makeDoNamespace(QUOTA_PAYLOAD) }),
      (req: Request) => handleAdminQuotaStatus(req, ORG_ID, { ...opts, doNamespace: makeDoNamespace(QUOTA_PAYLOAD) })],
  ] as const)('%s: the staff payload has the customer payload\'s keys in the same order', async (_name, customer, admin) => {
    stubSupabase({ ...memberRoutes(), ...orgDataRoutes() });

    const customerRes = await customer(await memberRequest(`/v1/orgs/${ORG_ID}`));
    const adminRes = await admin(await staffRequest(ADMIN_PATH));

    expect(customerRes.status).toBe(200);
    expect(adminRes.status).toBe(200);
    expect(await keysOf(adminRes)).toEqual(await keysOf(customerRes));
  });

  it('the two billing payloads differ only in role', async () => {
    stubSupabase(memberRoutes());
    const customer = await (await handleOrgBillingStatus(await memberRequest(`/v1/orgs/${ORG_ID}`), ORG_ID, customerOpts)).json() as Record<string, unknown>;
    const admin = await (await handleAdminOrgBillingStatus(await staffRequest(ADMIN_PATH), ORG_ID, opts)).json() as Record<string, unknown>;
    expect(admin).toEqual({ ...customer, role: null });
  });
});

describe('the audit row per org opened', () => {
  const EXPECTED_ROW = {
    organization_id: ORG_ID,
    actor_user_id: STAFF_USER_ID,
    action: 'admin.org_viewed',
    target_type: 'org',
    target_id: ORG_ID,
    metadata: { actor_auth0_id: STAFF_SUB, route: 'GET /v1/admin/orgs/:id/usage/summary' },
  };

  it('writes one row on the first read, naming who opened which org on which route', async () => {
    const stub = stubSupabase(orgDataRoutes());
    await handleAdminUsageSummary(await staffRequest(ADMIN_PATH), ORG_ID, opts);
    const audits = stub.findAll('POST', 'audit_log');
    expect(audits).toHaveLength(1);
    expect(audits[0].body).toEqual([expect.objectContaining(EXPECTED_ROW)]);
  });

  it('writes nothing for the same org again inside the window, whichever route polls it', async () => {
    const stub = stubSupabase(orgDataRoutes());
    await handleAdminUsageSummary(await staffRequest(ADMIN_PATH), ORG_ID, opts);
    await handleAdminUsageSummary(await staffRequest(ADMIN_PATH), ORG_ID, opts);
    await handleAdminOrgEntitlements(await staffRequest(ADMIN_PATH), ORG_ID, opts);
    expect(stub.findAll('POST', 'audit_log')).toHaveLength(1);
  });

  it('writes a row per org, so opening a second org is recorded', async () => {
    const stub = stubSupabase({ 'GET organizations': okRows([ORG_ROW, OTHER_ORG_ROW]), ...orgDataRoutes() });
    await handleAdminUsageSummary(await staffRequest(ADMIN_PATH), ORG_ID, opts);
    await handleAdminUsageSummary(await staffRequest(`/v1/admin/orgs/${OTHER_ORG_ID}`), OTHER_ORG_ID, opts);
    const targets = stub.findAll('POST', 'audit_log').map((r) => (r.body as Array<{ target_id: string }>)[0].target_id);
    expect(targets).toEqual([ORG_ID, OTHER_ORG_ID]);
  });

  it('hands the write to waitUntil when the router provides it', async () => {
    const stub = stubSupabase(orgDataRoutes());
    const pending: Promise<unknown>[] = [];
    await handleAdminUsageSummary(await staffRequest(ADMIN_PATH), ORG_ID, { ...opts, waitUntil: (p) => { pending.push(p); } });
    expect(pending).toHaveLength(1);
    await Promise.all(pending);
    expect(stub.findAll('POST', 'audit_log')).toHaveLength(1);
  });

  it('still answers 200 when the audit insert fails', async () => {
    const errorSpy = vi.spyOn(console, 'error').mockImplementation(() => {});
    stubSupabase({ ...orgDataRoutes(), 'POST audit_log': httpError(500) });
    const res = await handleAdminUsageSummary(await staffRequest(ADMIN_PATH), ORG_ID, opts);
    expect(res.status).toBe(200);
    expect(errorSpy).toHaveBeenCalledWith(expect.stringContaining('[audit]'), 'admin.org_viewed', expect.anything());
  });
});
