# Integrity Studio AI

[![CI](https://github.com/integritystudio/IntegrityLandingPage/actions/workflows/ci.yml/badge.svg)](https://github.com/integritystudio/IntegrityLandingPage/actions/workflows/ci.yml)
[![Coverage](https://img.shields.io/endpoint?url=https://aledlie.github.io/IntegrityLandingPage/badge.json)](https://aledlie.github.io/IntegrityLandingPage/)

Enterprise AI Observability Platform landing page built with Flutter Web.

**Production**: https://integritystudio.ai
**Status**: ✅ Sender-Worker UI complete (auth, provision, health pages), API provisioning + ingest workers live, 2440+ Flutter + 193 worker tests passing, code quality refactored

## Quick Start

```bash
flutter pub get          # Install dependencies
flutter run -d chrome    # Development server (localhost:8080)
flutter test             # Run tests (2440+ passing, ~94% coverage)
flutter build web        # Production build
```

### Workers

**Shared Library** (`workers/lib/`)
- Time constants: MS_PER_DAY
- HTTP utilities: CORS, request parsing, response factories, error handling
- Zod schemas: usage events, OTEL spans, audit logs, provisioning, Supabase queries
- Validation: typed result unions, formatted error responses

```bash
cd workers/lib && npm install && npm test
```

**Contact Form Worker** (`workers/contact-form/`)
- Email submissions via Resend
- KV-based rate limiting
- CSRF protection, idempotency keys
- Tests: 71 passing, ~94% coverage

```bash
cd workers/contact-form
npm install && npx wrangler dev   # Local dev
npx vitest run                    # Tests
```

**API Gateway Worker** (`workers/api-gateway/`)
- Usage event ingest, aggregation, and rollup (daily → monthly)
- OpenTelemetry span ingestion with quota enforcement
- Org quota tracking via Durable Objects
- Tests: 122 passing, ~94% coverage

```bash
cd workers/api-gateway
npm install && npx wrangler dev   # Local dev
npx vitest run                    # Tests
```

**API Provisioning Workers** (`workers/sender-worker/`, `workers/receiver-worker/`)
- **Sender**: Signs requests with HMAC-SHA256, forwards to receiver
- **Receiver**: Verifies signatures, stores provisioning data, replay protection

```bash
cd workers/sender-worker
npm install && npx wrangler dev   # Local dev
npx vitest run                    # Tests

cd workers/receiver-worker
npm install && npx wrangler dev   # Local dev
npx vitest run                    # Tests

# Manual E2E testing
npm run test:provisioning         # Interactive test guide
# Or read: PROVISIONING_MANUAL_TEST.md for detailed steps
```

## Documentation

- [Architecture](docs/architecture.md) — tech stack, patterns, directory structure
- [Routes](docs/routes.md) — GoRouter configuration, 33 routes
- [API Provisioning](docs/api-provisioning.md) — inter-worker HMAC-SHA256 auth, Flutter service layer, security model
- [Provisioning Manual Test Guide](PROVISIONING_MANUAL_TEST.md) — 7 test cases, step-by-step instructions
- [Provisioning E2E Results](PROVISIONING_E2E_RESULTS.md) — verified working components, test summary
- [Changelog](docs/changelog/1.1/CHANGELOG.md) — version history
- [BACKLOG](docs/BACKLOG.md) — open, deferred, blocked items
- [Token Tree](docs/repomix/token-tree.txt) — file tree with token counts

## Testing

```bash
flutter test                           # All Flutter tests (~2440, ~94% coverage)
flutter test --coverage                # With coverage report
flutter test test/pages/               # Page tests only
cd workers/contact-form && npm test    # Contact form worker tests (71 passing)
cd workers/api-gateway && npm test     # API Gateway worker tests (122 passing)
cd workers/receiver-worker && npm test # Receiver worker tests
cd workers/sender-worker && npm test   # Sender worker tests

# Manual provisioning E2E test (interactive, do NOT use in CI)
SHARED_SECRET=your-test-secret npm run test:provisioning
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
