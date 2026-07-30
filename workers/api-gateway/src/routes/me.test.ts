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

const makeUserRow = (overrides: Record<string, unknown> = {}) => ({
  id: 'user-id-1',
  auth0_id: 'user-id-1',
  email: 'user@example.com',
  name: 'Test User',
  tier: 'starter',
  created_at: '2026-01-01T00:00:00Z',
  ...overrides,
});

interface MeBody {
  id: string;
  email: string;
  name: string | null;
  tier: string;
  created_at: string;
}

afterEach(() => {
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
    const stub = stubSupabase({ 'GET users': okRows([makeUserRow()]) });

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
    const stub = stubSupabase({ 'GET users': okRows([makeUserRow()]) });

    await handleMe(makeRequest(token), opts);

    const lookup = stub.find('GET', 'users')!;
    expect(stub.requests).toHaveLength(1);
    expect(lookup.url.searchParams.get('auth0_id')).toBe('eq.user-id-1');
    expect(lookup.url.searchParams.get('select')).toBe('id, auth0_id, email, name, tier, created_at');
    expect(lookup.url.searchParams.get('limit')).toBe('1');
    expect(lookup.headers['apikey']).toBe(TEST_SERVICE_ROLE_KEY);
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
    stubSupabase({ 'GET users': okRows([makeUserRow({ name: null })]) });

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
  });
});
