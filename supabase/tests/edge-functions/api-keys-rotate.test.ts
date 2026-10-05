import { createHash } from 'node:crypto';
import { createClient } from '@supabase/supabase-js';
import { describe, expect, it } from 'vitest';
import { FAKE_SUPABASE_URL, FakeBackend, type Row } from './fake-backend';
import { createApiKeysRotateHandler } from '../../functions/api-keys-rotate/handler.ts';

// Server-to-server: the dashboard worker calls with its own sb_secret_ key, which is not the
// key the edge runtime injects, so the credential check is by capability, not equality.
const EDGE_RUNTIME_SERVICE_KEY = 'legacy-service-role-jwt';
const DASHBOARD_WORKER_KEY = 'sb_secret_dashboard_worker';
const PUBLISHABLE_KEY = 'sb_publishable_anon';
// A user's own token, the shape the function used to accept. It must now be refused.
const USER_JWT = `header.${Buffer.from(JSON.stringify({ sub: 'auth0|user-1' })).toString('base64')}.signature`;

const CF_ACCOUNT_ID = 'cf-account';
const CF_API_TOKEN = 'cf-kv-write-token';
const KV_NAMESPACE_ID = 'auth-kv-namespace';

const FUNCTION_URL = `${FAKE_SUPABASE_URL}/functions/v1/api-keys-rotate`;

const USER_ID = 'user-1';
const OTHER_USER_ID = 'user-2';
const KEY_ORG = 'org-of-the-key';
const OTHER_MEMBERSHIP_ORG = 'org-other-membership';
const OLD_KEY_ID = 'key-old';
const OLD_HASH = 'old-hash';
const OLD_KV_KEY = `apikey:${OLD_HASH}`;
const OLD_KV_VALUE = JSON.stringify({ status: 'active', organizationId: KEY_ORG });

const TOKEN_PATTERN = /^obtk_[0-9a-f]{64}$/;
const PREFIX_LENGTH = 8;
const TOKEN_PREFIX_LENGTH = 'obtk_'.length;

const BASE_ENV: Record<string, string> = {
  SUPABASE_URL: FAKE_SUPABASE_URL,
  SUPABASE_SERVICE_ROLE_KEY: EDGE_RUNTIME_SERVICE_KEY,
  CLOUDFLARE_ACCOUNT_ID: CF_ACCOUNT_ID,
  CLOUDFLARE_API_TOKEN: CF_API_TOKEN,
  KV_NAMESPACE_ID,
};

/**
 * USER_ID holds one active key in KEY_ORG, and is also a member of another org listed first,
 * so a handler that took the org from a membership instead of the old key would be caught.
 */
function baseTables(): Record<string, Row[]> {
  return {
    users: [{ id: USER_ID }, { id: OTHER_USER_ID }],
    organization_memberships: [
      { user_id: USER_ID, organization_id: OTHER_MEMBERSHIP_ORG, status: 'active' },
      { user_id: USER_ID, organization_id: KEY_ORG, status: 'active' },
    ],
    api_keys: [
      {
        id: OLD_KEY_ID,
        user_id: USER_ID,
        organization_id: KEY_ORG,
        hash: OLD_HASH,
        prefix: 'abcd1234',
        name: 'CI key',
        tier: 'growth',
        status: 'active',
      },
    ],
  };
}

interface SetupOptions {
  tables?: Record<string, Row[]>;
  env?: Record<string, string | undefined>;
}

function setup(options: SetupOptions = {}) {
  const backend = new FakeBackend({
    serviceKeys: [EDGE_RUNTIME_SERVICE_KEY, DASHBOARD_WORKER_KEY],
    cloudflareToken: CF_API_TOKEN,
    tables: options.tables ?? baseTables(),
  });
  backend.seedKv(CF_ACCOUNT_ID, KV_NAMESPACE_ID, OLD_KV_KEY, OLD_KV_VALUE);
  const env = { ...BASE_ENV, ...options.env };
  const handler = createApiKeysRotateHandler({
    env: (name) => env[name],
    fetch: backend.fetch,
    createClient,
  });

  const send = (init: RequestInit) => handler(new Request(FUNCTION_URL, init));
  const post = (body: unknown, authorization: string | null = `Bearer ${DASHBOARD_WORKER_KEY}`) =>
    send({
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        ...(authorization === null ? {} : { Authorization: authorization }),
      },
      body: typeof body === 'string' ? body : JSON.stringify(body),
    });

  const keyRow = (id: string) => backend.rows('api_keys').find((row) => row.id === id);
  const kvValue = (key: string) => backend.kvEntry(CF_ACCOUNT_ID, KV_NAMESPACE_ID, key)?.value;
  return { backend, send, post, keyRow, kvValue };
}

const VALID_BODY = { keyId: OLD_KEY_ID, userId: USER_ID };

function sha256Hex(input: string): string {
  return createHash('sha256').update(input).digest('hex');
}

describe('api-keys-rotate: trust boundary', () => {
  it.each([
    ['no credential', null],
    ["a user's own JWT", `Bearer ${USER_JWT}`],
    ['a publishable key', `Bearer ${PUBLISHABLE_KEY}`],
    ['an empty bearer', 'Bearer '],
  ])('refuses %s with 401 and changes nothing', async (_label, authorization) => {
    const { post, keyRow, kvValue, backend } = setup();

    const res = await post(VALID_BODY, authorization);

    expect(res.status).toBe(401);
    expect(keyRow(OLD_KEY_ID)?.status).toBe('active');
    expect(backend.rows('api_keys')).toHaveLength(1);
    expect(kvValue(OLD_KV_KEY)).toBe(OLD_KV_VALUE);
  });

  it('accepts a service key other than the one the runtime injects', async () => {
    const { post } = setup();

    const res = await post(VALID_BODY, `Bearer ${DASHBOARD_WORKER_KEY}`);

    expect(res.status).toBe(201);
  });

  it('answers 401 when the credential check cannot reach the Auth admin API', async () => {
    const { post, backend, keyRow } = setup();
    backend.fail('auth', { kind: 'network' });

    const res = await post(VALID_BODY);

    expect(res.status).toBe(401);
    expect(keyRow(OLD_KEY_ID)?.status).toBe('active');
  });
});

describe('api-keys-rotate: request shape', () => {
  it.each([
    ['invalid JSON', '{not json', 'Invalid JSON body'],
    ['a missing keyId', { userId: USER_ID }, 'keyId is required'],
    ['a missing userId', { keyId: OLD_KEY_ID }, 'userId is required'],
    ['a non-string userId', { keyId: OLD_KEY_ID, userId: 7 }, 'userId is required'],
  ])('answers 400 to %s', async (_label, body, message) => {
    const { post } = setup();

    const res = await post(body);

    expect(res.status).toBe(400);
    expect(await res.json()).toEqual({ error: message });
  });

  it('answers 405 to a GET', async () => {
    const { send } = setup();

    const res = await send({ method: 'GET', headers: { Authorization: `Bearer ${DASHBOARD_WORKER_KEY}` } });

    expect(res.status).toBe(405);
  });
});

describe('api-keys-rotate: which key', () => {
  it("refuses to rotate another user's key", async () => {
    const { post, keyRow } = setup();

    const res = await post({ keyId: OLD_KEY_ID, userId: OTHER_USER_ID });

    expect(res.status).toBe(404);
    expect(keyRow(OLD_KEY_ID)?.status).toBe('active');
  });

  it('refuses a key that is already revoked', async () => {
    const tables = baseTables();
    tables.api_keys[0].status = 'revoked';
    const { post, backend } = setup({ tables });

    const res = await post(VALID_BODY);

    expect(res.status).toBe(404);
    expect(backend.rows('api_keys')).toHaveLength(1);
  });
});

describe('api-keys-rotate: a successful rotation', () => {
  it('returns the new token once, with its id, the old id, its prefix and tier', async () => {
    const { post } = setup();

    const res = await post(VALID_BODY);
    const body = await res.json();

    expect(res.status).toBe(201);
    expect(body.token).toMatch(TOKEN_PATTERN);
    expect(body.previousKeyId).toBe(OLD_KEY_ID);
    expect(body.prefix).toBe(body.token.slice(TOKEN_PREFIX_LENGTH, TOKEN_PREFIX_LENGTH + PREFIX_LENGTH));
    expect(body.tier).toBe('growth');
    expect(body.keyId).not.toBe(OLD_KEY_ID);
  });

  it("stores the new key in the old key's org, with its name and tier, keyed by the token's hash", async () => {
    const { post, keyRow } = setup();

    const body = await (await post(VALID_BODY)).json();
    const row = keyRow(body.keyId);

    expect(row).toMatchObject({
      user_id: USER_ID,
      organization_id: KEY_ORG,
      name: 'CI key',
      tier: 'growth',
      status: 'active',
      prefix: body.prefix,
      hash: sha256Hex(body.token),
    });
  });

  it('writes the new KV record with the org, and revokes the old key in both places', async () => {
    const { post, keyRow, kvValue } = setup();

    const body = await (await post(VALID_BODY)).json();

    expect(JSON.parse(kvValue(`apikey:${sha256Hex(body.token)}`) ?? 'null')).toEqual({
      tier: 'growth',
      status: 'active',
      userId: USER_ID,
      keyId: body.keyId,
      prefix: body.prefix,
      organizationId: KEY_ORG,
    });
    expect(keyRow(OLD_KEY_ID)?.status).toBe('revoked');
    expect(keyRow(OLD_KEY_ID)?.revoked_at).toEqual(expect.any(String));
    expect(kvValue(OLD_KV_KEY)).toBeUndefined();
  });

  it('still succeeds when the old KV record cannot be deleted, with the old row revoked', async () => {
    const { post, backend, keyRow, kvValue } = setup();
    backend.fail('kv-delete', { kind: 'http', status: 500, body: { success: false } });

    const res = await post(VALID_BODY);

    expect(res.status).toBe(201);
    expect(keyRow(OLD_KEY_ID)?.status).toBe('revoked');
    expect(kvValue(OLD_KV_KEY)).toBe(OLD_KV_VALUE);
  });
});

describe('api-keys-rotate: a failure leaves the old key working', () => {
  it.each([
    ['an http error', { kind: 'http', status: 500, body: { success: false } } as const],
    ['a network error', { kind: 'network' } as const],
  ])('rolls back the new row when the KV write fails with %s', async (_label, failure) => {
    const { post, backend, keyRow, kvValue } = setup();
    backend.fail('kv', failure);

    const res = await post(VALID_BODY);

    expect(res.status).toBe(500);
    expect(backend.rows('api_keys')).toHaveLength(1);
    expect(keyRow(OLD_KEY_ID)?.status).toBe('active');
    expect(kvValue(OLD_KV_KEY)).toBe(OLD_KV_VALUE);
  });

  it('answers 500 and changes nothing when the insert fails', async () => {
    const { post, backend, keyRow, kvValue } = setup();
    backend.fail('insert:api_keys', { kind: 'http', status: 500, body: { message: 'insert failed' } });

    const res = await post(VALID_BODY);

    expect(res.status).toBe(500);
    expect(backend.rows('api_keys')).toHaveLength(1);
    expect(keyRow(OLD_KEY_ID)?.status).toBe('active');
    expect(kvValue(OLD_KV_KEY)).toBe(OLD_KV_VALUE);
  });

  it('answers 500 before writing anything when Cloudflare credentials are missing', async () => {
    const { post, backend, keyRow } = setup({ env: { KV_NAMESPACE_ID: undefined } });

    const res = await post(VALID_BODY);

    expect(res.status).toBe(500);
    expect(backend.rows('api_keys')).toHaveLength(1);
    expect(keyRow(OLD_KEY_ID)?.status).toBe('active');
  });
});
