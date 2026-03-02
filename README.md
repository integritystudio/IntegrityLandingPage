# Integrity Studio AI

[![CI](https://github.com/integritystudio/IntegrityLandingPage/actions/workflows/ci.yml/badge.svg)](https://github.com/integritystudio/IntegrityLandingPage/actions/workflows/ci.yml)
[![Coverage](https://img.shields.io/endpoint?url=https://aledlie.github.io/IntegrityLandingPage/badge.json)](https://aledlie.github.io/IntegrityLandingPage/)

Enterprise AI Observability Platform landing page built with Flutter Web.

**Production**: https://integritystudio.ai

## Quick Start

```bash
flutter pub get          # Install dependencies
flutter run -d chrome    # Development server
flutter test             # Run tests (1978+ passing)
flutter build web        # Production build
```

## Documentation

| Document | Description |
|----------|-------------|
| [Architecture](docs/architecture.md) | Tech stack, patterns, directory structure |
| [Routes](docs/routes.md) | GoRouter configuration, 27 routes |
| [Changelog](docs/CHANGELOG.md) | Version history, recent changes |
| [BACKLOG](docs/BACKLOG.md) | documented backlog items |
| [Token Count Tree](docs/repomix/token-count-tree.txt) | File tree with token counts |
| [SOC 2 Type II Compliance](docs/SOC2-COMPLIANCE-REPORT.md) | Compliance documentation |

## Project Structure

```
lib/
├── config/           # Content configuration
│   └── content/      # Static content definitions
├── controllers/      # Business logic controllers
├── models/           # Data models
├── pages/            # Page widgets (26 pages)
├── providers/        # Provider setup
├── routing/          # GoRouter configuration
├── services/         # External service integrations (analytics, consent, contact)
├── theme/            # Design system (colors, decorations, spacing, typography)
├── widgets/          # Reusable components
│   ├── common/       # Shared widgets
│   ├── consent/      # Cookie consent UI
│   ├── decorative/   # Visual elements
│   ├── docs/         # Documentation components
│   ├── modals/       # Dialog components
│   └── sections/     # Page sections
├── app.dart          # Main App widget
└── main.dart         # Application entry point
```

## Testing

```bash
flutter test                           # All tests
flutter test --coverage                # With coverage
flutter test test/pages/               # Page tests only
```

**[View Coverage Report](https://aledlie.github.io/IntegrityLandingPage/)** (~94% coverage)
