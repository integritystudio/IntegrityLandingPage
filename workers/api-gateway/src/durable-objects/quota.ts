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
}

const DEFAULT_QUOTAS: Record<string, { requestsPerMinute: number; monthlyLimit: number | null }> = {
  free: {
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

export class QuotaDurableObject implements DurableObject {
  private state: DurableObjectState;
  private quota: OrganizationQuota | null = null;
  private lastSavedAt: number = Date.now();

  constructor(state: DurableObjectState) {
    this.state = state;
  }

  async initialize(): Promise<void> {
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
      if (!orgId || !metricKey || !units || !requestId || !planKey || quotaVersion === undefined) {
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
          const quotaConfig = DEFAULT_QUOTAS[planKey] || DEFAULT_QUOTAS.free;
          this.quota = {
            orgId,
            planKey,
            quotaVersion,
            minuteLimit: quotaConfig.requestsPerMinute,
            monthlyLimit: quotaConfig.monthlyLimit,
            minuteUsedAt: Date.now(),
            minuteUsed: 0,
            monthlyUsed: 0,
          };
        }
      }

      // Update quota version if it changed (org plan/billing updated)
      if (quotaVersion > this.quota.quotaVersion) {
        const quotaConfig = DEFAULT_QUOTAS[planKey] || DEFAULT_QUOTAS.free;
        this.quota.planKey = planKey;
        this.quota.quotaVersion = quotaVersion;
        this.quota.minuteLimit = quotaConfig.requestsPerMinute;
        this.quota.monthlyLimit = quotaConfig.monthlyLimit;
        this.quota.minuteUsed = 0;
        this.quota.monthlyUsed = 0;
        this.quota.minuteUsedAt = Date.now();
      }

      // Check minute window expiration
      const now = Date.now();
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

      // Reserve units
      this.quota.minuteUsed += units;
      this.quota.monthlyUsed += units;

      // Periodically persist to storage
      if (now - this.lastSavedAt > 10_000) {
        await this.state.storage.put('quota', this.quota);
        this.lastSavedAt = now;
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
}
