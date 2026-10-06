/**
 * Quota Durable Object: Per-org quota state machine
 *
 * Responsibilities:
 * - Cache org quota/plan state
 * - Serialize quota checks
 * - Track current minute counters
 * - Track monthly counters in DO storage
 * - Reject over-limit requests
 * - Expose checkAndReserve()
 *
 * Nothing here writes to Supabase: the durable usage record is written per
 * request by the gateway's usage ledger (lib/usage-ledger.ts, UA01) via
 * ctx.waitUntil. There is no flush route: a `POST /flush-usage` that zeroed the
 * monthly counter, persisted nothing and had no caller was deleted (BACKLOG.md
 * CR45), because wired up it would have forgiven an org's month of usage while
 * the ledger kept the truth. A monthly reset, if ever wanted, belongs to a period
 * rollover keyed on the ledger, not a callable reset.
 */

import { MS_PER_MINUTE, MS_PER_SECOND, SECONDS_PER_MINUTE } from '../../../lib/constants';

/** Length of the per-minute quota window. */
export const QUOTA_MINUTE_WINDOW_SECONDS = SECONDS_PER_MINUTE;
const QUOTA_MINUTE_WINDOW_MS = MS_PER_MINUTE;
/** Longest a count stays unpersisted: the eager-save threshold and the flush-alarm delay (T28). */
const PERSIST_INTERVAL_MS = 10 * MS_PER_SECOND;
/** How long a requestId is remembered, so a retried reservation is not counted twice. */
const REQUEST_ID_TTL_MS = 5 * MS_PER_MINUTE;

interface QuotaCheckRequest {
  orgId: string;
  metricKey: string; // e.g. "requests", "otel_events", "agent_runs"
  units: number; // e.g. 1, 50, 1000
  requestId: string;
  planKey: string;
  quotaVersion: number;
  /** False for reads that must not spend the quota they report (CR58): the
   *  request counts toward the minute window only, and is admitted even when the
   *  month is exhausted so an org can still see its usage. Defaults to true. */
  chargeMonthly?: boolean;
}

interface QuotaCheckResponse {
  allowed: boolean;
  reason?: "minute_limit" | "monthly_limit" | "feature_disabled";
  remainingMinute?: number;
  remainingMonthly?: number | null;
  minuteLimit?: number | null;
  monthlyLimit?: number | null;
  minuteWindowResetsIn?: number;
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
      const chargesMonthly = body.chargeMonthly !== false;

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

      this.rollMonthIfNeeded(now);

      // Update quota version if it changed (org plan/billing updated).
      // monthlyUsed is intentionally preserved — resetting it would let an org evade
      // its monthly limit by triggering a quota_version bump mid-month.
      // A different planKey at the same version also applies: the gateway derives it
      // server-side (CR37's billing gate changed it for orgs whose version never moved),
      // and a lower version is still ignored so a stale read cannot roll a plan back.
      const planChanged = quotaVersion === this.quota.quotaVersion && planKey !== this.quota.planKey;
      if (quotaVersion > this.quota.quotaVersion || planChanged) {
        const quotaConfig = DEFAULT_QUOTAS[planKey] ?? DEFAULT_QUOTAS.starter;
        this.quota.planKey = planKey;
        this.quota.quotaVersion = quotaVersion;
        this.quota.minuteLimit = quotaConfig.requestsPerMinute;
        this.quota.monthlyLimit = quotaConfig.monthlyLimit;
        this.quota.minuteUsed = 0;
        this.quota.minuteUsedAt = now;
        // monthlyUsed NOT reset: preserved so quota evasion via plan cycling is prevented.
      }

      // Purge requestIds older than the TTL and check idempotency
      const requestIdCutoff = now - REQUEST_ID_TTL_MS;
      for (const id of Object.keys(this.quota.seenRequestIds)) {
        if (this.quota.seenRequestIds[id] < requestIdCutoff) {
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
            minuteLimit: this.quota.minuteLimit,
            monthlyLimit: this.quota.monthlyLimit,
            minuteWindowResetsIn: this.minuteWindowResetsIn(now),
          }),
          { status: 200, headers: { 'Content-Type': 'application/json' } },
        );
      }

      // Check minute window expiration
      if (now - this.quota.minuteUsedAt >= QUOTA_MINUTE_WINDOW_MS) {
        this.quota.minuteUsed = 0;
        this.quota.minuteUsedAt = now;
      }

      // Check minute limit
      if (this.quota.minuteUsed + units > this.quota.minuteLimit) {
        const response: QuotaCheckResponse = {
          allowed: false,
          reason: 'minute_limit',
          remainingMinute: Math.max(0, this.quota.minuteLimit - this.quota.minuteUsed),
          remainingMonthly: this.quota.monthlyLimit !== null
            ? Math.max(0, this.quota.monthlyLimit - this.quota.monthlyUsed)
            : null,
          minuteLimit: this.quota.minuteLimit,
          monthlyLimit: this.quota.monthlyLimit,
          minuteWindowResetsIn: this.minuteWindowResetsIn(now),
        };
        return new Response(JSON.stringify(response), {
          status: 429,
          headers: { 'Content-Type': 'application/json' },
        });
      }

      // Check monthly limit
      if (chargesMonthly && this.quota.monthlyLimit !== null && this.quota.monthlyUsed + units > this.quota.monthlyLimit) {
        const response: QuotaCheckResponse = {
          allowed: false,
          reason: 'monthly_limit',
          remainingMinute: Math.max(0, this.quota.minuteLimit - this.quota.minuteUsed),
          remainingMonthly: Math.max(0, this.quota.monthlyLimit - this.quota.monthlyUsed),
          minuteLimit: this.quota.minuteLimit,
          monthlyLimit: this.quota.monthlyLimit,
          minuteWindowResetsIn: this.minuteWindowResetsIn(now),
        };
        return new Response(JSON.stringify(response), {
          status: 429,
          headers: { 'Content-Type': 'application/json' },
        });
      }

      // Reserve units and record requestId for idempotency
      this.quota.minuteUsed += units;
      if (chargesMonthly) this.quota.monthlyUsed += units;
      this.quota.seenRequestIds[requestId] = now;

      // Periodically persist to storage (eager path: at least every 10 s under load).
      if (now - this.lastSavedAt > PERSIST_INTERVAL_MS) {
        await this.state.storage.put('quota', this.quota);
        this.lastSavedAt = now;
        this.alarmArmed = false; // persisted in-band; cancel pending alarm intent
      }

      // Arm a flush alarm so counts are persisted even during sparse traffic.
      // The alarm fires ≤10 s after the last write, ensuring eviction doesn't
      // lose quota state regardless of request rate.
      if (!this.alarmArmed) {
        await this.state.storage.setAlarm(now + PERSIST_INTERVAL_MS);
        this.alarmArmed = true;
      }

      const response: QuotaCheckResponse = {
        allowed: true,
        remainingMinute: Math.max(0, this.quota.minuteLimit - this.quota.minuteUsed),
        remainingMonthly: this.quota.monthlyLimit !== null
          ? Math.max(0, this.quota.monthlyLimit - this.quota.monthlyUsed)
          : null,
        minuteLimit: this.quota.minuteLimit,
        monthlyLimit: this.quota.monthlyLimit,
        minuteWindowResetsIn: this.minuteWindowResetsIn(now),
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

  /**
   * Seconds remaining in the current minute window — used for Retry-After and the
   * IETF RateLimit `t=` field. Rounded up so a client never sleeps too little.
   */
  private minuteWindowResetsIn(now: number): number {
    if (!this.quota) return QUOTA_MINUTE_WINDOW_SECONDS;
    return Math.max(0, Math.ceil((this.quota.minuteUsedAt + QUOTA_MINUTE_WINDOW_MS - now) / MS_PER_SECOND));
  }

  /**
   * Zero the monthly counter when the UTC calendar month has changed since the
   * last reset. `/status` calls it too (CR58), so a read on the 1st reports the
   * new month even before the org's first request of it. Deterministic by month,
   * so an unpersisted reset is simply re-applied after eviction.
   */
  private rollMonthIfNeeded(now: number): void {
    if (!this.quota) return;
    const thisMonth = new Date(now).toISOString().slice(0, 7);
    const lastResetMonth = new Date(this.quota.lastMonthlyResetAt || 0).toISOString().slice(0, 7);
    if (thisMonth !== lastResetMonth) {
      this.quota.monthlyUsed = 0;
      this.quota.lastMonthlyResetAt = now;
    }
  }

  private async handleStatus(): Promise<Response> {
    await this.initialize();

    if (!this.quota) {
      return new Response(
        JSON.stringify({ status: 'uninitialized' }),
        { status: 200, headers: { 'Content-Type': 'application/json' } },
      );
    }

    // The plan needs the org row, which only the check carries; every org route,
    // including the uncharged reads, runs that check before this read (CR58).
    this.rollMonthIfNeeded(Date.now());

    return new Response(
      JSON.stringify({
        orgId: this.quota.orgId,
        planKey: this.quota.planKey,
        quotaVersion: this.quota.quotaVersion,
        minuteLimit: this.quota.minuteLimit,
        monthlyLimit: this.quota.monthlyLimit,
        minuteUsed: this.quota.minuteUsed,
        monthlyUsed: this.quota.monthlyUsed,
        minuteWindowExpiresIn: QUOTA_MINUTE_WINDOW_MS - (Date.now() - this.quota.minuteUsedAt),
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
