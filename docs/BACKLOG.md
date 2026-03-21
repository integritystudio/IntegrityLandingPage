# Backlog

Open and deferred items only. Completed items are migrated to `docs/changelog/1.0/CHANGELOG.md` and `docs/changelog/1.1/CHANGELOG.md`.

**Last Updated:** 2026-03-20

---

## Phase 4 Remaining Items (Substantially Complete)

**Status:** Phase 1–4 substantially complete as of 2026-03-20. These items are essential for v1 release completion:

### V01: Usage Ledger Ingestion

**Priority:** P1 | **Estimated:** 6–8 hours

Implement event ingestion pipeline for metered usage tracking:

1. Create `/v1/ingest/events` endpoint accepting POST requests
2. Validate and store `usage_events` rows (org_id, metric_key, quantity, request_id, source, status_code, latency_ms)
3. Emit async task to aggregate daily bucket (`usage_buckets_daily`)
4. Return 202 Accepted for fire-and-forget ingest
5. Add query helpers for usage summaries by org/date/metric

**Files to implement:**
- `workers/api-gateway/src/routes/ingest.ts` — event handler
- `workers/api-gateway/src/aggregation.ts` — daily bucket rollup task
- Supabase integration for writes

**Status:** Deferred — Core infrastructure complete, ingest endpoint not yet wired.

---

### V02: Flutter Dashboard UI

**Priority:** P1 | **Estimated:** 10–12 hours

Implement authenticated dashboard with org switching, billing status, usage summaries, and entitlements display:

1. Create dashboard page with org switcher dropdown
2. Display current plan, billing status, next renewal date
3. Show monthly usage vs quota (bar/line chart for metrics)
4. Display feature entitlements grid (enabled/disabled flags)
5. Link to Stripe Customer Portal for billing self-service
6. Add real-time usage polling (refresh every 30s or on focus)
7. Error boundary and loading states for all async operations

**Architecture:**
- Use `provisioning_service.dart` for bootstrap/org context
- Integrate with `GET /v1/orgs/:id/dashboard`, `/v1/orgs/:id/usage/summary`, `/v1/orgs/:id/entitlements`
- Local state: active_org, entitlements, usage_snapshot (cached, TTL 30s)
- Global state: org_list, billing_status (cached, TTL 5min)

**Files to create:**
- `lib/pages/dashboard_page.dart`
- `lib/widgets/sections/dashboard_section.dart`
- `lib/services/dashboard_service.dart` (API client wrapper)

**Status:** Deferred — API gateway ready, Flutter UI scaffolding only.

---

## Deferred: OAuth Security (#8-#10)

## Deferred: OAuth Security (#8-#10)

These issues are **deferred** because this is a landing page with placeholder OAuth callback UI and no OAuth backend.
When OAuth is implemented, these MUST be added.

| Issue | Severity | Description |
|-------|----------|-------------|
| #8 OAuth State Validation | CRITICAL | CSRF via unvalidated `state` parameter |
| #9 PKCE Implementation | CRITICAL | Authorization code interception (RFC 7636) |

See git history for full implementation plans (removed from backlog on 2026-02-12 migration to CHANGELOG).

---

## Accepted Risk

### #23: KV Eventual Consistency Window

**Severity:** HIGH (accepted risk)
**Category:** Reliability
**File:** `workers/contact-form/src/index.ts:130-152`

KV is eventually consistent. Two requests from same IP at different datacenters can both read count=4, both increment to 5. Rate limit can be exceeded by ~2-3x.

**Status:** Accepted risk for contact form use case.

---

### #30: Multi-Environment CSP Endpoints

**Severity:** LOW (accepted)
**Category:** Infrastructure
**File:** `web/_headers`

Sentry `ingest.sentry.io` endpoint shared across staging and prod. CSP allows only one DSN per environment. Report DSN collision ignored when worker's `ENVIRONMENT` env var is not set (CF free plan limit).

**Status:** Accepted for landing page use case. Documented in `web/_headers`. If env-specific reporting is needed, use a build script to replace the DSN.

---

## Deferred: Chrome Platform Tests (#77)

### #77: `flutter test --platform chrome` Hangs Indefinitely

**Severity:** CRITICAL
**Category:** Test Infrastructure (Platform-Level)
**File:** N/A — Flutter SDK issue
**Source:** Session 2026-02-12, validated 2026-02-25

`flutter test --platform chrome` (CanvasKit + headless Chrome) hangs on **exit** after all tests pass. Affects CI pipelines: test suite completes, Chrome stays alive, process never exits until CI timeout.

**Upstream:** [Flutter #162798](https://github.com/flutter/flutter/issues/162798) — OPEN, marked for next stable release.

**Workaround:** N/A effective. Blocking factor.

**Status:** Blocked — `flutter test --platform chrome` hangs indefinitely (upstream Flutter issue #162798). Next stable v3.44 planned May 2026 with fix.

---

## Deferred: E2E Test Coverage Limitations (Flutter Canvas)

---

### #116: Page-Specific Meta Tags Per Route

**Severity:** LOW
**Category:** E2E Test Coverage (SEO)
**Files:** `e2e/tests/seo-meta.spec.ts`
**Source:** Coverage gap analysis 2026-03-11

Meta tags tested for home page only. Gaps:
- Dynamic `og:title`, `og:description` per route (e.g., `/pricing` should have "Pricing" in og:title)
- Route-specific canonical URLs
- Hreflang tags for i18n (if deployed)
- Page-specific JSON-LD (e.g., `Product` schema for /pricing)

**Status:** Deferred — Flutter SPA serves the same index.html for all routes; per-route meta requires Cloudflare Workers or edge-side rendering to inject dynamic tags. P3 SEO enhancement.

---


## Feature: Resume Upload on Careers Contact Form (#132)

### #132: Add File Upload to /contact?ref=careers

**Priority**: P2 | **Source**: session 2026-03-11

Add a file upload button (resume PDF/DOCX) to the contact form when `ref=careers`. Recommended architecture:

```
Browser (file_picker) → multipart POST → CF Worker → R2 bucket → Resend (path: r2_url)
```

This keeps CPU usage minimal and avoids the Cloudflare Workers free plan 10ms CPU limit. For a typical resume PDF (100KB–2MB), direct base64 encoding in the Worker might also work but is less reliable on the free tier.

**Key constraints:**
- `file_picker` package recommended for Flutter web file selection
- Resend supports attachments via `attachments[].path` (public URL) or `attachments[].content` (base64)
- Resend limit: 40MB per email (~30MB raw after base64 overhead)
- CF Workers free plan: 10ms CPU limit — base64 encoding large files can exceed this
- R2 approach avoids CPU-bound encoding; Resend fetches from the R2 URL server-side
- Blocked file types (Resend): `.exe`, `.bat`, `.js`, `.ps1`, etc. PDFs/DOCX are fine

**Implementation steps:**
1. Add `file_picker` dependency, show upload widget on `/contact?ref=careers`
2. Create R2 bucket for resume uploads
3. Update CF Worker to accept multipart POST, write file to R2, pass R2 URL to Resend
4. Add file type/size validation (client + server)

**Status:** Deferred — requires R2 bucket provisioning and Worker update.

---

### #133: Revert Careers CTA to "Submit Your Resume" After File Upload

**Priority**: P3 | **Source**: session 2026-03-11

Once #132 (resume upload) is implemented, revert the careers page CTA and copy:
- Button text: "Keep in Touch" → "Submit Your Resume"
- Description: restore "Send us your resume and a brief introduction..." (add "resume" back)

**Status:** Blocked on #132.

---

## Deferred: Server-Side Security Headers

These issues require **server-side HTTP response header configuration** and cannot be fixed in the Flutter app.

---

### S01: Add `frame-ancestors` CSP Header for Clickjacking Protection

**Priority:** P1 | **Source:** session 2026-03-20, code-reviewer (commit ec1fc78)

**Status:** Blocked on server configuration

The `frame-ancestors` directive controls who can embed this site in an iframe (clickjacking defense). The directive is currently missing from **both** the HTTP response headers and the `<meta>` CSP tag. CSP directives in `<meta>` tags are silently ignored for `frame-ancestors` — it **must** be delivered via HTTP response header.

**Required:**
- Add `frame-ancestors 'self';` to the server's CSP HTTP response header (production domain only)
- Remove from `<meta>` tag (already removed in ec1fc78)
- This requires Cloudflare Workers (`_headers` file) or similar edge configuration, not Flutter app changes

**File:** Server configuration (e.g., `web/_headers` or Cloudflare Workers config)

**Reason deferred:** Requires server-side deployment; cannot be fixed in Flutter app.

---

## Open Items

## Code Review Findings (Last 4 Commits: 00d7127, 94d26d0, e623040, e89fd7d)

**Date:** 2026-03-20 | **Reviewer:** code-reviewer agent

### R01: Add Clarifying Comment for `sanitizeServerError` Multi-Line Guard

**Priority:** P3 | **Severity:** Medium | **Source:** code-reviewer (commit 00d7127)

`lib/utils/security_utils.dart:218–223` — The `raw.contains('\r')` guard blocks CRLF multi-line messages, but the same control characters are also stripped by `sanitizeUserInput` via the `codeUnit < 32` check (line 49). This creates redundancy with unclear layering intent. Add a comment explaining whether this is a defense-in-depth measure or if one guard should be removed.

**File:** `lib/utils/security_utils.dart:218–223`

**Status:** Done — Clarifying comment added (commit d186f1d)

---

### R02: Document `_stackTracePattern` Extension List Limitations

**Priority:** P4 | **Severity:** Low | **Source:** code-reviewer (commit 00d7127)

`lib/utils/security_utils.dart:210` — The regex matches `.dart|.js|.ts|.cjs|.mjs|.wasm` file extensions but not `.py` or `.rb`. This is a known accepted-risk gap for the current deployed stack, but it is undocumented in the code comment. Add a brief note that the extension list is intentionally limited to current runtimes and should be extended if the backend runtime changes.

**File:** `lib/utils/security_utils.dart:205–210`

**Status:** Open — Needs documentation update

---

### R03: Add Isolated Test for Bare Carriage Return (`\r`) in `sanitizeServerError`

**Priority:** P4 | **Severity:** Low | **Source:** code-reviewer (commit 00d7127)

`test/utils/security_utils_test.dart:396–401` — The CRLF test uses `'line1\r\nline2'`, which would be blocked by the pre-existing `contains('\n')` check alone. The test does not isolate the `\r`-specific guard. Add a test with bare `'line1\rline2'` to verify the new `\r` guard independently.

**File:** `test/utils/security_utils_test.dart`

**Status:** Done — Isolated \r test added (commit bfc0d0c)

---

### R04: Add Performance Comment to `_stackTracePattern` Static Final

**Priority:** P4 | **Severity:** Low | **Source:** code-reviewer (commit 00d7127)

`lib/utils/security_utils.dart:209–210` — `_stackTracePattern` is correctly declared `static final` (compile once, reuse), but the performance motivation is undocumented. Add a one-liner explaining that `RegExp` compilation is expensive and should not be repeated in hot loops.

**File:** `lib/utils/security_utils.dart:209–210`

**Status:** Open — Needs documentation update

---

### R05: Dedup `PasswordPolicy.minLength` Test Assertions

**Priority:** P3 | **Severity:** Medium | **Source:** code-reviewer (commit 94d26d0)

`test/config/constants_test.dart:93–107` — Tests `'minLength is at least 8 characters'` (asserts `greaterThanOrEqualTo(8)`) and `'minLength is 8 for DOS protection'` (asserts `equals(8)`) both verify the same property. The `equals(8)` assertion strictly subsumes the `greaterThanOrEqualTo(8)` one, adding noise and creating redundant failure modes. Remove one or rephrase to cover a distinct property (e.g., `minLength < maxLength / 2` as a proportionality check).

**File:** `test/config/constants_test.dart:93–107`

**Status:** Done — Replaced with proportionality check (commit 9ec3af4)

---

### R06: Remove Backlog ID from Test Group Name

**Priority:** P4 | **Severity:** Low | **Source:** code-reviewer (commit 94d26d0)

`test/config/constants_test.dart:92` — Test group is named `'PasswordPolicy (L21: shared constants)'`, embedding a transient backlog ID. Once the item is archived, the label becomes misleading. Use a plain descriptive name like `'PasswordPolicy'`.

**File:** `test/config/constants_test.dart:92`

**Status:** Done — Group renamed to 'PasswordPolicy' (commit 7f116c1)

---

### R07: Add Boundary Tests for `PasswordPolicy` Min/Max Length

**Priority:** P4 | **Severity:** Low | **Source:** code-reviewer (commit 94d26d0)

`test/config/constants_test.dart` — No test verifies what happens when a password is exactly `minLength` or exactly `maxLength` characters. These boundary values are the most likely to regress if constants shift. Add tests in the auth-page widget tests (not here) to verify passwords of exactly 8 and 128 chars pass validation.

**File:** `test/pages/auth_page.dart` (or integrate into existing validation tests)

**Status:** Open — Add boundary value tests

---

### R08: Update TDD Report with Current `_stackTracePattern` Regex

**Priority:** P4 | **Severity:** Low | **Source:** code-reviewer (commit e623040)

`docs/TDD_SESSION_REPORT.md:55–58` — The code snippet shows the original regex `\.(dart|js|ts):\d` from commit `4554f81`, but commit `00d7127` extended it to include `cjs|mjs|wasm`. The report was not updated to reflect the amended pattern. Update the snippet to match current source.

**File:** `docs/TDD_SESSION_REPORT.md:55–58`

**Status:** Open — Update documentation snapshot

---

### R09: Back-Fill Commit Hashes in Changelog v1.1

**Priority:** P4 | **Severity:** Low | **Source:** code-reviewer (commit e89fd7d)

`docs/changelog/1.1/CHANGELOG.md:398` (M14, M15, M16, L19, L20) — Entries read `Commit: session 2026-03-20` instead of real git hashes. This breaks traceability. Back-fill with actual commit hashes from `git log`.

**File:** `docs/changelog/1.1/CHANGELOG.md`

**Status:** Open — Add missing commit references

---

### R10: Remove Duplicate M07 Entry from Open Items

**Priority:** P4 | **Severity:** Low | **Source:** code-reviewer (commit e89fd7d)

`docs/BACKLOG.md:162–171` — M07 is listed in the changelog as done but still appears under `## Open Items` with a `Status: Done` footnote. The migration was supposed to remove Done items. Remove the M07 entry from this file.

**File:** `docs/BACKLOG.md:162–171`

**Status:** Open — Clean up duplicate entry

---

---

## Payment Processor Security Remediation

Deferred security hardening for the two-layer authentication and billing system. Findings documented in `docs/security/SECURITY_VULNERABILITY_REPORT.md` and `docs/reports/JWT_COMPLIANCE_REVIEW.md`.

---

### M18: JWT Phase 1 Remediation (CRITICAL)

**Priority:** P1 | **Source:** session 2026-03-21, JWT_COMPLIANCE_REVIEW.md findings

**Partially complete** — V-02 (`iss` validation) implemented in commit 00bfaaf. Still open:

1. **V-01: Remove mutable claims from JWT** — Remove `billing_status` and `plan` from token; query server-side instead. Requires `supabase/custom-access-token-hook.ts` update (Edge Function, not in this repo).
2. **V-02: Add `iss` validation** — ✅ DONE (commit 00bfaaf). `verifyJwt` accepts optional `issuerUrl`; api-gateway threads `SUPABASE_JWT_ISSUER` env var through all route opts.
3. **Normalize RS256** — Requires Supabase project setting change (not code change).

**Status:** Partial — V-02 done. V-01 and RS256 blocked on Supabase project config/hook deployment.

---

### H19: Timing-Safe Hash Comparisons (CRITICAL)

**Priority:** P1 | **Source:** session 2026-03-21 | **Commit:** 0f9cece

✅ **DONE** — Both comparison sites replaced with `crypto.subtle.verify()` (constant-time):

1. **V-03: API key hash verification** — `workers/lib/api-keys.ts:verifyApiKeyHash` now uses `crypto.subtle.verify('HMAC', ...)` with hex-to-bytes conversion.
2. **V-04: Stripe webhook signature verification** — `workers/stripe-webhook/src/verify.ts` validates hex, converts to bytes, uses `crypto.subtle.verify('HMAC', ...)`.

**Status:** ✅ DONE — commit 0f9cece. All 22 tests passing.

---

### H20: IDOR Prevention — Org Membership Authorization (HIGH)

**Priority:** P2 | **Source:** session 2026-03-21, SECURITY_VULNERABILITY_REPORT.md (V-10)
**Estimated:** 4–5 hours

Add organization membership checks to all data access endpoints to prevent IDOR (Insecure Direct Object Reference) attacks. Currently, a user with a JWT for org A could potentially access org B's data if they craft direct requests.

**Pattern to implement:**
```typescript
// Middleware to verify user membership in requested org
async function requireOrgMembership(orgId: string, userJWT: string, env: Env) {
  const payload = await verifyJWT(userJWT, env);
  if (!payload.org_ids.includes(orgId)) {
    return { error: 'forbidden', status: 403 };
  }
  return { allowed: true };
}
```

**Endpoints to add checks:**
- GET `/api/orgs/{orgId}/subscriptions` — Verify caller is org member
- POST `/api/orgs/{orgId}/api-keys` — Verify caller is org admin/owner
- GET `/api/orgs/{orgId}/usage` — Verify caller is org member
- Any endpoint with `:orgId` path parameter

**Files to create/modify:**
- `workers/middleware/org-auth.ts` (new)
- `workers/routes/api.ts` (integrate middleware)

**Status:** Deferred — Requires middleware layer, testing, and endpoint audit.

---

### T22: Durable Object Quota Enforcement Implementation

**Priority:** P2 | **Source:** session 2026-03-21, completed 2026-03-20
**Estimated:** 8–10 hours | **Actual:** Complete

✅ **COMPLETE** — Per-org quota Durable Object fully implemented with minute-level burst control and monthly soft limits.

**Completed in this session:**
1. ✅ `workers/api-gateway/src/durable-objects/quota.ts` (253 lines) — Full Durable Object state machine
   - Minute-level burst control (60-second rolling windows)
   - Monthly soft limit enforcement
   - Quota version detection (triggers on Stripe webhook bumps)
   - Idempotent requestId tracking (5-minute TTL)
   - Three endpoints: `/check-and-reserve`, `/flush-usage`, `/status`
2. ✅ `workers/api-gateway/src/lib/quota.ts` (94 lines) — Type-safe service client
   - `checkAndReserve()` — Check and reserve quota units
   - `flushUsage()` — Clear monthly counter
   - `getQuotaStatus()` — Get current quota state
3. ✅ `workers/lib/types/schemas.ts` — Zod validation schemas
   - `QuotaCheckRequestSchema`, `QuotaCheckResponseSchema`, `QuotaFlushResultSchema`
   - `OrganizationQuotaSchema`, `QuotaStatusResponseSchema` (new)
4. ✅ `wrangler.toml` — Durable Object binding and migrations configured
5. ✅ `workers/docs/QUOTA_DURABLE_OBJECTS.md` (359 lines) — Comprehensive architecture documentation with integration guidance

**Next steps:** Wire into API gateway routes (T26) and write integration tests (T27).

**Status:** ✅ COMPLETE — Ready for integration into API gateway request handlers.

---

### T23: Webhook Resilience & Dead Letter Queue (Phase 1 of DR)

**Priority:** P2 | **Source:** session 2026-03-21 | **Commit:** 71153fc

Implement webhook idempotency and dead letter queue for Stripe webhook processing to prevent missed events during outages.

**Scope:**
1. Create `webhook_dead_letters` table (schema provided in DR plan)
2. Update `workers/webhooks/stripe.ts` to:
   - Store incoming event in dead letter queue on processing failure
   - Use `stripe_event_id` as idempotency key (Stripe event IDs are globally unique)
3. Create `workers/reconciliation-cron.ts` — Runs every 15 min to:
   - Retry pending dead letters with exponential backoff
   - Detect gaps: fetch recent Stripe events, verify local processing
4. Add database index on `webhook_dead_letters (status, next_retry_at)`

**Files to create/modify:**
- `supabase/migrations/20260321000000_add_webhook_dead_letters.sql` (schema)
- `workers/webhooks/stripe.ts` (update to write dead letters on failure)
- `workers/reconciliation-cron.ts` (new)
- `wrangler.toml` (add cron trigger)

**Status:** ✅ DONE — commit 71153fc. Schema migration, idempotency log, dead letter insert on failure, reconciliation cron (every 15 min), wrangler.toml cron trigger.

---

### T24: Full Reconciliation Script Implementation

**Priority:** P2 | **Source:** session 2026-03-21, DISASTER_RECOVERY_PLAN.md (Scenario E)
**Estimated:** 3–4 hours

Implement the "nuclear option" full reconciliation script to rebuild billing state from Stripe after data corruption or extended outage.

**Scope:**
1. Create `scripts/full-reconciliation.ts` (implementation provided in DR plan)
2. Script pulls all Stripe customers + subscriptions
3. Upserts to `organizations` and `subscriptions` tables
4. Calls `provisionEntitlements()` to rebuild entitlements from tier
5. Add safety: dry-run mode with summary before applying
6. Document runbook: when to trigger, what to monitor, expected duration

**Status:** ✅ DONE — commit 156bec1. `scripts/full-reconciliation.ts` with --dry-run mode, pages all Stripe customers, upserts orgs/subscriptions/entitlements.

---

### T25: Health Check & Monitoring Endpoints

**Priority:** P3 | **Source:** session 2026-03-21 | **Commit:** a9a034f

**Partially complete** — Health endpoint upgraded in commit a9a034f:
- `/health` on api-gateway now checks Supabase connectivity + DO liveness
- Returns `{ database, durableObjects, timestamp }`, 200 if all healthy, 503 otherwise
- Still open: PagerDuty integration and monitoring dashboard configuration

**Status:** Partial — Core health endpoint done. Alerting integration (PagerDuty) deferred.

---

---

## Quota Durable Object Integration & Testing

Items identified in session 2026-03-20: quota.ts idempotency and monthly reset fixes applied, but integration and test gaps remain.

---

### T26: Wire Quota Checks Into API Gateway Request Handler

**Priority:** P1 | **Source:** session 2026-03-20, follows T22 completion
**Estimated:** 3–4 hours

Wire the completed quota Durable Object into the API gateway request handler. Routes currently do not enforce quotas — all requests are allowed regardless of plan.

**Scope:**
1. Import `checkAndReserve()` from `workers/api-gateway/src/lib/quota.ts`
2. Extract `orgId`, `planKey`, `quotaVersion` from JWT/API key in request context
3. Generate idempotent `requestId` (uuid-based)
4. Call `checkAndReserve()` before executing route handler
5. Return 429 if quota exceeded; include `reason` and remaining units in response
6. Apply to all metered endpoints (`/v1/ingest/events`, `/v1/orgs/:id/dashboard`, etc.)

**Implementation pattern:**
```typescript
const quotaCheck = await checkAndReserve(env.QUOTA_DO, {
  orgId,
  metricKey: 'api_requests',
  units: 1,
  requestId: crypto.randomUUID(),
  planKey,
  quotaVersion,
});

if (!quotaCheck.allowed) {
  return new Response(JSON.stringify({
    error: 'Quota exceeded',
    reason: quotaCheck.reason,
    remaining_minute: quotaCheck.remainingMinute,
  }), { status: 429 });
}
```

**Files to modify:**
- `workers/api-gateway/src/index.ts` — Add quota check middleware
- `workers/api-gateway/src/routes/*.ts` — Wire middleware into all protected routes

**Status:** ✅ Done — `enforceOrgQuota()` added to `lib/quota.ts`; wired into all org-specific routes in `index.ts` (commits bb1d810, d58f382). Fetches org plan from DB, calls `checkAndReserve()`, returns 429 with `X-RateLimit-Remaining-*` headers. Fail-open if DO unavailable.

---

### T27: Write Integration Tests for Quota Durable Object

**Priority:** P2 | **Source:** session 2026-03-20, follows T22 completion
**Estimated:** 4–6 hours

Write comprehensive integration tests for the completed quota Durable Object. Current test file (`workers/api-gateway/src/durable-objects/quota.test.ts`) contains only placeholder stubs (35 lines). No actual validation of quota logic.

**Scope:**
1. Set up Wrangler miniflare environment for local DO testing (`npm run test:workers`)
2. Write integration tests covering core logic:
   - Request under minute limit → allowed, returns remaining units
   - Request exceeding minute limit → 429 + reason: "minute_limit"
   - Request exceeding monthly limit → 429 + reason: "monthly_limit"
   - Identical `requestId` retried within 5min window → allowed without double-counting
   - `requestId` older than 5min cleaned up (no memory leak)
   - 60-second window expiry → `minuteUsed` reset to 0
   - `quotaVersion` bump → all counters reset
   - Concurrent requests to same org (DO serialization) → quota checks strictly ordered
3. Edge cases:
   - Enterprise plan (no monthly limit) → only check minute limit
   - Exact boundary: `minuteUsed == minuteLimit` → next request rejected
   - Free plan (60 rpm, 10k/month) → enforce both limits
   - Default quotas loaded from `DEFAULT_QUOTAS` map

**Test structure:**
```typescript
describe('QuotaDurableObject integration', () => {
  it('should reject requests exceeding minute limit', async () => {
    // setup: create DO with free plan (60 rpm)
    // act: send 61 requests in rapid succession
    // assert: 61st request returns 429 with remainingMinute = 0
  });
  // ... more tests
});
```

**Files to create/modify:**
- `workers/api-gateway/src/durable-objects/quota.test.ts` — Full test suite (replace stubs)

**Status:** Pending (P2) — T22 complete, test scaffolding exists, needs implementation.

---

### T28: Handle Persistent Storage Data Loss Risk in Quota DO

**Priority:** P3 | **Source:** session 2026-03-20, quota commit review (523518f)
**Estimated:** 2–3 hours

Quota state is lazily persisted to Durable Object storage every 10 seconds (`workers/api-gateway/src/durable-objects/quota.ts:174–177`). If the DO crashes or is evicted between saves, up to 10 seconds of quota usage is lost (counts are dropped, monthly counter reverts).

**Scope:**
1. Evaluate risk appetite: Is 10-second data loss acceptable for quota tracking? (likely yes for low-tier plans, needs confirmation)
2. If higher durability is required:
   - Change save interval to synchronous: save immediately after every reservation (impacts latency)
   - OR batch saves: write to Durable Object every 100 requests OR 5 seconds (hybrid approach)
   - OR implement eventual consistency mode: accept up-to-10s drift, document in API contract
3. Document the chosen strategy in `workers/docs/QUOTA_DURABLE_OBJECTS.md` with:
   - Data consistency SLA
   - Acceptable loss window
   - When DO eviction is expected (low-traffic orgs evicted after 15 min idle)
4. Add monitoring: Cloudflare Durable Object metrics dashboard to track eviction rate

**Files to modify:**
- `workers/api-gateway/src/durable-objects/quota.ts` — Adjust save strategy (if needed)
- `workers/docs/QUOTA_DURABLE_OBJECTS.md` — Document durability guarantees and trade-offs

**Status:** Deferred — Documented but requires risk/latency trade-off decision and monitoring setup.

---

*Last updated: 2026-03-20 (Phase 1–4 substantially complete; added Phase 4 remaining items V01, V02; quota DO integration items T26–T28 added; existing security/monitoring items follow below)*

*Session update 2026-03-20: T22 marked ✅ COMPLETE with full Durable Objects implementation (quota.ts 253L, lib client 94L, schemas, docs 359L); T26 and T27 updated as next priorities with P1/P2 status and detailed scope; Zod schemas for quota state and status endpoint added.*
