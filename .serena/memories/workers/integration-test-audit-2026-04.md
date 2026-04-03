---
name: Integration Tests Mock Removal Audit (April 2026)
description: Analysis of worker test mocks with prioritized opportunities to test production environment more directly
type: project
---

## Executive Summary

Current state: Workers tests rely on `vi.mock()` for ~80% of external dependencies. **Primary opportunity**: Replace mocks with contract tests + optional e2e staging tests using `cloudflare:test` + `fetchMock`. This validates actual request/response pipelines and database interactions.

**High-value targets for removal:**
1. **stripe-webhook** — Heaviest mock load; replace DB mocking with staging Supabase
2. **contact-form** — Add e2e tests with Resend sandbox API
3. **api-gateway** — Remove quota library mock; add DO + staging Supabase e2e
4. **sender-worker** — Already good; minor: evaluate if unit test duplicates e2e coverage

---

## Detailed Analysis by Worker

### 1. **stripe-webhook** (Highest Priority) — Current Approach

**Current mocks:**
- `vi.mock('./supabase', () => ({ createSupabaseAdmin: vi.fn(...) }))` — entire DB layer mocked
- Event handlers (checkout, subscription, invoice) — each mocked with `vi.fn()`
- All handler responses, retry logic, dead-letter state mutations — stubbed

**Test coverage** (~280 tests):
- Signature verification (cryptographic, not mocked ✅)
- Request → handler dispatch logic
- Dead-letter reconciliation (mocked state)
- Error paths and retry logic (mocked responses)

**What's NOT tested directly:**
- Actual Supabase schema (migrations, constraints, indexes)
- Real handler implementations (each tested in isolation, not integration)
- Dead-letter state transitions in real DB (orphaned DL cleanup, transaction semantics)
- Idempotency guard interaction with real table (can miss race conditions)

### 2. **sender-worker** (Good Foundation) — Current Approach

**Current test mix:**
- `index.test.ts` (unit) — Mocks RECEIVER worker binding; tests signing logic
- `index.e2e.test.ts` (e2e) — Uses `SELF.fetch()` + `fetchMock` for Auth0/Supabase ✅
- `auth0.live.test.ts` — Real HTTP to Auth0 (guarded by `LIVE_TESTS`, runs separately)

**What's working well:**
- E2E pattern already established (`cloudflare:test` + `fetchMock`) ✅
- Real crypto signing tested ✅
- Full signup flow validated (Auth0 + Supabase mocked for external APIs)

**Minor opportunity:**
- `index.test.ts` unit tests for RECEIVER mock may duplicate coverage from `index.e2e.test.ts`
- Consider consolidating if e2e is comprehensive

### 3. **api-gateway** (Medium Priority) — Current Approach

**Current mocks:**
- `vi.spyOn(quotaLib, 'enforceOrgQuota').mockResolvedValue(...)` — quota enforcement stubbed
- Durable Objects binding — mocked as empty object `{}`
- Supabase responses — only used indirectly via quota spy

**What's NOT tested:**
- Real Durable Objects quota state (counter increments, reset windows, circuit breaker)
- Quota enforcement integration (auth → quota → rate limit headers → response)
- Org routes with real DO + Supabase (org creation, entitlement queries)

### 4. **contact-form** (Medium Priority) — Current Approach

**Current mocks:**
- `vi.mock('resend', () => ({ Resend: vi.fn(...) }))` — entire email service mocked
- KV rate limiting — tested indirectly (mocked in error paths, no direct tests)
- CSRF token generation — uses real `crypto.subtle` ✅

**What's NOT tested:**
- Real Resend API submission (format, headers, response handling)
- KV namespace state transitions (rate limit bucket increments, circuit breaker)
- CSRF token freshness and expiry (only tested with fixed timestamps)

### 5. **workers/lib** (Already Good)

**Current approach:**
- Zod schema validation tests ✅
- HTTP utility tests against real Request/Response objects ✅
- Type tests with pure TypeScript ✅

**Status**: No changes needed.

---

## Recommended Removal Opportunities (Prioritized)

### Phase 1: stripe-webhook (High Impact, Medium Effort)

**Opportunity 1.1: Replace DB mocking with staging Supabase + contract tests**

| Current | Opportunity | Benefit |
|---------|-------------|---------|
| `vi.mock('./supabase')` with `mockDb` stub | Create `.e2e.test.ts` with real staging DB | Validates actual schema, constraints, indexes |
| All handler responses mocked | Test handlers via real Supabase queries | Catches migration issues, race conditions |
| Dead-letter state mutations stubbed | Use real DL table with transaction rollback | Tests idempotency guard, retry semantics |

**Approach:**
```typescript
// workers/stripe-webhook/src/index.e2e.test.ts
import { SELF, fetchMock } from 'cloudflare:test';

beforeAll(() => fetchMock.activate());

// Mock only external APIs (Stripe signature, Stripe events)
fetchMock.get('https://api.stripe.com').intercept(...).reply(200, { ... });

// Real Supabase + handler logic
const res = await SELF.fetch('https://worker.test/webhook', {
  method: 'POST',
  body: JSON.stringify({ id: 'evt_test', type: 'checkout.session.completed', ... }),
});

expect(res.status).toBe(200);
const body = await res.json();
expect(body.ok).toBe(true);
expect(body.processed).toBe(true);
```

**Test scenarios to add:**
- Idempotency guard: send same event twice → second is skipped, DB only has 1 processed event
- Dead-letter retry: handler fails → DL inserted → cron retry succeeds → DL resolved
- Orphaned DL cleanup: handler succeeds but logProcessedEvent fails → next cron retry runs full handler again
- Handler-specific validation: checkout → Stripe customer linked, subscription → plan extracted

**Guard with environment variable:**
```typescript
const e2eEnabled = typeof crypto !== 'undefined' && !!globalThis.SELF;
// Skip in standard test runs; include in CI optional job
describe.skipIf(!e2eEnabled)('stripe-webhook e2e', () => { ... });
```

---

### Phase 2: contact-form (Medium Impact, Low Effort)

**Opportunity 2.1: Add e2e tests with Resend sandbox API + real KV**

**Approach:**
```typescript
// workers/contact-form/src/index.e2e.test.ts
import { SELF, fetchMock } from 'cloudflare:test';

beforeAll(() => fetchMock.activate());

// Mock only Resend external API
fetchMock.post('https://api.resend.com/emails').reply(200, { id: 'resend-id-123' });

// Real CSRF, KV, Resend format validation
const res = await SELF.fetch('https://worker.test/', {
  method: 'POST',
  headers: { 'content-type': 'application/json', 'origin': 'https://integritystudio.ai' },
  body: JSON.stringify({ name: 'Test', email: 'test@example.com', message: 'Hi' }),
});

expect(res.status).toBe(200);
expect(res.headers.get('x-ratelimit-remaining')).toMatch(/\d+/);
```

**Test scenarios:**
- Valid submission → Resend API called with correct headers and body format
- Rate limit (KV): 5 submissions in 1 minute → 6th fails with 429
- CSRF: token expired by timestamp check → request rejected
- Resend failure → circuit breaker activates after N failures

---

### Phase 3: api-gateway (Medium Impact, Higher Effort)

**Opportunity 3.1: Replace quota library spy with real Durable Objects e2e**

**Approach:**
```typescript
// workers/api-gateway/src/index.e2e.test.ts
import { SELF, fetchMock } from 'cloudflare:test';

// Mock Auth0, real DO + Supabase
const token = await makeJwt({ sub: 'user-123', org_id: 'org-test' }, JWT_SECRET);

const res = await SELF.fetch('https://api.integritystudio.ai/v1/orgs/org-test/usage', {
  method: 'GET',
  headers: { 'authorization': `Bearer ${token}` },
});

expect(res.status).toBe(200);
expect(res.headers.get('x-ratelimit-remaining-minute')).toMatch(/^\d+$/);
```

**Test scenarios:**
- Quota enforcement: 100 req/min limit → 100th succeeds, 101st returns 429 with headers
- Rate limit headers: forwarded correctly on success and failure
- Fail-open: DO unavailable → quota check skipped, request proceeds (with warning)
- Quota reset: after 1 minute window → counter resets

---

### Phase 4: sender-worker (Optional, Low Effort)

**Opportunity 4.1: Evaluate unit test duplication vs. e2e**

**Decision:**
- Check if `index.test.ts` (unit) tests something `index.e2e.test.ts` doesn't
- If e2e covers signing + forwarding, consider removing unit test and relying on e2e only
- If there's value in testing signing logic in isolation, keep but remove RECEIVER mock

**Current unit tests in `index.test.ts`:**
- HMAC-SHA256 signature generation
- Bearer token extraction
- RECEIVER fetch call with signed payload

**Current e2e coverage in `index.e2e.test.ts`:**
- Full signup flow (Auth0 token exchange, user creation, Supabase insert, provision_api_key forward)
- POST /send validation and forwarding to RECEIVER

**Recommendation**: Keep e2e as source of truth. If unit tests are redundant, remove them. If they provide value (fast execution, focused assertion), keep but remove RECEIVER binding mock and test signing directly against crypto API.

---

## Implementation Roadmap

### Week 1: stripe-webhook e2e
1. Create `workers/stripe-webhook/src/index.e2e.test.ts` using `cloudflare:test`
2. Add Stripe signature mocking (fetchMock for external API)
3. Add real handler tests with staging Supabase (wrapped in try/catch for transaction rollback)
4. Add dead-letter reconciliation e2e (idempotency, retry, orphaned cleanup)
5. Update CI to run e2e tests (optional job, non-blocking)

### Week 2: contact-form e2e
1. Create `workers/contact-form/src/index.e2e.test.ts`
2. Add Resend API mocking (fetchMock)
3. Add rate limiting tests with real KV state
4. Refactor existing unit tests to use e2e pattern where applicable

### Week 3: api-gateway e2e
1. Create `workers/api-gateway/src/index.e2e.test.ts`
2. Add real Durable Objects quota enforcement tests
3. Add rate limit header forwarding tests
4. Remove `quotaLib.enforceOrgQuota` spy from unit tests

### Week 4: sender-worker cleanup
1. Audit `index.test.ts` against `index.e2e.test.ts` for duplication
2. Consolidate or remove redundant tests
3. If keeping, remove RECEIVER binding mock

---

## Testing Pattern Template

All new e2e tests should follow this structure:

```typescript
import { describe, it, expect, beforeAll, afterEach } from 'vitest';
import { SELF, fetchMock } from 'cloudflare:test';

beforeAll(() => fetchMock.activate());
afterEach(() => fetchMock.assertNoPendingInterceptors());

describe('Worker E2E', () => {
  it('real request → real handler → mocked external API', async () => {
    // Mock ONLY external APIs (3rd-party services)
    fetchMock.post('https://api.external.com/v1/endpoint')
      .reply(200, JSON.stringify({ ... }), { headers: { 'content-type': 'application/json' } });

    // Use SELF.fetch for real request → handler logic
    const res = await SELF.fetch('https://worker.test/path', {
      method: 'POST',
      headers: { 'content-type': 'application/json' },
      body: JSON.stringify({ ... }),
    });

    expect(res.status).toBe(200);
    const body = await res.json();
    expect(body).toMatchObject({ ... });
    
    // Assert on response shape, not on mock call counts
    // (verify via real database query if needed)
  });
});
```

**Key principles:**
- ✅ Test real request → handler logic → real DB queries
- ✅ Mock external APIs only (3rd-party services like Stripe, Auth0, Resend)
- ✅ Use `SELF.fetch()` not direct function calls
- ✅ Assert on response shape/status and real DB state (via queries), not mock call counts
- ❌ Don't mock handlers or DB layer

---

## CI Integration

Add `.e2e` test files to CI workflow:

```yaml
- name: Run unit tests
  run: npm test

- name: Run E2E tests (optional, non-blocking)
  if: github.ref == 'refs/heads/main'
  continue-on-error: true
  env:
    SUPABASE_URL: ${{ secrets.STAGING_SUPABASE_URL }}
    SUPABASE_SERVICE_ROLE_KEY: ${{ secrets.STAGING_SUPABASE_KEY }}
  run: npm run test:e2e
```

---

## Success Metrics

- ✅ Unit test count decreases (redundant mocks removed)
- ✅ E2E test coverage increases (real pipelines validated)
- ✅ Test execution time stable (e2e slower, but not in main CI path)
- ✅ Integration bugs caught earlier (schema mismatches, constraint violations)
- ✅ Maintenance burden reduced (fewer mock stubs to maintain)
