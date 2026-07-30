import { describe, it, expect, vi, afterEach, beforeAll, type Mock } from 'vitest';
import type Stripe from 'stripe';
import { handleListOrgs, handleOrgDashboard, handleOrgBillingStatus, handleBillingPortal } from './orgs';
import type { Entitlement, Organization, OrgMembership, OrgRole } from '../../../lib/types';
import {
  createSupabaseFetchStub,
  createdRows,
  okRows,
  TEST_SERVICE_ROLE_KEY,
  TEST_SUPABASE_URL,
  type RouteResponder,
  type SupabaseFetchStub,
} from '../../../lib/test-helpers/supabase-fetch-stub';
import { createAuth0JwtFixture, TEST_AUTH0_OPTS, type Auth0JwtFixture } from '../../../lib/test-helpers/auth0-jwt-stub';

const ORG_ID = 'org-id-1';
const OTHER_ORG_ID = 'org-id-2';
const AUTH0_SUB = 'auth0|test-subject';
const USER_ID = 'user-id-1';
const RETURN_URL = 'https://app.integritystudio.ai/#/billing';
const API_KEY_TOKEN = 'int_live_abc12345_0123456789abcdef';

const makeOrg = (overrides: Partial<Organization> = {}): Organization => ({
  id: ORG_ID,
  slug: 'test-org',
  name: 'Test Org',
  billing_status: 'active',
  current_plan: 'growth',
  quota_version: 1,
  ...overrides,
});

const makeMembership = (orgId = ORG_ID, role: OrgRole = 'owner'): OrgMembership => ({
  organization_id: orgId,
  user_id: USER_ID,
  role,
  status: 'active',
});

const opts = {
  ...TEST_AUTH0_OPTS,
  supabaseUrl: TEST_SUPABASE_URL,
  serviceRoleKey: TEST_SERVICE_ROLE_KEY,
};

/** Installs the stub as global fetch and returns it for assertions. */
function stubSupabase(routes: Record<string, RouteResponder>): SupabaseFetchStub {
  // Every authenticated route now translates the JWT sub to users.id, so stub that
  // lookup by default; a test overrides it to exercise the resolution failures.
  const stub = createSupabaseFetchStub({ 'GET users': okRows([{ id: USER_ID }]), ...routes });
  vi.stubGlobal('fetch', jwt.wrap(stub.fetch));
  return stub;
}

/** Every handler here starts by resolving the caller's active memberships. */
const membershipRoutes = (
  memberships: OrgMembership[] = [makeMembership()],
): Record<string, RouteResponder> => ({
  'GET organization_memberships': okRows(memberships),
});

const authedRequest = (path: string, token: string, method = 'GET') =>
  new Request(`https://api.test${path}`, {
    method,
    headers: { authorization: `Bearer ${token}` },
  });

let jwt: Auth0JwtFixture;

beforeAll(async () => {
  jwt = await createAuth0JwtFixture();
});

afterEach(() => {
  vi.unstubAllGlobals();
});

describe('GET /v1/orgs', () => {
  it('returns 401 when no bearer token', async () => {
    stubSupabase({});
    const req = new Request('https://api.test/v1/orgs', { method: 'GET' });
    const res = await handleListOrgs(req, opts);
    expect(res.status).toBe(401);
  });

  it('returns list of orgs the user belongs to', async () => {
    const token = await jwt.sign({ sub: AUTH0_SUB, email: 'u@test.com' });
    const stub = stubSupabase({
      ...membershipRoutes(),
      'GET organizations': okRows([makeOrg()]),
    });

    const res = await handleListOrgs(authedRequest('/v1/orgs', token), opts);
    expect(res.status).toBe(200);
    const body = await res.json() as { organizations: Array<Organization & { role: OrgRole }> };
    expect(body.organizations).toHaveLength(1);
    expect(body.organizations[0].id).toBe(ORG_ID);
    expect(body.organizations[0].role).toBe('owner');

    // The real client serializes the membership scoping into the query string.
    const params = stub.find('GET', 'organization_memberships')!.url.searchParams;
    expect(params.get('user_id')).toBe(`eq.${USER_ID}`);
    expect(params.get('status')).toBe('eq.active');
    expect(params.get('select')).toBe('organization_id, user_id, role, status');
  });

  it('passes org IDs as in-filter to DB query (H3)', async () => {
    const token = await jwt.sign({ sub: AUTH0_SUB, email: 'u@test.com' });
    const stub = stubSupabase({
      ...membershipRoutes([makeMembership(), makeMembership(OTHER_ORG_ID, 'admin')]),
      'GET organizations': okRows([makeOrg(), makeOrg({ id: OTHER_ORG_ID, slug: 'other-org' })]),
    });

    const res = await handleListOrgs(authedRequest('/v1/orgs', token), opts);

    // PostgREST `in` takes a parenthesised, comma-joined list — assert the wire format.
    const params = stub.find('GET', 'organizations')!.url.searchParams;
    expect(params.get('id')).toBe(`in.(${ORG_ID},${OTHER_ORG_ID})`);

    const body = await res.json() as { organizations: Array<Organization & { role: OrgRole }> };
    expect(body.organizations.map((o) => o.role)).toEqual(['owner', 'admin']);
  });

  it('returns empty list when user has no memberships', async () => {
    const token = await jwt.sign({ sub: AUTH0_SUB, email: 'u@test.com' });
    const stub = stubSupabase(membershipRoutes([]));
    const res = await handleListOrgs(authedRequest('/v1/orgs', token), opts);
    expect(res.status).toBe(200);
    const body = await res.json() as { organizations: unknown[] };
    expect(body.organizations).toEqual([]);
    // No memberships means the organizations table is never queried.
    expect(stub.find('GET', 'organizations')).toBeUndefined();
  });
});

describe('GET /v1/orgs/:orgId/dashboard', () => {
  it('returns 401 when no bearer token', async () => {
    stubSupabase({});
    const req = new Request(`https://api.test/v1/orgs/${ORG_ID}/dashboard`, { method: 'GET' });
    const res = await handleOrgDashboard(req, ORG_ID, opts);
    expect(res.status).toBe(401);
  });

  it('returns 403 when user is not a member of the org', async () => {
    const token = await jwt.sign({ sub: AUTH0_SUB, email: 'u@test.com' });
    stubSupabase(membershipRoutes([]));
    const req = authedRequest(`/v1/orgs/${ORG_ID}/dashboard`, token);
    const res = await handleOrgDashboard(req, ORG_ID, opts);
    expect(res.status).toBe(403);
  });

  it('returns dashboard summary when user is a member', async () => {
    const token = await jwt.sign({ sub: AUTH0_SUB, email: 'u@test.com' });
    const entitlements: Entitlement[] = [
      { organization_id: ORG_ID, feature_key: 'api_keys_max', enabled: true, hard_limit: 10, soft_limit: null },
    ];
    const stub = stubSupabase({
      ...membershipRoutes(),
      'GET organizations': okRows([makeOrg()]),
      'GET entitlements': okRows(entitlements),
    });

    const req = authedRequest(`/v1/orgs/${ORG_ID}/dashboard`, token);
    const res = await handleOrgDashboard(req, ORG_ID, opts);
    expect(res.status).toBe(200);
    const body = await res.json() as {
      org: Organization;
      role: OrgRole;
      entitlements: Record<string, boolean | number | null>;
    };
    expect(body.org.id).toBe(ORG_ID);
    expect(body.role).toBe('owner');
    expect(body.entitlements).toEqual({ api_keys_max: 10 });

    const orgParams = stub.find('GET', 'organizations')!.url.searchParams;
    expect(orgParams.get('id')).toBe(`eq.${ORG_ID}`);
    expect(orgParams.get('limit')).toBe('1');
    const entParams = stub.find('GET', 'entitlements')!.url.searchParams;
    expect(entParams.get('organization_id')).toBe(`eq.${ORG_ID}`);
  });
});

describe('GET /v1/orgs/:orgId/billing-status', () => {
  it('returns 403 when user is not a member', async () => {
    const token = await jwt.sign({ sub: AUTH0_SUB, email: 'u@test.com' });
    stubSupabase(membershipRoutes([]));
    const req = authedRequest(`/v1/orgs/${ORG_ID}/billing-status`, token);
    const res = await handleOrgBillingStatus(req, ORG_ID, opts);
    expect(res.status).toBe(403);
  });

  it('returns billing status for owner', async () => {
    const token = await jwt.sign({ sub: AUTH0_SUB, email: 'u@test.com' });
    const stub = stubSupabase({
      ...membershipRoutes(),
      'GET organizations': okRows([makeOrg({ billing_status: 'active', current_plan: 'growth' })]),
    });

    const req = authedRequest(`/v1/orgs/${ORG_ID}/billing-status`, token);
    const res = await handleOrgBillingStatus(req, ORG_ID, opts);
    expect(res.status).toBe(200);
    const body = await res.json() as {
      org_id: string;
      billing_status: string;
      current_plan: string;
      role: OrgRole;
    };
    expect(body.billing_status).toBe('active');
    expect(body.current_plan).toBe('growth');
    expect(body.org_id).toBe(ORG_ID);
    expect(body.role).toBe('owner');

    const params = stub.find('GET', 'organizations')!.url.searchParams;
    expect(params.get('select')).toBe('id, billing_status, current_plan, quota_version');
    expect(params.get('id')).toBe(`eq.${ORG_ID}`);
  });
});

const makePortalOpts = (stripeOverride?: Stripe) => ({
  ...opts,
  stripeSecretKey: 'sk_test_xxx',
  returnUrl: RETURN_URL,
  _stripeOverride: stripeOverride,
});

/** Minimal Stripe stand-in exposing only the billing-portal call the route uses. */
const stripeWith = (create: Mock): Stripe =>
  ({ billingPortal: { sessions: { create } } }) as unknown as Stripe;

const portalRoutes = (
  stripeCustomerId: string | null,
  memberships: OrgMembership[] = [makeMembership()],
): Record<string, RouteResponder> => ({
  ...membershipRoutes(memberships),
  'GET organizations': okRows([{ id: ORG_ID, stripe_customer_id: stripeCustomerId }]),
  'POST audit_log': createdRows([]),
});

describe('POST /v1/orgs/:id/billing-portal', () => {
  it('returns 401 when no bearer token', async () => {
    stubSupabase({});
    const req = new Request(`https://api.test/v1/orgs/${ORG_ID}/billing-portal`, { method: 'POST' });
    const res = await handleBillingPortal(req, ORG_ID, makePortalOpts());
    expect(res.status).toBe(401);
  });

  it('returns 403 for an API key token rather than an opaque 401', async () => {
    stubSupabase({});
    const req = authedRequest(`/v1/orgs/${ORG_ID}/billing-portal`, API_KEY_TOKEN, 'POST');
    const res = await handleBillingPortal(req, ORG_ID, makePortalOpts());
    expect(res.status).toBe(403);
    const body = await res.json() as { error: { message: string } };
    expect(body.error.message).toContain('API keys are not accepted');
  });

  it('returns 403 when user is not a member', async () => {
    const token = await jwt.sign({ sub: AUTH0_SUB, email: 'u@test.com' });
    stubSupabase(membershipRoutes([]));
    const req = authedRequest(`/v1/orgs/${ORG_ID}/billing-portal`, token, 'POST');
    const res = await handleBillingPortal(req, ORG_ID, makePortalOpts());
    expect(res.status).toBe(403);
  });

  it('returns 403 when user role is not owner or billing_admin', async () => {
    const token = await jwt.sign({ sub: AUTH0_SUB, email: 'u@test.com' });
    stubSupabase(membershipRoutes([makeMembership(ORG_ID, 'member')]));
    const req = authedRequest(`/v1/orgs/${ORG_ID}/billing-portal`, token, 'POST');
    const res = await handleBillingPortal(req, ORG_ID, makePortalOpts());
    expect(res.status).toBe(403);
  });

  it('returns 404 when org has no stripe_customer_id', async () => {
    const token = await jwt.sign({ sub: AUTH0_SUB, email: 'u@test.com' });
    stubSupabase(portalRoutes(null));
    const req = authedRequest(`/v1/orgs/${ORG_ID}/billing-portal`, token, 'POST');
    const res = await handleBillingPortal(req, ORG_ID, makePortalOpts());
    expect(res.status).toBe(404);
  });

  it('returns 500 when stripe_customer_id has invalid format (H4)', async () => {
    const token = await jwt.sign({ sub: AUTH0_SUB, email: 'u@test.com' });
    stubSupabase(portalRoutes('invalid-id'));
    const req = authedRequest(`/v1/orgs/${ORG_ID}/billing-portal`, token, 'POST');
    const res = await handleBillingPortal(req, ORG_ID, makePortalOpts());
    expect(res.status).toBe(500);
  });

  it('returns portal URL for owner with stripe customer', async () => {
    const token = await jwt.sign({ sub: AUTH0_SUB, email: 'u@test.com' });
    const stub = stubSupabase(portalRoutes('cus_123'));
    const create = vi.fn().mockResolvedValue({ url: 'https://billing.stripe.com/session/xxx' });

    const req = authedRequest(`/v1/orgs/${ORG_ID}/billing-portal`, token, 'POST');
    const res = await handleBillingPortal(req, ORG_ID, makePortalOpts(stripeWith(create)));
    expect(res.status).toBe(200);
    const body = await res.json() as { url: string };
    expect(body.url).toBe('https://billing.stripe.com/session/xxx');
    expect(create).toHaveBeenCalledWith({
      customer: 'cus_123',
      return_url: RETURN_URL,
    });

    // Audit log written exactly once after successful portal session creation
    const audits = stub.findAll('POST', 'audit_log');
    expect(audits).toHaveLength(1);
    expect(audits[0].headers['prefer']).toBe('return=representation');
    expect(audits[0].body).toEqual([
      expect.objectContaining({
        organization_id: ORG_ID,
        action: 'billing_portal.accessed',
        target_type: 'org',
        target_id: ORG_ID,
        metadata: { actor_auth0_id: AUTH0_SUB },
      }),
    ]);
  });

  it('returns portal URL for billing_admin role', async () => {
    const token = await jwt.sign({ sub: AUTH0_SUB, email: 'u@test.com' });
    const stub = stubSupabase(portalRoutes('cus_456', [makeMembership(ORG_ID, 'billing_admin')]));
    const create = vi.fn().mockResolvedValue({ url: 'https://billing.stripe.com/session/yyy' });

    const req = authedRequest(`/v1/orgs/${ORG_ID}/billing-portal`, token, 'POST');
    const res = await handleBillingPortal(req, ORG_ID, makePortalOpts(stripeWith(create)));
    expect(res.status).toBe(200);
    const body = await res.json() as { url: string };
    expect(body.url).toBe('https://billing.stripe.com/session/yyy');
    expect(create).toHaveBeenCalledWith({
      customer: 'cus_456',
      return_url: RETURN_URL,
    });

    // Audit log written exactly once on billing_admin path
    const audits = stub.findAll('POST', 'audit_log');
    expect(audits).toHaveLength(1);
    expect(audits[0].body).toEqual([
      expect.objectContaining({
        action: 'billing_portal.accessed',
        target_type: 'org',
        target_id: ORG_ID,
      }),
    ]);
  });

  it('returns 500 when Stripe throws', async () => {
    const token = await jwt.sign({ sub: AUTH0_SUB, email: 'u@test.com' });
    const stub = stubSupabase(portalRoutes('cus_123'));
    const create = vi.fn().mockRejectedValue(new Error('Stripe API error'));

    const req = authedRequest(`/v1/orgs/${ORG_ID}/billing-portal`, token, 'POST');
    const res = await handleBillingPortal(req, ORG_ID, makePortalOpts(stripeWith(create)));
    expect(res.status).toBe(500);
    expect(stub.findAll('POST', 'audit_log')).toHaveLength(0);
  });
});
