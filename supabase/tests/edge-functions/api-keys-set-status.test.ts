import { createClient } from '@supabase/supabase-js';
import { describe, expect, it } from 'vitest';
import { FAKE_SUPABASE_URL, FakeBackend, type Row } from './fake-backend';
import { createApiKeysSetStatusHandler } from '../../functions/api-keys-set-status/handler.ts';

const SERVICE_KEY = 'sb_secret_operator';
const PUBLISHABLE_KEY = 'sb_publishable_anon';
const CF_ACCOUNT_ID = 'cf-account';
const CF_API_TOKEN = 'cf-kv-token';
const KV_NAMESPACE_ID = 'auth-kv-namespace';
const FUNCTION_URL = `${FAKE_SUPABASE_URL}/functions/v1/api-keys-set-status`;

const ACTIVE_HASH = 'a'.repeat(64);
const INACTIVE_HASH = 'b'.repeat(64);
const REVOKED_HASH = 'c'.repeat(64);
const ORPHAN_HASH = 'd'.repeat(64);
const HOME_HASH = 'e'.repeat(64);
const LEGACY_HASH = 'f'.repeat(64);

const ORG = 'org-1';

function baseTables(): Record<string, Row[]> {
  return {
    api_keys: [
      { id: 'key-active', hash: ACTIVE_HASH, status: 'active' },
      { id: 'key-inactive', hash: INACTIVE_HASH, status: 'inactive' },
      { id: 'key-revoked', hash: REVOKED_HASH, status: 'revoked', revoked_at: '2026-09-01T00:00:00Z' },
    ],
  };
}

const record = (status: string, extra: Record<string, unknown> = {}) =>
  JSON.stringify({ tier: 'starter', status, userId: 'user-1', keyId: 'k', prefix: 'abcd1234', organizationId: ORG, ...extra });

interface SetupOptions {
  env?: Record<string, string | undefined>;
  kvListPageSize?: number;
  seed?: Record<string, string>;
}

function setup(options: SetupOptions = {}) {
  const backend = new FakeBackend({
    serviceKeys: [SERVICE_KEY],
    cloudflareToken: CF_API_TOKEN,
    tables: baseTables(),
    kvListPageSize: options.kvListPageSize,
  });
  const seed = options.seed ?? {
    [ACTIVE_HASH]: record('active'),
    [INACTIVE_HASH]: record('active'),
  };
  for (const [hash, value] of Object.entries(seed)) backend.seedKv(CF_ACCOUNT_ID, KV_NAMESPACE_ID, `apikey:${hash}`, value);

  const env: Record<string, string | undefined> = {
    SUPABASE_URL: FAKE_SUPABASE_URL,
    SUPABASE_SERVICE_ROLE_KEY: SERVICE_KEY,
    CLOUDFLARE_ACCOUNT_ID: CF_ACCOUNT_ID,
    CLOUDFLARE_API_TOKEN: CF_API_TOKEN,
    KV_NAMESPACE_ID,
    ...options.env,
  };
  const handler = createApiKeysSetStatusHandler({ env: (name) => env[name], fetch: backend.fetch, createClient });
  const post = (body: unknown, authorization: string | null = `Bearer ${SERVICE_KEY}`) =>
    handler(new Request(FUNCTION_URL, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json', ...(authorization === null ? {} : { Authorization: authorization }) },
      body: typeof body === 'string' ? body : JSON.stringify(body),
    }));
  const kvRecord = (hash: string) => {
    const entry = backend.kvEntry(CF_ACCOUNT_ID, KV_NAMESPACE_ID, `apikey:${hash}`);
    return entry && JSON.parse(entry.value);
  };
  const rowStatus = (id: string) => backend.rows('api_keys').find((r) => r.id === id)?.status;
  return { backend, post, kvRecord, rowStatus };
}

describe('api-keys-set-status — access', () => {
  it.each([
    ['no credential', null],
    ['a publishable key', `Bearer ${PUBLISHABLE_KEY}`],
  ])('answers 401 and changes nothing with %s', async (_label, authorization) => {
    const { post, rowStatus, kvRecord } = setup();

    const res = await post({ keyId: 'key-active', status: 'inactive' }, authorization);

    expect(res.status).toBe(401);
    expect(rowStatus('key-active')).toBe('active');
    expect(kvRecord(ACTIVE_HASH).status).toBe('active');
  });

  it.each([
    ['a missing keyId', { status: 'inactive' }],
    ['a status outside active/inactive', { keyId: 'key-active', status: 'revoked' }],
    ['a body that is not an object', '[1]'],
  ])('answers 400 for %s', async (_label, body) => {
    const { post } = setup();
    expect((await post(body)).status).toBe(400);
  });
});

describe('api-keys-set-status — one key', () => {
  it('sets the row and its KV record inactive, keeping the record\'s other fields', async () => {
    const { post, rowStatus, kvRecord } = setup();

    const res = await post({ keyId: 'key-active', status: 'inactive' });

    expect(res.status).toBe(200);
    expect(await res.json()).toMatchObject({ keyId: 'key-active', status: 'inactive', previousStatus: 'active', kv: 'updated' });
    expect(rowStatus('key-active')).toBe('inactive');
    expect(kvRecord(ACTIVE_HASH)).toMatchObject({ status: 'inactive', organizationId: ORG, tier: 'starter' });
  });

  it('switches an inactive key back on', async () => {
    const { post, rowStatus, kvRecord } = setup({ seed: { [INACTIVE_HASH]: record('inactive') } });

    const res = await post({ keyId: 'key-inactive', status: 'active' });

    expect(res.status).toBe(200);
    expect(rowStatus('key-inactive')).toBe('active');
    expect(kvRecord(INACTIVE_HASH).status).toBe('active');
  });

  it('refuses to touch a revoked key: revocation is permanent', async () => {
    const { post, rowStatus } = setup();

    const res = await post({ keyId: 'key-revoked', status: 'active' });

    expect(res.status).toBe(409);
    expect(rowStatus('key-revoked')).toBe('revoked');
  });

  it('answers 404 for an unknown key', async () => {
    const { post } = setup();
    expect((await post({ keyId: 'key-missing', status: 'inactive' })).status).toBe(404);
  });

  it('updates the row and reports a KV record that does not exist', async () => {
    const { post, rowStatus } = setup({ seed: {} });

    const res = await post({ keyId: 'key-active', status: 'inactive' });

    expect(await res.json()).toMatchObject({ kv: 'missing' });
    expect(rowStatus('key-active')).toBe('inactive');
  });

  it('leaves a legacy plain-string KV value alone', async () => {
    const { post, backend } = setup({ seed: { [ACTIVE_HASH]: 'valid' } });

    const res = await post({ keyId: 'key-active', status: 'inactive' });

    expect(await res.json()).toMatchObject({ kv: 'legacy' });
    expect(backend.kvEntry(CF_ACCOUNT_ID, KV_NAMESPACE_ID, `apikey:${ACTIVE_HASH}`)?.value).toBe('valid');
  });

  it('reports a failed KV write with a warning, and a second call completes it', async () => {
    const { post, backend, rowStatus, kvRecord } = setup();
    backend.fail('kv', { kind: 'http', status: 500, body: { success: false } }, 1);

    const first = await (await post({ keyId: 'key-active', status: 'inactive' })).json();
    expect(first).toMatchObject({ kv: 'failed', warning: expect.any(String) });
    expect(rowStatus('key-active')).toBe('inactive');

    const second = await (await post({ keyId: 'key-active', status: 'inactive' })).json();
    expect(second).toMatchObject({ kv: 'updated' });
    expect(kvRecord(ACTIVE_HASH).status).toBe('inactive');
  });

  it('answers 503 when the row cannot be updated, and leaves KV alone', async () => {
    const { post, backend, kvRecord } = setup();
    backend.fail('update:api_keys', { kind: 'http', status: 500, body: { message: 'db down' } });

    const res = await post({ keyId: 'key-active', status: 'inactive' });

    expect(res.status).toBe(503);
    expect(kvRecord(ACTIVE_HASH).status).toBe('active');
  });
});

describe('api-keys-set-status — reconcile', () => {
  const world = {
    [ACTIVE_HASH]: record('active'),
    [INACTIVE_HASH]: record('active'),
    [REVOKED_HASH]: record('active'),
    [ORPHAN_HASH]: record('active'),
    [HOME_HASH]: record('active', { organizationId: 'home' }),
    [LEGACY_HASH]: 'valid',
  };

  it('is a dry run unless told otherwise, and reports why each record would change', async () => {
    const { post, kvRecord } = setup({ seed: world });

    const body = await (await post({ action: 'reconcile' })).json();

    expect(body).toMatchObject({ dryRun: true, scanned: 6, unchanged: 1, legacy: 1, failed: 0 });
    expect(body.changes).toEqual(expect.arrayContaining([
      { key: INACTIVE_HASH.slice(0, 8), from: 'active', to: 'inactive', reason: 'row is inactive' },
      { key: REVOKED_HASH.slice(0, 8), from: 'active', to: 'inactive', reason: 'row is revoked' },
      { key: ORPHAN_HASH.slice(0, 8), from: 'active', to: 'inactive', reason: 'no api_keys row' },
      { key: HOME_HASH.slice(0, 8), from: 'active', to: 'inactive', reason: 'no api_keys row' },
    ]));
    expect(kvRecord(ORPHAN_HASH).status).toBe('active');
  });

  it('writes the statuses when dryRun is false, and never touches api_keys', async () => {
    const { post, kvRecord, backend } = setup({ seed: world });
    const rowsBefore = JSON.stringify(backend.rows('api_keys'));

    const body = await (await post({ action: 'reconcile', dryRun: false })).json();

    expect(body.changes.every((c: { applied?: boolean }) => c.applied === true)).toBe(true);
    expect(kvRecord(ORPHAN_HASH)).toMatchObject({ status: 'inactive', organizationId: ORG });
    expect(kvRecord(REVOKED_HASH).status).toBe('inactive');
    expect(kvRecord(ACTIVE_HASH).status).toBe('active');
    expect(JSON.stringify(backend.rows('api_keys'))).toBe(rowsBefore);
  });

  it('keeps a key listed in KV_ONLY_KEY_HASHES active', async () => {
    const { post, kvRecord } = setup({ seed: world, env: { KV_ONLY_KEY_HASHES: ` ${HOME_HASH.toUpperCase()} ` } });

    const body = await (await post({ action: 'reconcile', dryRun: false })).json();

    expect(body.changes.map((c: { key: string }) => c.key)).not.toContain(HOME_HASH.slice(0, 8));
    expect(kvRecord(HOME_HASH).status).toBe('active');
  });

  it('pages through the whole namespace', async () => {
    const { post } = setup({ seed: world, kvListPageSize: 2 });

    const body = await (await post({ action: 'reconcile' })).json();

    expect(body.scanned).toBe(6);
  });

  it('answers 503 when api_keys cannot be read, before writing anything', async () => {
    const { post, backend, kvRecord } = setup({ seed: world });
    backend.fail('select:api_keys', { kind: 'http', status: 500, body: { message: 'db down' } });

    const res = await post({ action: 'reconcile', dryRun: false });

    expect(res.status).toBe(503);
    expect(kvRecord(ORPHAN_HASH).status).toBe('active');
  });

  it('answers 502 when the namespace cannot be listed', async () => {
    const { post, backend } = setup({ seed: world });
    backend.fail('kv-list', { kind: 'network' });

    expect((await post({ action: 'reconcile' })).status).toBe(502);
  });
});
