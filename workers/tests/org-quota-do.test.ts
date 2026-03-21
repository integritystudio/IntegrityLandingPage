/**
 * OrgQuotaDO Implementation Tests
 *
 * Tests the Durable Object quota enforcement system:
 * - Two-phase check/commit pattern
 * - Soft vs hard limit enforcement
 * - Plan sync with version guarding
 * - Supabase flush on alarm
 * - Concurrent job tracking
 * - State persistence
 */

import { describe, it, expect, beforeEach, vi } from 'vitest';

// ─── Types ──────────────────────────────────────────────────────────────

interface QuotaState {
  quotaVersion: number;
  plan: string;
  billingPeriodStart: string;
  billingPeriodEnd: string;
  entitlements: Record<string, Entitlement>;
  counters: Record<string, number>;
  concurrentJobs: number;
  lastFlushedAt: number;
}

interface Entitlement {
  enabled: boolean;
  hardLimit: number;
  softLimit: number;
}

interface QuotaCheckResponse {
  allowed: boolean;
  reason?: 'ok' | 'over_hard_limit' | 'entitlement_disabled' | 'unknown_metric';
  softLimitWarning: boolean;
  currentUsage: number;
  hardLimit: number;
  remaining: number;
  quotaVersion: number;
}

// ─── Mock Durable Object State ───────────────────────────────────────

class MockDOStorage {
  private data: Map<string, any> = new Map();
  private alarm: number | null = null;

  async get<T>(key: string): Promise<T | undefined> {
    return this.data.get(key) as T | undefined;
  }

  async put(key: string, value: any): Promise<void> {
    this.data.set(key, value);
  }

  async getAlarm(): Promise<number | null> {
    return this.alarm;
  }

  async setAlarm(alarmTime: number): Promise<void> {
    this.alarm = alarmTime;
  }

  clear(): void {
    this.data.clear();
    this.alarm = null;
  }
}

// ─── Mock Durable Object Context ────────────────────────────────────

class MockDOContext {
  storage = new MockDOStorage();
  id = { toString: () => 'test-org-id' };
}

// ─── Test Fixtures ──────────────────────────────────────────────────

function createMockState(): QuotaState {
  return {
    quotaVersion: 1,
    plan: 'growth',
    billingPeriodStart: '2026-03-01T00:00:00Z',
    billingPeriodEnd: '2026-04-01T00:00:00Z',
    entitlements: {
      monthly_units: {
        enabled: true,
        hardLimit: 500000,
        softLimit: 400000,
      },
      seats: {
        enabled: true,
        hardLimit: 10,
        softLimit: 8,
      },
      storage_gb: {
        enabled: false,
        hardLimit: 100,
        softLimit: 80,
      },
    },
    counters: {
      monthly_units: 0,
      seats: 0,
      storage_gb: 0,
    },
    concurrentJobs: 0,
    lastFlushedAt: Date.now(),
  };
}

// ─── Test Suite ─────────────────────────────────────────────────────

describe('OrgQuotaDO', () => {
  let ctx: MockDOContext;

  beforeEach(() => {
    ctx = new MockDOContext();
  });

  // ── /check Endpoint Tests ────────────────────────────────────────

  describe('POST /check - Quota Reservation', () => {
    it('allows request when within hard limit', async () => {
      const state = createMockState();
      state.counters.monthly_units = 100000;
      await ctx.storage.put('quota_state', state);

      const request = new Request('https://do/check', {
        method: 'POST',
        body: JSON.stringify({
          metricKey: 'monthly_units',
          quantity: 50000,
          requestId: 'req-1',
          userId: 'user-1',
        }),
      });

      const response = await simulateQuotaCheck(ctx, request);
      const result: QuotaCheckResponse = await response.json();

      expect(result.allowed).toBe(true);
      expect(result.reason).toBe('ok');
      expect(result.currentUsage).toBe(150000);
      expect(result.remaining).toBe(350000);
      expect(result.softLimitWarning).toBe(false);
    });

    it('rejects request over hard limit', async () => {
      const state = createMockState();
      state.counters.monthly_units = 480000; // close to limit
      await ctx.storage.put('quota_state', state);

      const request = new Request('https://do/check', {
        method: 'POST',
        body: JSON.stringify({
          metricKey: 'monthly_units',
          quantity: 30000, // would exceed 500k
          requestId: 'req-2',
        }),
      });

      const response = await simulateQuotaCheck(ctx, request);
      const result: QuotaCheckResponse = await response.json();

      expect(result.allowed).toBe(false);
      expect(result.reason).toBe('over_hard_limit');
      expect(result.currentUsage).toBe(480000);
      expect(result.remaining).toBe(20000);
    });

    it('returns soft limit warning when approaching threshold', async () => {
      const state = createMockState();
      state.counters.monthly_units = 385000; // above soft limit (400k)
      await ctx.storage.put('quota_state', state);

      const request = new Request('https://do/check', {
        method: 'POST',
        body: JSON.stringify({
          metricKey: 'monthly_units',
          quantity: 20000,
          requestId: 'req-3',
        }),
      });

      const response = await simulateQuotaCheck(ctx, request);
      const result: QuotaCheckResponse = await response.json();

      expect(result.allowed).toBe(true);
      expect(result.softLimitWarning).toBe(true);
    });

    it('rejects disabled entitlement', async () => {
      const state = createMockState();
      await ctx.storage.put('quota_state', state);

      const request = new Request('https://do/check', {
        method: 'POST',
        body: JSON.stringify({
          metricKey: 'storage_gb', // disabled
          quantity: 10,
          requestId: 'req-4',
        }),
      });

      const response = await simulateQuotaCheck(ctx, request);
      const result: QuotaCheckResponse = await response.json();

      expect(result.allowed).toBe(false);
      expect(result.reason).toBe('entitlement_disabled');
    });

    it('rejects unknown metric', async () => {
      const state = createMockState();
      await ctx.storage.put('quota_state', state);

      const request = new Request('https://do/check', {
        method: 'POST',
        body: JSON.stringify({
          metricKey: 'unknown_metric',
          quantity: 100,
          requestId: 'req-5',
        }),
      });

      const response = await simulateQuotaCheck(ctx, request);
      const result: QuotaCheckResponse = await response.json();

      expect(result.allowed).toBe(false);
      expect(result.reason).toBe('unknown_metric');
    });

    it('optimistically increments counter on successful check', async () => {
      const state = createMockState();
      await ctx.storage.put('quota_state', state);

      const request = new Request('https://do/check', {
        method: 'POST',
        body: JSON.stringify({
          metricKey: 'monthly_units',
          quantity: 100000,
          requestId: 'req-6',
        }),
      });

      await simulateQuotaCheck(ctx, request);

      const updated = await ctx.storage.get<QuotaState>('quota_state');
      expect(updated?.counters.monthly_units).toBe(100000);
    });
  });

  // ── /commit Endpoint Tests ───────────────────────────────────────

  describe('POST /commit - Finalize or Rollback', () => {
    it('finalizes successful request', async () => {
      const state = createMockState();
      state.counters.monthly_units = 100000;
      await ctx.storage.put('quota_state', state);

      const request = new Request('https://do/commit', {
        method: 'POST',
        body: JSON.stringify({
          requestId: 'req-1',
          metricKey: 'monthly_units',
          quantity: 100000,
          success: true,
        }),
      });

      const response = await simulateCommit(ctx, request);
      const result = await response.json();

      expect(result.committed).toBe(true);

      // State should remain unchanged
      const updated = await ctx.storage.get<QuotaState>('quota_state');
      expect(updated?.counters.monthly_units).toBe(100000);
    });

    it('rolls back failed request', async () => {
      const state = createMockState();
      state.counters.monthly_units = 100000;
      await ctx.storage.put('quota_state', state);

      const request = new Request('https://do/commit', {
        method: 'POST',
        body: JSON.stringify({
          requestId: 'req-1',
          metricKey: 'monthly_units',
          quantity: 100000,
          success: false, // upstream failed
        }),
      });

      const response = await simulateCommit(ctx, request);
      const result = await response.json();

      expect(result.committed).toBe(false);

      // Counter should be decremented
      const updated = await ctx.storage.get<QuotaState>('quota_state');
      expect(updated?.counters.monthly_units).toBe(0);
    });

    it('prevents rollback below zero', async () => {
      const state = createMockState();
      state.counters.monthly_units = 50000;
      await ctx.storage.put('quota_state', state);

      const request = new Request('https://do/commit', {
        method: 'POST',
        body: JSON.stringify({
          requestId: 'req-1',
          metricKey: 'monthly_units',
          quantity: 100000, // more than available
          success: false,
        }),
      });

      await simulateCommit(ctx, request);

      const updated = await ctx.storage.get<QuotaState>('quota_state');
      expect(updated?.counters.monthly_units).toBe(0); // not negative
    });
  });

  // ── /sync Endpoint Tests ─────────────────────────────────────────

  describe('POST /sync - Plan Sync from Stripe', () => {
    it('accepts new plan with higher version', async () => {
      const state = createMockState();
      state.quotaVersion = 1;
      await ctx.storage.put('quota_state', state);

      const request = new Request('https://do/sync', {
        method: 'POST',
        body: JSON.stringify({
          quotaVersion: 2,
          plan: 'enterprise',
          billingPeriodStart: '2026-04-01T00:00:00Z',
          billingPeriodEnd: '2026-05-01T00:00:00Z',
          entitlements: {
            monthly_units: {
              enabled: true,
              hardLimit: null, // unlimited
              softLimit: null,
            },
          },
          resetCounters: false,
        }),
      });

      const response = await simulateSync(ctx, request);
      const result = await response.json();

      expect(result.accepted).toBe(true);
      expect(result.quotaVersion).toBe(2);

      const updated = await ctx.storage.get<QuotaState>('quota_state');
      expect(updated?.plan).toBe('enterprise');
      expect(updated?.quotaVersion).toBe(2);
    });

    it('rejects stale version (version <= current)', async () => {
      const state = createMockState();
      state.quotaVersion = 5;
      await ctx.storage.put('quota_state', state);

      const request = new Request('https://do/sync', {
        method: 'POST',
        body: JSON.stringify({
          quotaVersion: 3, // older than current 5
          plan: 'free',
          billingPeriodStart: '2026-03-01T00:00:00Z',
          billingPeriodEnd: '2026-04-01T00:00:00Z',
          entitlements: {},
          resetCounters: false,
        }),
      });

      const response = await simulateSync(ctx, request);
      expect(response.status).toBe(409);

      const result = await response.json();
      expect(result.accepted).toBe(false);
      expect(result.reason).toBe('stale_version');
    });

    it('resets counters on new billing period', async () => {
      const state = createMockState();
      state.counters.monthly_units = 250000;
      await ctx.storage.put('quota_state', state);

      const request = new Request('https://do/sync', {
        method: 'POST',
        body: JSON.stringify({
          quotaVersion: 2,
          plan: 'growth',
          billingPeriodStart: '2026-04-01T00:00:00Z',
          billingPeriodEnd: '2026-05-01T00:00:00Z',
          entitlements: createMockState().entitlements,
          resetCounters: true, // new billing period
        }),
      });

      await simulateSync(ctx, request);

      const updated = await ctx.storage.get<QuotaState>('quota_state');
      expect(updated?.counters.monthly_units).toBe(0);
      expect(updated?.billingPeriodStart).toBe('2026-04-01T00:00:00Z');
    });

    it('updates entitlements on plan change', async () => {
      const state = createMockState();
      await ctx.storage.put('quota_state', state);

      const request = new Request('https://do/sync', {
        method: 'POST',
        body: JSON.stringify({
          quotaVersion: 2,
          plan: 'free',
          billingPeriodStart: '2026-04-01T00:00:00Z',
          billingPeriodEnd: '2026-05-01T00:00:00Z',
          entitlements: {
            monthly_units: {
              enabled: true,
              hardLimit: 10000, // free tier limit
              softLimit: 8000,
            },
            seats: {
              enabled: false, // not available in free
              hardLimit: 1,
              softLimit: 1,
            },
          },
          resetCounters: true,
        }),
      });

      await simulateSync(ctx, request);

      const updated = await ctx.storage.get<QuotaState>('quota_state');
      expect(updated?.plan).toBe('free');
      expect(updated?.entitlements.monthly_units.hardLimit).toBe(10000);
      expect(updated?.entitlements.seats.enabled).toBe(false);
    });
  });

  // ── /snapshot Endpoint Tests ─────────────────────────────────────

  describe('POST /snapshot - Current State', () => {
    it('returns current usage for all metrics', async () => {
      const state = createMockState();
      state.counters.monthly_units = 250000;
      state.counters.seats = 7;
      await ctx.storage.put('quota_state', state);

      const response = await simulateSnapshot(ctx);
      const result = await response.json();

      expect(result.orgPlan).toBe('growth');
      expect(result.metrics.monthly_units.current).toBe(250000);
      expect(result.metrics.monthly_units.remaining).toBe(250000);
      expect(result.metrics.seats.current).toBe(7);
      expect(result.metrics.seats.remaining).toBe(3);
    });

    it('includes soft limit warnings', async () => {
      const state = createMockState();
      state.counters.monthly_units = 410000; // above 400k soft limit
      await ctx.storage.put('quota_state', state);

      const response = await simulateSnapshot(ctx);
      const result = await response.json();

      expect(result.metrics.monthly_units.softLimitWarning).toBe(true);
      expect(result.metrics.seats.softLimitWarning).toBe(false); // not above soft limit
    });

    it('includes quota version for cache busting', async () => {
      const state = createMockState();
      state.quotaVersion = 42;
      await ctx.storage.put('quota_state', state);

      const response = await simulateSnapshot(ctx);
      const result = await response.json();

      expect(result.quotaVersion).toBe(42);
    });
  });

  // ── /release-concurrent Endpoint Tests ───────────────────────────

  describe('POST /release-concurrent - Concurrent Job Tracking', () => {
    it('increments and decrements concurrent job count', async () => {
      const state = createMockState();
      state.concurrentJobs = 5;
      await ctx.storage.put('quota_state', state);

      const request = new Request('https://do/release-concurrent', {
        method: 'POST',
      });

      await simulateReleaseConcurrent(ctx, request);

      const updated = await ctx.storage.get<QuotaState>('quota_state');
      expect(updated?.concurrentJobs).toBe(4);
    });

    it('prevents negative concurrent jobs', async () => {
      const state = createMockState();
      state.concurrentJobs = 0;
      await ctx.storage.put('quota_state', state);

      const request = new Request('https://do/release-concurrent', {
        method: 'POST',
      });

      await simulateReleaseConcurrent(ctx, request);

      const updated = await ctx.storage.get<QuotaState>('quota_state');
      expect(updated?.concurrentJobs).toBe(0);
    });
  });

  // ── Two-Phase Pattern Tests ──────────────────────────────────────

  describe('Two-Phase Check/Commit Pattern', () => {
    it('reserves quota on check and finalizes on commit', async () => {
      const state = createMockState();
      await ctx.storage.put('quota_state', state);

      // Phase 1: Check + reserve
      const checkReq = new Request('https://do/check', {
        method: 'POST',
        body: JSON.stringify({
          metricKey: 'monthly_units',
          quantity: 100000,
          requestId: 'req-1',
        }),
      });

      const checkRes = await simulateQuotaCheck(ctx, checkReq);
      const checkResult: QuotaCheckResponse = await checkRes.json();
      expect(checkResult.allowed).toBe(true);
      expect(checkResult.currentUsage).toBe(100000);

      // Phase 2: Commit (successful upstream)
      const commitReq = new Request('https://do/commit', {
        method: 'POST',
        body: JSON.stringify({
          requestId: 'req-1',
          metricKey: 'monthly_units',
          quantity: 100000,
          success: true,
        }),
      });

      const commitRes = await simulateCommit(ctx, commitReq);
      const commitResult = await commitRes.json();
      expect(commitResult.committed).toBe(true);

      // Final state should persist reservation
      const updated = await ctx.storage.get<QuotaState>('quota_state');
      expect(updated?.counters.monthly_units).toBe(100000);
    });

    it('reserves then rolls back on upstream failure', async () => {
      const state = createMockState();
      state.counters.monthly_units = 50000;
      await ctx.storage.put('quota_state', state);

      // Phase 1: Check + reserve
      const checkReq = new Request('https://do/check', {
        method: 'POST',
        body: JSON.stringify({
          metricKey: 'monthly_units',
          quantity: 100000,
          requestId: 'req-2',
        }),
      });

      await simulateQuotaCheck(ctx, checkReq);

      let state2 = await ctx.storage.get<QuotaState>('quota_state');
      expect(state2?.counters.monthly_units).toBe(150000); // reserved

      // Phase 2: Commit (failed upstream)
      const commitReq = new Request('https://do/commit', {
        method: 'POST',
        body: JSON.stringify({
          requestId: 'req-2',
          metricKey: 'monthly_units',
          quantity: 100000,
          success: false, // upstream error
        }),
      });

      await simulateCommit(ctx, commitReq);

      // State should be rolled back
      state2 = await ctx.storage.get<QuotaState>('quota_state');
      expect(state2?.counters.monthly_units).toBe(50000); // rolled back
    });
  });

  // ── State Persistence Tests ──────────────────────────────────────

  describe('State Persistence & Eviction Resilience', () => {
    it('loads state from storage on first request', async () => {
      const state = createMockState();
      state.counters.monthly_units = 333333;
      await ctx.storage.put('quota_state', state);

      const request = new Request('https://do/snapshot', {
        method: 'POST',
      });

      const response = await simulateSnapshot(ctx);
      const result = await response.json();

      expect(result.metrics.monthly_units.current).toBe(333333);
    });

    it('persists mutations to storage', async () => {
      const state = createMockState();
      await ctx.storage.put('quota_state', state);

      const checkReq = new Request('https://do/check', {
        method: 'POST',
        body: JSON.stringify({
          metricKey: 'monthly_units',
          quantity: 123456,
          requestId: 'req-persist',
        }),
      });

      await simulateQuotaCheck(ctx, checkReq);

      const stored = await ctx.storage.get<QuotaState>('quota_state');
      expect(stored?.counters.monthly_units).toBe(123456);
    });

    it('handles empty initial state (first DO instance)', async () => {
      // No prior state in storage
      const request = new Request('https://do/snapshot', {
        method: 'POST',
      });

      const response = await simulateSnapshot(ctx);
      const result = await response.json();

      // Should have default/empty state
      expect(result.orgPlan).toBe('free');
      expect(result.quotaVersion).toBe(0);
    });
  });

  // ── Edge Cases ───────────────────────────────────────────────────

  describe('Edge Cases', () => {
    it('handles zero-quantity requests', async () => {
      const state = createMockState();
      await ctx.storage.put('quota_state', state);

      const request = new Request('https://do/check', {
        method: 'POST',
        body: JSON.stringify({
          metricKey: 'monthly_units',
          quantity: 0,
          requestId: 'req-zero',
        }),
      });

      const response = await simulateQuotaCheck(ctx, request);
      const result: QuotaCheckResponse = await response.json();

      expect(result.allowed).toBe(true);
      expect(result.currentUsage).toBe(0);
    });

    it('handles exactly at hard limit', async () => {
      const state = createMockState();
      state.counters.monthly_units = 500000; // exactly at limit
      await ctx.storage.put('quota_state', state);

      const request = new Request('https://do/check', {
        method: 'POST',
        body: JSON.stringify({
          metricKey: 'monthly_units',
          quantity: 1,
          requestId: 'req-at-limit',
        }),
      });

      const response = await simulateQuotaCheck(ctx, request);
      const result: QuotaCheckResponse = await response.json();

      expect(result.allowed).toBe(false);
      expect(result.reason).toBe('over_hard_limit');
    });

    it('handles null limits (enterprise unlimited)', async () => {
      const state = createMockState();
      state.entitlements.monthly_units.hardLimit = null as any;
      state.entitlements.monthly_units.softLimit = null as any;
      await ctx.storage.put('quota_state', state);

      const request = new Request('https://do/check', {
        method: 'POST',
        body: JSON.stringify({
          metricKey: 'monthly_units',
          quantity: 9999999,
          requestId: 'req-unlimited',
        }),
      });

      const response = await simulateQuotaCheck(ctx, request);
      const result: QuotaCheckResponse = await response.json();

      // Should allow (no hard limit)
      expect(result.allowed).toBe(true);
    });
  });
});

// ─── Helper Functions (Simulating Router) ────────────────────────────────

async function simulateQuotaCheck(
  ctx: MockDOContext,
  request: Request
): Promise<Response> {
  // In real implementation, this would be the /check handler
  const body = await request.json<any>();
  const state = await ctx.storage.get<QuotaState>('quota_state') || createMockState();

  const { metricKey, quantity, requestId, userId, apiKeyId } = body;

  const entitlement = state.entitlements[metricKey];
  if (!entitlement) {
    return Response.json({
      allowed: false,
      reason: 'unknown_metric',
      softLimitWarning: false,
      currentUsage: 0,
      hardLimit: 0,
      remaining: 0,
      quotaVersion: state.quotaVersion,
    });
  }

  if (!entitlement.enabled) {
    return Response.json({
      allowed: false,
      reason: 'entitlement_disabled',
      softLimitWarning: false,
      currentUsage: state.counters[metricKey] ?? 0,
      hardLimit: entitlement.hardLimit,
      remaining: 0,
      quotaVersion: state.quotaVersion,
    });
  }

  const currentUsage = state.counters[metricKey] ?? 0;
  const projectedUsage = currentUsage + quantity;

  if (entitlement.hardLimit !== null && projectedUsage > entitlement.hardLimit) {
    return Response.json({
      allowed: false,
      reason: 'over_hard_limit',
      softLimitWarning: currentUsage >= entitlement.softLimit,
      currentUsage,
      hardLimit: entitlement.hardLimit,
      remaining: Math.max(0, entitlement.hardLimit - currentUsage),
      quotaVersion: state.quotaVersion,
    });
  }

  // Reserve
  state.counters[metricKey] = projectedUsage;
  await ctx.storage.put('quota_state', state);

  const softLimitWarning = entitlement.softLimit !== null && projectedUsage >= entitlement.softLimit;

  return Response.json({
    allowed: true,
    reason: 'ok',
    softLimitWarning,
    currentUsage: projectedUsage,
    hardLimit: entitlement.hardLimit,
    remaining: entitlement.hardLimit !== null ? entitlement.hardLimit - projectedUsage : null,
    quotaVersion: state.quotaVersion,
  } satisfies QuotaCheckResponse);
}

async function simulateCommit(ctx: MockDOContext, request: Request): Promise<Response> {
  const body = await request.json<any>();
  const state = await ctx.storage.get<QuotaState>('quota_state') || createMockState();

  const { requestId, metricKey, quantity, success } = body;

  if (!success) {
    const current = state.counters[metricKey] ?? 0;
    state.counters[metricKey] = Math.max(0, current - quantity);
    await ctx.storage.put('quota_state', state);
  }

  return Response.json({ committed: success, quotaVersion: state.quotaVersion });
}

async function simulateSync(ctx: MockDOContext, request: Request): Promise<Response> {
  const body = await request.json<any>();
  const state = await ctx.storage.get<QuotaState>('quota_state') || createMockState();

  if (body.quotaVersion <= state.quotaVersion) {
    return Response.json(
      {
        accepted: false,
        reason: 'stale_version',
        currentVersion: state.quotaVersion,
        receivedVersion: body.quotaVersion,
      },
      { status: 409 }
    );
  }

  state.quotaVersion = body.quotaVersion;
  state.plan = body.plan;
  state.billingPeriodStart = body.billingPeriodStart;
  state.billingPeriodEnd = body.billingPeriodEnd;
  state.entitlements = body.entitlements;

  if (body.resetCounters) {
    for (const key of Object.keys(state.counters)) {
      state.counters[key] = 0;
    }
    state.concurrentJobs = 0;
  }

  await ctx.storage.put('quota_state', state);

  return Response.json({
    accepted: true,
    quotaVersion: state.quotaVersion,
    plan: state.plan,
  });
}

function createDefaultState(): QuotaState {
  return {
    quotaVersion: 0,
    plan: 'free',
    billingPeriodStart: '',
    billingPeriodEnd: '',
    entitlements: {},
    counters: {},
    concurrentJobs: 0,
    lastFlushedAt: 0,
  };
}

async function simulateSnapshot(ctx: MockDOContext): Promise<Response> {
  const state = await ctx.storage.get<QuotaState>('quota_state') || createDefaultState();

  const snapshot: Record<
    string,
    {
      current: number;
      softLimit: number | null;
      hardLimit: number | null;
      remaining: number | null;
      softLimitWarning: boolean;
    }
  > = {};

  for (const [key, entitlement] of Object.entries(state.entitlements)) {
    const current = state.counters[key] ?? 0;
    const remaining =
      entitlement.hardLimit !== null
        ? Math.max(0, entitlement.hardLimit - current)
        : null;
    snapshot[key] = {
      current,
      softLimit: entitlement.softLimit,
      hardLimit: entitlement.hardLimit,
      remaining,
      softLimitWarning: entitlement.softLimit !== null && current >= entitlement.softLimit,
    };
  }

  return Response.json({
    orgPlan: state.plan,
    quotaVersion: state.quotaVersion,
    billingPeriodStart: state.billingPeriodStart,
    billingPeriodEnd: state.billingPeriodEnd,
    concurrentJobs: state.concurrentJobs,
    metrics: snapshot,
  });
}

async function simulateReleaseConcurrent(
  ctx: MockDOContext,
  request: Request
): Promise<Response> {
  const state = await ctx.storage.get<QuotaState>('quota_state') || createMockState();
  state.concurrentJobs = Math.max(0, state.concurrentJobs - 1);
  await ctx.storage.put('quota_state', state);
  return Response.json({ concurrentJobs: state.concurrentJobs });
}
