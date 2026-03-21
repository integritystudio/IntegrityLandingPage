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
**Estimated:** 5–6 hours

Implement mandatory fixes for 3 CRITICAL JWT claims strategy issues:

1. **V-01: Remove mutable claims from JWT** — Remove `billing_status` and `plan` from token (currently stale up to 59min, causing authorization bypass). Query these server-side in `/bootstrap` and `/snapshot` endpoints.
2. **V-02: Add `iss` (issuer) validation** — Verify token `iss` claim equals Supabase issuer URL; prevents token forgery from attacker-controlled JWTs.
3. **Normalize IANA algorithm claim** — Ensure RS256 (asymmetric) is used; currently HS256 (symmetric) is a security anti-pattern for multi-service architectures.

**Files to modify:**
- `workers/auth/verify-jwt.ts` — Add `iss` validation
- `workers/bootstrap.ts` — Query subscription status server-side, not from JWT
- `supabase/custom-access-token-hook.ts` — Remove mutable claims from enriched JWT

**References:** RFC 7519 (JWT standard), findings V-01, V-02 in vulnerability report

**Status:** Deferred — Requires JWT hook update, endpoint changes, and testing (~8 workers to update).

---

### H19: Timing-Safe Hash Comparisons (CRITICAL)

**Priority:** P1 | **Source:** session 2026-03-21, SECURITY_VULNERABILITY_REPORT.md (V-03, V-04)
**Estimated:** 3–4 hours

Replace non-constant-time hash comparisons with constant-time functions to prevent timing side-channels:

1. **V-03: API key hash verification** — Current code uses `hash === requestHash` (O(1) early exit on mismatch). Use `crypto.subtle.timingSafeEqual()` in `workers/auth/verify-api-key.ts`.
2. **V-04: Stripe webhook signature verification** — Current code uses string equality for HMAC-SHA256 signature. Use `crypto.subtle.timingSafeEqual()` in `workers/webhooks/stripe.ts`.

**Implementation:**
```typescript
// Before (vulnerable)
if (storedHash === providedHash) { /* ... */ }

// After (safe)
const equal = crypto.getRandomValues(new Uint8Array(1))[0] === 0; // timing-safe constant-time comparison
const encoder = new TextEncoder();
try {
  await crypto.subtle.timingSafeEqual(
    encoder.encode(storedHash),
    encoder.encode(providedHash)
  );
} catch {
  return null; // hashes don't match
}
```

**Files to modify:**
- `workers/auth/verify-api-key.ts`
- `workers/webhooks/stripe.ts`

**Status:** Deferred — Requires cryptographic library integration and testing.

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

**Priority:** P2 | **Source:** session 2026-03-21, implementation work deferred
**Estimated:** 8–10 hours

Implement the Durable Object quota enforcement system for which comprehensive tests were written (`workers/tests/org-quota-do.test.ts`, 897 lines). Tests pass but the actual Worker and DO handler are not yet deployed.

**Scope:**
1. Create `workers/quota/org-quota-do.ts` — Durable Object handler for per-org quota state (check/commit two-phase protocol)
2. Create `workers/quota/quota-client.ts` — HTTP client for Workers to call DO
3. Wire up DO binding in `wrangler.toml` (Durable Object namespace)
4. Integrate into request flow: extract org_id from JWT/API key → call DO → enforce quota
5. Add `/health` DO endpoint for monitoring
6. Test with real Stripe plan sync (version guarding)

**Design reference:** docs/TWO_LAYER_AUTH_ARCHITECTURE.md (section "Integration Flow")

**Status:** Deferred — Tests pass but implementation blocked on infrastructure setup (DO namespace binding).

---

### T23: Webhook Resilience & Dead Letter Queue (Phase 1 of DR)

**Priority:** P2 | **Source:** session 2026-03-21, DISASTER_RECOVERY_PLAN.md (Scenario D)
**Estimated:** 6–8 hours

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

**Status:** Deferred — Requires schema migration, Worker updates, and cron scheduling.

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

**Status:** Deferred — Utility script, low runtime complexity but requires careful execution.

---

### T25: Health Check & Monitoring Endpoints

**Priority:** P3 | **Source:** session 2026-03-21, DISASTER_RECOVERY_PLAN.md (section 3)
**Estimated:** 2–3 hours

Implement the health check and alerting infrastructure:

1. Create `workers/health.ts` — Endpoint that checks:
   - Supabase connectivity (list orgs)
   - Stripe API availability (list customers)
   - Durable Objects liveness (ping rate limiter)
   - Returns JSON with component status and timestamp
2. Configure PagerDuty integration for alerts:
   - Webhook gap > 5 min → P2
   - Dead letters > 10 → P2
   - DB replica lag > 30s → P1
   - Entitlement check failure rate > 5% → P1
   - Backup job missed → P2
3. Add health check to monitoring dashboard

**Status:** Deferred — Observable/monitoring infrastructure, enables proactive alerting.

---

---

## Quota Durable Object Integration & Testing

Items identified in session 2026-03-20: quota.ts idempotency and monthly reset fixes applied, but integration and test gaps remain.

---

### T26: Wire Quota Checks Into API Gateway Request Handler

**Priority:** P1 | **Source:** session 2026-03-20, quota commit review (523518f)
**Estimated:** 3–4 hours

The quota Durable Object (`workers/api-gateway/src/durable-objects/quota.ts`) is implemented with idempotency and monthly auto-reset, but is never called from the API gateway request handler. Routes do not enforce quotas — all requests are allowed regardless of plan.

**Scope:**
1. Import `checkAndReserve()` from `workers/api-gateway/src/lib/quota.ts`
2. Extract `orgId`, `planKey`, `quotaVersion` from JWT/API key in request context
3. Generate idempotent `requestId` (e.g., `sha256(orgId + timestamp + random)`)
4. Call `checkAndReserve()` before executing route handler
5. Return 429 if quota exceeded; include `remainingMinute` and `remainingMonthly` in response headers
6. Validate against all metriced endpoints (`/v1/ingest`, `/v1/dashboard`, etc.)

**Files to modify:**
- `workers/api-gateway/src/index.ts` — Add quota check middleware
- `workers/api-gateway/src/routes/*.ts` — Wire middleware into all protected routes

**Status:** Deferred — quota checking logic is ready; integration layer not yet implemented.

---

### T27: Write Integration Tests for Quota Durable Object

**Priority:** P2 | **Source:** session 2026-03-20, quota commit review (523518f)
**Estimated:** 4–6 hours

Current test file (`workers/api-gateway/src/durable-objects/quota.test.ts`) contains only placeholder stubs (35 lines, all `expect(true).toBe(true)`). No actual validation of quota logic:
- Minute window reset behavior
- Monthly counter reset on calendar month boundary
- Idempotent request tracking and TTL cleanup
- Version bump quota resets
- Minute + monthly limit enforcement

**Scope:**
1. Set up Wrangler miniflare environment for local DO testing
2. Write integration tests:
   - Request under minute limit → allowed
   - Request exceeding minute limit → 429 + reason: "minute_limit"
   - Request exceeding monthly limit → 429 + reason: "monthly_limit"
   - Identical requestId retried within 5min window → allowed without double-counting
   - requestId older than 5min cleaned up
   - Calendar month boundary → monthlyUsed reset to 0
   - quotaVersion bump → all counters reset
   - Concurrent requests to same org (DO serialization) → quota checks ordered
3. Add edge cases:
   - Enterprise plan (no monthly limit) should only check minute limit
   - Exact boundary: `minuteUsed == minuteLimit` → next request rejected

**Files to create/modify:**
- `workers/api-gateway/src/durable-objects/quota.test.ts` — Full test suite
- `workers/api-gateway/wrangler.toml` — Ensure Durable Object is configured for tests

**Status:** Deferred — Test scaffolding in place; actual test implementations missing.

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
