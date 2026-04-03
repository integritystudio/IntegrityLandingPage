---
name: Workers Test Mock Audit
description: Comprehensive analysis of mocks in workers test suite with removal opportunities
type: project
---

## Executive Summary

Workers tests rely heavily on `vi.mock()` for external dependencies. Many can be replaced with more direct testing patterns using `cloudflare:test` + `fetchMock` (already established in sender-worker e2e tests) or contract tests with real Zod schemas.

## By Worker

### 1. **stripe-webhook** (Heaviest Mock Load)

**Current Mocks:**
- `createSupabaseAdmin` → entire DB layer mocked
- All event handlers (checkout, subscription, invoice) → mocked
- Dead-letter logic → tested indirectly through mocks

**Mock Removal Opportunities:**

| What | Current | Opportunity | Benefit |
|------|---------|-------------|---------|
| **Supabase DB calls** | `vi.mock('./supabase', () => ({ createSupabaseAdmin: vi.fn(...) }))` | Use real Supabase staging instance + contract test for schema shape | Validates actual DB writes; catches migrations, constraints |
| **Event handlers** | `vi.mock('./handlers/checkout', () => ({ handleCheckoutSessionCompleted: mockHandleCheckout }))` | Test handlers via real worker fetch + `fetchMock` for Stripe API responses | Validates request→handler→DB pipeline; handler integration |
| **Dead-letter reconciliation** | All DB state mutations mocked | Create staging DB with test org → actual dead-letter write/retry loop | Tests idempotency, retry limits, orphaned DL cleanup |

**Recommended Approach:**
1. Create `.e2e.test.ts` using `cloudflare:test` + `SELF.fetch()` 
2. Mock only **external APIs** (Stripe signature verification, Auth0 responses) via `fetchMock`
3. Keep `vi.mock()` for 3rd-party services, remove for Supabase + handlers
4. Use staging DB with transaction rollback for test isolation

---

### 2. **sender-worker** (Good Foundation; Room for Expansion)

**Current Test Mix:**
- `index.test.ts` → Mocks RECEIVER fetcher (inter-worker call)
- `auth0.live.test.ts` → Real HTTP to Auth0 (guarded by env vars, runs separately)
- `index.e2e.test.ts` → Real worker via `SELF.fetch()` + `fetchMock` for Auth0/Supabase ✅

**Mock Removal Opportunities:**

| What | Current | Opportunity | Benefit |
|------|---------|-------------|---------|
| **RECEIVER binding mock** in `index.test.ts` | Mocks fetcher; tests signing logic in isolation | E2E already covers this; consider removing unit test duplication | Fewer mocks; e2e is the source of truth |
| **Auth0 responses** | `index.e2e.test.ts` uses `fetchMock` ✅ | Already good; keep pattern | Real Auth0 flow validated |
| **Supabase calls** | `index.e2e.test.ts` uses `fetchMock` ✅ | Already good; consider staging instance instead | Would catch actual DB schema mismatches |

**Recommended Approach:**
- Keep `index.e2e.test.ts` as the primary test (it's already well-designed)
- Consider if `index.test.ts` unit tests are redundant (e2e covers signing + forwarding)
- If keeping unit tests, remove RECEIVER mock and test signing directly against real crypto

---

### 3. **receiver-worker** (Minimal Mocks; Well-Designed)

**Current Approach:**
- No `vi.mock()` calls ✅
- Uses real `crypto.subtle` for HMAC verification ✅
- Tests signing logic directly ✅

**Status:** ✅ **Already following best practices. No changes needed.**

---

### 4. **contact-form** (Resend Mock Load; KV Well-Tested) ✅ VERIFIED

**Current Mocks:**
- `Resend` email service → mocked
- KV rate limiting → **directly tested** (lines 886, 920, 958, 1386) ✅
- CSRF token generation → uses real crypto ✅

**Mock Removal Opportunities:**

| What | Current | Opportunity | Benefit |
|------|---------|-------------|---------|
| **Resend email send** | `vi.mock('resend')` → mocks all responses | Create `.e2e.test.ts` with Resend sandbox API key | Validates actual email submission format |
| **KV rate limiting** | ✅ Already tested: rate limit bucket, circuit breaker, token expiry | Optional: extend with staging KV in e2e | Real KV state transitions (low priority) |
| **CSRF token validation** | Uses real crypto ✅ | Already good; extend e2e to test token freshness | Tests token expiry on real timings |

**Recommended Approach:**
1. Create `.e2e.test.ts` with `SELF.fetch()` + `fetchMock` for Resend (primary opportunity)
2. Keep existing KV tests as-is (already comprehensive)
3. Extract mock-to-e2e pattern: same tests, swap `fetchMock` for real API

---

### 5. **api-gateway** (Moderate Mock Load)

**Current Mocks:**
- Supabase queries → mocked via `vi.spyOn(quotaLib, 'enforceOrgQuota')`
- Durable Objects → mocked
- Health endpoint responses → partially mocked

**Mock Removal Opportunities:**

| What | Current | Opportunity | Benefit |
|------|---------|-------------|---------|
| **Quota enforcement** | Spied on; DB responses stubbed | E2E test with real Durable Object + staging DB | Validates quota calculations, headers, rate limit state |
| **Org routes auth** | JWT validation tested with mocks | E2E test with valid JWT + real quota check | Full auth→quota→response pipeline |
| **Health endpoint** | Depends on DB connectivity; can't fully test | E2E test against staging infrastructure | Validates all dependencies (Supabase, DO) |

**Recommended Approach:**
1. Create `.e2e.test.ts` with `SELF.fetch()` using Cloudflare Test Worker runtime
2. Mock only JWT signing/validation logic (expensive to replicate)
3. Use real Durable Objects + staging Supabase for quota tests
4. Keep unit tests for JWT parsing, remove quotaLib spy

---

### 6. **workers/lib** (Tests Are Schema-Focused; Already Good)

**Current Approach:**
- Zod schema tests → real validation, no mocks ✅
- HTTP utilities → tested against real Request/Response ✅
- Type tests → pure TypeScript, no mocks ✅

**Status:** ✅ **No changes needed.**

---

## Patterns & Precedents

### ✅ What's Working (Keep This):
1. **receiver-worker** → No mocks; real crypto
2. **sender-worker e2e** → `cloudflare:test` + `fetchMock` for external APIs
3. **sender-worker live tests** → Real HTTP to Auth0 (guarded by env vars)
4. **lib tests** → Pure schema validation, no mocks

### ❌ What Can Improve:
1. **stripe-webhook** → Heavy DB mocking; replace with staging DB + contract tests
2. **contact-form** → Resend mocked; add e2e with real API (KV tests already solid ✅)
3. **api-gateway** → Quota spy; replace with e2e + real DO
4. **sender-worker unit test** → RECEIVER mock may be redundant vs. e2e

---

## Recommended Implementation Order

### Phase 1 (High Impact, Low Effort)
1. **stripe-webhook**: Add `.e2e.test.ts` using `fetchMock` for Stripe + real handlers (no handler mocks)
   - Keep existing tests but remove `vi.mock('./handlers/*')`
   - Add staging DB integration test for dead-letter flow
   
2. **contact-form**: Add `.e2e.test.ts` with Resend sandbox API (Resend e2e only; KV already well-tested)

### Phase 2 (Medium Effort)
3. **api-gateway**: Add `.e2e.test.ts` with real Durable Objects + staging Supabase
   - Keep JWT unit tests, remove quota spy

### Phase 3 (Optional)
4. **sender-worker**: Evaluate if `index.test.ts` unit tests duplicate coverage from `index.e2e.test.ts`
   - If yes, consolidate into e2e
   - If no, keep both but remove RECEIVER mock from unit test

---

## Testing Pattern Template (For New E2E Files)

```typescript
// workers/*/src/index.e2e.test.ts
import { describe, it, expect, beforeAll, afterEach } from 'vitest';
import { SELF, fetchMock } from 'cloudflare:test';

beforeAll(() => fetchMock.activate());
afterEach(() => fetchMock.assertNoPendingInterceptors());

describe('Worker E2E', () => {
  it('real request → real handler → mocked external API', async () => {
    // Mock only external APIs (Stripe, Auth0, Resend, etc.)
    fetchMock.get('https://api.stripe.com')
      .intercept({ path: '/v1/webhooks/...', method: 'POST' })
      .reply(200, { ...response });
    
    // Use SELF.fetch to invoke worker real code path
    const res = await SELF.fetch('https://worker.test/webhook', {
      method: 'POST',
      body: JSON.stringify({ ... }),
    });
    
    expect(res.status).toBe(200);
    // Assert on response, not on mocked function calls
  });
});
```

**Key Principles:**
- ✅ Test real request → handler logic → real DB queries
- ✅ Mock external APIs only (3rd-party services)
- ✅ Use `SELF.fetch()` not direct function calls
- ✅ Assert on response shape/status, not mock call counts
- ❌ Don't mock handlers or DB layer
