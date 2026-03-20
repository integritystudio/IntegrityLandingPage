# Integrity Studio AI

[![CI](https://github.com/integritystudio/IntegrityLandingPage/actions/workflows/ci.yml/badge.svg)](https://github.com/integritystudio/IntegrityLandingPage/actions/workflows/ci.yml)
[![Coverage](https://img.shields.io/endpoint?url=https://aledlie.github.io/IntegrityLandingPage/badge.json)](https://aledlie.github.io/IntegrityLandingPage/)

Enterprise AI Observability Platform landing page built with Flutter Web.

**Production**: https://integritystudio.ai

## Quick Start

```bash
flutter pub get          # Install dependencies
flutter run -d chrome    # Development server
flutter test             # Run tests (2440+ passing)
flutter build web        # Production build
```

### Shared Worker Library

```bash
cd workers/lib
npm install && npm test           # Tests (79 passing, ~94% coverage)
```

Provides HTTP utilities (CORS, request parsing, response factories, error handling) and validation (Zod-based with typed result unions) shared across worker projects.

### Contact Form Worker

```bash
cd workers/contact-form
npm install && npx wrangler dev   # Local dev
npx vitest run                    # Tests
npx wrangler deploy               # Deploy
```

### API Provisioning Workers

```bash
cd workers/sender-worker
npm install && npx wrangler dev   # Local dev (signs & forwards events)
npx vitest run                    # Tests

cd workers/receiver-worker
npm install && npx wrangler dev   # Local dev (verifies & stores)
npx vitest run                    # Tests
```

## Documentation

- [Architecture](docs/architecture.md) — tech stack, patterns, directory structure
- [Routes](docs/routes.md) — GoRouter configuration, 33 routes
- [API Provisioning](docs/api-provisioning.md) — inter-worker HMAC-SHA256 auth, Flutter service layer, security model
- [Changelog](docs/changelog/1.1/CHANGELOG.md) — version history
- [BACKLOG](docs/BACKLOG.md) — open, deferred, blocked items
- [Token Tree](docs/repomix/token-tree.txt) — file tree with token counts

## Testing

```bash
flutter test                           # All tests
flutter test --coverage                # With coverage (~94%)
flutter test test/pages/               # Page tests only
cd workers/lib && npm test             # Shared library tests
cd workers/contact-form && npx vitest run  # Contact form worker tests
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
