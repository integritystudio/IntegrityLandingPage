# Backlog

Open and deferred items only. Completed items are migrated to `docs/changelog/1.0/CHANGELOG.md` and `docs/changelog/1.1/CHANGELOG.md`.

**Last Updated:** 2026-03-21 | **Phase:** Sender-Worker UI + Quota Integration Complete

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

**Status:** In progress — Bootstrap flow complete: `BootstrapResponse` models, `ProvisioningService.bootstrap()`, org context shown on ProvisionPage after provisioning (7 tests). Remaining: org switcher, billing display, usage charts, entitlements grid.

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

## Open Items

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

### T25: Health Check & Monitoring Endpoints

**Priority:** P3 | **Source:** session 2026-03-21 | **Commit:** a9a034f

**Partially complete** — Health endpoint upgraded in commit a9a034f:
- `/health` on api-gateway now checks Supabase connectivity + DO liveness
- Returns `{ database, durableObjects, timestamp }`, 200 if all healthy, 503 otherwise
- Still open: PagerDuty integration and monitoring dashboard configuration

**Status:** Partial — Core health endpoint done. Alerting integration (PagerDuty) deferred.

### L5: Sanitize `auth.email` in ProvisionPage

**Priority:** P3 | **Severity:** Low | **Source:** code-reviewer, bootstrap session 2026-03-21

`lib/pages/provision_page.dart:217` — `widget.auth.email` is rendered directly in a `Text()` widget without passing through `SecurityUtils.sanitizeUserInput()`. While Flutter's `Text` does not evaluate HTML, this is an inconsistency with the sanitization standard applied to other server-sourced fields (`org.name`, `org.planKey`) added in the same session. For defense-in-depth and consistency, wrap the email display with `SecurityUtils.sanitizeUserInput(widget.auth.email)`.

**Status:** Deferred — Low severity, non-blocking.

---

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

## Code Review Findings: Stripe Webhook Worker Infrastructure (Session 2026-03-21)

Final full-stack review of M23/M24 commits revealed pre-existing infrastructure issues in the stripe-webhook handlers.

---

### H1: Type Safety Lost — Stripe Event Payloads Cast as `any`

**Priority:** P1 | **Severity:** High | **Source:** code-reviewer full-stack review, session 2026-03-21

All event handlers immediately cast `event.data.object as any`: `checkout.ts:14`, `subscription.ts:28, 83`, `invoice.ts:49, 70`. A malformed Stripe payload (truncated body, schema change, corrupt dead-letter payload) causes silent runtime crash at property access rather than handled error return. Dead-letter retry path is especially vulnerable since payloads are stored as `unknown` and re-processed.

**Fix:** Define Zod schemas for each event object type (`CheckoutSession`, `Subscription`, `Invoice`) and parse with `safeParse`. Project has Zod infrastructure in `workers/lib/validation/`.

**Status:** Open

---

### H2: Missing Subscription Upsert in Checkout Handler

**Priority:** P1 | **Severity:** High | **Source:** code-reviewer full-stack review, session 2026-03-21

`handleCheckoutSessionCompleted` (workers/stripe-webhook/src/handlers/checkout.ts:27-32) calls `db.linkStripeCustomer` but never calls `db.upsertSubscription`. Subscription is only created later by `customer.subscription.updated`, not guaranteed to arrive before `invoice.paid`. Breaks any query joining on `subscriptions` table.

**Fix:** Call `db.upsertSubscription()` after linking customer, mirroring the pattern in other handlers.

**Status:** Open

---

### M25: `HandlerResult` Type Duplicated Across Four Files

**Priority:** P2 | **Severity:** Medium | **Source:** code-reviewer full-stack review, session 2026-03-21

`type HandlerResult = { ok: true } | { ok: false; error: string }` defined in `index.ts:15`, `checkout.ts:4`, `subscription.ts:12`, `invoice.ts:4`. Should live in `workers/lib/types.ts` and be imported. Drift between definitions is possible.

**Status:** Open

---

### M26: Non-Atomic Check-Then-Write in `upsertSubscription`

**Priority:** P2 | **Severity:** Medium | **Source:** code-reviewer full-stack review, session 2026-03-21

`workers/stripe-webhook/src/supabase.ts:36-65` — Read at line 36 and write at line 49/57 are not atomic. Two overlapping `customer.subscription.updated` events (common with Stripe retries) can both see `queryResult.data === null` and both attempt `insert`, causing duplicate key violation. Table should use true upsert (`ON CONFLICT DO UPDATE`) rather than manual check-then-insert.

**Status:** Open

---

### M27: Dead Letter Filter Applied in App Code, Not Query

**Priority:** P2 | **Severity:** Medium | **Source:** code-reviewer full-stack review, session 2026-03-21

`fetchPendingDeadLetters` (workers/stripe-webhook/src/supabase.ts:200) does not include `retry_count < max_retries` in DB query filter set. Rows that hit `max_retries` but still have `status=pending` (bug state from failed status update) are fetched then silently dropped client-side. Wastes round-trip and hides the discard. Push filter into query.

**Status:** Open

---

### M28: Wrong HTTP Status Code for Unmatched Webhook Route

**Priority:** P2 | **Severity:** Medium | **Source:** code-reviewer full-stack review, session 2026-03-21

`index.ts:170` returns `serverError` (HTTP 500) for unmatched routes instead of 404. Causes Stripe dashboard to report webhook delivery failures as 5xx instead of misconfiguration.

**Fix:** Return HTTP 404 with appropriate response for unmatched route.

**Status:** Open

---

### M29: Quota Bump Uses Null Assignment Instead of Monotonic Increment

**Priority:** P2 | **Severity:** Medium | **Source:** code-reviewer full-stack review, session 2026-03-21

`updateOrgBillingStatus` (workers/stripe-webhook/src/supabase.ts:84) sets `quota_version = null` as the bump mechanism. Null is not monotonic — it resets rather than increments. Two consecutive bumps within same tick both set `null` and second is indistinguishable from first. If polling clients use `quota_version` to detect changes, this breaks change detection.

**Fix:** Use `now()` timestamp or integer increment via RPC, not null.

**Status:** Open

---

### L5: Empty `PRICE_TO_PLAN` Map Shipped to Production

**Priority:** P3 | **Severity:** Low | **Source:** code-reviewer full-stack review, session 2026-03-21

`workers/stripe-webhook/src/handlers/subscription.ts:8-10` defines empty `PRICE_TO_PLAN` map. Comment says "Example: ..." suggesting placeholder. `planKey` always `undefined` for all subscriptions; every update silently skips plan mapping with no log or error. Price IDs are environment-specific and should come from `env` bindings, not hardcoded map.

**Status:** Open

---

### L6: Magic Number for Initial Retry Delay

**Priority:** P3 | **Severity:** Low | **Source:** code-reviewer full-stack review, session 2026-03-21

`addDeadLetter` (workers/stripe-webhook/src/supabase.ts:155) uses hardcoded `60_000` (ms) for initial retry delay. `failDeadLetter` at line 224 uses same logic with `Math.pow(2, retryCount) * 60_000`. Extract to named constant alongside existing `REPLAY_WINDOW_MS` pattern in `workers/constants.ts`.

**Status:** Open

---

### L7: Minimal Test Coverage for `handleWebhook` Fetch Handler

**Priority:** P3 | **Severity:** Low | **Source:** code-reviewer full-stack review, session 2026-03-21

`index.test.ts` has only one test for `handleWebhook` (the M23 logProcessedEvent failure case). Missing coverage: invalid signature rejection, already-processed skip (`skipped: true` response), handler failure → dead letter, health endpoint. Reconciliation suite is comprehensive; webhook handler suite is not.

**Status:** Open

---

### L8: Missing Unit Tests for Five Public `SupabaseAdmin` Functions

**Priority:** P3 | **Severity:** Low | **Source:** code-reviewer full-stack review, session 2026-03-21

`supabase.test.ts` covers only `fetchPendingDeadLetters` and `isEventProcessed`. Missing direct test coverage: `upsertSubscription`, `linkStripeCustomer`, `updateOrgBillingStatus`, `failDeadLetter`, `addDeadLetter`. Given M26 (non-atomic upsert), `upsertSubscription` is highest-priority gap.

**Status:** Open

---

### L9: `DeadLetter` Interface Scoped Inside Function Closure

**Priority:** P3 | **Severity:** Low | **Source:** code-reviewer full-stack review, session 2026-03-21

`workers/stripe-webhook/src/supabase.ts:170-178` — `DeadLetter` interface defined inside `createSupabaseAdmin` closure. Not exported; cannot be referenced externally (e.g., in `index.ts` where `dl` is typed implicitly). Should be exported from module or moved to `workers/lib/types.ts`.

**Status:** Open

---

*Last updated: 2026-03-21 — M23, M24 Done. Full-stack review appended H1, H2, M25-M29, L5-L9 (session 2026-03-21).*
