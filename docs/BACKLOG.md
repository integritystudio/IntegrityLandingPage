# Backlog

Open and deferred items only. Completed items are migrated to `docs/changelog/1.0/CHANGELOG.md`, `docs/changelog/1.1/CHANGELOG.md`, and `docs/changelog/1.2/CHANGELOG.md`.

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

### L16: Incomplete Scope — Update Remaining Card Containers in Dashboard Pages

**Priority:** P3 | **Severity:** Low | **Source:** code-reviewer observation, backlog-implementer session 2026-03-21

L10 refactored `_BillingCard` and `ErrorCard` to use `AppDecorations.card()` (commit d1152ed), but code-reviewer noted that equivalent inline `Container` + `BoxDecoration` patterns remain in:
- `_QuotaCard` (quota_status_page.dart)
- `_buildOrgContextCard` (provision_page.dart)
- Email badge `Container` in ProvisionPage

This creates inconsistency in design system usage. If the card style changes, developers must remember to update these three locations separately.

**Fix:** Apply the same `AppDecorations.card(borderColor: AppColors.gray700)` refactor to the remaining three containers for consistency.

**Files:** `lib/pages/quota_status_page.dart`, `lib/pages/provision_page.dart` (email badge, _buildOrgContextCard)

**Status:** Open — deferred from L10 scope (low priority, cosmetic).

---

### M37: DeadLetter and WebhookDeadLetter Interface Duplication

**Priority:** P3 | **Severity:** Low | **Source:** code review analysis, backlog-implementer session 2026-03-21

Two canonical definitions of the dead-letter interface exist:
1. `DeadLetter` — module-level export in `workers/stripe-webhook/src/supabase.ts` (lines 6–12), with 6 fields: `id`, `stripe_event_id`, `event_type`, `payload`, `retry_count`, `max_retries`
2. `WebhookDeadLetter` — Zod schema in `lib/types/schemas.ts`, with 8 fields including `status` and `created_at`

The two interfaces have overlapping but non-identical fields. Code references one or the other depending on context. During L9 implementation, this structural mismatch prevented using `WebhookDeadLetter` as a type for the query result (only 6 fields returned from the DB query, but `WebhookDeadLetter` requires 8).

**Fix options:**
1. Consolidate into a single schema definition and re-export from both locations
2. Document which definition is canonical and deprecate the other
3. Add JSDoc comments explaining the structural differences and use-case for each

**Files:** `workers/stripe-webhook/src/supabase.ts:6–12`, `lib/types/schemas.ts:DeadLetter vs WebhookDeadLetter`

**Status:** Open — requires design decision on consolidation strategy (not blocking, low impact).

---

*Last updated: 2026-03-21 — backlog-implementer session: L5 (02f567a), L6 (3c39673), L7 (4e02c0b), L9 (de048e7), L10 (d1152ed), L11 (4e1edc0), L12 (a59176f), L13 (fe85c77), L15 (b92d558) done; M34/M35/M36 confirmed done. Added L16, M37 from session observations.*
