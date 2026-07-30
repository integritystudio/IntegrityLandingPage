import { describe, it, expect, beforeEach, vi, afterEach } from 'vitest';
import {
  checkIdentityRateLimit,
  resetIdentityRateLimit,
  IDENTITY_RATE_LIMIT_MAX,
  IDENTITY_RATE_LIMIT_WINDOW_SECONDS,
} from './rate-limit';

const IDENTITY = 'auth0|subject-1';

/** Minimal in-memory KVNamespace double — only get/put are exercised. */
function makeKv(overrides: Partial<KVNamespace> = {}): KVNamespace {
  const store = new Map<string, string>();
  return {
    get: (async (key: string) => {
      const raw = store.get(key);
      return raw === undefined ? null : JSON.parse(raw);
    }) as unknown as KVNamespace['get'],
    put: (async (key: string, value: string) => {
      store.set(key, value);
    }) as unknown as KVNamespace['put'],
    ...overrides,
  } as KVNamespace;
}

beforeEach(() => {
  resetIdentityRateLimit();
});

afterEach(() => {
  vi.restoreAllMocks();
});

describe('checkIdentityRateLimit', () => {
  it('allows requests below the limit', async () => {
    const env = { RATE_LIMIT_KV: makeKv() };
    for (let i = 0; i < IDENTITY_RATE_LIMIT_MAX; i++) {
      expect((await checkIdentityRateLimit(IDENTITY, env)).allowed).toBe(true);
    }
  });

  it('denies once the limit is exceeded, with a retry hint inside the window', async () => {
    const env = { RATE_LIMIT_KV: makeKv() };
    for (let i = 0; i < IDENTITY_RATE_LIMIT_MAX; i++) {
      await checkIdentityRateLimit(IDENTITY, env);
    }

    const result = await checkIdentityRateLimit(IDENTITY, env);

    expect(result.allowed).toBe(false);
    if (!result.allowed) {
      expect(result.retryAfterSeconds).toBeGreaterThan(0);
      expect(result.retryAfterSeconds).toBeLessThanOrEqual(IDENTITY_RATE_LIMIT_WINDOW_SECONDS);
    }
  });

  // The whole point of keying on the subject: one caller hitting the limit must not lock out
  // everyone else, which an IP-keyed limit would do to users behind a shared NAT.
  it('counts each identity independently', async () => {
    const env = { RATE_LIMIT_KV: makeKv() };
    for (let i = 0; i <= IDENTITY_RATE_LIMIT_MAX; i++) {
      await checkIdentityRateLimit(IDENTITY, env);
    }
    expect((await checkIdentityRateLimit(IDENTITY, env)).allowed).toBe(false);
    expect((await checkIdentityRateLimit('auth0|subject-2', env)).allowed).toBe(true);
  });

  // An unbound namespace must not switch limiting off — the in-memory tier still denies. This
  // is the degraded mode, not a bypass.
  it('still limits per isolate when RATE_LIMIT_KV is unbound', async () => {
    vi.spyOn(console, 'warn').mockImplementation(() => {});
    for (let i = 0; i < IDENTITY_RATE_LIMIT_MAX; i++) {
      expect((await checkIdentityRateLimit(IDENTITY, {})).allowed).toBe(true);
    }
    expect((await checkIdentityRateLimit(IDENTITY, {})).allowed).toBe(false);
  });

  it('warns once per isolate about the unbound namespace, not once per request', async () => {
    const warn = vi.spyOn(console, 'warn').mockImplementation(() => {});
    await checkIdentityRateLimit(IDENTITY, {});
    await checkIdentityRateLimit('auth0|subject-3', {});
    await checkIdentityRateLimit('auth0|subject-4', {});
    expect(warn).toHaveBeenCalledTimes(1);
  });

  // A KV outage is not fail-open: the in-memory tier has already counted the request, so the
  // check degrades to the weaker count rather than admitting everything.
  it('degrades to the in-memory count when KV throws', async () => {
    vi.spyOn(console, 'error').mockImplementation(() => {});
    const env = {
      RATE_LIMIT_KV: makeKv({
        get: (async () => {
          throw new Error('kv unavailable');
        }) as unknown as KVNamespace['get'],
      }),
    };

    for (let i = 0; i < IDENTITY_RATE_LIMIT_MAX; i++) {
      expect((await checkIdentityRateLimit(IDENTITY, env)).allowed).toBe(true);
    }
    expect((await checkIdentityRateLimit(IDENTITY, env)).allowed).toBe(false);
  });

  // KV is the cross-isolate authority: a fresh isolate (empty in-memory map) must still see a
  // count recorded elsewhere, otherwise spreading requests across colos evades the limit.
  it('denies a fresh isolate when the KV count is already over the limit', async () => {
    const kv = makeKv();
    await kv.put(
      `gw_id_rl:${IDENTITY}`,
      JSON.stringify({
        count: IDENTITY_RATE_LIMIT_MAX + 5,
        resetAt: Date.now() + IDENTITY_RATE_LIMIT_WINDOW_SECONDS * 1000,
      }),
    );

    // Simulates a different isolate: in-memory state cleared, KV state retained.
    resetIdentityRateLimit();

    const result = await checkIdentityRateLimit(IDENTITY, { RATE_LIMIT_KV: kv });
    expect(result.allowed).toBe(false);
  });

  it('starts a new window once the stored one has expired', async () => {
    const kv = makeKv();
    await kv.put(
      `gw_id_rl:${IDENTITY}`,
      JSON.stringify({ count: IDENTITY_RATE_LIMIT_MAX + 5, resetAt: Date.now() - 1000 }),
    );
    resetIdentityRateLimit();

    expect((await checkIdentityRateLimit(IDENTITY, { RATE_LIMIT_KV: kv })).allowed).toBe(true);
  });
});
