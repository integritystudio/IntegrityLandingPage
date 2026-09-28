import { describe, it, expect, vi, afterEach } from 'vitest';
import {
  pollAuth0Logs,
  CHECKPOINT_KEY,
  TOKEN_KEY,
  LOGS_PAGE_SIZE,
  MAX_PAGES_PER_RUN,
  type Auth0LogPollerEnv,
} from './auth0-log-poller';

const DOMAIN = 'tenant.us.auth0.com';
const SUPABASE_URL = 'https://test.supabase.co';
const TOKEN_TTL_SECONDS = 86400;

/** In-memory KV that records the options each put was made with. */
function fakeKv(initial: Record<string, string> = {}) {
  const store = new Map(Object.entries(initial));
  const puts: Array<{ key: string; value: string; options?: KVNamespacePutOptions }> = [];
  const kv = {
    get: vi.fn(async (key: string) => store.get(key) ?? null),
    put: vi.fn(async (key: string, value: string, options?: KVNamespacePutOptions) => {
      store.set(key, value);
      puts.push({ key, value, options });
    }),
    delete: vi.fn(async (key: string) => { store.delete(key); }),
  };
  return { kv: kv as unknown as KVNamespace, store, puts };
}

const entry = (logId: string) => ({ log_id: logId, date: '2026-09-28T12:00:00.000Z', type: 'seccft', client_id: 'c1' });
const entries = (from: number, count: number) => Array.from({ length: count }, (_, i) => entry(`log-${String(from + i).padStart(4, '0')}`));

interface StubOptions {
  /** Pages served for successive GET /api/v2/logs calls. A number is an error status. */
  pages: Array<unknown[] | number>;
  insertStatus?: number;
}

function stubFetch({ pages, insertStatus = 201 }: StubOptions) {
  const calls = { token: 0, logs: [] as URL[], inserts: [] as unknown[] };
  let page = 0;
  vi.stubGlobal('fetch', vi.fn(async (input: RequestInfo | URL, init?: RequestInit) => {
    const url = new URL(String(input));
    if (url.pathname === '/oauth/token') {
      calls.token += 1;
      return Response.json({ access_token: 'minted-token', expires_in: TOKEN_TTL_SECONDS });
    }
    if (url.pathname === '/api/v2/logs') {
      calls.logs.push(url);
      const served = pages[page++] ?? [];
      return typeof served === 'number'
        ? new Response('{"message":"stubbed"}', { status: served })
        : Response.json(served);
    }
    if (url.pathname === '/rest/v1/auth0_logs') {
      calls.inserts.push(JSON.parse(String(init?.body)));
      return new Response(null, { status: insertStatus });
    }
    return new Response('unexpected', { status: 501 });
  }));
  return calls;
}

function makeEnv(kv: KVNamespace | undefined, overrides: Partial<Auth0LogPollerEnv> = {}): Auth0LogPollerEnv {
  return {
    auth0Domain: DOMAIN,
    clientId: 'reader-client',
    clientSecret: 'reader-secret',
    kv,
    supabaseUrl: SUPABASE_URL,
    serviceRoleKey: 'service-role-key',
    ...overrides,
  };
}

afterEach(() => {
  vi.unstubAllGlobals();
});

describe('pollAuth0Logs — configuration', () => {
  it.each([
    ['the client id is unbound', { clientId: undefined }],
    ['the client secret is unbound', { clientSecret: undefined }],
  ])('fails without a request when %s', async (_label, overrides) => {
    const calls = stubFetch({ pages: [] });

    const result = await pollAuth0Logs(makeEnv(fakeKv().kv, overrides));

    expect(result.status).toBe('failed');
    expect(calls.token + calls.logs.length).toBe(0);
  });

  it('fails without a request when there is no KV for the checkpoint', async () => {
    const calls = stubFetch({ pages: [] });

    const result = await pollAuth0Logs(makeEnv(undefined));

    expect(result.status).toBe('failed');
    expect(calls.token).toBe(0);
  });
});

describe('pollAuth0Logs — token', () => {
  it('mints a token once and caches it short of its expiry', async () => {
    const { kv, store, puts } = fakeKv();
    stubFetch({ pages: [[]] });

    await pollAuth0Logs(makeEnv(kv));

    expect(store.get(TOKEN_KEY)).toBe('minted-token');
    const ttl = puts.find((p) => p.key === TOKEN_KEY)?.options?.expirationTtl;
    expect(ttl).toBeGreaterThan(0);
    expect(ttl).toBeLessThan(TOKEN_TTL_SECONDS);
  });

  it('reuses a cached token without minting', async () => {
    const { kv } = fakeKv({ [TOKEN_KEY]: 'cached-token' });
    const calls = stubFetch({ pages: [[]] });

    await pollAuth0Logs(makeEnv(kv));

    expect(calls.token).toBe(0);
  });

  it('drops a cached token the logs API rejects, so the next run mints afresh', async () => {
    const { kv, store } = fakeKv({ [TOKEN_KEY]: 'revoked-token', [CHECKPOINT_KEY]: 'log-0001' });
    stubFetch({ pages: [401] });

    const result = await pollAuth0Logs(makeEnv(kv));

    expect(result.status).toBe('failed');
    expect(store.has(TOKEN_KEY)).toBe(false);
    expect(store.get(CHECKPOINT_KEY)).toBe('log-0001');
  });
});

describe('pollAuth0Logs — paging and checkpoint', () => {
  it('without a checkpoint, stores the newest page and checkpoints its head', async () => {
    const { kv, store } = fakeKv();
    // Newest first, as the API serves it when no `from` is given.
    const calls = stubFetch({ pages: [[entry('log-0003'), entry('log-0002'), entry('log-0001')]] });

    const result = await pollAuth0Logs(makeEnv(kv));

    expect(result).toEqual({ status: 'ok', inserted: 3, pages: 1 });
    expect(calls.logs[0].searchParams.has('from')).toBe(false);
    expect(store.get(CHECKPOINT_KEY)).toBe('log-0003');
  });

  it('with a checkpoint, pages forward from it and checkpoints the last entry', async () => {
    const { kv, store } = fakeKv({ [CHECKPOINT_KEY]: 'log-0001' });
    const calls = stubFetch({ pages: [[entry('log-0002'), entry('log-0003')]] });

    const result = await pollAuth0Logs(makeEnv(kv));

    expect(result).toEqual({ status: 'ok', inserted: 2, pages: 1 });
    expect(calls.logs[0].searchParams.get('from')).toBe('log-0001');
    expect(calls.logs[0].searchParams.get('take')).toBe(String(LOGS_PAGE_SIZE));
    expect(calls.inserts[0]).toEqual([
      expect.objectContaining({ log_id: 'log-0002', event_type: 'seccft', client_id: 'c1' }),
      expect.objectContaining({ log_id: 'log-0003' }),
    ]);
    expect(store.get(CHECKPOINT_KEY)).toBe('log-0003');
  });

  it('follows full pages until a short one', async () => {
    const { kv, store } = fakeKv({ [CHECKPOINT_KEY]: 'log-0000' });
    const calls = stubFetch({ pages: [entries(1, LOGS_PAGE_SIZE), entries(1 + LOGS_PAGE_SIZE, 2)] });

    const result = await pollAuth0Logs(makeEnv(kv));

    expect(result).toEqual({ status: 'ok', inserted: LOGS_PAGE_SIZE + 2, pages: 2 });
    expect(calls.logs[1].searchParams.get('from')).toBe(`log-${String(LOGS_PAGE_SIZE).padStart(4, '0')}`);
    expect(store.get(CHECKPOINT_KEY)).toBe(`log-${String(LOGS_PAGE_SIZE + 2).padStart(4, '0')}`);
  });

  it('stops after MAX_PAGES_PER_RUN full pages and leaves the rest for the next run', async () => {
    const { kv } = fakeKv({ [CHECKPOINT_KEY]: 'log-0000' });
    const full = Array.from({ length: MAX_PAGES_PER_RUN + 1 }, (_, i) => entries(1 + i * LOGS_PAGE_SIZE, LOGS_PAGE_SIZE));
    const calls = stubFetch({ pages: full });

    const result = await pollAuth0Logs(makeEnv(kv));

    expect(result.status).toBe('ok');
    expect(calls.logs).toHaveLength(MAX_PAGES_PER_RUN);
  });

  it('does not advance the checkpoint past rows it failed to store', async () => {
    const { kv, store } = fakeKv({ [CHECKPOINT_KEY]: 'log-0001' });
    stubFetch({ pages: [[entry('log-0002')]], insertStatus: 500 });

    const result = await pollAuth0Logs(makeEnv(kv));

    expect(result.status).toBe('failed');
    expect(store.get(CHECKPOINT_KEY)).toBe('log-0001');
  });

  it('skips an invalid entry but still checkpoints past it', async () => {
    const { kv, store } = fakeKv({ [CHECKPOINT_KEY]: 'log-0001' });
    const calls = stubFetch({ pages: [[entry('log-0002'), { log_id: 'log-0003' }]] });

    const result = await pollAuth0Logs(makeEnv(kv));

    expect(result).toEqual({ status: 'ok', inserted: 1, pages: 1 });
    expect(calls.inserts[0]).toEqual([expect.objectContaining({ log_id: 'log-0002' })]);
    expect(store.get(CHECKPOINT_KEY)).toBe('log-0003');
  });

  it('restarts from the newest page when the API rejects the checkpoint', async () => {
    const { kv, store } = fakeKv({ [CHECKPOINT_KEY]: 'not-a-log-id' });
    const calls = stubFetch({ pages: [400, [entry('log-0009'), entry('log-0008')]] });

    const result = await pollAuth0Logs(makeEnv(kv));

    expect(result).toEqual({ status: 'ok', inserted: 2, pages: 2 });
    expect(calls.logs[1].searchParams.has('from')).toBe(false);
    expect(store.get(CHECKPOINT_KEY)).toBe('log-0009');
  });

  it('writes nothing for an empty page', async () => {
    const { kv, store } = fakeKv({ [CHECKPOINT_KEY]: 'log-0001' });
    const calls = stubFetch({ pages: [[]] });

    const result = await pollAuth0Logs(makeEnv(kv));

    expect(result).toEqual({ status: 'ok', inserted: 0, pages: 1 });
    expect(calls.inserts).toHaveLength(0);
    expect(store.get(CHECKPOINT_KEY)).toBe('log-0001');
  });
});
