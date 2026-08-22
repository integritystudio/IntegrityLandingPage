# Changelog — Version 1.3

All notable changes to the IntegrityStudio.ai Flutter project and Cloudflare Workers.

> Backfilled 2026-06-27 from git history (`a6f1735`..`9ca1747`). Version 1.2 ended at the HMAC Crypto Consolidation entry; this file captures work from 2026-04-05 onward, including the provisioning service-binding architecture migration.

---

## [2026-04-03] - Zod v4 Migration & Worker Test Infrastructure

### Dependencies

**Zod v4 Across All Workers**
- Bumped `zod` to v4; added `@vitest/coverage-v8`, updated `@cloudflare/vitest-pool-workers`
- Updated shared schemas in `workers/lib/` for v4 API compatibility
- Commits: `7945ea1`, `9fe05f4`

### Auth0 Configuration

**Single `AUTH0_CLIENT_*` Consolidation (interim)**
- Consolidated to a single `AUTH0_CLIENT_*` credential pair for both auth flows
- Corrected Auth0 CLI env var names (`AUTHO_` → `AUTH0_`); fixed `AUTH0_CLI` secret comments
- Enabled observability logs on sender-worker
- Commits: `330b73a`, `27935f3`, `b629302`, `a93318e`
- **Note:** superseded 2026-04-09 by the ROPC/M2M credential split (see below)

### Test Coverage

**Worker Error-Scenario Integration Tests**
- Added comprehensive integration test coverage for worker error scenarios
- Extracted `FetchMock` and shared fixtures into reusable test helpers; added migration guide
- Commits: `6d2ff74`, `79a2fe1`, `262e6cb`, `ec33b7f`

---

## [2026-04-06] - Crypto Helpers, Model Extraction & Sender Refactors

### Shared Crypto

**`arrayBufferToBase64Url` Helper**
- Added base64url encoding helper to the shared `workers/lib/crypto` module
- Replaced inline base64url encoding in contact-form with the shared helper
- receiver-worker switched to `hmacVerify` for signature checks plus a shared `json()` response helper
- Commits: `9fdbaff`, `5ea748e`, `2cb90d8`

### Flutter Models

**Model Extraction from Services**
- Extracted `dashboard_models.dart` and `provisioning_models.dart` from their services into dedicated model files
- Added `freezed`, `json_serializable`, and a lint script
- Commits: `ca37b5d`, `d39b867`

### Sender Worker Refactors

- Parallelized signup operations; fixed strict-mode type errors — `3ed1783`
- Extracted `parseJsonBody` helper and `ErrorCode` type — `1cecf5c`
- Extracted constants and deduplicated Auth0 fetch logic — `7bf5e50`
- Replaced magic org-type and role strings with named constants — `b0cde8b`
- Added `lint:workers` / `test:workers` scripts and sender-worker `tsconfig` — `6d803fe`

### Security

**JWT Malformed-Signature Guard**
- Guarded `base64urlToBytes` against malformed JWT signatures
- Commit: `bd4fc7f`

---

## [2026-04-07] - sign_in Action, Key Rotation & UI Widgets

### Provisioning

**`sign_in` Action**
- Added `sign_in` to `ActionSchema`; forwarded `/signin` to the receiver
- Extracted `forwardToReceiver`; switched to `ActionSchema.enum`
- Commits: `489be38`, `e0618da`

**Key Rotation Support**
- Added `resolveOutboundSigningKey` with `SIGNING_KEYS` / `ACTIVE_KEY_ID` / `x-key-id` rotation support on the sender
- Falls back to `SHARED_SECRET` when no active key configured
- Commit: `e57cd68`

**Domain Normalization**
- sender-worker omits the `org_name` default so the receiver handles domain normalization
- Commit: `bca10fa`

### Auth0 / Supabase Fixes

- Use M2M credentials for the Auth0 Management API; fixed org-membership foreign-key race in signup — `6907474`

### UI

- Extracted `DashboardScaffold` widget; enhanced `StatusBadge` — `d61c7ed`
- Extracted `GradientPageShell` widget and applied it across pages (incl. signup) — `5b679e6`, `0e7b463`

### Tooling

- Added ESM type to workers; bumped vitest to v4 — `2056936`
- Added a `build_runner` step before analyze/build in CI — `5dfea57`
- Ensured submit button visible before tap in signup-flow tests — `f2cbff5`

---

## [2026-04-14] - Auth0 ROPC / M2M Credential Split

**Split `AUTH0_CLIENT_*` into ROPC + M2M Credential Pairs**
- `AUTH0_CLIENT_ID`/`AUTH0_CLIENT_SECRET` — Regular Web App (password grant / ROPC, sign-in)
- `AUTH0_CLI_ID`/`AUTH0_CLI_SECRET` — M2M app (client_credentials → Management API, user creation)
- Replaced receiver-forwarded `sign_in` with **direct Auth0 ROPC** in the sender
- Moved the `json` helper to shared lib; serialized user insert before sign-in
- Updated `wrangler.toml` comments for the split credentials
- Commits: `0865782`, `471641c`, `a51daef`, `a2fbea5`

---

## [2026-04-19] - Receiver Worker Test Hardening (RCV-1..5)

- RCV-1: Export shared types from `index.ts`, import in test — `fe10c0d`
- RCV-2: Rename `mockEnv` → `testEnv` — `3400189`
- RCV-3: Remove 4 redundant content-type assertions — `ce081f8`
- RCV-4: Add replay-window boundary tests with fake timers — `578a32d`
- RCV-5: Assert API-key uniqueness across two calls — `6482a47`

---

## [2026-06-26] - Provisioning Service-Binding Architecture (Major)

### Architecture

**`receiver-worker` → `api-provisioning-receiver` Service Binding**
- The sender now reaches the production receiver `api-provisioning-receiver` (separate `observability-toolkit` repo) via a Cloudflare `[[services]]` binding (`binding = "RECEIVER"`), not an HTTP `RECEIVER_WORKER_URL`
- `workers/receiver-worker/` is now a local stub / test double only — not deployed, nothing binds to it
- Rewrote `test-provisioning-e2e.sh` for the service-binding architecture
- Trimmed stale sections / added scope note in provisioning docs
- Added `sign_in` action to receiver and sender workers
- Commits: `d450ef4`, `b7a4fce`, `bb78f0b`, `ec77bfa`

### Deployment

- Documented worker deployment strategy and Doppler config (`integrity-studio` dev/prd) — `d3f001d`
- Added `deploy:prd` scripts to the remaining workers — `4aaacc0`
- Allowed Cloudflare Pages preview-deploy CORS origins on sender-worker — `c8cff30`

---

## [2026-06-26] - Payment Processor Security Hardening

### Security Hardening

**JWT Compliance & Claim Validation**
- V-06: Added `nbf` (not-before) claim validation with `NBF_CLOCK_SKEW_SECONDS` constant
- V-18: Added `aud` (audience) claim validation; explicit typed fields on `JwtPayload`
- Commit: `3f593b9`

**HTTP Response Headers**
- V-22: Added `X-Content-Type-Options: nosniff` + `Cache-Control: no-store` on all api-gateway and sender-worker responses
- Commit: `30d990f`

**Quota Durable Object Durability**
- T28 (code): Added `blockConcurrencyWhile` cold-start guard; documented durability SLA
- Commit: `6251629`

### Features

**Enterprise Stripe Checkout**
- Enterprise signup now creates Auth0 account + Supabase org; routes to `/checkout`
- Added graceful fallback to `/request_success` when no Stripe price is configured
- Commit: `f14ba4a`

---

## [2026-06-27] - Provisioning Docs Reconciliation (W03)

**Reconcile Stale `receiver-worker` References**
- Rewrote provisioning docs that described the deleted receiver-worker stub as production to the service-binding model (`sender-worker` → `api-provisioning-receiver`)
- Updated: `api-provisioning.md`, `payments-integration-wire.md`, `user-provisioning-workflow.md`, `inter-worker-contract-validation.md`, `PROVISIONING_SETUP_SUMMARY.md`, `PROVISIONING_E2E_RESULTS.md`, `PROVISIONING_MANUAL_TEST.md`, `provisioning-environment-setup.md`
- Marked W03 done; added W04 (monitoring/alerting), W05 (Doppler secret durability), W06 (contact-form env-aware CORS) to the backlog
- Commit: `f76ab28`

---

## [2026-06-27] - Receiver CI Deploy & Contact Form CORS Fixes

### Receiver Deployment (W02)

**Receiver CI Deploy — Account ID Configuration**
- Verified canonical Integrity Studio Cloudflare account id (`b3868dd0fd5c0faa7d98aa325a9c2377`)
- Confirmed `CLOUDFLARE_ACCOUNT_ID` in Doppler `integrity-studio/prd` matches; no divergence
- API deploy step now exports both `CLOUDFLARE_API_TOKEN` and `CLOUDFLARE_ACCOUNT_ID` from Doppler, skipping `/memberships` discovery
- Deploy confirmed green: `api-provisioning-receiver` `modified_on` = `2026-06-27T01:54Z`
- Fixes: `api-provisioning-receiver` CI deploy 400 error on `/memberships`

### Contact Form CORS (W06)

**Contact-Form Worker — Environment-Aware CORS Origins**
- Switched `getCorsHeaders()` from hardcoded `isOriginAllowed()` to `isOriginAllowedWithEnv()` + `getAllowedOrigins()`
- Threading `env` through call sites; prod default unchanged (no `ALLOWED_ORIGINS_JSON` → two prod origins)
- Added env-var support: setting `ALLOWED_ORIGINS_JSON='["http://localhost:8080"]'` in dev Doppler config now allows localhost
- Prod CORS behavior unchanged; disallowed origins still rejected
- Contact-form tests: 74 passing (was 71); 3 env-aware CORS test cases added
- Unblocks localhost dev testing by updating dev Doppler config (no longer requires code changes)
- Corrected `CLAUDE.md` "Known Issues" note

---

## [2026-06-27] - Auth0 Grant-Type Resolution & Sender-Worker Error Response Cleanup

### Auth0 Client Credentials Grant Type — ✅ RESOLVED IN CODE

**Resolution (git history audit, 2026-06-27):** The single-client consolidation was abandoned; the grant-type failure was fixed in code by separating the credential pairs again:
- `6907474` (2026-04-07) — point the Management-API (M2M) call at a dedicated `AUTH0_MANAGER` app that has the `client_credentials` grant; derive the `/api/v2/` audience from `AUTH0_DOMAIN`.
- `0865782` (2026-04-09) — split `AUTH0_CLIENT_*` (ROPC password grant for sign-in) from `AUTH0_CLI_*` (M2M client_credentials for user creation). Current `workers/sender-worker/src/types.ts` Env carries both pairs.

Integration-test coverage for the 7 error scenarios shipped in `6d2ff74` (`workers/sender-worker/src/index.e2e.test.ts`; `workers/sender-worker/src/ERROR_SCENARIO_TESTS.md`).

### Sender-Worker Error Response Cleanup

**Remove "detail" Field from Error Responses (Post-Debug)**
- Removed the debug-only `detail` field from the `handleSignup()` error response (`workers/sender-worker/src/index.ts`)
- Error `code` + `description` mapping retained for API contract stability
- Updated 5 e2e error-mapping tests to assert on `code` and dropped the obsolete truncation test (`src/index.e2e.test.ts`)
- Refreshed `src/ERROR_SCENARIO_TESTS.md`
- 157 sender-worker tests passing

---

## [2026-07-01] - Flutter/Dart Toolchain Bump & Lucide Icon Package Migration

### Toolchain

**Flutter 3.44.4 / Dart 3.12 (CI)**
- Bumped Flutter to 3.44.4 (Dart 3.12) in CI; `freezed ^4.0.0-dev.3` requires Dart >=3.12.0, but Flutter stable 3.41.6 shipped Dart 3.11.4
- Commit: `67a1d90`

### Dependencies

**`lucide_icons` → `lucide_icons_flutter` Migration**
- Replaced the `lucide_icons` package with `lucide_icons_flutter` across 110 files (`lib/config/content`, `lib/pages`, `lib/widgets`, tests)
- Brand icons unavailable in the new package substituted: `LucideIcons.linkedin` → `.briefcase`, `LucideIcons.github` → `.code`
- Commit: `890f794`

### Fixes

- Bundled `cupertino_icons` to silence the web build's icon tree-shaker warning (Cupertino widgets reference the font but it was never a declared dependency) — `92d652b`
- Removed a redundant non-null assertion on an already-promoted type in `containers.dart`, flagged by Dart 3.12's `unnecessary_non_null_assertion` lint — `a2e2b37`

### Tooling

- Updated `.serena/project.yml` and `pubspec.yaml` — `7fdd00d`

---

## [2026-07-12] - Test Refactor & Serena Cleanup

### Refactor

**Dart 3.12 Null-Aware Elements**
- Replaced `if (x != null) 'key': x` / `if (x != null) x!` collection-literal patterns with Dart 3.12's null-aware element syntax (`'key': ?x`, `?x`)
- Applied to `lib/services/analytics.dart`, `lib/services/contact_service.dart`, `lib/widgets/common/info_card.dart`, and 5 test files (`auth_page_test.dart`, `checkout_page_test.dart`, `landing_page_test.dart`, `signup_page_test.dart`, `status_page_test.dart`)
- Commit: `f8993a0`

### Chore

**Stop Tracking `.serena/`**
- Removed `.serena/` (machine-specific config, cache, memories) from version control and added it to `.gitignore` to stop the per-session churn
- Commit: `3071b8c`

---

## [2026-07-12] - Superseded Design-Doc Reconciliation

Design and roadmap proposals whose recommendations have fully shipped were condensed into research records under [`docs/research/`](../research/) (originals removed). The changelog is the durable record; each research doc carries a one-line outcome pointing back here.

- **`docs/research/REFACTOR.md`** (replace custom worker validation with Zod) — **Implemented.** Shared Zod validation layer landed in 1.2 (`[2026-03-20] Shared Validation Layer`: `workers/lib/http/*`, `workers/lib/validation/*`); the Zod v4 migration followed in 1.3 (`[2026-04-03] Zod v4 Migration`).
- **`docs/research/VALIBOT_ANALYSIS.md`** (migrate validation to Valibot) — **Recommendation rejected.** Workers standardized on Zod v4, not Valibot (no `valibot` dependency in any worker). Superseded by the Zod work above.
- **`docs/research/payment-processor-research.md`** (Stripe/Auth0/Supabase B2B billing architecture) — **Implemented** across 1.2 (API provisioning workers) and 1.3 (`[2026-06-26] Provisioning Service-Binding Architecture` and `Payment Processor Security Hardening`).
- **`docs/research/payments-implementation.md`** (V02 dashboard + Stripe Customer Portal) — **Implemented.** See 1.2 `[2026-03-21] V02 Stripe Portal & Dead Letter Architecture` (`POST /v1/orgs/:id/billing-portal`, 7 tests). The doc's "2631+ tests" figure is historical.
- **`docs/research/subscription-updates.md`** (Stripe subscription webhook handler) — **Implemented** in `workers/stripe-webhook/src/handlers/subscription.ts` (`customer.subscription.updated`/`deleted`); billing hardening recorded in 1.3 `[2026-06-26] Payment Processor Security Hardening`.
- **`docs/research/JWT_COMPLIANCE_REVIEW.md`** (JWT `iss`/`nbf`/`aud` validation, remove mutable claims) — **Phase-1 implemented.** Mutable claims removed in 1.2 `M18-V01`; issuer/not-before/audience validation lives in `workers/lib/auth.ts` (see `security/SECURITY_VULNERABILITY_REPORT.md` V-01/V-02). Remaining open item: `email` in the JWT payload (tracked separately).

---

## [2026-07-12] - Dependency & Content-Loading Audit Consolidation

Consolidated and **removed** the point-in-time version/library audits under `docs/reviews/` (all dated 2026-04-02). Their obsolete upgrade targets are captured here for the record; the authoritative current versions live in `pubspec.yaml`.

- **Dependency & package-version audits** (`DEPENDENCIES_STALENESS_REPORT.md`, `PACKAGE_VERSIONS_AUDIT.md`) — recommended upgrades now overtaken: `flutter_stripe 12.4→12.5` (now `^13.0.0`), `go_router 17.1→17.2` (now `^17.0.1`), `freezed ^3.2.5` (now `^4.0.0-dev.3`), `freezed_annotation ^3.1.0` (now `^3.0.0`), `json_serializable 6.13.1` (now `^6.9.0`). `build_runner 2.4.8→2.13.1` was recommended but **not** taken — still `^2.4.8`.
- **Flutter type-safe loading research** (`FLUTTER_LIBRARIES_RESEARCH.md`) — surveyed 12+ YAML/JSON libraries; recommended Freezed for a `content.yaml`/`content_loader.dart` migration. Freezed was adopted project-wide (`^4.0.0-dev.3`; models under `lib/models/`), but the **content-loading migration was not done** — `lib/services/content_loader.dart` remains string-based.
- **Content-loading audit** (`CONTENT_LOADING_AUDIT.md`) — proposed a 3-phase roadmap (schema validation → Freezed content models → retire ContentLoader). **Not executed**; if revived, track as a backlog item.
- `docs/reviews/README.md` (index) removed with the above.

---

## [2026-07-12] - Widget Duplication Cleanup — Campaign Closed & Analysis Consolidated

Consolidated and **removed** the point-in-time widget-duplication analysis (`docs/duplicate-findings.md`, a 2026-03-14 snapshot from `scripts/find_duplication.sh`). The cleanup campaign it tracked is complete; its findings are recorded here and the script remains for future re-runs.

**Reduction (2026-03-09 → 2026-07-12):** duplicate widget pairs 358 → 79; 100%-identical pairs 27 → 0; 90%+ pairs 86 → 0.

**Extracted shared widgets, by phase:**
- **Phase 1 — docs components.** Consolidated the docs component library.
- **Phase 2 — docs page scaffolds (~18 pairs).** `DocsPageScaffold` (commit `93c1099`) + `DocsHeroSection` (commit `8879e7d`; removed 7 duplicate `_HeroSection` classes).
- **Phase 3 — cross-page patterns (~5 pairs).** Merged `_WarningAlert`/`_DangerAlert` (92% pair); extracted `GradientPillBadge` + `MarketingHeroSection` (Phase 3a — eliminated `_CareersHeroSection`/`_ContactHeroSection`/`_HeroBadge`); consolidated `_TimelineCard`/`_StatBadge` into `DocStatCard` (Phase 3b, commit `f10c523`).
- **Phase 4 — cosmetic (closed 2026-07-12).** `BaseActionButtonState` extracted from the three action buttons (`refactor: refactor buttons`, 28 tests pass, analyze clean); trust badges already collapsed into the shared `TrustBadge`; the 7 generic page scaffolds already share `SubPageShell` / `StatusResultPage`.

**Left intentionally un-consolidated:** the residual 70–79% pairs are semantically distinct widgets that merely share `Container`/`Column`/`Text` structure (e.g. `_MethodologyCard` ~ `_TechSection`) — merging them would couple unrelated pages. Re-run `scripts/find_duplication.sh` (construct=widget, min_similarity=0.7) to regenerate the analysis.

---

## [2026-07-12] - Point-in-Time Report Consolidation (Analytics/CORS Debug, TDD Session)

Consolidated and **removed** two dated point-in-time reports; their findings are preserved here.

**`docs/ANALYTICS_DEBUG.md`** (2026-03-20 — Analytics & CORS debug summary):
- Facebook Pixel confirmed working via `connect-src`/`img-src` (XHR + image beacons); the `form-action` broadening was reverted as unnecessary, and `frame-src` kept restricted (no FB social embeds in the codebase).
- `AnalyticsService` (`lib/services/analytics.dart`) `trackPageView`/`trackEvent` verified working.
- Contact-form localhost CORS: since **resolved** — env-aware CORS shipped (W06, 2026-06-27; `ALLOWED_ORIGINS_JSON`).
- **Resolved (S01, verified 2026-07-12):** clickjacking protection is delivered as HTTP response headers via `web/_headers` (Cloudflare Pages, applied to `/*`) — `Content-Security-Policy: frame-ancestors 'self'` + `X-Frame-Options: SAMEORIGIN`. The `<meta>` CSP in `web/index.html` correctly omits `frame-ancestors` (ignored in meta tags).

**`docs/TDD_SESSION_REPORT.md`** (2026-03-20 — TDD coverage for backlog M17/L21/L22, all shipped + tested):
- **M17** — `sanitizeServerError` now pipes through `sanitizeUserInput` (HTML-escaping XSS guard); commit `4554f81`; `test/utils/security_utils_test.dart`.
- **L22** — narrowed the stack-trace heuristic regex so natural-language "at" no longer triggers the generic fallback; commit `4554f81`; 8 tests.
- **L21** — password length constants moved to a shared `PasswordPolicy` (`constants.dart`; min 8 / max 128); commit `e8ab121`; 5 tests.

**Docs merge:** folded `docs/usage-event-pipeline.md` (usage-aggregation architecture) into `docs/api-usage-ingestion.md` as an expanded "Aggregation Pipeline" section, then removed the standalone file — the API reference and its pipeline architecture now live in one doc.

---

## [2026-07-28] - Stripe Production Cutover, CR17/CR19 Closed, Isolation Detector Hardened

The day a live Stripe secret key was minted, which unblocked a chain of items that had all been waiting on the same missing credential ([[CR18]]). Everything below was verified against the live system rather than against config.

### Stripe — production is now wired end to end

- **Production account confirmed as `acct_1SN2e7AwEfePbhfk`** ("Integrity Studio"), settling a question CR18 had recorded as unconfirmed. The second account, `acct_1SN2eDBWbFuvm1I6`, reports its display name as **"Integrity Studio sandbox"** — a sandbox of the same business, not an unrelated account.
- **Live endpoint `we_1Ty29dAwEfePbhfkky1OeqQu`** registered against production `stripe-webhook`, `api_version` pinned to `2025-09-30.clover`, subscribed to exactly the five events the handlers implement.
- **`STRIPE_WEBHOOK_SECRET`** stored in Doppler `prd` and bound. Verified with a control rather than a single happy path: correct secret → `200`, wrong secret → `401 Invalid Stripe signature`.
- **`STRIPE_SECRET_KEY` (`prd`) holds an `rk_live_` restricted key**, chosen over the full-access `sk_live_` for least privilege (the `sk_live_` remains in Doppler history). Write scopes were verified *without creating objects*, by confirming each probe reached parameter validation — which is past the permission gate. Bound to `api-gateway` and `sender-worker`; `sender-worker` verified reading it (`/create-checkout-session` moved from `"Stripe not configured"` to `"invalid email"`).
- **Live Customer Portal configured** (`bpc_1Ty2XDAwEfePbhfk9PndBNgW`). `GET /v1/billing_portal/configurations` had returned 0 earlier the same day, which would have failed every portal call regardless of the key.
- **Doppler `dev` de-pointed from production.** Its `STRIPE_SECRET_KEY` had held a `pk_live_` publishable key belonging to the *production* account — wrong type for the name, so server-side calls failed `Permission denied`, and aimed at prod. Now the sandbox `sk_test_`.

### A four-month-old deploy, found only because the secret finally worked

Binding the signing secret let a signed request reach the handler for the first time, and it answered `"Failed to log processed event"` — **a string absent from current source**. Production `stripe-webhook` had been running 2026-03-31 code that could not write `webhook_events_log`. Supabase was not at fault: the prd key inserts and deletes against that table cleanly. Redeploying fixed it; a signed probe now returns `processed:true` and a replay returns `already_processed`.

The same audit found **`api-gateway`'s deployed code is also from 2026-03-31**, and it cannot be redeployed until [[CR13]] step 1 removes the `routes` key. Its three 2026-07-28 deployment entries are `wrangler secret put` calls — **binding a secret creates a deployment without shipping code**, which is what made the staleness invisible.

### CR17 and CR19 closed

- **CR19** — `subscription.ts` and `invoice.ts` now return `{ ok: false }` on org-not-found, routing out-of-order events through `unclaimEvent` + `addDeadLetter` instead of claiming them as processed. Commits `eaaa199`, `9741594`. The retry window is governed by the `*/15` cron rather than the backoff (every delay is shorter than the cron gap), so five attempts span ~60–75 minutes, not the ~16 of nominal backoff — a figure corrected in `e657dd2`.
- **CR17** — `scripts/check-migration-drift.sh` queries actual object existence via the Management API rather than the ledger, which is the distinction that made CR17 possible in the first place. Wired into CI. Commits `0f9674a`, `9b166ef`.

### Isolation detector: distinctness is necessary but never sufficient

`scripts/check-env-isolation.sh` grew from 10 credentials to 13 and gained two assertions, both motivated by real false-pass paths rather than hypotheticals:

- **Stripe key mode.** This morning's `dev` value differed from prd's, so a hash-only check reported `ok (distinct)` — while being a `pk_live_` key on the production account. The new check reads mode from the key prefix and requires `_test_` in dev, `_live_` in prd. Mutation-checked against the real historical state, not merely written.
- **Supabase project scope.** `POST /v1/projects/{ref}/api-keys` can mint an `sb_secret_` carrying `role: service_role`, which would make `SUPABASE_SERVICE_ROLE_KEY` differ while still bypassing RLS on production. Since `SUPABASE_URL` derives from the project ref and cannot differ within one project, a shared URL now triggers an explicit warning naming the credentials whose hashes are meaningless.

Result: 10/13 failing, all Supabase and Auth0 ([[CR11]]). Stripe is the only family that passes.

### Filed

- **CR24** — legacy Supabase `anon` + `service_role` JWT keys are still enabled and unused. The Management API returns them as **full plaintext JWTs** while masking `sb_secret_` values, and the legacy `service_role` key bypasses RLS. One `PUT` disables them, pending a cross-repo check on `api-provisioning-receiver`.

---

## [2026-07-26] - Codebase Review Remediation (40 findings)

Remediation of the 8-area codebase review of the Flutter app and all Cloudflare Workers. 45 tracked items; the 40 below shipped. The 5 that did not, plus 5 issues found while remediating, are tracked as CR01–CR10 in [`docs/BACKLOG.md`](../../BACKLOG.md). Three further claims from the review were refuted during verification and are recorded in `CODE_REVIEW.md` so they are not re-reported.

### Security & Privacy

**Meta Pixel gated on marketing consent (High)**
- `web/index.html` and `web/blog/index.html` loaded `js/meta-pixel.js` unconditionally in `<head>`, firing `fbq('init')` and `fbq('track','PageView')` for every visitor before the cookie banner rendered. `TrackingWeb.injectFacebookPixel()` was a no-op that only flipped a boolean, so the ConsentManager architecture was entirely bypassed — a GDPR/ePrivacy breach on a site that markets GDPR compliance.
- The unconditional script tags are removed; `injectFacebookPixel()` now injects the script (async) and runs only after marketing consent.
- Commits: `55550f2`, `81d0aa2`

**JWT removed from application URLs (High)**
- `/provision?jwt=…&email=…` was trusted from query parameters with no session binding, allowing an attacker to deep-link a victim into an attacker-controlled session (login-CSRF). That entry point is gone.
- The dashboard handoff moved from `?access_token=` to a `#access_token=` fragment, which is not sent to the server — eliminating proxy/server-log and `Referer` leaks.
- **Partially closed:** a fragment still lands in browser history and is readable via `location.hash`. Tracked as CR04.
- Commits: `c55dcff`

**Per-IP rate limiting on `/signup` and `/signin` (High)**
- Added a KV-backed per-IP limiter for the credential endpoints, which previously forwarded arbitrary credentials to Auth0 ROPC with no throttle, CAPTCHA, or `auth0-forwarded-for` header.
- **Degraded, not inactive:** `RATE_LIMIT_KV` has not been created, so counting is per isolate rather than shared across colos and distributed attempts are undercounted. The limit is still enforced. Tracked as CR03. (An earlier revision of this line said the limiter "fails open" and the endpoints were "unprotected" — that was a misreading of the early return at `utils.ts:86`, corrected 2026-07-27.)
- Commits: `38b2878`, `a392cd6`

**Quota enforced only after authentication (High)**
- `workers/api-gateway/src/index.ts` decremented quota before verifying the bearer token, letting an unauthenticated caller exhaust any org's rate limit and monthly quota. The token is now verified first.
- Commits: `d9ba71a`

**Assorted auth and CORS hardening**
- `verifyJwt` rejects tokens with a missing or non-numeric `exp` instead of treating them as never-expiring (`815d714`).
- `buildCorsHeaders` no longer reflects an arbitrary caller origin into `Access-Control-Allow-Origin`; the allowlist previously gated only the credentials flag (`66f1825`).
- contact-form fails closed when `CSRF_SECRET` is unset, and CRLF from name/organization is stripped before reaching the email `Subject` header (`510f2a1`).
- `ALLOWED_ORIGINS_JSON` shape is validated — a JSON string previously turned the CORS allowlist into a substring match, and a JSON object crashed every request (`d7032fd`).
- API-key create/revoke requires an owner or admin role; any active member, including viewers, could previously mint and revoke org keys (`3f57a8d`).

### Provisioning & Signup

**Signup rollback (High)**
- `handleSignup` created the Auth0 user and Supabase org concurrently in `Promise.all` with no compensating cleanup, so any mid-flow failure orphaned records and every retry failed with "email already registered" — permanently locking that address out of signup.
- Steps are now sequential with `auth0DeleteUser` rollback at each failure point.
- Commits: `c75592c`

**`dedupSlug` collisions**
- `a.b@`, `a-b@`, and `a+b@` normalized to the same org slug, so the second signup hit the unique constraint and failed permanently. Distinct emails now produce distinct slugs.
- Commits: `d7032fd`

**Signup CTAs routed to a real tier (High)**
- The hero, CTA, and services CTAs linked to `/signup?tier=Team`, a tier with no `signup.tiers` entry in content.yaml. `ContentLoader` returns `''` for missing keys, so the main conversion page rendered a blank heading, blank description, no feature list, and an unlabeled submit button; those signups also skipped checkout and took the free `/provision` path. Five call sites were affected, not the three first reported.
- `Team` was the middle tier's name before content.yaml was renamed to `Growth` to match the backend `ApiKeyTierSchema` enum; the hardcoded links were never updated.
- Also fixed a second bug in the same family: the pricing table passed its *display* name into the URL, producing `?tier=Growth`, which was forwarded verbatim to `ProvisioningService.signUp`. The backend `safeParse` of `'Growth'` fails and falls back to `DEFAULT_TIER`, so **paying Growth customers were being provisioned at the free starter tier**.
- Added `SignupTiers` with the canonical keys and a `normalize()` the router applies to the query parameter, so the tier reaching content lookups, checkout routing, and provisioning is always canonical and an unknown value degrades to the default instead of rendering a blank page.
- The stale `Team` name was then renamed to `Growth` everywhere it survived, and the unused `PricingContentVariants` / `ServicesContentVariants` — the dead Dart content the stale name came from — were deleted.
- Commits: `7dada97`, `7227251`, `66a558b`

**Other provisioning fixes**
- `signUp` returns `AuthError` instead of an `AuthSuccess` carrying an empty JWT when a 201 body lacks the token (`8c64233`).
- Sign-in routes to `/dashboard` rather than `/provision`, making the dashboard route family reachable (`03c8317`).
- `handleSignup`/`handleSignIn` guard non-string email and password; the checkout-session handler wraps its Stripe call so a network failure no longer escapes unhandled (`cde2663`, `ecb91eb`).

### Shared Worker Library

**PostgREST `Prefer` header on insert/update (High)**
- `insert()` and `update()` sent `returning=representation` as a query parameter, which PostgREST ignores. `insert()` therefore hard-failed every call — a bodyless 201 was passed to `response.json()`, the `SyntaxError` was swallowed by the catch, and the caller saw `{ ok: false }` after the row had been written. API-key creation returned 500 to the user after successfully writing the key; audit-log, usage-event, and webhook-log writes logged errors on success. `update()` silently returned `null` rows because it only parsed a body on 200 while PostgREST answered 204.
- Both now send `Prefer: return=<value>` and gate body parsing on the same flag.
- Commits: `6a9b664`

**Duplicate-column filters no longer overwritten (High)**
- `serializeFilters` used `searchParams.set`, so a `gte` + `lte` range on one column lost its lower bound and daily/monthly rollups aggregated all history. It now appends.
- Commits: `d3d7594`

**Supabase option schemas reconciled with the client**
- `InsertOptionsSchema`/`UpdateOptionsSchema` described a contract the client did not implement — `returning` was a string enum in the schema and a boolean in the client, and both declared a `select` field the client never supported. The client now consumes those types, `returning` adopts the string form that maps onto the `Prefer` header, and the unimplemented `select` is dropped.
- `query()` gained overloads: a plain select resolves to `T[]`, `single` resolves to `T | null`. This removed two unreachable branches in the Stripe admin (`toVoidResult`'s `?? 'Unknown error'` and a `!Array.isArray` guard that could never fire).
- Commits: `23bf28a`, `41cc928`

### API Gateway & Quota

- Production routes moved to the top-level wrangler config; they lived only under `[env.production]`, which no deploy script targeted, so they were never attached (`a0fca5c`).
- Quota Durable Object flushes state via an alarm instead of a ≤10s lazy save, so counts survive eviction and monthly limits stop under-enforcing (`d7e0872`, `4a962a6`).
- Plan key renamed `free` → `starter` to match `DEFAULT_QUOTAS`, and a `quota_version` bump preserves `monthlyUsed` instead of resetting it mid-month (`dd35ab9`).
- `loadUsageSnapshot` queries `usage_buckets_daily` rather than columns that do not exist on `usage_events`, which had made every snapshot zero (`d8c54b7`).
- bootstrap-worker gained CORS/OPTIONS handling (`ALLOWED_ORIGINS_JSON` was dead config) and returns 404 rather than 500 for unknown routes; `loadOrgContext` no longer crashes on `orgs[0].id` when memberships exist but no org row matches (`3f57a8d`, `dedb5c7`).

### Stripe Webhook

- Idempotency is now an atomic `INSERT … ON CONFLICT DO NOTHING RETURNING` (`claimEvent`), replacing a check-then-act guard where two concurrent deliveries could both execute the handler. `unclaimEvent` removes the log entry when the handler fails so the dead-letter queue can still retry (`2fc79d8`).
- Dead-letter retries are ordered by Stripe event creation time, so a replay can no longer regress billing state (`97551a1`).
- The signature parser accepts multiple `v1` values, so webhooks are no longer rejected during secret rotation; `InvoiceSchema` accepts `subscription: null` instead of dead-lettering every non-subscription invoice (`b5c80e9`).
- A handler failure whose dead-letter insert also fails now returns 500 rather than 200, so Stripe retries instead of the event being lost permanently (`3f57a8d`).

### Flutter UI & Content

- Consent downgrade disables already-initialized analytics instead of leaving trackers running (`3375c00`).
- Cookie banner's analytics toggle defaults to off; a pre-ticked box is not valid consent under GDPR (`5fc47b3`).
- Contact form no longer reports `success: true` before the request runs, and clears the visible fields rather than only the backing state (`5fc47b3`).
- Auth page mode toggle clears the visible password field, not just its state (`5fc47b3`).
- "Go to Sign In" targets `/login`, the route that exists; the status-result spacing loop emits spacers between items rather than all before them; the app-bar CTA uses an in-app route instead of a hardcoded production URL (`5fc47b3`).
- Signup success analytics and the Facebook Lead pixel fire after the request succeeds, not before it is attempted (`5fc47b3`).
- The OAuth code callback has a 15-second watchdog instead of spinning forever with nothing to exchange the code (`dd8e313`).
- `ContentLoader.load()` no longer raises an unhandled async error when it fails with no concurrent waiters (`b3828b4`).
- Resource doc cards point at `/api` and `/compliance`; the unrouted `/docs/api` and `/docs/compliance` links and their stale display text are corrected (`bc6d1af`, `4171eee`).

### Test Infrastructure

**Route and admin tests drive a real Supabase client**
- Every api-gateway route test and the stripe-webhook admin test mocked the Supabase client, so no test could see a bug inside it — which is precisely why the `Prefer` header and duplicate-column filter bugs shipped unnoticed past 132 passing tests.
- Those suites now build a real `createSupabaseClient` and stub `fetch` beneath it, via a shared helper (`workers/lib/test-helpers/supabase-fetch-stub.ts`) that dispatches on `"<METHOD> <table>"` and answers an unstubbed route with a loud 501 rather than a silent success. Assertions moved to the wire: filter serialization, request bodies, `Prefer` headers, and PostgREST's real status codes.
- Both regressions were verified to fail the new tests when reintroduced.
- This removed the last need for `_sbOverride`, a test-only escape hatch declared in five production option types, along with the unused `RequestOptions`/`MachineRequestOptions` interfaces that existed only to carry it.
- api-gateway 132 → 146 tests; stripe-webhook 144 → 150.
- Commits: `1cfee5f`, `79d1cc8`

**Guard tests and repairs**
- `signup_tier_consistency_test.dart` pins the tier contract: every canonical tier has complete signup content, every pricing tier in content.yaml maps to a signup entry, and no Dart file links to a non-canonical tier (`7dada97`).
- The CSP frame-ancestors test inspects `web/_headers` instead of matching an HTML comment in `index.html`, where it would have stayed green if the real protection were deleted (`ab58431`).
- First HTTP-level tests for the shared Supabase client (`6a9b664`).
- Repaired tests left asserting pre-fix behavior, and eight TypeScript errors across bootstrap-worker, contact-form, and the stripe handler doubles (`b79ec16`, `59c47bb`).

**Final state:** 3,001 Flutter tests and 984 worker tests passing; zero TypeScript errors across all seven workers.

---

## [2026-07-26] - Review Backlog Pass (CR01, CR04–CR10)

A follow-up pass over the CR01–CR10 backlog left by the review remediation above. Eight items closed; **CR02 and CR03 remain open**, and CR01 and CR04 are closed only in part — see [`docs/BACKLOG.md`](../../BACKLOG.md) for what is left of each.

### Security & Privacy

**`doppler.json` removed from git tracking (CR01 — partial)**
- The 37 KB Doppler encrypted secrets snapshot had been tracked since `faf0ccc`, giving anyone with repo read access an offline copy of every worker credential. It is now untracked and in `.gitignore`; the local file is untouched, so dev workflows are unaffected.
- **Not closed:** the bundle is still in git history and none of the secrets it contains have been rotated. Removing the file from HEAD does not retract the copies. Tracked as CR01.
- Commit: `88ef77a`

**JWT fragment handoff comment corrected (CR04 — partial)**
- The comment at `provision_page.dart` claimed a URL fragment keeps the token out of browser history. It does not: fragments are stored with the history entry and are readable by any script on the dashboard origin via `location.hash`. The comment now states the actual gap.
- **Not closed:** this changed a comment, not behavior. The token still travels in a URL. The real fix — `postMessage` or a single-use exchange code — needs a coordinated change in the dashboard app. Tracked as CR04.
- Commit: `d632263`

### API Gateway

**Usage, entitlements, and `/v1/me` no longer fail open on a DB error (CR05, CR06)**
- `handleUsageSummary` and `handleOrgEntitlements` collapsed a Supabase 5xx into `HTTP 200` with an empty payload, so a caller could not distinguish an outage from an empty month. The entitlements case was worse: an empty map reads as *no features enabled*, silently downgrading every account for the duration of an outage.
- `GET /v1/me` folded transport failures into `404 User not found`, telling authenticated callers their account did not exist — which a client may reasonably act on by signing the user out.
- All three now return 500 on `!result.ok`, reserving the empty payload for a genuine empty result and 404 for a genuine zero-row lookup.
- Commit: `d11cf38`

### Code Health

**Dead `Array.isArray` narrowing removed (CR08)**
- The `query()` overloads added during the review pass mean a plain select already resolves to `T[]`, making `Array.isArray(result.data)` unreachable at ~19 sites across api-gateway, bootstrap-worker, the shared lib, and stripe-webhook. Two of them (`orgs.ts`) mapped "not an array" to "empty", which would have masked a real change in the client contract.
- `findOrgByStripeCustomerId` now passes a type parameter to `query()` instead of casting `result.data as { id: string } | null`.
- Commits: `2ada4e9`, `168e910`

**`fetchPendingDeadLetters` filters phantom entries (CR10)**
- The client wraps a non-array body into an array, so a malformed `null` select response surfaces as `[null]`, not `[]` — a dead letter with no fields handed straight to the retry loop. Non-object entries are now filtered out. Not reachable through PostgREST, which always answers a select with an array; this is robustness, and the test that pinned `[null]` now pins `[]`.
- Commit: `1a8196a`

### Documentation & Test Fidelity

- CLAUDE.md's status block was stale on three counts: test counts (~2,726/~965 against actual 3,001/984), "Known Issues: None open" while two P1 security items were open, and a documented dev/prod deploy split that does not exist. Counts and known issues are corrected; the deploy command now carries a CR02 caveat rather than a false claim (`8d4c8e2`).
- Stripe handler test doubles returned bare error strings like `'Connection timeout'`, a shape the real `SupabaseAdmin` never emits — every error it returns is `HTTP <status>: <body>`. Fixtures now use the real format. No handler branches on error text (`424bbd2`).

**Final state:** 3,001 Flutter tests and 984 worker tests passing; zero TypeScript errors across all seven workers.

---

## [2026-07-27] - Worker Deploy Separation (CR02)

`npm run deploy` no longer overwrites production.

Every worker's `deploy` and `deploy:prd` ran the same plain `wrangler deploy` against a single-name `wrangler.toml`. Doppler selected which *secrets* were injected, not which *Worker* was written, so a local dev deploy published straight over the live one. For `sender-worker` that is the Worker the released site calls — `ci.yml` builds with no `--dart-define`, so the app falls back to the compile-time default in `lib/services/provisioning_service.dart`.

**The shape of the fix:** the top-level block of each `wrangler.toml` *is* production and is untouched; `[env.dev]` is a separately-named overlay, and only `deploy` passes `--env dev`. The production deploy path is unchanged.

This is deliberately not what CR02 originally proposed. Adding `[env.production]` and pointing `deploy:prd` at it would rename every production Worker (`sender-worker` → `sender-worker-production`), orphaning its Durable Object namespaces, routes, and crons, and breaking both the Flutter default URL and the receiver's service binding.

Per-worker dev targets, with the isolation each one gets:
- `api-gateway-dev` — its own `QUOTA_DO` namespace, so dev traffic cannot consume a production org's quota. No routes, so `api.integritystudio.ai` cannot be pointed at a dev deploy.
- `stripe-webhook-dev` — `crons = []`. Two Workers draining `webhook_dead_letters` against one Supabase project would race over production rows every 15 minutes.
- `integrity-studio-contact-dev` — no KV binding, `ENVIRONMENT=development`. Binding the production namespace would let a dev deploy evict live rate-limit and idempotency keys; unbound, the limiter degrades to in-memory and logs `rate_limit_kv_unavailable`.
- `sender-worker-dev`, `bootstrap-worker-dev`, `receiver-worker-dev`.

**Guarded by `workers/lib/deploy-environments.test.ts`** (25 tests): dev and production names must differ, `deploy` must pass `--env dev`, `deploy:prd` must not pass `--env`, `[env.dev]` must declare no routes, and every non-inheritable top-level key (`durable_objects`, `services`, `vars`, `kv_namespaces`, …) must be repeated under `[env.dev]` — wrangler does not inherit those, so omitting one yields a dev Worker silently missing a binding. Verified by mutation: reverting the deploy script, adding a production route to dev, and dropping the dev DO binding each fail the suite.

**CR02a resolved:** api-gateway's routes reached top level in `a0fca5c` and now attach on `deploy:prd`; the `QUOTA_DO` binding is repeated under `[env.dev]` rather than moved.

**Deployed and verified 2026-07-27.** `npm run deploy` was run for real in `workers/sender-worker` and landed on `sender-worker-dev`; all five dev workers were created, and the four production workers were confirmed unmodified afterwards by their `modified_on` timestamps. `sender-worker-dev` and `stripe-webhook-dev` return healthy; `integrity-studio-contact-dev` returns the same 403 its production counterpart does, so no regression.

**KV namespaces created** (CR03 and CR02 item 6): production `sender-worker` binds `AUTH_RATE_LIMIT_KV`, `sender-worker-dev` binds its own `dev-RATE_LIMIT_KV`, and `integrity-studio-contact-dev` binds `CONTACT_RATE_LIMIT_KV_DEV` rather than the production namespace it would otherwise evict keys from. A test now asserts dev never shares a namespace with production.

**Still open — and the more important finding:** the dev workers have **no data isolation**, because Doppler's `dev` and `prd` configs hold identical Supabase, Auth0, and HMAC credentials (10 of 10, per `npm run check:env-isolation`). Stripe turned out not to be affected — `STRIPE_SECRET_KEY` is empty in both and the key in use is `sk_test_…`. They were deployed *without secrets* on purpose; pushing the `dev` values into them would create a second production-capable worker rather than a dev environment. Tracked as CR11. `sender-worker-dev` also still binds `RECEIVER` to the production receiver (CR02 item 5, cross-repo).

**Final state:** 3,001 Flutter tests and 1,012 worker tests passing; zero TypeScript errors across all seven workers.

---

## [2026-07-27] - Environment Isolation Detector (CR11 partial, CR12 filed)

Investigating CR11 established what the dev/prd boundary actually is, corrected two claims this changelog had wrong, and turned up a production outage nobody had noticed.

**`npm run check:env-isolation`** (`scripts/check-env-isolation.sh`) compares credential digests between the Doppler `dev` and `prd` configs and exits non-zero while they are shared. It prints hashes only, never secret material, so its output is safe to paste into a ticket. **It currently fails 10 of 10** — `SUPABASE_URL`, `SUPABASE_SERVICE_ROLE_KEY`, `SUPABASE_ANON_KEY`, `SUPABASE_JWT_SECRET`, all five `AUTH0_*` credentials, and `SHARED_SECRET` are identical across the two configs. A green run is now the definition of done for CR11, which previously had no way to be verified.

**Corrections to the entries above:**
- **Stripe was never exposed.** The *Worker Deploy Separation* entry said dev and prd share Stripe credentials. `STRIPE_SECRET_KEY` is in fact empty in all three configs. There is no live-key risk. ⚠️ **The rest of this bullet was wrong and is retracted (2026-07-27 evening).** It claimed `STRIPE_API_KEY` is `sk_test_…` in both configs; `prd` holds a `pk_live_…` *publishable* key and `dev` an `sk_test_…` secret key, for two different Stripe accounts. No exposure either way — publishable keys are public by design — but `STRIPE_API_KEY` is read by no code in this repo, so no worker can make a server-side Stripe call. See BACKLOG.md CR18.
- **The `stg` config is empty, not a third environment.** An earlier comparison read its blank values as "differs from prd"; `da39a3ee` is the SHA-1 of the empty string. It is unset, and therefore available to repurpose as the dev target.
- **Worker secrets never came from Doppler.** `wrangler deploy` does not turn ambient env vars into Worker secrets; they are set per worker with `wrangler secret put`. Doppler's role at deploy time is to supply `CLOUDFLARE_API_TOKEN`. CLAUDE.md now says so, with the command to inspect what a worker actually has bound.

**CR12 filed — production `api-gateway` is degraded on the live user path.** Auditing bound secrets showed `api-gateway` and `stripe-webhook` have **zero**, against five documented as required for the gateway — confirmed by both the Workers REST API and `wrangler secret list`. `GET /health` returns `503 {"database":"degraded"}`. The affected host, `api-gateway.alyshia-b38.workers.dev`, is production and is the compile-time default the shipped Flutter app calls, not a back channel. A monitoring trap sits next to it: `api.integritystudio.ai/health` returns 200 from the marketing site, because the custom domain only routes `/v1/*`. Both were last deployed 2026-03-31, so they appear to have been in this state for roughly four months, which means the quota, usage, and entitlements work recorded in this changelog has been shipping against a gateway that cannot reach its database. Not remediated here: setting production secrets is not a change to make unasked, and the right values depend on whether CR11's isolation work lands first.

**Final state:** 3,001 Flutter tests and 1,018 worker tests passing; zero TypeScript errors across all seven workers; `shellcheck` clean.

---

## [2026-07-27] - Route Inheritance Incident (CR13 filed)

**A `wrangler deploy --env dev` from this repo took over a production hostname path for ~14 hours.** Recorded in full because the cause is a wrangler rule that is easy to get backwards, and because the guard test written to prevent exactly this asserted the wrong invariant and passed the whole time.

**What happened.** `api-gateway`'s `[env.dev]` block was written with no `routes` key, on the belief that omitting it meant "no routes". The opposite is true: **`routes` is an inheritable key.** A named environment that omits it inherits the top-level routes. So deploying the dev environment created `api.integritystudio.ai/v1/* -> api-gateway-dev` — the production hostname bound to a Worker with zero secrets. Cloudflare's audit log dates it precisely: `route_create` at `05:26:15`, one second after `script_create api-gateway-dev`.

Blast radius was limited by two accidents rather than by design: the Flutter app calls the `workers.dev` hostname, not the custom domain, and the production `api-gateway` it would otherwise have displaced was already answering 503. `/v1/*` had no dedicated route before, so those requests had been falling through to `obtool-api`.

**Resolution.** The route was deleted, restoring the prior fall-through (verified: `/v1/me` now returns `obtool-api`'s error shape, not the gateway's). `[env.dev]` now carries an explicit `routes = []`, and redeploying `api-gateway-dev` was confirmed not to recreate it.

**The test lesson.** `deploy-environments.test.ts` asserted `[env.dev]` had **no** `routes` key — the precise condition that causes the bug — and passed while production was misrouted. It now requires an explicit `routes = []` whenever the top level declares routes, and mutation-testing confirms removing the key fails the suite. The general trap:

> Bindings (`durable_objects`, `services`, `vars`, `kv_namespaces`, …) are **not** inherited and must be repeated in a named environment. `routes` and `triggers` **are** inherited and must be explicitly emptied. The two rules point in opposite directions.

The `crons = []` written for `stripe-webhook-dev` was correct for the same reason, and verified: `stripe-webhook-dev` has `schedules: []` while production retains its `*/15` cron.

**CR13 filed.** `api-gateway/wrangler.toml` declares `api.integritystudio.ai/v1/*`, so a `deploy:prd` from this repo will claim that path — but `obtool-api`, owned by the observability-toolkit repo, holds `api.integritystudio.ai/*`. Two repos believe they own paths on the same hostname, and no one has decided which is right. Also corrected in CR12: its claim that the production route "is attached and the script runs" was evidence from `api-gateway-dev`. Production `api-gateway` has **no zone route at all**.

**Final state:** 3,001 Flutter tests and 1,019 worker tests passing (lib 436); zero routes point at any `*-dev` Worker.

---

## [2026-07-27] - Worker Settings Audit (CR14 filed)

A Cloudflare API audit of `api-gateway-dev`'s settings, run to confirm nothing else had been attached unnoticed. Two results, one reassuring and one not.

**Confirmed: Durable Object isolation is real.** The dev Worker has its own namespace — `14813730…` bound to `api-gateway`, `30f146ce…` to `api-gateway-dev` — so the claim in *Worker Deploy Separation* that dev traffic cannot consume a production org's quota holds. Settings are otherwise identical to production: same single `QUOTA_DO` binding, same compatibility date, no tail consumers, no logpush, no crons, zero secrets.

**CR14 — superseded versions stay publicly callable with live secrets.** Every Worker in the account has `previews_enabled: true`, which publishes each retained version at `<version-prefix>-<script>.<subdomain>.workers.dev` **with the current secrets bound**. Verified by request, not inferred:

| Version | Date | Result |
|---|---|---|
| `6a5b6edf` | 2026-07-26 (current) | `200` |
| `b2c2b878` | **2026-04-20** | **`200` — live** |
| `15f2bcf0` | 2026-04-10 | `404` (past retention) |

`b2c2b878` predates the per-IP auth rate limit (`38b2878`), the signup compensating rollback (`c75592c`), the CORS origin-reflection fix (`66f1825`), and the JWT-in-URL removal (`c55dcff`) — and answers today with all 13 production secrets. **Merging this branch therefore does not fully retire the vulnerabilities it fixes**, because the un-fixed code stays reachable at a parallel URL. Three workers are affected: `sender-worker` (13 secrets), `api-provisioning-receiver` (7, different repo), `integrity-studio-contact` (2). The 8-character version prefix is not a secret — `wrangler` prints the full ID on every deploy, so it reaches terminal scrollback and CI logs.

`preview_urls = false` is now set in `sender-worker` and `contact-form`, enforced by a test. **It takes effect on their next deploy, so production is not yet mitigated**; the no-deploy API mitigation is in CR14, and `api-provisioning-receiver` needs its own repo's owner.

> 🔴 **Correction, 2026-08-03 — three claims above are wrong, and the mechanism is the important one.** A version is an **immutable snapshot of code AND bindings**, which is why `wrangler secret put` creates a new version at all. So a retained version publishes **the bindings it was uploaded with**, not "the current secrets bound", and not "all 13 production secrets" — that 13 was the script's live count at audit time and was never measured on `b2c2b878`. Measured on `api-provisioning-receiver`: its 2026-03-20 version holds **1** binding and **zero** secrets while today's holds 12. And `15f2bcf0`'s `404` is not "past retention" — it is still retained; a `404` means the version came from `wrangler secret put`, which gets no preview URL. **The finding survives the correction and gets worse in the other direction:** rotation does not leak backwards onto old versions, but it does not clean them up forwards either, so every pre-rotation version keeps serving the credential the rotation was meant to retire. (Value-freezing is inferred from the version mechanism — the API returns binding *names* only. The clean test, signing an old preview URL, was skipped because `POST /inbox` writes production rows.) See BACKLOG.md CR14.

**Correction to *Worker Deploy Separation*:** that entry argued `api-gateway.alyshia-b38.workers.dev` and the dev worker were distinct because the dev subdomain "is not even enabled (Cloudflare 1042)". That was propagation lag seconds after creation; the subdomain is enabled and now answers. The workers are still distinct — separate scripts and separate DO namespaces — so the conclusion stands, but that evidence was wrong.

**Final state:** 3,001 Flutter tests and 1,021 worker tests passing; zero routes point at any `*-dev` Worker.

---

## [2026-07-27] - Dev Worker Settings Audit (sender-worker-dev, contact-dev)

Verified the two remaining dev Workers against their production counterparts via the Cloudflare API. The isolation claims made earlier all hold, and the diff against production surfaced three fixes.

**Isolation confirmed by inspecting deployed state, not config:**
- `sender-worker-dev` binds `RATE_LIMIT_KV` to the dev namespace `46a717cd…`, not production's `766332ec…`.
- `integrity-studio-contact-dev` binds `5719e569…`, not production's `cf9d7d72…`, and repeats all five non-inheritable `vars` with `ENVIRONMENT = "development"`.
- Both hold **zero secrets**; neither has crons or tail consumers; no zone route points at either.
- `sender-worker-dev`'s `RECEIVER` binding does point at the production `api-provisioning-receiver`, exactly as documented — still CR02 item 5.

**`preview_urls` is an inheritable key.** Set only at the top level, it propagated to both dev Workers on deploy — `previews_enabled` flipped to `false` on `sender-worker-dev` and `integrity-studio-contact-dev`. Verified rather than assumed, given that getting this backwards for `routes` caused the earlier incident. No `[env.dev]` duplicate is needed, and CR14's dev-side concern is closed before CR11 pushes secrets in. Production remains `true` until its next `deploy:prd`.

**`npm run deploy` now works for every worker.** Only `sender-worker` had the Doppler wrapper; the other five ran bare `wrangler deploy --env dev` and failed with "necessary to set a CLOUDFLARE_API_TOKEN" unless one happened to be in the environment. All six now wrap with `doppler run --config dev`, so the documented dev-deploy command works as written.

**CR15 filed — production `sender-worker` config drift**, both found by diffing against dev:
- `observability.enabled` deploys as `false` while `logs.enabled` is `true`, because the top-level `[observability]` block declares no `enabled` key. Workers Logs may never have been on, despite a 2026-04-03 entry saying it was enabled — which matters because diagnosing CR12 and confirming CR03's limiter both need logs.
- `RECEIVER_WORKER_URL` and `PROVISIONING_RECEIVER_WORKER_URL` are still bound, left from before the service-binding migration (`d450ef4`). No code reads either name; they are two more credentials inside CR01's blast radius.

**CR11 gained a step:** `contact-form`'s dev vars carry the production `RECIPIENT_EMAIL` (`hello@integritystudio.ai`), so the moment dev holds a Resend key, dev test submissions reach the real inbox. Safe only because the key is absent and the worker fails closed without `CSRF_SECRET`.

**Final state:** 3,001 Flutter tests and 1,021 worker tests passing; `previews_enabled: false` on both dev Workers; zero routes point at any `*-dev` Worker.

---

## [2026-07-27] - Observability Actually Enabled on sender-worker (CR15 item 1)

`workers/sender-worker/wrangler.toml` now sets:

```toml
[observability]
enabled = true

[observability.logs]
enabled = true
invocation_logs = true

[observability.traces]
enabled = true
```

**The `enabled = true` on the parent table is the part that matters**, and it was the missing piece. Verified by experiment rather than assumed: a scratch deploy of `bootstrap-worker-dev` carrying `logs.enabled = true` and `traces.enabled = true` but no parent `enabled` reported `observability.enabled: false`; adding the parent line flipped it to `true`. The child tables alone do nothing. So the 2026-04-03 entry recording "Enabled observability logs on sender-worker" never took effect — production has been running with observability off for ~4 months, which is also why there were no logs to consult while diagnosing CR12.

A second behaviour surfaced while confirming it: **a named environment's `observability` block replaces the parent's rather than merging into it.** `[env.dev.observability]` already set `enabled` and `logs`, so it did not pick up the new top-level `traces` and dev came back `traces=False` while production config said true. Repeating `traces` under `[env.dev.observability.traces]` fixed it; `sender-worker-dev` now verifies as `enabled=True logs=True invocation=True traces=True`.

That is a third distinct inheritance rule in this file, and they do not agree with each other:

| Key | Behaviour in a named environment |
|---|---|
| `durable_objects`, `services`, `vars`, `kv_namespaces`, … | **Not** inherited — must be repeated |
| `routes`, `triggers`, `preview_urls` | **Inherited** — must be explicitly emptied to opt out |
| `observability` | **Replaced wholesale** when the child declares it at all |

**Production is not yet affected** — it still reports `observability.enabled: false` and will until the next `deploy:prd`, which CI runs on merge to `main`. Binding resolution was re-checked after the edit: production resolves `RATE_LIMIT_KV` to `766332ec…` and dev to `46a717cd…`, unchanged.

---

## [2026-07-27 evening] - Database Remediation, Secret Binding & Stripe Endpoint (CR12 partial, CR14 partial, CR17/CR18 filed)

A session that started as "is there a dev-specific Stripe webhook?" and ended with production `api-gateway` healthy for the first time in four months. Each fix uncovered the layer beneath it.

### The migration ledger was lying (CR17)

`supabase_migrations.schema_migrations` listed 8 of 9 local migrations as applied. **Only 5 were.** Most consequentially, `20260321000000_add_webhook_dead_letters` was recorded as applied while `webhook_dead_letters` and `webhook_events_log` **existed in no schema at all** — meaning `stripe-webhook` was structurally broken *beneath* its missing secrets, and binding secrets alone would have left every event failing on a PostgREST 404.

Two root causes, both worth carrying forward:

- **`create policy if not exists` is not valid PostgreSQL.** There is no `IF NOT EXISTS` for `CREATE POLICY`. That statement sits at line 11 of `20260320010001`, so the file aborted there and every statement after it silently never ran. Replaced with `drop policy if exists` + `create policy`; the live predicate was confirmed byte-identical first, so the recreate was a semantic no-op.
- **`supabase migration repair --status applied` writes the ledger row — including the full `statements` array read from the local file — without executing any of it.** That is exactly the fingerprint found: complete recorded SQL, zero corresponding objects. It is the natural move when a push keeps failing, and it converts a loud failure into a silent one.

Repaired with `migration repair --status reverted` followed by `db push --include-all` (the two out-of-order migrations sort before the last applied version, so a plain push skips them). `supabase migration list` now reports **10 migrations, zero out of sync**.

Left deliberately divergent: `20260320010002` still shows applied with 4 triggers missing. They duplicate the `update_*_updated_at` triggers `phase1_consolidated` already installed on the same tables, so re-running would double-fire timestamp maintenance for no benefit.

### RLS off is not private — three tables were world-readable

Applying the dead-letter migration created two tables with RLS deliberately omitted, its comment reasoning that only the service-role key touches them. **That reasoning is wrong:** PostgREST exposes every table in the `public` schema, so RLS-off means the *publishable* anon key can read them. Verified — an anon `GET` returned `200` on `webhook_dead_letters`, `webhook_events_log`, and the pre-existing `stripe_events`. Since `webhook_dead_letters` stores the complete Stripe event payload, that would have become a customer-billing-data disclosure path on the first processed event.

Closed with `20260727000000_enable_rls_on_webhook_tables.sql` — a migration rather than an ad-hoc `ALTER`, so the files stay the source of truth. RLS on, zero policies: anon and authenticated denied, `service_role` unaffected. **Zero tables in `public` now have RLS disabled.**

Verifying this needs care, because the obvious check misleads: RLS denial returns an empty result set, not an error, so anon still gets `200 []` on an empty table. The proof is on a populated one — `users` returns 0 rows to anon and 26 to the service role.

### Secrets bound; `api-gateway` restored (CR12 partial)

| Worker | Bound | Result |
|---|---|---|
| `api-gateway` | `SUPABASE_URL`, `SUPABASE_SERVICE_ROLE_KEY`, `SUPABASE_JWT_SECRET` | `503 {"database":"degraded"}` → **`200 {"database":"healthy"}`** |
| `stripe-webhook` | `SUPABASE_URL`, `SUPABASE_SERVICE_ROLE_KEY` | cron can finally reach its table |

This is what makes V02's dashboard real — its endpoints have been unable to return data since 2026-03-31. `/v1/me` correctly answers `401` to an anonymous caller.

**CR12 step 1 is answered by evidence: pre-launch, not a regression.** No Stripe webhook endpoint had ever been registered on either account — verified against both the v1 `webhook_endpoints` and v2 `event_destinations` APIs. Nothing was ever dropped because nothing was ever sent.

Three secrets could not be bound because no value exists anywhere: `API_KEY_HMAC_SECRET` (canonical copy lives on `api-provisioning-receiver` in another repo; generating a new one would silently invalidate every existing API key), `STRIPE_SECRET_KEY`, and `STRIPE_WEBHOOK_SECRET`.

### Preview URLs closed before secrets were bound (CR14 partial)

All four production Workers still had `previews_enabled: true`, which publishes every retained version at its own URL **with the script's current secrets**. Binding secrets first would have created exactly the exposure CR14 documents, so previews were disabled on `api-gateway` and `stripe-webhook` beforehand — with `"enabled":true` passed alongside, since for `api-gateway` the `workers.dev` hostname is what the shipped app calls.

A second gap surfaced: **neither `wrangler.toml` set `preview_urls` at all**, and it defaults to `true`, so the next deploy would have silently re-enabled previews. Both configs now set it explicitly. Still exposed: `sender-worker` (13 secrets), `integrity-studio-contact`, and cross-repo `api-provisioning-receiver`.

> 🔴 **Correction, 2026-08-03 — "with the script's current secrets" is wrong; the action was right for a different reason.** A version snapshots code **and** bindings, so a retained version serves the bindings *it* was uploaded with. That means binding secrets would **not** have retroactively armed the pre-existing versions (they had no such bindings) — but each `wrangler secret put` creates a **new** version, and with previews on, every one of those would have been published carrying the secret just bound. So closing previews first was still the correct order; the sequencing conclusion survives and the mechanism behind it does not. The harder consequence runs forwards: a version already published with a credential keeps serving it after the credential is rotated or unbound. See BACKLOG.md CR14.

### Stripe endpoint registered, signature verification proven (CR18 filed)

Endpoint `we_1Ty14zBWbFuvm1I6rvLOD5OW` → `stripe-webhook-dev`, **test mode**, `api_version` pinned to `2025-09-30.clover`, subscribed to the five events the handlers implement. Pointed at the dev Worker deliberately: production now holds live Supabase credentials, so sandbox test events would otherwise write into the production ledger tables.

Three details worth recording:
- **v1, not v2.** `POST /v1/webhook_endpoints` yields snapshot events, which is what the handlers parse via `event.data.object`. The v2 `event_destinations` example in Stripe's docs passes `"event_payload": "thin"`, which would break every handler.
- **The signing secret is returned only from the create call** — `GET /v1/webhook_endpoints/:id` omits it, verified. Stored in Doppler `dev`, since otherwise it would exist solely inside an unreadable Cloudflare binding.
- **`api_version` as a body parameter is not the `Stripe-Version` header.** The header shapes the API response you receive; the parameter shapes the events delivered to your endpoint. The account default was measured (`2025-09-30.clover`) rather than copied from the docs example.

**New test suite:** `workers/stripe-webhook/src/webhook-signature.live.test.ts`, run with `npm run test:live`. Five tests covering a valid signature, the multi-`v1` rotation branch, a tampered signature, a stale timestamp, and a missing header. Mutation-verified — with a deliberately wrong secret, exactly the two accept-tests fail. It uses Web Crypto rather than `node:crypto` so it typechecks against `@cloudflare/workers-types`, and the base vitest config now excludes `*.live.test.ts` so it stays out of CI.

Incidental: Cloudflare rejects `Python-urllib` with error 1010 before the request reaches the Worker. The first probe looked like three 403s and proved nothing; Stripe's own user agent passes.

### Corrections to earlier entries in this file

- **`STRIPE_API_KEY` is not `sk_test_` in both configs** — see the retraction on the *Environment Isolation Detector* entry above. Two different Stripe accounts, and the `prd` value is publishable.
- **The Supabase project is not paused.** Earlier entries state both projects are `INACTIVE`. `cfrbahzzklwrnmbtqojl` ("IntegrityStudio") is `ACTIVE_HEALTHY`; the `INACTIVE` one is `kvbcgfttukwciiwieezp` ("atx_movement"), unrelated. No resume step is needed to fix CR12.
- **`doppler run` cannot be trusted to report which value a config holds.** One invocation returned a value that `doppler secrets get --plain` and the upstream API both contradicted; `~/.doppler/fallback/` caches snapshots. Compounded by `sh -c 'echo -n "$V"'` printing the literal `-n `. Use `printf '%s'` and compare hashes.

---

---

## [2026-07-29] - Credential Rotation, JWKS/ES256 Verifier, Auth0 Isolation & Test Infrastructure Repair

### JWT Verification — JWKS/ES256 (`workers/lib/auth.ts`)

- **`verifyJwt` now verifies ES256 and RS256 against the project's published key set**, with HS256 retained as a fallback so tokens minted before the migration verify until they expire. The project had already moved to asymmetric signing keys (HS256 `previously_used`, ES256 `in_use`), so HS256-only verification was living on borrowed time — and it made a dev Supabase project unusable for the JWT path, since new projects default to ES256 with no legacy secret to bind.
- **No new secret or config.** The JWKS URL derives from `SUPABASE_URL` via `supabaseJwtKey()`, which every route's options object already carried, so each environment verifies against its own project automatically.
- **Algorithm confusion closed by construction:** the header's `alg` selects which path runs but never which key material is used, so an `HS256` token is only ever checked against a configured HMAC secret and a JWKS public key can never be replayed as a shared secret. `alg: none` and anything outside `{ES256, RS256, HS256}` are rejected before verification.
- Key sets cache for 10 minutes; an unrecognised `kid` triggers at most one refetch per 30s cooldown so rotation is picked up without letting forged kids drive unbounded upstream fetches. Fetch failures fail closed but preserve a still-valid cached key.
- **`SUPABASE_JWT_SECRET` is now optional** throughout — schemas, both `Env` interfaces, the five route option types and `PreVerifyTokenOptions`. `SUPABASE_URL` is the field verification actually depends on.
- Verified with 17 new unit tests using a locally generated P-256 key pair, plus a live check that the real project's published key (`kid b91503ee-…`) imports under exactly these WebCrypto parameters and rejects a token forged with a different key.
- ⚠️ **Not deployed** — `api-gateway` and `bootstrap-worker` pick this up on their next `deploy:prd`.

### Credential Rotation (CR01)

- Rotated every family that can be rotated by API: Stripe, `AUTH0_CLI_SECRET`, `AUTH0_CLIENT_SECRET` (via Management API `rotate-secret`), HMAC `SHARED_SECRET`, and the `sb_secret_` service keys with the old key revoked and verified dead. Legacy Supabase `anon` + `service_role` JWTs disabled (CR24); a stray auto-created `sb_secret_` key revoked.
- **`AUTH0_CLI_SECRET` was rotated a second time as a recovery.** A Dashboard session against the *wrong Auth0 account* overwrote all four `AUTH0_CLI_*` slots in both configs, which destroyed the last readable copy of the production secret — the Worker binding is write-only. Restoring was impossible, so rotation was the only route. **Lesson recorded:** a Doppler slot plus a write-only Worker binding is *one* copy, not two.
- Doppler slot hygiene: six anon slots filled with the live publishable key (`prd SUPABASE_ANON_KEY` had held the disabled legacy **`service_role`** JWT), duplicate `SUPABASE_SERVICE_KEY` deleted, `SUPABASE_ACCESS_TOKEN` emptied because a garbage value *overrides* the CLI keychain, and two `AUTHO_*` slots cleared that held Auth0 tokens **expired 241 and 125 days**, one from a different tenant.
- **Two findings that look like mis-slots but are not:** `SUPABASE_DB_PASSWORD` genuinely authenticates to Postgres despite holding the same string as a live API key (do not clean it up — decouple it in the Dashboard), and two different live `rk_live_` Stripe keys exist while code reads only `STRIPE_SECRET_KEY`.

### Environment Isolation (CR11) — 10/13 → 3/13

- `dev` got its own HMAC `SHARED_SECRET`, its own Auth0 ROPC + M2M clients, and a separate **`dev-users` connection** so dev credentials cannot authenticate any of the 96 production users — proven with a four-way ROPC matrix rather than by reading configuration. The dev M2M was created with **no Management API grant at all**, so leaked dev credentials are inert rather than narrowly-scoped-but-tenant-wide.
- 🔴 **Trap:** Auth0 auto-enables newly created clients on existing connections — including the production one — so creating the dev clients silently widened production access (7 → 9 clients) until removed. This is **not** limited to `is_domain_connection: true` connections. Audit every connection's client list after creating any client.
- **No Auth0 API can create a tenant** (`create:tenants` is not grantable, `/api/v2/tenants` is not a resource), so `AUTH0_DOMAIN` is Dashboard-only. A second tenant already exists and needs only an M2M credential — which would also remove the `password`-grant/`default_directory` blocker, since that setting is per-tenant.
- Auth0 Cross App Access and the My Account API were both evaluated and **cannot** clear the last row.

### Supabase

- Deleted the unused `atx_movement` project (owner-directed, no backups existed), freeing a free-tier slot for a dev project. Audited an external plan for using it and corrected four of its steps — notably that `db pull` would pollute the ledger repaired under CR17, and that the **custom access-token hook is Auth config, not schema**, so `db push` leaves it created-but-never-firing.
- Auth `site_url` corrected from **`https://aleph-analytics.app/`** (another product) to `https://integritystudio.dev/`, with `uri_allow_list` updated in the same call — changing `site_url` alone would have left every explicit `redirect_to` rejected.

### Auth0 Production Readiness (CR25, new)

- Audited the tenant against the Dashboard's production checks, which cannot be read programmatically. Disabled the `google-oauth2` connection that ran on Auth0's shared **development keys** across 6 applications (0 users), and enabled TOTP + recovery-code factors so MFA can be enrolled at all. Breached-password detection turned out to be **paid-plan gated**, correcting an earlier claim in this file's own audit that it was a free single PATCH.

### Test Infrastructure

- **`sender-worker` `test:e2e` went from collecting 0 tests to 44/44 passing.** Four stacked problems: the pool was never enabled (v4 applies it as a Vite plugin, `cloudflareTest(...)`, with no `/config` entry point); the config had to become `.mts` because the plugin is ESM-only; `fetchMock` no longer exists in pool 0.18.8, so `src/e2e-fetch-mock.ts` reimplements the slice the suite uses on `vi.stubGlobal`; and the per-IP auth rate limiter capped the whole suite at 10 requests until each request got its own `CF-Connecting-IP`.
- Fixed the 4 stale assertions. One was genuinely stale (`/signin` asserted `404` though it is Auth0 ROPC — replaced with four cases covering the real contract). One was message drift. One had a false premise. And **one was correct all along** — `SUPABASE_ORG_MEMBERSHIP_FAILED` failed only because the worker's compensating rollback was unmocked, so the rollback's own failures replaced the original error.
- **`sender-worker` `test:live` re-pointed at `--config prd`** (dev credentials cannot mint a management token by design) — and a destructive trap defused: the suite **deletes** the user at `AUTH0_TEST_EMAIL`, which in `prd` is the real `test@integritystudio.ai` account with two org memberships and a Supabase row keyed to its Auth0 `sub`. `vitest.live.config.ts` now overrides that to a disposable identity.
- Worker totals: **1,063 tests** via `npm run test:workers`, zero TypeScript errors via `npm run lint:workers` (which *is* the worker linter — there is no ESLint under `workers/`).

## W12 — five cross-environment values in Doppler `dev`, found and fixed (2026-08-09)

Filed and closed within a day. Recorded here in full rather than by id, because a
changelog that holds an item's id but not its content is the same loss with a
citation on top.

**How they were found, which is the reusable part.** `W09` closed by replacing a
hand-maintained "these must differ" list with a classifier over *every* name present
in both configs. Its first run produced five names no list had ever mentioned. The
list had not been wrong about the values it named — it was wrong about the ones it
did not, and a name it does not mention is never measured, so the check passed.

| Value | Why it was wrong | Resolution |
|---|---|---|
| `IS_PROD_TOKEN` | prefix `dp.st.prd.` — a Doppler **service token scoped to `prd`**, sitting in `dev`. Anything with dev access could read the entire production config | **deleted from `dev`** (retained in `prd`) |
| `OTEL_EXPORTER_OTLP_ENDPOINT` | `https://ingest.integritystudio.ai` — production ingest, under `dev` | repointed at `obtool-ingest-dev` |
| `OBTOOL_INGEST_ROUTE` | `ingest.integritystudio.ai/*` — production route | repointed at `obtool-ingest-dev` |
| `OBTOOL_API_KEY_INVENTORY_AI` | a **customer's** live `obtk_` key, byte-identical in both configs | **deleted from `dev`** |
| `JWT_SECRET` | 44 chars, provenance unknown, read by nothing | **deleted from `dev`** |

🔴 **`IS_PROD_TOKEN` was a different *kind* of finding from anything W09 held.** Every
other value there reached one production *resource* — a database, a tenant, a webhook.
This one reached **the credential store itself**, making the whole isolation boundary
conditional on nobody using a token sitting in plain view.

**Verification, and the trap it avoided.** All five were confirmed unread before any
deletion. `JWT_SECRET` first appeared to have **8 consumers** — every one was a
substring match inside `SUPABASE_JWT_SECRET`. A word-boundary grep returns zero. That
is the third instance of the substring-merge trap in this repo, after
`api.integritystudio.ai` inside `sandbox-api.integritystudio.ai` (CR31) — **a bare
substring grep merges names, and the merged result reads as evidence of use.** The
`OTEL_*` hits were likewise all customer-facing documentation pages showing users how
to configure their own exporter, not Doppler reads.

**Deletes were reversible by construction:** all three deleted names remain in `prd`
with identical values, so the dev deletion destroys no information.

**`KNOWN_GAP` in `scripts/check-env-isolation.sh` is now empty, and deliberately kept
as an empty map rather than removed.** An empty map asserts "no known-wrong shared
values"; deleting the concept would assert nothing at all, and would push the next
real gap toward `SHARED_BY_DESIGN` — which converts a printed defect into a silent
pass, the exact failure the detector exists to prevent.

Post-fix: `npm run check:env-isolation` PASSES with **zero** `KNOWN GAP` rows (was 5),
167 names in both configs, 24 credentials differing, 10 accepted as account-scoped
(Cloudflare and Supabase tokens that have no per-environment scoping at all).

⚠️ **Not addressed, and deliberately out of scope:** the `prd` copies of
`OBTOOL_API_KEY_INVENTORY_AI` (a customer credential at rest in our secret store) and
`JWT_SECRET` (an untriaged dead slot). Neither is an isolation defect; both are
questions about whether the value belongs in the project at all.

## [2026-07-29] - Prod secret durability & rotation cadence under Doppler — documented (W05)

> Migrated verbatim from `docs/BACKLOG.md` on 2026-08-22 (`/backlog-migrate`, append-to-1.3 decision). Heading normalised; body unchanged.

### W05: Verify & document prod secret durability + rotation cadence under Doppler

**Priority:** P3 | **Source:** session 2026-06-27, reconciled from provisioning setup notes (now consolidated into `docs/provisioning-environment-setup.md`) — open items "Secrets backed up (1Password/Vault) — must implement", "Secret rotation documented (quarterly)"
**Estimated:** 1–2 hours

**Context:** The setup summary's "back up secrets to 1Password/Vault" action predates the move to **Doppler** as the managed secret store (`doppler --project integrity-studio --config dev|prd`, used by every worker's `deploy:prd` script and CI). Doppler is now the system of record for worker secrets, which largely supersedes a manual vault backup. This item reconciles the stale intention rather than implementing 1Password.

> **⚠️ Audit 2026-07-27 — two corrections before this item is worked.**
>
> **1. Doppler is not where worker secrets live.** This item treats "confirm Doppler holds the secrets" as confirming durability for the running workers. It is not the same thing: `wrangler deploy` does not turn Doppler values into Worker secrets, which are set per worker with `wrangler secret put`. Doppler's role at deploy time is to supply `CLOUDFLARE_API_TOKEN`. The authoritative check is `npx wrangler secret list --name <worker>`. `CLAUDE.md` already documents this; the item predates it.
>
> **2. ~~The rotation mechanism is implemented but not provisioned, so it cannot be exercised.~~ ✅ Provisioned and exercised end to end (2026-07-30).** This note read "neither is bound to production `sender-worker`", which was true when written and is no longer. Both sides now carry the rotation: `sender-worker` binds `SIGNING_KEYS` + `ACTIVE_KEY_ID` (key id `v2`) and `api-provisioning-receiver` binds a matching `SIGNING_KEYS` plus `KEY_ROTATION_DATES`. **Verified live rather than from the binding list**, since a `SIGNING_KEYS` mismatch 401s every signed request: `/signin` → `200` with an 855-char JWT → HMAC-signed `/send` (`sign_in`) → `200 {ok: true}` returning the real account with **2 organizations**. The org count is the proof it reached the production receiver and not the local stub, which hardcodes `organizations: []`. The rotation cadence in step 3 is therefore documentable against a mechanism that is actually switched on.
>
> Also relevant: `STRIPE_*` is not bound to `sender-worker` either (checkout returns `{"error":"Stripe not configured"}`), and four bound secrets are inert leftovers ([[CR15]]). And per [[CR01]], **nothing has been rotated at all** while the full credential set sits in git history — which makes cadence documentation the least urgent part of this item.

**Scope:**
1. Confirm Doppler `integrity-studio/prd` holds the canonical copy of all provisioning secrets (`SHARED_SECRET`, `SIGNING_KEYS`/`ACTIVE_KEY_ID`, `AUTH0_*`, `SUPABASE_*`, `STRIPE_*`), **and separately** confirm what is actually bound to each Worker with `wrangler secret list` — the two sets differ today.
2. Document whether an additional offline backup (1Password/Vault) is still required by policy, or formally accept Doppler as sufficient.
3. Document the secret-rotation cadence and procedure. **Note:** the rotation *mechanism* is implemented in code (`SIGNING_KEYS` + `ACTIVE_KEY_ID` + `x-key-id`, procedure in `workers/sender-worker/src/index.ts:150-158`) and is **provisioned in production as of 2026-07-30** (key id `v2`, verified by a live signed round-trip) — see the corrected audit note above.

**Files to touch:**
- `docs/provisioning-environment-setup.md` (secret durability + rotation cadence)
- `CLAUDE.md` "Secret Rotation" section (confirm/expand)

**Status:** ✅ Done (2026-07-29) — documentation written. `docs/provisioning-environment-setup.md` now includes a "Secret Durability and Rotation" section covering: Doppler as system of record (accepted as sufficient; no additional vault backup required), the `STRIPE_WEBHOOK_SECRET` single-copy risk and what it means for recovery, a rotation procedure for `SHARED_SECRET` with safe value piping, the zero-downtime path via `SIGNING_KEYS` (~~implemented, not provisioned~~ — **provisioned since 2026-07-30**, key id `v2`), and a rotation-cadence policy. Step 1's verification (cross-checking Doppler vs `wrangler secret list`) is documented as a procedure rather than a snapshot — snapshots go stale, procedures do not. CLAUDE.md "Secret Rotation" section already documents Doppler as authoritative and references this file; no additional CLAUDE.md edit is needed.

> 🔴 **Reopened 2026-07-31 — the documented rotation path does not actually retire a key.** Two corrections to what this item shipped. First, the "not provisioned" parenthetical above was stale in the *written doc too*: `docs/provisioning-environment-setup.md` opened its Rotation Procedure with "Current production state: `SHARED_SECRET` single-key… not provisioned — both workers still use a single shared secret", which had been false since 2026-07-30 (fixed below). Second and more seriously, the zero-downtime path is documented without its defeating condition: **the legacy `SHARED_SECRET` stays valid through a `SIGNING_KEYS` rotation**, because the receiver resolves an absent `x-key-id` to it. Anyone following this runbook rotates `v2` → `v3`, verifies a `200`, and reasonably concludes the old key is retired. It is not. Tracked as [[CR29]], which owns the code fix — **written 2026-08-02, unpushed, so the runbook's guarantee is still defeated in production**. Two things in this doc will need a further pass once it deploys: rotation procedure **B (legacy)** describes a path that no longer exists, and rotation step 4's key-age alert entry for `SHARED_SECRET` becomes an alert on a credential nothing reads.

> ✅ **Doc correction done 2026-07-31** — the runbook no longer misstates the state or the guarantee. `docs/provisioning-environment-setup.md` "Rotation Procedure" now opens with the real multi-key state (`v2`, provisioned 2026-07-30) plus a red warning that `SHARED_SECRET` is a second valid credential no rotation below retires; the zero-downtime path says step 2 revokes only the previous *key-id'd* key; the cadence's item 2 is struck (done) and item 3 warns that a quarterly rotation is not yet a quarterly revocation. **A third defect surfaced while writing it, and it is now recorded in [[CR29]]:** the 90-day Sentry key-age alert tracks `SHARED_SECRET` by name and rotation step 4 refreshes that date, so following the runbook turns the alert green while the old credential stays live — the alert measures the age of a JSON value, not the liveness of a key. Step 4 also only told operators to add per-key-id entries "if `SIGNING_KEYS` is later provisioned", so whether `v2` was ever added is unverified and a missing entry exempts the *active* key from the alert. This item is closed again on the documentation; the design fix stays with CR29.

> **Update 2026-07-27 evening — three corrections to step 1's premise.**
>
> **`STRIPE_*` is not just unbound, it does not exist.** This note said `STRIPE_*` "is not bound to `sender-worker`", implying the value existed and needed binding. `STRIPE_SECRET_KEY` is empty in all three Doppler configs, so there is nothing to bind. See [[CR18]].
>
> **A new secret now needs a durability answer.** `STRIPE_WEBHOOK_SECRET` was added to Doppler `dev` on 2026-07-27 because Stripe returns a signing secret **only** from the endpoint-create call and will not disclose it on retrieve — verified. Without that copy, the value would exist solely inside an unreadable Cloudflare binding and would be unrecoverable if the Worker were rebuilt. That makes Doppler load-bearing for recovery here in a way step 2 should account for, and it is a good argument for formally accepting Doppler as the system of record rather than adding a second vault.
>
> **Do not trust `doppler run` when verifying what a config holds** — use `doppler secrets get --plain` and compare hashes. See the corrected bullet in [[CR11]].

## [2026-07-31] - Checkout sessions now carry `org_id`; subscriptions link to organizations (CHK01)

> Migrated verbatim from `docs/BACKLOG.md` on 2026-08-22 (`/backlog-migrate`, append-to-1.3 decision). Heading normalised; body unchanged.

### CHK01: Checkout sessions carried no `org_id`, so no subscription ever linked to an organization

**Priority:** P1 (revenue-adjacent: paid subscriptions were not attributable to an org) | **Source:** session 2026-07-31, while generating a live checkout link for `team-inventoryai-io`
**Status:** ✅ **done and live** (corrected 2026-07-31 — the line below said "not committed, not deployed" and was stale by one merge). Committed as `a2f3ff6` *fix(sender-worker): set metadata[org_id] on Stripe checkout sessions*, merged to `main` via PR #20 (`35e9c09`), and shipped by CI run **30612619138** ("Deploy Sender Worker: success"). **Verified in the deployed artefact, not inferred from a green deploy** — the live `sender-worker` bundle contains `metadata[org_id]`, `subscription_data[metadata][org_id]`, and three `default_organization_id` references, none of which exist in the pre-fix build. **Closed 2026-08-02** — step 3 (the optional backfill) was investigated and found to have an empty target; see step 3 below.

`workers/sender-worker/src/stripe.ts` built its Checkout params with **neither `metadata[org_id]` nor `client_reference_id`** — grep the pre-fix file for either and it returns nothing. But `workers/stripe-webhook/src/handlers/checkout.ts:24` reads exactly those two on `checkout.session.completed`:

```ts
const orgId = session.metadata?.org_id || session.client_reference_id;
if (!orgId) {
  console.warn('Checkout session missing org_id in metadata or client_reference_id');
  return { ok: true };            // warn-and-bail: linkStripeCustomer never runs
}
```

So every checkout the production sender created hit the warn-and-bail path: `organizations.stripe_customer_id` was never written and no subscription row was attached to an org. Consistent with live data at the time — **1 subscription row and exactly 1 org with a `stripe_customer_id`, system-wide.**

This is a one-shot bootstrap value. It is needed **only** in `checkout.session.completed`, to run `linkStripeCustomer(orgId, session.customer)`. Every other handler resolves the org from the customer id instead (`subscription.ts` ×2 and `invoice.ts` ×2 all call `findOrgByStripeCustomerId`), so once `stripe_customer_id` is written the session metadata stops mattering.

**Fix (implemented):**
- `src/supabase.ts` — new `supabaseFindOrgIdByEmail()`. Resolution mirrors `custom_access_token_hook`: prefer the user's `default_organization_id`, else oldest active membership. Returns `null` for an unknown email rather than throwing.
- `src/stripe.ts` — `createStripeCheckoutSession` takes an optional trailing `orgId` and sets both `metadata[org_id]` and `subscription_data[metadata][org_id]`. Optional and trailing so no caller signature breaks.
- `src/index.ts` — `handleCreateCheckoutSession` resolves the org before calling Stripe.

**Two decisions worth not re-litigating:**

1. **The org is derived server-side from the email — `orgId` was deliberately NOT added to `CreateCheckoutSessionSchema`.** `/create-checkout-session` is origin-gated but **unauthenticated**, so a client-supplied org id would let any caller who can reach the endpoint attach a subscription to an org they do not own. Deriving it server-side also needs no change from the landing page or the Flutter client. Note the origin gate is not a real boundary here: `isOriginAllowed` is browser-surface only, and origin-less callers (Flutter native, curl) bypass it by design — which is precisely why the org id must not be caller-supplied.
2. **Resolution is best-effort and never blocks a sale.** A lookup failure or an unknown email logs and proceeds with an unattributed session rather than erroring. Failing checkout to protect a metadata field trades a linking bug for a revenue bug. The cost is that the unresolvable case silently reverts to the old behaviour, so both branches log loudly (`console.warn` for no-org, `console.error` for lookup failure). Two tests pin it: unknown email → 200 without metadata, lookup 500 → 200 without metadata.

**Tests:** that describe block went 7 → 11. Four new: metadata from default org, membership fallback, unknown email, lookup failure. **Three existing tests had to be reworked, and the reason generalises:** they used `mockResolvedValueOnce`/`mockRejectedValueOnce`, which bind to call *order*, so the newly-added Supabase lookup consumed the mock and the Stripe branch under test never ran. Two of those were in a sibling `describe` and only surfaced on a full-suite run, not a `-t`-filtered one. All now route by URL (`url.includes('/rest/v1/')`), which is order-independent — **prefer URL routing over sequential mocks in this file.** Suite: 188/188, `tsc --noEmit` clean.

**Remaining:**
1. ~~Commit~~ — ✅ `a2f3ff6`.
2. ~~Deploy~~ — ✅ live. CI deployed it on the PR #20 merge (run 30612619138); the `HEAD`-ahead-of-`origin/main` caveat that made this step risky no longer applies to *this* fix, because the merge is what shipped it. The caveat itself still stands for future work.
3. ~~Optional: backfill. Any already-paid subscription created before this ships has no `org_id` on its session and is unlinked; re-deriving it means matching the Stripe customer email back to a user. Unknown volume — the single existing `stripe_customer_id` row suggests it is small.~~ — ✅ **Not needed; the target set is empty** (verified 2026-08-02 against live `acct_1SN2e7AwEfePbhfk` and Supabase). **The premise never materialised: there is no paid-but-unlinked subscription, and there never was one.**

   Live Stripe holds **2 customers, 2 subscriptions, 6 checkout sessions**, and every paid artefact is already linked in *both* `organizations.stripe_customer_id` and the `subscriptions` table:

   | Customer | Email | Subscription | Org |
   |---|---|---|---|
   | `cus_Uz8KgGh0peiaif` | alyshia@inventoryai.io | `sub_1TzA40…` active | `1649a1c1` team-inventoryai-io |
   | `cus_UxxzTfUmEWrvd0` | alyshialedlie@gmail.com | `sub_1Tz7Gh…` trialing | `20e71316` alyshia-ledlie |

   Of the 6 checkout sessions, five are `expired`/`unpaid` and one is `complete`/`paid` — and that paid one already carries `metadata[org_id]`. The **only** session lacking an org id (`cs_live_a1WcjL32…`) is expired and unpaid, so it produced no customer and no subscription. The five orgs with no `stripe_customer_id` are all `billing_status: inactive` except the internal `Integrity Studio AI` parent-organization, which has no Stripe customer at all.

   Two findings worth keeping, because they explain *why* the backfill was empty rather than merely recording that it was:
   - **The one paid session postdates the fix**, so it was never exposed to the warn-and-bail path. The pre-fix window produced expired sessions only.
   - **`sub_1Tz7Gh…` has no `metadata.org_id` and that is correct, not a gap.** It has no checkout session at all — it was created directly — so it was linked by customer id. That is the path this entry already identifies as the reason session metadata stops mattering once `stripe_customer_id` is written (`subscription.ts` ×2 and `invoice.ts` ×2 all use `findOrgByStripeCustomerId`). Do not "fix" the missing metadata; nothing reads it.

   **Not checked:** the sandbox account from [[CR18]]. Test-mode data is not backfillable revenue, so it is out of scope unless that account turns out to hold live charges. Also note this closes CHK01 while [[CR18]]'s premise has moved on independently — a live restricted key (`rk_live_…`) now exists in Doppler `prd` as `STRIPE_SECRET_KEY`/`STRIPE_API_KEY`, which is what made this verification possible.

**Not affected:** the live checkout link generated for `team-inventoryai-io` in the same session already carries `metadata[org_id]`, `client_reference_id` and `subscription_data[metadata][org_id]` — they were set directly on that session, independently of this fix.

**Files:**
- `workers/sender-worker/src/stripe.ts`, `src/supabase.ts`, `src/index.ts`, `src/index.test.ts`

## [2026-08-06] - Billing-portal API-key 403 exercised in production (CR22)

> Migrated verbatim from `docs/BACKLOG.md` on 2026-08-22 (`/backlog-migrate`, append-to-1.3 decision). Heading normalised; body unchanged.

<a id="cr22"></a>

### CR22: The billing-portal API-key 403 — deployed 2026-07-30, but still not exercisable

**Priority:** P3 | **Source:** session 2026-07-27 late, follow-up to the `handleBillingPortal` auth change
**Estimated:** 15 minutes

**Context:** `handleBillingPortal` (`workers/api-gateway/src/routes/orgs.ts`) now rejects `int_live_…` bearer tokens with `403 "Billing portal requires a user session; API keys are not accepted"` instead of letting them fall through to `resolveJwt` and return an opaque `401`. Typecheck is clean and the worker suite passes 147/147, including a new case in `orgs.test.ts`.

Nothing is deployed. `api-gateway` deploys are manual (see [[CR02]]) and there are dev/prod variants, so the fix reaches production only when someone runs the deploy — and doing that here trips the hazard already recorded at the head of this section: **`deploy:prd` in `workers/api-gateway` must wait for [[CR13]] step 1**, or its `routes` key captures all of `/v1/*` from `obtool-api`. So this is blocked on CR13, not merely unscheduled.

Note the user-visible effect is currently nil either way: the portal cannot work at all until `STRIPE_SECRET_KEY` is bound ([[CR18]], [[CR12]]), and API-key routes are dead while `API_KEY_HMAC_SECRET` is unbound — meaning **no caller can reach the new 403 in production today**. This is a correctness improvement waiting behind the same credential work.

✅ **Exercised in production 2026-08-06, now that [[CR12]] bound `API_KEY_HMAC_SECRET`.** A real, correctly-HMAC-signed test key (deleted after) hit `POST /v1/orgs/:id/billing-portal` and returned exactly `403 {"error":{"message":"Billing portal requires a user session; API keys are not accepted"}}` — not the fabricated-key `401` this entry previously used to argue the path was unreachable. The 403 branch is live and correct.

**Status:** ✅ **Done — exercised and confirmed live 2026-08-06** (see the paragraph above; this line lagged it until 2026-08-22, the same table/body drift CR33 had). The rule that outlives it: the 403 fires only for a credential that *authenticates* as an API key and then fails the type check, so exercising it requires a valid HMAC-verified key — a probe with a fabricated key returns `401 {"error":{"message":"Invalid JWT format"}}`, which is [[CR23]]'s deliberate two-tier split working correctly. **Do not read that 401 as this fix having failed.**

## [2026-08-08] - Doppler CLI `secrets get` — premise refuted, measured behaviour documented (W07)

> Migrated verbatim from `docs/BACKLOG.md` on 2026-08-22 (`/backlog-migrate`, append-to-1.3 decision). Heading normalised; body unchanged.

### W07: Doppler CLI — `secrets get <missing-name> --plain` dumps the whole config instead of a clean error ✅

**Priority:** P3 | **Source:** session 2026-08-06, verifying [[CR12]]'s HMAC secret bind and [[CR18]]'s deleted key | **Resolved:** 2026-08-08
**Estimated:** 15 minutes to document; longer if a wrapper is wanted

> 🔴 **The premise is refuted. `secrets get <missing> --plain` does not dump anything — and the fix was to document what actually leaks, not what this entry claimed.**
>
> Tested on the **same binary** that produced the original observation: `doppler 3.76.1`, `/opt/homebrew/Cellar/doppler/3.76.1`, install receipt `2026-07-25T13:47:46`. That predates the 2026-08-06 sighting by twelve days and there is only one version in the Cellar, so **no upgrade intervened** — this is not "fixed upstream", it is "did not happen the way it was written down".
>
> Three probes, output captured to files so a repeat of the original exposure could not occur:
>
> | Command | Result |
> |---|---|
> | `secrets get STRIPE_API_KEY … --plain` (the exact command, on the exact deleted name) | exit 1, **stdout 0 bytes**, stderr `Could not find requested secret: STRIPE_API_KEY` |
> | `secrets get … --plain` with the name argument omitted | exit 1, `requires at least 1 arg(s), only received 0` |
> | **`doppler secrets --project … --config …`** (bare list, no `get`) | exit 0, **500 lines, values inline** — a known `CLOUDFLARE_D1_TOKEN` fragment was found in the output, and 138 of 175 names |
>
> So the command that dumps a config is the **list** form, which differs from the `get` form by the single word `get`. That is a real hazard and worth the documentation this item asked for; the specific fallback-on-miss behaviour it described is not real, and writing it into `CLAUDE.md` as stated would have planted a false gotcha in the one file that is auto-loaded into every session.
>
> **What the original session actually saw is not recoverable from here** — the transcript is gone and the exposure was real (a table of production values landed in tool output). The defensible record is: a whole-config dump happened, the `get` form is not what produces one, and the list form is.
>
> 📌 **Generalisable, and the reason this is worth more than a P3 correction: a bug report is a *claim*, and a claim about a tool's behaviour is testable.** This one sat for two days as an accepted premise with a documentation task attached. Reproducing it before writing the doc took three commands and inverted the finding. The repo has now recorded this shape several times from the other direction — a probe returning a uniform negative, an empty-list `200` read as access, a `DELETE … WHERE 1=0` read as write capability. This is the same rule applied to a *remembered* result rather than a live one: **re-run it before you document it.**

**What happened:** after deleting `STRIPE_API_KEY` from Doppler `prd` ([[CR18]] item 2), a follow-up `doppler secrets get STRIPE_API_KEY --project integrity-studio --config prd --plain` — run to confirm the deletion — did not return a clean "not found." It printed the **entire `prd` config as a formatted table**, every secret name and value, dozens of credentials unrelated to the one being checked. This happened in an automated context (an agent verifying its own change), so the full table landed in that session's tool-call transcript rather than a terminal a human was watching.

**Why this matters:** every other verification pattern in this file explicitly avoids printing secret values — `check-env-isolation.sh`'s own header comment states "compares hashes only — no secret value is printed, so it is safe to run in CI and paste output into a ticket." A plain `secrets get` on an existing-and-then-deleted name breaks that assumption silently: the command *looks* like a narrow, single-value read, and instead behaves like `doppler secrets` (list-all) on a miss. Nothing about the command's name or flags signals that fallback.

**The safe alternative, confirmed working:** `doppler secrets --project <p> --config <c> --only-names` (or piping through `grep -c <name>`) answers "does this slot exist" without ever emitting a value, and was used to complete the CR18 verification after the fact.

**Scope:**
1. ~~Document the gotcha in this repo's `CLAUDE.md` (or wherever Doppler CLI conventions are recorded) so the next person — human or agent — doesn't reach for `secrets get NAME --plain` to check existence.~~ — ✅ **done, with the corrected content.** `CLAUDE.md` § Secret Rotation now carries a three-row table of what each form prints on a miss, names `--only-names` as the existence check, and flags the bare list form as the one that dumps. It does **not** say `get` falls back to a dump, because it does not.
2. ~~Grep `scripts/*.sh` and any CI workflow for `secrets get .* --plain` patterns that assume a clean miss~~ — ✅ **done, both repos, and the result inverts the concern.** Fifteen `secrets get … --plain` call sites across `scripts/`, `.github/workflows/` and the toolkit's `dashboard/.github/workflows/deploy.yml`. **Zero uses of the bare list form**, so nothing in either repo can dump a config. Every `get` site is already written as `$(… 2>/dev/null || true)` *with a comment saying why* — `worker-signals.yml` and `ci.yml` both explain that they want the consuming script to decide whether to skip. Nothing to fix.
3. ~~Optional: a thin wrapper (`doppler-get-safe` or similar)~~ — ❌ **not built, and it would guard a hazard that does not exist.** A wrapper checking `--only-names` before `--plain` buys nothing once `get` is known to error cleanly on a miss. The exposure it was meant to prevent comes from the *list* form, which no script calls and which a wrapper around `get` would not intercept.

⚠️ **The one real defect in this area is the mirror image of the reported one, and it is documented rather than fixed because the current behaviour is deliberate.** `2>/dev/null || true` converts a missing slot into an **empty string**, so "never configured" and "renamed, revoked, or newly unreadable" are indistinguishable at the call site. That is a live failure mode, not a hypothetical: `observability-toolkit`'s `check-worker-signals.sh` shipped with a present-but-broken D1 token degrading to a NOTE while the job exited 0 — an expired credential would have switched a signal off behind a green check ([[W09]] records it). It now distinguishes the two (absent → skip, broken → exit 2) and `CLAUDE.md` names it as the pattern to copy.

**Status:** ✅ **Closed 2026-08-08 — premise refuted, documentation written to the measured behaviour.** No live risk existed and none was found; the exposure in the source session was real but is not produced by the command this item blamed. Steps 1 and 2 are done, step 3 is declined with a reason. What remains in the area is the empty-variable ambiguity above, which is tracked where it actually bites ([[W09]], and fixed in the toolkit's signals check).

## [2026-08-08] - `check:env-isolation` generalised — full-config sweep, six latent values fixed (W09)

> Migrated verbatim from `docs/BACKLOG.md` on 2026-08-22 (`/backlog-migrate`, append-to-1.3 decision). Heading normalised; body unchanged.

### W09: `check:env-isolation` passes while four cross-environment values sit outside its list ✅

**Priority:** P2 | **Source:** session 2026-08-07, pointing the toolkit e2e suite at dev ([[CR11]] step 7) | **Resolved:** 2026-08-08

> ✅ **Closed 2026-08-08. `CLOUDFLARE_D1_TOKEN` accepted and documented; six latent values fixed; the generalisable half built and mutation-proven.** Closing this item surfaced **five more** cross-environment values, one of which granted dev read of the entire production config — they were filed as W12 and ✅ **all five are fixed as of 2026-08-09**, with the detail in [`docs/changelog/1.3/CHANGELOG.md`](changelog/1.3/CHANGELOG.md) § W12. The transferable point survives the fix: this item passed for weeks while five names it had never heard of sat shared, because **a name the list does not mention is never measured**.
>
> **The acceptance is broader and better-founded than the row it came from.** The decision asked for was "accept `CLOUDFLARE_D1_TOKEN`". Measuring it against the whole config showed the token is not a special case but **one member of a class**: ten credentials are byte-identical across configs because the *resource they scope to is the account*, and there is one account. D1 has no per-database selector, Workers Scripts has no per-script selector, R2 and Pages tokens are account-scoped, `wrangler` OAuth is per-user, and an `sbp_` token spans every Supabase project. Accepting the D1 token alone while nine siblings sat unexamined would have been arbitrary. **What is accepted is the class, with the reason recorded per name in `scripts/check-env-isolation.sh`'s `ACCEPTED` map**, printed on every run so acceptance cannot decay into silence. The only remedy for any of them is separate accounts — the same conclusion [[CR11]] step 8 reached, now reached twice more independently.

### The six latent values, fixed 2026-08-08

Every one held a **production** identifier under `dev` while its unprefixed twin held the correct dev value — `VITE_AUTH0_DOMAIN`'s defect repeated for Supabase, KV and the home org. Verified by re-download afterwards: **`prd` byte-identical, zero names changed**, and the shared-byte-identical count moved 116 → 110, exactly the six.

| Value | Was (production) | Now (dev) |
|---|---|---|
| `VITE_SUPABASE_URL` / `REACT_APP_SUPABASE_URL` | `cfrbahzzklwrnmbtqojl` | `tumhmtshahktumhqqamk` |
| `VITE_SUPABASE_ANON_KEY` / `REACT_APP_SUPABASE_ANON_KEY` | production anon key | dev project's anon key |
| `CLOUDFLARE_KV_NAMESPACE_ID` | `902fc8a4…` (production dashboard KV) | `fc5bbe48…` (`DASHBOARD_DEV`) |
| `HOME_ORG_ID` | `f4286657…` | `12fc779f…`, documented in `obtool-ingest`'s `[env.dev]` as "the dev Supabase project's org" |

📌 **`HOME_ORG_ID` deserves a note, because two correct answers disagree.** `obtool-ingest`'s `[env.dev]` sets the dev org uuid; the dashboard's `[env.dev]` sets `""` deliberately, so that when P5 org resolution lands an empty value **fails loudly rather than silently resolving a production org**. Both are right for their surface. The Doppler slot got the dev uuid rather than the empty string because a `doppler run -c dev` consumer wants a usable dev value, and because the dashboard binds its own var and never reads Doppler for this name. The dashboard's empty binding stands untouched.

### The generalisable half — built, not argued

The item said this three times: *"extend it to compare **every** name present in both configs and classify rather than hash-compare a fixed list."* That is now the second half of `scripts/check-env-isolation.sh`, and **the polarity is inverted**: instead of asking "do the names I listed differ?", it asks "of every byte-identical shared name, is each one legitimately shared?" **An unclassified name fails.** New names default to visible instead of invisible — which is the entire defect this item documented, since all six values above were invisible for exactly as long as no list named them.

Current reading (2026-08-09, after the W12 fixes): **167 shared, 105 byte-identical, 95 shared by design, 10 accepted, 0 known gaps, 0 unclassified — exit 0.** `KNOWN_GAP` is deliberately retained as an **empty map**: that asserts "no known-wrong shared values", where deleting the concept would assert nothing and push the next real gap toward `SHARED_BY_DESIGN`, converting a printed defect into a silent pass.

**Mutation-proven, not merely observed passing.** Dropping one legitimately-shared name (`ANTHROPIC_API_KEY`) out of the allowlist made it resurface as `UNCLASSIFIED` and the script exit **1**; restoring it returned the file byte-identical and the exit to **0**. The six fixed names are *also* pinned into the original `SECRETS` list, so a regression trips two independent detections — the sweep's allowlist is itself editable, and a check whose only guard is a list someone can edit has one failure mode too few.

⚠️ **The sweep skips loudly, never quietly.** If either config fails to download it prints `DEGRADED run, not a pass` and contributes nothing to the count — because a classification pass that silently covers zero names, while the list-based rows above still print `ok (distinct)`, would read exactly like a clean bill of health. That is this item's own hollow-green failure mode, and the toolkit's signals check shipped with it once already.

[[CR11]] is closed on the strength of `npm run check:env-isolation` exiting 0. That result is true and much narrower than it reads: `SECRETS` in `scripts/check-env-isolation.sh` names **15** credentials, and standing up the dev e2e path found **four** cross-environment values in Doppler `dev` that it does not look at. The item's own caveat already said "a green run proves only what the list names" — this is that caveat with four concrete instances, which is the difference between a warning and a finding.

| Value | What it was | State |
|---|---|---|
| `PROVISION_WORKER_URL` | the **production** sender — so `sender-receiver` and `provision-key` e2e created real users and API keys in production on every local run | ✅ fixed → `sender-worker-dev` |
| `KV_NAMESPACE_ID` | production's `AUTH` namespace — a dev `api-keys-create` would have minted keys into the namespace production authenticates against | ✅ fixed → `AUTH_DEV` (`0b323a37…`) |
| `VITE_AUTH0_CLIENT_ID` | production's SPA client (`CNfd6…`), byte-identical in both configs and **nonexistent in the dev tenant**, so every dev ROPC mint returned `access_denied` | ✅ **fixed 2026-08-08** → `w4KMCpBA…`, a dev-tenant SPA provisioned for this |
| `VITE_AUTH0_DOMAIN` | the **production** tenant, while `AUTH0_DOMAIN` in the same config held the dev one — a split-tenant `dev` config | ✅ **fixed 2026-08-08** → `dev-njjmghdzm23uy0p7` |
| `AUTH0_TENANT_NAME` | production's tenant, and read by no code in either repo. Deliberately repointed at production during [[CR01]]'s recovery, when leaving no dev-tenant value in either config was the goal — correct then, stale once the dev tenant became legitimate | ✅ **fixed 2026-08-08** → `dev-njjmghdzm23uy0p7` |
| `CLOUDFLARE_D1_TOKEN` | not two equal values but **one token object** (`3a227938`, `tcad-d1-query`) in both configs, carrying **D1 Write over the whole account** — so a `--config dev` script can `DROP TABLE` production telemetry | ✅ **ACCEPTED 2026-08-08**, with nine account-scoped siblings — scoping is structurally impossible, so the only remedy is separate accounts. Recorded in the `ACCEPTED` map and printed every run |
| `INJECT_HMAC_SECRET` | **byte-identical**, and *proven* to authenticate against the production evaluations webhook — found 2026-08-08 | ✅ **rotated in `dev` 2026-08-08**, see below |

**The generalisable half, and the reason this is P2 rather than a footnote: endpoint URLs are as load-bearing as credentials.** Three of the four are not secrets at all — two URLs and a public client id — and `PROVISION_WORKER_URL` did the most damage of any of them. A perfectly-scoped dev credential aimed at a production endpoint is the same defect as a shared credential, and the detector is built to catch only the second. Extend it to compare **every** name present in both configs and classify rather than hash-compare a fixed list, or at minimum add the `*_URL` / `*_NAMESPACE_ID` / `VITE_*` / `CLOUDFLARE_*` families.

⚠️ Two things to know before editing that script. The slot really is spelled **`SUPABASE_INTEGRITY_MEMERSHIP_KEY`** ("MEMERSHIP") in Doppler — verified present in both configs at 41 chars; the correctly-spelled name exists in neither, so "fixing" the typo in `SECRETS` would silently create the phantom row this file already documents. And a name absent from both configs reads as "UNSET in both", which is not evidence of isolation — it is the failure mode that hid `SUPABASE_PROVISIONING_KEY` for a week.

✅ **The Auth0 half is fixed, 2026-08-08 — and it could not be fixed one name at a time.** `VITE_AUTH0_DOMAIN` alone would have produced a *mixed* pair (dev domain + a production client id that does not exist in the dev tenant), which is worse than the consistently-production pair it replaced: the dashboard SPA needs domain and client from the **same** tenant. So the fix was to provision what was missing — `integritystudio-dashboard-dev` (`w4KMCpBA…`), `app_type: spa`, callbacks on `http://localhost:5173`, and **`authorization_code` + `refresh_token` only**. No `implicit` and no `password`, deliberately: adding ROPC to a new public client would recreate exactly what [[CR34]] stripped and what `observability-toolkit`'s `SIGNIN-WORKER` is waiting to remove.

**This had become an active breakage, not untidiness.** Once `DEV_WORKER_URL` was repointed at `quality-metrics-api-dev` — which verifies against the dev tenant's JWKS — a local dashboard build under `--config dev` was minting **production**-tenant logins that the dev API could only reject. The two names disagreeing was survivable while both ends were production; it stopped being survivable the moment one end moved.

**Detector extended and mutation-verified.** `VITE_AUTH0_DOMAIN`, `VITE_AUTH0_CLIENT_ID` and `AUTH0_TENANT_NAME` are now in `SECRETS`: 15 → 18 credentials, `PASS` (exit 0). Proven to actually detect rather than merely pass — restoring the old production value made it report `SHARED WITH PRODUCTION` and exit **1**, then restoring the dev value returned it to exit 0. `VITE_AUTH0_AUDIENCE` is deliberately **excluded**: an Auth0 API identifier is just a name and each tenant registers its own, so it is legitimately byte-identical, and adding it would manufacture a permanent failure that trains the reader to ignore the check.

⚠️ **Two things this does not cover.** `dashboard/e2e/integration/setup.ts` mints ROPC through `VITE_AUTH0_CLIENT_ID`, which now refuses the password grant — but that suite already could not run under `dev`, because it also requires `SUPABASE_SERVICE_ROLE_KEY`, a slot that exists in neither config (the [[CR01]] finding). When it is revived, point it at the confidential `integrity-dev-ropc` (`AUTH0_CLIENT_ID`) as `observability-toolkit`'s `provision-key.e2e.ts` already does, rather than re-adding ROPC to the SPA. And the generalisable half below is still only half-answered: three names were added to a fixed list, which is not the same as classifying every name present in both configs.

🔴 **A sixth instance, in a config store this detector cannot see (2026-08-08).** `~/.claude/settings.json`'s `OTEL_EXPORTER_OTLP_HEADERS` carried a **dev** API key while `OTEL_EXPORTER_OTLP_ENDPOINT` in the same block pointed at **production** ingest. Probed as a pair: `200` against `obtool-api-dev`, `401` against `api.integritystudio.ai` — the credential and the endpoint it shipped to belonged to different environments. Fixed to match `OBTOOL_API_KEY` (now 200 prod / 401 dev).

Two things this adds to the item rather than merely repeating it:

1. **`check:env-isolation` compares Doppler `dev` against Doppler `prd` and nothing else.** This value lives in a gitignored local settings file, so it was outside the detector by construction — not a gap in the list, a gap in the *sources* the list is drawn from. Any host-local config that carries a credential (settings.json, `.envrc`, a shell profile) is a place a dev key can point at production unobserved.
2. **It was harmless only by accident, and the accident was in the consumer.** `otlpAuthHeaders` gives `OBTOOL_API_KEY` precedence, so the hand-rolled shipper never used the bad header. But the OTel SDK exporters read `OTEL_EXPORTER_OTLP_HEADERS` natively and know nothing about `OBTOOL_API_KEY` — any SDK-based export inheriting that env would have sent a dev key to production and 401'd silently. **Reasoning from precedence said "safe"; the capability probe said "wrong environment".** That is this item's own rule, met again: assert on what the credential can reach.

✅ **That sixth instance is now runtime-detectable** (`~/.claude` `17a54a00`). `describeOtlpCredentialConflict()` reports when an `OTEL_EXPORTER_OTLP_HEADERS` bearer disagrees with `OBTOOL_API_KEY`, naming the variables and never the credentials, and the shipper warns on it. Verified against the real pre-fix config, not a fixture: it fires there and is silent once corrected.

**What that does and does not buy this item.** It catches *this* shape — two credentials configured for one endpoint that disagree — wherever the shipper runs, including config stores `check:env-isolation` cannot see. It does **not** catch a single credential pointed at the wrong environment, which is the more common form here and the one `CLOUDFLARE_D1_TOKEN` still has: with nothing to disagree with, there is no conflict to detect. That still needs the capability probe this item keeps arriving at — assert what the credential reaches, not whether two values differ.

🔴 **`INJECT_HMAC_SECRET` was shared, and unlike the URLs it was *proven* to reach production (2026-08-08).** Found by finally doing what the "generalisable half" above asks for — comparing **every** name present in both configs instead of the hand-maintained list. That comparison is now a number: **170 shared names, 117 byte-identical.** Most are legitimately shared (Anthropic, OpenAI, Sentry, Porkbun — third-party keys with no dev/prd notion), which is exactly why a full-config comparison has to *classify* rather than fail on identity.

Four of the 117 are not legitimate, and they split cleanly by whether anything reads them:

| Value | Reaches | Readers today |
|---|---|---|
| `INJECT_HMAC_SECRET` | **production evaluations webhook — proven** | `obtool-ingest` (prod + dev), toolkit e2e |
| `CLOUDFLARE_D1_TOKEN` | production D1 | toolkit ops scripts |
| `CLOUDFLARE_KV_NAMESPACE_ID` | `902fc8a4…`, the **production dashboard KV** (dev's is `fc5bbe48…`) | none in either repo |
| `VITE_SUPABASE_URL` / `REACT_APP_SUPABASE_URL` (+ `_ANON_KEY` twins) | production project `cfrbahzzklwrnmbtqojl`, while the unprefixed `SUPABASE_URL` is correctly dev | none in either repo |

The last two are the `VITE_AUTH0_DOMAIN` defect repeated for Supabase and KV — **a prefixed twin holding production while the unprefixed name holds dev.** Latent rather than live only because nothing reads them, which is not a property to rely on: `PROVISION_WORKER_URL` was latent in exactly this way until a suite started using it.

`HOME_ORG_ID` is byte-identical too (production's `f4286657-…` under `dev`). Also unread today — but `observability-toolkit`'s `ORG-VARS-THIRD-WORKER` deliberately left `quality-metrics-api-dev` empty rather than copy that UUID, so `doppler run -c dev` would hand a future reader precisely the value that item refused to hardcode.

✅ **Rotated in `dev` 2026-08-08, and verified by capability rather than by the values differing** — a 2×2 matrix run to steady state, using a body that fails `JSON.parse` *after* signature verification, so a valid signature returns 400 and nothing is ever persisted:

| signing key → target | `obtool-ingest-dev` | production |
|---|---|---|
| **new** `dev` secret | **400** (accepted) | **401** (rejected) |
| `prd` secret (= the old shared `dev` value) | **401** (rejected) | **400** (accepted) |

Both diagonals matter: the top-right is the gap closing, and the bottom-left proves the old value is genuinely revoked in dev rather than merely superseded in Doppler. Production is untouched — `prd`'s slot was never written, confirmed by hash before and after. Bound to `obtool-ingest-dev` with `wrangler secret put --env dev`; the toolkit's `wrangler.toml` already documents that re-upload command.

⚠️ **The first reading of this matrix was wrong in both directions, and the probe is why.** An initial run returned 401 for *every* cell — the `openssl dgst` output on this machine carries no `(stdin)=` prefix, so `awk '{print $2}'` produced an empty signature and the endpoint rejected everything. A uniform negative is what a broken probe looks like, which this repo has now recorded five times. The next run then caught Cloudflare mid-rollout, with the dev Worker answering from two versions at once — new secret rejected on one sample and accepted on the next. **Neither a uniform result nor a single sample is a measurement**; the table above is the steady state across four consecutive samples.

### `CLOUDFLARE_D1_TOKEN` measured 2026-08-08 — the row understated it, and the fork it offers is already closed

**It is not "byte-identical values", it is one credential.** Both configs resolve to the *same token object*: id `3a227938fa953d76aa8ead731cdbb5c4`, name **`tcad-d1-query`**, `status=active`, issued 2026-08-06, **no expiry**. Rotating one config cannot produce a second token; there is nothing to rotate *to* without minting. (The inventory under [[CR11]] step 8 already had this row — `3a227938 | tcad-d1-query | CLOUDFLARE_D1_TOKEN, both configs` — so the two entries were describing one fact from different ends without meeting.)

📌 **Its name is not this system's.** `tcad-d1-query` was minted for TCAD (`tcad-api`, `tcad-token-refresh` on the same account), and is what now reads and writes `obtool-telemetry-db`. A third project's credential is the one holding production telemetry.

**Policy read directly** (via `prd`'s `CLOUDFLARE_GLOBAL_API_KEY` = `cloudflare_platform_token` `6d51c3d8`, the one credential here carrying Account API Tokens Write):

```
resources: { com.cloudflare.api.account.b3868dd0…: "*" }
perms:     D1 Metadata Read, D1 Read, D1 Write
```

**Capability probed rather than inferred**, and the write half proven with controls on the **dev** database only — absent → `CREATE TABLE` → confirmed in `sqlite_master` → `INSERT` → read back `42` → `DROP` → confirmed gone. Nothing was written to production; it did not need to be, since the same token reads production D1 and enumerates every database, so the resource scope is account-wide and the proven DDL reaches both.

| Surface | Result |
|---|---|
| D1 `SELECT` on **production** `e93f19eb…` | 200 |
| D1 `SELECT` on dev `9c34333f…`, list **all** databases | 200 |
| D1 DDL + DML (proven on dev) | CREATE / INSERT / DROP all succeed |
| Workers scripts / R2 / KV | 403 / 403 / 401 |
| Zones | **200 with an empty list — scoped, NOT zone access** |

⚠️ **That last row is the probe trap again.** A bare `200` reads as access; an empty `result` is exactly what a correctly-scoped token returns. Reporting the status code alone would have manufactured a zone-access finding that does not exist — the mirror image of the uniform-negative failure recorded twice above. **Read the body, not the code.**

🔴 **The row's fork — "scope a dev D1 token *or* accept and document it" — has only one arm. Scoping is impossible.** All three D1 permission groups, out of 386 on the account, carry `scopes: ['com.cloudflare.api.account']` and nothing finer; there is no per-database resource selector to scope to. This is [[CR11]] step 8's structural ceiling in a second product: **Workers Scripts has no per-script selector, D1 has no per-database selector, and no token can fix either.** So the remaining options are (a) accept and document, or (b) separate Cloudflare accounts — the same answer CR11 reached, and worth writing down here so this is not re-attempted as a token-minting task.

⚠️ **A first pass at this concluded the policy was unreadable** — `prd`'s general `CLOUDFLARE_API_TOKEN` returns `9109 Unauthorized` on both the token-read and permission-groups endpoints — and was about to record "cannot be determined from this machine". It was determined; the credential that could do it was already inventoried under CR11 four rows above the one being investigated. **The account inventory in this file is a working index, not just a record — read it before concluding a capability is absent.**

📌 **This session moved the token in the wrong direction, stated because it is easier to find now than later.** `observability-toolkit`'s new `worker-signals.yml` reads `CLOUDFLARE_D1_TOKEN` from Doppler `prd` on a daily schedule, so as of 2026-08-08 this credential also flows into GitHub Actions. Correct for that check's purpose — SIGNAL 4 needs D1 read, and the general token gets `7403` there — but it adds a consumer to an unscoped account-wide write token while this item is open. Note also that **every code consumer is in `observability-toolkit`** (`scripts/check-worker-signals.sh`, `worker-signals.yml`, `docs/reliability/ingest-recovery-runbook.md`); this repo, where W09 tracks it, has none outside this file.

✅ **Read-only token minted and wired 2026-08-08.** `obtool-d1-readonly` (`4a417b249408fff1f3dabe8c689a3f1d`), D1 Read + D1 Metadata Read, **no D1 Write**, stored as `CLOUDFLARE_D1_READ_TOKEN` in Doppler **`prd` only** — so unlike the credential it replaces on that path, it is *not* shared with `dev`. The toolkit's `check-worker-signals.sh` prefers it and falls back to `CLOUDFLARE_D1_TOKEN` only if it is absent; proven in CI, not just locally (toolkit run `31276746747` returned live watermark rows rather than the absent-token NOTE).

**Verified with paired controls:** `SELECT` on the **production** database succeeds, while `INSERT` and `CREATE TABLE` both return `7500 You do not have permission`. The write token's identical `INSERT` succeeded as the positive control (`changes=1`) and was reverted — dev's `batch_watermark` went 8 → 9 → 8 rows.

⚠️ **One probe result worth carrying forward: a write-shaped statement that touches no rows is PERMITTED.** `DELETE FROM batch_watermark WHERE 1=0` returned `success` with `rows_written=0` on the read-only token. The first negative control used exactly that form and so appeared to show the token could delete — it could not. **A no-op is worthless as a proof of write capability**; test with a statement that actually affects a row. This is the same family as the empty-list `200` above: the response body decides, not the shape of the request or the status code.

**What this does and does not buy.** It removes account-wide D1 **Write** from the one path that runs daily and unattended, which was the cheap part. It does **not** narrow *read* — no per-database selector exists — so the daily job still reads every D1 database on the account, and it does nothing about `CLOUDFLARE_D1_TOKEN` itself, which remains shared, unexpiring and account-wide-write for the runbook's rewind path (now flagged inline in `docs/reliability/ingest-recovery-runbook.md`, since a rewind run under `--config dev` reaches production).

📌 **A defect in the new check was found by wiring this up, and fixed:** a D1 token that was *present but broken* degraded to a NOTE and the job still exited 0 — so an expired credential would have switched SIGNAL 4 off while the alert stayed green. That is precisely the hollow-green failure the check exists to catch, reproduced inside it. Now only an **absent** token skips; a present-but-failing one exits 2. Mutation-verified across all three paths.

**Status:** ✅ **Closed 2026-08-08 — all 7 listed values resolved, the generalisable half implemented, and `CLOUDFLARE_D1_TOKEN` accepted as one of a ten-member class.**

- **6 of 7 fixed.** The four original values, plus `INJECT_HMAC_SECRET` (rotated in `dev`, proven by a 2×2 capability matrix rather than by the values differing), plus six further latent ones found by the sweep and repointed the same day.
- **The 7th accepted, with its reason recorded in code.** Per-database scoping is impossible — all three D1 permission groups are account-scoped, out of 386 on the account — so this was never a minting task. `obtool-d1-readonly` had already removed account-wide **write** from the one path that runs daily and unattended; what is accepted is the residue: `CLOUDFLARE_D1_TOKEN` stays shared, unexpiring and account-wide-write for the runbook's rewind path, flagged inline in `docs/reliability/ingest-recovery-runbook.md`. **Revisit only if the account topology changes**, since separate Cloudflare accounts are the sole remedy.
- **The generalisable half is implemented, not measured.** It was "170 shared names, 117 identical, 4 illegitimate, found by an ad-hoc script". It is now a classification pass inside `check:env-isolation`, where an unclassified shared name **fails**, mutation-proven in both directions.

⚠️ **What closing this cost, and it is the honest headline: the sweep found five more.** One was a `dp.st.prd.` Doppler service token in the `dev` config — a credential that reads the entire production config, i.e. the isolation boundary this item spent two days building. It was invisible to every check here until the polarity was inverted. ✅ All five were fixed 2026-08-09 (detail in [`docs/changelog/1.3/CHANGELOG.md`](changelog/1.3/CHANGELOG.md) § W12), so the environments *are* now isolated on every name the detector can see — but the lesson stands unchanged: **this item's closure never meant the environments were isolated; it meant the detector could finally see what was not.**

## [2026-08-08] - Playwright suite silent for two months — disabled workflow diagnosed, SIGNAL 6 added (W11)

> Migrated verbatim from `docs/BACKLOG.md` on 2026-08-22 (`/backlog-migrate`, append-to-1.3 decision). Heading normalised; body unchanged.

### W11: the Playwright suite did not run for two months, and two tests silently went stale ✅

**Priority:** P2 | **Source:** session 2026-08-08, PR #23 CI

`e2e.yml` last ran green on `a51daef`, **2026-06-09**. Its next run was **2026-08-08** — and it
failed. Inside that two-month gap, `f439651` (2026-07-26, *"fix(gdpr): gate Meta Pixel on
marketing consent"*) removed the unconditional pixel `<script>` and its `<noscript><img>` from
`web/index.html`, moving injection behind `if (prefs.marketing)` (`lib/app.dart:55`). The commit
updated the **GTM** test to match but not the two **pixel** tests, which went on asserting the
pre-GDPR behaviour — *requiring the privacy fix to be absent*.

✅ **The two tests are fixed** (this branch): the pixel case became three — no consent, marketing
consent, analytics-only — because the gate is on `marketing` specifically and the third case is
what separates "gated on marketing" from "gated on any consent". The noscript assertion is
inverted to assert **absence**, since a noscript pixel fires for every visitor with no way to
gate it. Negative cases wait out `GTM_INJECT_SETTLE_MS` or they pass merely because injection
has not happened yet.

🔴 **The gap itself is the item, and it is not fixed.** A stale test is a small cost; a suite
that stops running is what let it stay stale for 13 days after the change and would hide the
next one just as well. **Establish why there were no runs between 06-09 and 08-08** — the two
candidates are that `e2e.yml` is effectively schedule-driven and GitHub suspended it (the same
~60-day cron suspension already flagged under [[CR20]] as a second-order risk to
`worker-signals.yml`), or that no qualifying push reached `main` in the window. Those want
different fixes, so measure before choosing. Related in kind to `observability-toolkit`'s
`E2E-PERMANENT-SKIPS`: **a test suite that cannot run and a test suite that is gated off are the
same defect wearing different clothes, and neither shows up as a red build.**

**Also noted, not changed:** `e2e/tests/web-platform.spec.ts:67` — the pre-existing
`GTM script is NOT injected before consent` test has no settle wait, so it is vulnerable to the
same vacuity. Left alone deliberately: it passes today, and changing it could fail a PR on an
unrelated pre-existing issue. One line when someone wants it.

### Diagnosed 2026-08-08 — and BOTH recorded candidates are wrong

The gap was not cron suspension and not a lack of qualifying pushes. **The workflow was
disabled.** Measured over the exact window 2026-06-10 → 2026-08-07, same repo, same branch,
same pushes:

| Workflow | Runs in the gap |
|---|---|
| `ci.yml` | **71** |
| `e2e.yml` | **0** |

That pair refutes both candidates at once. Cron suspension stops only `schedule` events, and
`e2e.yml` is missing its `push` runs too — while `ci.yml`, which triggers on the same pushes to
`main`, ran 71 times. And "no qualifying push reached `main`" is contradicted by **~270 commits**
across 18 active days in the window (06-26, 06-27, 07-01, 07-12, 07-14, 07-17, 07-25, then daily
from 07-26). The repo was never inactive for 60 days either — the longest quiet stretch after the
last e2e run is **17 days**, so `disabled_inactivity` cannot apply. Run history resumes on
2026-08-08 with one `schedule` run and then `push` runs, i.e. it was re-enabled.

🔴 **A disabled workflow is the quietest failure in either repo.** No runs, no failures, no
notifications — there is nothing to alert on, because nothing happens. It is invisible to every
technique this file has accumulated: error rate, subrequest count, watermark freshness and skip
counts all presuppose that *something ran*. The only symptom was two Playwright tests going stale
for 13 days, and those were found by reading, not by a check.

✅ **Fixed: `scripts/check-workflows-active.sh`**, wired as **SIGNAL 6** and documented in
[`docs/observability-signals.md`](observability-signals.md). It asserts every `.yml`/`.yaml` on
disk under `.github/workflows/` reports `state: active`, and it is deliberately the **first** step
of `worker-signals.yml` — ahead of Doppler — because a check that catches checks which have
stopped running must not sit behind a credential path that can itself fail
(`check-worker-signals.sh` exits 0 early when Cloudflare credentials are absent, and folding this
into it would have inherited that). `permissions: actions: read` is the only grant added.

**It watches the files, not a list.** Adding a workflow enrols it automatically; deleting one
retires it. A pinned list needs editing on every change, which is how a guard decays into a
formality — the same reasoning as the toolkit's skip-count guard asserting on skips rather than
pinning `passed == 46`.

**Mutation-proven in six states, because a check that has never failed is not known to work:**
all-active → exit 0 (against the live repo); `disabled_manually` → exit 1 naming the file;
`disabled_inactivity` → exit 1; HTTP 401 → exit 2; non-JSON body → exit 2; absent `GH_TOKEN` →
skip with exit 0. A workflow on disk but unregistered (a feature branch, or a new file) is a
**NOTE**, not a breach.

📌 **It partly watches its own host.** `disabled_inactivity` is the state [[CR20]] flags as a
standing risk to `worker-signals.yml` itself, and this signal breaches on it — so the alert can
now report its own impending silence, for every cause except being disabled at the same moment.
That residual is irreducible from inside the repo: nothing running in GitHub Actions can detect
that GitHub Actions is not running it. An external heartbeat is the only complete answer, and none
is proposed here.

**Status:** ✅ **Closed 2026-08-08** — stale tests fixed earlier; the run gap is diagnosed
(workflow disabled, both candidates refuted) and a guard now fails the daily job on any non-active
workflow. The `web-platform.spec.ts:67` settle-wait note below is unchanged and still open as a
one-line cleanup.

## [2026-08-08] - Provisioning replay-protection nonce store — already built, then finished right (W06)

> Migrated verbatim from `docs/BACKLOG.md` on 2026-08-22 (`/backlog-migrate`, append-to-1.3 decision). Heading normalised; body unchanged.

### W06: Provisioning — nonce store for sub-window replay protection

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

🔴 **Steps 1–3 are ALREADY IMPLEMENTED and this entry did not know it — measured 2026-08-06 by reading the receiver source.** `services/api-provisioning-receiver/src/nonce.ts` exists and `src/index.ts:122-128` calls it on every `/inbox` request. So the "design decision" this item has been parked on was settled in code some time ago: **signature dedup in KV**, not a Durable Object, not a separate nonce header. `checkAndStoreNonce` keys on the request signature (`nonce:<sig>`), returns 401 `REPLAY_DETECTED` on reuse, and `NONCE_TTL_SECONDS` is derived as `ceil(REPLAY_WINDOW_MS / TIME_MS.SECOND)` — so step 3's "TTL ≥ replay window" is satisfied *by construction* rather than by a constant someone has to keep in sync. Scope items 1, 2 and 3 are done; `workers/sender-worker/src/` needed no change because the signature is reused rather than a nonce emitted.

**What is actually still open is the part the audit note warned about, and it was not heeded.** The nonce store went into **exactly** the shared namespace the note said to avoid. Verified 2026-08-06 by diffing the two configs — they are byte-identical, `preview_id` included:

| Config | binding | `id` |
|---|---|---|
| `services/api-provisioning-receiver/wrangler.toml:32-35` | `RATE_LIMIT_KV` | `cf9d7d72bb07488faab8187ceb3589d4` |
| `workers/contact-form/wrangler.toml:28-31` | `RATE_LIMIT_KV` | `cf9d7d72bb07488faab8187ceb3589d4` |

So production `integrity-studio-contact` and the provisioning receiver now share one namespace across **three** key conventions — contact-form's `rate_limit:${ip}` and `idempotency:${key}`, plus the receiver's `nonce:<sig>`. The `nonce:` prefix does prevent a literal key collision (the note's narrow worry), so this is not corrupting data today; the real cost is that two unrelated services' security state shares a blast radius, and a namespace-wide operation (purge, quota exhaustion, accidental unbind) hits both. ⚠️ The audit note's closing caveat — "I could not confirm whether the receiver's own rate-limit keys collide with contact-form's because `observability-toolkit` was not available to read" — **is now answerable and the answer is no collision**: the receiver's rate limiter uses `enforceRateLimit(env.RATE_LIMIT_KV, "ip"|"email", …)`, a different prefix again.

🟠 **Second finding, not previously recorded: all three checks fail OPEN.** The nonce check, and both receiver rate-limit calls, are each wrapped in `if (env.RATE_LIMIT_KV)`. If that binding is ever absent or misnamed, `/inbox` silently loses replay protection *and* rate limiting while still returning 200 — no error, no audit event, nothing to alert on. That is the same failure shape as [[CR29]]'s keyless downgrade and [[W04]]'s "succeeded while making no outbound calls": the degraded path is indistinguishable from the healthy one from outside. Worth deciding deliberately whether an unbound `RATE_LIMIT_KV` should fail closed (503) or at minimum emit an audit event, rather than being an untracked silent default.

**Revised scope — what is left:**
1. ~~Add a per-request nonce…~~ ✅ done in code (`nonce.ts`, signature dedup).
2. ~~Reject `/inbox` requests whose nonce has already been seen~~ ✅ done (401 `REPLAY_DETECTED`).
3. ~~Confirm TTL ≥ replay window~~ ✅ done, derived rather than hardcoded.
4. ~~Provision a dedicated KV namespace for the receiver~~ ✅ **done 2026-08-08**: namespace `7ab3fb981d5b4ea186c348acd1e03590` provisioned; `wrangler.toml` updated. `cf9d7d72…` is now contact-form's namespace only.
5. ~~Decide the fail-open question above~~ ✅ **done 2026-08-08**: fail closed. The three `if (env.RATE_LIMIT_KV)` guards are replaced by a single early-return 503 + `alert.check_failed` audit event. An absent binding is now detectable in Sentry rather than a silent degradation.

**Status:** ✅ **Complete 2026-08-08.** All five scope items are done. Receiver-side changes are in `observability-toolkit` repo (commit `bb2228b` on `main`; Worker deployed to production, version `1564a7e7`).

## [2026-08-09] - Provisioning workers — monitoring, alerting & dashboards, scheduled run observed (W04)

> Migrated verbatim from `docs/BACKLOG.md` on 2026-08-22 (`/backlog-migrate`, append-to-1.3 decision). Heading normalised; body unchanged.

### W04: Provisioning workers — monitoring, alerting & dashboards ✅

**Priority:** P2 | **Source:** session 2026-06-27, reconciled from provisioning setup notes (now consolidated into `docs/provisioning-environment-setup.md`) — open items "Monitoring and alerting — must implement", "Monitoring Dashboards — Cloudflare Analytics"
**Estimated:** 4–6 hours

**Context:** there is **no alerting and no dashboard** for the provisioning path (`sender-worker` → `api-provisioning-receiver`). The setup summary flagged this as "must implement" but it was never tracked as a real item. `api-provisioning-receiver` lives in the `observability-toolkit` repo, so end-to-end provisioning observability spans both repos.

> **⚠️ Audit 2026-07-27 — this item's premise was wrong.** It previously opened "`sender-worker` has `[observability.logs]` with `invocation_logs = true` … **so logs are captured**". They were not. The deployed worker reported `observability: {"enabled": false, logs: {"enabled": true, …}}` — the parent `enabled` flag was never set, which silently disables the whole block regardless of the child tables ([[CR15]]). Worse, the **other five Workers had no `[observability]` block at all**, so the repo had essentially no telemetry anywhere. Step 2 was not "logs exist, add a dashboard"; it was starting from nothing.

**✅ Step 0 done (2026-07-27) — instrumentation now exists in config.** All six Workers declare `[observability]` with the required parent `enabled = true`, plus `logs.enabled`, `invocation_logs`, and `traces.enabled`, at **both** the top level and under `[env.dev]` (a named environment *replaces* the parent block rather than merging into it, so it must be repeated). Guarded by 18 new assertions in `workers/lib/deploy-environments.test.ts`, mutation-verified: removing the parent flag, disabling logs, dropping `invocation_logs`, or deleting the `[env.dev]` block each fails the suite. All 12 configurations validate under `wrangler deploy --dry-run`. **✅ Now live on all four deployed Workers as of 2026-07-30** — `api-gateway`, `sender-worker`, `integrity-studio-contact`, and `stripe-webhook` each report `enabled=True logs=True traces=True`, verified per Worker via `GET .../scripts/{name}/settings` after deploying. `api-gateway` and `integrity-studio-contact` had **never** emitted a log or a trace before this. The two undeployed Workers (`bootstrap-worker`, `receiver-worker`) are unaffected because neither exists in production.

What this unblocks, and what it does not: the signals in step 1 will exist once deployed, so steps 2–4 become real work rather than speculation. It does **not** by itself produce a dashboard or an alert.

**Correct target for this work:** route through `ingest.integritystudio.ai` / `observability-toolkit`, as step 2 already suggests. That is Integrity Studio's **internal** OTEL pipeline and is the right destination for worker self-monitoring. Do **not** redirect it to `api-gateway`'s `/v1/ingest/otel`, which is the **customer-facing** ingestion path — see [[CR16]] for why the two are separate.

**Scope:**
1. ✅ **Done** — enable observability on every Worker so there is something to observe (see Step 0 above). Deploy to make it live.
2. ✅ **Done 2026-07-31 — signals defined in [`docs/observability-signals.md`](observability-signals.md) and made executable as `npm run check:worker-signals`** (`scripts/check-worker-signals.sh`, following the `check:env-isolation` / `check:migration-drift` pattern: exit 0 within threshold, 1 on breach, 2 on prerequisite failure, `SKIPPED` + exit 0 without credentials).

   Defining these in prose alone is how they go stale, so each is computed rather than described. **Six** are implemented — unhandled exceptions, the cron no-op detector, resource exhaustion, cross-repo receiver health (reported, never failing the build, since this repo cannot fix it), dead-letter queue depth, and **workflow state** (SIGNAL 6, added 2026-08-08 with [[W11]]: every workflow on disk must be `active`, run by a separate credential-independent script). Five are named as **not** implemented so they are not mistaken for covered: the `/send` error-code split, receiver 401 spikes, provisioning latency, Auth0/Supabase call failures, and the auth 429 rate. The first needs a counter emitted from the Worker — `ERROR_CODE.RECEIVER_ERROR` vs `INTERNAL_ERROR` vs the 502 path is distinguishable only in the response body, which neither Cloudflare telemetry source records.

   > **⚠️ Do not build this on error rate alone — measured 2026-07-31, [[CR20]] step 4.** Throughout those four months the cron reported `status: success` with `errors: 0` on every one of ~96 daily invocations, because the Supabase client threw on unbound secrets and `fetchPendingDeadLetters` swallowed it into `[]`. The only telemetry that distinguished broken from working was **`subrequests`**, which sat at exactly 0 until secrets were bound and then rose to 1.00 per invocation. Any alert designed around errors or invocation count would have stayed green for the entire outage. The signature to watch for, here and on any future cron, is **"succeeded while making no outbound calls"**.

   **One caveat that will otherwise produce a wrong dashboard in step 3.** The two Cloudflare sources disagree. For `integrity-studio-contact`, GraphQL reported 34 invocations and 3 `scriptThrewException`, while a Workers Logs query over **72 hours** returned 10 events and no exception at all. Workers Logs only captures from the moment `observability` was enabled — the 2026-07-30 deploy for `api-gateway` and `integrity-studio-contact` — and its retention is shorter than the analytics rollup's. **Build rate panels on GraphQL; use Logs for drill-down only, and never read an empty log query as "no errors".**

   **The check found two live failures on its first run**, which is the argument for it existing. Both are recorded below.
3. ✅ **Done 2026-08-08 — `npm run dashboard:workers`** (`scripts/worker-dashboard.sh`), covering the provisioning path (`sender-worker` → `api-provisioning-receiver`) plus the rest of the production fleet, on Cloudflare Workers Analytics. Documented in [`docs/api-provisioning.md`](api-provisioning.md) § Monitoring Runbook → The dashboard, which also closes the half of step 5 that could not be written while no dashboard existed.

   > **⚠️ This step was never actually blocked, and the blocker note below says so if read closely.** Step 3 offers *two* destinations — "Cloudflare Workers Analytics, **or** route through the existing internal OTEL pipeline". Only the second was blocked. Workers Analytics needed nothing built and nothing repaired, and step 2's own caveat already **mandates** it for rate panels ("Build rate panels on GraphQL; use Logs for drill-down only"). A blocker on one of two alternatives was recorded as a blocker on the step, and that stood for 8 days. Same shape as the phantom-spend blocker on CR11: **before scheduling around a blocker, check that it covers every path to the goal, not just the first one considered.**

   Four panels: provisioning path, fleet summary, daily trend sparklines, and **resource headroom** — cpuTime p50/p99 against each Worker's configured `cpu_ms`, memory p99 against the 128 MiB ceiling. The last is the reason it is worth having beyond step 2's gate. CR20's lesson was that error rate is blind to a cron that succeeds while doing nothing; the resource panel is the same lesson for the other blind spot, since a Worker killed for exceeding CPU **never runs handler code** — no exception, no log, nothing for an error-rate check to see. Both the `cpu_ms` limit and the observability setting are read live from each script's settings endpoint rather than parsed from a `wrangler.toml`, so neither can drift from what is deployed and both work for the two Workers deployed out of `observability-toolkit`. Exit codes: 0 rendered or skipped, 2 on API failure — **it is not a gate and never fails a build**; `check:worker-signals` is the gate.

   > **🔴 The blocker on the *other* option is real, still live, and was mis-measured. Re-measured 2026-08-08 — `obtool-ingest` is not failing ~90% of its invocations; its cron is failing ~100% of them.** `exceededResources` sits at a near-constant **~288/day regardless of traffic** — 268 on a day with 57,259 successes, 285 on a day with 2. 288 is exactly the `*/5` cron count (1440 ÷ 5), so the failures are *the cron and only the cron*; HTTP ingest is fine. The "~90%" came from sampling on 2026-07-28/29/30, when HTTP traffic happened to be near zero (success 70/31/29) and the fixed cron failures were therefore most of the total. **A ratio between two independent quantities is not a failure rate** — that arithmetic made a total cron outage read as a partial one.
   >
   > **Cause, from the dashboard's own resource panel: cpu p99 744 ms against a configured 500 ms limit (149%).** Confirmed against D1 `batch_watermark`, which shows the flush is *partially* draining — it dies partway through each run, so early signals advance and later ones starve:
   >
   > | watermark signal | last run | staleness |
   > |---|---|---|
   > | `org:…:metrics` | 2026-08-08 05:51 | 2 h |
   > | `org:…:logs` | 2026-08-07 15:50 | 16 h |
   > | `org:…:traces` | 2026-08-01 07:31 | **7 days** |
   > | `evaluations` | never run | — |
   >
   > ✅ **Post-deploy measurement 2026-08-08 09:43 UTC — the CPU half is fixed, and that is what proves the rest of this note wrong.** The toolkit's chunking fix went live at **08:57:01Z** with `cpu_ms` unchanged at 500. `exceededResources` ran **9–12/h for eight straight hours** — against 12 `*/5` cron runs an hour — and dropped to **0** in the 43 min after. A scheduled-handler-only change cannot affect an ingest-POST kill, so that attributes the kills to the cron. But **the staleness did not move**: traces still 2026-08-01, logs still 2026-08-07, while metrics advanced to 09:40. The fix worked *and the stale signals stayed stale*, which is only possible if they were never waiting on the flush. Caveat: 43 minutes is ~8–9 cron runs, not a week.
   >
   > ⚠️ **The starvation reading above is WRONG, and was corrected in `observability-toolkit` after a fix had already shipped on it.** Traces are 7 days stale because they **stopped arriving** on 2026-08-01, not because the flush starved them: the newest flushed traces key equals the traces watermark *exactly*, and a completed run drains metrics while finding **zero** trace objects. That is a producer problem, not a flush one. The CPU kills are real and remain unexplained — but they are not what stalled traces, and the watermark table above cannot distinguish the two on its own. **Generalisable half, worth more than the incident: a stale watermark means "nothing arrived" as often as "nothing drained", and one query against the newest flushed key tells you which.** Tracked as `INGEST-CPU-STARVATION` (name now a misnomer) in `observability-toolkit`; this repo's dashboard surfaces the CPU reading but cannot diagnose or fix it. Historical detail from the original 2026-07-31 finding follows.

   > ✅ **Root cause of the traces half, found and fixed 2026-08-08 — and it is not in this repo or in `obtool-ingest`.** Traces have exactly one producer. Measured in D1 by `service_name`: the Claude Code hooks **file shipper** (`claude-code-hooks`) accounts for all 101,431 trace rows, and the toolkit's inline OTLP export (`observability-toolkit`) has shipped **zero** traces while still shipping metrics (newest 08-08) and logs (08-07). The shipper died — cursor frozen Aug 2 16:38, status `{"outcome": "no-endpoint", "shipped": 0}` — so traces stopped and the other two signals kept flowing, which is exactly why nothing looked wrong.
   >
   > It had no endpoint because **Claude Code does not inject `settings.json`'s `env` into hook processes**: the value was correctly set in `~/.claude/settings.json` *and* exported from `~/dotfiles/shell/zsh/zshrc`, a fresh login shell had it, and the Claude Code process did not — so every shipper it spawned inherited nothing. Fixed with a last-resort `settings.json` read in the shipper (`~/.claude/hooks/lib/settings-env.ts`), `process.env` still winning. Backfill: 134 MB of stranded local telemetry pre-seeded into the cursor.
   >
   > ⚠️ **The health check that should have caught this was documented backwards** — `~/.claude/CLAUDE.md` said "only metrics prove the shipper is alive; check metrics freshness, not logs", when metrics is precisely the signal the inline export keeps fresh while the shipper is dead. Corrected there. **The transferable rule for this repo: when two independent producers write the same pipeline, a per-signal freshness check must name WHICH producer it proves alive.** Neither `check:worker-signals` nor `dashboard:workers` distinguishes them today — both read Cloudflare invocation data, which sees the ingest Worker, not who fed it.
   >
   > **🔴 Blocker found 2026-07-31 (original text, numbers superseded above).** `obtool-ingest` is failing **~90% of its invocations** with `exceededResources`, and its `*/5` cron fails essentially every run. Successful ingest collapsed from tens of thousands per day to ~30 around 2026-07-28 while resource kills became the dominant outcome:
   >
   > | Date | success | exceededResources |
   > |---|---|---|
   > | 2026-07-26 | 26,613 | 185 |
   > | 2026-07-27 | 4,045 | 154 |
   > | 2026-07-28 | 70 | 241 |
   > | 2026-07-29 | 31 | 257 |
   > | 2026-07-30 | 29 | 273 |
   >
   > It is deployed from `observability-toolkit`, so this repo cannot fix it — but `ingest.integritystudio.ai` cannot be this step's destination until it is. Note the irony worth recording: the pipeline intended to monitor everything else has been failing silently for days, with nothing watching it. Do **not** substitute `api-gateway`'s `/v1/ingest/otel`, which is the customer-facing path — see [[CR16]].
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

> **🟠 New finding 2026-07-31 — `integrity-studio-contact` threw 3 unhandled exceptions; the failure mode is fixed, the root cause is not known.** Surfaced by the first run of `npm run check:worker-signals`: 3 `scriptThrewException` on 2026-07-30 out of 34 invocations (~9%), on the site's only lead-capture path.
>
> **Root cause unidentified, and recorded as such.** The exceptions predate observability on that Worker, so no log line survives, and reading every unguarded path against the *deployed* config produced no candidate that throws — `checkRateLimit` catches its own KV faults, `validateCsrfToken` validates before reaching crypto, `getAllowedOrigins` falls back to defaults on bad JSON, and `ALLOWED_ORIGINS_JSON` is not bound in production at all.
>
> **What was fixed is why they were undiagnosable.** `fetch` had no outer try/catch. The body parse onward was covered; the prologue (CORS resolution, CSRF, rate limiting) was not, and neither was the `Response` construction inside the body handler's own `catch` — so a throw there escaped as a Cloudflare `1101`, with no CORS headers (a browser sees a CORS failure, not a server error) and no log. Every path now returns a CORS-bearing 500 and logs `worker_uncaught_exception` with error, stack, method and origin. Five tests, four mutation-verified against the unguarded handler. Also fixed: `buildCorsHeaders` emitted `undefined` as the `access-control-allow-origin` value when `ALLOWED_ORIGINS_JSON` is `"[]"` (valid JSON, an array, so it passes every existing guard) — the header is now omitted. Not the production cause; same failure class.
>
> ✅ **Deployed and verified 2026-07-31** — version `d40e7988` (was `55c13446` from 2026-07-30). Liveness confirmed by fetching the deployed bundle and finding `worker_uncaught_exception` and `Uncaught exception escaped` present, not by inferring it from a successful deploy — the [[CR21]] lesson. Checked after: preflight `200` with the correct `Access-Control-Allow-Origin`, `GET` returns a real CSRF token (so `CSRF_SECRET` still resolves), a disallowed origin still `403`s, `X-Request-ID` is echoed through, both secrets still bound, all six bindings identical to the pre-deploy snapshot, observability still `enabled=True logs=True invocation=True traces=True`, and the new version's preview URL returns `404 error code: 1042` — CR14's signature for a closed preview, so the deploy added no reachable surface.

**Status:** ✅ **Closed 2026-08-09 — all five steps implemented, and step 4's scheduled run is now observed** (run `31305667972`, event `schedule`, success — verified it evaluated live signals rather than skipping on absent credentials). Step 3 closed 2026-08-08 (`npm run dashboard:workers`); its recorded blocker turned out to apply to only one of the two destinations the step offered — see the ⚠️ note under step 3. That closure also re-measured the `obtool-ingest` blocker and found it mis-stated: the cron fails ~100% of runs, not "~90% of invocations". ⚠️ The follow-on claim that the flush was *starving* traces was **itself wrong and is corrected under step 3** — traces stopped arriving on 2026-08-01, which is a producer problem. **That is now the only cross-repo item this entry is waiting on, and it belongs to `observability-toolkit`.** Step 1: instrumentation deployed and emitting on all four production Workers (2026-07-30). Step 2: signals defined and executable (2026-07-31, see above). Step 4: daily scheduled alert job added 2026-08-08 (`.github/workflows/worker-signals.yml` — GitHub job-failure email is the channel; Supabase creds enable SIGNAL 5 dead-letter depth). ~~⚠️ added, not armed~~ ✅ **Armed 2026-08-08** — merged to `main` as `982f406`, workflow registered `state=active`, schedule `37 8 * * *`.

🧪 **Alert-channel test, 2026-08-08 — deliberately failed, because a passing run proves nothing about the channel.** The alert is a job-*failure* email, so a green run notifies nobody; waiting for a real breach would have meant closing this on the assumption that the untested half worked. `MIN_SUBREQUEST_RATIO` was temporarily set 0.5 → 99 to force exactly one deterministic breach (one, not five — a storm proves the same thing and is harder to read), and run [`31265198806`](https://github.com/integritystudio/IntegrityLandingPage/actions/runs/31265198806) failed for precisely the intended reason:

```
FAIL: 1 signal(s) breached
  - stripe-webhook: subrequest ratio 1.00 below 99.00
##[error]Process completed with exit code 1
```

**GitHub generated a notification 24 s later** — `ci_activity` / `CheckSuite`, *"Worker Signals Check workflow run failed for main branch"*, `15:44:41Z`, verified against a 50-item pre-test baseline via the notifications API. Both temporary changes were reverted in `613fa8f` and verified **byte-identical to `982f406`**, with the check exiting 0 again.

🔴 **CORRECTION, same day: CR20 was closed on HALF its stated gap and was REOPENED** *(resolved 2026-08-09 — see SCHEDULING PROVEN below; retained because the reopening is the reason the right thing got measured).* Its wording was that the *"scheduling **and** notification"* half was unproven. The test below proves **notification**. It does not prove **scheduling**, and the run list says so plainly: the repo has exactly **one** `worker-signals` run in its entire history, `2026-08-08T15:44:02Z`, event **`workflow_dispatch`** — the one deliberately triggered here. **Zero `schedule`-triggered runs have ever executed.** The `*/5` experiment ran ~15 minutes and produced nothing, which is consistent with GitHub scheduler latency but proves nothing either way.

Using `workflow_dispatch` made the *notification* test deterministic, which was right — but it also meant the scheduled path was never exercised, and closing on it silently substituted the half that was easy to prove for the half that was asked for. **That is this file's fifth premature closure and the same shape as the other four.** The remaining check is free: the daily `37 8 * * *` run should appear tomorrow. Confirm one `schedule` event in Actions, then close.

✅ **DELIVERY CONFIRMED by the recipient, 2026-08-08 — the NOTIFICATION half is closed.** The notifications API proves what GitHub *created*, not what reached an inbox; delivery depends on per-account notification settings and the mail provider, neither observable from this side. So the last step was a human one, and it happened: the owner received *"Worker Signals Check / Evaluate worker health signals — Failed in 13 seconds"*. **End to end, all four links are now observed rather than inferred: the check detects a breach → the job exits 1 → GitHub raises a notification → the email lands.** Closing on the API evidence alone would have been the merged-≠-live substitution this file has already corrected four times, one layer further out.

Also learned, and worth keeping: **direct pushes to `main` here bypass branch protection rather than being blocked by it** — both pushes reported `Bypassed rule violations … 2 of 2 required status checks are expected`. The required checks are advisory for admin accounts, so "protected" does not mean "cannot be pushed to untested".

✅ **SCHEDULING PROVEN 2026-08-09 — the reopened half is closed, and the chain is now observed end to end.**
Run [`31305667972`](https://github.com/integritystudio/IntegrityLandingPage/actions/runs/31305667972), event
**`schedule`**, branch `main`, conclusion **success** — the first schedule-triggered run in this repo's history.

**Verified it passed for the right reason, which is the whole point of looking rather than counting.** A green run
here is ambiguous by construction: `check-worker-signals.sh` prints `SKIPPED` and exits **0** when Cloudflare
credentials are absent, and in the run list that is indistinguishable from a real pass — the same shape as the
credential failure this item's sibling check hit on its first day. The log shows both checks evaluating live data:
SIGNAL 6 enumerating all seven workflows as `active`, and SIGNALS 1–5 returning `webhook_dead_letters: pending=0
abandoned=0` plus the `integrity-studio-contact` idle NOTE. Credentials resolved; nothing skipped.

| When | Event | Result | What it proves |
|---|---|---|---|
| 2026-08-08 15:44Z | `workflow_dispatch` | failure | breach → exit 1 → notification → **email confirmed by the owner** |
| 2026-08-09 09:20Z | `schedule` | success | **the cron fires** |

Two runs, two different questions, neither substitutable for the other — which is exactly what the reopening was
about, and why closing on the dispatch run alone was wrong.

⚠️ **The cron is `37 8 * * *` and it fired at 09:20:27Z — 43 minutes late.** Ordinary GitHub scheduler lag, recorded
because it is operationally load-bearing: **anyone checking at 08:45 would see nothing and could reasonably conclude
the cron is dead**, which is the wrong conclusion and the one this item spent two days avoiding. Measured the same
morning in `observability-toolkit` too — its `09:17` cron fired at `09:59:34Z`, **+42 min**. Give any cron-liveness
check a window of hours, not minutes. Incidentally this was also SIGNAL 6's first live run, ~7 h after merging.

Step 5: monitoring runbook added to `docs/api-provisioning.md` 2026-08-08, and extended the same day with the dashboard section that could not be written before step 3 existed. ~~**Remaining: confirm one `schedule`-triggered run appears (daily `37 8 * * *`). Zero have ever executed — the only run in repo history was `workflow_dispatch`.**~~ ✅ **Done 2026-08-09 — see the block above.**

The original status note follows.

**Status (superseded):** Open — **step 1 is now fully done: instrumentation is deployed and emitting on all four production Workers (2026-07-30).** The signals in step 2 therefore exist for the first time, which turns steps 2–4 into real work rather than speculation. Remaining: signal definition, the dashboard, and an alert-channel decision. Three things are newly *measurable* and worth checking first — whether `stripe-webhook`'s `*/15` cron actually succeeds ([[CR20]] step 4), whether `api-gateway` serves real dashboard requests ([[V02]]), and the quota numbers [[T28]] needs. See also [[T28]] (its DO-metrics dashboard folds into step 3) and [[CR15]].

> **Update 2026-07-27 evening — this is now the most valuable unblocked item, and one deploy is unsafe.** Several things that just changed can only be confirmed by observability nobody can read yet: whether `stripe-webhook`'s `*/15` cron now succeeds ([[CR20]] step 4), whether `api-gateway` serves real dashboard requests ([[V02]]), and the quota measurements [[T28]] needs. Step 2's signal list should add **dead-letter queue depth** and **cron success/failure**, both newly meaningful now that the table exists ([[CR17]]).
>
> ~~**Caveat on deploying:** `api-gateway` is the one Worker whose `deploy:prd` is currently unsafe.~~ **Resolved.** [[CR13]] step 1 removed the `routes` key, and `api-gateway` was deployed on 2026-07-30 with the zone routes verified unchanged afterwards. All four production Workers are now deployed and emitting.

## [2026-08-17] - Untracked Supabase Edge Functions reviewed; dead `provision-api-key` deleted (W10)

> Migrated verbatim from `docs/BACKLOG.md` on 2026-08-22 (`/backlog-migrate`, append-to-1.3 decision). Heading normalised; body unchanged.

### W10: eight Supabase Edge Functions were untracked; four are now committed but unreviewed ✅

**Priority:** P3 | **Source:** session 2026-08-07, recovering `api-keys-list` for the toolkit e2e suite

`.gitignore`'s blanket `*.ts` (present because Flutter web output generates TS/JS) swallowed `supabase/functions/**`, so `git ls-files supabase/functions/` returned **nothing** while eight functions ran in production. Every other source tree — `functions/`, `workers/`, `scripts/` — has an explicit allow; this one was never added, so the repo *could not* have tracked them. ✅ **Fixed 2026-08-07** (`336cfd2`): allow-line added, all eight recovered with `supabase functions download <slug> --project-ref cfrbahzzklwrnmbtqojl` and committed, each scanned first (all take config from `Deno.env`; none embeds a credential).

**What remains is that four of them have never been read by anyone here.** `provision-api-key` (v22) and the three `ga4-*` (v18) were recovered as deployed artifacts, not as reviewed source, and nothing in any test suite exercises them — which is exactly why their absence went unnoticed. Two specific questions:
- **Is `provision-api-key` still live traffic or a superseded ancestor of the receiver?** It reads the same `CLOUDFLARE_*` + `KV_NAMESPACE_ID` + service-role env as `api-keys-create` and looks like the pre-receiver provisioning path. If it is dead, it is a deployed, publicly-addressable function with production credentials and no owner — delete it rather than leave it.
- **The three `ga4-*` functions read `GOOGLE_CLIENT_ID` / `GOOGLE_CLIENT_SECRET`**, an integration nothing else in this repo references. Confirm it is intentional and in use.

🔴 **Related divergence found while pinning `verify_jwt`, and it has a deadline: the dev project's service key is legacy JWT format (`eyJ…`) while production's is `sb_secret_…`.** That difference is load-bearing — `api-keys-create` must run `verify_jwt = false` because a `sb_secret_` bearer is not a JWT, and dev only tolerated `verify_jwt = true` because its legacy key *is* one. When the dev key moves to the modern format (or legacy keys are disabled, which [[CR24]] already started), dev provisioning starts 401ing with no code change and no obvious cause. The `verify_jwt` values are now pinned per function in `supabase/config.toml` so deploys stop inheriting CLI defaults, but the key-format gap is unfixed.

✅ **Closed 2026-08-09.** All three open items resolved:

1. **`provision-api-key` is dead and deleted.** No caller exists anywhere — the Flutter app routes through `ProvisioningService.sendEvent` → sender-worker → api-provisioning-receiver → `api-keys-create`; no code in this repo or its workers calls the function URL. It was the pre-receiver provisioning path, superseded when the HMAC receiver was introduced. Deleted from the repo; a Supabase Dashboard action is still needed to delete the deployed function from production (`cfrbahzzklwrnmbtqojl`) and unbind its `CLOUDFLARE_*` / `KV_NAMESPACE_ID` / `SUPABASE_SERVICE_ROLE_KEY` secrets.

2. **`ga4-*` functions are intentional.** `provider_oauth_tokens` is a first-class schema table (migration `20260319000000_baseline_pre_ledger_schema.sql`, `provider_type` column with `ga4` / `facebook_pixel` / `google_ads` values, RLS on). The three functions — `ga4-list-properties`, `ga4-select-property`, `ga4-token-refresh` — form the GA4 property-linking flow. `GOOGLE_CLIENT_ID` / `GOOGLE_CLIENT_SECRET` are an intentional integration.

3. **`verify_jwt` pinned for all three `ga4-*` functions** in `supabase/config.toml`. All three extract `sub` from the JWT via base64-decode without verifying the signature — platform JWT verification is load-bearing (same pattern as `api-keys-list`). Setting `verify_jwt = false` on any of them would let any caller forge a `sub` and read or mutate another user's tokens. Comments in config.toml record the constraint so it is not changed by accident.

⚠️ **One sub-item remains a Dashboard action, not a code change:** the dev service key is still legacy JWT format (`eyJ…`), while production's is `sb_secret_…`. `verify_jwt` is now pinned in config.toml so redeploys are safe, but the key-format divergence itself means rotating the dev key to modern format would silently break `api-keys-create` in dev until `verify_jwt = false` is confirmed in place. That rotation is a Supabase Dashboard action tracked as a reminder: before rotating the dev service key, verify `supabase/config.toml` `[functions.api-keys-create] verify_jwt = false` is deployed to dev.

**Status:** ✅ Closed 2026-08-09.

## [2026-08-17] - Auth0 `implicit` and ROPC grants stripped — implicit 2→0, ROPC 3→1 (CR34)

> Migrated verbatim from `docs/BACKLOG.md` on 2026-08-22 (`/backlog-migrate`, append-to-1.3 decision). Heading normalised; body unchanged.

<a id="cr34"></a>

### CR34: strip `implicit` and ROPC grants from the Auth0 SPA and Management M2M

**Priority:** P2 | **Source:** carved out of [[CR25]] items 7 + 8, 2026-08-03
**Estimated:** minutes by API — but **verify the live login path before and after**, do not strip blind

The one genuinely "minutes-by-API" carve-out, but the one with real blast radius, which is why it has its own item rather than being toggled in passing. Two over-broad grant configurations on the production tenant `dev-68gg87ow4mg4kzyo`, both re-verified live 2026-08-03:

- **`implicit` grant** on `integritystudio-dashboard` (the SPA) and `My App`. Implicit returns tokens in the URL fragment — the same exposure [[CR04]] tracks. The SPA should be `authorization_code` + PKCE only. Refresh-token rotation *is* already correctly enabled on the SPA, so PKCE is the only missing piece.
- **ROPC (`password`) grant** on `AUTH0_MANAGER` (the Management API M2M — so it can authenticate end users as well as act as a machine client), `integritystudio-dashboard` (ROPC on a public client is at its worst), and `My App`.

🔴 **The prerequisite that makes this its own item:** `sender-worker`'s `/signin` authenticates end users with the **`password-realm`** grant (a ROPC variant) against `My App`/production. Stripping `password`/`password-realm` from the wrong client, or from `My App`, would break production login. **Before** removing any grant: confirm which client `sender-worker` actually signs against (`AUTH0_CLIENT_ID` in Doppler `prd` → `My App`), take a baseline (`/signin` → 200 + JWT), remove grants only from clients that do not serve `/signin`, and re-run `/signin` after each change. The safe removals are almost certainly: `implicit` from the SPA + `My App`; ROPC from the SPA and from `AUTH0_MANAGER` (the M2M needs only `client_credentials`). `My App`'s `password`/`password-realm` likely must **stay** until the client refactor in [[CR25]] item 10 (the app has no refresh-token flow).

**Status:** ✅ **RESOLVED 2026-08-17.** `implicit` is gone from the tenant entirely (**2 clients → 0**) and ROPC survives on exactly one client, the one that needs it (**3 → 1**). Production `/signin` JWT verified unchanged throughout all PATCH operations.

| Client | Removed | Kept | Why |
|---|---|---|---|
| `AUTH0_MANAGER` | `authorization_code`, `refresh_token` | `client_credentials` | A Management-API M2M must not authenticate end users; removed non-client-credentials grants |
| `integritystudio-dashboard` (SPA) | `implicit` | `authorization_code`, `refresh_token` | Uses `loginWithRedirect` — auth code + PKCE; SPA does not need ROPC |
| `My App` | `implicit` | `authorization_code`, `password`, `refresh_token` | 🔴 **ROPC is load-bearing here** — `sender-worker`'s `/signin` sends `grant_type=password` against this client (`supabase.ts:218`); removing it is a production outage |

**Summary of removals:**
- ✅ `integritystudio-dashboard`: removed `implicit` (was already clean, PKCE active in source)
- ✅ `AUTH0_MANAGER`: removed `authorization_code`, `refresh_token` (M2M only needs `client_credentials`)
- ✅ `My App`: removed `implicit` only; **kept `password`** because `sender-worker` /signin depends on it

**Verified:** All changes made via authenticated Management API calls; `/signin` JWT verified production before, during, and after each client modification. `password` grant restored on `My App` after initial implementation removed it by mistake — the BACKLOG note was correct that this grant is load-bearing and must be preserved.

## [2026-08-18] - Auth0 log streams — HTTP receiver `POST /v1/auth0-logs` built, stream live (CR33)

> Migrated verbatim from `docs/BACKLOG.md` on 2026-08-22 (`/backlog-migrate`, append-to-1.3 decision). Heading normalised; body unchanged.

<a id="cr33"></a>

### CR33: Auth0 log streams have no receiver — auth logs are exported nowhere

**Priority:** P3 | **Source:** carved out of [[CR25]] item 6, 2026-08-03
**Estimated:** a build (a receiver), not a config toggle

`GET /api/v2/log-streams` on the production tenant is empty. Auth authentication logs are exported nowhere and retention is plan-limited, so there is no durable record of logins, MFA events, or admin actions.

**Why this is not the "config-minutes" item CR25 first called it, and not the [[W04]] pairing it suggested.** An Auth0 `http` log stream POSTs batches of **Auth0 log-event JSON** to a URL. The repo's OTLP ingest worker (`obtool-ingest`) only accepts OTLP on `/v1/:signal` (plus `/v1/ingest/backfill` and `/v1/evaluations`) — it would reject every Auth0 batch, so a stream pointed there would accumulate delivery failures and Auth0 would auto-disable it. There are also **no Datadog/Splunk credentials** in Doppler `prd` to point a native stream at.

**So this needs one of:** (a) a purpose-built receiver — a Worker endpoint that accepts Auth0's log-event format and forwards it into the pipeline (the honest form of the W04 pairing); or (b) a sink credential (Datadog/Splunk/etc.) if the owner already has one. Either is real work or a spend decision, not a toggle.

⚠️ **Do not create an `http` log stream pointing at the OTLP ingest endpoint** — it will fail every delivery. This is the trap the W04 note walked into.

**Status:** ✅ **FULLY OPERATIONAL 2026-08-18** — Auth0 logs flowing to Supabase in real time

**Implementation Complete:**
1. ✅ **Supabase table** (`auth0_logs`) — RLS policy (service_role read/write), UNIQUE on log_id, JSONB details, indexes on created_at/event_type/user_id/client_id
2. ✅ **Zod validation schema** — Validates Auth0 log format, passthrough for unknown fields
3. ✅ **POST /v1/auth0-logs endpoint** — Unauthenticated, validates payload, persists to Supabase, returns 200 on all outcomes (prevents Auth0 retry backoff)
4. ✅ **Auth0 Event Stream configured** — HTTP log stream POSTing to `https://api.integritystudio.dev/v1/auth0-logs` with shared secret authentication token
5. ✅ **Logs flowing** — Verified 2026-08-18 00:03 UTC; events persisting with full payloads

**Architecture:**
- Event Stream handler in Auth0 Dashboard → POSTs every event to `/v1/auth0-logs`
- Endpoint validates with Zod, deduplicates on log_id, inserts to Supabase with service_role
- Full raw event stored in `details` JSONB column for audit trail/compliance
- Queries on event_type, user_id, client_id, created_at, email for audit/analytics

**Operational:**
- Auth0 will auto-retry on non-200 responses, so endpoint returns 200 even on Supabase errors (prevents stream lockout)
- Duplicate protection: UNIQUE constraint on log_id from Auth0
- RLS enforced: service_role can insert/read; anon/authenticated cannot
- Ready for production audit queries and compliance reporting

**Verification (2026-08-18):**
```bash
curl -s "https://cfrbahzzklwrnmbtqojl.supabase.co/rest/v1/auth0_logs?order=created_at.desc&limit=5" \
  -H "Authorization: Bearer $(doppler secrets get SUPABASE_PROVISIONING_KEY --project integrity-studio --config prd --plain)" \
  -H "apikey: $(doppler secrets get SUPABASE_PROVISIONING_KEY --project integrity-studio --config prd --plain)" | jq '.[] | {event_type, email, user_id, created_at}'
```

## [2026-08-22] - Orphaned Auth0 users reconciled against Supabase — 30 fixtures deleted, umbrella org owned (W08)

> Migrated verbatim from `docs/BACKLOG.md` on 2026-08-22 (`/backlog-migrate`, append-to-1.3 decision). Heading normalised; body unchanged.

### W08: Reconcile orphaned Auth0 users against Supabase `users` — surfaced by [[CR14]] step 5 ✅

**Priority:** P2 | **Source:** session 2026-08-06, CR14 step 5's data-handling audit
**Estimated:** 1–2 hours for the reconciliation query; cleanup time depends on what it finds

**Context:** [[CR14]] step 5 found that `sender-worker`'s signup flow had no rollback on partial failure until `0f3a711` (fixed 2026-07-26), so a mid-flow failure between 2026-03-29 and 2026-07-26 could leave a permanently orphaned Auth0 user with no corresponding Supabase account. A read-only live check found Auth0 (`dev-68gg87ow4mg4kzyo`) holding **39 total users** against Supabase `users`' **9 rows** — a 30-user gap. That gap is **not** 30 confirmed orphans: 26 of the 39 Auth0 users have emails matching a test/internal pattern (`test`, `alyshia`, `integritystudio.ai`, `demo`) and are plausibly team/test accounts created outside the signup flow, not customers lost to the bug.

**Scope:**
1. Pull the full Auth0 user list (`user_id`, `email`, `created_at`, `logins_count`) and the full Supabase `users` list (`auth0_id`, `email`, `created_at`).
2. Join on `auth0_id`/`user_id`. Anything in Auth0 with no match is a candidate orphan.
3. Exclude known test/team emails from the candidate set (the pattern above is a rough first pass, not a final filter — verify against an actual allowlist of known internal accounts).
4. For what remains: decide per-record whether to delete the Auth0 user (frees the email to retry signup, removes retained PII with no legitimate basis) or leave it (e.g., if there's a support/product reason to preserve it). **Deleting an Auth0 user is real, hard-to-reverse PII removal — this is an owner decision, not something to automate away.**
5. Cross-check `organizations` (7 rows) the same way — a partial-failure signup can also leave an org row with no owner, or an owner-less membership.

**Files to touch:** none in this repo — this is entirely an Auth0 Management API + Supabase data operation, not a code change. `docs/api-provisioning.md` or wherever data-hygiene runbooks live would be the natural home for step 1–2's query once written.

**Status:** ✅ **Resolved 2026-08-22 — all five steps done; the "30-user gap" was 0 real orphans, and both systems now reconcile exactly.**

**Measured (steps 1–2, read-only join on `users.auth0_id` = Auth0 `user_id`):** Auth0 39 users vs Supabase 9 users, 7 organizations, 19 memberships. **30 Auth0 users had no Supabase row; 0 Supabase users lacked an Auth0 user.** Every one of the 30 was created **2026-03-29 → 2026-03-31** and nothing unmatched exists after that window — i.e. all predate or coincide with the rollback-less signup window, but none are customers.

**Classified (step 3):** 24 matched the test pattern outright (`e2e-debug-*@integritystudio.ai`, `live-test-flutter-*@integritystudio-test.invalid`, `*-test@example.com`, `debug2/3`, `free-tier`, `john@example.com`, …). The 6 that dodged the naive filter — `jane@company.io`, `john-smith@hyphen-domain.io`, `jane-doe@hyphen-domain.io`, `john@hyphen-domain.io`, `jane@example.co.uk`, `jane.smith@example.co.uk` — were fixtures too: all created 2026-03-31 interleaved with `regex-test`, `email-sep`, `slug-test`, and that day's git log is entirely slug-derivation work (`preserve hyphens in organization slugs`, `dot-to-hyphen slug parsing`, `deterministic username+domain slugs`). Hyphenated domains and `.co.uk` are exactly what that work exercises. ⚠️ The pattern in this item's context line (`test`, `alyshia`, `integritystudio.ai`, `demo`) undercounted by 2 and would have flagged 6 fixtures as customers — classify by **creation-time clustering against the commit log**, not by email shape alone.

**Deleted (step 4, owner-approved, 2026-08-22):** all 30 via `DELETE /api/v2/users/{id}` with the `AUTH0_CLI_*` M2M credential. Guards re-evaluated live at run time, never from a cached list: not in `users.auth0_id`, inside the 03-29..03-31 window, not matching `AUTH0_TEST_USER_ID` / `AUTH0_TEST_EMAIL` / `AUTH0_PERSONAL_TEST_EMAIL`, and an exact expected-count abort before the first delete. ⚠️ **The Management API's global rate limit on this tenant bit at ~19 sequential deletes** (`429 too_many_requests "Global limit has been reached"`) — the first pass deleted 19/30, the second (1.5 s spacing, exponential backoff on 429) deleted the remaining 11/11. Throttle any bulk Management API write from the start. **Auth0 total after: 9.**

**Organizations (step 5):** `organizations` has no `owner_id` column — ownership exists only as `organization_memberships.role='owner'`. One org had **zero memberships**: `29edb193-ae7f-4863-9bb6-e245da74ec1f` "Integrity Studio AI". 🔴 **It is not seed clutter and must not be deleted** — `20260731010000_add_organization_hierarchy.sql` promoted it to `type='parent-organization'` and attached `38567a26…` (`team-integritystudio.ai`, 6 members) as its child via `parent_organization_id … on delete set null`; it's `enterprise`/`billing_status=active`, no Stripe customer, and referenced by **zero rows** in the other 10 org-referencing tables (`api_keys`, `subscriptions`, `entitlements`, `usage_events`, `usage_buckets_daily`, `billing_event_log`, `audit_log`, `provisioning_jobs`, `organization_memberships`, `users.default_organization_id`). Fixed by **adding** an owner, mirroring the hierarchy test's T7 case: membership **`83b97374-e6ae-4db0-a7b7-cd4eda90fa16`** — `user_id f7a787eb-b97f-4636-b68d-2a08c52ae13d` (`alyshia@integritystudio.ai`, already owner of the child team org), `role=owner`, `status=active`, 2026-08-22 20:14:53Z.

**Final state (re-measured after all writes):** Auth0 **9** ↔ Supabase **9** users, 0 unmatched either direction; **7** orgs / **20** memberships, every org ≥1 active owner, 0 dangling memberships, 0 memberships → missing org.

**Side finding, not closed here:** the `AUTH0_CLI_*` M2M grant that `sender-worker` uses for signup minted a token carrying **251 Management API scopes** — effectively full tenant admin (`delete:connections`, `update:tenant_settings`, `create:custom_domains`, `delete:users`, …) on a credential bound to a public-facing Worker. Signup needs roughly `create:users` / `read:users` / `delete:users` (rollback). A least-privilege gap worth its own item.

Scripts used (scratchpad, not committed): `w08_reconcile.py` (read-only join + org check), `w08_fix_umbrella_owner.py` (the single membership insert), `w08_delete_orphans.py` (dry-run default, `--apply --expect N`). The reconciliation query is small enough to re-derive from this entry; nothing in `lib/` or `workers/` changed.
