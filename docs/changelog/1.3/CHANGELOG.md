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
- **Stripe was never exposed.** The *Worker Deploy Separation* entry said dev and prd share Stripe credentials. `STRIPE_SECRET_KEY` is in fact empty in all three configs, and the key actually in use — `STRIPE_API_KEY` — is `sk_test_…` in both. There is no live-key risk. (Separately: production being configured with a test key is its own question.)
- **The `stg` config is empty, not a third environment.** An earlier comparison read its blank values as "differs from prd"; `da39a3ee` is the SHA-1 of the empty string. It is unset, and therefore available to repurpose as the dev target.
- **Worker secrets never came from Doppler.** `wrangler deploy` does not turn ambient env vars into Worker secrets; they are set per worker with `wrangler secret put`. Doppler's role at deploy time is to supply `CLOUDFLARE_API_TOKEN`. CLAUDE.md now says so, with the command to inspect what a worker actually has bound.

**CR12 filed — production `api-gateway` is degraded on the live user path.** Auditing bound secrets showed `api-gateway` and `stripe-webhook` have **zero**, against five documented as required for the gateway — confirmed by both the Workers REST API and `wrangler secret list`. `GET /health` returns `503 {"database":"degraded"}`. The affected host, `api-gateway.alyshia-b38.workers.dev`, is production and is the compile-time default the shipped Flutter app calls, not a back channel. A monitoring trap sits next to it: `api.integritystudio.ai/health` returns 200 from the marketing site, because the custom domain only routes `/v1/*`. Both were last deployed 2026-03-31, so they appear to have been in this state for roughly four months, which means the quota, usage, and entitlements work recorded in this changelog has been shipping against a gateway that cannot reach its database. Not remediated here: setting production secrets is not a change to make unasked, and the right values depend on whether CR11's isolation work lands first.

**Final state:** 3,001 Flutter tests and 1,018 worker tests passing; zero TypeScript errors across all seven workers; `shellcheck` clean.

---
