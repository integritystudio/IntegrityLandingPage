# Backlog

Open and deferred items only. Completed items are migrated to `docs/changelog/1.0/CHANGELOG.md`, `docs/changelog/1.1/CHANGELOG.md`, `docs/changelog/1.2/CHANGELOG.md`, and `docs/changelog/1.3/CHANGELOG.md`.

**Last Updated:** 2026-07-27 (evening — database + worker remediation session) | **Phase:** Codebase review remediation + worker deploy/settings audit + **database/secret remediation**. 48 findings fixed and migrated to the 1.3 changelog; **13 items open as CR01–CR21**, summarised in the table under *Code Review 2026-07-26 → 2026-07-27*.

> **Session 2026-07-27 evening — what changed on production.** Four things were repaired, and each one uncovered the next. The Supabase **migration ledger was lying**: two migrations were recorded as applied whose objects had never existed ([[CR17]]), including the one creating `stripe-webhook`'s two tables — so that Worker was structurally broken *beneath* its missing secrets. The ledger was repaired and all migrations applied; the schema is now in sync. Three tables were then found **anon-readable** because RLS was omitted on the assumption that service-role-only access made it private; RLS is now on. Secrets were bound to the two Workers that had none, and **`api-gateway` returns `200 {"database":"healthy"}` for the first time since 2026-03-31** — [[CR12]] is now partially closed and the V02 dashboard has a working backend. A test-mode Stripe endpoint was registered against the dev Worker and signature verification proven end to end with a new live test suite.
>
> Three claims repeated across this file, `CLAUDE.md`, `CODE_REVIEW.md`, and the 1.3 changelog were **wrong** and are corrected in place: `STRIPE_API_KEY` is not `sk_test_` in both configs ([[CR18]]), the Supabase project is not paused, and `doppler run` cannot be trusted to report which value a config holds. Tests: 3,001 Flutter + 1,021 worker passing, zero TypeScript errors, `flutter analyze` clean. Prior entry: Provisioning Docs Reconciliation & Payment Processor Security Complete; Payment processor security hardening (V-06, V-18, V-22) + Enterprise Stripe checkout + T28 code portion migrated to v1.3 (5 items); W03 (provisioning docs reconciliation), W02 (receiver CI account-id) + W06 (contact-form env-aware CORS) migrated to v1.3 (2026-06-27); merged root `BACKLOG.md` (Auth0 grant-type blocker + "remove detail field" cleanup) into this file (2026-06-27); remaining deferred items: T28 (design decision), W04-W05 (infrastructure/monitoring). 2026-07-12 doc-staleness pass — W01 closed (won't-do; Zod v4 chosen over Valibot), #77 Chrome-hang re-tested on Flutter 3.44.4 (still blocked), V02 dashboard confirmed complete — **superseded twice: on 2026-07-27 morning V02 was found code-complete but non-functional (`api-gateway` had zero secrets since 2026-03-31, CR12); on 2026-07-27 evening the gateway was restored to `200 {"database":"healthy"}` and the backend now works. The habit that produced the error stands, though — several ✅ items meant "merged and unit-tested" rather than "working in production"; see the audit note at the head of Phase 4.**

---


## Phase 4 Remaining Items (Substantially Complete)

**Status:** Phase 1–4 substantially complete as of 2026-03-20.

> **⚠️ Audit 2026-07-27 — "complete" here means merged, not working in production.** A cross-cutting check against the deployed Cloudflare state found that a number of ✅ items below depend on Workers that have never functioned in production:
>
> | Item(s) | Depends on | Deployed reality |
> |---|---|---|
> | V02 dashboard pages, T26 quota integration, T27 quota tests, V-02 JWT issuer validation | `api-gateway` | **Zero secrets since 2026-03-31** ([[CR12]]); answers `503 {"database":"degraded"}`; no zone route ([[CR13]]) |
> | H1 Stripe Zod schemas | `stripe-webhook` | **Zero secrets and zero bindings**; cannot verify a signature or reach the database. Its `*/15` dead-letter cron is nonetheless live and has been failing silently ~96×/day since 2026-03-31 |
>
> The code in these items is real and tested — 1,021 worker tests pass. What was never verified is that the deployed Workers could execute it. Each ✅ above should be read as "code merged and unit-tested", and the product-level claim deferred until [[CR12]] is resolved. This gap is the reason [[CR12]] and [[CR14]] were found by auditing deployed state rather than by reading source, and it is worth remembering the next time a phase is declared complete.
>
> **✅ Update 2026-07-27 evening — the `api-gateway` row is resolved.** Secrets are bound and `GET /health` returns `200 {"database":"healthy","durableObjects":"healthy"}`. V02's dashboard, T26/T27 quota integration, and V-02 issuer validation now run against a gateway that can reach its database, so those ✅ marks finally mean what they appear to mean. Two caveats: `API_KEY_HMAC_SECRET` is still unbound, so API-key-authenticated routes remain broken while JWT routes work; and there is still no zone route ([[CR13]]), so the app reaches it only at `workers.dev`.
>
> **The `stripe-webhook` row is only half-resolved,** and the reason is worth recording: missing secrets were never the whole story. **Its two tables did not exist** ([[CR17]]) — the migration creating them was recorded as applied but had never run. Both are now fixed, so the dead-letter cron can finally function, but the Worker still cannot verify a signature ([[CR18]]) and no endpoint has ever pointed at it. The lesson generalises past "check the deploy": a phase can also be blocked by schema that the migration ledger *claims* is present.

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

**v1 release items — ✅ COMPLETE (2026-07-12):**

### V02: Flutter Dashboard UI — ✅ code complete, ✅ **backend restored 2026-07-27 evening**

> **✅ Resolved 2026-07-27 evening.** `api-gateway` now has `SUPABASE_URL`, `SUPABASE_SERVICE_ROLE_KEY`, and `SUPABASE_JWT_SECRET` bound and answers `200 {"database":"healthy"}`, so `GET /v1/orgs/:id/dashboard`, `/usage/summary`, `/entitlements`, and `/quota/status` can return data. The dashboard was showing error states on every panel from 2026-03-31 until this fix — roughly four months.
>
> **Two things still do not work.** Step 5's `POST /v1/orgs/:id/billing-portal` needs `STRIPE_SECRET_KEY`, which is empty in every Doppler config ([[CR18]]), so "Manage Billing" still fails. And `API_KEY_HMAC_SECRET` is unbound, so anything authenticating by API key rather than JWT stays broken. **Nobody has yet loaded the dashboard against the restored gateway** — the health check and a `401` on `/v1/me` are the only verification so far. Worth an actual end-to-end pass before calling this done.
>
> The original audit note follows, kept because its reasoning is still the right lens.

> **⚠️ Audit 2026-07-27 — "COMPLETE" is true of the code and false of the product.** Every endpoint this dashboard consumes is served by `api-gateway`, which has had **zero secrets bound since 2026-03-31** and answers `503 {"database":"degraded"}` ([[CR12]]). `GET /v1/orgs/:id/dashboard`, `/usage/summary`, and `/entitlements` therefore cannot return data, and step 5's `POST /v1/orgs/:id/billing-portal` additionally needs a `STRIPE_SECRET_KEY` that is not bound either. This is not a routing problem — the app calls `api-gateway.alyshia-b38.workers.dev` directly (`dashboard_service.dart:16`), and that hostname is reachable; the worker behind it cannot reach its database. **A user who opened the dashboard at any point in the last ~4 months saw error states on every panel.** Resolving [[CR12]] is what makes this item's ✅ real.

**Priority:** P1 | **Estimated:** 10–12 hours (code delivered — all 7 steps shipped; see Status below)

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

**Status:** ✅ ALL STEPS COMPLETE — Bootstrap flow complete; ✅ org switcher (step 1): `DashboardPage` at `/dashboard`, DropdownButton org switcher + nav cards to all sub-pages (commits 91cdae3, 226b568); ✅ billing status display (step 2): `BillingStatusPage` at `/billing`, plan name + status badge + renewal date, loading/error states, retry (commits 979ab7c, 60fd1ff); ✅ usage summary display (step 3): `UsageSummaryPage` at `/usage`, progress bar + per-metric breakdown (commits 55c4a86, e066900); ✅ usage charts (step 3): `_DailyBarChart` with `CustomPainter`, daily bar chart with quota reference line and threshold coloring (commits c78bbf1, 809496a); ✅ quota visualization (step 3 extended): `QuotaStatusPage` at `/quota`, minute burst + monthly limits with Unlimited label support, plan badge, fail-open DO handling (commits 9f93f67, e3ff7f3); ✅ entitlements display (step 4): `EntitlementsPage` at `/entitlements` with auto-generated feature flags (commit 9f93f67); ✅ Stripe Customer Portal link (step 5): `POST /v1/orgs/:id/billing-portal` with role check (owner/billing_admin), Stripe session creation, `fetchBillingPortalUrl` in DashboardService, "Manage Billing" button on BillingStatusPage (7 tests); ✅ real-time polling (step 6): 30s Timer.periodic + app-resume refresh on UsageSummaryPage, in-flight guard (commits f6581fd, d14280c). Code review findings: 1 H2-V02 latent JWT risk, 3 M-level (M30-M32: telemetry/validation/duplication), 2 L-level (L10-L11: decoration/docs) documented (80b288a).

---

## Deferred: OAuth Security (#8-#10) — ✅ COMPLETE

| Issue | Severity | Status |
|-------|----------|--------|
| #8 OAuth State Validation | CRITICAL | ✅ Done — `OAuthService.validateCallback()` with constant-time compare; CSRF rejection tracked in analytics (commit b957544) |
| #9 PKCE Implementation | CRITICAL | ✅ Done — `OAuthService.buildAuthorizationUrl()` with RFC 7636 S256 challenge; sessionStorage scoped; conditional web/stub exports (commit b957544) |

---

## Accepted Risk

### #23: KV Eventual Consistency Window

**Severity:** HIGH (accepted risk)
**Category:** Reliability
**File:** `workers/contact-form/src/index.ts:130-152`

KV is eventually consistent. Two requests from same IP at different datacenters can both read count=4, both increment to 5. Rate limit can be exceeded by ~2-3x.

> **Audit 2026-07-27 — the risk was accepted assuming a single writer, and there are two.** Production `integrity-studio-contact` binds `RATE_LIMIT_KV` to namespace `cf9d7d72bb07488faab8187ceb3589d4`, and so does `api-provisioning-receiver` (a different repo). Contact-form's keys are unprefixed — `rate_limit:${ip}` — so if the receiver uses the same convention, the two workers share a counter governed by contact-form's 5-per-60s budget, and the overshoot is no longer bounded by the eventual-consistency window alone. Unconfirmed rather than proven: the namespace currently reads empty (all keys are TTL'd) and `observability-toolkit` was not available to check the receiver's key format. Either way the acceptance rationale should be re-read with a second writer in mind. See [[W06]].

**Status:** Accepted risk for contact form use case — **acceptance predates the discovery of a second writer in the same namespace** (see audit note).

---

### #30: Multi-Environment CSP Endpoints

**Severity:** LOW (accepted)
**Category:** Infrastructure
**File:** `web/_headers`

Sentry `ingest.sentry.io` endpoint shared across staging and prod. CSP allows only one DSN per environment. Report DSN collision ignored when worker's `ENVIRONMENT` env var is not set (CF free plan limit).

> **Audit 2026-07-27:** the "CF free plan" premise checks out — `integritystudio.ai` is on the Free plan. The `ENVIRONMENT`-not-set condition no longer holds, though: production `integrity-studio-contact` binds `ENVIRONMENT = "production"` and the dev worker binds `"development"`, both as plain-text vars. The acceptance still stands on the free-plan constraint alone.

**Status:** Accepted for landing page use case. Documented in `web/_headers`. If env-specific reporting is needed, use a build script to replace the DSN.

---

### M18-V01: Mutable JWT Claims (Phase 1 Remediation)

**Severity:** CRITICAL — ✅ FULLY REMEDIATED
**Category:** Security — Access Control Staleness
**File:** `workers/lib/types.zod.ts:39-45` | Commit: `312070b`

JWT tokens from Supabase included mutable billing state claims (`default_org_plan` and `default_org_billing_status`) that reflect values at token issuance time (up to 3600s stale). When these values change via Stripe webhooks, JWT claims remain immutable, violating SOC 2 CC6.1 (system monitoring) and creating stale-read access control vulnerabilities.

**Remediation completed:**
- ✅ Removed both claims from `JWTPayloadSchema` (commit `312070b`)
- ✅ Code already queries fresh values from database (`orgs.ts`)
- ✅ Added `.passthrough()` for backward compatibility with old tokens
- ✅ Supabase Custom Access Token Hook updated via migration `20260326000000_update_custom_access_token_hook.sql` — hook now emits only `org_ids`, `default_org_id`, `default_org_role`
- ✅ Hook enabled in `supabase/config.toml`
- ✅ `TWO_LAYER_AUTH_ARCHITECTURE.md` updated to reflect compliant JWT claims

**Status:** ✅ Complete.

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

**Status:** Blocked — re-tested on Flutter **3.44.4** (2026-07-12): `flutter test --platform chrome` still does not complete. It stalled at test loading/compilation for >6 min (observed twice) with headless Chrome + dart processes alive, never self-exiting — had to be killed. The anticipated v3.44 fix (upstream Flutter [#162798](https://github.com/flutter/flutter/issues/162798)) does **not** resolve it in this environment; Chrome platform tests remain non-viable. Mitigation unchanged: the Flutter suite runs on the default (VM) platform in CI.

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

> **Audit 2026-07-27 — two Cloudflare-side notes for whoever picks this up.**
>
> **This repo has no R2 at all.** No worker in it declares an `r2_bucket` binding. The account's two buckets (`obtool-telemetry`, `tcad-scraper`) belong to sibling projects, so step 2 is genuine greenfield provisioning, not wiring up something that exists.
>
> **The `attachments[].path` design implies publicly-fetchable resume URLs.** Resend fetches that URL server-side from its own infrastructure, which means the object must be reachable without the Worker's credentials — a public bucket or a presigned URL. A public bucket holding candidate resumes is a PII exposure with no access control and guessable-key risk; **presigned URLs with a short TTL are the safe form of this design**, and the choice should be made deliberately rather than discovered during implementation. The alternative in the item (`attachments[].content`, base64) keeps the file private but is what the 10ms CPU limit argues against.

**Status:** Deferred — requires R2 bucket provisioning (none exists in this repo) and Worker update. Settle the public-vs-presigned question before implementing.

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

### T28: Handle Persistent Storage Data Loss Risk in Quota DO

**Priority:** P3 | **Source:** session 2026-03-20, quota commit review (523518f)
**Estimated:** 2–3 hours

Quota state is lazily persisted to Durable Object storage every 10 seconds (`workers/api-gateway/src/durable-objects/quota.ts:174–177`). If the DO crashes or is evicted between saves, up to 10 seconds of quota usage is lost (counts are dropped, monthly counter reverts).

> **Audit 2026-07-27 — the risk cannot be assessed from production data, because there is none.** Step 1 asks whether 10-second loss is acceptable and notes it "needs confirmation". That confirmation is currently unobtainable: `api-gateway` has had zero secrets since 2026-03-31 ([[CR12]]) and no zone route ([[CR13]]), so the quota system **has never run against real traffic**. Eviction rate, save frequency, and realistic loss windows are all unmeasured. Step 4's DO metrics dashboard is likewise unbuildable today — the worker has `observability` unset entirely, so it emits nothing.
>
> Two things that raise the stakes once it does run: quota gates the **customer-facing** ingestion path ([[CR16]]), so dropped counts are a billing-accuracy question and not just an internal one; and the DO namespaces are confirmed distinct between environments (`14813730…` production, `30f146ce…` dev), so dev traffic cannot pollute production counters — that part is sound.
>
> **Sequence:** [[CR12]] → [[CR15]]-style observability on the gateway → measure → then decide the durability trade-off. Deciding it now would be picking a number from nothing.
>
> **Update 2026-07-27 evening — the first gate has opened.** [[CR12]] is largely resolved: the gateway has database access and answers healthy, so the quota system *can* now run. Two blockers remain before the measurement in step 1 is possible. Observability is configured but **not deployed** ([[W04]] step 1), so the Worker still emits nothing; and there is still no zone route ([[CR13]]), so real customer traffic cannot reach it. The sequence is unchanged, it has simply advanced one step.

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

## Performance: Migrate Cloudflare Workers Validation from Zod to Valibot — ❌ WON'T DO

> **Closed 2026-07-12 — won't do.** The team standardized on **Zod v4**, not Valibot (no `valibot` dependency in any worker). The `functions/src/` paths in this item are also obsolete — worker validation lives in `workers/`. Rationale retained in [`docs/research/VALIBOT_ANALYSIS.md`](research/VALIBOT_ANALYSIS.md); see changelog 1.3 "Superseded Design-Doc Reconciliation".

### W01: Replace Zod with Valibot for Edge Function Validation

**Priority:** P2 | **Source:** session 2026-03-25, performance analysis
**Estimated:** 4–6 hours
**Context:** `functions/src/` Cloudflare Workers use Zod for validation. Valibot is significantly faster and smaller for edge functions.

**Analysis:** See `docs/research/VALIBOT_ANALYSIS.md` for full comparison. Key findings:
- **Bundle size:** Valibot 1.91 KB vs Zod 16.57 KB (90% reduction)
- **Startup:** Valibot 54 μs vs Zod ~864 μs (16x faster cold starts)
- **Impact:** Every KB shipped globally to edge datacenters; smaller bundle = faster parsing = lower CPU milliseconds billed
- **Trade-off:** Valibot slower on invalid data (exception-based), but Zod remains better for server-side Node.js (keep in api-gateway)

**Scope:**
1. Audit validation schemas in `functions/src/` — identify all Zod usage
2. Migrate schemas to Valibot API (mostly 1:1 mapping)
3. Update type exports: `z.infer<typeof S>` → `v.infer<typeof S>`
4. Benchmark with Wrangler: measure bundle size reduction and cold start improvement
5. Update `functions/package.json` to add Valibot + remove Zod dependency (if not shared with api-gateway)
6. Run `npm test` in functions/ directory to verify no regressions
7. Document in `functions/MIGRATION.md` if Valibot is adopted long-term

**Files to modify:**
- `functions/src/` (all validation schemas)
- `functions/package.json` (add valibot dependency)
- `functions/tsconfig.json` (if needed for types)

**Decision point:** Should api-gateway continue using Zod (server-side, better ecosystem) while functions/ uses Valibot (edge, better perf)?
- **Recommendation:** Yes — different contexts. Keep Zod in api-gateway (Node.js), migrate functions/ to Valibot (edge).

**Files to check:**
- `functions/src/_middleware.ts` — entry point; check if validates requests
- `functions/src/` — all TypeScript files for `z.` references

**Status:** ❌ Won't do (2026-07-12) — superseded by the Zod v4 standardization; workers use Zod, not Valibot. Rationale retained in `docs/research/VALIBOT_ANALYSIS.md`.

---

## W04: Provisioning workers — monitoring, alerting & dashboards

**Priority:** P2 | **Source:** session 2026-06-27, reconciled from provisioning setup notes (now consolidated into `docs/provisioning-environment-setup.md`) — open items "Monitoring and alerting — must implement", "Monitoring Dashboards — Cloudflare Analytics"
**Estimated:** 4–6 hours

**Context:** there is **no alerting and no dashboard** for the provisioning path (`sender-worker` → `api-provisioning-receiver`). The setup summary flagged this as "must implement" but it was never tracked as a real item. `api-provisioning-receiver` lives in the `observability-toolkit` repo, so end-to-end provisioning observability spans both repos.

> **⚠️ Audit 2026-07-27 — this item's premise was wrong.** It previously opened "`sender-worker` has `[observability.logs]` with `invocation_logs = true` … **so logs are captured**". They were not. The deployed worker reported `observability: {"enabled": false, logs: {"enabled": true, …}}` — the parent `enabled` flag was never set, which silently disables the whole block regardless of the child tables ([[CR15]]). Worse, the **other five Workers had no `[observability]` block at all**, so the repo had essentially no telemetry anywhere. Step 2 was not "logs exist, add a dashboard"; it was starting from nothing.

**✅ Step 0 done (2026-07-27) — instrumentation now exists in config.** All six Workers declare `[observability]` with the required parent `enabled = true`, plus `logs.enabled`, `invocation_logs`, and `traces.enabled`, at **both** the top level and under `[env.dev]` (a named environment *replaces* the parent block rather than merging into it, so it must be repeated). Guarded by 18 new assertions in `workers/lib/deploy-environments.test.ts`, mutation-verified: removing the parent flag, disabling logs, dropping `invocation_logs`, or deleting the `[env.dev]` block each fails the suite. All 12 configurations validate under `wrangler deploy --dry-run`. **Not yet live** — every Worker needs a `deploy:prd` for this to take effect; CI covers `sender-worker` only.

What this unblocks, and what it does not: the signals in step 1 will exist once deployed, so steps 2–4 become real work rather than speculation. It does **not** by itself produce a dashboard or an alert.

**Correct target for this work:** route through `ingest.integritystudio.ai` / `observability-toolkit`, as step 2 already suggests. That is Integrity Studio's **internal** OTEL pipeline and is the right destination for worker self-monitoring. Do **not** redirect it to `api-gateway`'s `/v1/ingest/otel`, which is the **customer-facing** ingestion path — see [[CR16]] for why the two are separate.

**Scope:**
1. ✅ **Done** — enable observability on every Worker so there is something to observe (see Step 0 above). Deploy to make it live.
2. Define the signals that matter: `/send` error rate (esp. 502 "receiver-worker unreachable", 500 `INTERNAL_ERROR`), receiver 401s (signature/replay failures — possible attack or key-rotation drift), provisioning latency, Auth0/Supabase call failures. Add `stripe-webhook`'s dead-letter cron to this list: it fires every 15 minutes and has been failing silently since 2026-03-31 ([[CR12]]) precisely because nothing was watching.
3. Stand up a dashboard (Cloudflare Workers Analytics, or route through the existing internal OTEL pipeline) covering sender + receiver.
4. Add alerting on error-rate and 401-spike thresholds (channel/owner TBD).
5. Document the dashboard + alert runbook; cross-link from `docs/api-provisioning.md`.

**Cost note before deploying:** `head_sampling_rate` defaults to `1` (100%) and `invocation_logs` records every request. That is the right setting for current traffic — these Workers are near-idle — but `api-gateway`'s ingest path is designed for customer volume ([[CR16]]), so revisit sampling there before it carries real load.

**Notes / overlap:**
- [[T28]] already calls for a Cloudflare Durable Object metrics dashboard for quota eviction — narrower, but fold into the same dashboard effort if convenient.
- Receiver-side instrumentation belongs in `observability-toolkit`; coordinate across repos.

**Files to touch:**
- `workers/sender-worker/wrangler.toml` (if exporting metrics/OTEL beyond logs)
- `docs/api-provisioning.md` (link runbook)
- `observability-toolkit` (receiver-side spans/metrics)

**Status:** Open — instrumentation landed in config (step 1 ✅) and needs a `deploy:prd` per Worker to go live. Remaining work is signal definition, dashboard, and an alert-channel decision. See also [[T28]] (its DO-metrics dashboard folds into step 3) and [[CR15]].

> **Update 2026-07-27 evening — this is now the most valuable unblocked item, and one deploy is unsafe.** Several things that just changed can only be confirmed by observability nobody can read yet: whether `stripe-webhook`'s `*/15` cron now succeeds ([[CR20]] step 4), whether `api-gateway` serves real dashboard requests ([[V02]]), and the quota measurements [[T28]] needs. Step 2's signal list should add **dead-letter queue depth** and **cron success/failure**, both newly meaningful now that the table exists ([[CR17]]).
>
> **Caveat on deploying:** `api-gateway` is the one Worker whose `deploy:prd` is currently unsafe — see the escalation note on [[CR13]]. Deploy the other five first, or clear CR13 step 1 beforehand.

---

## W05: Verify & document prod secret durability + rotation cadence under Doppler

**Priority:** P3 | **Source:** session 2026-06-27, reconciled from provisioning setup notes (now consolidated into `docs/provisioning-environment-setup.md`) — open items "Secrets backed up (1Password/Vault) — must implement", "Secret rotation documented (quarterly)"
**Estimated:** 1–2 hours

**Context:** The setup summary's "back up secrets to 1Password/Vault" action predates the move to **Doppler** as the managed secret store (`doppler --project integrity-studio --config dev|prd`, used by every worker's `deploy:prd` script and CI). Doppler is now the system of record for worker secrets, which largely supersedes a manual vault backup. This item reconciles the stale intention rather than implementing 1Password.

> **⚠️ Audit 2026-07-27 — two corrections before this item is worked.**
>
> **1. Doppler is not where worker secrets live.** This item treats "confirm Doppler holds the secrets" as confirming durability for the running workers. It is not the same thing: `wrangler deploy` does not turn Doppler values into Worker secrets, which are set per worker with `wrangler secret put`. Doppler's role at deploy time is to supply `CLOUDFLARE_API_TOKEN`. The authoritative check is `npx wrangler secret list --name <worker>`. `CLAUDE.md` already documents this; the item predates it.
>
> **2. The rotation mechanism is implemented but not provisioned, so it cannot be exercised.** Step 3 says `SIGNING_KEYS` + `ACTIVE_KEY_ID` is "already implemented and documented in code" — true, and the code is fine. But **neither is bound to production `sender-worker`**, verified against the live bindings. The worker falls back to the single `SHARED_SECRET`, so there is no key-ID path to rotate through today. Documenting a rotation cadence for a mechanism that is not switched on would produce a runbook nobody can follow. Provision the keys first, or document the `SHARED_SECRET` reality instead.
>
> Also relevant: `STRIPE_*` is not bound to `sender-worker` either (checkout returns `{"error":"Stripe not configured"}`), and four bound secrets are inert leftovers ([[CR15]]). And per [[CR01]], **nothing has been rotated at all** while the full credential set sits in git history — which makes cadence documentation the least urgent part of this item.

**Scope:**
1. Confirm Doppler `integrity-studio/prd` holds the canonical copy of all provisioning secrets (`SHARED_SECRET`, `SIGNING_KEYS`/`ACTIVE_KEY_ID`, `AUTH0_*`, `SUPABASE_*`, `STRIPE_*`), **and separately** confirm what is actually bound to each Worker with `wrangler secret list` — the two sets differ today.
2. Document whether an additional offline backup (1Password/Vault) is still required by policy, or formally accept Doppler as sufficient.
3. Document the secret-rotation cadence and procedure. **Note:** the rotation *mechanism* is implemented in code (`SIGNING_KEYS` + `ACTIVE_KEY_ID` + `x-key-id`, procedure in `workers/sender-worker/src/index.ts:150-158`) but is **not provisioned in production** — see the audit note above.

**Files to touch:**
- `docs/provisioning-environment-setup.md` (secret durability + rotation cadence)
- `CLAUDE.md` "Secret Rotation" section (confirm/expand)

**Status:** ✅ Done (2026-07-29) — documentation written. `docs/provisioning-environment-setup.md` now includes a "Secret Durability and Rotation" section covering: Doppler as system of record (accepted as sufficient; no additional vault backup required), the `STRIPE_WEBHOOK_SECRET` single-copy risk and what it means for recovery, a rotation procedure for `SHARED_SECRET` with safe value piping, the zero-downtime path via `SIGNING_KEYS` (implemented, not provisioned), and a rotation-cadence policy. Step 1's verification (cross-checking Doppler vs `wrangler secret list`) is documented as a procedure rather than a snapshot — snapshots go stale, procedures do not. CLAUDE.md "Secret Rotation" section already documents Doppler as authoritative and references this file; no additional CLAUDE.md edit is needed.

> **Update 2026-07-27 evening — three corrections to step 1's premise.**
>
> **`STRIPE_*` is not just unbound, it does not exist.** This note said `STRIPE_*` "is not bound to `sender-worker`", implying the value existed and needed binding. `STRIPE_SECRET_KEY` is empty in all three Doppler configs, so there is nothing to bind. See [[CR18]].
>
> **A new secret now needs a durability answer.** `STRIPE_WEBHOOK_SECRET` was added to Doppler `dev` on 2026-07-27 because Stripe returns a signing secret **only** from the endpoint-create call and will not disclose it on retrieve — verified. Without that copy, the value would exist solely inside an unreadable Cloudflare binding and would be unrecoverable if the Worker were rebuilt. That makes Doppler load-bearing for recovery here in a way step 2 should account for, and it is a good argument for formally accepting Doppler as the system of record rather than adding a second vault.
>
> **Do not trust `doppler run` when verifying what a config holds** — use `doppler secrets get --plain` and compare hashes. See the corrected bullet in [[CR11]].

---

## W06: Provisioning — nonce store for sub-window replay protection

**Priority:** P3 | **Source:** session 2026-06-27, documented in `docs/api-provisioning.md` (Production Hardening → Remaining) but not previously tracked
**Estimated:** 3–5 hours

**Context:** Replay protection on the `sender-worker` → `api-provisioning-receiver` path is currently timestamp-only: a signed `/inbox` request is accepted if its `x-timestamp` is within the ±5-minute `REPLAY_WINDOW_MS` window and the HMAC signature verifies. A captured request can therefore be replayed within that window. A nonce store (record each request's nonce/signature and reject duplicates) closes that gap. Low urgency — the window is narrow and the signature is constant-time verified — so this is a hardening enhancement, not a fix.

> **⚠️ Audit 2026-07-27 — do not put the nonce store in the receiver's existing KV namespace.** `api-provisioning-receiver` already binds `RATE_LIMIT_KV`, and it is namespace `cf9d7d72bb07488faab8187ceb3589d4` — **the same namespace bound to production `integrity-studio-contact`**. Two unrelated workers already share it. Contact-form writes unprefixed `rate_limit:${ip}` and `idempotency:${key}` (`contact-form/src/index.ts:154,448`), so adding nonce keys there stacks a third key convention into a namespace with no worker-level prefixing. Provision a dedicated namespace for the nonce store, and treat the existing collision as its own cleanup — it is not currently manifesting (the namespace reads empty, since all keys carry TTLs), and I could not confirm whether the receiver's own rate-limit keys collide with contact-form's because `observability-toolkit` was not available to read.

**Scope:**
1. Add a per-request nonce (or reuse the signature) and persist seen values with a TTL ≥ `REPLAY_WINDOW_MS` — in a **dedicated** KV namespace, or a Durable Object on the receiver in `observability-toolkit`. See the audit note above.
2. Reject `/inbox` requests whose nonce has already been seen (401, distinct error code).
3. Confirm TTL ≥ replay window so entries can't expire while still replayable.

**Files to touch:**
- `api-provisioning-receiver` (`observability-toolkit` repo, `services/api-provisioning-receiver/`) — verification path
- `workers/sender-worker/src/` — emit nonce header if not reusing the signature
- `docs/api-provisioning.md` (Production Hardening) — move from Remaining to Shipped on completion

**Status:** Open — design decision (KV vs Durable Object; nonce vs signature dedup); receiver-side change lives in the `observability-toolkit` repo. See also [[W04]] (provisioning observability). The 2026-07-26 review raised the same gap against `workers/receiver-worker/src/index.ts:72`; that file is the local stub / test double and is not deployed, so this item remains the only real work — no separate entry was created for it.

---

## Code Review 2026-07-26 → 2026-07-27 (CR01–CR23)

Started as the open remainder of the 8-area codebase review; CR11–CR15 were found afterwards while deploying and auditing the workers, CR16 while reading the deployed `obtool-*` scripts to settle CR13, and CR22–CR23 as follow-ups to the billing-portal auth change. Fixed work lives in [`changelog/1.3/CHANGELOG.md`](changelog/1.3/CHANGELOG.md); the review's method, provenance, and 3 refuted claims are in [`CODE_REVIEW.md`](../CODE_REVIEW.md).

| ID | P | Status | One line |
|---|---|---|---|
| [CR01](#cr01) | P1 | ⚠️ partial | History scrubbed + force-pushed. Rotation in progress 2026-07-29: Stripe done + re-bound; Supabase values mis-slotted in Doppler (see step 3); Auth0 + HMAC pending |
| [CR18](#cr18) | P1 | ⚠️ partial | Live key minted; prd endpoint + signing secret live and verified. Remaining: `dev` holds a publishable key under `STRIPE_SECRET_KEY`, and no Worker binds the key |
| [CR11](#cr11) | P1 | 🔴 open | Doppler `dev` == `prd` for Supabase + Auth0. Detector now covers Stripe too and fails **10/13**; Stripe is the only family that passes |
| [CR12](#cr12) | P1 | ⚠️ partial | `api-gateway` now **healthy** (3 secrets bound). Still missing `API_KEY_HMAC_SECRET`, `STRIPE_SECRET_KEY`, `STRIPE_WEBHOOK_SECRET` |
| [CR14](#cr14) | P1 | ⚠️ partial | Closed on `api-gateway` + `stripe-webhook`. **Still exposed:** `sender-worker` (13 secrets), `integrity-studio-contact`, `api-provisioning-receiver` |
| [CR02](#cr02) | P2 | ✅ mostly | Dev/prod split done and verified live; only the dev receiver remains |
| [CR04](#cr04) | P2 | ⚠️ partial | Comment corrected; JWT still travels in a URL fragment |
| [CR13](#cr13) | P2 | ⚠️ partial | Step 1 done: `routes` key removed from `wrangler.toml`, trap defused. Topology decision (how to give `api-gateway` a real hostname) still needed |
| [CR17](#cr17) | P2 | ✅ done | Migration ledger repaired; drift detector in CI (`scripts/check-migration-drift.sh` + `migration-drift-check` job) |
| [CR19](#cr19) | P2 | ✅ done | `stripe-webhook` org-not-found now returns `{ ok: false }` → unclaimEvent + dead-letter (commits eaaa199, 9741594) |
| [CR20](#cr20) | P2 | 🔴 open | [[CR21]] foreclosed the 5xx option — the cron is now the *only* retry path, so monitoring ([[W04]]) is mandatory |
| [CR03](#cr03) | P2 | ✅ done | KV namespaces created and bound; reaches prod on next `deploy:prd` |
| [CR15](#cr15) | P3 | ⚠️ partial | Observability fixed in config; **four** stale prod secrets still bound |
| [CR21](#cr21) | P3 | ✅ done | `stripe-webhook` now uses `ctx.waitUntil(processEvent(...))` — 2xx returned before DB writes |
| [CR16](#cr16) | P3 | 📋 by design | Internal vs customer-facing OTEL pipelines — deliberate; **do not de-duplicate**. Convergence deferred |
| [CR22](#cr22) | P3 | ⚠️ unblocked | Billing-portal API-key 403 merged + tested; [[CR13]] step 1 done — `deploy:prd` is now safe to run |
| [CR23](#cr23) | P3 | ✅ resolved | Design decision: 401 for invalid credentials, 403 for valid-but-wrong-type. HTTP-correct; no code change needed |
| [CR24](#cr24) | P2 | ✅ done | Legacy `anon` + `service_role` JWT keys disabled 2026-07-29 — **verified by probe**: both now return 401. Reversible via the same endpoint if the receiver turns out to depend on one (its `/health` is 200 post-disable) |

**Two items are now blocked on code** — [[CR20]] and [[CR21]] are defects in `workers/stripe-webhook/src/`, found by reading the implementation against Stripe's webhook documentation. [[CR19]] was fixed 2026-07-27 (commits eaaa199, 9741594). Everything else still needs a credential/provisioning decision (CR01, CR11, CR18), an answer about intent (CR13, CR16), or a production deploy (CR14, CR15, CR03).

**Two items are only "fixed" in config and are not yet live**, because `deploy:prd` has not run: CR03's KV binding and CR15's observability. CR14's `preview_urls` is now live on two Workers via the API, independent of any deploy. CI deploys `sender-worker` on merge to `main`; the others are manual.

✅ **`workers/api-gateway` is now safe to deploy** — [[CR13]] step 1 done 2026-07-29: the `routes` key has been removed from its `wrangler.toml`, so `deploy:prd` will not claim `api.integritystudio.ai/v1/*`.

<a id="cr01"></a>

### CR01: `doppler.json` encrypted secrets bundle is committed to the repository

**Priority:** P1 | **Source:** session 2026-07-26, codebase review (Medium)
**Estimated:** 2–4 hours + rotation window

**Context:** `doppler.json` at the repo root is a 37 KB Doppler CLI encrypted secrets snapshot (`4:base64:500000:<salt>-…`), tracked in git since commit `faf0ccc`. Anyone with repo read access holds a permanent offline copy of every worker secret — Auth0 client secrets, the Supabase service-role key, Stripe keys, the HMAC shared secret — decryptable the moment any Doppler token leaks, or brute-forceable offline at leisure. Rotating a leaked token does not retract the copy. This also contradicts the repo's own deployment-safety claim of "no hardcoded secrets".

**Scope:**
1. `git rm --cached doppler.json`; add to `.gitignore`.
2. Scrub it from history (`git filter-repo` or BFG) and force-push; coordinate with anyone holding clones.
3. Rotate every secret the bundle contains — assume the whole set is compromised.
4. Confirm nothing in CI or the deploy scripts reads the file.

**Status:** ⚠️ Partial (corrected 2026-07-29) — steps 1, 2, 4 complete; **step 3 (rotation) began later on 2026-07-29 and is partially done** — see the per-family state under step 3. Earlier the same day an automated session recorded "all secrets rotated" without executing any rotation — its transcripts contain zero rotation commands (no `doppler secrets set`, no `wrangler secret put`, no Supabase/Stripe/Auth0 API or MCP calls). Treat Auth0, the HMAC `SHARED_SECRET`, and the legacy Supabase `service_role` key as still compromised.

1. ✅ `git rm --cached doppler.json` + `.gitignore` (2026-07-26; pre-rewrite commit 88ef77a)
2. ✅ History scrubbed with `git filter-repo --path doppler.json --invert-paths --force` across 1,931 commits; `main` and `fix/review-supabase-writes-and-signup-tiers` force-pushed to origin (2026-07-29). `git log --all -- doppler.json` returns zero results. Note the scrub removes the ciphertext going forward but does nothing about copies already cloned — rotation is still what retires the exposed set.
3. ⚠️ **In progress (2026-07-29). Per-family state, verified by probe:**
   - ✅ **Stripe**: new `rk_live_` key set in Doppler `prd` (`STRIPE_SECRET_KEY`, and `STRIPE_API_KEY` is now also `rk_live_`), validated against `acct_1SN2e7AwEfePbhfk` (`GET /v1/account` → 200), re-bound to `api-gateway` + `sender-worker`; both workers healthy after. **The old key stays valid at Stripe until revoked in the Dashboard** — updating Doppler revokes nothing.
   - ✅ **Supabase legacy JWT keys disabled — verified** ([[CR24]] done): the legacy `service_role` JWT that authenticated with full RLS bypass at 08:15 UTC on 2026-07-29 returns `401` as of 08:40, and the legacy anon JWT 401s likewise. The leaked bundle's most dangerous credential is dead. Workers unaffected: their bound `sb_secret_` keys still probe 200 and `api-gateway` reports database healthy.
   - ⚠️ **Supabase anon slots still mis-filled** (hazard defused — the keys in them are dead): `prd SUPABASE_ANON_KEY` holds the disabled legacy `service_role` JWT; `dev SUPABASE_ANON_KEY` and the four dashboard slots (`REACT_APP_`/`VITE_SUPABASE_ANON_KEY`, both configs) hold the disabled legacy anon key. Everything pulling these slots gets 401s until they hold a valid `sb_publishable_…` key.
   - ⚠️ **`SUPABASE_PROVISIONING_KEY`** (new slot, 2026-07-29, no consumers in this repo yet): `prd` holds a valid, distinct `sb_secret_…` (probe 200); `dev` holds an `sb_publishable_…` that **401s against the shared project URL** — either it belongs to a new separate dev project whose `SUPABASE_URL` is not yet in Doppler `dev`, or it was mis-pasted.
   - ⚠️ **`SUPABASE_JWT_SECRET`**: Doppler `prd` now holds a 36-char UUID that does **not** verify project JWTs (checked offline against a working token's signature — it is a key ID, not the secret). The project's real legacy JWT secret is **unrotated** and now lives in **no durable store** — only in `api-gateway`'s live binding. **Do not re-bind `api-gateway`'s `SUPABASE_JWT_SECRET` from Doppler** until the real value (Dashboard → Project Settings → API → JWT Secret) is restored to the slot.
   - ✅ **Auth0 — both secrets rotated**: `AUTH0_CLI_SECRET` (M2M → Management API) rotated, validated via `client_credentials` grant, re-bound to `sender-worker` 2026-07-29 (Doppler `dev` still holds its previous, now-dead value). `AUTH0_CLIENT_SECRET` (ROPC): a dashboard attempt had left a wrong value in Doppler with the old secret still live; fixed via Management API `rotate-secret` using the CLI credentials — old secret invalidated, new one bound to `sender-worker` first, then stored in Doppler `prd`+`dev`, verified by a direct ROPC grant and live `/signin` → 200 with JWT. Sign-in outage window: seconds.
   - ✅ **HMAC `SHARED_SECRET`**: rotated 2026-07-29 per the W05 runbook — `openssl rand -base64 32`, bound back-to-back to `sender-worker` and `api-provisioning-receiver` (same Cloudflare account, so no cross-repo deploy was needed), stored in Doppler `prd`+`dev`. **Verified end-to-end**: `/signin` → JWT → `/send` (`sign_in` event for the test account) → 200 `ok:true`, proving the sender signs and the receiver verifies on the new key.
   - ✅ **`sb_secret_` service keys swapped and old key revoked** (2026-07-29): the new `integrity_provisioning_key` (`sb_secret_BGd7L…`) is bound as `SUPABASE_SERVICE_ROLE_KEY` on `api-gateway`, `sender-worker`, `stripe-webhook`, and `api-provisioning-receiver`; Doppler `prd` synced. The old `service_role_key` (`sb_secret_OBc1n…`) was then deleted via the Management API — **verified**: old key probes 401, new key 200, all four workers healthy, `api-gateway` deep health reports database healthy. Doppler `dev`'s `SUPABASE_SERVICE_ROLE_KEY` deliberately keeps the now-dead old value, so the `dev` config no longer holds any working RLS-bypassing Supabase credential — a material [[CR11]] improvement.
   - ⚠️ **`SUPABASE_ACCESS_TOKEN` slot is broken in both configs**: it holds the now-revoked old `sb_secret_OBc1n…` key (apparently with an embedded newline), not an `sbp_` personal access token — so Doppler-driven `supabase` CLI and Management-API flows fail until a real token is stored. Note the working `sbp_` token from the CLI keychain was **echoed into a session transcript on 2026-07-29** while debugging; mint a replacement at supabase.com/dashboard/account/tokens, store it here, and revoke the exposed one.
   - ⚠️ **Stray live key**: the migration auto-created a "default" secret key (`sb_secret_bgU_b…`) that matches no Doppler slot and is bound nowhere. It is live, unused, unleaked. Revoke it for least-privilege, or adopt it deliberately.
4. ✅ CI and deploy scripts read from Doppler at runtime, not from the file — `doppler.json` was never in a workflow step; confirmed by grepping all `.github/workflows/*.yml` files.

**Local copies (⚠️ treat as live, do not delete yet):** the untracked `doppler.json` at the repo root and `~/.doppler/fallback/`'s cached snapshots hold the pre-rotation credential set — now a mix of dead (legacy Supabase JWTs, old `AUTH0_CLI_SECRET`) and **still-valid** material (old Stripe key until Dashboard revocation, `AUTH0_CLIENT_SECRET`, HMAC `SHARED_SECRET`, and more). They become safe to delete only when step 3 completes; at that point `rm doppler.json` and clearing the fallback cache close out CR01.

**Note for anyone holding a clone:** force-pushing rewrote all commit hashes. Run `git fetch --all && git reset --hard origin/<branch>` on any local clone to sync.

---

<a id="cr02"></a>

### CR02: Worker deploys have no dev/prod separation — `npm run deploy` overwrites production

**Priority:** P2 (was P1 — the overwrite risk is closed; what remains is dev-environment fidelity) | **Source:** session 2026-07-26, codebase review (Medium)
**Estimated:** 3–5 hours → ~1 hour remaining, plus a cross-repo change

**Context:** Each worker's `deploy` (Doppler `dev`) and `deploy:prd` (Doppler `prd`) both run a plain `wrangler deploy` against a single-name `wrangler.toml` with no `[env]` blocks. Doppler changes only the credentials injected into the deploy process, not the deploy target, so a local `npm run deploy` publishes straight over the worker production uses. For `sender-worker` that is the exact worker the released site calls: `ci.yml:212` builds with no `--dart-define`, so the app falls back to the compile-time default `https://sender-worker.alyshia-b38.workers.dev` (`lib/services/provisioning_service.dart:15`). CLAUDE.md's claim that `npm run deploy` "deploys to dev environment" is false — there is no dev environment.

**Scope:**
1. ~~Add `[env.dev]` blocks with distinct worker names per worker.~~ Done 2026-07-27.
2. ~~Make `deploy` pass `--env dev`.~~ Done 2026-07-27. **`deploy:prd` deliberately still passes no `--env`** — see the design note below.
3. ~~Point the dev Flutter build at the dev worker via `--dart-define`.~~ Documented in CLAUDE.md 2026-07-27.
4. ~~Correct the deployment section of CLAUDE.md.~~ Done 2026-07-27.
5. **Remaining — deploy a dev receiver.** `sender-worker-dev` still binds `RECEIVER` to the production `api-provisioning-receiver`; no dev receiver exists (it lives in the `observability-toolkit` repo). `/send` from a dev deploy reaches the production receiver. Cross-repo.
6. ~~Give `contact-form-dev` its own KV namespace.~~ Done 2026-07-27 — `CONTACT_RATE_LIMIT_KV_DEV` (`5719e569…`), distinct from the production namespace so a dev deploy cannot evict live rate-limit and idempotency keys. A test now asserts dev never shares a namespace with production.
7. ~~Verify by deploying.~~ Done 2026-07-27 — `npm run deploy` was run for real in `workers/sender-worker` and landed on `sender-worker-dev`, not `sender-worker`. All five dev workers deployed; the four production workers were confirmed unmodified afterwards by their `modified_on` timestamps.

**Design note — why production stayed on the top-level config.** The original scope proposed `[env.production]` with `deploy:prd --env production`. That would have been actively harmful: a named environment renames the Worker (`sender-worker` → `sender-worker-production`), orphaning its Durable Object namespaces, routes, and crons, and breaking both the Flutter compile-time default URL and the receiver's service binding. Instead the top-level block **is** production and is untouched; `[env.dev]` is the overlay. The production deploy path is byte-identical to before this change.

**CR02a — resolved.** The routes had already moved to top level in `a0fca5c`, so they now attach on the plain `deploy:prd`. The `QUOTA_DO` binding concern is handled by repeating it under `[env.dev]` (wrangler does not inherit `durable_objects` into named environments) while leaving the top-level binding in place. `migrations` is inheritable and applies to both. The unused `[env.staging]` block was left alone — dead, but harmless, and nothing deploys it.

**Status:** Done and verified live (2026-07-27) — `npm run deploy` can no longer overwrite a production worker, enforced by `workers/lib/deploy-environments.test.ts` (31 tests, mutation-verified) and confirmed by an actual deploy. Only item 5 remains (dev receiver, cross-repo).

**Read [[CR11]] before treating the dev workers as an environment.** The structural split is real, but Doppler's `dev` and `prd` configs hold identical credentials, so there is no data isolation behind it. The dev workers were deployed without secrets on purpose.

---

<a id="cr03"></a>

### CR03: Auth rate limiting is per-isolate only — `RATE_LIMIT_KV` namespace was never created

**Priority:** P2 | **Source:** session 2026-07-26, verifying the review's remediation pass
**Estimated:** 15 minutes (one `wrangler` command + two IDs)

> **Correction (2026-07-27).** This entry previously read "the limiter is inert" and "**fails open**", citing `utils.ts:86` (`if (!env.RATE_LIMIT_KV) return { allowed: true }`). That was a misreading of the early return, and it was wrong: the in-memory tier above line 86 has already counted the request and denies at the limit, so that line skips only the KV tier. Tests at `utils.test.ts` have proved 429-without-KV since `38b2878`. The item is real but much smaller than described, and has been repriced P1 → P2.

**Context:** `checkAuthRateLimit()` in `workers/sender-worker/src/utils.ts` enforces `AUTH_RATE_LIMIT_MAX` (10 per 600s) per IP on `/signup` and `/signin`, returning 429 with `Retry-After`. It counts in memory first and always enforces on that count; `RATE_LIMIT_KV` adds an authoritative count shared across isolates and colos.

The remaining gap is **accuracy, not absence**. In-memory state is per isolate, so an attacker who spreads attempts across colos, or who waits out isolate recycling, gets more than 10 attempts per window in aggregate. A single-connection brute force is still stopped. The `[[kv_namespaces]]` block in `wrangler.toml` is commented out because placeholder IDs break the deploy (`a392cd6`).

**Scope:**
1. ~~Make the degraded mode observable~~ — done 2026-07-27: warns once per isolate when the binding is absent, and the misleading "fail-open-looking" early return is documented and pinned by tests.
2. `wrangler kv namespace create RATE_LIMIT_KV` and `wrangler kv namespace create RATE_LIMIT_KV --preview`.
3. Uncomment the `[[kv_namespaces]]` block in `workers/sender-worker/wrangler.toml` and fill in both IDs.
4. Deploy and confirm a burst returns 429. **Blocked on [[CR02]]** — `npm run deploy` currently publishes over the worker production uses, so there is no safe way to test this deploy first.

**Status:** ✅ Done (2026-07-27) — namespaces created and bound. Production `sender-worker` binds `AUTH_RATE_LIMIT_KV` (`766332ec…`); `sender-worker-dev` binds its own `dev-RATE_LIMIT_KV` (`46a717cd…`). Titled `AUTH_RATE_LIMIT_KV` rather than `RATE_LIMIT_KV` because contact-form already owned that title — the two workers must not share a namespace. The binding reaches production on the next `deploy:prd`; `sender-worker-dev` is deployed and healthy with it bound.

---

<a id="cr04"></a>

### CR04: Dashboard handoff still passes the JWT in a URL fragment

**Priority:** P2 | **Source:** session 2026-07-26, verifying the review's remediation pass
**Estimated:** 3–4 hours (coordinated with the dashboard app)

**Context:** The review's "JWT accepted and propagated via URLs" finding was marked fixed. The `?jwt=` router entry point is genuinely gone, which removes the login-CSRF deep-link vector. The dashboard redirect moved from `?access_token=` to `#access_token=` (`lib/pages/provision_page.dart:90`), and a fragment is not sent to the server, so proxy/server-log and `Referer` leaks are closed. The token is still in a URL, though: fragments are stored with the browser-history entry — contrary to the comment on that line — and any script on the dashboard origin can read `location.hash`.

**Scope:**
1. Replace the fragment handoff with `postMessage` to the dashboard origin, or a single-use exchange code redeemed for the JWT.
2. Correct the comment at `provision_page.dart:87-89`, which overstates what a fragment protects.
3. Requires a matching change in the dashboard app.

**Status:** Partially done (2026-07-26, commit d632263) — misleading comment corrected in `provision_page.dart:87-91`. Full fix (postMessage / exchange code) requires a coordinated change in the dashboard app.

---

<a id="cr11"></a>

### CR11: Doppler `dev` is not a separate environment

**Priority:** P1 | **Source:** session 2026-07-27, deploying the CR02 dev environments
**Estimated:** ~2 hours once the provisioning decisions are made

**Detector:** `npm run check:env-isolation` — compares credential hashes between the two configs, prints no secret material, exits non-zero while they are shared. **Currently fails 10 of 10.** A green run is the definition of done for this item.

**Context:** `--config dev` and `--config prd` resolve to the same Supabase project (`cfrbahzzklwrnmbtqojl`), the same Auth0 tenant, and the same `SHARED_SECRET`. Anything run against the dev config reads and writes production state. CLAUDE.md's "E2E tests use `--config dev` (isolated from prod)" was false and is now corrected in place.

Facts established while investigating, several of which correct earlier notes in this file:

- **Stripe is not exposed — but this bullet was wrong about why. Corrected 2026-07-27 evening.** It read "`STRIPE_API_KEY` … is `sk_test_…` in both dev and prd". It is not. `prd` holds a **`pk_live_…` publishable key** and `dev` holds an `sk_test_…` secret key, and they belong to **two different Stripe accounts**. The conclusion survives — a publishable key is public by design, so there is no exposure — but the reasoning does not, and the real picture is worse: `STRIPE_SECRET_KEY` (the name the code actually reads) is empty everywhere, so **no Worker can make a server-side Stripe call at all**. See [[CR18]]. The bad reading came from `echo -n` inside POSIX `sh`, which emits the flag literally and shifted the prefix by three characters.
- **The isolation detector covers no Stripe credential.** `SECRETS` in `scripts/check-env-isolation.sh` lists only the Supabase, Auth0, and `SHARED_SECRET` values. A green run says nothing about Stripe. Harmless while the two configs hold different key *types*, but it should not be read as blanket coverage.
- **The `stg` config is empty**, not a third environment — every credential above is unset in it. It is available to repurpose as the dev target.
- **Worker secrets do not come from Doppler.** `wrangler deploy` does not convert ambient env vars into Worker secrets; they are set per worker with `wrangler secret put`. So this item does not by itself mean the deployed workers are misconfigured — it means every *local* and *CI* process using the dev config touches production.
- **The `*-dev` workers have zero secrets bound** (verified via the Workers API) and were deployed that way deliberately. They cannot reach production data. Do not push the current dev values into them: that would create a second production-capable worker, not a dev environment. **One exception since 2026-07-27 evening:** `stripe-webhook-dev` holds `STRIPE_API_KEY` (sandbox `sk_test_`) and `STRIPE_WEBHOOK_SECRET` (test-mode signing secret). Both are sandbox-only and reach no production system, which is exactly why they were safe to bind — and it is still true that no Supabase or Auth0 credential may be pushed to a dev Worker until this item passes.
- **Corrected 2026-07-27 evening: the projects are not both paused.** This read "Both Supabase projects are `INACTIVE` (free-tier pause)". Per the Management API, `cfrbahzzklwrnmbtqojl` ("IntegrityStudio") is **`ACTIVE_HEALTHY`**; the `INACTIVE` one is `kvbcgfttukwciiwieezp` ("atx_movement"), an unrelated project. The org has 2 projects, so a third may still require a plan change — that part of the decision blocking step 1 stands.
- **Read Doppler values with `doppler secrets get --plain`, never `doppler run`.** On 2026-07-27 a `doppler run --config prd` reported a value that `doppler secrets get --config prd --plain` contradicted, and Stripe's API confirmed the latter. `~/.doppler/fallback/` holds cached snapshots and `doppler.json` still sits at the repo root ([[CR01]]), so a silently-served stale snapshot is the likely mechanism. Fingerprint before acting: prefix + length + `shasum | cut -c1-12` reveals a mismatch without printing secret material. The detector script already uses the safe form, so its 10-of-10 result is trustworthy.

**Scope:**
1. **Decide the Supabase boundary.** Either a new project (may need a paid plan — the org already has 2) or a separate schema in `cfrbahzzklwrnmbtqojl` with its own role. A separate schema is cheaper but shares the service-role key, so it does not isolate credentials — only a separate project makes the checker pass on `SUPABASE_SERVICE_ROLE_KEY`.
2. **Create an Auth0 dev tenant** and a matching M2M + ROPC application pair. Not scriptable with the current credentials: the `AUTH0_CLI_*` M2M app is scoped to the existing tenant's Management API, so it cannot create tenants. Dashboard action.
3. **Populate Doppler.** Write the new values into `dev` (or into the empty `stg` config, promoting it to the dev target). Re-run `npm run check:env-isolation` until it passes.
4. **Push the dev secrets to the `*-dev` workers** — only after step 3 passes, never before:
   ```bash
   for s in SUPABASE_URL SUPABASE_SERVICE_ROLE_KEY AUTH0_DOMAIN AUTH0_CLIENT_ID AUTH0_CLIENT_SECRET AUTH0_CLI_ID AUTH0_CLI_SECRET AUTH0_AUDIENCE SHARED_SECRET; do
     doppler secrets get "$s" --project integrity-studio --config dev --plain \
       | npx wrangler secret put "$s" --env dev
   done
   ```
5. **Change `contact-form`'s dev recipient before giving dev a `RESEND_API_KEY`.** `[env.dev.vars]` currently carries the production addresses — `RECIPIENT_EMAIL = hello@integritystudio.ai`, `SENDER_EMAIL = contact@integritystudio.ai` — so the moment dev holds a Resend key, dev test submissions land in the real business inbox. Harmless today only because the key is absent and the worker fails closed without `CSRF_SECRET`.
6. **Verify.** Run a dev signup against `sender-worker-dev` and confirm no row appears in the production `organizations` / `users` tables.
7. **Point the E2E suite at the dev workers** via the `--dart-define` URLs in CLAUDE.md, so the corrected isolation claim becomes true rather than merely accurate.

**Status:** Open — blocked on two owner decisions: whether to pay for a third Supabase project (step 1) and creating the Auth0 dev tenant (step 2), neither of which is scriptable with the credentials available. Everything downstream of those (steps 3–6) is mechanical and the runbook above is complete. The detector and the documentation corrections landed 2026-07-27.

**Update 2026-07-28 — the detector now covers Stripe, and Stripe is the only family that passes (10/13 failing).**

Two findings from probing what the Management APIs can actually do:

- **`POST /v1/projects` is available to the `sbp_` token**, so step 1 is scriptable after all. What it is blocked on is the *spend decision*, not tooling. The account currently holds one active project (`IntegrityStudio`) plus `atx_movement`, which is `INACTIVE` and unrelated.
- **There is a tempting false fix, and the detector now refuses it.** `POST /v1/projects/{ref}/api-keys` mints an `sb_secret_` key carrying `secret_jwt_template {role: service_role}`. Pointing `dev` at a freshly minted key would make `SUPABASE_SERVICE_ROLE_KEY` differ, so the hash table would print `ok (distinct)` — while the key still bypasses RLS on the **production** database. It would also only reach 2 of the 4 Supabase rows: `SUPABASE_URL` derives from the project ref and `SUPABASE_JWT_SECRET` is one-per-project, so neither can differ within a single project. Net effect would be trading a loud accurate failure for a quiet misleading one. `scripts/check-env-isolation.sh` now detects the shared `SUPABASE_URL` and says so explicitly (commit `0bc8f3a`).

The general lesson is the same one [[CR18]] taught with a `pk_live_` key: **distinctness is necessary but never sufficient.** A credential can differ from production's and still authenticate against production.

---

<a id="cr12"></a>

### CR12: Production `api-gateway` and `stripe-webhook` have zero secrets bound and are degraded

> **✅ Largely resolved 2026-07-27 evening — `api-gateway` is healthy.** `GET /health` returns `200 {"database":"healthy","durableObjects":"healthy"}`, up from `503 {"database":"degraded"}`, and `/v1/me` correctly answers `401` to an anonymous caller. Three secrets were bound: `SUPABASE_URL`, `SUPABASE_SERVICE_ROLE_KEY`, `SUPABASE_JWT_SECRET`. **This is what makes [[V02]]'s dashboard real** — its endpoints can return data for the first time since 2026-03-31.
>
> **Step 1 answered by evidence: pre-launch, not a regression.** No Stripe webhook endpoint has ever been registered on either account (verified against both the v1 `webhook_endpoints` and v2 `event_destinations` APIs, both returning zero), so `stripe-webhook` was never receiving traffic to lose. Nothing was dropped; nothing was ever sent.
>
> **The premise was also incomplete.** Missing secrets were not the only reason `stripe-webhook` could not work — **its two tables did not exist** ([[CR17]]). Binding secrets alone would have left every event failing on a 404 from PostgREST. Both are now fixed.
>
> **Corrected:** this entry says both Supabase projects are `INACTIVE`. The project that matters, `cfrbahzzklwrnmbtqojl` ("IntegrityStudio"), is **`ACTIVE_HEALTHY`**. The `INACTIVE` one is `kvbcgfttukwciiwieezp` ("atx_movement"), an unrelated project. No resume step is needed.
>
> **What remains:** three secrets that do not exist anywhere to bind — see Status below.

**Priority:** P1 | **Source:** session 2026-07-27, auditing worker secrets while investigating CR11
**Estimated:** 30 minutes to restore, longer to explain

**Context:** Querying the Workers API for the secrets bound to each deployed worker returns **zero** for both `api-gateway` and `stripe-webhook`:

| Worker | Secrets bound | Last deployed |
|---|---|---|
| `sender-worker` | 13 | 2026-07-26 |
| `integrity-studio-contact` | 2 (`CSRF_SECRET`, `RESEND_API_KEY`) | 2026-03-31 |
| **`api-gateway`** | **0** | 2026-03-31 |
| **`stripe-webhook`** | **0** | 2026-03-31 |

`api-gateway`'s own `wrangler.toml` documents five required secrets (`SUPABASE_URL`, `SUPABASE_SERVICE_ROLE_KEY`, `SUPABASE_JWT_SECRET`, `API_KEY_HMAC_SECRET`, `STRIPE_SECRET_KEY`). None are set. Its health endpoint confirms the consequence:

```
GET https://api-gateway.alyshia-b38.workers.dev/health
503 {"database":"degraded","durableObjects":"healthy",...}
```

Verified by two independent sources: the Workers REST API, and `wrangler secret list --name api-gateway` returning `[]` (control: `sender-worker` returns 13 by the same method).

So every authenticated route that touches Supabase — usage, entitlements, orgs, me, api-keys — cannot work, and `stripe-webhook` cannot verify a signature or reach the database, meaning subscription events are dropped rather than dead-lettered. **Correction (2026-07-27):** an earlier version of this entry cited `api.integritystudio.ai/v1/me` returning `401 Missing or invalid Bearer token` as proof the production route was attached and working. That response came from `api-gateway-dev`, not `api-gateway` — see CR13. Production `api-gateway` has **no zone route at all**; the only routes on `integritystudio.ai` are `api.integritystudio.ai/*` → `obtool-api` and `ingest.integritystudio.ai/*` → `obtool-ingest`. It is reachable solely at its `workers.dev` hostname, which is what the Flutter app calls.

**`https://api-gateway.alyshia-b38.workers.dev` is the production gateway**, not a dev URL — and it is the URL the shipped app actually calls. It is the compile-time default for `API_GATEWAY_URL` in both `lib/services/dashboard_service.dart:16` and `lib/services/provisioning_service.dart:22`, and `ci.yml` builds with no `--dart-define`. The dev worker is the separate script `api-gateway-dev`. So the 503 is on the live user path, not a back channel.

*(Correction: an earlier revision argued the two were distinct because `api-gateway-dev`'s `workers.dev` subdomain "is not even enabled — returns Cloudflare 1042". That was propagation lag moments after creation. The subdomain is enabled and now answers 503 with the same body as production. The workers are still demonstrably distinct — separate scripts, and separate Durable Object namespaces: `14813730…` bound to `api-gateway`, `30f146ce…` to `api-gateway-dev` — so the conclusion holds and the DO-isolation claim in the changelog is confirmed. Only that piece of evidence was wrong.)*

`degraded` rather than `unhealthy` is consistent with unset secrets: `checkDatabase` gets `undefined` for `supabaseUrl`, the shared client catches the resulting invalid-URL throw and returns `{ok: false}`, which maps to `degraded`. It does not distinguish this from a reachable-but-failing database. ~~Both causes are present, because both Supabase projects are `INACTIVE` (free-tier pause).~~ **Wrong — corrected 2026-07-27 evening.** Only one cause was present. `cfrbahzzklwrnmbtqojl` is `ACTIVE_HEALTHY`; binding the three secrets alone flipped `/health` to `200 {"database":"healthy"}` with no resume step. The `INACTIVE` project is `kvbcgfttukwciiwieezp` ("atx_movement"), unrelated to this repo.

**Monitoring trap:** `https://api.integritystudio.ai/health` returns **200**, so any uptime check pointed there is permanently green regardless of gateway state. Point step 3 at `https://api-gateway.alyshia-b38.workers.dev/health` instead.

**Corrected 2026-07-27:** this previously attributed that 200 to "the marketing site, nothing to do with the gateway", and said the custom domain "only routes `/v1/*`". Both are wrong. The zone route is `api.integritystudio.ai/*` → `obtool-api` (a wildcard, not `/v1/*`), and the 200 is `obtool-api`'s own health endpoint — the body is `{"status":"ok","d1":"connected"}`, and `obtool-api` is the only worker in the account binding D1. The conclusion stands; the stated cause does not, which matters if someone tries to fix this by looking at the marketing site.

**Scope:**
1. Determine whether this is expected — i.e. whether the platform is pre-launch and these two workers were never configured, or whether secrets were lost in a redeploy. The 2026-03-31 timestamp on both suggests they have been in this state for ~4 months.
2. If live traffic is expected: set the documented secrets (`wrangler secret put --name api-gateway`), resume the Supabase project, and re-check `/health`.
3. Add `/health` to an uptime check so a degraded gateway is not discovered incidentally during a code review four months later.
4. Reconcile with the many changelog entries describing api-gateway quota, usage, and entitlements work — that code has been shipped against a gateway that cannot reach its database.

**Status:** ⚠️ Partial (2026-07-27 evening). Bound and verified:

| Worker | Bound | Health |
|---|---|---|
| `api-gateway` | `SUPABASE_URL`, `SUPABASE_SERVICE_ROLE_KEY`, `SUPABASE_JWT_SECRET` | `200 {"database":"healthy"}` |
| `stripe-webhook` | `SUPABASE_URL`, `SUPABASE_SERVICE_ROLE_KEY` | tables exist; cron can now drain |

**Two of the three cleared on 2026-07-28 when [[CR18]] unblocked; one remains:**

1. 🔴 **`API_KEY_HMAC_SECRET`** (`api-gateway`) — still empty in Doppler. Deliberately **not** generated: API keys are minted by `api-provisioning-receiver` in the `observability-toolkit` repo, which hashes them with its own copy. Inventing a value here would silently fail to verify every existing key. The canonical value must come from that Worker's owner. Until then, API-key-authenticated routes (`/v1/ingest/*`) stay broken while JWT routes work.
2. ✅ **`STRIPE_SECRET_KEY`** (`api-gateway`, and `sender-worker`) — bound 2026-07-28 with the `rk_live_` restricted key. `sender-worker` verified reading it. The billing portal is separately unblocked now that a live Customer Portal configuration exists (`bpc_1Ty2XDAwEfePbhfk9PndBNgW`); a real session was created against it to prove the call works.
3. ✅ **`STRIPE_WEBHOOK_SECRET`** (`stripe-webhook`) — bound 2026-07-28 from live endpoint `we_1Ty29dAwEfePbhfkky1OeqQu`, verified with a wrong-secret control (200 vs 401).

**Updated worker state (2026-07-28):**

| Worker | Bound | Health |
|---|---|---|
| `api-gateway` | `SUPABASE_URL`, `SUPABASE_SERVICE_ROLE_KEY`, `SUPABASE_JWT_SECRET`, `STRIPE_SECRET_KEY` | `/health` 200 |
| `stripe-webhook` | `SUPABASE_URL`, `SUPABASE_SERVICE_ROLE_KEY`, `STRIPE_WEBHOOK_SECRET` | signed probe → `processed:true`; replay → `already_processed` |
| `sender-worker` | 13 existing + `STRIPE_SECRET_KEY` | `/health` 200 |

**A caveat that only surfaced when the secret finally worked.** Binding `STRIPE_WEBHOOK_SECRET` let a signed request reach the handler for the first time, and it returned `"Failed to log processed event"` — a string absent from current source. Production `stripe-webhook` had been running 2026-03-31 code that could not write `webhook_events_log`. Supabase was not at fault; the prd key inserts and deletes against that table cleanly. Redeploying fixed it. **The same check has not been done for `api-gateway`, whose deployed code is also from 2026-03-31 and cannot be redeployed until [[CR13]] step 1.** Assume its behaviour does not match this repo.

One side effect worth watching: `stripe-webhook`'s `*/15` dead-letter cron now has database access, a table to read, and current code. Nothing has confirmed a successful cron run yet — worth checking now that observability is deployed on that Worker.

---

<a id="cr13"></a>

### CR13: Decide what should serve `api.integritystudio.ai/v1/*` (cross-repo ownership)

**Priority:** P2 — **argues for P1; see the deployment-backlog note below** | **Source:** session 2026-07-27, after a dev deploy inadvertently claimed the route
**Estimated:** 30 minutes, once the ownership question is answered

> **This trap is now blocking real fixes, not just sitting there (added 2026-07-28).** Production `api-gateway`'s last **code** deploy was **2026-03-31** — the three 2026-07-28 02:36 entries in its deployment history are Supabase secret bindings, and the 04:18 one is a `STRIPE_SECRET_KEY` binding; none of them shipped code. Every `api-gateway` fix since March is therefore undeployed, and it cannot be deployed until step 1 removes the `routes` key. That backlog includes **`d9ba71a` — "verify bearer token before quota enforcement", a security fix** — plus `d11cf38` (return 5xx on DB errors rather than masking them as empty data, CR05/CR06). Defusing the trap is no longer housekeeping; it is the precondition for shipping a security fix.
>
> `sender-worker` is in better shape but not current either: last code deploy **2026-07-26 04:08**, and `69fbb1b` is not on `origin/main`. It self-corrects on merge, since CI deploys it — `api-gateway` has no such path.

**Context:** `workers/api-gateway/wrangler.toml` declares `routes = [api.integritystudio.ai/v1/*]` at the top level, so a `npm run deploy:prd` from this repo **will claim that hostname path** for `api-gateway`. But the zone's routes are currently:

| Pattern | Worker | Owned by |
|---|---|---|
| `api.integritystudio.ai/*` | `obtool-api` | observability-toolkit |
| `ingest.integritystudio.ai/*` | `obtool-ingest` | observability-toolkit |

`obtool-api` holds the wildcard, and there is no `/v1/*` route, so `/v1/*` requests currently fall through to `obtool-api`. The more specific pattern wins whenever this repo deploys to production.

**Corrected 2026-07-27 — this entry was mis-specified.** It described a contest over the same paths. Reading both deployed scripts (`GET /accounts/:id/workers/scripts/:name`) shows **zero overlap**:

| `obtool-api` serves | `api-gateway` serves |
|---|---|
| `/v1/traces`, `/v1/traces/:id`, `/v1/traces/:id/raw`, `/v1/sessions`, `/v1/sessions/:id`, `/v1/metrics`, `/v1/metrics/histograms`, `/v1/logs`, `/v1/cost`, `/v1/datasets`, `/v1/datasets/:id` | `/v1/me`, `/v1/orgs`, `/v1/orgs/:id/{dashboard,billing-status,usage/summary,entitlements,quota/status,billing-portal,api-keys}`, `/v1/ingest/events`, `/v1/ingest/otel` |

These are complementary halves of one product API — a telemetry data plane and an account/billing control plane. Nobody is claiming anybody's path. The real problem is the **wildcard**: `obtool-api` holds `/*` and auth-gates before routing, so it answers `401` for the gateway's paths rather than passing them on. (That auth-before-routing behaviour is also why external probing proves nothing — `/v1/nonexistent-xyz` returns `401` too.) So the question is not *who wins the hostname* but *how one hostname is split across two complementary workers*, which has a different and larger answer set — see Scope.

**How this surfaced:** a `wrangler deploy --env dev` from this repo created `api.integritystudio.ai/v1/* -> api-gateway-dev` (route inheritance — see CR12's note and the comment in `api-gateway/wrangler.toml`). For roughly 14 hours on 2026-07-27, that path was served by a secret-less dev Worker. The route was deleted and the prior fall-through restored; the config now carries an explicit `routes = []` and a test enforces it.

**Scope — defusing and deciding are separable, and step 1 should not wait:**

1. **Defuse now, independent of the architecture.** Delete the `routes` key from `workers/api-gateway/wrangler.toml`. The shipped app calls `workers.dev` directly, so this costs nothing and permanently removes the landmine. Every option below is easier to reach from a safe state.
2. ~~**Do not route anything to the gateway until [[CR12]] is fixed.** It has zero secrets and answers `{"database":"degraded"}`.~~ **Largely satisfied 2026-07-27 evening** — the gateway now answers `200 {"database":"healthy"}`. Two caveats before reading this as "safe to route": `API_KEY_HMAC_SECRET` is still unbound, so API-key-authenticated paths (`/v1/ingest/*`) would 401; and the danger in step 1 was never the gateway's health, it is that `/v1/*` is **more specific than `obtool-api`'s `/*`** and would capture that Worker's telemetry paths. A healthy gateway makes the trap *more* tempting, not less dangerous.
3. **Then choose a topology:**

| | Approach | Trade-off |
|---|---|---|
| **A** | Concede — gateway stays on `workers.dev` | Zero risk, one-line diff. **Viable only as a temporary defusal, not an end state** — see below |
| **B** | Path-split: `/v1/me`, `/v1/orgs*`, `/v1/ingest/*` as separate routes | Keeps one hostname, but the route list becomes a hand-maintained mirror of a dispatch table in another repo. **Never `/v1/*` here** — that is the trap as currently armed and would swallow all of `obtool-api` |
| **C** | Give the gateway its own branded hostname | Matches the existing per-service convention; one hostname per repo, no cross-repo route coordination. Costs a DNS record, a Flutter default, and doc updates |
| **D** | Single front door — `obtool-api` service-binds unmatched `/v1` paths to `api-gateway` | Best external DX. Requires changes in a repo this one does not own, and couples the two auth models |

4. **`api-gateway` is the customer-facing API** ([[CR16]]), so it needs a real hostname eventually — customers cannot be handed `api-gateway.alyshia-b38.workers.dev` as an integration target, and `docs/api-usage-ingestion.md` already publishes `api.integritystudio.ai` as theirs. That rules **A out as a destination**, though not as today's safe parking spot. It also raises a question this entry cannot answer from the repo: `obtool-ingest` is internal, but **is `obtool-api` internal too?** If both `obtool-*` workers are internal, then the most customer-looking hostname in the account is serving internal telemetry while the actual customer API has none — and the right answer may be to *give `api.integritystudio.ai` to the gateway* and move the obtool stack to an internal name, rather than routing around it.
5. Either way, stop relying on the `workers.dev` hostname as the app's production default (`dashboard_service.dart:16`, `provisioning_service.dart:22`).

**Suggested:** step 1 (delete the `routes` key) immediately and unconditionally — it is safe, reversible, and independent of everything else. Defer the destination until `obtool-api`'s audience is settled, because that answer decides between "gateway takes `api.integritystudio.ai`" and options C/D.

**Status:** ⚠️ Partial — step 1 done (2026-07-29): `routes` key removed from `workers/api-gateway/wrangler.toml`. The trap is defused — `deploy:prd` will no longer claim `api.integritystudio.ai/v1/*`. `api-gateway` is now safe to deploy and [[CR22]]'s billing-portal fix can ship. Hostname-topology decision (steps 2–5: which approach to give the gateway a branded endpoint) still needed.

> ✅ **Resolved 2026-07-29 — step 1 done.** The `routes` key has been removed from `workers/api-gateway/wrangler.toml` (52 deploy-environment tests passing). A `deploy:prd` will no longer declare `api.integritystudio.ai/v1/*` and cannot displace `obtool-api`. The topology question (steps 3–5 — how to give the gateway a real branded hostname) remains open and is deferred until `obtool-api`'s audience is settled.

---

<a id="cr14"></a>

### CR14: Superseded Worker versions stay publicly callable with live secrets

**Priority:** P1 | **Source:** session 2026-07-27, auditing `api-gateway-dev` settings via the Cloudflare API
**Estimated:** 15 minutes to mitigate; the audit of what old versions expose is longer

**Context:** Every Worker in the account has `previews_enabled: true`. Cloudflare then publishes each retained version at `https://<version-id-prefix>-<script>.<subdomain>.workers.dev`, **with the script's current secrets bound**. Superseded code therefore stays live.

Verified, not theoretical:

| URL | Version date | Result |
|---|---|---|
| `6a5b6edf-sender-worker.…workers.dev/health` | 2026-07-26 (current) | `200` |
| `b2c2b878-sender-worker.…workers.dev/health` | **2026-04-20** | **`200` — live** |
| `15f2bcf0-sender-worker.…workers.dev/health` | 2026-04-10 | `404` (past retention) |

The `b2c2b878` version predates this branch's security work: the per-IP auth rate limit (`38b2878`), the signup compensating rollback (`c75592c`), the CORS origin-reflection fix (`66f1825`), and the JWT-in-URL removal (`c55dcff`). It answers requests today with all 13 production secrets bound. **So merging and deploying this branch does not fully retire the vulnerabilities it fixes** — the un-fixed code remains reachable at a parallel URL.

Workers with both secrets and preview URLs enabled:

| Worker | Secrets | Notes |
|---|---|---|
| `sender-worker` | 13 | Auth0 ROPC + M2M, Supabase service-role, HMAC `SHARED_SECRET` |
| `api-provisioning-receiver` | 7 | **Different repo** (`observability-toolkit`) — needs that owner |
| `integrity-studio-contact` | 2 | `CSRF_SECRET`, `RESEND_API_KEY` |

The 8-hex-character version prefix is not a meaningful secret: `wrangler` prints the full version ID on every deploy, so it lands in terminal scrollback and CI logs. This session printed one.

**Scope:**
1. ~~Set `preview_urls = false`~~ — done 2026-07-27 in `sender-worker` and `contact-form` `wrangler.toml`. **Takes effect on their next deploy**, so it is not yet mitigated in production.
2. **Immediate mitigation without a deploy**, per worker:
   ```bash
   doppler run --project integrity-studio --config prd -- sh -c \
     'curl -X POST -H "Authorization: Bearer $CLOUDFLARE_API_TOKEN" \
       -H "Content-Type: application/json" -d "{\"previews_enabled\":false}" \
       "https://api.cloudflare.com/client/v4/accounts/$CLOUDFLARE_ACCOUNT_ID/workers/scripts/sender-worker/subdomain"'
   ```
3. Ask the `observability-toolkit` owner to do the same for `api-provisioning-receiver` (7 secrets, not deployable from here).
4. ~~Decide whether preview URLs are wanted on the `*-dev` workers.~~ Resolved 2026-07-27. **`preview_urls` is an inheritable key** — verified by deploying `sender-worker-dev` and `integrity-studio-contact-dev` after setting it only at the top level, and confirming both flipped to `previews_enabled: false`. So no `[env.dev]` duplicate is needed, and the dev workers are already covered before [[CR11]] step 4 adds secrets. (Contrast with the *non*-inheritable binding keys — the asymmetry is documented in `api-gateway/wrangler.toml`.)
5. Consider whether any retained version predates a *data-handling* change (schema, consent, retention), not just a security fix.

**Status:** ⚠️ Partial (updated 2026-07-29) — closed live on two Workers, config-correct awaiting deploy on two, pre-emptive on the undeployed `bootstrap-worker`, cross-repo one outstanding.

**Closed live:** `api-gateway` and `stripe-webhook` now report `previews_enabled: false` live, applied via the step 2 API call **before** [[CR12]]'s secrets were bound, so those secrets were never exposed on a retained version. A second gap was found and fixed while doing it: **neither `wrangler.toml` set `preview_urls` at all**, and the key defaults to `true`, so the next `deploy:prd` would have silently re-enabled previews. Both configs now set it explicitly, matching `sender-worker` and `contact-form`.

**Gap found and closed in config (2026-07-29):** `bootstrap-worker` was missing `preview_urls = false` despite declaring `SUPABASE_URL`, `SUPABASE_SERVICE_ROLE_KEY`, and `SUPABASE_JWT_SECRET` in its `Env` type. Added to `wrangler.toml` and to the `SECRET_BEARING` assertion in `deploy-environments.test.ts` (commit 85e1a11). **Verified same day: this closes no live exposure, because no production `bootstrap-worker` exists** — `wrangler secret list --name bootstrap-worker` returns "Worker not found"; only `bootstrap-worker-dev` is deployed, with zero secrets bound. The fix is pre-emptive: the first production deploy will ship with previews disabled instead of defaulting them on.

**Still exposed — these hold secrets and still answer on per-version URLs:**

| Worker | Secrets | Fix |
|---|---|---|
| `sender-worker` | 13 | Config already correct; one `deploy:prd`, or the step 2 API call for immediate effect |
| `integrity-studio-contact` | 2 | Same |
| `api-provisioning-receiver` | 7 | **Cross-repo** — needs the `observability-toolkit` owner (step 3) |

The step 2 command applies to any of them by name. Note it must include `"enabled":true` alongside `"previews_enabled":false`, or the Worker's `workers.dev` hostname is switched off — which for `api-gateway` is the hostname the shipped Flutter app calls.

Step 5 (auditing whether any retained version predates a *data-handling* change) is still not done.

---

<a id="cr15"></a>

### CR15: Production `sender-worker` config drift found in the settings audit

**Priority:** P3 | **Source:** session 2026-07-27, auditing `sender-worker-dev` against production
**Estimated:** 20 minutes

Two items, both on the production worker, both surfaced by diffing it against its new dev counterpart.

**1. Workers Logs are not on — config fixed 2026-07-27, reaches production on the next `deploy:prd`.** Production `sender-worker` reports `observability.enabled: false` with `observability.logs.enabled: true`; the dev worker reports `enabled: true` for both. The cause is `wrangler.toml`: the top-level block is

```toml
[observability]
[observability.logs]
enabled = true
```

— `[observability]` declares no `enabled` key, so it deploys as `false`, while `[env.dev.observability]` sets `enabled = true` explicitly and therefore differs. A changelog entry from 2026-04-03 records "Enabled observability logs on sender-worker", which may never have taken effect. This matters beyond tidiness: diagnosing [[CR12]] and confirming [[CR03]]'s rate limiter both depend on being able to read worker logs.

**Confirmed by experiment, not inference.** A scratch deploy of `bootstrap-worker-dev` with `logs.enabled = true` and `traces.enabled = true` but no parent `enabled` reported `observability.enabled: false`; adding `enabled = true` to the parent flipped it to `true`. The child tables alone do nothing. (Experiment reverted and the worker redeployed clean.)

`sender-worker`'s config now sets `enabled = true` on the parent plus `logs` and `traces`, and `sender-worker-dev` verifies as `enabled=True logs=True invocation=True traces=True`. Production still reports `enabled: false` and will until the next `deploy:prd` — which CI runs automatically on merge to `main`.

A second gotcha found the same way: **a named environment's `observability` block replaces the parent's rather than merging.** `[env.dev.observability]` had to repeat `traces` or dev would have silently run without them while production had them. This is a third distinct inheritance behaviour, alongside the non-inheritable bindings and the inheritable `routes`/`triggers`/`preview_urls`.

**2. Four stale secrets remain bound.** Production `sender-worker` has 13 secrets. Diffing all of them against the non-test source (`env.NAME` references across the 7 files in `workers/sender-worker/src/`) shows **four are never read**:

| Secret | Why it is stale |
|---|---|
| `RECEIVER_WORKER_URL` | pre-dates the service-binding migration (`d450ef4`) |
| `PROVISIONING_RECEIVER_WORKER_URL` | same |
| `AUTH0_CLI_AUDIENCE` | not read, and not declared in the `Env` type |
| `SUPABASE_ANON_KEY` | same — the worker uses the service-role key |

**Corrected 2026-07-27:** this item previously said *two*. The count came from grepping only for the names already suspected, rather than diffing the full bound set against source. `AUTH0_CLI_AUDIENCE` and `SUPABASE_ANON_KEY` were missed. All four are inert, but each is another credential inside [[CR01]]'s blast radius, and the two URL secrets imply an HTTP path to the receiver that no longer exists. Remove with:

```bash
npx wrangler secret delete RECEIVER_WORKER_URL --name sender-worker
npx wrangler secret delete PROVISIONING_RECEIVER_WORKER_URL --name sender-worker
npx wrangler secret delete AUTH0_CLI_AUDIENCE --name sender-worker
npx wrangler secret delete SUPABASE_ANON_KEY --name sender-worker
```

**Status:** Open — item 1 is a one-line config change deferred to the next production deploy; item 2 deletes production secrets and was not done unasked.

---

<a id="cr16"></a>

### CR16: Internal and customer-facing OTEL pipelines run separately — convergence is deferred, not pending

> **⚠️ Do not "de-duplicate" these.** An earlier version of this entry read the two pipelines as an accidental fork and instructed removing `handleIngestOtel` from `api-gateway`. That is wrong and would delete the **customer-facing** ingestion path. Corrected 2026-07-27 on owner clarification; see *What this entry got wrong* below.

**Priority:** P3 | **Source:** session 2026-07-27, reading both deployed scripts while analysing [[CR13]]; intent corrected by owner
**Estimated:** no work scheduled — convergence is an eventual goal, explicitly not a current priority

**Context — the split is deliberate.** Two OTEL ingestion pipelines exist because they serve **two different populations**:

| | `obtool-ingest` (observability-toolkit) | `api-gateway` (this repo) |
|---|---|---|
| **Audience** | **Integrity Studio's own internal telemetry** | **customers / end users** |
| Hostname | `ingest.integritystudio.ai/*` — attached | none — no zone route ([[CR13]]) |
| Path | `/v1/:signal` (`traces`, `metrics`, `logs`, `evaluations`), `/v1/ingest/backfill` | `/v1/ingest/otel`, `/v1/ingest/events` |
| Storage | R2 `obtool-telemetry` + D1 `obtool_telemetry_db` | Supabase `usage_events.metadata.spans` (jsonb) |
| Auth | KV `AUTH` | HMAC API key verified against Supabase |
| Dedup | KV `DEDUP` | none |
| Quota | none | per-org via `QUOTA_DO` |
| Wire format | per-signal | `{spans: [...]}`, max 1,000, custom flat `OtelSpanSchema` |

The differing auth, quota, and storage choices follow from the audience split: the customer-facing path needs per-org quota and API-key auth because it is metered and multi-tenant; the internal path does not.

**Eventual direction:** fold `obtool-ingest` into the public-facing `api-gateway`, so one pipeline serves both. This is a stated end-state, **not scheduled work** — it should not be started as cleanup, and the current two-pipeline arrangement is correct until it is.

**What this entry got wrong.** It was originally filed as an accidental duplicate, inferred from the commit trail: `obtool-ingest` and its R2 bucket were created 2026-02-24, and `/v1/ingest/otel` was added a month later on 2026-03-21 by a backlog-implementer session closing an `OTEL-1` item against the payments roadmap's "Telemetry/monitoring setup" checkbox (`1b771e3`, `c40a1c8`). The chronology is accurate; the conclusion drawn from it was not. Later-and-similar is not the same as redundant, and no amount of reading the two repos would have revealed the audience split — that is product intent, and it was not written down anywhere. Recording it here is the fix.

**Note the scope:** `/v1/ingest/events` takes `metric_key` + `quantity` and is usage metering for billing and quota — a third, separate concern from either telemetry pipeline.

**What is actually actionable now** — none of it is the pipeline split:

1. **The documented customer entry point is dead.** `docs/api-usage-ingestion.md` instructs customers to `POST https://api.integritystudio.ai/v1/ingest/events`. No deployed worker serves that path on that hostname — `obtool-api` holds the `/*` wildcard, auth-gates every `/v1/*` path before routing, and does not implement it. Now that this is confirmed customer-facing, it is a **launch blocker rather than a stale doc**: the published integration instructions cannot work.
2. **The customer-facing pipeline has never run in production.** Zero secrets since 2026-03-31 ([[CR12]]) so it cannot reach Supabase, and no zone route ([[CR13]]) so it is unreachable at a branded hostname. Both must resolve before any customer can send a span.
3. **Retention is undefined for customer span volume.** `usage_events.metadata` is `jsonb not null default '{}'`, unpartitioned, with no purge or retention job anywhere in this repo. Internal-only volume would be tolerable; customer volume accumulating indefinitely in a billing ledger table is not. Decide retention before the path is switched on, not after.

**Verified so it is not re-raised:** `rollupDailyBucket` selects only `organization_id, metric_key, quantity, latency_ms` (`aggregation.ts:45`), so stored span payloads are **not** dragged through daily aggregation.

**Status:** Not a defect — design intent, now recorded. No work scheduled on the split itself. Items 1–3 above are real and belong to [[CR12]] and [[CR13]]; this entry exists mainly so the two-pipeline arrangement is not "tidied up" by someone who finds it without the context.

**Update 2026-07-27 evening:** item 2 is half-resolved — `api-gateway` now has database access and answers healthy ([[CR12]]), so the customer-facing pipeline *can* reach Supabase. It still has no zone route ([[CR13]]) and `API_KEY_HMAC_SECRET` is unbound, so `/v1/ingest/otel` cannot authenticate a customer API key. Item 1 (the published entry point returning nothing) and item 3 (undefined retention for customer span volume) are unchanged and still gate launch.

---

<a id="cr17"></a>

### CR17: The Supabase migration ledger recorded migrations that had never run

**Priority:** P2 | **Source:** session 2026-07-27 evening, diffing local migrations against the live schema
**Estimated:** repair done; ~2 hours for the drift detector

**Context:** `supabase_migrations.schema_migrations` listed 8 of 9 local migrations as applied. Only 5 were. The ledger is what `supabase db push` consults, so the missing ones were being **skipped as already-done** on every deploy.

| Migration | Ledger said | Reality |
|---|---|---|
| `20260320010001_phase1_integrate_existing_schema` | applied | **0 of 3 unique objects existed** |
| `20260320010002_add_phase1_update_triggers` | applied | function yes, **4 triggers missing** |
| `20260321000000_add_webhook_dead_letters` | applied | **both tables missing, in every schema** |
| `20260717000000_provisioned_dashboard_viewer_default_role` | absent | partly reflected in data |

**Two root causes, both worth remembering:**

1. **`create policy if not exists` is not valid PostgreSQL.** There is no `IF NOT EXISTS` for `CREATE POLICY`. That statement sits at line 11 of `20260320010001`, so the file aborts there and everything after it silently never ran. The idempotent form is `drop policy if exists` then `create policy`, which is what the file now uses.
2. **Someone ran `supabase migration repair --status applied`.** That command writes the ledger row *including the full `statements` array read from the local file* without executing any of it — which is exactly the fingerprint observed: complete recorded SQL, zero corresponding objects. It is the natural thing to do when a push keeps failing, and it converts a loud failure into a silent one.

**Resolved:** ledger repaired with `migration repair --status reverted`, the invalid syntax fixed, and `db push --include-all` applied all three (the two out-of-order ones need `--include-all` because they sort before the last applied version). `supabase migration list` now reports 10 migrations with zero out of sync.

**Deliberately left divergent:** `20260320010002` still shows applied with 4 objects missing. Its `trigger_update_*_timestamp` triggers duplicate the `update_*_updated_at` triggers `phase1_consolidated` already installed on the same four tables; re-running it would double-fire timestamp maintenance on every row update for no benefit. Recorded here rather than forced into agreement.

**Remaining work:**
1. ✅ **Drift detector shipped.** `scripts/check-migration-drift.sh` parses every migration file for `CREATE TABLE` and `CREATE [OR REPLACE] FUNCTION` statements, queries the live database via the Supabase Management API, and reports any missing objects. Run with `npm run check:migration-drift` (needs `SUPABASE_ACCESS_TOKEN`). A `migration-drift-check` CI job runs it on every push to `main` using `DOPPLER_TOKEN` to supply the credential. Known limits: checks object *presence* only (not column types, constraints, or defaults); cannot verify DML-only migrations; skips triggers because `20260320010002`'s triggers are deliberately absent (see above).
2. **Policy on `migration repair --status applied`**: treat it as a last resort that requires a written reason committed alongside the repair. The command writes a ledger row without executing SQL — it is the correct tool for a migration that has already been applied by other means, and the wrong tool for bypassing a failing push. The two-step safe form is `--status reverted` + fix + `db push`, not `--status applied`. This is documented in `CLAUDE.md` ("Two hard-won rules") but not enforced by any tooling.
3. `20260320010002` — leaving permanently divergent (4 triggers absent, documented above). Deleting the file would remove a record of why the triggers that do exist came from `phase1_consolidated` rather than this file, which is more confusing than the divergence.

**Status:** ✅ Done — schema in sync; drift detector in CI; policy documented.

---

<a id="cr18"></a>

### CR18: Two Stripe accounts, no live secret key, and no way to complete the production webhook

**Priority:** P1 | **Source:** session 2026-07-27 evening, registering a Stripe endpoint
**Estimated:** 15 minutes once the account question is answered

**Context:** the Stripe credentials in Doppler point at **two different accounts**, and neither gives server-side live access.

| Config | `STRIPE_API_KEY` | Kind | Account |
|---|---|---|---|
| `prd` | `pk_live_…` | **publishable** (public by design) | `acct_1SN2e7AwEfePbhfk` |
| `dev` | `sk_test_…` | secret, test mode | `acct_1SN2eDBWbFuvm1I6` |
| `stg` | unset | — | — |

`STRIPE_SECRET_KEY` — the variable the code actually reads (`api-gateway/src/index.ts:21`, `sender-worker/src/types.ts:213`) — is **empty in all three configs**. `STRIPE_API_KEY` is read by no code in this repo at all; it appears only in documentation. So `sender-worker`'s `{"error":"Stripe not configured"}` on checkout is not a missing binding, it is a credential that has never existed.

Different account IDs mean these are not the test and live halves of one account — most likely one is a Stripe Sandbox, which gets its own `acct_` id. ~~That is unconfirmed.~~ **Confirmed 2026-07-28:** `acct_1SN2eDBWbFuvm1I6` reports its display name as **"Integrity Studio sandbox"**, so it is a sandbox of the same business rather than an unrelated account. Its `whsec_` belongs to `we_1Ty14zBWbFuvm1I6rvLOD5OW` (`livemode=false` → `stripe-webhook-dev`), so the dev trio is internally consistent.

**Why this blocks [[CR12]]:** a webhook signing secret is only issued when an endpoint is created, and creating a **live-mode** endpoint requires a live secret key. No live secret key exists, so production `stripe-webhook` cannot be completed. **Stripe has no API for creating secret API keys** — not via the MCP, not via curl, not via the CLI. It is a Dashboard-only action, so this needs a human once.

**Scope:**
1. **Decide which account is production.** If `acct_1SN2eDBWbFuvm1I6` is a Sandbox of `acct_1SN2e7AwEfePbhfk`, the live key comes from the same Dashboard. If they are unrelated accounts, decide which one the product bills through before minting anything.
2. Create an `sk_live_…` (or a restricted key with the needed permissions) in the Dashboard and put it in Doppler `prd` as **`STRIPE_SECRET_KEY`**, the name the code reads.
3. Register a **live-mode** endpoint at production `stripe-webhook`'s URL and bind the returned `secret` as `STRIPE_WEBHOOK_SECRET`. Use `POST /v1/webhook_endpoints` with `api_version` pinned; see [[CR20]] for what to check first.
4. **Rename `prd`'s `STRIPE_API_KEY` to `STRIPE_PUBLISHABLE_KEY`.** The generic name is what caused four documents — and a prior session — to describe it as the key in use.
5. Add the Stripe credentials to `SECRETS` in `scripts/check-env-isolation.sh` so [[CR11]]'s detector actually covers them.

**Already done (test mode only):** endpoint `we_1Ty14zBWbFuvm1I6rvLOD5OW` is registered on the sandbox account against `stripe-webhook-dev`, `api_version` pinned to `2025-09-30.clover`, subscribed to the five events the handlers implement. Its signing secret is bound to that Worker and stored in Doppler `dev`. Signature verification is proven end to end by `workers/stripe-webhook/src/webhook-signature.live.test.ts` (`npm run test:live`).

**Status:** ⚠️ Mostly resolved (2026-07-28) — the blocker cleared when a live key was minted in the Dashboard.

**Resolved:**
- **Production account is `acct_1SN2e7AwEfePbhfk`** ("Integrity Studio", US, `charges_enabled`, `payouts_enabled`). Question in scope item 1 is answered.
- `prd`'s `STRIPE_API_KEY` is now an **`rk_live_` restricted key** on that account — no longer the publishable key the table above describes. Verified against `GET /v1/account` → `200`.
- **`STRIPE_SECRET_KEY` (`prd`) now holds that same restricted key.** Chosen over the full-access `sk_live_` for least privilege; the `sk_live_` remains in Doppler secret history. Write scopes verified without creating objects (probe reaches parameter validation, which is past the permission gate): `checkout/sessions`, `billing_portal/sessions`, `webhook_endpoints`, `customers` — everything this repo exercises.
- **Live-mode endpoint registered:** `we_1Ty29dAwEfePbhfkky1OeqQu` → `https://stripe-webhook.alyshia-b38.workers.dev/webhook`, `api_version=2025-09-30.clover`, the five implemented events, `livemode=true`.
- **`STRIPE_WEBHOOK_SECRET` stored in Doppler `prd` and bound to production `stripe-webhook`.** Proven end to end with a control: correct secret → `200`, wrong secret → `401 Invalid Stripe signature`.

**Still open:**
1. ✅ **Done 2026-07-28** — `dev`'s `STRIPE_SECRET_KEY` had held a **`pk_live_` publishable key belonging to the production account** (a publishable key under a secret-key name, so every server-side call with it failed `Permission denied`). It now holds the sandbox `sk_test_` from `acct_1SN2eDBWbFuvm1I6`. **No value in Doppler `dev` references the production Stripe account any more** — verified by scanning all three `STRIPE_*` values for the production account token. Note this was a *set*, not a revert: that secret had never held the sandbox value (it went empty → `pk_live_`), and Doppler's `configs logs` rollback operates on the whole config, so it would have reverted unrelated secrets too.
2. **`STRIPE_API_KEY` and `STRIPE_SECRET_KEY` in `prd` now hold the identical value.** Scope item 4's rename is superseded: decide whether `STRIPE_API_KEY` should be dropped or repointed at the publishable key, and note that rotating one will not rotate the other.
3. ✅ **Done 2026-07-28** — `scripts/check-env-isolation.sh` now covers `STRIPE_SECRET_KEY`, `STRIPE_API_KEY`, and `STRIPE_WEBHOOK_SECRET` (13 credentials, up from 10).

   It also gained a **second, stronger assertion**, because distinctness alone would not have caught this morning's bug. `dev`'s `STRIPE_SECRET_KEY` was a `pk_live_` key on the *production* account: it differed from prd's value, so the hash table reported `ok (distinct)` while the credential pointed at production. The new section asserts key **mode** from the prefix — dev must be `_test_`, prd must be `_live_`. Mutation-checked against the real historical state (`dev=pk_live_, prd=rk_live_` → `HOLDS A LIVE KEY`), not merely written. `STRIPE_WEBHOOK_SECRET` is excluded from the mode check because `whsec_` carries no mode marker; its isolation rests on the two endpoints living on different accounts.

   The script still fails 10/13 — every Supabase and Auth0 credential plus `SHARED_SECRET` remains shared ([[CR11]]). Stripe is now the only family that passes.
4. ✅ **Done 2026-07-28** — `STRIPE_SECRET_KEY` is bound to both `api-gateway` and `sender-worker`. Bound with `wrangler secret put --name` from the repo root, which updates the binding without deploying code or reading `wrangler.toml`, so [[CR13]]'s route trap was not tripped (routes confirmed unchanged, both Workers `200` on `/health`). `sender-worker` verified to actually read it: `POST /create-checkout-session` moved from `{"error":"Stripe not configured"}` to `{"error":"invalid email"}`. **Note:** the binding propagates over ~seconds, and a stale instance answered `Stripe not configured` once during rollout — sample more than one request when verifying. `api-gateway`'s billing portal needs a JWT and remains unverified end to end, and is blocked behind item 5 regardless.
5. ✅ **Done 2026-07-28** — the live Customer Portal now has a configuration, `bpc_1Ty2XDAwEfePbhfk9PndBNgW` (livemode, default, active; `customer_update`, `invoice_history`, `subscription_cancel`, `subscription_update` all enabled). `GET /v1/billing_portal/configurations` returned **0** earlier the same day, which is why the call would have failed. Verified by actually creating a session — `bps_1Ty2eIAwEfePbhfk3X9kdpGu`, `livemode=true`, bound to that configuration — not by inferring it from the config's existence.

   **Do not wire the portal *login link* into `api-gateway`.** A `https://billing.stripe.com/p/login/…` URL is static and account-wide: the customer types an email and Stripe mails a magic link. `api-gateway` (`src/index.ts:161-168`) instead creates a per-customer session (`/p/session/…`, ~1h expiry) via `handleBillingPortal`, which is correct — the caller is already authenticated by JWT, so a login link would force an identity round-trip the app has already done. The login link is only useful as a standalone customer-facing entry point.

   Still unexercised: the `/v1/orgs/:id/billing-portal` route itself needs a real JWT. The Stripe half is confirmed; the auth half is not.

---

<a id="cr19"></a>

### CR19: `stripe-webhook` silently swallows out-of-order events

**Priority:** P2 | **Source:** session 2026-07-27 evening, reading the handlers against Stripe's webhook documentation
**Estimated:** 1–2 hours

**Context:** Stripe explicitly does not guarantee ordering, and documents the exact sequence you hit — `customer.subscription.created`, `invoice.created`, `invoice.paid` can arrive in any order.

Every handler resolves the org from `stripe_customer_id` and, when the lookup is empty, logs a warning and returns `{ok: true}` — `subscription.ts:32-34` and `:89-91`, `invoice.ts:17-19`, and the metadata equivalent at `checkout.ts:25-27`. Because `claimEvent` runs *before* the handler, the event is already recorded as processed. The Worker then returns 200, so Stripe never retries.

**The failure:** a `customer.subscription.updated` that overtakes the `checkout.session.completed` which would have created the org link is **permanently lost** — no dead-letter row, no retry, no error, and a log line nobody is reading ([[CR15]]). This is a silent revenue-state bug, not a cosmetic one.

**Scope:**
1. Treat "org not found" as a retryable failure so it reaches `webhook_dead_letters` instead of being claimed as done.
2. Alternatively, follow Stripe's own advice and fetch the missing object from the API rather than giving up.
3. Only release the claim on paths that genuinely did nothing — the existing `unclaimEvent` path is the right model.
4. Add a test asserting an unmatched customer does **not** leave a satisfied claim behind.

**Status:** ✅ Done (2026-07-27, commits eaaa199, 9741594) — `subscription.ts` and `invoice.ts` now return `{ ok: false }` when org-not-found, routing the event through the existing `unclaimEvent` + `addDeadLetter` path in `index.ts`. The cron retries up to 5 times, then abandons the row. The **real** retry window is set by the `*/15` cron, not by the backoff: `failDeadLetter` writes delays of 1, 2, 4, and 8 minutes (`2^retry_count`, and the 16-minute interval is never written because `newCount >= maxRetries` abandons first), every one of which is shorter than the cron gap. So the five attempts land on five consecutive ticks — roughly **60–75 minutes** of wall-clock, not the ~16 minutes of nominal backoff. Beyond that the event is `abandoned` and only a manual replay recovers it. `checkout.ts` is unchanged — missing `org_id` in metadata means the checkout is not from this system, so `{ ok: true }` (no-op) remains correct. Four handler tests updated; one integration test added in `index.test.ts` asserting `unclaimEvent` and `addDeadLetter` are called on org-not-found. 151 tests passing.

**Two consequences of the fix, neither blocking:**
- A Stripe customer that legitimately maps to no org — a subscription created by hand in the Dashboard, say — now produces a dead-letter row that retries five times and is then `abandoned`, where it used to be a silent no-op. That is the correct trade (visible beats silent), but it means `webhook_dead_letters` will accumulate rows that no amount of retrying can fix.
- **This fix makes [[CR20]] more load-bearing, not less.** The Worker still returns 200 on the dead-letter path (`index.ts:129`), so recovery depends entirely on the `*/15` cron — which is still unmonitored. Out-of-order events are no longer *lost*, but nothing yet alerts when one is `abandoned`. Option 2 in the scope above (fetch the missing object from the Stripe API instead of deferring to the cron) would remove that dependency and is worth revisiting once [[CR18]] gives the Worker a usable secret key.

---

<a id="cr20"></a>

### CR20: `stripe-webhook` discards Stripe's 3-day retry in favour of a cron

**Priority:** P2 | **Source:** session 2026-07-27 evening, reading the handlers against Stripe's webhook documentation
**Estimated:** 2–3 hours, mostly deciding

**Context:** on handler failure the Worker writes a dead-letter row and returns **200**, with the comment "Return 200 to suppress Stripe's built-in retry (we own the retry schedule)". Stripe would otherwise retry for **three days with exponential backoff** in live mode. That is a real guarantee being traded away for a `*/15` cron.

The trade is only sound if the replacement works, and for four months it did not: the Worker had zero secrets ([[CR12]]) and its dead-letter table did not exist ([[CR17]]). Had an endpoint been registered, a failing event would have been claimed, unclaimed, failed its dead-letter insert, returned 200, and vanished — with Stripe explicitly instructed not to retry.

Both underlying faults are now fixed, so the cron can function. The design question stands.

> **⚠️ Update 2026-07-29 — [[CR21]]'s implementation (commit 8de2122) forecloses scope item 1.** `handleWebhook` now returns 200 *before* the handler runs (`ctx.waitUntil`), so returning 5xx on handler failure is structurally impossible without reverting CR21. The decision has effectively been made by implementation: the cron is the only retry path, which converts item 2 (alerting, [[W04]]) from an option into the sole remaining mitigation.
>
> The same commit also removed the last 5xx anywhere in the failure chain. Previously, if the **dead-letter insert itself** failed after a handler failure, the Worker returned 500 and Stripe retried for three days — the last-resort safety net, and free alerting via Stripe's failing-endpoint emails. Now that path logs `CRITICAL … Manual replay required` and nothing else. This exact failure mode has a precedent: [[CR17]]'s missing `webhook_dead_letters` table made every dead-letter insert fail for four months. A recurrence now loses events behind 200s, observable only in Worker logs. A **full** Supabase outage is still protected — the synchronous `claimEvent` fails first and returns 500 before the 200 is sent. The narrowed window is *partial* DB failure: claim succeeds, handler fails, dead-letter insert fails.

**Scope:**
1. ~~Decide whether owning the retry schedule is worth it. Returning 5xx and letting Stripe retry for three days is simpler, needs no cron, and no table.~~ Foreclosed by [[CR21]] — see update above.
2. Alert on dead-letter depth and on cron failure ([[W04]] step 2 already lists this). **Now mandatory, not optional** — it is the only recovery signal left.
3. Note sandbox retries are only 3 attempts over a few hours, so testing there understates live behaviour.
4. Confirm a successful cron run has actually happened since secrets were bound. Nothing has verified this yet.

**Status:** 🔴 Open — no longer a design decision. [[CR21]] committed to the cron; remaining work is monitoring ([[W04]]) and verifying the cron actually runs.

---

<a id="cr21"></a>

### CR21: `stripe-webhook` processes synchronously before responding

**Priority:** P3 | **Source:** session 2026-07-27 evening, reading the handlers against Stripe's webhook documentation
**Estimated:** 1 hour

**Context:** Stripe's guidance is to return `2xx` **before** any complex logic, and it warns specifically about spikes when subscriptions renew at the start of a month. `handleWebhook` was doing the full Supabase round trip — claim, handler, and possibly a dead-letter write — before responding.

Severity is limited by the atomic claim: a timeout followed by a Stripe retry hits `already_processed` and returns 200, so it degrades to noise and failed-delivery records rather than double-processing. `ctx.waitUntil()` is the Workers-native fix, and the pattern is already used elsewhere in this codebase (M40's audit-log write).

**Status:** ✅ Done (2026-07-29, commit 8de2122) — handler logic extracted into `processEvent`; `handleWebhook` now atomically claims the event, returns `200 { ok: true, queued: true }` immediately, then runs `ctx.waitUntil(processEvent(...))`. The dead-letter CRITICAL path no longer returns 500 (the response is already sent by then; manual Stripe replay is the only recovery). 151 tests passing.

---

<a id="cr22"></a>

### CR22: The billing-portal API-key 403 is merged but not deployed

**Priority:** P3 | **Source:** session 2026-07-27 late, follow-up to the `handleBillingPortal` auth change
**Estimated:** 15 minutes

**Context:** `handleBillingPortal` (`workers/api-gateway/src/routes/orgs.ts`) now rejects `int_live_…` bearer tokens with `403 "Billing portal requires a user session; API keys are not accepted"` instead of letting them fall through to `resolveJwt` and return an opaque `401`. Typecheck is clean and the worker suite passes 147/147, including a new case in `orgs.test.ts`.

Nothing is deployed. `api-gateway` deploys are manual (see [[CR02]]) and there are dev/prod variants, so the fix reaches production only when someone runs the deploy — and doing that here trips the hazard already recorded at the head of this section: **`deploy:prd` in `workers/api-gateway` must wait for [[CR13]] step 1**, or its `routes` key captures all of `/v1/*` from `obtool-api`. So this is blocked on CR13, not merely unscheduled.

Note the user-visible effect is currently nil either way: the portal cannot work at all until `STRIPE_SECRET_KEY` is bound ([[CR18]], [[CR12]]), and API-key routes are dead while `API_KEY_HMAC_SECRET` is unbound — meaning **no caller can reach the new 403 in production today**. This is a correctness improvement waiting behind the same credential work.

**Status:** ⚠️ Unblocked (2026-07-29) — [[CR13]] step 1 is done; `routes` key removed from `wrangler.toml` and `deploy:prd` is now safe. Code is merged, typecheck is clean, 147/147 tests pass. Needs a manual `cd workers/api-gateway && npm run deploy:prd` to reach production.

---

<a id="cr23"></a>

### CR23: Revoked and expired API keys still get a 401 from the billing-portal route

**Priority:** P3 | **Source:** session 2026-07-27 late, reviewing the CR22 change
**Estimated:** 1 hour, mostly a decision

**Context:** The new 403 only fires for API keys that are *valid*. Every `/v1/orgs/:id/*` request first passes through `preVerifyToken` (`workers/api-gateway/src/lib/helpers.ts`), which HMAC-verifies key-shaped tokens against the database and returns `401` for anything revoked, expired, or unknown. A revoked key therefore never reaches `handleBillingPortal`, so the response to a key-shaped token depends on the key's *state*: valid → `403` "API keys are not accepted", revoked → `401`.

That split is arguably correct — the token genuinely is invalid — but it means a client cannot distinguish "my key is bad" from "keys are the wrong credential for this route" without knowing its own key is good. If a uniform answer is wanted for all key-shaped tokens, the check has to move ahead of the HMAC verification in `preVerifyToken` (or be duplicated there per-route), which is a larger change than the one-route guard in [[CR22]] and touches every org route's auth ordering.

**Scope:** decide whether response shape should key off credential *type* before credential *validity*; if yes, hoist the type check into `preVerifyToken` with a per-route allowlist and re-verify the ordering assumptions in `orgs.test.ts`, `usage.test.ts`, and `ingest.test.ts`.

**Status:** ✅ Resolved by design decision (2026-07-29) — the two-tier split is correct per HTTP semantics. `401` signals an authentication failure (the presented credentials are invalid, regardless of what type they are); `403` signals an authorization failure (the credentials are valid but insufficient for this operation). Hoisting the type check before the HMAC verification would require a per-route allowlist inside `preVerifyToken`, touching every org route's auth ordering — a non-trivial refactor with no user-visible benefit while API-key auth routes are broken ([[CR12]]). No code change. Re-evaluate if a client that cannot distinguish the two cases is reported as a real issue in production.

---

<a id="cr24"></a>

### CR24: Legacy Supabase `anon` + `service_role` JWT keys are still enabled

**Priority:** P2 | **Source:** session 2026-07-28, enumerating `GET /v1/projects/{ref}/api-keys`
**Estimated:** 5 minutes, plus one cross-repo check

**Context:** project `cfrbahzzklwrnmbtqojl` still has the original JWT-format keys active alongside the `sb_*` keys that replaced them. `GET /v1/projects/{ref}/api-keys/legacy` returns `enabled: true`.

Two properties make this worth closing rather than leaving:

1. **The legacy `service_role` JWT bypasses RLS**, exactly like the `sb_secret_` key in use. It is a second, older credential with full read/write on every table — including the three whose RLS was only enabled on 2026-07-27.
2. **It is disclosed in plaintext by the Management API.** `GET /v1/projects/{ref}/api-keys` masks `sb_secret_` values (`sb_secret_OBc1n···`) but returns legacy keys as complete JWTs. Anything that can read that endpoint — any holder of the `sbp_` access token, which includes Doppler `prd` and therefore anyone with the unrotated token from [[CR01]] — can retrieve them in full. **This happened during the session that filed this item: a routine enumeration printed both JWTs into a transcript.**

**Evidence they are unused (checked, not assumed):**
- All four Doppler Supabase values, in both `dev` and `prd`, are the new format (`sb_secret_` / `sb_publishable_`) — none begins `eyJ`.
- No non-test code in this repo reads `SUPABASE_ANON_KEY`; the workers read `SUPABASE_SERVICE_ROLE_KEY`, which holds `sb_secret_OBc1n…`.

**Scope:**
1. Confirm `api-provisioning-receiver` (in `observability-toolkit`) does not use a legacy key. **This repo cannot answer that** — it is the one unchecked consumer.
2. Disable via `PUT /v1/projects/{ref}/api-keys/legacy` with `{"enabled": false}`. Reversible through the same endpoint, so the blast radius of getting step 1 wrong is one API call.
3. Treat the two JWTs as disclosed and rotate if anything turns out to depend on them — disabling is not rotation, and re-enabling would restore the same key material.

**Status:** ✅ Done (2026-07-29) — legacy keys disabled at the project. Verified by probe: the legacy `service_role` JWT authenticated with full RLS bypass at 08:15 UTC and returned `401 Invalid API key` at 08:40; the legacy anon JWT 401s likewise. The step-1 cross-repo check was skipped, mitigated by reversibility (step 2's endpoint re-enables) — `api-provisioning-receiver`'s `/health` returns 200 post-disable, and `api-gateway` reports database healthy on its `sb_secret_` key. Step 3 stands: the two JWTs remain disclosed material; never re-enable them.

---

*Last updated: 2026-03-21 — backlog-implementer + backlog-migrate + auto-error-resolver session: L6/L7/L10/L11/L12/L13 marked done (38c339c); M36 fixed (7d86372); L5 env binding added (5c7a443, 8cdaa09, 306ccfc); 27 items migrated to v1.2; CSP test failure diagnosed and fixed (47b4dc3); L16 + M37 migrated to v1.2 changelog (2 completed items). Test Status: ✅ ALL 2631 TESTS PASSING. Remaining: T25, T28, V02-Remaining, M34, M38, M39 (6 deferred/design-decision items). Score: 9/10.*

*Backlog-implementer continuation (2026-03-21): L16 refactored (AppDecorations.card() 5786939, PASS); M34 fixed with soft-delete + active-only filter (33aa1a2, cf5059c, PASS); M37 verified done (no new commits). Test Status: ✅ 61 stripe-webhook tests passing. Remaining open items: 4 (T25, T28, M38, M39 require design decisions). Items completed: 2 (L16, M34). Score: 9/10.*

*Backlog-implementer session (2026-03-21): H3 DB filter fix (b2d23fe, PASS); H4 stripe_customer_id validation (162983d, PASS); M40 audit log waitUntil (8f999e6, PASS); M41 APP_URL env escalation (826d2f3, PASS); M42 503 retry + test fix (8b6120f, 51f8ad8, PASS); L20 error sanitization (32ee699, PASS); L21 insert call count assertion (32ee699, PASS); L22 billing_admin audit log count (user-applied); L23 sanitize read endpoint errors + fetchOrgList (15da535, c586ee8, 2ece18a, PASS). Test Status: ✅ 35 Dart + 17 TS tests passing. Items completed: 9. Remaining: T25, T28, M18 (design decisions / external deps). Score: 9/10.*

*Backlog-implementer session (2026-03-21): OTEL-1 POST /v1/ingest/otel implemented — OtelSpanSchema, IngestOtelRequestSchema, handleIngestOtel with API-key auth + quota enforcement + attribute size caps (1b771e3, c40a1c8, PASS); 10 new tests. Payments roadmap "Telemetry/monitoring setup" item DONE. Test Status: ✅ 120 api-gateway tests passing. Items completed: 1. Remaining: T28 (design decision). Score: 9/10.*

*Backlog-implementer session (2026-03-21): L23 rate-limit headers forwarded (e743c68, PASS); L25 OTEL_INGEST_ROUTE exported (2aa30eb, PASS); L24 start_time_ms upper bound refine (32658b9, PASS); L22 makeOpts typed as SupabaseClient|undefined (ce4c563, PASS); final review high finding addressed — applyRateLimitHeaders helper + boundary tests (5e5d2c4). Test Status: ✅ 122 api-gateway tests passing. Items completed: 4 (L22-L25). Remaining: T28 (design decision). Score: 10/10.*

*Code-review remediation session (2026-07-26): recovered and consolidated the 8-area review (43 items / 51 findings), fixed the PostgREST `Prefer` header and the `/signup?tier=Team` routing break, then a backlog pass closed 38 more. Added CR01–CR10 for the remainder: the 5 items never fixed, 2 marked-fixed-but-not-closed (inert rate limiter, JWT still in a URL fragment), and 3 found while converting the api-gateway and stripe-webhook tests to drive a real Supabase client over a stubbed transport. Test Status: ✅ 3,001 Flutter + 984 worker tests passing; zero TypeScript errors across all 7 workers.*

*Backlog-implementer session (2026-07-26): CR01 doppler.json removed from git + .gitignore (88ef77a); CR05 usage/entitlements endpoints return 5xx on DB error (d11cf38); CR06 me.ts splits DB error from 404 (d11cf38); CR04 provision_page.dart comment corrected (d632263); CR07 CLAUDE.md status block refreshed (8d4c8e2); CR08 ~18 dead Array.isArray checks removed (2ada4e9); CR09 handler test fixtures use HTTP-format errors (424bbd2); CR10 fetchPendingDeadLetters null phantom filtered (1a8196a). CR02 (dev/prod separation) and CR03 (RATE_LIMIT_KV) deferred — need live wrangler/CF operations. CR01 steps 2–3 (history scrub + rotation) deferred to maintenance window. CR04 full fix deferred — cross-repo. CR05–CR10 migrated to the 1.3 changelog (*Review Backlog Pass*) and removed from this section. Test Status: ✅ 3,001 Flutter + 984 worker tests passing; zero TypeScript errors across all 7 workers.*
