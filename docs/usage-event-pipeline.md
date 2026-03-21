# Usage Event Pipeline Architecture

Complete flow from event capture through monthly billing aggregation.

## Overview

The usage event pipeline captures API consumption metrics in real-time, aggregates them by day for operational dashboards, and rolls up to monthly summaries for billing cycles.

```
┌─────────────────┐
│  API Client     │
│  (JWT/API Key)  │
└────────┬────────┘
         │
         │ POST /v1/ingest/events
         │ (IngestEventRequest)
         ▼
┌──────────────────────────────────┐
│  API Gateway Worker              │
│  ├─ Validate auth (JWT/API key)  │
│  ├─ Validate Zod schema          │
│  ├─ Check org membership         │
│  └─ Insert into usage_events     │
└────────┬─────────────────────────┘
         │
         ├──────► Response: 202 (request_id)
         │
         └──────► waitUntil() ──────────────┐
                                            │
                  ┌─────────────────────────┘
                  │
                  ▼
         ┌──────────────────────────────────┐
         │  Daily Rollup (rollupDailyBucket)│
         │  ├─ Query usage_events by date   │
         │  ├─ Aggregate by metric_key      │
         │  │   - total_quantity            │
         │  │   - request_count             │
         │  │   - avg_latency_ms            │
         │  └─ Upsert into usage_buckets_   │
         │     daily (keyed by org/date/key)│
         └──────────────────────────────────┘
                  │
                  │ (trigger: scheduled job or manual)
                  ▼
         ┌──────────────────────────────────┐
         │ Monthly Rollup                   │
         │ (rollupMonthlyBucket)            │
         │ ├─ Query daily buckets by month  │
         │ ├─ Weighted aggregation by key   │
         │ ├─ Per-metric breakdown          │
         │ └─ Return MonthlyUsageSummary    │
         └──────────────────────────────────┘
                  │
                  ├──────► Usage Dashboard
                  │
                  └──────► Billing System
```

## Layer 1: Event Ingestion

### Endpoint: POST /v1/ingest/events

Capture usage events from API clients with JWT or API key authentication.

**Authentication:**
- JWT Bearer token (user identity)
- API Key (machine identity, org-scoped)

**Request Schema:**
```typescript
{
  org_id: UUID,
  metric_key: string (1-128 chars),
  quantity?: number (default: 1),
  source?: 'api' | 'ingest' | 'job' | 'internal' | 'migration' (default: 'api'),
  route?: string,
  status_code?: 100-599,
  latency_ms?: 0-300000,
  metadata?: Record<string, unknown>
}
```

**Response:**
```typescript
{
  ok: true,
  request_id: UUID
}
```

Status: **202 Accepted** (fire-and-forget)

**Stored as:**
```
usage_events (immutable log):
  id (bigint, auto-increment)
  organization_id (uuid)
  user_id (uuid | null) — JWT claims
  api_key_id (uuid | null) — API key identity
  metric_key (string)
  quantity (bigint)
  route (string)
  status_code (int | null)
  latency_ms (int | null)
  metadata (jsonb)
  request_id (string, idempotency key)
  source (enum)
  created_at (timestamptz)
```

**Key Design:**
- Immutable write-once log prevents reconciliation errors
- Timestamps are server-assigned (not client-provided) for consistency
- `request_id` enables idempotent retries
- Fire-and-forget response (202) allows the handler to return immediately; rollup happens via `ctx.waitUntil()`

### Implementation

File: `/workers/api-gateway/src/routes/ingest.ts`

```typescript
export async function handleIngestEvent(
  request: Request,
  opts: IngestHandlerOptions,
  waitUntil?: (p: Promise<unknown>) => void,
): Promise<Response>
```

**Flow:**
1. Extract & verify bearer token (JWT or API key)
2. Parse and validate request body (Zod)
3. Check org membership (forbid if JWT user not in org)
4. Insert event into `usage_events`
5. Generate request_id (UUID)
6. Schedule daily rollup via `waitUntil()`
7. Return 202 with request_id

**Test Coverage:** 83 tests
- Auth validation (JWT, API key, membership)
- Zod schema validation
- Event insertion with all field types
- Rollup scheduling (waitUntil)
- Error cases (401, 403, 422, 500)

---

## Layer 2: Daily Aggregation

### Function: rollupDailyBucket

Aggregate daily events by metric_key into pre-computed buckets.

**Signature:**
```typescript
async function rollupDailyBucket(
  orgId: string,
  date: string, // YYYY-MM-DD UTC
  sb: SupabaseClient,
): Promise<UsageFlushResult>
```

**Input:**
- Org ID (uuid)
- Date range: `YYYY-MM-DD` 00:00:00 UTC to 23:59:59.999 UTC next day

**Process:**
1. Query `usage_events` for the org and date (limit: 10,000 events to bound memory)
2. Group by `metric_key`
3. For each metric, compute:
   - `total_quantity` = sum of quantities
   - `request_count` = number of events
   - `avg_latency_ms` = mean of non-null latencies (weighted by request count)
4. Upsert into `usage_buckets_daily` keyed by (org_id, bucket_date, metric_key)

**Output Schema:**
```typescript
interface UsageFlushResult {
  organization_id: string;
  events_processed: number;
  buckets_updated: number;
  period: {
    start_date: ISO8601;
    end_date: ISO8601;
  };
  flushed_at: ISO8601;
}
```

**Stored as:**
```
usage_buckets_daily (upsert-safe):
  organization_id (uuid, PK)
  bucket_date (date, PK) — YYYY-MM-DD
  metric_key (string, PK)
  total_quantity (bigint)
  request_count (bigint)
  avg_latency_ms (numeric | null)
  updated_at (timestamptz)
```

**Key Design:**
- **Upsert semantics:** Safe to call multiple times for the same org/date pair
- **Bounded memory:** Max 10,000 events per rollup + max 31 days × 100 metric keys = 3,100 daily buckets
- **Derived latency:** Average latency is computed from raw event latencies, enabling later weighted aggregation

### Implementation

File: `/workers/api-gateway/src/aggregation.ts`

```typescript
export async function rollupDailyBucket(
  orgId: string,
  date: string,
  sb: SupabaseClient,
): Promise<UsageFlushResult>
```

**Trigger:**
- Called via `waitUntil()` in ingest handler (fire-and-forget from request context)
- Can also be manually triggered for backfill or catch-up

**Test Coverage:** 83 ingest tests (covers rollup calls)

---

## Layer 3: Monthly Aggregation

### Function: rollupMonthlyBucket

Aggregate daily buckets across a calendar month into a billing summary.

**Signature:**
```typescript
async function rollupMonthlyBucket(
  orgId: string,
  yearMonth: string, // YYYY-MM UTC
  sb: SupabaseClient,
): Promise<MonthlyUsageSummary>
```

**Input:**
- Org ID (uuid)
- Year-month: `YYYY-MM` (e.g., `2026-03`)
- Automatically determines period: 1st day 00:00:00 UTC to 1st day of next month 00:00:00 UTC

**Process:**
1. Query `usage_buckets_daily` for org and year-month (limit: 31 × 100 = 3,100 buckets)
2. Group by `metric_key`
3. For each metric, compute:
   - `total_quantity` = sum of daily quantities
   - `total_requests` = sum of daily request counts
   - `avg_latency_ms` = weighted mean (sum of daily_avg × daily_count) / total_count
4. Also compute cross-metric totals (total_quantity, total_requests, weighted_latency_ms)
5. Return `MonthlyUsageSummary` with per-metric breakdown

**Output Schema:**
```typescript
interface MonthlyUsageSummary {
  organization_id: UUID;
  year_month: "YYYY-MM";
  total_quantity: number;
  total_requests: number;
  avg_latency_ms: number | null;
  metric_breakdown: Record<string, {
    quantity: number;
    requests: number;
    avg_latency_ms: number | null;
  }>;
  created_at: ISO8601;
  updated_at: ISO8601;
}
```

**Key Design:**
- **Weighted latency:** Accounts for the fact that daily buckets store averages, not raw sums
- **Per-metric breakdown:** Enables granular usage analysis (e.g., "api_requests" vs "data_retention_days")
- **Cross-metric mean is approximate:** Useful for overall health checks, but per-metric analysis is more reliable
- **No database mutation:** Returns computed summary; does not update tables (allows easy replay)

### Implementation

File: `/workers/api-gateway/src/aggregation.ts`

```typescript
export async function rollupMonthlyBucket(
  orgId: string,
  yearMonth: string,
  sb: SupabaseClient,
): Promise<MonthlyUsageSummary>
```

**Trigger:**
- Called by scheduled job (e.g., daily at 00:05 UTC for previous month)
- Or on-demand via dashboard/API for historical analysis

**Test Coverage:** 9 tests
- Valid month parsing (YYYY-MM format)
- Aggregation across multiple days and metrics
- Weighted latency calculation
- Metric breakdown with zero-quantity metrics

---

## Data Flow Summary

| Layer | Input | Process | Output | Storage | Query Pattern |
|-------|-------|---------|--------|---------|---------------|
| **Ingest** | HTTP request | Parse, validate, auth | 202 + request_id | usage_events (append-only) | Ordered by created_at |
| **Daily** | usage_events | Group by date + metric_key | UsageFlushResult | usage_buckets_daily (upsert) | Point query: org/date/key |
| **Monthly** | usage_buckets_daily | Group by month + metric_key | MonthlyUsageSummary | Returned (no persist) | Point query: org/month |

---

## Error Handling

### Ingest Handler
- **401:** No bearer token or invalid token → `unauthorized()`
- **403:** JWT user not in org → `forbidden()`
- **422:** Invalid schema → `unprocessableEntity()` with field errors
- **500:** Database insert fails → `serverError()`

### Daily Rollup
- **Validation Error:** Invalid date format (not YYYY-MM-DD) → throws `Error`
- **Query Error:** Logs to console, returns error in result
- **Upsert Error:** Logs to console, continues with partial result

### Monthly Rollup
- **Validation Error:** Invalid month format (not YYYY-MM) → throws `Error`
- **Query Error:** Throws with context
- **No database mutations:** Safe to replay

---

## Constraints & Limits

| Item | Limit | Reason |
|------|-------|--------|
| Events per daily rollup | 10,000 | Bound memory on edge worker |
| Daily buckets per month | 3,100 (31 × 100) | 31 days × max ~100 distinct metric keys |
| Metric key length | 1–128 chars | Reasonable bound for cardinality |
| Latency range | 0–300,000 ms | 5-minute max API call (reasonable bound) |
| Quantity | ≥ 1 (positive int) | Prevents zero/negative consumption reporting |

---

## Usage Examples

### Ingest a metric
```bash
curl -X POST http://localhost:8080/v1/ingest/events \
  -H "Authorization: Bearer $JWT" \
  -H "Content-Type: application/json" \
  -d '{
    "org_id": "f47ac10b-58cc-4372-a567-0e02b2c3d479",
    "metric_key": "api_requests",
    "quantity": 42,
    "source": "api",
    "latency_ms": 150,
    "status_code": 200
  }'
```

Response:
```json
{
  "ok": true,
  "request_id": "a1b2c3d4-e5f6-7890-abcd-ef1234567890"
}
```

### Query daily buckets
```sql
SELECT * FROM usage_buckets_daily
WHERE organization_id = $1
  AND bucket_date >= $2
  AND bucket_date <= $3
ORDER BY bucket_date, metric_key;
```

### Trigger monthly rollup
```typescript
const summary = await rollupMonthlyBucket('org-uuid', '2026-03', sb);
console.log(summary.metric_breakdown); // { api_requests: { quantity: 1000, requests: 50, avg_latency_ms: 200 }, ... }
```

---

## Security Considerations

1. **Authentication:** JWT (user) or API key (machine) required for ingest
2. **Authorization:** JWT users must be active members; API keys scoped to org
3. **Immutability:** Events are write-once, preventing tampering
4. **Quota Enforcement:** Separate quota layer (`enforceOrgQuota`) limits ingest throughput per plan
5. **Latency Bounds:** Max 300s prevents nonsense values, enables efficient aggregation
6. **Request Idempotency:** `request_id` UUID prevents double-counting on retries

---

## Testing

**Ingest Tests:** `/workers/api-gateway/src/routes/ingest.test.ts` (83 tests)
- Auth validation (JWT, API key)
- Org membership checks
- Zod validation with edge cases
- Event insertion with all field combinations
- Rollup scheduling

**Aggregation Tests:** `/workers/api-gateway/src/aggregation.test.ts` (9 tests)
- Daily rollup with multiple events and metrics
- Monthly rollup with multiple days and metrics
- Weighted latency calculation
- Edge cases (zero events, null latencies)

---

## Future Enhancements

1. **Streaming Aggregation:** For high-volume orgs, compute monthly rolls incrementally as daily buckets arrive
2. **Retention Policy:** Archive usage_events to cold storage after monthly rollup complete
3. **Anomaly Detection:** Alert on unusual metric changes during monthly aggregation
4. **Usage Dashboard:** Real-time visualization of daily/monthly totals per metric
5. **Cost Attribution:** Map metrics to billing line items via entitlements
