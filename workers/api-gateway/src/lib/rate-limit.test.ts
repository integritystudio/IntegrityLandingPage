import { describe, it, expect, beforeEach, vi, afterEach } from 'vitest';
import {
  checkIdentityRateLimit,
  resetIdentityRateLimit,
  IDENTITY_RATE_LIMIT_MAX,
  IDENTITY_RATE_LIMIT_WINDOW_SECONDS,
  MAX_TRACKED_IDENTITIES,
  checkOrgRateLimit,
  resetOrgRateLimit,
  ORG_RATE_LIMIT_MAX,
  ORG_RATE_LIMIT_WINDOW_SECONDS,
  MAX_TRACKED_ORGS,
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

// ---------------------------------------------------------------------------
// checkOrgRateLimit (CR36)
// ---------------------------------------------------------------------------

const ORG_ID = 'org-uuid-1';

beforeEach(() => {
  resetOrgRateLimit();
});

describe('checkOrgRateLimit', () => {
  it('allows requests below the limit', async () => {
    const env = { RATE_LIMIT_KV: makeKv() };
    for (let i = 0; i < ORG_RATE_LIMIT_MAX; i++) {
      expect((await checkOrgRateLimit(ORG_ID, env)).allowed).toBe(true);
    }
  });

  it('denies once the limit is exceeded, with a retry hint inside the window', async () => {
    const env = { RATE_LIMIT_KV: makeKv() };
    for (let i = 0; i < ORG_RATE_LIMIT_MAX; i++) {
      await checkOrgRateLimit(ORG_ID, env);
    }

    const result = await checkOrgRateLimit(ORG_ID, env);

    expect(result.allowed).toBe(false);
    if (!result.allowed) {
      expect(result.retryAfterSeconds).toBeGreaterThan(0);
      expect(result.retryAfterSeconds).toBeLessThanOrEqual(ORG_RATE_LIMIT_WINDOW_SECONDS);
    }
  });

  it('counts each org independently', async () => {
    const env = { RATE_LIMIT_KV: makeKv() };
    for (let i = 0; i <= ORG_RATE_LIMIT_MAX; i++) {
      await checkOrgRateLimit(ORG_ID, env);
    }
    expect((await checkOrgRateLimit(ORG_ID, env)).allowed).toBe(false);
    expect((await checkOrgRateLimit('org-uuid-2', env)).allowed).toBe(true);
  });

  it('still limits per isolate when RATE_LIMIT_KV is unbound', async () => {
    vi.spyOn(console, 'warn').mockImplementation(() => {});
    for (let i = 0; i < ORG_RATE_LIMIT_MAX; i++) {
      expect((await checkOrgRateLimit(ORG_ID, {})).allowed).toBe(true);
    }
    expect((await checkOrgRateLimit(ORG_ID, {})).allowed).toBe(false);
  });

  it('warns once per isolate about the unbound namespace, not once per request', async () => {
    const warn = vi.spyOn(console, 'warn').mockImplementation(() => {});
    await checkOrgRateLimit(ORG_ID, {});
    await checkOrgRateLimit('org-uuid-3', {});
    await checkOrgRateLimit('org-uuid-4', {});
    expect(warn).toHaveBeenCalledTimes(1);
  });

  it('degrades to the in-memory count when KV throws', async () => {
    vi.spyOn(console, 'error').mockImplementation(() => {});
    const env = {
      RATE_LIMIT_KV: makeKv({
        get: (async () => {
          throw new Error('kv unavailable');
        }) as unknown as KVNamespace['get'],
      }),
    };

    for (let i = 0; i < ORG_RATE_LIMIT_MAX; i++) {
      expect((await checkOrgRateLimit(ORG_ID, env)).allowed).toBe(true);
    }
    expect((await checkOrgRateLimit(ORG_ID, env)).allowed).toBe(false);
  });

  it('denies a fresh isolate when the KV count is already over the limit', async () => {
    const kv = makeKv();
    await kv.put(
      `gw_org_rl:${ORG_ID}`,
      JSON.stringify({
        count: ORG_RATE_LIMIT_MAX + 5,
        resetAt: Date.now() + ORG_RATE_LIMIT_WINDOW_SECONDS * 1000,
      }),
    );

    resetOrgRateLimit();

    const result = await checkOrgRateLimit(ORG_ID, { RATE_LIMIT_KV: kv });
    expect(result.allowed).toBe(false);
  });

  it('starts a new window once the stored one has expired', async () => {
    const kv = makeKv();
    await kv.put(
      `gw_org_rl:${ORG_ID}`,
      JSON.stringify({ count: ORG_RATE_LIMIT_MAX + 5, resetAt: Date.now() - 1000 }),
    );
    resetOrgRateLimit();

    expect((await checkOrgRateLimit(ORG_ID, { RATE_LIMIT_KV: kv })).allowed).toBe(true);
  });
});

// ---------------------------------------------------------------------------
// TS24: memory bounds — pruneExpired and pruneOrgExpired
// ---------------------------------------------------------------------------
// Both prunes run on every in-memory miss: they delete windows whose resetAt
// has passed, then clear() the whole map once it exceeds its cap. An expired
// window starts fresh on read whether or not it was pruned, so deletion is
// only observable through the cap: a leaked window counts toward it, and the
// clear() it triggers wipes live windows too.

const LIMITERS = [
  {
    name: 'checkIdentityRateLimit',
    check: checkIdentityRateLimit,
    max: IDENTITY_RATE_LIMIT_MAX,
    windowMs: IDENTITY_RATE_LIMIT_WINDOW_SECONDS * 1000,
    cap: MAX_TRACKED_IDENTITIES,
  },
  {
    name: 'checkOrgRateLimit',
    check: checkOrgRateLimit,
    max: ORG_RATE_LIMIT_MAX,
    windowMs: ORG_RATE_LIMIT_WINDOW_SECONDS * 1000,
    cap: MAX_TRACKED_ORGS,
  },
] as const;

/** Each miss scans the whole map, so filling one to its cap is quadratic. */
const CAP_TEST_TIMEOUT_MS = 30_000;

describe.each(LIMITERS)('TS24: $name memory bounds', ({ check, max, windowMs, cap }) => {
  beforeEach(() => {
    vi.spyOn(console, 'warn').mockImplementation(() => {});
  });

  async function exhaust(key: string): Promise<void> {
    for (let i = 0; i < max; i++) await check(key, {});
  }

  async function fill(prefix: string, count: number): Promise<void> {
    for (let i = 0; i < count; i++) await check(`${prefix}-${i}`, {});
  }

  it('deletes expired windows, and keeps live ones until the map exceeds the cap', async () => {
    vi.useFakeTimers();
    try {
      await fill('stale', cap);
      vi.advanceTimersByTime(windowMs + 1);

      // The first miss after expiry prunes every stale window.
      await exhaust('live');
      expect((await check('live', {})).allowed).toBe(false);

      // The last of these misses sees exactly `cap` windows, so none may clear the
      // map. Had the stale windows leaked, the first one would have.
      await fill('fresh', cap);
      expect((await check('live', {})).allowed).toBe(false);
    } finally {
      vi.useRealTimers();
    }
  }, CAP_TEST_TIMEOUT_MS);

  it('clears every window once the map exceeds the cap', async () => {
    await exhaust('live');
    expect((await check('live', {})).allowed).toBe(false);

    await fill('filler', cap); // the map now holds cap + 1 live windows
    await check('trigger', {}); // a miss over the cap clears the map

    expect((await check('live', {})).allowed).toBe(true);
  }, CAP_TEST_TIMEOUT_MS);
});
