import { createHash } from 'node:crypto';
import { createClient } from '@supabase/supabase-js';
import { describe, expect, it } from 'vitest';
import { FAKE_SUPABASE_URL, FakeBackend, type Row } from './fake-backend';
import { createApiKeysCreateHandler } from '../../functions/api-keys-create/handler.ts';

// The function is server-to-server: the provisioning receiver calls it with a service key.
// The edge runtime injects a DIFFERENT service key as SUPABASE_SERVICE_ROLE_KEY, which is why
// the credential check is by capability (the Auth admin API accepts it) and not by equality.
const EDGE_RUNTIME_SERVICE_KEY = 'legacy-service-role-jwt';
const RECEIVER_SERVICE_KEY = 'sb_secret_receiver';
const PUBLISHABLE_KEY = 'sb_publishable_anon';

const CF_ACCOUNT_ID = 'cf-account';
const CF_API_TOKEN = 'cf-kv-write-token';
const KV_NAMESPACE_ID = 'auth-kv-namespace';

const FUNCTION_URL = `${FAKE_SUPABASE_URL}/functions/v1/api-keys-create`;

const USER_ID = 'user-1';
const OTHER_USER_ID = 'user-2';
const GROWTH_ORG = 'org-growth';
const STARTER_ORG = 'org-starter';
const ENTERPRISE_ORG = 'org-enterprise';

const TOKEN_PATTERN = /^obtk_[0-9a-f]{64}$/;
const MAX_NAME_LENGTH = 100;
const DEFAULT_NAME = 'Default';

const BASE_ENV: Record<string, string> = {
  SUPABASE_URL: FAKE_SUPABASE_URL,
  SUPABASE_SERVICE_ROLE_KEY: EDGE_RUNTIME_SERVICE_KEY,
  CLOUDFLARE_ACCOUNT_ID: CF_ACCOUNT_ID,
  CLOUDFLARE_API_TOKEN: CF_API_TOKEN,
  KV_NAMESPACE_ID,
};

/**
 * The starting world: USER_ID is an active member of the growth org only, and carries a
 * stale `users.tier` of enterprise that nothing may read (UA11).
 */
function baseTables(): Record<string, Row[]> {
  return {
    users: [
      { id: USER_ID, email: 'owner@example.com', tier: 'enterprise' },
      { id: OTHER_USER_ID, email: 'other@example.com', tier: 'starter' },
    ],
    organizations: [
      { id: GROWTH_ORG, current_plan: 'growth' },
      { id: STARTER_ORG, current_plan: 'starter' },
      { id: ENTERPRISE_ORG, current_plan: 'enterprise' },
    ],
    organization_memberships: [
      { user_id: USER_ID, organization_id: GROWTH_ORG, status: 'active' },
      { user_id: OTHER_USER_ID, organization_id: STARTER_ORG, status: 'active' },
      { user_id: OTHER_USER_ID, organization_id: ENTERPRISE_ORG, status: 'active' },
    ],
    api_keys: [],
  };
}

interface SetupOptions {
  tables?: Record<string, Row[]>;
  env?: Record<string, string | undefined>;
}

function setup(options: SetupOptions = {}) {
  const backend = new FakeBackend({
    serviceKeys: [EDGE_RUNTIME_SERVICE_KEY, RECEIVER_SERVICE_KEY],
    cloudflareToken: CF_API_TOKEN,
    tables: options.tables ?? baseTables(),
  });
  const env = { ...BASE_ENV, ...options.env };
  const handler = createApiKeysCreateHandler({
    env: (name) => env[name],
    fetch: backend.fetch,
    createClient,
  });

  const send = (init: RequestInit) => handler(new Request(FUNCTION_URL, init));
  const post = (body: unknown, authorization: string | null = `Bearer ${RECEIVER_SERVICE_KEY}`) =>
    send({
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        ...(authorization === null ? {} : { Authorization: authorization }),
      },
      body: typeof body === 'string' ? body : JSON.stringify(body),
    });

  return { backend, send, post };
}

interface CreatedKey {
  token: string;
  keyId: string;
  prefix: string;
  tier: string;
  name: string;
  warning?: string;
}

const sha256Hex = (value: string) => createHash('sha256').update(value).digest('hex');

function kvRecord(backend: FakeBackend, token: string): Record<string, unknown> | undefined {
  const entry = backend.kvEntry(CF_ACCOUNT_ID, KV_NAMESPACE_ID, `apikey:${sha256Hex(token)}`);
  return entry && JSON.parse(entry.value);
}

function expectNothingMinted(backend: FakeBackend) {
  expect(backend.rows('api_keys')).toEqual([]);
  expect(backend.kv.size).toBe(0);
}

describe('api-keys-create: transport', () => {
  it('answers a CORS preflight with 204 and no body', async () => {
    const { send } = setup();

    const res = await send({ method: 'OPTIONS' });

    expect(res.status).toBe(204);
    expect(await res.text()).toBe('');
    expect(res.headers.get('Access-Control-Allow-Methods')).toBe('POST, OPTIONS');
    expect(res.headers.get('Access-Control-Allow-Headers')).toContain('authorization');
  });

  it.each(['GET', 'PUT', 'DELETE'])('rejects %s with 405', async (method) => {
    const { backend, send } = setup();

    const res = await send({ method, headers: { Authorization: `Bearer ${RECEIVER_SERVICE_KEY}` } });

    expect(res.status).toBe(405);
    expect(await res.json()).toEqual({ error: 'Method not allowed' });
    expectNothingMinted(backend);
  });

  it.each([
    ['a success', () => ({ userId: USER_ID }), `Bearer ${RECEIVER_SERVICE_KEY}`, 201],
    ['an auth failure', () => ({ userId: USER_ID }), null, 401],
    ['a validation failure', () => ({}), `Bearer ${RECEIVER_SERVICE_KEY}`, 400],
  ] as const)('answers %s as JSON with CORS headers', async (_label, body, authorization, status) => {
    const { post } = setup();

    const res = await post(body(), authorization);

    expect(res.status).toBe(status);
    expect(res.headers.get('Content-Type')).toBe('application/json');
    expect(res.headers.get('Access-Control-Allow-Origin')).toBe('*');
  });
});

describe('api-keys-create: caller authentication', () => {
  it.each([
    ['no Authorization header', null],
    ['a non-Bearer scheme', `Basic ${RECEIVER_SERVICE_KEY}`],
    ['an empty Bearer token', 'Bearer    '],
    ['a publishable (anon) key', `Bearer ${PUBLISHABLE_KEY}`],
    ['an unknown key', 'Bearer not-a-key'],
  ])('refuses %s with 401 and mints nothing', async (_label, authorization) => {
    const { backend, post } = setup();

    const res = await post({ userId: USER_ID }, authorization);

    expect(res.status).toBe(401);
    expect(await res.json()).toEqual({ error: 'Unauthorized' });
    expectNothingMinted(backend);
  });

  it('accepts a service key other than the one the function itself holds', async () => {
    const { post } = setup();

    const res = await post({ userId: USER_ID }, `Bearer ${RECEIVER_SERVICE_KEY}`);

    expect(res.status).toBe(201);
  });

  it('fails closed with 401 when the Auth admin API is unreachable', async () => {
    const { backend, post } = setup();
    backend.fail('auth', { kind: 'network' });

    const res = await post({ userId: USER_ID });

    expect(res.status).toBe(401);
    expectNothingMinted(backend);
  });

  it('fails closed with 401 when the Auth admin API errors', async () => {
    const { backend, post } = setup();
    backend.fail('auth', { kind: 'http', status: 500, body: { msg: 'internal' } });

    const res = await post({ userId: USER_ID });

    expect(res.status).toBe(401);
    expectNothingMinted(backend);
  });
});

describe('api-keys-create: request validation', () => {
  it.each([
    ['no userId', { name: 'k' }],
    ['a numeric userId', { userId: 42 }],
    ['an empty userId', { userId: '' }],
  ])('rejects a body with %s with 400', async (_label, body) => {
    const { backend, post } = setup();

    const res = await post(body);

    expect(res.status).toBe(400);
    expect(await res.json()).toEqual({ error: 'userId is required' });
    expectNothingMinted(backend);
  });

  it('treats a body that is not JSON as empty, so it fails on the missing userId', async () => {
    const { backend, post } = setup();

    const res = await post('{not json');

    expect(res.status).toBe(400);
    expectNothingMinted(backend);
  });

  it('answers 404 for a userId with no users row', async () => {
    const { backend, post } = setup();

    const res = await post({ userId: 'no-such-user' });

    expect(res.status).toBe(404);
    expect(await res.json()).toEqual({ error: 'User not found.' });
    expectNothingMinted(backend);
  });

  // TS20: a database failure must surface as 5xx, not 404, so the receiver can
  // distinguish an outage from a genuinely missing user and choose to retry.
  it('answers 503 and mints nothing when the user lookup fails with a database error', async () => {
    const { backend, post } = setup();
    backend.fail('select:users', { kind: 'http', status: 500, body: { message: 'db down' } });

    const res = await post({ userId: USER_ID });

    expect(res.status).toBe(503);
    expectNothingMinted(backend);
  });
});

describe('api-keys-create: organization resolution', () => {
  it('mints into the requested organization when the user is an active member of it', async () => {
    const { backend, post } = setup();

    const res = await post({ userId: USER_ID, organizationId: GROWTH_ORG });

    expect(res.status).toBe(201);
    expect(backend.rows('api_keys')).toEqual([expect.objectContaining({ organization_id: GROWTH_ORG })]);
  });

  it('refuses an organization the user does not belong to, even one another user does', async () => {
    const { backend, post } = setup();

    const res = await post({ userId: USER_ID, organizationId: ENTERPRISE_ORG });

    expect(res.status).toBe(403);
    expect(await res.json()).toEqual({ error: 'User is not an active member of that organization.' });
    expectNothingMinted(backend);
  });

  it.each(['invited', 'suspended', 'removed'])(
    'refuses an organization where the membership is %s',
    async (status) => {
      const tables = baseTables();
      tables.organization_memberships.push({ user_id: USER_ID, organization_id: ENTERPRISE_ORG, status });
      const { backend, post } = setup({ tables });

      const res = await post({ userId: USER_ID, organizationId: ENTERPRISE_ORG });

      expect(res.status).toBe(403);
      expectNothingMinted(backend);
    },
  );

  it('uses the user\'s active membership when no organization is requested', async () => {
    const { backend, post } = setup();

    const res = await post({ userId: USER_ID });

    expect(res.status).toBe(201);
    expect(backend.rows('api_keys')).toEqual([expect.objectContaining({ organization_id: GROWTH_ORG })]);
  });

  it('ignores inactive memberships when choosing the organization', async () => {
    const tables = baseTables();
    tables.organization_memberships = [
      { user_id: USER_ID, organization_id: ENTERPRISE_ORG, status: 'suspended' },
      { user_id: USER_ID, organization_id: GROWTH_ORG, status: 'active' },
    ];
    const { backend, post } = setup({ tables });

    const res = await post({ userId: USER_ID });

    expect(res.status).toBe(201);
    expect(backend.rows('api_keys')).toEqual([expect.objectContaining({ organization_id: GROWTH_ORG })]);
  });

  it.each([
    ['no memberships', []],
    ['only an inactive membership', [{ user_id: USER_ID, organization_id: GROWTH_ORG, status: 'suspended' }]],
  ])('refuses a user with %s and no requested organization', async (_label, memberships) => {
    const tables = baseTables();
    tables.organization_memberships = memberships;
    const { backend, post } = setup({ tables });

    const res = await post({ userId: USER_ID });

    expect(res.status).toBe(403);
    expect(await res.json()).toEqual({ error: 'User has no organization. Contact support.' });
    expectNothingMinted(backend);
  });
});

describe('api-keys-create: organization resolution (TS21)', () => {
  it('prefers users.default_organization_id over the first active membership', async () => {
    const tables = baseTables();
    tables.users = [{ id: USER_ID, email: 'owner@example.com', tier: 'enterprise', default_organization_id: ENTERPRISE_ORG }];
    tables.organization_memberships = [
      { user_id: USER_ID, organization_id: GROWTH_ORG, status: 'active' },
      { user_id: USER_ID, organization_id: ENTERPRISE_ORG, status: 'active' },
    ];
    const { backend, post } = setup({ tables });

    const res = await post({ userId: USER_ID });

    expect(res.status).toBe(201);
    expect(backend.rows('api_keys')).toEqual([expect.objectContaining({ organization_id: ENTERPRISE_ORG })]);
  });

  it('falls back to the oldest active membership when default_organization_id is absent', async () => {
    const tables = baseTables();
    tables.organization_memberships = [
      { user_id: USER_ID, organization_id: ENTERPRISE_ORG, status: 'active', created_at: '2020-06-01T00:00:00Z' },
      { user_id: USER_ID, organization_id: STARTER_ORG, status: 'active', created_at: '2020-01-01T00:00:00Z' },
    ];
    tables.organizations = [
      { id: STARTER_ORG, current_plan: 'starter' },
      { id: ENTERPRISE_ORG, current_plan: 'enterprise' },
    ];
    const { backend, post } = setup({ tables });

    const res = await post({ userId: USER_ID });

    expect(res.status).toBe(201);
    // STARTER_ORG has the earliest created_at so it must win
    expect(backend.rows('api_keys')).toEqual([expect.objectContaining({ organization_id: STARTER_ORG })]);
  });

  it('falls back past an inactive default_organization_id to the oldest active membership', async () => {
    const tables = baseTables();
    tables.users = [{ id: USER_ID, email: 'owner@example.com', tier: 'enterprise', default_organization_id: ENTERPRISE_ORG }];
    tables.organization_memberships = [
      { user_id: USER_ID, organization_id: GROWTH_ORG, status: 'active', created_at: '2020-01-01T00:00:00Z' },
      { user_id: USER_ID, organization_id: ENTERPRISE_ORG, status: 'suspended' },
    ];
    const { backend, post } = setup({ tables });

    const res = await post({ userId: USER_ID });

    expect(res.status).toBe(201);
    expect(backend.rows('api_keys')).toEqual([expect.objectContaining({ organization_id: GROWTH_ORG })]);
  });
});

describe('api-keys-create: tier', () => {
  it.each([
    ['growth', GROWTH_ORG],
    ['starter', STARTER_ORG],
    ['enterprise', ENTERPRISE_ORG],
  ])('mints a %s key for an org on that plan, everywhere the tier is recorded', async (plan, orgId) => {
    const tables = baseTables();
    tables.organization_memberships.push({ user_id: USER_ID, organization_id: orgId, status: 'active' });
    const { backend, post } = setup({ tables });

    const res = await post({ userId: USER_ID, organizationId: orgId });
    const body = (await res.json()) as CreatedKey;

    expect(body.tier).toBe(plan);
    expect(backend.rows('api_keys')[0].tier).toBe(plan);
    expect(kvRecord(backend, body.token)?.tier).toBe(plan);
  });

  it('ignores a tier in the request body', async () => {
    const tables = baseTables();
    tables.organization_memberships.push({ user_id: USER_ID, organization_id: STARTER_ORG, status: 'active' });
    const { post } = setup({ tables });

    const res = await post({ userId: USER_ID, organizationId: STARTER_ORG, tier: 'enterprise' });

    expect(((await res.json()) as CreatedKey).tier).toBe('starter');
  });

  it('ignores users.tier, even when it names a higher plan than the org (UA11)', async () => {
    const tables = baseTables();
    tables.organization_memberships.push({ user_id: USER_ID, organization_id: STARTER_ORG, status: 'active' });
    const { post } = setup({ tables });

    const res = await post({ userId: USER_ID, organizationId: STARTER_ORG });

    expect(((await res.json()) as CreatedKey).tier).toBe('starter');
  });

  it.each([
    ['a plan that is not a key tier', 'free'],
    ['an empty plan', ''],
  ])('falls back to starter for %s', async (_label, plan) => {
    const tables = baseTables();
    tables.organizations = [{ id: GROWTH_ORG, current_plan: plan }];
    const { post } = setup({ tables });

    const res = await post({ userId: USER_ID });

    expect(((await res.json()) as CreatedKey).tier).toBe('starter');
  });

  it('falls back to starter when the organization row does not exist', async () => {
    const tables = baseTables();
    tables.organizations = [];
    const { post } = setup({ tables });

    const res = await post({ userId: USER_ID });

    expect(res.status).toBe(201);
    expect(((await res.json()) as CreatedKey).tier).toBe('starter');
  });

  // TS20: a database failure on the org lookup must surface as 5xx rather than
  // silently downgrading the key to starter tier.
  it('answers 503 and mints nothing when the organizations lookup fails', async () => {
    const { backend, post } = setup();
    backend.fail('select:organizations', { kind: 'http', status: 500, body: { message: 'db down' } });

    const res = await post({ userId: USER_ID });

    expect(res.status).toBe(503);
    expectNothingMinted(backend);
  });

  // TS21: current_plan comparison is case-insensitive; stripe-webhook writes the
  // plan as-is, but the UA04 trigger lower-cases before writing users.tier, so a
  // "Growth" or "ENTERPRISE" value in the DB must still produce the right tier.
  it.each([
    ['Growth', 'growth'],
    ['ENTERPRISE', 'enterprise'],
    ['STARTER', 'starter'],
  ])('treats a mixed-case plan "%s" as "%s"', async (plan, expectedTier) => {
    const tables = baseTables();
    tables.organizations = [{ id: GROWTH_ORG, current_plan: plan }];
    const { post } = setup({ tables });

    const res = await post({ userId: USER_ID });

    expect(((await res.json()) as CreatedKey).tier).toBe(expectedTier);
  });
});

describe('api-keys-create: the minted key', () => {
  it('returns a token the caller can use, and stores only its hash', async () => {
    const { backend, post } = setup();

    const res = await post({ userId: USER_ID, name: 'CI key' });
    const body = (await res.json()) as CreatedKey;

    expect(res.status).toBe(201);
    expect(body.token).toMatch(TOKEN_PATTERN);
    expect(body.prefix).toBe(body.token.slice('obtk_'.length, 'obtk_'.length + 8));
    const [row] = backend.rows('api_keys');
    expect(row).toMatchObject({
      id: body.keyId,
      user_id: USER_ID,
      organization_id: GROWTH_ORG,
      prefix: body.prefix,
      hash: sha256Hex(body.token),
      name: 'CI key',
      tier: 'growth',
      status: 'active',
    });
    expect(JSON.stringify(row)).not.toContain(body.token);
  });

  it('answers with exactly the created key\'s fields', async () => {
    const { post } = setup();

    const res = await post({ userId: USER_ID, name: 'CI key' });

    expect(Object.keys(await res.json()).sort()).toEqual(['keyId', 'name', 'prefix', 'tier', 'token']);
  });

  it('mints a different token on every call', async () => {
    const { backend, post } = setup();

    const first = (await (await post({ userId: USER_ID })).json()) as CreatedKey;
    const second = (await (await post({ userId: USER_ID })).json()) as CreatedKey;

    expect(first.token).not.toBe(second.token);
    expect(backend.rows('api_keys')).toHaveLength(2);
  });

  it('syncs the key to the AUTH KV namespace under its hash, with the org the readers require', async () => {
    const { backend, post } = setup();

    const body = (await (await post({ userId: USER_ID })).json()) as CreatedKey;

    expect(kvRecord(backend, body.token)).toEqual({
      tier: 'growth',
      status: 'active',
      userId: USER_ID,
      keyId: body.keyId,
      prefix: body.prefix,
      organizationId: GROWTH_ORG,
    });
    const entry = backend.kvEntry(CF_ACCOUNT_ID, KV_NAMESPACE_ID, `apikey:${sha256Hex(body.token)}`);
    expect(entry?.value).not.toContain(body.token);
  });
});

describe('api-keys-create: key name', () => {
  it.each([
    ['absent', undefined, DEFAULT_NAME],
    ['not a string', 7, DEFAULT_NAME],
    // TS21: a whitespace-only name is truthy but trims to ""; fall back to "Default"
    // rather than storing an empty string.
    ['whitespace-only', '   ', DEFAULT_NAME],
    ['padded with spaces', '  deploy bot  ', 'deploy bot'],
    ['exactly the maximum length', 'n'.repeat(MAX_NAME_LENGTH), 'n'.repeat(MAX_NAME_LENGTH)],
    ['one past the maximum length', 'n'.repeat(MAX_NAME_LENGTH + 1), 'n'.repeat(MAX_NAME_LENGTH)],
  ])('stores the name when it is %s', async (_label, name, expected) => {
    const { backend, post } = setup();

    const res = await post({ userId: USER_ID, name });

    expect(((await res.json()) as CreatedKey).name).toBe(expected);
    expect(backend.rows('api_keys')[0].name).toBe(expected);
  });
});

describe('api-keys-create: downstream failures', () => {
  it.each(['CLOUDFLARE_ACCOUNT_ID', 'CLOUDFLARE_API_TOKEN', 'KV_NAMESPACE_ID'])(
    'refuses with 500 and writes no key row when %s is unset',
    async (name) => {
      const { backend, post } = setup({ env: { [name]: undefined } });

      const res = await post({ userId: USER_ID });

      expect(res.status).toBe(500);
      expect(await res.json()).toEqual({ error: 'Server misconfigured: missing Cloudflare credentials' });
      expectNothingMinted(backend);
    },
  );

  it('answers 500 and syncs nothing to KV when the key row cannot be inserted', async () => {
    const { backend, post } = setup();
    backend.fail('insert:api_keys', {
      kind: 'http',
      status: 409,
      body: { code: '23505', message: 'duplicate key value violates unique constraint "api_keys_hash_key"' },
    });

    const res = await post({ userId: USER_ID });

    expect(res.status).toBe(500);
    expect(((await res.json()) as { error: string }).error).toContain('duplicate key value');
    expectNothingMinted(backend);
  });

  it('still returns the token, with a warning, when KV rejects the write', async () => {
    const { backend, post } = setup();
    backend.fail('kv', { kind: 'http', status: 500, body: { success: false, errors: [{ code: 10001 }] } });

    const res = await post({ userId: USER_ID });
    const body = (await res.json()) as CreatedKey;

    expect(res.status).toBe(201);
    expect(body.token).toMatch(TOKEN_PATTERN);
    expect(body.warning).toBe('API key created but KV sync failed. Key may not work immediately.');
    expect(backend.rows('api_keys')).toHaveLength(1);
  });

  // Regression (BACKLOG.md TS19): a network failure used to throw AFTER the api_keys row
  // was inserted, so the caller got a 500 with no token and the active row was orphaned.
  it('still returns the token, with a warning, when KV is unreachable', async () => {
    const { backend, post } = setup();
    backend.fail('kv', { kind: 'network' });

    const res = await post({ userId: USER_ID });
    const body = (await res.json()) as CreatedKey;

    expect(res.status).toBe(201);
    expect(body.token).toMatch(TOKEN_PATTERN);
    expect(body.warning).toBe('API key created but KV sync failed. Key may not work immediately.');
    expect(backend.rows('api_keys')).toHaveLength(1);
  });
});
