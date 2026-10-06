# Integrity Studio AI

[![CI](https://github.com/integritystudio/IntegrityLandingPage/actions/workflows/ci.yml/badge.svg)](https://github.com/integritystudio/IntegrityLandingPage/actions/workflows/ci.yml)
[![Coverage](https://img.shields.io/endpoint?url=https://aledlie.github.io/IntegrityLandingPage/badge.json)](https://aledlie.github.io/IntegrityLandingPage/)

Enterprise AI Observability Platform landing page built with Flutter Web.

**Production**: https://integritystudio.ai
**Status**: ✅ Sender-Worker UI complete (auth, provision, health pages), API provisioning + ingest + Stripe billing workers live, ~3,017 Flutter (unit+contract+integration, 2026-07-31) + **1,282 worker tests** (verified 2026-10-06 via `npm run test:workers`)

## Quick Start

```bash
flutter pub get          # Install dependencies
flutter run -d chrome    # Development server (localhost:8080)
flutter test             # Run tests (~3,017 passing, ~94% coverage)
flutter build web        # Production build
```

### Workers

**Shared Library** (`workers/lib/`)
- Time constants: MS_PER_DAY
- HTTP utilities: CORS, request parsing, response factories, error handling
- Zod schemas: usage events, OTEL spans, quota/billing, audit logs, Auth0 logs, request bodies, Supabase queries
- Validation: typed result unions, formatted error responses
- Billing and entitlements (`effectivePlan`, `isEntitled`, `PLAN_MIN_SEATS`), API-key parsing and verification, Auth0 JWKS verification

```bash
cd workers/lib && npm install && npm test
```

**Contact Form Worker** (`workers/contact-form/`)
- Email submissions via Resend
- KV-based rate limiting
- CSRF protection, idempotency keys
- Tests: 81 passing, ~94% coverage

```bash
cd workers/contact-form
npm install && npx wrangler dev   # Local dev
npx vitest run                    # Tests
```

**API Gateway Worker** (`workers/api-gateway/`)
- Serves `api.integritystudio.dev`
- Usage event ingest, aggregation, and rollup (daily → monthly)
- OpenTelemetry span ingestion with quota enforcement
- Org quota tracking via Durable Objects
- Org routes (`/v1/orgs/:id/*`): dashboard, billing status, usage summary, entitlements, quota status, billing portal, checkout session, API key create/revoke; plus `/v1/me` and `POST /bootstrap`
- Staff-only admin reads (`/v1/admin/orgs`), gated by `STAFF_USER_IDS`
- Auth0 log poller (15-minute cron) feeding `auth0_logs`
- Tests: 422 passing

```bash
cd workers/api-gateway
npm install && npx wrangler dev   # Local dev
npx vitest run                    # Tests
```

**API Provisioning Workers** (`workers/sender-worker/`, `workers/receiver-worker/`)
- **Sender** (`api-provisioning-sender`): routes `POST /signup`, `/signin`, `/forgot-password`, `/send`, `/create-checkout-session`, `GET /health` (Zod v4).
  - *Inline (no receiver):* `/signup` = Auth0 user creation (M2M) + Supabase org/user/membership + ROPC sign-in → returns JWT; `/signin` = direct Auth0 ROPC (`{email,password}` → `{jwt,email}`); `/forgot-password` = Auth0 reset email, same 200 whether or not the account exists.
  - *Forwarded:* `/send` events (`provision_api_key`, `sign_in`) are HMAC-SHA256-signed and sent to the production receiver `api-provisioning-receiver` via a Cloudflare service binding. The receiver mints `obtk_` API keys; api-gateway's `POST /v1/orgs/:id/api-keys` mints the legacy `int_live_` format, which only api-gateway accepts.
- **Receiver**: `workers/receiver-worker/` is a **local stub / test double** (signature verification, replay protection). The production receiver is `api-provisioning-receiver` in the separate `observability-toolkit` repo (persists to Supabase).

```bash
cd workers/sender-worker
npm install && npx wrangler dev   # Local dev
npx vitest run                    # Tests

cd workers/receiver-worker
npm install && npx wrangler dev   # Local dev
npx vitest run                    # Tests

# Manual E2E testing
npm run test:provisioning         # Interactive test guide
# Or read: docs/PROVISIONING_MANUAL_TEST.md for detailed steps
```

**Stripe Webhook Worker** (`workers/stripe-webhook/`)
- Stripe event verification and routing
- Handles five events: `checkout.session.completed`, `invoice.paid`, `invoice.payment_failed`, `customer.subscription.updated`, `customer.subscription.deleted`
- Dead-letter queue for failed events with reconciliation
- Supabase sync: subscriptions, plan mapping via `STRIPE_PRICE_TO_PLAN_JSON`
- Tests: 188 passing

```bash
cd workers/stripe-webhook
npm install && npx wrangler dev   # Local dev
npx vitest run                    # Tests
```

## Documentation

- [Architecture](docs/architecture.md) — tech stack, patterns, directory structure
- [Authentication](docs/authentication.md) — Auth0 Universal Login (PKCE), session storage and refresh, sign-up → provision, how the Workers check the token, legacy sender password routes
- [Routes](docs/routes.md) — GoRouter configuration, 45 routes
- [API Provisioning](docs/api-provisioning.md) — inter-worker HMAC-SHA256 auth, Flutter service layer, security model
- [Provisioning Manual Test Guide](docs/PROVISIONING_MANUAL_TEST.md) — 7 test cases, step-by-step instructions, last recorded results
- [Changelog](docs/changelog/1.3/CHANGELOG.md) — version history
- [BACKLOG](docs/BACKLOG.md) — open, deferred, blocked items
- [Token Tree](docs/repomix/token-tree.txt) — file tree with token counts

## Testing

```bash
# Flutter: Unit + Contract + Widget tests (~3,017, ~94% coverage)
flutter test                           # All tests
flutter test --coverage                # With coverage report
flutter test test/pages/               # Page tests only
flutter test test/services/provisioning_service_test.dart        # Unit tests (48)
flutter test test/services/provisioning_service_contract_test.dart # Contract tests (25, Dart ↔ TS schema)

# Flutter: Live integration tests (optional; against the dev worker — `sender-worker` without -dev is production)
flutter test test/services/provisioning_service_live_test.dart \
  --dart-define=LIVE_TESTS=true \
  --dart-define=SENDER_WORKER_URL=https://sender-worker-dev.alyshia-b38.workers.dev

# Workers — or run every package at once from the repo root:
#   npm run test:workers   (1,282 tests)   npm run lint:workers   (tsc --noEmit x6; there is no ESLint here)
# Per-package counts measured 2026-10-06:
cd workers/lib && npm test              # Shared lib tests (352 passing)
cd workers/contact-form && npm test     # Contact form worker tests (81 passing)
cd workers/api-gateway && npm test      # API Gateway worker tests (422 passing)
cd workers/receiver-worker && npm test  # Receiver worker tests (33, local stub)
cd workers/sender-worker && npm test    # Sender worker tests (206 passing)
cd workers/stripe-webhook && npm test   # Stripe webhook tests (188 passing)
# (bootstrap-worker was deleted 2026-07-31 — POST /bootstrap is now a route on api-gateway)

# Opt-in worker suites (e2e 49/49 on 2026-10-06; the two live suites last recorded 2026-07-29,
# before stripe-webhook's gained the CR38 plan-sync case)
cd workers/sender-worker && npm run test:e2e    # workerd runtime, outbound mocked, no credentials — but runs under doppler run --config dev (49/49)
cd workers/sender-worker && npm run test:live   # real Auth0 Management API, --config prd (9 passed/3 skipped)
cd workers/stripe-webhook && npm run test:live  # real Stripe-signed requests (5/5)

# Manual provisioning E2E test (interactive, do NOT use in CI)
# Writes a temporary .dev.vars with SIGNING_KEYS + ACTIVE_KEY_ID if none exists
npm run test:provisioning
```

**[Coverage Report](https://aledlie.github.io/IntegrityLandingPage/)**

### Platform-Limited Test Gaps

| Item | File | Reason |
|------|------|--------|
| `_launchUrl` error handling | `lib/widgets/sections/footer_section.dart` | `url_launcher` failures untestable in widget tests |
| `_initializeTracking` error handling | `lib/app.dart` | `kIsWeb` compile-time constant; requires web platform |

See `test/app_test.dart:692-702` for native test ceiling details.

### Known Issues

**Flutter Canvas Limitation (CanvasKit)** — Flutter Web renders all content to `<canvas>`, making DOM-based selectors (Playwright `page.locator()`, `page.click()`) unable to reach widget content. Workaround: `Semantics` widget wrappers expose ARIA labels accessible via `page.getByLabel()`. `SemanticsBinding.instance.ensureSemantics()` enables the semantics tree at startup. Some browsers may fail to materialise the tree ([Flutter #151929](https://github.com/flutter/flutter/issues/151929)); e2e tests gracefully skip in that case. Interactions that require pixel-level canvas hit-testing (touch fling, swipe gestures, overlay opacity) remain infeasible.
