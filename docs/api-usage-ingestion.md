# Usage Event Ingestion API (V01)

Complete API reference for POST /v1/ingest/events endpoint.

## Overview

The usage ingestion API captures quantified metrics (API calls, jobs, data retention, etc.) for billing, dashboards, and quotas. The API uses fire-and-forget semantics: requests receive immediate 202 Accepted responses while background aggregation happens asynchronously.

## Endpoint

```
POST /v1/ingest/events
```

## Authentication

Two authentication methods are supported:

### JWT Bearer Token (User Identity)
```bash
Authorization: Bearer <jwt_token>
```

- Issued by Supabase Auth or Auth0
- Token must include `sub` (user UUID) claim
- Issuer URL validated against `SUPABASE_JWT_ISSUER` (if configured)
- User must be an active member of the target organization

### API Key (Machine Identity)
```bash
Authorization: Bearer <api_key>
```

- Format: `obtk_<prefix>_<secret>` (e.g., `obtk_prod_abc123...`)
- Scoped to a single organization
- Verified via HMAC-SHA256 against stored hash
- No user context needed; implies organization membership

**Note:** JWT is preferred for application-initiated requests (user actions), while API keys are preferred for programmatic/automated ingestion (backend jobs, webhooks).

## Request

### Headers

```
POST /v1/ingest/events HTTP/1.1
Host: api.integritystudio.ai
Content-Type: application/json
Authorization: Bearer <jwt_or_api_key>
```

### Body

```typescript
{
  org_id: string (UUID),         // Required. Organization to bill for this event.
  metric_key: string,            // Required. 1–128 characters. Metric name (e.g., 'api_requests', 'data_retention_days').
  quantity?: number,             // Optional. Positive integer. Default: 1. Units consumed.
  source?: string,               // Optional. Enum: 'api' | 'ingest' | 'job' | 'internal' | 'migration'. Default: 'api'.
  route?: string,                // Optional. HTTP route or operation name. Used for cost attribution.
  status_code?: number,          // Optional. HTTP status code (100–599). For request metrics.
  latency_ms?: number,           // Optional. Response time in milliseconds (0–300,000). For performance analysis.
  metadata?: object              // Optional. Custom JSON object. Free-form attributes.
}
```

### Schema Details

| Field | Type | Min | Max | Default | Notes |
|-------|------|-----|-----|---------|-------|
| `org_id` | UUID | - | - | - | Must be valid UUID; requester must be member |
| `metric_key` | string | 1 | 128 | - | Alphanumeric + underscore recommended; used as aggregation key |
| `quantity` | int | 1 | - | 1 | Positive only; prevents zero/negative consumption |
| `source` | enum | - | - | 'api' | Categorizes origin: API call, batch job, etc. |
| `route` | string | 1 | - | null | Optional path/operation identifier |
| `status_code` | int | 100 | 599 | null | Optional; useful for tracking error rates |
| `latency_ms` | int | 0 | 300000 | null | Capped at 5 minutes; null if not measured |
| `metadata` | object | - | - | {} | Arbitrary JSON; not indexed (use for debugging) |

### Validation Rules

- **org_id:** Must be a valid UUID; if using JWT, requester must be active member of organization
- **metric_key:** Predefined keys recommended (e.g., `api_requests`, `data_retention_days`), but any 1–128 character string is accepted
- **quantity:** Positive integer only (>= 1)
- **source:** Must be one of the 5 predefined enum values
- **status_code:** If provided, must be 100–599 (valid HTTP range)
- **latency_ms:** If provided, must be 0–300,000 (0–5 minutes)

### Example Requests

**Minimal (JWT):**
```bash
curl -X POST https://api.integritystudio.ai/v1/ingest/events \
  -H "Authorization: Bearer eyJhbGc..." \
  -H "Content-Type: application/json" \
  -d '{
    "org_id": "f47ac10b-58cc-4372-a567-0e02b2c3d479",
    "metric_key": "api_requests"
  }'
```

**Full (API Key):**
```bash
curl -X POST https://api.integritystudio.ai/v1/ingest/events \
  -H "Authorization: Bearer obtk_prod_abcdef1234567890" \
  -H "Content-Type: application/json" \
  -d '{
    "org_id": "f47ac10b-58cc-4372-a567-0e02b2c3d479",
    "metric_key": "api_requests",
    "quantity": 42,
    "source": "api",
    "route": "POST /v1/analyze",
    "status_code": 200,
    "latency_ms": 1250,
    "metadata": {
      "user_id": "alice@example.com",
      "plan": "enterprise",
      "region": "us-east-1"
    }
  }'
```

**Batch (typical workflow):**
```typescript
const events = [
  { org_id: '...', metric_key: 'api_requests', quantity: 5, status_code: 200, latency_ms: 150 },
  { org_id: '...', metric_key: 'data_retention_days', quantity: 30 },
  { org_id: '...', metric_key: 'api_requests', quantity: 2, status_code: 429, latency_ms: 50 },
];

for (const event of events) {
  await fetch('https://api.integritystudio.ai/v1/ingest/events', {
    method: 'POST',
    headers: { 'Authorization': `Bearer ${apiKey}` },
    body: JSON.stringify(event),
  });
}
```

## Response

### Success (202 Accepted)

```json
{
  "ok": true,
  "request_id": "a1b2c3d4-e5f6-7890-abcd-ef1234567890"
}
```

**Status Code:** 202

**Fields:**
- `ok: true` — Event accepted and queued for processing
- `request_id: UUID` — Unique identifier for idempotent retry; can be used to trace the event in logs

**Note:** 202 does not guarantee the event was persisted. The API immediately returns control to the caller while the event is durably stored in the background.

### Errors

#### 400 Bad Request (Malformed JSON)
```json
{
  "error": "Invalid JSON body"
}
```

#### 401 Unauthorized (Missing/Invalid Auth)
```json
{
  "error": "No authorization header"
}
```

Causes:
- Missing `Authorization` header
- Invalid JWT signature
- Invalid API key format
- Expired token

#### 403 Forbidden (Access Denied)
```json
{
  "error": "Not a member of this organization"
}
```

Causes:
- JWT user is not an active member of the target org
- API key belongs to a different org
- User membership is suspended

#### 422 Unprocessable Entity (Schema Validation)
```json
{
  "error": "Validation failed",
  "fieldErrors": {
    "org_id": ["Invalid UUID"],
    "metric_key": ["String must contain at least 1 character(s)"],
    "quantity": ["Number must be greater than or equal to 1"]
  }
}
```

Causes:
- `org_id` not a valid UUID
- `metric_key` is empty or > 128 chars
- `quantity` is 0 or negative
- `status_code` outside 100–599 range
- `latency_ms` < 0 or > 300,000
- Unknown `source` enum value
- `metadata` is not a valid object

#### 500 Internal Server Error
```json
{
  "error": "Failed to store usage event"
}
```

Causes:
- Database connection failure
- Supabase service error
- Worker runtime error

**Retry Policy:** 5xx errors are retriable; use exponential backoff with jitter.

## Data Stored

After a 202 response, the following is durably stored in the database:

```sql
INSERT INTO usage_events (
  organization_id,
  user_id,           -- NULL if API key auth
  api_key_id,        -- NULL if JWT auth
  metric_key,
  quantity,
  source,
  route,
  status_code,
  latency_ms,
  metadata,
  request_id,        -- UUID for idempotency
  created_at         -- Server timestamp (UTC)
) VALUES (...)
```

**Idempotency:** The `request_id` is unique per event. If the same request is submitted twice with the same request body, the database upsert semantics (by request_id) prevent double-counting. Clients can safely retry on network failures.

## Aggregation

After the 202 response is sent, the Worker schedules a background task to aggregate the event:

1. **Daily Rollup (via `ctx.waitUntil()`):** Event is aggregated into `usage_buckets_daily` keyed by (org_id, bucket_date, metric_key)
   - Sums quantities
   - Counts requests
   - Computes average latency
   - Runs asynchronously; does not block the ingest response

2. **Monthly Rollup (triggered separately):** Daily buckets are aggregated into monthly summaries for billing

See [usage-event-pipeline.md](usage-event-pipeline.md) for full details.

## Rate Limiting

Rate limits are enforced per organization via a Durable Object quota manager:

- Limit: Depends on subscription plan (e.g., 10,000 requests/hour for Growth, unlimited for Enterprise)
- Response Headers:
  ```
  X-RateLimit-Limit: 10000
  X-RateLimit-Remaining: 9995
  X-RateLimit-Reset: 1234567890
  ```
- When limit is exceeded: 429 Too Many Requests

**Quota Enforcement:** Uses a sliding-window rate limiter in a Durable Object. The quota check is soft (fail-open): if the DO is unreachable, the request is allowed. This ensures availability over strict quota compliance.

## Recommended Metrics

Metric keys are freeform, but the following are commonly tracked:

| Metric Key | Unit | Source | Example |
|------------|------|--------|---------|
| `api_requests` | count | API calls | 1 per request |
| `data_retention_days` | days | Configuration | 30 days per month |
| `team_members` | count | Org membership | 1 per active member |
| `custom_dashboards` | count | Feature usage | 1 per dashboard created |
| `background_jobs` | count | Internal | 1 per job run |
| `storage_gb` | GB | Data volume | 100 GB per day |

Create custom metrics as needed (e.g., `gpt_tokens`, `email_sends`, `webhook_calls`).

## Client Libraries

### Node.js / TypeScript

```typescript
import fetch from 'node-fetch';

async function ingestEvent(orgId: string, metricKey: string, quantity = 1) {
  const response = await fetch('https://api.integritystudio.ai/v1/ingest/events', {
    method: 'POST',
    headers: {
      'Authorization': `Bearer ${process.env.API_KEY}`,
      'Content-Type': 'application/json',
    },
    body: JSON.stringify({
      org_id: orgId,
      metric_key: metricKey,
      quantity,
      source: 'api',
    }),
  });

  if (!response.ok) {
    const error = await response.json();
    throw new Error(`Ingest failed: ${error.error}`);
  }

  const data = await response.json();
  console.log(`Request ${data.request_id} accepted`);
  return data.request_id;
}
```

### Python

```python
import requests
import os

def ingest_event(org_id, metric_key, quantity=1):
    response = requests.post(
        'https://api.integritystudio.ai/v1/ingest/events',
        headers={
            'Authorization': f"Bearer {os.getenv('API_KEY')}",
            'Content-Type': 'application/json',
        },
        json={
            'org_id': org_id,
            'metric_key': metric_key,
            'quantity': quantity,
            'source': 'api',
        },
    )
    response.raise_for_status()
    return response.json()['request_id']
```

### cURL

```bash
curl -X POST https://api.integritystudio.ai/v1/ingest/events \
  -H "Authorization: Bearer $API_KEY" \
  -H "Content-Type: application/json" \
  -d '{
    "org_id": "f47ac10b-58cc-4372-a567-0e02b2c3d479",
    "metric_key": "api_requests",
    "quantity": 1,
    "latency_ms": 150
  }'
```

## Best Practices

1. **Batch Ingestion:** Avoid rapid individual requests; batch 10–50 events per ingest call if possible
2. **Metric Cardinality:** Keep metric keys to a handful of predefined values; don't create one per customer
3. **Latency Measurement:** Include `latency_ms` for performance monitoring; use `Date.now()` before and after the operation
4. **Idempotent Clients:** Retry on network failures; the API automatically dedupes by request_id (server-side)
5. **Async Processing:** Do not wait for the 202 response to confirm aggregation; it's guaranteed eventual
6. **Metadata for Debugging:** Use `metadata` for contextual information (user_id, region, etc.) but don't rely on it for billing logic

## Testing

### Ingest via JWT

```bash
# Obtain a valid JWT
export JWT=$(curl -s "https://auth.example.com/oauth/token" | jq -r '.access_token')

curl -X POST http://localhost:8080/v1/ingest/events \
  -H "Authorization: Bearer $JWT" \
  -H "Content-Type: application/json" \
  -d '{
    "org_id": "f47ac10b-58cc-4372-a567-0e02b2c3d479",
    "metric_key": "test_metric",
    "quantity": 1
  }'
```

### Ingest via API Key

```bash
export API_KEY="obtk_prod_test1234567890"

curl -X POST http://localhost:8080/v1/ingest/events \
  -H "Authorization: Bearer $API_KEY" \
  -H "Content-Type: application/json" \
  -d '{
    "org_id": "f47ac10b-58cc-4372-a567-0e02b2c3d479",
    "metric_key": "test_metric",
    "quantity": 1
  }'
```

### Verify Event Storage

```sql
SELECT * FROM usage_events
WHERE organization_id = 'f47ac10b-58cc-4372-a567-0e02b2c3d479'
ORDER BY created_at DESC
LIMIT 10;
```

### Verify Daily Rollup

```sql
SELECT * FROM usage_buckets_daily
WHERE organization_id = 'f47ac10b-58cc-4372-a567-0e02b2c3d479'
ORDER BY bucket_date DESC, metric_key
LIMIT 10;
```

## Troubleshooting

| Issue | Cause | Solution |
|-------|-------|----------|
| 401 Unauthorized | Missing/invalid token | Verify JWT is fresh; API key is correct format |
| 403 Forbidden | User not in org | Ensure user is an active member of the target org |
| 422 Validation Failed | Invalid schema | Check field types (org_id must be UUID, quantity >= 1, etc.) |
| Events not aggregated | Daily rollup not triggered | Check Worker logs; ensure `ctx.waitUntil()` is used |
| Missing metadata | Not included in request | Metadata is optional; use if tracking custom attributes |

## Implementation Details

**File:** `/workers/api-gateway/src/routes/ingest.ts`

**Handler:** `handleIngestEvent(request, opts, waitUntil)`

**Dependencies:**
- Supabase client for database access
- JWT verification (Auth0 issuer validation)
- API key HMAC verification
- Zod schema validation
- Daily rollup aggregation

**Test Coverage:** 83 tests
- Auth (JWT, API key, membership)
- Validation (all field types and constraints)
- Event insertion
- Error cases (401, 403, 422, 500)
- Rollup scheduling

See `/workers/api-gateway/src/routes/ingest.test.ts` for test patterns.
