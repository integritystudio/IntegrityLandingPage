# Backlog

Open and deferred items only. Completed items are migrated to `docs/changelog/1.0/CHANGELOG.md` and `docs/changelog/1.1/CHANGELOG.md`.

**Last Updated:** 2026-03-20 | **Phase:** Sender-Worker UI + Quota Integration Complete

---

## Phase 4 Remaining Items (Substantially Complete)

**Status:** Phase 1–4 substantially complete as of 2026-03-20.

**Completed in this session (2026-03-20):**
- ✅ Sender-Worker UI Implementation — AuthPage, ProvisionPage, SenderHealthPage with JWT flow (commit 9ea6256)
- ✅ Quota Durable Object Integration (T26) — Wire quota checks into API gateway routes with fail-open logic (commits bb1d810, d58f382, 3483538)
- ✅ Quota Integration Tests (T27) — 25 comprehensive tests covering limits, idempotency, plan tiers (commit 6bc3cd8)
- ✅ Security Fixes — JWT issuer validation (V-02, commit 00bfaaf), timing-safe hash comparisons H19 (commit 0f9cece)
- ✅ Code Review — 10+ findings addressed; 6 backlog items marked Done (R02, R04, R07, R08, R09, R10)

**Remaining for v1 release:**

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

**Status:** Done — Implemented in commit 761ab48 (2026-03-20). Endpoint wired, 16 tests passing.

---

### V03: Monthly Aggregation Rollup

**Priority:** P1 | **Estimated:** 2–3 hours

Implement monthly rollup that aggregates `usage_buckets_daily` rows into `MonthlyUsageSummary` responses for billing period reporting:

1. `rollupMonthlyBucket(orgId, yearMonth, sb)` — queries `usage_buckets_daily` for a given YYYY-MM period and aggregates totals/averages per metric_key
2. Return `MonthlyUsageSummary` validated via `MonthlyUsageSummarySchema` (already defined in `workers/lib/types/usage.ts`)
3. `metric_breakdown` map: per-metric quantity, request count, avg_latency_ms
4. TDD: write tests first, implement to pass

**Files to implement:**
- `workers/api-gateway/src/aggregation.ts` — add `rollupMonthlyBucket`
- `workers/api-gateway/src/aggregation.test.ts` — monthly tests (TDD)

**Status:** Done — Implemented in commits 59402f3, c021f5b (2026-03-20). 17 tests passing (TDD). Zod-validated return via MonthlyUsageSummarySchema.

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

**Status:** Done — Extension list note and runtime guidance added (commit c326a28)

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

**Status:** Done — Static final performance rationale documented (commit c326a28)

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

**Status:** Done — Boundary tests added in test/pages/auth_page_test.dart (commit 3cce1c5)

---

### R08: Update TDD Report with Current `_stackTracePattern` Regex

**Priority:** P4 | **Severity:** Low | **Source:** code-reviewer (commit e623040)

`docs/TDD_SESSION_REPORT.md:55–58` — The code snippet shows the original regex `\.(dart|js|ts):\d` from commit `4554f81`, but commit `00d7127` extended it to include `cjs|mjs|wasm`. The report was not updated to reflect the amended pattern. Update the snippet to match current source.

**File:** `docs/TDD_SESSION_REPORT.md:55–58`

**Status:** Done — Regex snippet updated to include cjs|mjs|wasm (commit 26e12a7)

---

### R09: Back-Fill Commit Hashes in Changelog v1.1

**Priority:** P4 | **Severity:** Low | **Source:** code-reviewer (commit e89fd7d)

`docs/changelog/1.1/CHANGELOG.md:398` (M14, M15, M16, L19, L20) — Entries read `Commit: session 2026-03-20` instead of real git hashes. This breaks traceability. Back-fill with actual commit hashes from `git log`.

**File:** `docs/changelog/1.1/CHANGELOG.md`

**Status:** Done — Real commit hashes already present (bc59b8b, 7ffbeb0, 9581ce8, 39e54fa, a5767c4)

---

### R10: Remove Duplicate M07 Entry from Open Items

**Priority:** P4 | **Severity:** Low | **Source:** code-reviewer (commit e89fd7d)

`docs/BACKLOG.md:162–171` — M07 is listed in the changelog as done but still appears under `## Open Items` with a `Status: Done` footnote. The migration was supposed to remove Done items. Remove the M07 entry from this file.

**File:** `docs/BACKLOG.md:162–171`

**Status:** Done — M07 entry not present in current BACKLOG.md (already removed in prior migration)

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

Items identified in session 2026-03-20: quota.ts idempotency and monthly reset fixes applied; T26 and T27 now complete (commit 6bc3cd8).

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

**Status:** ✅ Done — 25 integration tests covering minute/monthly limits, idempotency, enterprise plan, quotaVersion bumps, storage persistence, and legacy backfill (commit 6bc3cd8)

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

---

## Code Review Findings: Security Remediation Session (2026-03-21)

Session completed critical fixes for T23, T24, T25 security remediations. Code-reviewer identified additional medium/low priority issues:

---

### H19-M1: Extract `hexToBytes` Utility to Shared Library

**Priority:** P3 | **Severity:** Medium | **Source:** code-reviewer, session 2026-03-21 (commit 6287919)

`hexToBytes()` is implemented independently in two places:
- `workers/lib/api-keys.ts:44–51` (for API key hash verification)
- `workers/stripe-webhook/src/verify.ts:65–68` (for Stripe signature verification)

Both perform identical hex-to-bytes conversion. This is a maintenance risk: a bug fix to one won't propagate. Extract to `workers/lib/hex-utils.ts` as a shared export and update both call sites.

**Files affected:**
- `workers/lib/api-keys.ts`
- `workers/stripe-webhook/src/verify.ts`
- `workers/lib/hex-utils.ts` (new)

**Status:** Done — `workers/lib/hex-utils.ts` created; both call sites updated; 7 tests added (commits 2d4df62, 5d00632)

---

### H19-M2: Strict Validation for `hexToBytes` in `api-keys.ts`

**Priority:** P3 | **Severity:** Medium | **Source:** code-reviewer, session 2026-03-21

`workers/lib/api-keys.ts:45` uses regex `/^[0-9a-f]*$/` (zero or more, `*`) which accepts empty strings. Empty `Uint8Array` would pass `crypto.subtle.verify` against itself, potentially bypassing validation if a corrupted row has a blank hash. Change `*` to `+` (one or more) to require at least one byte. `workers/stripe-webhook/src/verify.ts` correctly uses `+` — this is an inconsistency.

**File:** `workers/lib/api-keys.ts:45`

**Fix:** Change `!/^[0-9a-f]*$/.test(hex)` to `!/^[0-9a-f]+$/.test(hex)` and add length check `hex.length === 0`.

**Status:** Done — Fixed as part of H19-M1; shared `hexToBytes` in `hex-utils.ts` uses `+` throughout (commits 2d4df62, 5d00632)

---

### M18-M1: JWT Issuer Claim Validated Before Signature

**Priority:** P3 | **Severity:** Medium | **Source:** code-reviewer, session 2026-03-21

`workers/lib/auth.ts:59–69` validates JWT issuer claim before verifying the signature. Standard JWT validation order is: parse → **verify signature** → check claims. Validating unverified claims is a defense-in-depth issue (both branches return 401, but order leaks information about invalid vs mismatched issuers).

**File:** `workers/lib/auth.ts:40–69`

**Fix:** Reorder to verify signature first, then check expiry, then check issuer.

**Status:** Done — signature verified before exp/iss checks (commits fc69dea, 42faa70)

---

### M18-M2: No Startup Warning When JWT Issuer Validation Disabled

**Priority:** P3 | **Severity:** Medium | **Source:** code-reviewer, session 2026-03-21

`SUPABASE_JWT_ISSUER` is optional in both Zod schema and Env interface (`workers/api-gateway/src/index.ts:17`, `workers/lib/types/handler-options.ts:29`). If never set in production, V-02 mitigation (`iss` validation) is silently inactive. Add a startup warning (non-blocking) when the env var is absent to make this visible in deployment logs.

**Files affected:**
- `workers/api-gateway/src/index.ts` — Add warning in fetch handler
- Or create startup check function in `workers/lib/startup-checks.ts`

**Status:** Done — module-level `jwtIssuerWarned` flag emits once-per-isolate `console.warn` (commits 0932e90, ee29f30)

---

### T23-M1: No Idempotency Guard on Dead Letter Reconciliation Retry

**Priority:** P3 | **Severity:** Medium | **Source:** code-reviewer, session 2026-03-21

`workers/stripe-webhook/src/index.ts:125–127` — The webhook handler calls `isEventProcessed()` before attempting the first process, but the reconciliation cron loop (line 125) does not. If two cron ticks overlap, the same dead letter could be dispatched concurrently, both succeed, and `logProcessedEvent()` attempts a duplicate insert. The UNIQUE constraint on `stripe_event_id` silently fails and the duplicate is ignored.

**File:** `workers/stripe-webhook/src/index.ts:115–135`

**Fix:** Call `isEventProcessed()` at the top of the reconciliation retry block, matching the webhook handler pattern (line 43–44).

**Status:** Open

---

### T23-M2: Dead Letter Queue Schema Missing RLS Policies

**Priority:** P4 | **Severity:** Low | **Source:** code-reviewer, session 2026-03-21

`supabase/migrations/20260321000000_add_webhook_dead_letters.sql` — Tables `webhook_dead_letters` and `webhook_events_log` have no `ENABLE ROW LEVEL SECURITY` or `CREATE POLICY` statements. They are accessed only via service-role key (acceptable), but inconsistent with the rest of the schema. Either explicitly enable RLS with a service-role bypass policy, or add a comment explaining why RLS is omitted.

**Files affected:**
- `supabase/migrations/20260321000000_add_webhook_dead_letters.sql`

**Status:** Done — Added comment explaining service-role-only access pattern and why RLS is intentionally omitted (commit 313cd7f)

---

### T23-M3: Unused `'processing'` Status in Dead Letter Queue Schema

**Priority:** P4 | **Severity:** Low | **Source:** code-reviewer, session 2026-03-21

`supabase/migrations/20260321000000_add_webhook_dead_letters.sql` defines CHECK constraint with status enum including `'processing'`. No code ever writes this status. This suggests distributed locking (optimistic claim) was planned and never implemented. Either use `'processing'` or remove it from the CHECK to avoid confusion.

**File:** `supabase/migrations/20260321000000_add_webhook_dead_letters.sql:20`

**Status:** Done (commit 7da6701, 2026-03-21)

---

### T24-M1: Stripe Customer Subscriptions Accessed via Unsafe Cast

**Priority:** P3 | **Severity:** Medium | **Source:** code-reviewer, session 2026-03-21

`scripts/full-reconciliation.ts:260` — Unsafe cast to add optional `subscriptions` field to Stripe Customer type:
```typescript
const subs = (customer as Stripe.Customer & { subscriptions?: ... }).subscriptions?.data ?? [];
```

This is the standard workaround for expanded Stripe types, but if the Stripe SDK is updated, the shape could change and fail silently. Add a runtime guard: `Array.isArray(subs) || throw new Error(...)` to fail fast on schema mismatch.

**File:** `scripts/full-reconciliation.ts:260–261`

**Status:** Done — `Array.isArray` guard added; throws with `customer.id` and `typeof subsData` on shape mismatch (commits 9bbb550, 4f03052)

---

### T24-M2: Entitlements Delete-Then-Insert Not Atomic

**Priority:** P4 | **Severity:** Low | **Source:** code-reviewer, session 2026-03-21

`scripts/full-reconciliation.ts:172–192` — `provisionEntitlements()` deletes all existing entitlements, then re-inserts one by one. If the script crashes between delete and insert, the org is left with zero entitlements. For a reconciliation script this is acceptable risk, but should be documented: **Run this during a maintenance window only.**

**File:** `scripts/full-reconciliation.ts:164–193`

**Note:** Document in script header that this is a "nuclear option" and should not run concurrently with production traffic.

**Status:** Open

---

### T25-M2: `'degraded'` Status Unreachable in Durable Object Health Check

**Priority:** P4 | **Severity:** Low | **Source:** code-reviewer, session 2026-03-21

`workers/api-gateway/src/routes/health.ts:59` — The condition `resp.status < 500 ? 'healthy' : 'degraded'` implies a distinction between healthy and degraded for DOs, but in practice a DO returning 5xx is a hard failure, not degraded. The `'degraded'` type is only meaningfully used in the database check. Consider whether this distinction is useful or should collapse to `'healthy'` | `'unhealthy'`.

**File:** `workers/api-gateway/src/routes/health.ts:54–63`

**Status:** Done — `checkDurableObject` return type narrowed to `'healthy' | 'unhealthy'`; `HealthCheckResult.durableObjects` field typed accordingly (commit 3dd5824)

---

### T24-M3: `entitlementsRebuilt` Counter Increments at Wrong Granularity

**Priority:** P4 | **Severity:** Low | **Source:** code-reviewer, session 2026-03-21

`scripts/full-reconciliation.ts:303` — Counter increments inside the subscription loop (once per subscription), but the name and placement suggest it counts per-entitlement-row. The summary output is ambiguous: "Entitlements rebuilt: 5" could mean 5 rows or 5 subscriptions. Rename to `subscriptionsProcessed` or clarify the counter semantics in the summary output.

**File:** `scripts/full-reconciliation.ts:303` and `324–330`

**Status:** Done — Renamed to `orgEntitlementsRebuilt`; log label updated to `"Orgs with entitlements rebuilt:"` (commit 1b9c88d)

---

### H21: Org Quota Enforcement Before JWT Authentication

**Priority:** P1 | **Severity:** High | **Source:** code-reviewer, session 2026-03-20 final review

`workers/api-gateway/src/index.ts:58–70` — `enforceOrgQuota()` is called before JWT authentication on all `/v1/orgs/:orgId/*` sub-routes. An unauthenticated caller who knows (or guesses) a valid `orgId` will trigger a Durable Object read and consume quota I/O before being rejected. This also leaks information: a 429 response reveals the org exists and is active, while a 401/404 signals auth failure. Fix: resolve and verify JWT first, return early on failure, then enforce quota.

**File:** `workers/api-gateway/src/index.ts:58–70`

**Status:** Open

---

### M19: Typo in `entitlements` Variable Name

**Priority:** P2 | **Severity:** Medium | **Source:** code-reviewer, session 2026-03-20 final review

`scripts/full-reconciliation.ts:221` — Variable is named `entitlementsToRebuild` but should be `entitlementsToRebuild` (missing 'e'). The name is used consistently throughout the scope so there is no runtime bug, but it will surface in future searches and diffs. Rename to correct spelling.

**File:** `scripts/full-reconciliation.ts:221`

**Status:** Done — Renamed across 5 occurrences (commit 7fa808f, 2026-03-20)

---

### M20: Missing Org ID Validation in Reconciliation Script

**Priority:** P2 | **Severity:** Medium | **Source:** code-reviewer, session 2026-03-20 final review

`scripts/full-reconciliation.ts:325–351` — The variable `orgs[0].id` is used directly in `provisionEntitlements()` without validating that `id` is a non-empty string. A Supabase row with a null or empty `id` would produce a malformed filter URL. Add a guard: `if (!orgs[0]?.id) throw new Error(...)`.

**File:** `scripts/full-reconciliation.ts:325–351`

**Status:** Done — Explicit `!orgId` guard added after Zod parse; returns error if id is somehow empty (commit 005fc5c)

---

### L1: Redundant `token.split()` Calls in JWT Verification

**Priority:** P3 | **Severity:** Low | **Source:** code-reviewer, session 2026-03-20 final review

`workers/lib/auth.ts:52 vs 59` — `parseJwtPayload()` splits the token internally but does not return the parts array. `verifyJwt` then calls `token.split('.')` again on line 59 to verify the signature. Minor redundancy — consider caching the parts result from parse or restructuring to avoid the second split.

**File:** `workers/lib/auth.ts:52–59`

**Status:** Done — `parseJwtPayload` returns `parts` in ok result; `verifyJwt` destructures from parse result, eliminating second split (commit f3cbb38)

---

### L2: Compound Issuer Check Could Be Simplified

**Priority:** P3 | **Severity:** Low | **Source:** code-reviewer, session 2026-03-20 final review

`workers/lib/auth.ts:95` — The issuer check `typeof payload.iss !== 'string' || payload.iss !== opts.issuerUrl` can be collapsed to `payload.iss !== opts.issuerUrl` since `opts.issuerUrl` is guaranteed to be a `string` by the `!== undefined` guard on the outer `if`. Simplify for readability.

**File:** `workers/lib/auth.ts:95`

**Status:** Done — Removed redundant `typeof` guard; `payload.iss !== opts.issuerUrl` is semantically equivalent (commit 7fa808f, 2026-03-20)

---

### M21: Log Warning When Daily/Monthly Query Results Hit Limit

**Priority:** P2 | **Severity:** Medium | **Source:** code-reviewer, session 2026-03-20 (V03 final review, commits 59402f3, c021f5b, 97d3b74)

`workers/api-gateway/src/aggregation.ts:50–52 (rollupDailyBucket), 155–158 (rollupMonthlyBucket)` — Both rollup functions have query limits (`MAX_EVENTS_PER_ROLLUP = 10_000` for daily, `MAX_DAILY_BUCKETS_PER_MONTH = 3100` for monthly) to prevent OOM, but neither logs a warning when the limit is hit. If the limit is reached, data silently truncates and the aggregation is incomplete. Add `if (events.length === MAX_EVENTS_PER_ROLLUP) console.warn(...)` in rollupDailyBucket and `if (buckets.length === MAX_DAILY_BUCKETS_PER_MONTH) console.warn(...)` in rollupMonthlyBucket.

**Files:** `workers/api-gateway/src/aggregation.ts:50–52, 155–158`

**Status:** Done — `console.warn` added in both rollup functions when result count hits the configured limit (commit 8e8c033)

---

### M22: Add Int Type Enforcement to DailyBucketRow Interface

**Priority:** P2 | **Severity:** Medium | **Source:** code-reviewer, session 2026-03-20 (V03 final review)

`workers/api-gateway/src/aggregation.ts:110–116 (DailyBucketRow)` — DailyBucketRow is typed as `extends Record<string, unknown>` with numeric fields typed as plain `number`. The monthly aggregation relies on `total_quantity` and `request_count` being integers but does not enforce at the boundary. If a DB row returns floats (e.g., from a faulty migration), the aggregation would compute float sums that fail Zod's `int()` check on parse. Low-risk hardening: use `Math.trunc()` before aggregation, or parse DB rows against `UsageBucketSchema.pick(...)` to enforce type safety at query time.

**File:** `workers/api-gateway/src/aggregation.ts:110–116`

**Status:** Open

---

### L3: Add Zod Schema Rejection Path Test for MonthlyUsageSummary

**Priority:** P3 | **Severity:** Low | **Source:** code-reviewer, session 2026-03-20 (V03 final review)

`workers/api-gateway/src/aggregation.test.ts` — The test at line 290 (`returns a Zod-validated MonthlyUsageSummary shape`) confirms that a valid shape passes the schema, but there is no negative test confirming that `MonthlyUsageSummarySchema.parse` rejects invalid shapes (e.g., negative `total_quantity`). Add a test that mocks a malformed bucket row and confirms the Zod parse throws. Improves schema coverage beyond happy-path.

**File:** `workers/api-gateway/src/aggregation.test.ts`

**Status:** Done — Negative test added; `MonthlyUsageSummarySchema.parse` confirmed to throw on negative `total_quantity` and invalid `organization_id`/`year_month`.

---

### L4: Refactor Test Factories to Reduce Duplication in aggregation.test.ts

**Priority:** P3 | **Severity:** Low | **Source:** code-reviewer, session 2026-03-20 (V03 final review)

`workers/api-gateway/src/aggregation.test.ts:18–24 (makeSb), 167–173 (makeMonthSb)` — `makeSb` and `makeMonthSb` have duplicate structure (both create mock Supabase clients). The only difference is `makeMonthSb` does not mock `upsert`. Consider extracting a single factory that accepts optional mock overrides, reducing duplication and improving maintainability. Low priority; does not affect correctness.

**File:** `workers/api-gateway/src/aggregation.test.ts:18–24, 167–173`

**Status:** Open

---

*Last updated: 2026-03-20 — Phase 4 substantially complete. Quota Durable Object (T22-T27) fully integrated with API gateway routes; sender-worker UI pages (auth, provision, health) implemented; Usage Ledger Ingestion (V01) and Monthly Aggregation (V03) completed. Final review of V03 identified 4 medium/low findings (M21–L4) for future hardening and observability improvement.*
