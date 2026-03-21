# Backlog

Open and deferred items only. Completed items are migrated to `docs/changelog/1.0/CHANGELOG.md` and `docs/changelog/1.1/CHANGELOG.md`.

**Last Updated:** 2026-03-21 | **Phase:** V02 Flutter Dashboard Feature-Complete (5/8 steps: org switcher, billing status, usage summary, charts, entitlements, polling); H1 Zod Schemas + M25–M33 Code Review Fixes; Medium Priority Items Complete; M34/M35 New Findings; Session Wrap-Up

---

## Phase 4 Remaining Items (Substantially Complete)

**Status:** Phase 1–4 substantially complete as of 2026-03-20.

**Completed in this session (2026-03-20 to 2026-03-21):**
- ✅ Sender-Worker UI Implementation — AuthPage, ProvisionPage, SenderHealthPage with JWT flow (commit 9ea6256)
- ✅ Quota Durable Object Integration (T26) — Wire quota checks into API gateway routes with fail-open logic (commits bb1d810, d58f382, 3483538)
- ✅ Quota Integration Tests (T27) — 25 comprehensive tests covering limits, idempotency, plan tiers (commit 6bc3cd8)
- ✅ Security Fixes — JWT issuer validation (V-02, commit 00bfaaf), timing-safe hash comparisons H19 (commit 0f9cece)
- ✅ Code Review — 10+ findings addressed; 6 backlog items marked Done (R02, R04, R07, R08, R09, R10)
- ✅ V02 Dashboard Core Pages — Usage summary page (55c4a86, e066900) + billing status display page (979ab7c, 60fd1ff) with DashboardService
- ✅ V02 Code Review Findings Documented — Backlog items H2, M30-M32, L10-L11, V02-Remaining 5 components (commit 80b288a)
- ✅ Roadmap Updated — V02 status reflects complete core pages + code review findings + remaining work (commits 81d3c24, 7f2e699)
- ✅ H1: Zod Schemas for Stripe Event Payloads — CheckoutSessionSchema, SubscriptionSchema, InvoiceSchema; all `as any` casts replaced with `safeParse` (commit 29a71d1)
- ✅ V02: Quota Visualization — QuotaStatusPage at `/quota` with minute burst + monthly limits, GET /quota/status endpoint (commits 9f93f67, e3ff7f3)
- ✅ V02: Usage Charts — Daily bar chart with quota reference line and threshold coloring, fixed shouldRepaint (commits c78bbf1, 809496a)
- ✅ V02: Entitlements Display — EntitlementsPage at `/entitlements` with auto-generated feature flags (commit 9f93f67)
- ✅ Code Review Cycle — H1 Zod schema findings documented + code review addressing H1/H2/M4 findings (commits fc91224, e3ff7f3)
- ✅ Backlog Updated — V02 quota visualization and entitlements display marked done (commit 52a2d4c)
- ✅ V02: Org Switcher Dashboard Hub — DashboardPage at `/dashboard`, DropdownButton org switcher, nav cards to billing/usage/quota/entitlements, fetchOrgList GET /v1/orgs with retry (commits 91cdae3, 226b568)
- ✅ V02: Real-time Usage Polling — 30s Timer.periodic + WidgetsBindingObserver resume refresh on UsageSummaryPage; in-flight guard prevents overlapping fetches (commits f6581fd, d14280c)

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

**Status:** ✅ CORE PAGES + CHARTS + ORG SWITCHER + POLLING COMPLETE — Bootstrap flow complete; ✅ org switcher (step 1): `DashboardPage` at `/dashboard`, DropdownButton org switcher + nav cards to all sub-pages (commits 91cdae3, 226b568); ✅ billing status display (step 2): `BillingStatusPage` at `/billing`, plan name + status badge + renewal date, loading/error states, retry (commits 979ab7c, 60fd1ff); ✅ usage summary display (step 3): `UsageSummaryPage` at `/usage`, progress bar + per-metric breakdown (commits 55c4a86, e066900); ✅ usage charts (step 3): `_DailyBarChart` with `CustomPainter`, daily bar chart with quota reference line and threshold coloring (commits c78bbf1, 809496a); ✅ quota visualization (step 3 extended): `QuotaStatusPage` at `/quota`, minute burst + monthly limits with Unlimited label support, plan badge, fail-open DO handling (commits 9f93f67, e3ff7f3); ✅ entitlements display (step 4): `EntitlementsPage` at `/entitlements` with auto-generated feature flags (commit 9f93f67); ✅ real-time polling (step 6): 30s Timer.periodic + app-resume refresh on UsageSummaryPage, in-flight guard (commits f6581fd, d14280c). Code review findings: 1 H2-V02 latent JWT risk, 3 M-level (M30-M32: telemetry/validation/duplication), 2 L-level (L10-L11: decoration/docs) documented (80b288a). Remaining: Stripe portal link (step 5) — deferred, requires Stripe SDK in api-gateway.

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

**Status:** ✅ Done — commit 29a71d1. `CheckoutSessionSchema`, `SubscriptionSchema`, `InvoiceSchema` added to `stripe-schemas.ts`; all `as any` casts replaced with `safeParse` + typed error returns.

---

### H2: Missing Subscription Upsert in Checkout Handler

**Priority:** P1 | **Severity:** High | **Source:** code-reviewer full-stack review, session 2026-03-21

`handleCheckoutSessionCompleted` (workers/stripe-webhook/src/handlers/checkout.ts:27-32) calls `db.linkStripeCustomer` but never calls `db.upsertSubscription`. Subscription is only created later by `customer.subscription.updated`, not guaranteed to arrive before `invoice.paid`. Breaks any query joining on `subscriptions` table.

**Fix:** Call `db.upsertSubscription()` after linking customer, mirroring the pattern in other handlers.

**Status:** ✅ Done — commit 64b1387. Stub row with null price_id and status 'active' created after linkStripeCustomer; price populated by subsequent customer.subscription.updated.

---

### M25: `HandlerResult` Type Duplicated Across Four Files

**Priority:** P2 | **Severity:** Medium | **Source:** code-reviewer full-stack review, session 2026-03-21

`type HandlerResult = { ok: true } | { ok: false; error: string }` defined in `index.ts:15`, `checkout.ts:4`, `subscription.ts:12`, `invoice.ts:4`. Should live in `workers/lib/types.ts` and be imported. Drift between definitions is possible.

**Status:** ✅ Done — commit 3e63278. HandlerResult exported from workers/lib/types/index.ts; local definitions removed from all 4 files.

---

### M26: Non-Atomic Check-Then-Write in `upsertSubscription`

**Priority:** P2 | **Severity:** Medium | **Source:** code-reviewer full-stack review, session 2026-03-21

`workers/stripe-webhook/src/supabase.ts:36-65` — Read at line 36 and write at line 49/57 are not atomic. Two overlapping `customer.subscription.updated` events (common with Stripe retries) can both see `queryResult.data === null` and both attempt `insert`, causing duplicate key violation. Table should use true upsert (`ON CONFLICT DO UPDATE`) rather than manual check-then-insert.

**Status:** ✅ Done — commit 867957c. sb.upsert with on_conflict=organization_id,stripe_subscription_id replaces read-then-insert-or-update pattern.

---

### M27: Dead Letter Filter Applied in App Code, Not Query

**Priority:** P2 | **Severity:** Medium | **Source:** code-reviewer full-stack review, session 2026-03-21

`fetchPendingDeadLetters` (workers/stripe-webhook/src/supabase.ts:200) does not include `retry_count < max_retries` in DB query filter set. Rows that hit `max_retries` but still have `status=pending` (bug state from failed status update) are fetched then silently dropped client-side. Wastes round-trip and hides the discard. Push filter into query.

**Status:** ✅ Done — commit 77bd17e. DEAD_LETTER_MAX_RETRIES=5 constant added; retry_count filter pushed into PostgREST query.

---

### M28: Wrong HTTP Status Code for Unmatched Webhook Route

**Priority:** P2 | **Severity:** Medium | **Source:** code-reviewer full-stack review, session 2026-03-21

`index.ts:170` returns `serverError` (HTTP 500) for unmatched routes instead of 404. Causes Stripe dashboard to report webhook delivery failures as 5xx instead of misconfiguration.

**Fix:** Return HTTP 404 with appropriate response for unmatched route.

**Status:** ✅ Done — commit 22794bb. notFound() (HTTP 404) replaces serverError() for unmatched routes.

---

### M29: Quota Bump Uses Null Assignment Instead of Monotonic Increment

**Priority:** P2 | **Severity:** Medium | **Source:** code-reviewer full-stack review, session 2026-03-21

`updateOrgBillingStatus` (workers/stripe-webhook/src/supabase.ts:84) sets `quota_version = null` as the bump mechanism. Null is not monotonic — it resets rather than increments. Two consecutive bumps within same tick both set `null` and second is indistinguishable from first. If polling clients use `quota_version` to detect changes, this breaks change detection.

**Fix:** Use `now()` timestamp or integer increment via RPC, not null.

**Status:** ✅ Done — commit cec8997. quota_version set to new Date().toISOString() — monotonic, unique per bump.

---

### L5: Empty `PRICE_TO_PLAN` Map Shipped to Production

**Priority:** P3 | **Severity:** Low | **Source:** code-reviewer full-stack review, session 2026-03-21

`workers/stripe-webhook/src/handlers/subscription.ts:8-10` defines empty `PRICE_TO_PLAN` map. Comment says "Example: ..." suggesting placeholder. `planKey` always `undefined` for all subscriptions; every update silently skips plan mapping with no log or error. Price IDs are environment-specific and should come from `env` bindings, not hardcoded map.

**Status:** Open — Low priority, deferred.

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

**Status:** ✅ Done — commit 3b017e9. 15 tests added covering all 5 functions; mockInsert/mockUpdate/mockUpsert hoisted; fake timers used for time-dependent assertions.

---

### L9: `DeadLetter` Interface Scoped Inside Function Closure

**Priority:** P3 | **Severity:** Low | **Source:** code-reviewer full-stack review, session 2026-03-21

`workers/stripe-webhook/src/supabase.ts:170-178` — `DeadLetter` interface defined inside `createSupabaseAdmin` closure. Not exported; cannot be referenced externally (e.g., in `index.ts` where `dl` is typed implicitly). Should be exported from module or moved to `workers/lib/types.ts`.

**Status:** ✅ Done — commit 9a154ea. issues.map(i => i.message).join('; ') replaces error.message at 5 call sites.

---

### M33: Improve Zod Error Message Formatting in Stripe Webhook Handlers

**Priority:** P2 | **Severity:** Medium | **Source:** code-reviewer review of H1 fix, session 2026-03-21 (commit 29a71d1)

`parseResult.error.message` on a Zod `ZodError` produces a stringified JSON array of issue objects (e.g., `[{"code":"invalid_type","path":["id"],...}]`), not a human-readable message. This raw output is stored verbatim in the dead-letter queue (via `db.addDeadLetter` in `index.ts`). Using `parseResult.error.issues.map(i => i.message).join('; ')` would produce cleaner error records.

**Files:** `workers/stripe-webhook/src/handlers/checkout.ts:17`, `subscription.ts:31,90`, `invoice.ts:52,77`

**Status:** ✅ Done — commit 9a154ea. issues.map(i => i.message).join('; ') replaces error.message at all 5 call sites.

---

### L12: Add Unit Tests for Stripe Schemas

**Priority:** P3 | **Severity:** Low | **Source:** code-reviewer review of H1 fix, session 2026-03-21 (commit 29a71d1)

`stripe-schemas.ts` (new file, lines 1-28) has no direct unit tests. Schema correctness is only exercised via integration through the handler tests. Add test file `workers/stripe-webhook/src/stripe-schemas.test.ts` covering:
- Valid Stripe payloads pass safeParse
- Malformed payloads (missing required fields, type mismatches) fail safeParse
- Edge cases (null metadata, missing items array, missing price.id)

**Status:** Open

---

### L13: Consider Requiring `customer` Field in Subscription/Invoice Schemas

**Priority:** P3 | **Severity:** Low | **Source:** code-reviewer review of H1 fix, session 2026-03-21 (commit 29a71d1)

`customer` is marked `.optional()` on `SubscriptionSchema` (line 16) and `InvoiceSchema` (line 22). Based on Stripe's API, `customer` is always present for non-setup-mode objects. A missing-customer payload currently passes `safeParse` successfully and only fails the business-logic guard in the handler. Marking `customer` as required in the schema would reject malformed payloads earlier.

**Files:** `workers/stripe-webhook/src/stripe-schemas.ts:16,22`

**Status:** Open (semantic issue, not a correctness bug)

---

### M34: Subscription Upsert Conflict Key Doesn't Handle Plan Upgrades

**Priority:** P2 | **Severity:** Medium | **Source:** code-reviewer session, session 2026-03-21 (post-M26 review, commit 867957c)

`upsertSubscription` uses conflict key `(organization_id, stripe_subscription_id)` to handle duplicate `customer.subscription.updated` events. However, the design assumes one subscription per org. Stripe allows plan changes (upgrades/downgrades) within a single subscription ID, which change the `stripe_price_id`. The current key strategy will update an existing row on conflict, which is correct, but the schema and handler logic do not guard against edge cases where a subscription cycles through multiple price IDs in quick succession (e.g., upgrade then downgrade). This is a latent design issue, not a current bug, but should be documented or refactored for clarity.

**Files:** `workers/stripe-webhook/src/supabase.ts:31-50`, `workers/stripe-webhook/src/handlers/subscription.ts:10-60`

**Status:** ✅ Done — commit e9046de. Doc comment added to `upsertSubscription` documenting conflict key semantics: one subscription per org assumption, plan upgrades/downgrades reuse same `stripe_subscription_id` and update `stripe_price_id` on conflict (last-write-wins), no special handling needed.

---

### M35: Dead Letter Reconciliation Partial Failure Leaves Inconsistent State

**Priority:** P2 | **Severity:** Medium | **Source:** code-reviewer session, session 2026-03-21 (post-M27 review)

Dead letter retry loop (`workers/stripe-webhook/src/index.ts:180-210`) calls `db.logProcessedEvent(eventId)` before `db.resolveDeadLetter(id)`. If `logProcessedEvent` succeeds but `resolveDeadLetter` fails (DB error), the event is marked as processed in the webhook_events_log table but the dead-letter row remains with `status='pending'`, creating inconsistent state. A subsequent retry attempt will skip it (already processed) without resolving the dead letter. Reconciliation cron must handle this scenario or queries should use a join to detect orphaned dead-letter rows.

**Files:** `workers/stripe-webhook/src/index.ts:198-206`

**Status:** ✅ Done — commits e9046de, b3a4224. Error logging added to both `resolveDeadLetter` call sites. When `logProcessedEvent` fails, `continue` skips `resolveDeadLetter` to leave dead-letter pending for retry. Idempotency guard recovery path documented in comments. Test updated to assert new correct behavior (resolveDeadLetter NOT called on logProcessedEvent failure).

---

---

## Code Review Findings: Billing Status Dashboard UI (Session 2026-03-21)

Code-reviewer full-stack review of billing status page (BillingStatusPage + DashboardService) identified 1 fixed High finding, 1 latent High risk, and 4 medium/low findings.

---

### H2-V02: JWT Leaked into Sentry `extra` Context (Latent Risk)

**Priority:** P2 | **Severity:** High | **Source:** code-reviewer review, session 2026-03-21 (billing status commits 979ab7c, 60fd1ff)

`DashboardService.fetchBillingStatus` and `fetchUsageSummary` pass `orgId` in `captureException` `extra` map (line 223-226). The JWT flows as a method parameter but is not currently logged. However, the pattern is established (ProvisioningService logs `endpoint`), and future copy-paste into `extra` would silently exfiltrate tokens to Sentry. The `extra` dict is untyped — no guard prevents credential inclusion.

**Mitigation:** Document the `extra` map at call sites as "no credentials" or add JSDoc comment on `captureException` signature warning against logging secrets.

**Status:** ✅ Done — commit 3f0804c. SECURITY comment added at all four captureException call sites in DashboardService.

---

### M30: `_formatDate` Lacks Telemetry on `DateTime.tryParse` Failure

**Priority:** P2 | **Severity:** Medium | **Source:** code-reviewer review, session 2026-03-21

`BillingStatusData.fromJson` (dashboard_service.dart:37) uses `DateTime.tryParse(rawDate)` which silently returns `null` if the API returns a malformed `current_period_end` (e.g., Unix epoch as integer instead of ISO 8601). The `null` case is handled correctly in the UI, but API format drift is undetected. If the API ever changes format, developers won't see an error until data appears wrong on-screen.

**Fix:** Add `if (rawDate != null && rawDate.isNotEmpty) { final parsed = DateTime.tryParse(rawDate); if (parsed == null) { await ErrorTrackingService.captureException(...); } }` to surface format divergence.

**Status:** ✅ Done — commit 4fb5380. unawaited captureException added in BillingStatusData.fromJson when tryParse returns null.

---

### M31: `billingStatus` String Type Unvalidated; Wildcard Falls Silent

**Priority:** P2 | **Severity:** Medium | **Source:** code-reviewer review, session 2026-03-21

`_statusColor` and `_statusLabel` (billing_status_page.dart:82-93) use switch expressions with wildcard default for unknown `billingStatus` values. If the API adds a new status (e.g., `'trialing'`), it silently falls through to `error` color + "Inactive" label, which is inaccurate and alarming to users. A future developer won't know the wildcard exists.

**Fix:** Add assertion in debug builds: `_ => () { assert(false, 'Unknown billing status: $status'); return AppColors.error; }()`.

**Status:** ✅ Done — commit c8e03a2. assert() added in _statusColor and _statusLabel covering all known values.

---

### M32: `statusColor`/`statusLabel` Computed in Parent; Duplication Risk

**Priority:** P2 | **Severity:** Medium | **Source:** code-reviewer review, session 2026-03-21

`_BillingStatusPageState` computes `_statusColor` and `_statusLabel` from `billingStatus`, then passes these derived values down to `_BillingCard` (lines 145-150). The conditional that ensures `statusColor`/`statusLabel` are non-null duplicates the check inside `_BillingCard`. If logic changes, both must be updated in lockstep.

**Fix:** Refactor to pass only `billingStatus` to `_BillingCard` and have the widget derive color/label internally, or extract a dedicated `_buildStatusBadge(String billingStatus)` method.

**Status:** ✅ Done — commit a76348b. _statusColor/_statusLabel moved to module-level functions; _BillingCard computes badge internally from billingStatus data.

---

### L10: Inline `Container` Decoration Duplicated in Two Cards

**Priority:** P3 | **Severity:** Low | **Source:** code-reviewer review, session 2026-03-21

`_BillingCard` (lines 183-189) and `_ErrorCard` (lines 322-328) have identical `BoxDecoration` with gray800 background, gray700 border, radiusMD. Duplicates the style pattern already established in `containers.dart`. If design system card style changes, both need manual update.

**Fix:** Extract to a static method or use `containers.dart` GlassCard widget for consistency.

**Status:** Open

---

### L11: Missing Doc Comment for `_maxRetries` Constant Semantics

**Priority:** P3 | **Severity:** Low | **Source:** code-reviewer review, session 2026-03-21

`DashboardService._maxRetries = 2` (line 139) lacks a doc comment explaining that "2 retries = 3 total attempts". `ProvisioningService` documents this pattern (line 204); `DashboardService` copied the code but not the clarifying comment.

**Fix:** Add line comment: `// Max retry attempts (2 retries = 3 total attempts: initial + 2 retries)`

**Status:** Open

---

### V02-Remaining: Org Switcher, Stripe Portal, Polling

**Priority:** P1 | **Severity:** Medium | **Source:** session 2026-03-21 (billing status implementation)

V02 Flutter Dashboard UI has 3 remaining components:
1. **Org switcher dropdown** — Select active org from list, update local state
2. **Stripe Customer Portal link** — Button linking to Stripe-managed subscription UI
3. **Real-time usage polling** — Refresh usage every 30s or on window focus (via `visibilitychange` event)

~~**Entitlements grid display** — ✅ Done: `EntitlementsPage` at `/entitlements` (commit 9f93f67)~~
~~**Usage charts/metrics visualization** — ✅ Done: `_DailyBarChart` (commits c78bbf1, 809496a), `QuotaStatusPage` (commits 9f93f67, e3ff7f3)~~

**Status:** Partially deferred — Entitlements grid and usage charts complete. Remaining 3 tasks are independent.

---

## Code Review Findings: V02 Dashboard Pages (Session 2026-03-21)

Code-reviewer session on quota_status_page, entitlements_page, usage_summary_page identified 2 fixed issues and 2 deferred Low-priority items.

---

### L14: `_ErrorCard` Widget Duplicated Across 5 Files

**Priority:** P3 | **Severity:** Low | **Source:** code-reviewer review, session 2026-03-21 (V02 pages)

`_ErrorCard` appears identically in 5 files: `billing_status_page.dart`, `quota_status_page.dart`, `entitlements_page.dart`, `usage_summary_page.dart`, `dashboard_page.dart`. Each file redeclares a `Container` with gray800 background, gray700 border, radiusMD, and "Retry"/"Try again" button. Maintenance risk: any styling change requires updating all 5 copies.

**Fix:** Extract to `lib/widgets/common/error_card.dart` as reusable widget or add to `containers.dart` (which exports GlassCard).

**Files:** `billing_status_page.dart:355-378`, `quota_status_page.dart:324-365`, `entitlements_page.dart:345-385`, `usage_summary_page.dart:614-660`, `dashboard_page.dart:273-301`

**Status:** ✅ Done — commit 2b281c5, code review PASS 2026-03-21.

---

### L15: `_PlanBadge` Renders Raw `planKey` Without Display Formatting

**Priority:** P3 | **Severity:** Low | **Source:** code-reviewer review, session 2026-03-21 (V02 pages)

`QuotaStatusPage._PlanBadge` renders `planKey` directly (e.g., `"starter_monthly"`) as display text. `_MetricTable._formatMetricKey` and `_EntitlementsGrid._formatKey` both apply snake_case → Title Case formatting to server-sourced strings. Plan key inconsistently raw.

**Fix:** Add `_formatPlanKey(planKey)` → split('_').map capitalize.join(' ') or reference shared formatter.

**File:** `lib/pages/quota_status_page.dart:307-310`

**Status:** ✅ Done — commit b92d558, code review PASS 2026-03-21.

---

---

## Code Review Findings: Stripe Webhook — Remaining Medium Items

### M34: Subscription Upsert Conflict Key Does Not Handle Plan Upgrades With New Subscription IDs

**Priority:** P2 | **Severity:** Medium | **Source:** code review analysis, 2026-03-21

`upsertSubscription` uses conflict key `(organization_id, stripe_subscription_id)`. When a customer upgrades from free to paid, Stripe may issue a brand-new `stripe_subscription_id`. This inserts a new row rather than updating the existing one, leaving two rows for the same org in the `subscriptions` table — one from the old plan, one from the new. `organizations.current_plan` is updated separately by `updateOrgBillingStatus` (driven by `customer.subscription.updated`) so direct `orgs` queries remain correct, but any direct query on the `subscriptions` table could return multiple active rows.

**Fix options:**
1. Before upserting, soft-delete (status='canceled') any existing subscription row for the org where `stripe_subscription_id` differs
2. Use `organization_id` alone as the conflict key if the business rule is one active subscription per org
3. Accept multi-row state and always join via `organizations.current_plan` rather than `subscriptions`

**File:** `workers/stripe-webhook/src/supabase.ts:38–58`

**Status:** Open — requires design decision on which conflict key strategy fits the billing model.

---

### M35: Silent Event Loss When `addDeadLetter` Fails in Webhook Handler

**Priority:** P2 | **Severity:** Medium | **Source:** code review analysis, 2026-03-21

In `handleWebhook` (`workers/stripe-webhook/src/index.ts:78–83`): when a handler returns `{ ok: false }`, `addDeadLetter` is called but its result is not checked. If the DB insert fails (network error, connection timeout), `addDeadLetter` resolves with `{ ok: false }` silently. The function still returns HTTP 200 to Stripe, so Stripe will not retry. The failed event is neither in `webhook_events_log` nor in `webhook_dead_letters` — it is permanently lost with no alert.

**Fix:** Check the return value of `addDeadLetter`. On failure, log a critical error with the full event payload for operator recovery. Consider returning HTTP 500 in this path to trigger Stripe's built-in retry, but note the re-delivery tradeoff (handler may be retried without the partial-failure guard).

**File:** `workers/stripe-webhook/src/index.ts:78–83`, `src/supabase.ts:141–160`

**Status:** ✅ Done — commit 82e488a. `addDeadLetter` result checked; on failure a CRITICAL log is emitted with the full event payload for operator recovery. HTTP 200 still returned to suppress Stripe retry (cron owns retry schedule).

---

### M36: `handleWebhook` Returns `processed: true` When `logProcessedEvent` Fails

**Priority:** P2 | **Severity:** High | **Source:** code-reviewer final review, backlog-implementer session 2026-03-21

In `handleWebhook` (`workers/stripe-webhook/src/index.ts`), when the handler succeeds but `logProcessedEvent` fails, the function returns HTTP 200 with `{ processed: true }`. The event is NOT in `webhook_events_log`, so the idempotency guard will not detect it as processed on a future Stripe retry — the handler will fire a second time. There is no dead-letter row (handler succeeded, no dead-letter written) and no cron recovery path.

**Fix:** When `logProcessedEvent` fails in `handleWebhook`, insert a dead-letter row (or return `processed: false`) so the cron can retry the log write. Alternatively, mirror the `runReconciliation` pattern: skip the success response and leave the event for retry.

**File:** `workers/stripe-webhook/src/index.ts:96–101`

**Status:** Open — High severity; complements the M35-a fix in runReconciliation.

---

*Last updated: 2026-03-21 — backlog-implementer (Medium) session: M34 documented (e9046de), M35-a fixed (b3a4224), M35-b fixed (82e488a), L14 extracted (2b281c5). Final review PASS (7/10). New finding: M36 (handleWebhook logProcessedEvent failure returns processed: true). Remaining: M34 conflict key design decision, M36, V02 Stripe portal link, Low items (L5–L7, L9, L12–L13, L15).*
