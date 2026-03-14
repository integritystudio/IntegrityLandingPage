# Integrity Studio AI

[![CI](https://github.com/integritystudio/IntegrityLandingPage/actions/workflows/ci.yml/badge.svg)](https://github.com/integritystudio/IntegrityLandingPage/actions/workflows/ci.yml)
[![Coverage](https://img.shields.io/endpoint?url=https://aledlie.github.io/IntegrityLandingPage/badge.json)](https://aledlie.github.io/IntegrityLandingPage/)

Enterprise AI Observability Platform landing page built with Flutter Web.

**Production**: https://integritystudio.ai

## Quick Start

```bash
flutter pub get          # Install dependencies
flutter run -d chrome    # Development server
flutter test             # Run tests (2173+ passing)
flutter build web        # Production build
```

### Contact Form Worker

```bash
cd workers/contact-form
npm install && npx wrangler dev   # Local dev
npx vitest run                    # Tests
npx wrangler deploy               # Deploy
```

## Documentation

- [Architecture](docs/architecture.md) — tech stack, patterns, directory structure
- [Routes](docs/routes.md) — GoRouter configuration, 33 routes
- [Changelog](docs/changelog/1.1/CHANGELOG.md) — version history
- [BACKLOG](docs/BACKLOG.md) — open, deferred, blocked items
- [Token Count Tree](docs/repomix/token-count-tree.txt) — file tree with token counts

## Testing

```bash
flutter test                           # All tests
flutter test --coverage                # With coverage (~94%)
flutter test test/pages/               # Page tests only
cd workers/contact-form && npx vitest run  # Worker tests
```

**[Coverage Report](https://aledlie.github.io/IntegrityLandingPage/)**

### Platform-Limited Test Gaps

| Item | File | Reason |
|------|------|--------|
| #75 `_launchUrl` error handling | `lib/widgets/sections/footer_section.dart` | `url_launcher` failures untestable in widget tests |
| #76 `_initializeTracking` error handling | `lib/app.dart` | `kIsWeb` compile-time constant; requires web platform |

See `test/app_test.dart:690-701` for native test ceiling details.

### Known Issues

**Flutter Canvas Limitation (CanvasKit)** — Flutter Web renders all content to `<canvas>`, making DOM-based selectors (Playwright `page.locator()`, `page.click()`) unable to reach widget content. Workaround: `Semantics` widget wrappers expose ARIA labels accessible via `page.getByLabel()`. `SemanticsBinding.instance.ensureSemantics()` enables the semantics tree at startup. Some browsers may fail to materialise the tree ([Flutter #151929](https://github.com/flutter/flutter/issues/151929)); e2e tests gracefully skip in that case. Interactions that require pixel-level canvas hit-testing (touch fling, swipe gestures, overlay opacity) remain infeasible.
