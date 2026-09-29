import { createRequire } from 'node:module';
import { describe, it, expect, vi, afterEach } from 'vitest';

// Loaded exactly as Auth0 runs it: a CommonJS module exporting onExecutePostLogin.
const require = createRequire(import.meta.url);
const { onExecutePostLogin } = require('./provision-user-and-enrich-token.cjs') as {
  onExecutePostLogin: (event: unknown, api: unknown) => Promise<void>;
};

const SUPABASE_URL = 'https://project.supabase.co';
const AUTH0_ID = 'auth0|user-1';
const EMAIL = 'user@example.com';
const APP_USER_ID = '00000000-0000-4000-8000-000000000001';
const LOGINS_COUNT = 7;
const CLAIM = 'https://integritystudio.dev/';

interface Call { method: string; url: URL; body: Record<string, unknown> | undefined }
type Responder = (call: Call) => Response;

const rows = (data: unknown, status = 200) => () => Response.json(data, { status });

/**
 * Stubs fetch, routing on "<METHOD> <table>[?<column>]"; every call is recorded. A request
 * with no route throws, naming it, so a call a test forbids fails by name rather than as a
 * JSON parse error further on.
 */
function stubFetch(routes: Record<string, Responder>) {
  const calls: Call[] = [];
  vi.stubGlobal('fetch', vi.fn(async (input: string, init: RequestInit = {}) => {
    const url = new URL(input);
    const method = (init.method ?? 'GET').toUpperCase();
    const call = { method, url, body: init.body ? JSON.parse(String(init.body)) : undefined };
    calls.push(call);
    const table = url.pathname.split('/').pop();
    const column = [...url.searchParams.keys()].find((k) => k !== 'select' && k !== 'limit');
    const key = `${method} ${table}?${column}`;
    const responder = routes[key] ?? routes[`${method} ${table}`];
    if (!responder) throw new Error(`unrouted request: ${key}`);
    return responder(call);
  }));
  return calls;
}

/** `user` fields are merged over a verified default user, e.g. `{ user: { email_verified: false } }`. */
function makeEvent(overrides: { protocol?: string; stats?: unknown; user?: Record<string, unknown> } = {}) {
  return {
    secrets: { SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY: 'service-role-key' },
    user: {
      user_id: AUTH0_ID, email: EMAIL, name: 'User One', nickname: 'user', picture: 'https://pic.example/u.png', email_verified: true,
      ...overrides.user,
    },
    stats: 'stats' in overrides ? overrides.stats : { logins_count: LOGINS_COUNT },
    transaction: { protocol: overrides.protocol ?? 'oidc-basic-profile' },
  };
}

function makeApi() {
  const idClaims: Record<string, unknown> = {};
  const accessClaims: Record<string, unknown> = {};
  return {
    idClaims,
    accessClaims,
    api: {
      idToken: { setCustomClaim: (k: string, v: unknown) => { idClaims[k] = v; } },
      accessToken: { setCustomClaim: (k: string, v: unknown) => { accessClaims[k] = v; } },
    },
  };
}

const noRoles = { 'GET user_roles': rows([]) };

afterEach(() => {
  vi.unstubAllGlobals();
});

describe('post-login Action — profile write (UA02)', () => {
  it('writes the profile onto the auth0_id row in the same request that finds it', async () => {
    const calls = stubFetch({ 'PATCH users?auth0_id': rows([{ id: APP_USER_ID, email: EMAIL }]), ...noRoles });
    const { api, accessClaims } = makeApi();

    await onExecutePostLogin(makeEvent(), api);

    const userCalls = calls.filter((c) => c.url.pathname.endsWith('/users'));
    expect(userCalls.map((c) => c.method)).toEqual(['PATCH']);
    expect(userCalls[0].url.searchParams.get('auth0_id')).toBe(`eq.${AUTH0_ID}`);
    expect(userCalls[0].body).toEqual({
      name: 'User One',
      nickname: 'user',
      picture: 'https://pic.example/u.png',
      email_verified: true,
      login_count: LOGINS_COUNT,
      last_login: expect.stringMatching(/^\d{4}-\d{2}-\d{2}T/),
    });
    expect(accessClaims[`${CLAIM}app_user_id`]).toBe(APP_USER_ID);
  });

  it('does not touch last_login on a refresh-token exchange, which is not a login', async () => {
    const calls = stubFetch({ 'PATCH users?auth0_id': rows([{ id: APP_USER_ID }]), ...noRoles });

    await onExecutePostLogin(makeEvent({ protocol: 'oauth2-refresh-token' }), makeApi().api);

    const body = calls.find((c) => c.method === 'PATCH')?.body;
    expect(body).not.toHaveProperty('last_login');
    expect(body?.login_count).toBe(LOGINS_COUNT);
  });

  it('leaves login_count alone when Auth0 supplies no stats', async () => {
    const calls = stubFetch({ 'PATCH users?auth0_id': rows([{ id: APP_USER_ID }]), ...noRoles });

    await onExecutePostLogin(makeEvent({ stats: undefined }), makeApi().api);

    expect(calls.find((c) => c.method === 'PATCH')?.body).not.toHaveProperty('login_count');
  });

  it('falls back to a read when the profile write fails, so claims still resolve', async () => {
    const calls = stubFetch({
      'PATCH users?auth0_id': rows({ message: 'column does not exist' }, 400),
      'GET users?auth0_id': rows([{ id: APP_USER_ID, email: EMAIL }]),
      ...noRoles,
    });
    const { api, accessClaims } = makeApi();

    await onExecutePostLogin(makeEvent(), api);

    expect(calls.filter((c) => c.url.pathname.endsWith('/users')).map((c) => c.method)).toEqual(['PATCH', 'GET']);
    expect(accessClaims[`${CLAIM}app_user_id`]).toBe(APP_USER_ID);
  });

  it('backfills auth0_id and the profile onto a user found by email', async () => {
    const calls = stubFetch({
      'PATCH users?auth0_id': rows([]),
      'GET users?email': rows([{ id: APP_USER_ID, email: EMAIL }]),
      'PATCH users?id': rows([{ id: APP_USER_ID }]),
      ...noRoles,
    });

    await onExecutePostLogin(makeEvent(), makeApi().api);

    const backfill = calls.find((c) => c.method === 'PATCH' && c.url.searchParams.has('id'));
    expect(backfill?.body).toMatchObject({ auth0_id: AUTH0_ID, name: 'User One', login_count: LOGINS_COUNT });
  });

  it('provisions a fresh row without an email lookup when email_verified is false (CR51)', async () => {
    // An unverified user matching by email must NOT inherit the existing row's memberships.
    const calls = stubFetch({
      'PATCH users?auth0_id': rows([]),
      // No 'GET users?email' route — it must not be called.
      'POST users': rows([{ id: APP_USER_ID }], 201),
      ...noRoles,
    });
    const { api, accessClaims } = makeApi();

    await onExecutePostLogin(makeEvent({ user: { email_verified: false } }), api);

    // Email lookup must be skipped entirely.
    expect(calls.some((c) => c.method === 'GET' && c.url.pathname.endsWith('/users'))).toBe(false);
    // A new row must be provisioned (step 3).
    expect(calls.find((c) => c.method === 'POST')?.body).toMatchObject({
      auth0_id: AUTH0_ID,
      email: EMAIL,
      email_verified: false,
    });
    expect(accessClaims[`${CLAIM}app_user_id`]).toBe(APP_USER_ID);
  });

  it('grants no app claims when an unverified identity shares an existing row\'s email (CR51)', async () => {
    // users_email_key rejects the insert, so nothing links the new identity to the old row.
    const calls = stubFetch({
      'PATCH users?auth0_id': rows([]),
      'GET users?email': rows([{ id: APP_USER_ID, email: EMAIL }]),
      'POST users': rows({ code: '23505', message: 'duplicate key value violates unique constraint "users_email_key"' }, 409),
      ...noRoles,
    });
    const { api, accessClaims, idClaims } = makeApi();

    await onExecutePostLogin(makeEvent({ user: { email_verified: false } }), api);

    expect(calls.some((c) => c.url.searchParams.has('id'))).toBe(false);
    expect(accessClaims).toEqual({});
    expect(idClaims).toEqual({});
  });

  it('provisions a new user with the profile', async () => {
    const calls = stubFetch({
      'PATCH users?auth0_id': rows([]),
      'GET users?email': rows([]),
      'POST users': rows([{ id: APP_USER_ID }], 201),
      ...noRoles,
    });
    const { api, accessClaims } = makeApi();

    await onExecutePostLogin(makeEvent(), api);

    expect(calls.find((c) => c.method === 'POST')?.body)
      .toMatchObject({ auth0_id: AUTH0_ID, email: EMAIL, email_verified: true, login_count: LOGINS_COUNT });
    expect(accessClaims[`${CLAIM}app_user_id`]).toBe(APP_USER_ID);
  });
});

describe('post-login Action — claims (unchanged from v8)', () => {
  it('puts role names and the union of their permissions on both tokens', async () => {
    stubFetch({
      'PATCH users?auth0_id': rows([{ id: APP_USER_ID }]),
      'GET user_roles': rows([
        { roles: { name: 'admin', permissions: ['read', 'write'] } },
        { roles: { name: 'viewer', permissions: ['read'] } },
        { roles: null },
      ]),
    });
    const { api, idClaims, accessClaims } = makeApi();

    await onExecutePostLogin(makeEvent(), api);

    expect(idClaims[`${CLAIM}roles`]).toEqual(['admin', 'viewer']);
    expect(accessClaims[`${CLAIM}permissions`]).toEqual(['read', 'write']);
  });

  it('sets no claims and does not throw when no user can be resolved', async () => {
    stubFetch({
      'PATCH users?auth0_id': rows([]),
      'GET users?email': rows([]),
      'POST users': rows({ message: 'insert failed' }, 409),
    });
    const { api, accessClaims } = makeApi();

    await expect(onExecutePostLogin(makeEvent(), api)).resolves.toBeUndefined();
    expect(accessClaims).toEqual({});
  });
});
