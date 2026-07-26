/**
 * Quota Durable Object: Per-org quota state machine
 *
 * Responsibilities:
 * - Cache org quota/plan state
 * - Serialize quota checks
 * - Track current minute counters
 * - Track monthly counter deltas before flush
 * - Reject over-limit requests
 * - Expose checkAndReserve() and flushUsage() methods
 */

interface QuotaCheckRequest {
  orgId: string;
  metricKey: string; // e.g. "requests", "otel_events", "agent_runs"
  units: number; // e.g. 1, 50, 1000
  requestId: string;
  planKey: string;
  quotaVersion: number;
}

interface QuotaCheckResponse {
  allowed: boolean;
  reason?: "minute_limit" | "monthly_limit" | "feature_disabled";
  remainingMinute?: number;
  remainingMonthly?: number | null;
}

interface OrganizationQuota {
  orgId: string;
  planKey: string;
  quotaVersion: number;
  minuteLimit: number; // requests per minute for this plan
  monthlyLimit: number | null; // total units per month, or null for unlimited
  minuteUsedAt: number; // timestamp when minute window started
  minuteUsed: number; // units used in current minute
  monthlyUsed: number; // units used this month (delta before flush)
  lastMonthlyResetAt: number; // timestamp of last monthly counter reset
  seenRequestIds: Record<string, number>; // requestId → timestamp for idempotency (5-min TTL)
}

const DEFAULT_QUOTAS: Record<string, { requestsPerMinute: number; monthlyLimit: number | null }> = {
  // 'starter' is the canonical plan key in DB (current_plan column).
  // 'free' is kept as an alias so existing orgs with current_plan = 'free' stay functional.
  starter: {
    requestsPerMinute: 60,
    monthlyLimit: 10000,
  },
  growth: {
    requestsPerMinute: 600,
    monthlyLimit: 500000,
  },
  enterprise: {
    requestsPerMinute: 6000,
    monthlyLimit: null, // unlimited
  },
};
DEFAULT_QUOTAS.free = DEFAULT_QUOTAS.starter;

export class QuotaDurableObject implements DurableObject {
  private state: DurableObjectState;
  private quota: OrganizationQuota | null = null;
  private lastSavedAt: number = Date.now();
  /** True when a flush alarm has been scheduled but not yet fired. */
  private alarmArmed: boolean = false;

  constructor(state: DurableObjectState) {
    this.state = state;
    // blockConcurrencyWhile ensures storage is loaded before the first fetch()
    // call is dispatched. Without this, two concurrent cold-start requests could
    // both see quota=null and both initialize from DEFAULT_QUOTAS, discarding any
    // previously persisted state for the DO's lifetime.
    this.state.blockConcurrencyWhile(async () => {
      const stored = await this.state.storage.get<OrganizationQuota>('quota');
      if (stored) {
        this.quota = stored;
        this.lastSavedAt = Date.now();
      }
    });
  }

  async initialize(): Promise<void> {
    if (this.quota !== null) return; // already loaded by blockConcurrencyWhile
    const stored = await this.state.storage.get<OrganizationQuota>('quota');
    if (stored) {
      this.quota = stored;
    }
  }

  async fetch(request: Request): Promise<Response> {
    const url = new URL(request.url);

    if (url.pathname === '/check-and-reserve' && request.method === 'POST') {
      return this.handleCheckAndReserve(request);
    }

    if (url.pathname === '/flush-usage' && request.method === 'POST') {
      return this.handleFlushUsage();
    }

    if (url.pathname === '/status' && request.method === 'GET') {
      return this.handleStatus();
    }

    return new Response('Not found', { status: 404 });
  }

  private async handleCheckAndReserve(request: Request): Promise<Response> {
    await this.initialize();

    try {
      const body = (await request.json()) as QuotaCheckRequest;
      const { orgId, metricKey, units, requestId, planKey, quotaVersion } = body;

      // Validate required fields
      if (!orgId || !metricKey || units == null || units <= 0 || !requestId || !planKey || quotaVersion === undefined) {
        return new Response(
          JSON.stringify({ error: 'Missing required fields' }),
          { status: 400, headers: { 'Content-Type': 'application/json' } },
        );
      }

      // Load or initialize quota state
      if (!this.quota || this.quota.orgId !== orgId) {
        const stored = await this.state.storage.get<OrganizationQuota>('quota');
        if (stored && stored.orgId === orgId) {
          this.quota = stored;
        } else {
          const quotaConfig = DEFAULT_QUOTAS[planKey] ?? DEFAULT_QUOTAS.starter;
          this.quota = {
            orgId,
            planKey,
            quotaVersion,
            minuteLimit: quotaConfig.requestsPerMinute,
            monthlyLimit: quotaConfig.monthlyLimit,
            minuteUsedAt: Date.now(),
            minuteUsed: 0,
            monthlyUsed: 0,
            lastMonthlyResetAt: Date.now(),
            seenRequestIds: {},
          };
        }
      }

      const now = Date.now();

      // Backfill fields missing from legacy stored state
      if (!this.quota.lastMonthlyResetAt) {
        this.quota.lastMonthlyResetAt = 0; // epoch → guaranteed different from current month
      }
      if (!this.quota.seenRequestIds) {
        this.quota.seenRequestIds = {};
      }

      // Reset monthly counter when the calendar month rolls over
      const thisMonth = new Date(now).toISOString().slice(0, 7);
      const lastResetMonth = new Date(this.quota.lastMonthlyResetAt).toISOString().slice(0, 7);
      if (thisMonth !== lastResetMonth) {
        this.quota.monthlyUsed = 0;
        this.quota.lastMonthlyResetAt = now;
      }

      // Update quota version if it changed (org plan/billing updated).
      // monthlyUsed is intentionally preserved — resetting it would let an org evade
      // its monthly limit by triggering a quota_version bump mid-month.
      if (quotaVersion > this.quota.quotaVersion) {
        const quotaConfig = DEFAULT_QUOTAS[planKey] ?? DEFAULT_QUOTAS.starter;
        this.quota.planKey = planKey;
        this.quota.quotaVersion = quotaVersion;
        this.quota.minuteLimit = quotaConfig.requestsPerMinute;
        this.quota.monthlyLimit = quotaConfig.monthlyLimit;
        this.quota.minuteUsed = 0;
        this.quota.minuteUsedAt = now;
        // monthlyUsed NOT reset: preserved so quota evasion via plan cycling is prevented.
      }

      // Purge requestIds older than 5 minutes and check idempotency
      const fiveMinAgo = now - 5 * 60_000;
      for (const id of Object.keys(this.quota.seenRequestIds)) {
        if (this.quota.seenRequestIds[id] < fiveMinAgo) {
          delete this.quota.seenRequestIds[id];
        }
      }
      if (this.quota.seenRequestIds[requestId] !== undefined) {
        // Duplicate within TTL — return allowed without double-counting
        return new Response(
          JSON.stringify({
            allowed: true,
            remainingMinute: Math.max(0, this.quota.minuteLimit - this.quota.minuteUsed),
            remainingMonthly: this.quota.monthlyLimit !== null
              ? Math.max(0, this.quota.monthlyLimit - this.quota.monthlyUsed)
              : null,
          }),
          { status: 200, headers: { 'Content-Type': 'application/json' } },
        );
      }

      // Check minute window expiration
      if (now - this.quota.minuteUsedAt >= 60_000) {
        this.quota.minuteUsed = 0;
        this.quota.minuteUsedAt = now;
      }

      // Check minute limit
      if (this.quota.minuteUsed + units > this.quota.minuteLimit) {
        const response: QuotaCheckResponse = {
          allowed: false,
          reason: 'minute_limit',
          remainingMinute: Math.max(0, this.quota.minuteLimit - this.quota.minuteUsed),
        };
        return new Response(JSON.stringify(response), {
          status: 429,
          headers: { 'Content-Type': 'application/json' },
        });
      }

      // Check monthly limit
      if (this.quota.monthlyLimit !== null && this.quota.monthlyUsed + units > this.quota.monthlyLimit) {
        const response: QuotaCheckResponse = {
          allowed: false,
          reason: 'monthly_limit',
          remainingMonthly: Math.max(0, this.quota.monthlyLimit - this.quota.monthlyUsed),
        };
        return new Response(JSON.stringify(response), {
          status: 429,
          headers: { 'Content-Type': 'application/json' },
        });
      }

      // Reserve units and record requestId for idempotency
      this.quota.minuteUsed += units;
      this.quota.monthlyUsed += units;
      this.quota.seenRequestIds[requestId] = now;

      // Periodically persist to storage (eager path: at least every 10 s under load).
      if (now - this.lastSavedAt > 10_000) {
        await this.state.storage.put('quota', this.quota);
        this.lastSavedAt = now;
        this.alarmArmed = false; // persisted in-band; cancel pending alarm intent
      }

      // Arm a flush alarm so counts are persisted even during sparse traffic.
      // The alarm fires ≤10 s after the last write, ensuring eviction doesn't
      // lose quota state regardless of request rate.
      if (!this.alarmArmed) {
        await this.state.storage.setAlarm(now + 10_000);
        this.alarmArmed = true;
      }

      const response: QuotaCheckResponse = {
        allowed: true,
        remainingMinute: Math.max(0, this.quota.minuteLimit - this.quota.minuteUsed),
        remainingMonthly: this.quota.monthlyLimit !== null
          ? Math.max(0, this.quota.monthlyLimit - this.quota.monthlyUsed)
          : null,
      };

      return new Response(JSON.stringify(response), {
        status: 200,
        headers: { 'Content-Type': 'application/json' },
      });
    } catch (err) {
      const message = err instanceof Error ? err.message : 'Unknown error';
      return new Response(
        JSON.stringify({ error: message }),
        { status: 400, headers: { 'Content-Type': 'application/json' } },
      );
    }
  }

  private async handleFlushUsage(): Promise<Response> {
    await this.initialize();

    if (!this.quota) {
      return new Response(
        JSON.stringify({ error: 'No quota state' }),
        { status: 404, headers: { 'Content-Type': 'application/json' } },
      );
    }

    const monthlyUsed = this.quota.monthlyUsed;

    // Reset monthly counter
    this.quota.monthlyUsed = 0;

    // Persist to storage
    await this.state.storage.put('quota', this.quota);
    this.lastSavedAt = Date.now();

    return new Response(
      JSON.stringify({
        orgId: this.quota.orgId,
        monthlyUsedSinceLastFlush: monthlyUsed,
        flushedAt: new Date().toISOString(),
      }),
      { status: 200, headers: { 'Content-Type': 'application/json' } },
    );
  }

  private async handleStatus(): Promise<Response> {
    await this.initialize();

    if (!this.quota) {
      return new Response(
        JSON.stringify({ status: 'uninitialized' }),
        { status: 200, headers: { 'Content-Type': 'application/json' } },
      );
    }

    return new Response(
      JSON.stringify({
        orgId: this.quota.orgId,
        planKey: this.quota.planKey,
        quotaVersion: this.quota.quotaVersion,
        minuteLimit: this.quota.minuteLimit,
        monthlyLimit: this.quota.monthlyLimit,
        minuteUsed: this.quota.minuteUsed,
        monthlyUsed: this.quota.monthlyUsed,
        minuteWindowExpiresIn: 60_000 - (Date.now() - this.quota.minuteUsedAt),
      }),
      { status: 200, headers: { 'Content-Type': 'application/json' } },
    );
  }

  /**
   * Alarm handler — fires ≤10 s after the last quota update.
   * Persists in-memory state so counts are not lost when the DO is evicted.
   * This is the sole flush path for sparse traffic where the 10 s in-band
   * persist threshold in handleCheckAndReserve is never crossed.
   */
  async alarm(): Promise<void> {
    this.alarmArmed = false;
    if (!this.quota) return;
    await this.state.storage.put('quota', this.quota);
    this.lastSavedAt = Date.now();
  }
}
