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
const SUPABASE_CLIENT_ID = 'client-supabase-spa';
const OTHER_CLIENT_ID = 'client-native-app';

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

/**
 * `user` fields are merged over a verified default user, e.g. `{ user: { email_verified: false } }`;
 * `secrets` over the two the Action always has. The default client is not Supabase-bound.
 * The default connection is `auth0` (the built-in database connection), which is the only
 * strategy allowed to do email-based re-linking (CR65).
 */
function makeEvent(overrides: {
  protocol?: string;
  stats?: unknown;
  user?: Record<string, unknown>;
  secrets?: Record<string, string>;
  clientId?: string;
  connection?: { strategy: string; name?: string };
  authentication?: { methods: Array<{ name: string; timestamp: string }> };
} = {}) {
  return {
    secrets: { SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY: 'service-role-key', ...overrides.secrets },
    client: { client_id: overrides.clientId ?? OTHER_CLIENT_ID },
    connection: overrides.connection ?? { strategy: 'auth0', name: 'Username-Password-Authentication' },
    user: {
      user_id: AUTH0_ID, email: EMAIL, name: 'User One', nickname: 'user', picture: 'https://pic.example/u.png', email_verified: true,
      ...overrides.user,
    },
    stats: 'stats' in overrides ? overrides.stats : { logins_count: LOGINS_COUNT },
    transaction: { protocol: overrides.protocol ?? 'oidc-basic-profile' },
    ...(overrides.authentication ? { authentication: overrides.authentication } : {}),
  };
}

function makeApi() {
  const idClaims: Record<string, unknown> = {};
  const accessClaims: Record<string, unknown> = {};
  const denials: string[] = [];
  return {
    idClaims,
    accessClaims,
    denials,
    api: {
      idToken: { setCustomClaim: (k: string, v: unknown) => { idClaims[k] = v; } },
      accessToken: { setCustomClaim: (k: string, v: unknown) => { accessClaims[k] = v; } },
      access: { deny: (reason: string) => { denials.push(reason); } },
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

  // CR60: a silent sign-in (an /authorize that reuses the Auth0 session) runs post-login too,
  // and Auth0 does not count it. `event.authentication.methods` carries the session's methods
  // with the time each was used, so last_login is that time on a login and on a session reuse.
  describe('last_login follows event.authentication.methods (CR60)', () => {
    const NOW = new Date('2026-09-30T05:05:36.000Z');

    afterEach(() => {
      vi.useRealTimers();
    });

    it('writes the latest method timestamp on a login, without a silent sign-in log line', async () => {
      vi.useFakeTimers({ now: NOW, toFake: ['Date'] });
      const log = vi.spyOn(console, 'log').mockImplementation(() => {});
      const calls = stubFetch({ 'PATCH users?auth0_id': rows([{ id: APP_USER_ID }]), ...noRoles });
      const authentication = {
        methods: [
          { name: 'pwd', timestamp: '2026-09-30T05:05:30.000Z' },
          { name: 'mfa', timestamp: '2026-09-30T05:05:34.000Z' },
        ],
      };

      await onExecutePostLogin(makeEvent({ authentication }), makeApi().api);

      const body = calls.find((c) => c.method === 'PATCH')?.body;
      expect(body).toHaveProperty('last_login', '2026-09-30T05:05:34.000Z');
      expect(log.mock.calls.flat().join('\n')).not.toMatch(/silent sign-in/);
    });

    it('keeps last_login at the session\'s login time on a silent sign-in, and logs it as one', async () => {
      // The measured case: login at 05:02:20Z, then a session-reusing /authorize at 05:05:36Z.
      vi.useFakeTimers({ now: NOW, toFake: ['Date'] });
      const log = vi.spyOn(console, 'log').mockImplementation(() => {});
      const calls = stubFetch({ 'PATCH users?auth0_id': rows([{ id: APP_USER_ID }]), ...noRoles });
      const authentication = { methods: [{ name: 'pwd', timestamp: '2026-09-30T05:02:20.000Z' }] };

      await onExecutePostLogin(makeEvent({ authentication }), makeApi().api);

      const body = calls.find((c) => c.method === 'PATCH')?.body;
      expect(body).toHaveProperty('last_login', '2026-09-30T05:02:20.000Z');
      expect(log.mock.calls.flat().join('\n')).toMatch(/silent sign-in for auth0\|user-1: session authenticated 2026-09-30T05:02:20.000Z/);
    });

    it('falls back to now when the event carries no authentication methods', async () => {
      vi.useFakeTimers({ now: NOW, toFake: ['Date'] });
      const calls = stubFetch({ 'PATCH users?auth0_id': rows([{ id: APP_USER_ID }]), ...noRoles });

      await onExecutePostLogin(makeEvent({ authentication: { methods: [] } }), makeApi().api);

      const body = calls.find((c) => c.method === 'PATCH')?.body;
      expect(body).toHaveProperty('last_login', NOW.toISOString());
    });
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

    const lookup = calls.find((c) => c.method === 'GET' && c.url.searchParams.has('email'));
    expect(lookup?.url.searchParams.get('email')).toBe(`eq.${EMAIL}`);
    const backfill = calls.find((c) => c.method === 'PATCH' && c.url.searchParams.has('id'));
    expect(backfill?.url.searchParams.get('id')).toBe(`eq.${APP_USER_ID}`);
    expect(backfill?.body).toMatchObject({ auth0_id: AUTH0_ID, name: 'User One', login_count: LOGINS_COUNT });
  });

  // Only a literal `true` counts as verified: a missing flag or a string is not verification.
  it.each([false, undefined, null, 'false', 'true'])(
    'provisions a fresh row without an email lookup when email_verified is %j (CR51)',
    async (emailVerified) => {
    // An unverified user matching by email must NOT inherit the existing row's memberships.
    const calls = stubFetch({
      'PATCH users?auth0_id': rows([]),
      // No 'GET users?email' route — it must not be called.
      'POST users': rows([{ id: APP_USER_ID }], 201),
      ...noRoles,
    });
    const { api, accessClaims } = makeApi();

    await onExecutePostLogin(makeEvent({ user: { email_verified: emailVerified } }), api);

    // Email lookup must be skipped entirely.
    expect(calls.some((c) => c.method === 'GET' && c.url.pathname.endsWith('/users'))).toBe(false);
    // A new row must be provisioned (step 3).
    expect(calls.find((c) => c.method === 'POST')?.body).toMatchObject({
      auth0_id: AUTH0_ID,
      email: EMAIL,
      email_verified: false,
    });
    expect(accessClaims[`${CLAIM}app_user_id`]).toBe(APP_USER_ID);
  },
  );

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

  // CR65: email-based re-linking is restricted to the `auth0` (database) connection strategy.
  // Social / enterprise IdPs (Google, GitHub, SAML) assert email_verified on the IdP's word;
  // allowing re-link from them would let any identity controlling the same email on any IdP
  // claim an existing row's memberships and API keys.
  it.each(['google-oauth2', 'github', 'samlp', 'windowslive', 'oidc'])(
    'skips email re-link for "%s" connection strategy even when email is verified (CR65)',
    async (strategy) => {
      const calls = stubFetch({
        'PATCH users?auth0_id': rows([]),
        // No 'GET users?email' route — the email lookup must not be called.
        'POST users': rows([{ id: APP_USER_ID }], 201),
        ...noRoles,
      });
      const { api, accessClaims } = makeApi();

      await onExecutePostLogin(
        makeEvent({ connection: { strategy, name: `${strategy}-connection` } }),
        api,
      );

      // Email lookup is forbidden for non-allowlisted connections.
      expect(calls.some((c) => c.method === 'GET' && c.url.pathname.endsWith('/users'))).toBe(false);
      // A new row is provisioned instead (step 3).
      expect(calls.find((c) => c.method === 'POST')?.body).toMatchObject({
        auth0_id: AUTH0_ID,
        email: EMAIL,
      });
      expect(accessClaims[`${CLAIM}app_user_id`]).toBe(APP_USER_ID);
    },
  );

  it('allows email re-link from the auth0 (database) connection when email is verified (CR65)', async () => {
    // Baseline: confirm the allowlisted connection still re-links correctly.
    const calls = stubFetch({
      'PATCH users?auth0_id': rows([]),
      'GET users?email': rows([{ id: APP_USER_ID, email: EMAIL }]),
      'PATCH users?id': rows([{ id: APP_USER_ID }]),
      ...noRoles,
    });

    await onExecutePostLogin(
      makeEvent({ connection: { strategy: 'auth0', name: 'Username-Password-Authentication' } }),
      makeApi().api,
    );

    expect(calls.some((c) => c.method === 'GET' && c.url.searchParams.has('email'))).toBe(true);
    expect(calls.find((c) => c.method === 'PATCH' && c.url.searchParams.has('id'))?.body)
      .toMatchObject({ auth0_id: AUTH0_ID });
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

  it('denies login when Supabase cannot provision a user row (CR69)', async () => {
    stubFetch({
      'PATCH users?auth0_id': rows([]),
      'GET users?email': rows([]),
      'POST users': rows({ message: 'insert failed' }, 409),
    });
    const { api, accessClaims, denials } = makeApi();

    await expect(onExecutePostLogin(makeEvent(), api)).resolves.toBeUndefined();
    expect(accessClaims).toEqual({});
    expect(denials).toHaveLength(1);
    expect(denials[0]).toMatch(/provision user account/i);
  });

  it('denies login for a user with no email when the insert is rejected (CR69)', async () => {
    const calls = stubFetch({
      'PATCH users?auth0_id': rows([]),
      'GET users?email': rows([]),
      'POST users': rows({ code: '23502', message: 'null value in column "email" violates not-null constraint' }, 400),
    });
    const { api, accessClaims, denials } = makeApi();

    await expect(onExecutePostLogin(makeEvent({ user: { email: undefined } }), api)).resolves.toBeUndefined();
    expect(calls.find((c) => c.method === 'POST')?.body).not.toHaveProperty('email');
    expect(accessClaims).toEqual({});
    expect(denials).toHaveLength(1);
  });

  // Fail-open covers only an unresolved user. A transport failure throws, and Auth0 fails the
  // login; whether it should fail open instead is an owner decision (TS26).
  it.each([
    ['fetch rejects', () => { throw new TypeError('fetch failed'); }],
    ['Supabase answers with a non-JSON body', () => new Response('<html>Bad Gateway</html>', { status: 502 })],
  ])('throws, so the login fails, when %s', async (_case, responder: Responder) => {
    stubFetch({ 'PATCH users?auth0_id': responder, 'GET users?auth0_id': responder });

    await expect(onExecutePostLogin(makeEvent(), makeApi().api)).rejects.toThrow();
  });
});

describe('post-login Action — Supabase third-party auth role claim (CR62)', () => {
  const resolvedUser = { 'PATCH users?auth0_id': rows([{ id: APP_USER_ID }]), ...noRoles };
  const bound = { SUPABASE_TPA_CLIENT_IDS: ` ${OTHER_CLIENT_ID}, ${SUPABASE_CLIENT_ID} ` };

  it('puts role=authenticated on the ID token, and only there, for a listed client', async () => {
    stubFetch(resolvedUser);
    const { api, idClaims, accessClaims } = makeApi();

    await onExecutePostLogin(makeEvent({ secrets: bound, clientId: SUPABASE_CLIENT_ID }), api);

    expect(idClaims.role).toBe('authenticated');
    expect(accessClaims).not.toHaveProperty('role');
  });

  it('sets no role claim for a client that is not listed', async () => {
    stubFetch(resolvedUser);
    const { api, idClaims } = makeApi();

    await onExecutePostLogin(makeEvent({ secrets: { SUPABASE_TPA_CLIENT_IDS: SUPABASE_CLIENT_ID } }), api);

    expect(idClaims).not.toHaveProperty('role');
  });

  it('sets no role claim when the secret is absent, whatever the client', async () => {
    stubFetch(resolvedUser);
    const { api, idClaims } = makeApi();

    await onExecutePostLogin(makeEvent({ clientId: SUPABASE_CLIENT_ID }), api);

    expect(idClaims).not.toHaveProperty('role');
  });

  it('sets no role claim when no users row resolved, even for a listed client', async () => {
    stubFetch({
      'PATCH users?auth0_id': rows([]),
      'GET users?email': rows([]),
      'POST users': rows({ message: 'insert failed' }, 409),
    });
    const { api, idClaims } = makeApi();

    await onExecutePostLogin(makeEvent({ secrets: bound, clientId: SUPABASE_CLIENT_ID }), api);

    expect(idClaims).toEqual({});
  });
});
