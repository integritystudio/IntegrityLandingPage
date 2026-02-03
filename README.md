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
| [SOC 2 Type II Compliance](docs/SOC2-COMPLIANCE-REPORT.md) | Compliance documentation |

## Project Structure

```
lib/
├── pages/       # 26 page widgets
├── widgets/     # Reusable components
├── services/    # Content loading, analytics, consent
├── routing/     # GoRouter configuration
└── theme/       # Design system
```

See [docs/architecture.md](docs/architecture.md) for detailed breakdown.

## Testing

```bash
flutter test                           # All tests
flutter test --coverage                # With coverage
flutter test test/pages/               # Page tests only
```

**[View Coverage Report](https://aledlie.github.io/IntegrityLandingPage/)** (~94% coverage)
