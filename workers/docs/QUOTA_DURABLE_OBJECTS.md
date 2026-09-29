# Quota Durable Objects Implementation

## Overview

Quota management via Cloudflare Durable Objects provides **globally unique, stateful, single-threaded instances** with strongly consistent attached storage — exactly what's needed for serialized quota mutations.

**Key responsibility:** One Durable Object per organization, responsible for:
- Caching org quota/plan state
- Serializing quota checks (avoid race conditions)
- Tracking current-minute counters (for burst limits)
- Tracking the monthly counter in DO storage (reset on calendar-month rollover)
- Rejecting over-limit requests
- Exposing `checkAndReserve()` and `/status`

There is no flush route. A `POST /flush-usage` that zeroed the monthly counter, wrote nothing to Supabase and had no caller was deleted with its `flushUsage()` client (BACKLOG.md CR45). The durable usage record is written elsewhere — see [Integration Points](#integration-points).

---

## Architecture

### Request Flow

```
API Request  /v1/orgs/:id/*
  ↓
API Gateway (api-gateway worker, src/index.ts)
  ↓
preVerifyToken()  ← 401 here touches no quota
  ↓
enforceOrgQuota(orgId)  (src/lib/quota.ts)
  ├→ Load current_plan + billing_status + quota_version from Supabase
  ├→ planKey = effectivePlan(current_plan, billing_status)  (paid plan only while entitled — CR37)
  ├→ Call Durable Object: checkAndReserve()
  │    ├→ Serialize quota check
  │    ├→ Verify minute and monthly limits
  │    ├→ Reserve units if allowed
  │    └→ Return QuotaCheckResponse
  └→ 429 if denied (with X-RateLimit-Remaining-* headers), else continue
  ↓
Route handler (membership check happens here)
  ↓
recordMeteredRequest() via ctx.waitUntil  (src/lib/usage-ledger.ts, UA01)
  → one usage_events row per reserved unit
  → trigger_upsert_daily_usage_bucket rolls it into usage_buckets_daily
```

`POST /v1/ingest/otel` calls `enforceOrgQuota` the same way from `routes/ingest.ts`.

### Quota Plan Limits

Default plan quotas are stored in the Durable Object state:

```typescript
const DEFAULT_QUOTAS: Record<string, { requestsPerMinute: number; monthlyLimit: number | null }> = {
  // 'starter' is the canonical plan key in DB (current_plan column).
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
DEFAULT_QUOTAS.free = DEFAULT_QUOTAS.starter; // legacy alias for rows still holding 'free'
```

When `quotaVersion` changes (org subscription updated), the Durable Object:
1. Detects the version bump on the next `checkAndReserve()`
2. Reloads plan limits from `DEFAULT_QUOTAS`
3. **Preserves `monthlyUsed`** — resetting it would let an org evade its monthly limit by triggering a bump mid-month

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
  planKey: string; // "starter" | "growth" | "enterprise" ("free" accepted as an alias of starter)
  quotaVersion: number; // set to Date.now() by the Stripe webhook on plan changes
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

### 1. API Gateway Routes — done

`enforceOrgQuota(orgId, opts)` in `src/lib/quota.ts` is the integration. It loads `current_plan`, `billing_status` and `quota_version` for the org, resolves the plan with `effectivePlan` (a paid plan counts only while `isEntitled(billing_status)`; otherwise starter — CR37), calls `checkAndReserve` with `metricKey: 'requests', units: 1`, and returns either `{ ok: true, rateLimitHeaders }` or `{ ok: false, response }` where `response` is a 429 carrying `X-RateLimit-Remaining-Minute` / `X-RateLimit-Remaining-Monthly`. If the DO is unreachable it **fails open** (request allowed, no headers).

Call sites:
- `src/index.ts` — every `/v1/orgs/:id/*` request, after `preVerifyToken` and before the route handler
- `src/routes/ingest.ts` — `POST /v1/ingest/otel`, after API-key resolution

The unit the DO reserves is written durably by `recordMeteredRequest` (`src/lib/usage-ledger.ts`) into `usage_events`, same metric key, same one unit, off the response path via `ctx.waitUntil`. That is what `/v1/orgs/:id/usage/summary` reports.

### 2. Stripe Webhook Handler — done

`updateOrgBillingStatus(orgId, billingStatus, planKey, bumpQuotaVersion)` in `workers/stripe-webhook/src/supabase.ts` sets `quota_version = Date.now()` when `bumpQuotaVersion` is true. The subscription handlers pass `true` so the DO reloads plan limits on the next request. `quota_version` is a `bigint` column, so the millisecond timestamp fits.

### 3. Usage Flush Job — not built, and superseded

None is planned: the usage ledger (UA01, above) writes the durable record per request, so there is no batch to hand off. The dead `/flush-usage` route and its client were deleted (CR45).

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
- Serialized by single-threaded DO → no race conditions

### Monthly Soft Limit

1. Track cumulative `monthlyUsed` across all requests
2. Reject if `monthlyUsed + units > monthlyLimit`
3. Reset `monthlyUsed = 0` when the calendar month rolls over (`lastMonthlyResetAt`)

**Why the database, not the DO, is the billing record:**
- Monthly buckets are computed in the database (`usage_events` → `usage_buckets_daily` trigger), not in the DO
- The DO is the enforcement layer; losing a few seconds of its state affects enforcement precision, not billing

### Quota Version Bumps

When the Stripe webhook updates an org's subscription:
1. `quota_version = Date.now()` in the database
2. Next `checkAndReserve()` call detects the version change
3. DO reloads plan limits; `monthlyUsed` is preserved. A different `planKey` at the **same** version is applied too (CR37: the billing gate changed some orgs' plan without moving their version); a lower version is ignored, so a stale read cannot roll a plan back
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
- `/flush-usage` answers 404 and leaves the counter alone (CR45 regression test)
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

### Alerting

Set up alerts for:
- High rejection rate (many 429s) → capacity planning
- Version bump storms → potential billing issue

---

## Next Steps

1. ✅ Durable Object implementation
2. ✅ Quota service client
3. ✅ Types and schemas
4. ✅ **Integrate into API gateway routes** — `enforceOrgQuota` in `src/index.ts` and `routes/ingest.ts`
5. ✅ **Stripe webhook quota version bump** — `updateOrgBillingStatus(…, true)` sets `quota_version = Date.now()`
6. ❌ **Usage flush job** — superseded by the per-request usage ledger (UA01); the dead `/flush-usage` route was deleted (CR45)
7. ⏳ **Dashboard** (show usage vs quota to users)
8. ⏳ **Monitoring** (Grafana dashboard for quota metrics)

---

## Durability Guarantee (T28 Decision)

**Decided:** 2026-03-27

### Strategy: Hybrid lazy persistence (accepted)

Quota state is persisted at least every **10 seconds** under load (`lastSavedAt` check on the reserve path), and a storage alarm armed on each write persists it ≤10 s after the last request during sparse traffic. On DO eviction or crash between saves, up to 10 seconds of quota usage is silently dropped — counters revert to their last saved values.

**Risk appetite decision:** Acceptable for current plan tiers. Rationale:
- Quota enforcement is a soft limit (protect against abuse, not billing precision)
- The billing record is the `usage_events` ledger written per request (UA01); short-term DO loss does not affect it
- Strict synchronous saves (on every reserve) would add ~5ms storage latency per request

**Consistency SLA:**
- Minute burst counter: eventually consistent within 10s window
- Monthly usage counter: eventually consistent within 10s; exact totals live in `usage_events` / `usage_buckets_daily`
- Idempotency deduplication window: 5 minutes (exact; stored and persisted at same cadence)

**Acceptable loss window:** ≤10 seconds of quota usage on DO eviction. Low-traffic orgs are evicted after ~15 min idle; high-traffic orgs persist indefinitely.

**Cold-start safety:** `constructor` calls `state.blockConcurrencyWhile` to load storage before any `fetch()` is dispatched. Prevents two concurrent cold-start requests both seeing `quota=null` and discarding persisted state.

**If higher durability is required in future:**
- Change the `10_000` in `durable-objects/quota.ts` — both the eager-save check and the alarm delay in `handleCheckAndReserve` — to `0` for synchronous per-request saves (~5ms latency cost)
- Or implement a hybrid: save synchronously only when `monthlyUsed` crosses a billing threshold
- Add Cloudflare DO metrics dashboard to track eviction rate and loss frequency

---

## References

- [Cloudflare Durable Objects Docs](https://developers.cloudflare.com/durable-objects/)
- [Rate Limiting Design (Requests per Second)](https://en.wikipedia.org/wiki/Token_bucket)
- [Payments Implementation Plan](../../docs/research/payments-implementation.md)
