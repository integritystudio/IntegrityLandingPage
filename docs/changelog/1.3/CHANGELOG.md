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
