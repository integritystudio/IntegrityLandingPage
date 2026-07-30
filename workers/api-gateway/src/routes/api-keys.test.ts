import { describe, it, expect, vi, afterEach, beforeAll } from 'vitest';
import { handleCreateApiKey, handleRevokeApiKey } from './api-keys';
import { hashApiKeySecret, parseApiKey, API_KEY_REGEX } from '../../../lib/api-keys';
import {
  createSupabaseFetchStub,
  createdRows,
  httpError,
  noContent,
  okRows,
  updatedRows,
  TEST_SERVICE_ROLE_KEY,
  TEST_SUPABASE_URL,
  type RouteResponder,
  type SupabaseFetchStub,
} from '../../../lib/test-helpers/supabase-fetch-stub';
import { createAuth0JwtFixture, TEST_AUTH0_OPTS, type Auth0JwtFixture } from '../../../lib/test-helpers/auth0-jwt-stub';

const HMAC_SECRET = 'test-hmac-secret-at-least-32-chars!';

const ORG_ID = 'org-id-1';
const AUTH0_SUB = 'auth0|test-subject';
const USER_ID = 'user-id-1';
const KEY_ID = 'key-id';
const REVOKED_AT = '2026-03-20T00:00:00Z';

const opts = {
  ...TEST_AUTH0_OPTS,
  hmacSecret: HMAC_SECRET,
  supabaseUrl: TEST_SUPABASE_URL,
  serviceRoleKey: TEST_SERVICE_ROLE_KEY,
};

/** Installs the stub as global fetch and returns it for assertions. */
function stubSupabase(routes: Record<string, RouteResponder>): SupabaseFetchStub {
  const stub = createSupabaseFetchStub(routes);
  vi.stubGlobal('fetch', jwt.wrap(stub.fetch));
  return stub;
}

const makeMembership = (orgId = ORG_ID, role = 'owner') => ({
  organization_id: orgId,
  user_id: USER_ID,
  role,
  status: 'active',
});

const makeUser = () => ({
  id: USER_ID,
  auth0_id: USER_ID,
  email: 'user@test.com',
});

const makeInsertedKey = () => ({
  id: 'new-key-id',
  prefix: 'WILLBESET',
  user_id: USER_ID,
  organization_id: ORG_ID,
  created_at: '2026-03-19T00:00:00Z',
});

const makeExistingKey = () => ({
  id: KEY_ID,
  organization_id: ORG_ID,
  user_id: USER_ID,
  status: 'active',
  revoked_at: null,
});

const REPRESENTATION_PREFER = 'return=representation';
const CREATED_STATUS = 201;

/**
 * PostgREST returns the inserted rows only when the request asked for them via
 * the `Prefer` header; a `returning` query param is ignored and the response
 * comes back bodiless. Modelling that here means the whole create path — not
 * just the header assertion — fails if the client ever regresses.
 */
const preferAwareInsert = (rows: unknown[]): RouteResponder => (request) =>
  request.headers['prefer'] === REPRESENTATION_PREFER
    ? new Response(JSON.stringify(rows), {
      status: CREATED_STATUS,
      headers: { 'content-type': 'application/json' },
    })
    : new Response(null, { status: CREATED_STATUS });

/** Membership lookup + user lookup + key insert + audit log — the create happy path. */
const createRoutes = (
  overrides: Record<string, RouteResponder> = {},
): Record<string, RouteResponder> => ({
  'GET organization_memberships': okRows([makeMembership()]),
  'GET users': okRows([makeUser()]),
  'POST api_keys': preferAwareInsert([makeInsertedKey()]),
  'POST audit_log': createdRows([{ id: 'audit-1' }]),
  ...overrides,
});

/** Membership lookup + key lookup + key update + audit log — the revoke happy path. */
const revokeRoutes = (
  overrides: Record<string, RouteResponder> = {},
): Record<string, RouteResponder> => ({
  'GET organization_memberships': okRows([makeMembership()]),
  'GET users': okRows([makeUser()]),
  'GET api_keys': okRows([makeExistingKey()]),
  'PATCH api_keys': updatedRows([{ ...makeExistingKey(), status: 'revoked', revoked_at: REVOKED_AT }]),
  'POST audit_log': createdRows([{ id: 'audit-1' }]),
  ...overrides,
});

const makeCreateRequest = (token: string, body: Record<string, unknown> = { name: 'My Key' }) =>
  new Request('https://api.test/v1/orgs/org-id-1/api-keys', {
    method: 'POST',
    headers: { authorization: `Bearer ${token}`, 'content-type': 'application/json' },
    body: JSON.stringify(body),
  });

const makeRevokeRequest = (token: string) =>
  new Request('https://api.test/v1/orgs/org-id-1/api-keys/key-id/revoke', {
    method: 'POST',
    headers: { authorization: `Bearer ${token}` },
  });

interface CreateApiKeyResponse {
  id: string;
  name: string;
  prefix: string;
  tier: string;
  status: string;
  expires_at: string | null;
  created_at: string;
  token: string;
  hash?: unknown;
}

interface RevokeApiKeyResponse {
  id: string;
  status: string;
  revoked_at: string;
}

let jwt: Auth0JwtFixture;

beforeAll(async () => {
  jwt = await createAuth0JwtFixture();
});

afterEach(() => {
  vi.unstubAllGlobals();
});

describe('POST /v1/orgs/:orgId/api-keys', () => {
  it('returns 401 when no bearer token', async () => {
    const stub = stubSupabase({});
    const req = new Request('https://api.test/v1/orgs/org-id-1/api-keys', { method: 'POST' });
    const res = await handleCreateApiKey(req, ORG_ID, opts);
    expect(res.status).toBe(401);
    // Auth is rejected before any Supabase traffic is issued.
    expect(stub.requests).toEqual([]);
  });

  it('returns 403 when user is not a member', async () => {
    const token = await jwt.sign({ sub: AUTH0_SUB, email: 'u@test.com' });
    const stub = stubSupabase(createRoutes({ 'GET organization_memberships': okRows([]) }));
    const res = await handleCreateApiKey(makeCreateRequest(token), ORG_ID, opts);
    expect(res.status).toBe(403);
    // No key is minted when membership fails.
    expect(stub.find('POST', 'api_keys')).toBeUndefined();
  });

  it('returns 403 when user role is viewer', async () => {
    const token = await jwt.sign({ sub: AUTH0_SUB, email: 'u@test.com' });
    const stub = stubSupabase(createRoutes({
      'GET organization_memberships': okRows([makeMembership(ORG_ID, 'viewer')]),
    }));
    const res = await handleCreateApiKey(makeCreateRequest(token), ORG_ID, opts);
    expect(res.status).toBe(403);
    expect(stub.find('POST', 'api_keys')).toBeUndefined();
  });

  it('returns 403 when user role is billing_admin', async () => {
    const token = await jwt.sign({ sub: AUTH0_SUB, email: 'u@test.com' });
    const stub = stubSupabase(createRoutes({
      'GET organization_memberships': okRows([makeMembership(ORG_ID, 'billing_admin')]),
    }));
    const res = await handleCreateApiKey(makeCreateRequest(token), ORG_ID, opts);
    expect(res.status).toBe(403);
    expect(stub.find('POST', 'api_keys')).toBeUndefined();
  });

  it('scopes the membership lookup to the user, org, and active status', async () => {
    const token = await jwt.sign({ sub: AUTH0_SUB, email: 'u@test.com' });
    const stub = stubSupabase(createRoutes());
    await handleCreateApiKey(makeCreateRequest(token), ORG_ID, opts);

    const params = stub.find('GET', 'organization_memberships')!.url.searchParams;
    expect(params.get('user_id')).toBe(`eq.${USER_ID}`);
    expect(params.get('organization_id')).toBe(`eq.${ORG_ID}`);
    expect(params.get('status')).toBe('eq.active');
    expect(params.get('limit')).toBe('1');
  });

  it('returns 404 when the JWT subject has no users row', async () => {
    const token = await jwt.sign({ sub: AUTH0_SUB, email: 'u@test.com' });
    const stub = stubSupabase(createRoutes({ 'GET users': okRows([]) }));
    const res = await handleCreateApiKey(makeCreateRequest(token), ORG_ID, opts);
    expect(res.status).toBe(404);
    expect(stub.find('GET', 'users')!.url.searchParams.get('auth0_id')).toBe(`eq.${AUTH0_SUB}`);
    expect(stub.find('POST', 'api_keys')).toBeUndefined();
  });

  it('creates an API key for an org member and returns the token once', async () => {
    const token = await jwt.sign({ sub: AUTH0_SUB, email: 'u@test.com' });
    const stub = stubSupabase(createRoutes());

    const res = await handleCreateApiKey(
      makeCreateRequest(token, { name: 'CI Key' }), ORG_ID, opts,
    );
    expect(res.status).toBe(201);
    const body = await res.json() as CreateApiKeyResponse;
    // Token must match the API key format
    expect(body.token).toMatch(API_KEY_REGEX);
    expect(body.id).toBe('new-key-id');
    expect(body.name).toBe('CI Key');
    // Hash is NOT returned — only the token (shown once)
    expect(body.hash).toBeUndefined();
    // The row that actually went over the wire, with the columns PostgREST receives.
    const insert = stub.find('POST', 'api_keys')!;
    expect(insert.body).toEqual([
      expect.objectContaining({
        user_id: USER_ID,
        organization_id: ORG_ID,
        prefix: body.prefix,
        name: 'CI Key',
        tier: 'starter',
        status: 'active',
        expires_at: null,
      }),
    ]);
    // Audit log written: first call is membership check, second is user lookup, third is audit_log insert
    expect(stub.find('POST', 'audit_log')!.body).toEqual([
      expect.objectContaining({
        action: 'api_key.created',
        target_type: 'api_key',
        target_id: 'new-key-id',
        actor_user_id: USER_ID,
        organization_id: ORG_ID,
      }),
    ]);
  });

  it('asks PostgREST for the inserted row via the Prefer header, not a query param', async () => {
    const token = await jwt.sign({ sub: AUTH0_SUB, email: 'u@test.com' });
    const stub = stubSupabase(createRoutes());

    const res = await handleCreateApiKey(makeCreateRequest(token), ORG_ID, opts);
    expect(res.status).toBe(201);

    const insert = stub.find('POST', 'api_keys')!;
    // Regression guard: `returning` as a query param is silently ignored by
    // PostgREST, so the insert succeeds but comes back without rows and the
    // route 500s after already writing the key.
    expect(insert.headers['prefer']).toBe('return=representation');
    expect(insert.url.searchParams.get('returning')).toBeNull();
  });

  it('returns 500 when the insert succeeds but returns no representation', async () => {
    const token = await jwt.sign({ sub: AUTH0_SUB, email: 'u@test.com' });
    const stub = stubSupabase(createRoutes({ 'POST api_keys': noContent() }));

    const res = await handleCreateApiKey(makeCreateRequest(token), ORG_ID, opts);
    expect(res.status).toBe(500);
    // The write happened — this is the shape of the shipped Prefer-header bug.
    expect(stub.find('POST', 'api_keys')).toBeDefined();
    expect(stub.find('POST', 'audit_log')).toBeUndefined();
  });

  it('returns 500 when the key insert fails', async () => {
    const token = await jwt.sign({ sub: AUTH0_SUB, email: 'u@test.com' });
    stubSupabase(createRoutes({ 'POST api_keys': httpError(500, 'DB error') }));
    const res = await handleCreateApiKey(makeCreateRequest(token), ORG_ID, opts);
    expect(res.status).toBe(500);
  });

  it('stores an HMAC hash of the secret, never the secret itself', async () => {
    const token = await jwt.sign({ sub: AUTH0_SUB, email: 'u@test.com' });
    const stub = stubSupabase(createRoutes());

    const res = await handleCreateApiKey(makeCreateRequest(token), ORG_ID, opts);
    const body = await res.json() as CreateApiKeyResponse;
    const parsed = parseApiKey(body.token);
    expect(parsed.ok).toBe(true);
    if (!parsed.ok) return;

    const [row] = stub.find('POST', 'api_keys')!.body as Array<{ hash: string; prefix: string }>;
    expect(row.prefix).toBe(parsed.prefix);
    expect(row.hash).toBe(await hashApiKeySecret(parsed.secret, HMAC_SECRET));
    expect(row.hash).not.toContain(parsed.secret);
  });

  it('writes audit log even when audit insert fails, and still returns 201', async () => {
    const token = await jwt.sign({ sub: AUTH0_SUB, email: 'u@test.com' });
    const stub = stubSupabase(createRoutes({ 'POST audit_log': httpError(500, 'db error') }));

    const res = await handleCreateApiKey(
      makeCreateRequest(token, { name: 'CI Key' }), ORG_ID, opts,
    );
    expect(res.status).toBe(201);
    // The audit write was attempted; its failure is swallowed.
    expect(stub.find('POST', 'audit_log')).toBeDefined();
  });

  it('accepts optional expires_at for key creation', async () => {
    const token = await jwt.sign({ sub: AUTH0_SUB, email: 'u@test.com' });
    const stub = stubSupabase(createRoutes());
    const res = await handleCreateApiKey(
      makeCreateRequest(token, { name: 'Expiring Key', expires_at: '2027-01-01T00:00:00Z' }),
      ORG_ID,
      opts,
    );
    expect(res.status).toBe(201);
    // Verify insert was called with expires_at
    expect(stub.find('POST', 'api_keys')!.body).toEqual([
      expect.objectContaining({ expires_at: '2027-01-01T00:00:00Z' }),
    ]);
    const body = await res.json() as CreateApiKeyResponse;
    expect(body.expires_at).toBe('2027-01-01T00:00:00Z');
  });
});

describe('POST /v1/orgs/:orgId/api-keys/:keyId/revoke', () => {
  it('returns 401 when no bearer token', async () => {
    const stub = stubSupabase({});
    const req = new Request('https://api.test/v1/orgs/org-id-1/api-keys/key-id/revoke', {
      method: 'POST',
    });
    const res = await handleRevokeApiKey(req, ORG_ID, KEY_ID, opts);
    expect(res.status).toBe(401);
    expect(stub.requests).toEqual([]);
  });

  it('returns 403 when user is not a member', async () => {
    const token = await jwt.sign({ sub: AUTH0_SUB, email: 'u@test.com' });
    const stub = stubSupabase(revokeRoutes({ 'GET organization_memberships': okRows([]) }));
    const res = await handleRevokeApiKey(makeRevokeRequest(token), ORG_ID, KEY_ID, opts);
    expect(res.status).toBe(403);
    expect(stub.find('PATCH', 'api_keys')).toBeUndefined();
  });

  it('returns 403 when user role is viewer', async () => {
    const token = await jwt.sign({ sub: AUTH0_SUB, email: 'u@test.com' });
    const stub = stubSupabase(revokeRoutes({
      'GET organization_memberships': okRows([makeMembership(ORG_ID, 'viewer')]),
    }));
    const res = await handleRevokeApiKey(makeRevokeRequest(token), ORG_ID, KEY_ID, opts);
    expect(res.status).toBe(403);
    expect(stub.find('PATCH', 'api_keys')).toBeUndefined();
  });

  it('returns 403 when user role is billing_admin', async () => {
    const token = await jwt.sign({ sub: AUTH0_SUB, email: 'u@test.com' });
    const stub = stubSupabase(revokeRoutes({
      'GET organization_memberships': okRows([makeMembership(ORG_ID, 'billing_admin')]),
    }));
    const res = await handleRevokeApiKey(makeRevokeRequest(token), ORG_ID, KEY_ID, opts);
    expect(res.status).toBe(403);
    expect(stub.find('PATCH', 'api_keys')).toBeUndefined();
  });

  it('returns 404 when key does not belong to the org', async () => {
    const token = await jwt.sign({ sub: AUTH0_SUB, email: 'u@test.com' });
    const stub = stubSupabase(revokeRoutes({ 'GET api_keys': okRows([]) }));
    const res = await handleRevokeApiKey(makeRevokeRequest(token), ORG_ID, KEY_ID, opts);
    expect(res.status).toBe(404);
    // The lookup is scoped to both the key and the org, so a foreign key 404s.
    const params = stub.find('GET', 'api_keys')!.url.searchParams;
    expect(params.get('id')).toBe(`eq.${KEY_ID}`);
    expect(params.get('organization_id')).toBe(`eq.${ORG_ID}`);
    expect(stub.find('PATCH', 'api_keys')).toBeUndefined();
  });

  it('revokes the key and returns 200', async () => {
    const token = await jwt.sign({ sub: AUTH0_SUB, email: 'u@test.com' });
    const stub = stubSupabase(revokeRoutes());

    const res = await handleRevokeApiKey(makeRevokeRequest(token), ORG_ID, KEY_ID, opts);
    expect(res.status).toBe(200);
    const body = await res.json() as RevokeApiKeyResponse;
    expect(body.id).toBe(KEY_ID);
    expect(body.status).toBe('revoked');
    const patch = stub.find('PATCH', 'api_keys')!;
    expect(patch.body).toEqual(
      expect.objectContaining({ status: 'revoked', revoked_at: body.revoked_at }),
    );
    expect(patch.url.searchParams.get('id')).toBe(`eq.${KEY_ID}`);
    // Audit log written for revoke
    expect(stub.find('POST', 'audit_log')!.body).toEqual([
      expect.objectContaining({
        action: 'api_key.revoked',
        target_type: 'api_key',
        target_id: KEY_ID,
        organization_id: ORG_ID,
      }),
    ]);
  });

  it('asks PostgREST for the updated row via the Prefer header, not a query param', async () => {
    const token = await jwt.sign({ sub: AUTH0_SUB, email: 'u@test.com' });
    const stub = stubSupabase(revokeRoutes());

    const res = await handleRevokeApiKey(makeRevokeRequest(token), ORG_ID, KEY_ID, opts);
    expect(res.status).toBe(200);

    const patch = stub.find('PATCH', 'api_keys')!;
    expect(patch.headers['prefer']).toBe('return=representation');
    expect(patch.url.searchParams.get('returning')).toBeNull();
  });

  it('returns 500 when the revoke update fails', async () => {
    const token = await jwt.sign({ sub: AUTH0_SUB, email: 'u@test.com' });
    const stub = stubSupabase(revokeRoutes({ 'PATCH api_keys': httpError(500, 'DB error') }));
    const res = await handleRevokeApiKey(makeRevokeRequest(token), ORG_ID, KEY_ID, opts);
    expect(res.status).toBe(500);
    expect(stub.find('POST', 'audit_log')).toBeUndefined();
  });
});
