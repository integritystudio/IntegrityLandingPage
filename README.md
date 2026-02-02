# Integrity Studio AI

[![CI](https://github.com/aledlie/IntegrityLandingPage/actions/workflows/ci.yml/badge.svg)](https://github.com/aledlie/IntegrityLandingPage/actions/workflows/ci.yml)
[![Coverage](https://img.shields.io/endpoint?url=https://aledlie.github.io/IntegrityLandingPage/badge.json)](https://aledlie.github.io/IntegrityLandingPage/)

Landing page for Integrity Studio AI - AI Observability Platform.

## Development

### Prerequisites

- Flutter 3.32.0 or later
- Dart SDK

### Setup

```bash
# Install dependencies
flutter pub get

# Run in development
flutter run -d chrome
```

### Testing

```bash
# Run all unit and widget tests
flutter test

# Run tests with coverage
flutter test --coverage

# Generate HTML coverage report
genhtml coverage/lcov.info -o coverage/html
open coverage/html/index.html

# Run E2E tests in Chrome (requires chromedriver)
chromedriver --port=4444 &
flutter drive --driver=test_driver/integration_test.dart \
  --target=integration_test/e2e/landing_page_test.dart -d chrome
```

### Build

```bash
# Build web release
flutter build web --release
```

## Project Structure

```
lib/
├── config/           # Content configuration
├── pages/            # Landing page, Blog page
├── services/         # Analytics, consent management
├── theme/            # Colors, typography, spacing
└── widgets/
    ├── common/       # Reusable buttons, cards
    └── sections/     # Hero, features, pricing, etc.
```

## Routing

See [docs/routes.md](docs/routes.md) for full routing architecture and route list.

- 27 routes implemented using GoRouter
- Deep linking enabled
- Cookie banner via ShellRoute wrapper

## Reports

| Report | Source |
|--------|--------|
| SOC 2 Type II Compliance | [docs/SOC2-COMPLIANCE-REPORT.md](docs/SOC2-COMPLIANCE-REPORT.md) |

## Test Coverage

Coverage reports are automatically generated and deployed to GitHub Pages on every push to main. Reports include function-level coverage metrics.

**[View Coverage Report](https://aledlie.github.io/IntegrityLandingPage/)**

### Coverage in PRs

Pull requests automatically receive a coverage comment showing:
- Overall coverage percentage
- Function coverage summary
- Link to download the full HTML report
