import { describe, it, expect, vi } from 'vitest';
import { QuotaDurableObject } from './quota';

// ---------------------------------------------------------------------------
// Minimal mock for DurableObjectState / DurableObjectStorage
// ---------------------------------------------------------------------------

class MockStorage {
  private store: Map<string, unknown> = new Map();

  async get<T>(key: string): Promise<T | undefined> {
    return this.store.get(key) as T | undefined;
  }

  async put(key: string, value: unknown): Promise<void> {
    this.store.set(key, value);
  }

  async delete(key: string): Promise<boolean> {
    return this.store.delete(key);
  }
}

interface QuotaState {
  orgId: string;
  planKey: string;
  quotaVersion: number;
  minuteLimit: number;
  monthlyLimit: number | null;
  minuteUsedAt: number;
  minuteUsed: number;
  monthlyUsed: number;
  lastMonthlyResetAt: number;
  seenRequestIds: Record<string, number>;
}

function makeDO(): { do_: QuotaDurableObject; storage: MockStorage } {
  const storage = new MockStorage();
  const state = {
    storage,
    blockConcurrencyWhile: async <T>(fn: () => Promise<T>) => fn(),
    waitUntil: (_p: Promise<unknown>) => undefined,
  } as unknown as DurableObjectState;
  return { do_: new QuotaDurableObject(state), storage };
}

/** Seed storage with a complete quota state record. */
async function seedQuota(storage: MockStorage, overrides: Partial<QuotaState> = {}): Promise<void> {
  const base: QuotaState = {
    orgId: 'org-1',
    planKey: 'starter',
    quotaVersion: 1,
    minuteLimit: 60,
    monthlyLimit: 10000,
    minuteUsedAt: Date.now() - 70_000, // expired minute window (forces reset)
    minuteUsed: 0,
    monthlyUsed: 0,
    lastMonthlyResetAt: Date.now(),
    seenRequestIds: {},
  };
  await storage.put('quota', { ...base, ...overrides });
}

// ---------------------------------------------------------------------------
// Request helpers
// ---------------------------------------------------------------------------

const BASE = 'http://quota.local';

function checkReq(overrides: Partial<{
  orgId: string;
  metricKey: string;
  units: number;
  requestId: string;
  planKey: string;
  quotaVersion: number;
}> = {}): Request {
  const body = {
    orgId: 'org-1',
    metricKey: 'requests',
    units: 1,
    requestId: crypto.randomUUID(),
    planKey: 'starter',
    quotaVersion: 1,
    ...overrides,
  };
  return new Request(`${BASE}/check-and-reserve`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify(body),
  });
}

function flushReq(): Request {
  return new Request(`${BASE}/flush-usage`, { method: 'POST' });
}

function statusReq(): Request {
  return new Request(`${BASE}/status`, { method: 'GET' });
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

describe('QuotaDurableObject', () => {
  describe('unknown routes', () => {
    it('returns 404 for unknown path', async () => {
      const { do_ } = makeDO();
      const res = await do_.fetch(new Request(`${BASE}/unknown`, { method: 'GET' }));
      expect(res.status).toBe(404);
    });
  });

  describe('checkAndReserve — validation', () => {
    it('returns 400 when required fields are missing', async () => {
      const { do_ } = makeDO();
      const res = await do_.fetch(new Request(`${BASE}/check-and-reserve`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ orgId: 'org-1' }),
      }));
      expect(res.status).toBe(400);
      const body = await res.json() as { error: string };
      expect(body.error).toBeTruthy();
    });

    it('returns 400 on malformed JSON body', async () => {
      const { do_ } = makeDO();
      const res = await do_.fetch(new Request(`${BASE}/check-and-reserve`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: 'not-json',
      }));
      expect(res.status).toBe(400);
    });
  });

  describe('checkAndReserve — default quota initialisation', () => {
    it('initialises free plan from DEFAULT_QUOTAS when org is new', async () => {
      const { do_ } = makeDO();
      const res = await do_.fetch(checkReq({ planKey: 'starter' }));
      expect(res.status).toBe(200);
      const body = await res.json() as { allowed: boolean; remainingMinute: number; remainingMonthly: number };
      expect(body.allowed).toBe(true);
      expect(body.remainingMinute).toBe(59); // 60 - 1
      expect(body.remainingMonthly).toBe(9999); // 10000 - 1
    });

    it('initialises growth plan limits (600 rpm, 500k monthly)', async () => {
      const { do_ } = makeDO();
      const res = await do_.fetch(checkReq({ planKey: 'growth' }));
      expect(res.status).toBe(200);
      const body = await res.json() as { allowed: boolean; remainingMinute: number; remainingMonthly: number };
      expect(body.remainingMinute).toBe(599);
      expect(body.remainingMonthly).toBe(499999);
    });

    it('falls back to free-plan limits for unknown plan keys', async () => {
      const { do_ } = makeDO();
      const res = await do_.fetch(checkReq({ planKey: 'unknown-plan' }));
      expect(res.status).toBe(200);
      const body = await res.json() as { allowed: boolean; remainingMinute: number };
      expect(body.allowed).toBe(true);
      expect(body.remainingMinute).toBe(59); // free fallback: 60 rpm
    });
  });

  describe('checkAndReserve — minute limit', () => {
    it('allows requests below the minute limit', async () => {
      const { do_ } = makeDO();
      for (let i = 0; i < 59; i++) {
        const res = await do_.fetch(checkReq());
        expect(res.status).toBe(200);
      }
    });

    it('rejects the request that exceeds the minute limit with reason "minute_limit"', async () => {
      const { do_ } = makeDO();
      for (let i = 0; i < 60; i++) {
        await do_.fetch(checkReq());
      }
      const res = await do_.fetch(checkReq());
      expect(res.status).toBe(429);
      const body = await res.json() as { allowed: boolean; reason: string; remainingMinute: number };
      expect(body.allowed).toBe(false);
      expect(body.reason).toBe('minute_limit');
      expect(body.remainingMinute).toBe(0);
    });

    it('returns 429 at exact boundary (minuteUsed + units > minuteLimit)', async () => {
      const { do_, storage } = makeDO();
      await seedQuota(storage, { minuteUsed: 60, minuteUsedAt: Date.now() });
      const res = await do_.fetch(checkReq({ units: 1 }));
      expect(res.status).toBe(429);
      const body = await res.json() as { reason: string };
      expect(body.reason).toBe('minute_limit');
    });

    it('resets minuteUsed after the 60-second window expires', async () => {
      const { do_ } = makeDO();
      for (let i = 0; i < 60; i++) {
        await do_.fetch(checkReq());
      }
      const spy = vi.spyOn(Date, 'now').mockReturnValue(Date.now() + 61_000);
      try {
        const res = await do_.fetch(checkReq());
        expect(res.status).toBe(200);
        const body = await res.json() as { allowed: boolean };
        expect(body.allowed).toBe(true);
      } finally {
        spy.mockRestore();
      }
    });
  });

  describe('checkAndReserve — monthly limit', () => {
    it('rejects when monthly limit is exceeded with reason "monthly_limit"', async () => {
      const { do_, storage } = makeDO();
      // Seed: 1 unit below limit; minute window already expired so minute check passes.
      await seedQuota(storage, { monthlyUsed: 9999, minuteUsedAt: Date.now() - 70_000 });
      const res = await do_.fetch(checkReq({ units: 2 })); // 9999 + 2 > 10000
      expect(res.status).toBe(429);
      const body = await res.json() as { allowed: boolean; reason: string; remainingMonthly: number };
      expect(body.allowed).toBe(false);
      expect(body.reason).toBe('monthly_limit');
      expect(body.remainingMonthly).toBe(1); // 10000 - 9999
    });

    it('resets monthly counter automatically on month boundary', async () => {
      const { do_, storage } = makeDO();
      // Use 40 days ago — guaranteed to be in a prior month regardless of current date.
      const fortyDaysAgo = Date.now() - 40 * 24 * 60 * 60 * 1000;
      await seedQuota(storage, {
        monthlyUsed: 10000,
        lastMonthlyResetAt: fortyDaysAgo,
        minuteUsedAt: Date.now() - 70_000,
      });
      const res = await do_.fetch(checkReq({ units: 1 }));
      expect(res.status).toBe(200);
      const body = await res.json() as { allowed: boolean };
      expect(body.allowed).toBe(true);
    });
  });

  describe('checkAndReserve — enterprise plan (unlimited monthly)', () => {
    it('allows requests when monthly limit is null (enterprise)', async () => {
      const { do_ } = makeDO();
      const res = await do_.fetch(checkReq({ planKey: 'enterprise', units: 5000 }));
      expect(res.status).toBe(200);
      const body = await res.json() as { allowed: boolean; remainingMonthly: null };
      expect(body.allowed).toBe(true);
      expect(body.remainingMonthly).toBeNull();
    });

    it('still enforces minute limit for enterprise plan', async () => {
      const { do_, storage } = makeDO();
      await seedQuota(storage, {
        planKey: 'enterprise',
        minuteLimit: 6000,
        monthlyLimit: null,
        minuteUsed: 6000,
        minuteUsedAt: Date.now(), // fresh window — would not expire
      });
      const res = await do_.fetch(checkReq({ planKey: 'enterprise', units: 1, quotaVersion: 1 }));
      expect(res.status).toBe(429);
      const body = await res.json() as { reason: string };
      expect(body.reason).toBe('minute_limit');
    });
  });

  describe('checkAndReserve — idempotency', () => {
    it('allows a duplicate requestId without double-counting usage', async () => {
      const { do_, storage } = makeDO();
      const requestId = crypto.randomUUID();
      const now = Date.now();

      // Seed storage with the requestId already in seenRequestIds and minuteUsed=5.
      // This simulates the state after a prior request was made and persisted.
      await seedQuota(storage, {
        minuteUsed: 5,
        minuteUsedAt: now,
        seenRequestIds: { [requestId]: now },
      });

      // Duplicate submission — should be allowed without counting again.
      const res = await do_.fetch(checkReq({ requestId }));
      expect(res.status).toBe(200);
      const body = await res.json() as { allowed: boolean };
      expect(body.allowed).toBe(true);

      // minuteUsed must remain 5 — no double-count.
      const status = await (await do_.fetch(statusReq())).json() as { minuteUsed: number };
      expect(status.minuteUsed).toBe(5);
    });

    it('treats expired requestIds as new (past 5-minute TTL)', async () => {
      const { do_, storage } = makeDO();
      const oldRequestId = crypto.randomUUID();
      const fiveMinAgo = Date.now() - 6 * 60_000;

      // Seed storage with an old seenRequestId that is past the TTL.
      await seedQuota(storage, {
        seenRequestIds: { [oldRequestId]: fiveMinAgo },
        minuteUsed: 5,
        minuteUsedAt: Date.now(),
      });

      // Send a new unique request to trigger cleanup, then confirm minuteUsed state.
      await do_.fetch(checkReq()); // triggers cleanup of old ids; minuteUsed = 6

      const statusBefore = await (await do_.fetch(statusReq())).json() as { minuteUsed: number };
      const usedBefore = statusBefore.minuteUsed;

      // Re-submit the old requestId — should be treated as new (not idempotent).
      await do_.fetch(checkReq({ requestId: oldRequestId }));

      const statusAfter = await (await do_.fetch(statusReq())).json() as { minuteUsed: number };
      expect(statusAfter.minuteUsed).toBe(usedBefore + 1);
    });
  });

  describe('checkAndReserve — quotaVersion bump', () => {
    it('resets minute counter and applies new plan limits when quotaVersion is bumped', async () => {
      const { do_, storage } = makeDO();
      // Seed: exhausted free plan at version 1.
      await seedQuota(storage, {
        planKey: 'starter',
        quotaVersion: 1,
        minuteLimit: 60,
        monthlyLimit: 10000,
        minuteUsed: 60,
        monthlyUsed: 9990,
        minuteUsedAt: Date.now(), // fresh window
      });
      // Bump version to 2 and upgrade to growth plan.
      const res = await do_.fetch(checkReq({ planKey: 'growth', quotaVersion: 2 }));
      expect(res.status).toBe(200);
      const body = await res.json() as { allowed: boolean; remainingMinute: number; remainingMonthly: number };
      expect(body.allowed).toBe(true);
      expect(body.remainingMinute).toBe(599); // growth 600 rpm - 1 (minute reset on bump)
      // monthlyUsed is preserved (9990 + 1 = 9991) so plan cycling cannot evade monthly limits.
      // remainingMonthly reflects the new growth limit (500000) minus carried-over usage.
      expect(body.remainingMonthly).toBe(500000 - 9991);
    });

    it('preserves monthlyUsed on quotaVersion bump to prevent quota evasion by plan cycling', async () => {
      const { do_, storage } = makeDO();
      // Seed: one slot below the monthly limit at version 1.
      // With monthlyLimit = 10000 and check being `> limit`, we need 10000 used before a request
      // is blocked (the 10001st request). Start at 9999 so the version-bump request uses the
      // last slot (9999 → 10000) and the very next request is blocked (10001 > 10000).
      await seedQuota(storage, {
        planKey: 'starter',
        quotaVersion: 1,
        minuteLimit: 60,
        monthlyLimit: 10000,
        minuteUsed: 10,
        monthlyUsed: 9999,
        minuteUsedAt: Date.now(),
      });
      // Bump to version 2, staying on starter — monthlyUsed should NOT reset.
      // This request uses the last slot: 9999 → 10000.
      await do_.fetch(checkReq({ planKey: 'starter', quotaVersion: 2 }));
      // Next request exceeds limit: 10000 + 1 = 10001 > 10000 → blocked.
      const res = await do_.fetch(checkReq({ planKey: 'starter', quotaVersion: 2 }));
      const body = await res.json() as { allowed: boolean };
      expect(body.allowed).toBe(false);
    });

    it('does not reset counters when quotaVersion is unchanged', async () => {
      const { do_, storage } = makeDO();
      await seedQuota(storage, {
        quotaVersion: 1,
        minuteUsed: 30,
        minuteUsedAt: Date.now(), // fresh window
      });
      const res = await do_.fetch(checkReq({ quotaVersion: 1 }));
      const body = await res.json() as { remainingMinute: number };
      expect(body.remainingMinute).toBe(29); // 60 - 30 - 1
    });
  });

  describe('/flush-usage', () => {
    it('returns 404 when called before any quota state is initialised', async () => {
      const { do_ } = makeDO();
      const res = await do_.fetch(flushReq());
      expect(res.status).toBe(404);
    });

    it('returns the monthly delta and resets the monthly counter', async () => {
      const { do_, storage } = makeDO();
      await seedQuota(storage, { monthlyUsed: 5 });
      const res = await do_.fetch(flushReq());
      expect(res.status).toBe(200);
      const body = await res.json() as { orgId: string; monthlyUsedSinceLastFlush: number; flushedAt: string };
      expect(body.orgId).toBe('org-1');
      expect(body.monthlyUsedSinceLastFlush).toBe(5);
      expect(typeof body.flushedAt).toBe('string');
    });

    it('resets monthlyUsed to 0 after flush', async () => {
      const { do_, storage } = makeDO();
      await seedQuota(storage, { monthlyUsed: 5 });
      await do_.fetch(flushReq());
      const status = await (await do_.fetch(statusReq())).json() as { monthlyUsed: number };
      expect(status.monthlyUsed).toBe(0);
    });
  });

  describe('/status', () => {
    it('returns { status: "uninitialized" } before any request', async () => {
      const { do_ } = makeDO();
      const res = await do_.fetch(statusReq());
      expect(res.status).toBe(200);
      const body = await res.json() as { status: string };
      expect(body.status).toBe('uninitialized');
    });

    it('returns current quota state after initialisation', async () => {
      const { do_, storage } = makeDO();
      await seedQuota(storage, { minuteUsed: 3, monthlyUsed: 3 });
      const res = await do_.fetch(statusReq());
      expect(res.status).toBe(200);
      const body = await res.json() as {
        orgId: string;
        planKey: string;
        minuteLimit: number;
        monthlyLimit: number;
        minuteUsed: number;
        monthlyUsed: number;
      };
      expect(body.orgId).toBe('org-1');
      expect(body.planKey).toBe('starter');
      expect(body.minuteLimit).toBe(60);
      expect(body.monthlyLimit).toBe(10000);
      expect(body.minuteUsed).toBe(3);
      expect(body.monthlyUsed).toBe(3);
    });
  });

  describe('storage persistence', () => {
    it('restores quota state from storage on second instance', async () => {
      const storage = new MockStorage();
      const makeState = () => ({
        storage,
        blockConcurrencyWhile: async <T>(fn: () => Promise<T>) => fn(),
        waitUntil: (_p: Promise<unknown>) => undefined,
      } as unknown as DurableObjectState);

      // First instance seeds and flushes (flush always persists to storage).
      const do1 = new QuotaDurableObject(makeState());
      await storage.put('quota', {
        orgId: 'org-1', planKey: 'starter', quotaVersion: 1,
        minuteLimit: 60, monthlyLimit: 10000,
        minuteUsedAt: Date.now() - 70_000, minuteUsed: 0,
        monthlyUsed: 42, lastMonthlyResetAt: Date.now(), seenRequestIds: {},
      });
      await do1.fetch(flushReq()); // saves with monthlyUsed reset to 0

      // Second instance should load flushed (persisted) state.
      const do2 = new QuotaDurableObject(makeState());
      const res = await do2.fetch(statusReq());
      const body = await res.json() as { monthlyUsed: number; orgId: string };
      expect(body.orgId).toBe('org-1');
      expect(body.monthlyUsed).toBe(0);
    });

    it('backfills missing fields on legacy stored state', async () => {
      const storage = new MockStorage();
      // Simulate stored state without lastMonthlyResetAt or seenRequestIds.
      await storage.put('quota', {
        orgId: 'org-1', planKey: 'starter', quotaVersion: 1,
        minuteLimit: 60, monthlyLimit: 10000,
        minuteUsedAt: Date.now() - 70_000, minuteUsed: 0, monthlyUsed: 0,
      });
      const state = {
        storage,
        blockConcurrencyWhile: async <T>(fn: () => Promise<T>) => fn(),
        waitUntil: (_p: Promise<unknown>) => undefined,
      } as unknown as DurableObjectState;
      const do_ = new QuotaDurableObject(state);
      const res = await do_.fetch(checkReq());
      expect(res.status).toBe(200);
    });
  });
});
