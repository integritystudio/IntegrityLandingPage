import { describe, it, expect, vi, afterEach, beforeAll } from 'vitest';
import { handleMe } from './me';
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
import { resetIdentityRateLimit } from '../lib/rate-limit';

const opts = {
  ...TEST_AUTH0_OPTS,
  supabaseUrl: TEST_SUPABASE_URL,
  serviceRoleKey: TEST_SERVICE_ROLE_KEY,
};

let jwt: Auth0JwtFixture;

beforeAll(async () => {
  jwt = await createAuth0JwtFixture();
});

function makeRequest(token?: string): Request {
  return new Request('https://api.integritystudio.ai/v1/me', {
    method: 'GET',
    headers: token ? { authorization: `Bearer ${token}` } : {},
  });
}

/** Installs the stub as global fetch and returns it for assertions. */
function stubSupabase(routes: Record<string, RouteResponder>): SupabaseFetchStub {
  const stub = createSupabaseFetchStub(routes);
  vi.stubGlobal('fetch', jwt.wrap(stub.fetch));
  return stub;
}

const USER_SELECT = 'id, auth0_id, email, name, tier, created_at, default_organization_id';

const makeUserRow = (overrides: Record<string, unknown> = {}) => ({
  id: 'user-id-1',
  auth0_id: 'user-id-1',
  email: 'user@example.com',
  name: 'Test User',
  tier: 'starter',
  created_at: '2026-01-01T00:00:00Z',
  default_organization_id: null,
  ...overrides,
});

const makeOrgRow = (current_plan = 'growth') => ({ id: 'org-1', current_plan });

/** A user with no default org and no memberships: `tier` falls back to `users.tier`. */
const noOrgRoutes = (userOverrides: Record<string, unknown> = {}): Record<string, RouteResponder> => ({
  'GET users': okRows([makeUserRow(userOverrides)]),
  'GET organization_memberships': okRows([]),
});

interface MeBody {
  id: string;
  email: string;
  name: string | null;
  tier: string;
  created_at: string;
}

afterEach(() => {
  resetIdentityRateLimit();
  vi.unstubAllGlobals();
});

describe('GET /v1/me', () => {
  it('returns 401 when no bearer token', async () => {
    const stub = stubSupabase({});
    const res = await handleMe(makeRequest(), opts);
    expect(res.status).toBe(401);
    expect(stub.requests).toHaveLength(0);
  });

  it('returns 401 for expired jwt', async () => {
    const header = btoa(JSON.stringify({ alg: 'RS256', typ: 'JWT' }))
      .replace(/\+/g, '-').replace(/\//g, '_').replace(/=+$/, '');
    const body = btoa(JSON.stringify({ sub: 'user-1', email: 'a@b.com', exp: 1000000 }))
      .replace(/\+/g, '-').replace(/\//g, '_').replace(/=+$/, '');
    const expiredToken = `${header}.${body}.badsig`;
    const stub = stubSupabase({});
    const res = await handleMe(makeRequest(expiredToken), opts);
    expect(res.status).toBe(401);
    expect(stub.requests).toHaveLength(0);
  });

  it('returns 200 with user profile when jwt is valid and user exists', async () => {
    const token = await jwt.sign({ sub: 'user-id-1', email: 'user@example.com' });
    const stub = stubSupabase({
      'GET users': okRows([makeUserRow({ default_organization_id: 'org-1' })]),
      'GET organizations': okRows([makeOrgRow()]),
    });

    const res = await handleMe(makeRequest(token), opts);

    expect(res.status).toBe(200);
    const body = await res.json() as MeBody;
    expect(body.id).toBe('user-id-1');
    expect(body.email).toBe('user@example.com');
    expect(body.name).toBe('Test User');
    expect(stub.unexpected).toHaveLength(0);
  });

  it('looks the user up by auth0_id, selecting the profile columns, limit 1', async () => {
    const token = await jwt.sign({ sub: 'user-id-1', email: 'user@example.com' });
    const stub = stubSupabase(noOrgRoutes());

    await handleMe(makeRequest(token), opts);

    const lookup = stub.find('GET', 'users')!;
    expect(lookup.url.searchParams.get('auth0_id')).toBe('eq.user-id-1');
    expect(lookup.url.searchParams.get('select')).toBe(USER_SELECT);
    expect(lookup.url.searchParams.get('limit')).toBe('1');
    expect(lookup.headers['apikey']).toBe(TEST_SERVICE_ROLE_KEY);
  });

  // `users.tier` is the pre-organizations column and billing never updates it: the owner
  // of a paid growth org read `starter` here while api-keys-create minted growth keys.
  it('reports the default organization plan as tier, not users.tier', async () => {
    const token = await jwt.sign({ sub: 'user-id-1', email: 'user@example.com' });
    const stub = stubSupabase({
      'GET users': okRows([makeUserRow({ tier: 'starter', default_organization_id: 'org-1' })]),
      'GET organizations': okRows([makeOrgRow('growth')]),
    });

    const res = await handleMe(makeRequest(token), opts);

    expect(res.status).toBe(200);
    expect(((await res.json()) as MeBody).tier).toBe('growth');
    const org = stub.find('GET', 'organizations')!;
    expect(org.url.searchParams.get('id')).toBe('eq.org-1');
    expect(org.url.searchParams.get('select')).toBe('current_plan');
    expect(org.url.searchParams.get('limit')).toBe('1');
    expect(stub.find('GET', 'organization_memberships')).toBeUndefined();
    expect(stub.unexpected).toHaveLength(0);
  });

  it('falls back to the oldest active membership when there is no default organization', async () => {
    const token = await jwt.sign({ sub: 'user-id-1', email: 'user@example.com' });
    const stub = stubSupabase({
      'GET users': okRows([makeUserRow()]),
      'GET organization_memberships': okRows([{ organization_id: 'org-2' }]),
      'GET organizations': okRows([{ id: 'org-2', current_plan: 'enterprise' }]),
    });

    const res = await handleMe(makeRequest(token), opts);

    expect(((await res.json()) as MeBody).tier).toBe('enterprise');
    const membership = stub.find('GET', 'organization_memberships')!;
    expect(membership.url.searchParams.get('user_id')).toBe('eq.user-id-1');
    expect(membership.url.searchParams.get('status')).toBe('eq.active');
    expect(membership.url.searchParams.get('order')).toBe('created_at.asc');
    expect(membership.url.searchParams.get('limit')).toBe('1');
    expect(stub.find('GET', 'organizations')!.url.searchParams.get('id')).toBe('eq.org-2');
  });

  it('falls back to users.tier when the user has no active membership', async () => {
    const token = await jwt.sign({ sub: 'user-id-1', email: 'user@example.com' });
    stubSupabase(noOrgRoutes({ tier: 'starter' }));

    const res = await handleMe(makeRequest(token), opts);

    expect(res.status).toBe(200);
    expect(((await res.json()) as MeBody).tier).toBe('starter');
  });

  it('still answers 200 with users.tier when the organization lookup fails', async () => {
    const token = await jwt.sign({ sub: 'user-id-1', email: 'user@example.com' });
    const error = vi.spyOn(console, 'error').mockImplementation(() => {});
    stubSupabase({
      'GET users': okRows([makeUserRow({ tier: 'starter', default_organization_id: 'org-1' })]),
      'GET organizations': httpError(500, 'DB error'),
    });

    const res = await handleMe(makeRequest(token), opts);

    expect(res.status).toBe(200);
    expect(((await res.json()) as MeBody).tier).toBe('starter');
    expect(error).toHaveBeenCalledWith(expect.stringContaining('organization lookup failed'), 'org-1', expect.any(String));
    error.mockRestore();
  });

  it('returns 404 when user not found in db', async () => {
    const token = await jwt.sign({ sub: 'ghost-user', email: 'ghost@example.com' });
    const stub = stubSupabase({ 'GET users': okRows([]) });

    const res = await handleMe(makeRequest(token), opts);

    expect(res.status).toBe(404);
    expect(stub.find('GET', 'users')!.url.searchParams.get('auth0_id')).toBe('eq.ghost-user');
  });

  it('returns 500 when the user lookup fails', async () => {
    const token = await jwt.sign({ sub: 'user-id-1', email: 'user@example.com' });
    stubSupabase({ 'GET users': httpError(500, 'DB error') });

    const res = await handleMe(makeRequest(token), opts);

    expect(res.status).toBe(500);
  });

  it('omits db-only columns from the response body', async () => {
    const token = await jwt.sign({ sub: 'user-id-1', email: 'user@example.com' });
    stubSupabase(noOrgRoutes({ name: null }));

    const res = await handleMe(makeRequest(token), opts);

    expect(res.status).toBe(200);
    const body = await res.json() as Record<string, unknown>;
    expect(body).toEqual({
      id: 'user-id-1',
      email: 'user@example.com',
      name: null,
      tier: 'starter',
      created_at: '2026-01-01T00:00:00Z',
    });
    expect(body).not.toHaveProperty('auth0_id');
    expect(body).not.toHaveProperty('default_organization_id');
  });
});
