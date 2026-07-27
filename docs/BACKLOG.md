# Backlog

Open and deferred items only. Completed items are migrated to `docs/changelog/1.0/CHANGELOG.md`, `docs/changelog/1.1/CHANGELOG.md`, `docs/changelog/1.2/CHANGELOG.md`, and `docs/changelog/1.3/CHANGELOG.md`.

**Last Updated:** 2026-07-26 | **Phase:** Codebase review remediation — 40 of 45 review findings fixed; the 5 open items plus 5 issues found during remediation are tracked here as CR01–CR10 (2 × P1 security, 3 × P2, 5 × P3). Prior entry: Provisioning Docs Reconciliation & Payment Processor Security Complete; Payment processor security hardening (V-06, V-18, V-22) + Enterprise Stripe checkout + T28 code portion migrated to v1.3 (5 items); W03 (provisioning docs reconciliation), W02 (receiver CI account-id) + W06 (contact-form env-aware CORS) migrated to v1.3 (2026-06-27); merged root `BACKLOG.md` (Auth0 grant-type blocker + "remove detail field" cleanup) into this file (2026-06-27); remaining deferred items: T28 (design decision), W04-W05 (infrastructure/monitoring). 2026-07-12 doc-staleness pass — W01 closed (won't-do; Zod v4 chosen over Valibot), #77 Chrome-hang re-tested on Flutter 3.44.4 (still blocked), V02 dashboard confirmed complete

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

**v1 release items — ✅ COMPLETE (2026-07-12):**

### V02: Flutter Dashboard UI — ✅ COMPLETE

**Priority:** P1 | **Estimated:** 10–12 hours (delivered — all 7 steps shipped; see Status below)

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

**Status:** Accepted risk for contact form use case.

---

### #30: Multi-Environment CSP Endpoints

**Severity:** LOW (accepted)
**Category:** Infrastructure
**File:** `web/_headers`

Sentry `ingest.sentry.io` endpoint shared across staging and prod. CSP allows only one DSN per environment. Report DSN collision ignored when worker's `ENVIRONMENT` env var is not set (CF free plan limit).

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

**Context:** `sender-worker` has `[observability.logs]` with `invocation_logs = true` (`workers/sender-worker/wrangler.toml`), so logs are captured, but there is **no alerting and no dashboard** for the provisioning path (`sender-worker` → `api-provisioning-receiver`). The setup summary flagged this as "must implement" but it was never tracked as a real item. `api-provisioning-receiver` lives in the `observability-toolkit` repo, so end-to-end provisioning observability spans both repos.

**Scope:**
1. Define the signals that matter: `/send` error rate (esp. 502 "receiver-worker unreachable", 500 `INTERNAL_ERROR`), receiver 401s (signature/replay failures — possible attack or key-rotation drift), provisioning latency, Auth0/Supabase call failures.
2. Stand up a dashboard (Cloudflare Workers Analytics, or route through the existing OTEL pipeline — see `ingest.integritystudio.ai` / `observability-toolkit`) covering sender + receiver.
3. Add alerting on error-rate and 401-spike thresholds (channel/owner TBD).
4. Document the dashboard + alert runbook; cross-link from `docs/api-provisioning.md`.

**Notes / overlap:**
- [[T28]] already calls for a Cloudflare Durable Object metrics dashboard for quota eviction — narrower, but fold into the same dashboard effort if convenient.
- Receiver-side instrumentation belongs in `observability-toolkit`; coordinate across repos.

**Files to touch:**
- `workers/sender-worker/wrangler.toml` (if exporting metrics/OTEL beyond logs)
- `docs/api-provisioning.md` (link runbook)
- `observability-toolkit` (receiver-side spans/metrics)

**Status:** Open — reconciled from setup-summary intentions; needs signal definition + alert-channel decision. See also [[T28]].

---

## W05: Verify & document prod secret durability + rotation cadence under Doppler

**Priority:** P3 | **Source:** session 2026-06-27, reconciled from provisioning setup notes (now consolidated into `docs/provisioning-environment-setup.md`) — open items "Secrets backed up (1Password/Vault) — must implement", "Secret rotation documented (quarterly)"
**Estimated:** 1–2 hours

**Context:** The setup summary's "back up secrets to 1Password/Vault" action predates the move to **Doppler** as the managed secret store (`doppler --project integrity-studio --config dev|prd`, used by every worker's `deploy:prd` script and CI). Doppler is now the system of record for worker secrets, which largely supersedes a manual vault backup. This item reconciles the stale intention rather than implementing 1Password.

**Scope:**
1. Confirm Doppler `integrity-studio/prd` holds the canonical copy of all provisioning secrets (`SHARED_SECRET`, `SIGNING_KEYS`/`ACTIVE_KEY_ID`, `AUTH0_*`, `SUPABASE_*`, `STRIPE_*`) and that Doppler's own retention/backup is acceptable as the durability story.
2. Document whether an additional offline backup (1Password/Vault) is still required by policy, or formally accept Doppler as sufficient.
3. Document the secret-rotation cadence and procedure. **Note:** the rotation *mechanism* is already implemented and documented in code (`SIGNING_KEYS` + `ACTIVE_KEY_ID` + `x-key-id`, procedure in `workers/sender-worker/src/index.ts:150-158`) — this item is the operational policy/cadence, not new code.

**Files to touch:**
- `docs/provisioning-environment-setup.md` (secret durability + rotation cadence)
- `CLAUDE.md` "Secret Rotation" section (confirm/expand)

**Status:** Open — verification + documentation only; key-rotation mechanism already shipped. See also [[W02]] (Doppler-stored `CLOUDFLARE_ACCOUNT_ID`).

---

## W06: Provisioning — nonce store for sub-window replay protection

**Priority:** P3 | **Source:** session 2026-06-27, documented in `docs/api-provisioning.md` (Production Hardening → Remaining) but not previously tracked
**Estimated:** 3–5 hours

**Context:** Replay protection on the `sender-worker` → `api-provisioning-receiver` path is currently timestamp-only: a signed `/inbox` request is accepted if its `x-timestamp` is within the ±5-minute `REPLAY_WINDOW_MS` window and the HMAC signature verifies. A captured request can therefore be replayed within that window. A nonce store (record each request's nonce/signature and reject duplicates) closes that gap. Low urgency — the window is narrow and the signature is constant-time verified — so this is a hardening enhancement, not a fix.

**Scope:**
1. Add a per-request nonce (or reuse the signature) and persist seen values with a TTL ≥ `REPLAY_WINDOW_MS` (Cloudflare KV or a Durable Object on the receiver in `observability-toolkit`).
2. Reject `/inbox` requests whose nonce has already been seen (401, distinct error code).
3. Confirm TTL ≥ replay window so entries can't expire while still replayable.

**Files to touch:**
- `api-provisioning-receiver` (`observability-toolkit` repo, `services/api-provisioning-receiver/`) — verification path
- `workers/sender-worker/src/` — emit nonce header if not reusing the signature
- `docs/api-provisioning.md` (Production Hardening) — move from Remaining to Shipped on completion

**Status:** Open — design decision (KV vs Durable Object; nonce vs signature dedup); receiver-side change lives in the `observability-toolkit` repo. See also [[W04]] (provisioning observability). The 2026-07-26 review raised the same gap against `workers/receiver-worker/src/index.ts:72`; that file is the local stub / test double and is not deployed, so this item remains the only real work — no separate entry was created for it.

---

## Code Review 2026-07-26 (CR01–CR10)

Open items from the 8-area codebase review, plus issues found while remediating it. The 40 findings already fixed are recorded in [`changelog/1.3/CHANGELOG.md`](changelog/1.3/CHANGELOG.md) under *Codebase Review Remediation*; the review's method, provenance, and 3 refuted claims are in [`CODE_REVIEW.md`](../CODE_REVIEW.md). This section is the actionable remainder.

### CR01: `doppler.json` encrypted secrets bundle is committed to the repository

**Priority:** P1 | **Source:** session 2026-07-26, codebase review (Medium)
**Estimated:** 2–4 hours + rotation window

**Context:** `doppler.json` at the repo root is a 37 KB Doppler CLI encrypted secrets snapshot (`4:base64:500000:<salt>-…`), tracked in git since commit `faf0ccc`. Anyone with repo read access holds a permanent offline copy of every worker secret — Auth0 client secrets, the Supabase service-role key, Stripe keys, the HMAC shared secret — decryptable the moment any Doppler token leaks, or brute-forceable offline at leisure. Rotating a leaked token does not retract the copy. This also contradicts the repo's own deployment-safety claim of "no hardcoded secrets".

**Scope:**
1. `git rm --cached doppler.json`; add to `.gitignore`.
2. Scrub it from history (`git filter-repo` or BFG) and force-push; coordinate with anyone holding clones.
3. Rotate every secret the bundle contains — assume the whole set is compromised.
4. Confirm nothing in CI or the deploy scripts reads the file.

**Status:** Open — step 2 rewrites history and step 3 is a live-credential rotation, so both need an owner and a maintenance window. See also [[W05]] (Doppler durability + rotation policy).

---

### CR02: Worker deploys have no dev/prod separation — `npm run deploy` overwrites production

**Priority:** P1 | **Source:** session 2026-07-26, codebase review (Medium)
**Estimated:** 3–5 hours

**Context:** Each worker's `deploy` (Doppler `dev`) and `deploy:prd` (Doppler `prd`) both run a plain `wrangler deploy` against a single-name `wrangler.toml` with no `[env]` blocks. Doppler changes only the credentials injected into the deploy process, not the deploy target, so a local `npm run deploy` publishes straight over the worker production uses. For `sender-worker` that is the exact worker the released site calls: `ci.yml:212` builds with no `--dart-define`, so the app falls back to the compile-time default `https://sender-worker.alyshia-b38.workers.dev` (`lib/services/provisioning_service.dart:15`). CLAUDE.md's claim that `npm run deploy` "deploys to dev environment" is false — there is no dev environment.

**Scope:**
1. Add `[env.dev]` / `[env.production]` blocks with distinct worker names per worker, or separate Cloudflare accounts.
2. Make `deploy` pass `--env dev` and `deploy:prd` pass `--env production`; verify Durable Object bindings and migrations are inherited (see [[CR02a]] note below).
3. Point the dev Flutter build at the dev worker via `--dart-define`.
4. Correct the deployment section of CLAUDE.md.

**CR02a (same change):** `workers/api-gateway/wrangler.toml:5` defines routes only under `[env.production]`, but no deploy script passes `--env`, so those routes are never attached. Conversely `--env production` would drop the top-level `QUOTA_DO` durable-object binding, which named environments do not inherit. Both must be resolved together.

**Status:** Open — infrastructure change affecting every worker; needs a deploy-safety plan before the first `--env` deploy.

---

### CR03: Auth rate limiter is inert — `RATE_LIMIT_KV` namespace was never created

**Priority:** P1 | **Source:** session 2026-07-26, verifying the review's remediation pass
**Estimated:** 30 minutes

**Context:** The review's "no rate limiting on `/signin` and `/signup`" finding was marked fixed, and the limiter exists in `workers/sender-worker/src/utils.ts` — but it is keyed on an optional binding and `utils.ts:86` reads `if (!env.RATE_LIMIT_KV) return { allowed: true }`, so it **fails open**. The `[[kv_namespaces]]` block in `workers/sender-worker/wrangler.toml` is commented out, left as setup instructions. Until the namespace exists, the endpoints have exactly the brute-force exposure the finding described. This is the highest-value item here per minute spent: the code is written and only the binding is missing.

**Scope:**
1. `wrangler kv namespace create RATE_LIMIT_KV` (and `--preview`) for dev and prd.
2. Uncomment the `[[kv_namespaces]]` block and fill in both IDs.
3. Deploy and confirm a burst of requests returns 429.
4. Decide whether failing open remains acceptable once the binding exists, or whether a missing binding should fail closed / alarm.

**Status:** Open — deployment step, no code change required.

---

### CR04: Dashboard handoff still passes the JWT in a URL fragment

**Priority:** P2 | **Source:** session 2026-07-26, verifying the review's remediation pass
**Estimated:** 3–4 hours (coordinated with the dashboard app)

**Context:** The review's "JWT accepted and propagated via URLs" finding was marked fixed. The `?jwt=` router entry point is genuinely gone, which removes the login-CSRF deep-link vector. The dashboard redirect moved from `?access_token=` to `#access_token=` (`lib/pages/provision_page.dart:90`), and a fragment is not sent to the server, so proxy/server-log and `Referer` leaks are closed. The token is still in a URL, though: fragments are stored with the browser-history entry — contrary to the comment on that line — and any script on the dashboard origin can read `location.hash`.

**Scope:**
1. Replace the fragment handoff with `postMessage` to the dashboard origin, or a single-use exchange code redeemed for the JWT.
2. Correct the comment at `provision_page.dart:87-89`, which overstates what a fragment protects.
3. Requires a matching change in the dashboard app.

**Status:** Open — cross-repo; the current state is a real improvement, not a complete fix.

---

### CR05: Usage and entitlements endpoints fail open, reporting a DB outage as valid empty data

**Priority:** P2 | **Source:** session 2026-07-26, found converting api-gateway tests to a real Supabase client
**Estimated:** 1–2 hours

**Context:** `workers/api-gateway/src/routes/usage.ts:107` and `:130` both read `result.ok && Array.isArray(result.data) ? result.data : []` and then return `ok(...)`, so a Supabase 5xx produces **HTTP 200 with an empty payload**. A caller cannot distinguish "Supabase is down" from "no usage this month". The entitlements case is worse: `buildEntitlementMap([])` yields an empty map, so an outage presents as *no features enabled* and any client gating UI on entitlements silently downgrades the account. This was invisible until the tests started returning real failure responses instead of always-`ok` mocks.

**Scope:**
1. Return 5xx when `!result.ok`, reserving the empty payload for a genuine empty result.
2. If a degraded 200 is deliberate for the usage endpoint, add an explicit `degraded: true` flag so callers can tell.
3. Update the tests that currently pin the fail-open behavior.

**Status:** Open — current behavior is pinned by tests, so a change will show in the diff.

---

### CR06: `GET /v1/me` reports a database failure as `404 User not found`

**Priority:** P2 | **Source:** session 2026-07-26, found converting api-gateway tests to a real Supabase client
**Estimated:** 30 minutes

**Context:** `workers/api-gateway/src/routes/me.ts:33` guards with `if (!result.ok || !Array.isArray(result.data) || result.data.length === 0)` and returns `notFound('User not found')`, collapsing a transport/DB error into the same response as a genuine zero-row result. During an outage every authenticated caller is told their account does not exist, which a client may reasonably act on by signing the user out.

**Scope:**
1. Split the branches: 5xx when `!result.ok`, 404 only on zero rows.
2. Update the test that pins the current behavior.

**Status:** Open — small, self-contained.

---

### CR07: CLAUDE.md status block is stale and contradicts the review

**Priority:** P2 | **Source:** session 2026-07-26
**Estimated:** 30 minutes

**Context:** Three claims in CLAUDE.md are no longer true. **Test counts** (line 30) read "~2,726 Flutter tests … ~965 worker tests passing (5 workers + shared lib)"; the suites now stand at 3,001 Flutter and 984 worker tests across 6 workers plus the shared lib. **Known Issues** (line 34) says "None open", while `CODE_REVIEW.md` and this section track open items including two P1 security items. **Deployment** claims a dev/prod split that [[CR02]] shows does not exist.

**Scope:**
1. Refresh the test counts and `Last Updated`.
2. Replace "None open" with a pointer to `docs/BACKLOG.md` and `CODE_REVIEW.md`.
3. Correct the deployment section once [[CR02]] lands, or caveat it now.

**Status:** Open — documentation only; step 3 is best done with [[CR02]].

---

### CR08: Redundant `Array.isArray(result.data)` narrowing at ~20 call sites

**Priority:** P3 | **Source:** session 2026-07-26, follow-on from the `query()` overload
**Estimated:** 1–2 hours

**Context:** `sb.query()` previously declared `T[] | T | null` for every call, so callers had to narrow with `Array.isArray` before using the rows. It now has overloads — a plain select resolves to `T[]`, `single` resolves to `T | null` — so that narrowing is dead at roughly twenty call sites across `api-gateway` (routes and `aggregation.ts`), `bootstrap-worker`, and `lib/api-keys.ts`. They all still compile; the checks are simply unreachable noise, and a few (`orgs.ts:34`, `:52`) silently map "not an array" to "empty", which would mask a real change in the client contract. Same follow-on: `findOrgByStripeCustomerId` in `workers/stripe-webhook/src/supabase.ts` casts `result.data as { id: string } | null`, now only needed for the row shape — passing a type parameter to `query()` would remove it.

**Scope:**
1. Remove the dead `Array.isArray` narrowing where the overload makes it provably redundant.
2. Keep the genuine `length === 0` / null checks.
3. Give `findOrgByStripeCustomerId` a type parameter instead of a cast.

**Status:** Open — mechanical cleanup, no behavior change; best done in one sweep so the diff is easy to read.

---

### CR09: Stripe handler tests assert error strings the admin can never produce

**Priority:** P3 | **Source:** session 2026-07-26, found converting `stripe-webhook/src/supabase.test.ts`
**Estimated:** 1–2 hours

**Context:** `workers/stripe-webhook/src/handlers/*.test.ts` double `SupabaseAdmin` and assert bare error strings such as `'Connection timeout'` and `'Insert failed'`. Every error the real admin returns is `HTTP <status>: <body>`, so those assertions describe a shape production never emits — a handler that formats or matches on error text could be wrong in production while the tests stay green. The doubles themselves are appropriate (`SupabaseAdmin` is a domain port, unlike the REST client), so this is about fixture fidelity, not another conversion.

**Scope:**
1. Change the doubles' error fixtures to the real `HTTP <status>: <body>` form.
2. Check whether any handler branches on error text.

**Status:** Open — test-fidelity gap; `supabase.test.ts` itself now drives a real client and is unaffected.

---

### CR10: `fetchPendingDeadLetters` can return a `[null]` phantom dead letter

**Priority:** P3 | **Source:** session 2026-07-26, found converting `stripe-webhook/src/supabase.test.ts`
**Estimated:** 30 minutes

**Context:** `query()` wraps a non-array body into an array, so a malformed `null` response surfaces as `[null]`, not `[]`, and `fetchPendingDeadLetters` would hand that straight to the retry loop as a dead letter with no fields. The `!Array.isArray(result.data)` guard that appeared to defend against this never fired — `[null]` is itself an array — and was removed as dead code in `41cc928`. Not reachable through PostgREST, which always answers a select with an array, so this is robustness rather than a live bug. The current shape is pinned by the test `'non-array data → returned as the client wraps it, without error'`.

**Scope:**
1. Decide whether the client should return `[]` rather than `[value]` when a select body is not an array, or whether `fetchPendingDeadLetters` should filter non-objects.
2. Update the pinning test to match whichever contract is chosen.

**Status:** Open — theoretical; worth a decision rather than a fix.

---


*Last updated: 2026-03-21 — backlog-implementer + backlog-migrate + auto-error-resolver session: L6/L7/L10/L11/L12/L13 marked done (38c339c); M36 fixed (7d86372); L5 env binding added (5c7a443, 8cdaa09, 306ccfc); 27 items migrated to v1.2; CSP test failure diagnosed and fixed (47b4dc3); L16 + M37 migrated to v1.2 changelog (2 completed items). Test Status: ✅ ALL 2631 TESTS PASSING. Remaining: T25, T28, V02-Remaining, M34, M38, M39 (6 deferred/design-decision items). Score: 9/10.*

*Backlog-implementer continuation (2026-03-21): L16 refactored (AppDecorations.card() 5786939, PASS); M34 fixed with soft-delete + active-only filter (33aa1a2, cf5059c, PASS); M37 verified done (no new commits). Test Status: ✅ 61 stripe-webhook tests passing. Remaining open items: 4 (T25, T28, M38, M39 require design decisions). Items completed: 2 (L16, M34). Score: 9/10.*

*Backlog-implementer session (2026-03-21): H3 DB filter fix (b2d23fe, PASS); H4 stripe_customer_id validation (162983d, PASS); M40 audit log waitUntil (8f999e6, PASS); M41 APP_URL env escalation (826d2f3, PASS); M42 503 retry + test fix (8b6120f, 51f8ad8, PASS); L20 error sanitization (32ee699, PASS); L21 insert call count assertion (32ee699, PASS); L22 billing_admin audit log count (user-applied); L23 sanitize read endpoint errors + fetchOrgList (15da535, c586ee8, 2ece18a, PASS). Test Status: ✅ 35 Dart + 17 TS tests passing. Items completed: 9. Remaining: T25, T28, M18 (design decisions / external deps). Score: 9/10.*

*Backlog-implementer session (2026-03-21): OTEL-1 POST /v1/ingest/otel implemented — OtelSpanSchema, IngestOtelRequestSchema, handleIngestOtel with API-key auth + quota enforcement + attribute size caps (1b771e3, c40a1c8, PASS); 10 new tests. Payments roadmap "Telemetry/monitoring setup" item DONE. Test Status: ✅ 120 api-gateway tests passing. Items completed: 1. Remaining: T28 (design decision). Score: 9/10.*

*Backlog-implementer session (2026-03-21): L23 rate-limit headers forwarded (e743c68, PASS); L25 OTEL_INGEST_ROUTE exported (2aa30eb, PASS); L24 start_time_ms upper bound refine (32658b9, PASS); L22 makeOpts typed as SupabaseClient|undefined (ce4c563, PASS); final review high finding addressed — applyRateLimitHeaders helper + boundary tests (5e5d2c4). Test Status: ✅ 122 api-gateway tests passing. Items completed: 4 (L22-L25). Remaining: T28 (design decision). Score: 10/10.*

*Code-review remediation session (2026-07-26): recovered and consolidated the 8-area review (43 items / 51 findings), fixed the PostgREST `Prefer` header and the `/signup?tier=Team` routing break, then a backlog pass closed 38 more. Added CR01–CR10 for the remainder: the 5 items never fixed, 2 marked-fixed-but-not-closed (inert rate limiter, JWT still in a URL fragment), and 3 found while converting the api-gateway and stripe-webhook tests to drive a real Supabase client over a stubbed transport. Test Status: ✅ 3,001 Flutter + 984 worker tests passing; zero TypeScript errors across all 7 workers.*
