import { describe, it, expect, beforeEach, vi, afterEach } from 'vitest';
import {
  checkIdentityRateLimit,
  resetIdentityRateLimit,
  IDENTITY_RATE_LIMIT_MAX,
  IDENTITY_RATE_LIMIT_WINDOW_SECONDS,
  checkOrgRateLimit,
  resetOrgRateLimit,
  ORG_RATE_LIMIT_MAX,
  ORG_RATE_LIMIT_WINDOW_SECONDS,
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
// pruneExpired/pruneOrgExpired are called on every cache miss. They delete
// entries whose resetAt has passed and, as a backstop, call clear() when the
// map exceeds MAX_TRACKED_IDENTITIES / MAX_TRACKED_ORGS (10,000 each). Neither
// path was exercised by any test before TS24.

describe('TS24: memory bounds', () => {
  it('pruneExpired deletes expired in-memory identity windows', async () => {
    vi.useFakeTimers();
    try {
      vi.spyOn(console, 'warn').mockImplementation(() => {});

      // Hit the per-identity limit (no KV → in-memory only).
      for (let i = 0; i < IDENTITY_RATE_LIMIT_MAX; i++) {
        await checkIdentityRateLimit('prune-id-A', {});
      }
      expect((await checkIdentityRateLimit('prune-id-A', {})).allowed).toBe(false);

      // Advance the fake clock past the window — prune-id-A's entry is now expired.
      vi.advanceTimersByTime(IDENTITY_RATE_LIMIT_WINDOW_SECONDS * 1000 + 1);

      // A new-identity miss triggers pruneExpired, which deletes the stale entry.
      await checkIdentityRateLimit('prune-id-B', {});

      // prune-id-A's window was deleted; a fresh count-1 window starts → allowed.
      expect((await checkIdentityRateLimit('prune-id-A', {})).allowed).toBe(true);
    } finally {
      vi.useRealTimers();
    }
  });

  // The 10,000-entry cap is a backstop for the pathological case where every
  // request carries a fresh identity and none ever expire. When the map exceeds
  // the threshold, pruneExpired calls inMemoryWindows.clear(). This test fills
  // the map past that threshold and verifies that a previously-denied identity
  // is allowed again after the clear.
  it('pruneExpired: the 10,000-entry cap clears all in-memory windows', async () => {
    vi.spyOn(console, 'warn').mockImplementation(() => {});

    // Hit the limit for identity 0 so we can prove it was cleared.
    for (let i = 0; i < IDENTITY_RATE_LIMIT_MAX; i++) {
      await checkIdentityRateLimit('cap-id-0', {});
    }
    expect((await checkIdentityRateLimit('cap-id-0', {})).allowed).toBe(false);

    // Fill 10,000 more distinct identities — map now holds 10,001 entries.
    for (let i = 1; i <= 10_000; i++) {
      await checkIdentityRateLimit(`cap-id-${i}`, {});
    }

    // The next new identity triggers pruneExpired: no entries expired, but
    // size 10,001 > MAX_TRACKED_IDENTITIES (10,000) → inMemoryWindows.clear().
    await checkIdentityRateLimit('cap-id-trigger', {});

    // cap-id-0's window was cleared; it now starts fresh and is allowed.
    expect((await checkIdentityRateLimit('cap-id-0', {})).allowed).toBe(true);
  }, 30_000); // Iterates ~50 M map entries; allow generous time.

  it('pruneOrgExpired deletes expired in-memory org windows', async () => {
    vi.useFakeTimers();
    try {
      vi.spyOn(console, 'warn').mockImplementation(() => {});

      for (let i = 0; i < ORG_RATE_LIMIT_MAX; i++) {
        await checkOrgRateLimit('prune-org-A', {});
      }
      expect((await checkOrgRateLimit('prune-org-A', {})).allowed).toBe(false);

      vi.advanceTimersByTime(ORG_RATE_LIMIT_WINDOW_SECONDS * 1000 + 1);

      await checkOrgRateLimit('prune-org-B', {});

      expect((await checkOrgRateLimit('prune-org-A', {})).allowed).toBe(true);
    } finally {
      vi.useRealTimers();
    }
  });

  it('pruneOrgExpired: the 10,000-entry cap clears all in-memory windows', async () => {
    vi.spyOn(console, 'warn').mockImplementation(() => {});

    for (let i = 0; i < ORG_RATE_LIMIT_MAX; i++) {
      await checkOrgRateLimit('cap-org-0', {});
    }
    expect((await checkOrgRateLimit('cap-org-0', {})).allowed).toBe(false);

    for (let i = 1; i <= 10_000; i++) {
      await checkOrgRateLimit(`cap-org-${i}`, {});
    }

    await checkOrgRateLimit('cap-org-trigger', {});

    expect((await checkOrgRateLimit('cap-org-0', {})).allowed).toBe(true);
  }, 30_000);
});
