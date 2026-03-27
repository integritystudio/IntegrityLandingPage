# Quota Durable Objects Implementation

## Overview

Quota management via Cloudflare Durable Objects provides **globally unique, stateful, single-threaded instances** with strongly consistent attached storage — exactly what's needed for serialized quota mutations.

**Key responsibility:** One Durable Object per organization, responsible for:
- Caching org quota/plan state
- Serializing quota checks (avoid race conditions)
- Tracking current-minute counters (for burst limits)
- Tracking monthly usage deltas before flush
- Rejecting over-limit requests
- Exposing `checkAndReserve()` and `flushUsage()` methods

---

## Architecture

### Request Flow

```
API Request
  ↓
API Gateway (api-gateway worker)
  ↓
Rate Limit Check (Cloudflare binding) ← permissive, for burst control
  ↓
Load org quota/entitlements from Supabase
  ↓
Call Durable Object: checkAndReserve()
  ├→ Serialize quota check
  ├→ Verify minute and monthly limits
  ├→ Reserve units if allowed
  └→ Return QuotaCheckResponse
  ↓
[Reject if denied, or continue]
  ↓
Proxy request to upstream handler
  ↓
Emit usage_events asynchronously
  ↓
[Periodically flush usage to database]
```

### Quota Plan Limits

Default plan quotas are stored in the Durable Object state:

```typescript
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
```

When a quota `quotaVersion` changes (org subscription updated), the Durable Object:
1. Detects version bump
2. Reloads plan limits from `DEFAULT_QUOTAS`
3. Resets current-minute and monthly counters

---

## Request/Response Contracts

### checkAndReserve

**Request:**
```typescript
interface QuotaCheckRequest {
  orgId: string;
  metricKey: string; // e.g. "requests", "otel_events", "agent_runs"
  units: number; // e.g. 1, 50, 1000
  requestId: string; // for idempotency/tracing
  planKey: string; // "free" | "growth" | "enterprise"
  quotaVersion: number; // increments on Stripe webhook
}
```

**Response (200 OK — allowed):**
```typescript
interface QuotaCheckResponse {
  allowed: true;
  remainingMinute?: number;
  remainingMonthly?: number | null;
}
```

**Response (429 Too Many Requests — denied):**
```typescript
interface QuotaCheckResponse {
  allowed: false;
  reason: "minute_limit" | "monthly_limit" | "feature_disabled";
  remainingMinute?: number;
  remainingMonthly?: number | null;
}
```

### flushUsage

Clears the monthly usage counter and returns total units used since last flush.

**Request:** POST `/flush-usage`

**Response:**
```typescript
interface QuotaFlushResult {
  orgId: string;
  monthlyUsedSinceLastFlush: number; // total units since last flush
  flushedAt: string; // ISO 8601 timestamp
}
```

### status

Returns current quota state for debugging and monitoring.

**Request:** GET `/status`

**Response:**
```typescript
{
  orgId: string;
  planKey: string;
  quotaVersion: number;
  minuteLimit: number;
  monthlyLimit: number | null;
  minuteUsed: number;
  monthlyUsed: number;
  minuteWindowExpiresIn: number; // milliseconds
}
```

---

## Integration Points

### 1. API Gateway Routes

Routes that need quota checks should:
1. Load org context (plan, quotaVersion, entitlements)
2. Call `checkAndReserve()` before proxying upstream
3. Track `requestId` for tracing
4. Emit `usage_events` after response

Example (to be implemented in `routes/usage.ts`):

```typescript
import { checkAndReserve } from '../lib/quota';

export async function handleIngestRequest(
  request: Request,
  orgId: string,
  opts: RouteOptions,
): Promise<Response> {
  const sb = createSupabaseClient(opts.supabaseUrl, opts.serviceRoleKey);

  // 1. Verify auth
  const auth = await resolveAuth(request, opts, sb);
  if (!auth.ok) return auth.error;

  // 2. Load org plan/entitlements
  const org = await sb.query('organizations', {
    filters: [{ column: 'id', operator: 'eq', value: orgId }],
    limit: 1,
  });
  const quotaVersion = org.data[0].quota_version;

  // 3. Check quota
  const quotaResult = await checkAndReserve(opts.env.QUOTA_DO, {
    orgId,
    metricKey: 'api_requests',
    units: 1,
    requestId: crypto.randomUUID(),
    planKey: org.data[0].current_plan,
    quotaVersion,
  });

  if (!quotaResult.allowed) {
    return new Response(
      JSON.stringify({
        error: 'Quota exceeded',
        reason: quotaResult.reason,
        remaining: quotaResult.remainingMinute,
      }),
      { status: 429, headers: { 'Content-Type': 'application/json' } },
    );
  }

  // 4. Proxy to upstream, emit usage events async
  // ...
}
```

### 2. Stripe Webhook Handler

When a subscription update arrives, bump the quota version:

```typescript
// In stripe-webhook/src/handlers/subscription.ts
export async function handleSubscriptionUpdated(
  event: StripeEvent,
  orgId: string,
  sb: SupabaseClient,
): Promise<void> {
  // ... update subscriptions, entitlements ...

  // Bump quota version to trigger Durable Object state reset
  await sb.update('organizations', {
    quota_version: orgId, // incrementing this forces DO reload
  });
}
```

### 3. Usage Flush Job

Periodically call `/flush-usage` to reset monthly counters and sync to database:

```typescript
// POST /internal/usage/flush (internal endpoint)
export async function handleFlushUsage(req: Request, env: Env): Promise<Response> {
  // Get list of all active orgs
  const orgs = await getActiveOrganizations(sb);

  for (const org of orgs) {
    try {
      const flushResult = await flushUsage(env.QUOTA_DO, org.id);

      // Record flush event in billing_event_log or audit_log
      await sb.insert('usage_flush_log', {
        organization_id: org.id,
        units_flushed: flushResult.monthlyUsedSinceLastFlush,
        flushed_at: flushResult.flushedAt,
      });
    } catch (err) {
      // Log error, continue to next org
      console.error(`Flush failed for org ${org.id}:`, err);
    }
  }

  return ok({ flushed_orgs: orgs.length });
}
```

---

## How It Works

### Minute-Level Burst Control

1. When `checkAndReserve()` is called:
   - Check if current minute window (last 60s) has expired
   - If yes, reset `minuteUsed = 0` and `minuteUsedAt = now()`
   - If no, add `units` to `minuteUsed`

2. Reject if `minuteUsed + units > minuteLimit`

**Why this approach:**
- Prevents request storms (e.g., 600 rpm = max 10 req/sec for growth)
- Cloudflare RL binding is permissive → DO is exact
- Serialized by single-threaded DO → no race conditions

### Monthly Soft Limit

1. Track cumulative `monthlyUsed` across all requests
2. Reject if `monthlyUsed + units > monthlyLimit`
3. On `flushUsage()`, reset `monthlyUsed = 0`

**Why separate flush:**
- Monthly buckets are computed in database, not DO
- DO provides the quota enforcement layer
- Flush allows graceful handoff to async billing pipeline

### Quota Version Bumps

When Stripe webhook updates org subscription:
1. `quotaVersion++` in database
2. Next `checkAndReserve()` call detects version change
3. DO reloads plan limits and resets counters
4. No cache invalidation needed — version comparison handles it

---

## Testing

Run tests with:
```bash
cd workers/api-gateway
npx vitest run src/durable-objects/quota.test.ts
```

Coverage includes:
- Default plan limit initialization
- Minute-level burst rejection
- Monthly limit enforcement
- Quota version upgrades
- Minute window expiration
- Usage flushing
- Status reporting
- Error handling

---

## Monitoring & Debugging

### Status Endpoint

Check quota state for a specific org:
```bash
curl -X GET https://quota.local/status \
  -H "X-Org-ID: org-123"
```

Returns current `minuteUsed`, `monthlyUsed`, plan limits, etc.

### Logs

Each Durable Object logs state changes to Cloudflare Logpush:
- Quota check attempts
- Over-limit rejections
- Version bumps
- Flush events

### Alerting

Set up alerts for:
- High rejection rate (many 429s) → capacity planning
- Version bump storms → potential billing issue
- Flush failures → check database connectivity

---

## Next Steps

1. ✅ Durable Object implementation
2. ✅ Quota service client
3. ✅ Types and schemas
4. ⏳ **Integrate into API gateway routes** (handle rate-limited requests)
5. ⏳ **Stripe webhook quota version bump**
6. ⏳ **Usage flush job** (daily or hourly)
7. ⏳ **Dashboard** (show usage vs quota to users)
8. ⏳ **Monitoring** (Grafana dashboard for quota metrics)

---

## Durability Guarantee (T28 Decision)

**Decided:** 2026-03-27

### Strategy: Hybrid lazy persistence (accepted)

Quota state is persisted every **10 seconds** (`lastSavedAt` check). On DO eviction or crash between saves, up to 10 seconds of quota usage is silently dropped — counters revert to their last saved values.

**Risk appetite decision:** Acceptable for current plan tiers. Rationale:
- Quota enforcement is a soft limit (protect against abuse, not billing precision)
- Monthly usage is also tracked in `usage_events` table (separate audit trail)
- `flushUsage()` syncs totals to database; short-term DO loss does not affect billing
- Strict synchronous saves (on every reserve) would add ~5ms storage latency per request

**Consistency SLA:**
- Minute burst counter: eventually consistent within 10s window
- Monthly usage counter: eventually consistent within 10s; exact totals recovered from `usage_events` flush
- Idempotency deduplication window: 5 minutes (exact; stored and persisted at same cadence)

**Acceptable loss window:** ≤10 seconds of quota usage on DO eviction. Low-traffic orgs are evicted after ~15 min idle; high-traffic orgs persist indefinitely.

**Cold-start safety:** `constructor` calls `state.blockConcurrencyWhile` to load storage before any `fetch()` is dispatched. Prevents two concurrent cold-start requests both seeing `quota=null` and discarding persisted state.

**If higher durability is required in future:**
- Change `10_000` to `0` in `quota.ts:217` for synchronous per-request saves (~5ms latency cost)
- Or implement a hybrid: save synchronously only when `monthlyUsed` crosses a billing threshold
- Add Cloudflare DO metrics dashboard to track eviction rate and loss frequency

---

## References

- [Cloudflare Durable Objects Docs](https://developers.cloudflare.com/durable-objects/)
- [Rate Limiting Design (Requests per Second)](https://en.wikipedia.org/wiki/Token_bucket)
- [Payments Implementation Plan](../roadmap/payments-implementation.md)
