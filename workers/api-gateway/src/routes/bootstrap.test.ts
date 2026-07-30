import { describe, it, expect, vi, afterEach, beforeAll } from 'vitest';
import { handleBootstrap } from './bootstrap';
import {
  createSupabaseFetchStub,
  httpError,
  okRows,
  TEST_SERVICE_ROLE_KEY,
  TEST_SUPABASE_URL,
  type RouteResponder,
  type SupabaseFetchStub,
} from '../../../lib/test-helpers/supabase-fetch-stub';
import { createAuth0JwtFixture, TEST_AUTH0_OPTS, type Auth0JwtFixture } from '../../../lib/test-helpers/auth0-jwt-stub';

const opts = {
  ...TEST_AUTH0_OPTS,
  supabaseUrl: TEST_SUPABASE_URL,
  serviceRoleKey: TEST_SERVICE_ROLE_KEY,
};

let jwt: Auth0JwtFixture;

beforeAll(async () => {
  jwt = await createAuth0JwtFixture();
});

function makeRequest(token?: string, orgId?: string): Request {
  const headers: Record<string, string> = {};
  if (token) headers['authorization'] = `Bearer ${token}`;
  if (orgId) headers['x-org-id'] = orgId;
  return new Request('https://api.integritystudio.ai/bootstrap', { method: 'POST', headers });
}

function stubSupabase(routes: Record<string, RouteResponder>): SupabaseFetchStub {
  const stub = createSupabaseFetchStub(routes);
  vi.stubGlobal('fetch', jwt.wrap(stub.fetch));
  return stub;
}

const makeUserRow = (overrides: Record<string, unknown> = {}) => ({
  id: 'user-uuid-1',
  email: 'user@example.com',
  ...overrides,
});

const makeOrgRow = (overrides: Record<string, unknown> = {}) => ({
  id: 'org-1',
  slug: 'acme',
  name: 'Acme',
  billing_status: 'active',
  current_plan: 'starter',
  quota_version: 1,
  ...overrides,
});

const makeMembershipRow = (overrides: Record<string, unknown> = {}) => ({
  organization_id: 'org-1',
  role: 'owner',
  ...overrides,
});

const makeEntitlementRow = (overrides: Record<string, unknown> = {}) => ({
  organization_id: 'org-1',
  feature_key: 'some_feature',
  enabled: true,
  hard_limit: null,
  soft_limit: null,
  ...overrides,
});

const makeUsageBucketRow = (overrides: Record<string, unknown> = {}) => ({
  total_quantity: 42,
  ...overrides,
});

afterEach(() => {
  vi.unstubAllGlobals();
});

describe('POST /bootstrap', () => {
  it('returns 401 when no bearer token', async () => {
    const stub = stubSupabase({});
    const res = await handleBootstrap(makeRequest(), opts);
    expect(res.status).toBe(401);
    expect(stub.requests).toHaveLength(0);
  });

  it('returns 401 for an expired jwt', async () => {
    const header = btoa(JSON.stringify({ alg: 'RS256', typ: 'JWT' }))
      .replace(/\+/g, '-').replace(/\//g, '_').replace(/=+$/, '');
    const body = btoa(JSON.stringify({ sub: 'auth0|u', email: 'a@b.com', exp: 1000000 }))
      .replace(/\+/g, '-').replace(/\//g, '_').replace(/=+$/, '');
    const stub = stubSupabase({});
    const res = await handleBootstrap(makeRequest(`${header}.${body}.badsig`), opts);
    expect(res.status).toBe(401);
    expect(stub.requests).toHaveLength(0);
  });

  it('returns 401 when the user row does not exist', async () => {
    const token = await jwt.sign({ sub: 'auth0|ghost', email: 'ghost@example.com' });
    const stub = stubSupabase({
      'GET users': okRows([]),
    });
    const res = await handleBootstrap(makeRequest(token), opts);
    expect(res.status).toBe(401);
    expect(stub.find('GET', 'users')?.url.searchParams.get('auth0_id')).toBe('eq.auth0|ghost');
  });

  it('returns 404 when user has no active memberships', async () => {
    const token = await jwt.sign({ sub: 'auth0|u1', email: 'u@example.com' });
    stubSupabase({
      'GET users': okRows([makeUserRow()]),
      'GET organization_memberships': okRows([]),
    });
    const res = await handleBootstrap(makeRequest(token), opts);
    expect(res.status).toBe(404);
  });

  it('returns 500 when membership query fails', async () => {
    const token = await jwt.sign({ sub: 'auth0|u1', email: 'u@example.com' });
    stubSupabase({
      'GET users': okRows([makeUserRow()]),
      'GET organization_memberships': httpError(500, 'DB error'),
    });
    const res = await handleBootstrap(makeRequest(token), opts);
    expect(res.status).toBe(500);
  });

  it('returns 404 when membership rows exist but no matching org rows', async () => {
    const token = await jwt.sign({ sub: 'auth0|u1', email: 'u@example.com' });
    stubSupabase({
      'GET users': okRows([makeUserRow()]),
      'GET organization_memberships': okRows([makeMembershipRow({ organization_id: 'org-999' })]),
      'GET organizations': okRows([]),
    });
    const res = await handleBootstrap(makeRequest(token), opts);
    expect(res.status).toBe(404);
  });

  it('returns 200 with bootstrap payload for a valid token', async () => {
    const token = await jwt.sign({ sub: 'auth0|u1', email: 'user@example.com' });
    stubSupabase({
      'GET users': okRows([makeUserRow()]),
      'GET organization_memberships': okRows([makeMembershipRow()]),
      'GET organizations': okRows([makeOrgRow()]),
      'GET entitlements': okRows([makeEntitlementRow()]),
      'GET usage_buckets_daily': okRows([makeUsageBucketRow()]),
    });
    const res = await handleBootstrap(makeRequest(token), opts);
    expect(res.status).toBe(200);
    const body = (await res.json()) as Record<string, unknown>;
    expect(body).toHaveProperty('user');
    expect(body).toHaveProperty('organizations');
    expect(body).toHaveProperty('active_org_id');
    expect(body).toHaveProperty('entitlements');
    expect(body).toHaveProperty('usage_snapshot');
  });

  // Both fields come from the users row, not the token. A real Auth0 access token for a
  // custom audience carries no `email` claim even with `email` in scope, so sourcing it from
  // the JWT shipped a permanently blank address; and `id` must mean the same thing here as
  // it does in GET /v1/me, which returns users.id. Note the token below deliberately carries
  // no email claim — signing one that does would only re-test a token Auth0 never issues.
  it('sets user.id and user.email from the users row, not the JWT', async () => {
    const token = await jwt.sign({ sub: 'auth0|u1' });
    stubSupabase({
      'GET users': okRows([makeUserRow()]),
      'GET organization_memberships': okRows([makeMembershipRow()]),
      'GET organizations': okRows([makeOrgRow()]),
      'GET entitlements': okRows([]),
      'GET usage_buckets_daily': okRows([]),
    });
    const res = await handleBootstrap(makeRequest(token), opts);
    expect(res.status).toBe(200);
    const body = (await res.json()) as { user: { id: string; email: string } };
    expect(body.user.id).toBe('user-uuid-1');
    expect(body.user.id).not.toBe('auth0|u1');
    expect(body.user.email).toBe('user@example.com');
  });

  it('reports the users-row email even when the token does carry an email claim', async () => {
    const token = await jwt.sign({ sub: 'auth0|u1', email: 'stale-token-email@example.com' });
    stubSupabase({
      'GET users': okRows([makeUserRow({ email: 'canonical@example.com' })]),
      'GET organization_memberships': okRows([makeMembershipRow()]),
      'GET organizations': okRows([makeOrgRow()]),
      'GET entitlements': okRows([]),
      'GET usage_buckets_daily': okRows([]),
    });
    const res = await handleBootstrap(makeRequest(token), opts);
    const body = (await res.json()) as { user: { email: string } };
    expect(body.user.email).toBe('canonical@example.com');
  });

  it('resolves userId via auth0_id, not using sub directly for membership lookup', async () => {
    const token = await jwt.sign({ sub: 'auth0|u1', email: 'user@example.com' });
    const stub = stubSupabase({
      'GET users': okRows([makeUserRow({ id: 'user-uuid-1' })]),
      'GET organization_memberships': okRows([makeMembershipRow()]),
      'GET organizations': okRows([makeOrgRow()]),
      'GET entitlements': okRows([]),
      'GET usage_buckets_daily': okRows([]),
    });
    await handleBootstrap(makeRequest(token), opts);
    const membershipReq = stub.find('GET', 'organization_memberships')!;
    // Must filter by the internal UUID (users.id), not the Auth0 sub.
    expect(membershipReq.url.searchParams.get('user_id')).toBe('eq.user-uuid-1');
  });

  it('respects x-org-id header to select the active org', async () => {
    const token = await jwt.sign({ sub: 'auth0|u1', email: 'user@example.com' });
    stubSupabase({
      'GET users': okRows([makeUserRow()]),
      'GET organization_memberships': okRows([
        makeMembershipRow({ organization_id: 'org-1' }),
        makeMembershipRow({ organization_id: 'org-2', role: 'member' }),
      ]),
      'GET organizations': okRows([makeOrgRow(), makeOrgRow({ id: 'org-2', slug: 'other', name: 'Other' })]),
      'GET entitlements': okRows([]),
      'GET usage_buckets_daily': okRows([]),
    });
    const res = await handleBootstrap(makeRequest(token, 'org-2'), opts);
    expect(res.status).toBe(200);
    const body = (await res.json()) as { active_org_id: string };
    expect(body.active_org_id).toBe('org-2');
  });

  // x-org-id is caller-controlled, so this is an access-control boundary, not a preference.
  // The header is only honoured if it names an org the caller is actually a member of;
  // anything else silently falls back rather than being trusted. Without this test a
  // refactor that "fixed" the fallback by taking the header at face value would still pass.
  it('ignores an x-org-id naming an org the caller is not a member of', async () => {
    const token = await jwt.sign({ sub: 'auth0|u1' });
    const stub = stubSupabase({
      'GET users': okRows([makeUserRow()]),
      'GET organization_memberships': okRows([makeMembershipRow({ organization_id: 'org-1' })]),
      'GET organizations': okRows([makeOrgRow({ id: 'org-1' })]),
      'GET entitlements': okRows([]),
      'GET usage_buckets_daily': okRows([]),
    });

    const res = await handleBootstrap(makeRequest(token, 'org-someone-else'), opts);

    expect(res.status).toBe(200);
    const body = (await res.json()) as {
      active_org_id: string;
      organizations: { id: string }[];
    };
    // Falls back to the caller's own org; the foreign id is neither active nor listed.
    expect(body.active_org_id).toBe('org-1');
    expect(body.organizations.map((o) => o.id)).toEqual(['org-1']);

    // The foreign id must never reach the database as a filter value.
    const orgQuery = stub.find('GET', 'organizations')!;
    expect(orgQuery.url.searchParams.get('id')).toBe('in.(org-1)');
    expect(orgQuery.url.toString()).not.toContain('org-someone-else');
  });

  // Entitlements and usage are loaded for the *active* org, so an ignored x-org-id must not
  // leak another org's data into those two payload fields either.
  it('scopes entitlements and usage to the fallback org when x-org-id is foreign', async () => {
    const token = await jwt.sign({ sub: 'auth0|u1' });
    const stub = stubSupabase({
      'GET users': okRows([makeUserRow()]),
      'GET organization_memberships': okRows([makeMembershipRow({ organization_id: 'org-1' })]),
      'GET organizations': okRows([makeOrgRow({ id: 'org-1' })]),
      'GET entitlements': okRows([]),
      'GET usage_buckets_daily': okRows([]),
    });

    await handleBootstrap(makeRequest(token, 'org-someone-else'), opts);

    expect(stub.find('GET', 'entitlements')!.url.searchParams.get('organization_id')).toBe('eq.org-1');
    expect(stub.find('GET', 'usage_buckets_daily')!.url.searchParams.get('organization_id')).toBe('eq.org-1');
  });

  it('falls back to the first org when x-org-id is absent', async () => {
    const token = await jwt.sign({ sub: 'auth0|u1', email: 'user@example.com' });
    stubSupabase({
      'GET users': okRows([makeUserRow()]),
      'GET organization_memberships': okRows([makeMembershipRow()]),
      'GET organizations': okRows([makeOrgRow()]),
      'GET entitlements': okRows([]),
      'GET usage_buckets_daily': okRows([]),
    });
    const res = await handleBootstrap(makeRequest(token), opts);
    expect(res.status).toBe(200);
    const body = (await res.json()) as { active_org_id: string };
    expect(body.active_org_id).toBe('org-1');
  });

  it('sums usage_buckets_daily total_quantity for month_to_date_units', async () => {
    const token = await jwt.sign({ sub: 'auth0|u1', email: 'user@example.com' });
    stubSupabase({
      'GET users': okRows([makeUserRow()]),
      'GET organization_memberships': okRows([makeMembershipRow()]),
      'GET organizations': okRows([makeOrgRow()]),
      'GET entitlements': okRows([]),
      'GET usage_buckets_daily': okRows([
        makeUsageBucketRow({ total_quantity: 10 }),
        makeUsageBucketRow({ total_quantity: 25 }),
      ]),
    });
    const res = await handleBootstrap(makeRequest(token), opts);
    expect(res.status).toBe(200);
    const body = (await res.json()) as { usage_snapshot: { month_to_date_units: number } };
    expect(body.usage_snapshot.month_to_date_units).toBe(35);
  });

  it('returns current_minute_remaining as null in the usage snapshot', async () => {
    const token = await jwt.sign({ sub: 'auth0|u1', email: 'user@example.com' });
    stubSupabase({
      'GET users': okRows([makeUserRow()]),
      'GET organization_memberships': okRows([makeMembershipRow()]),
      'GET organizations': okRows([makeOrgRow()]),
      'GET entitlements': okRows([]),
      'GET usage_buckets_daily': okRows([]),
    });
    const res = await handleBootstrap(makeRequest(token), opts);
    const body = (await res.json()) as { usage_snapshot: { current_minute_remaining: unknown } };
    expect(body.usage_snapshot.current_minute_remaining).toBeNull();
  });

  it('returns 500 when entitlements query fails', async () => {
    const token = await jwt.sign({ sub: 'auth0|u1', email: 'user@example.com' });
    stubSupabase({
      'GET users': okRows([makeUserRow()]),
      'GET organization_memberships': okRows([makeMembershipRow()]),
      'GET organizations': okRows([makeOrgRow()]),
      'GET entitlements': httpError(500, 'DB error'),
      'GET usage_buckets_daily': okRows([]),
    });
    const res = await handleBootstrap(makeRequest(token), opts);
    expect(res.status).toBe(500);
  });

  it('queries organizations with an `in` filter over the membership org IDs', async () => {
    const token = await jwt.sign({ sub: 'auth0|u1', email: 'user@example.com' });
    const stub = stubSupabase({
      'GET users': okRows([makeUserRow()]),
      'GET organization_memberships': okRows([makeMembershipRow()]),
      'GET organizations': okRows([makeOrgRow()]),
      'GET entitlements': okRows([]),
      'GET usage_buckets_daily': okRows([]),
    });
    await handleBootstrap(makeRequest(token), opts);
    const orgsReq = stub.find('GET', 'organizations')!;
    // Must use `in` filter rather than fetching all orgs.
    expect(orgsReq.url.searchParams.get('id')).toMatch(/^in\./);
  });
});
