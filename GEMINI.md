# Integrity Studio AI - Project Overview

This document provides an overview of the Integrity Studio AI project, a Flutter Web-based landing page for an Enterprise AI Observability Platform. It covers the project's architecture, development practices, and operational aspects to serve as a comprehensive guide for future interactions.

## Project Overview

The Integrity Studio AI landing page is built with Flutter Web and deployed on Cloudflare Pages, utilizing Cloudflare Workers for backend services. The project emphasizes a clear separation of concerns, robust routing, efficient content loading, and comprehensive testing.

**Key Technologies:**
*   **Frontend:** Flutter 3.x (Web)
*   **Routing:** GoRouter
*   **State Management:** Provider, ValueNotifier
*   **Backend:** Cloudflare Workers (for contact form submissions)
*   **Hosting:** Cloudflare Pages
*   **Error Tracking:** Sentry
*   **Analytics:** Google Tag Manager (GTM) with Consent Mode v2, Facebook Pixel

## Directory Structure

```
.
├── .github/          # GitHub Actions workflows (CI/CD)
├── android/          # Android specific project files
├── assets/           # Static assets (images, icons, lottie animations)
├── build/            # Build output directory
├── docs/             # Project documentation (architecture, routes, changelog)
├── e2e/              # End-to-End tests (Playwright)
├── integration_test/ # Flutter Integration tests
├── ios/              # iOS specific project files
├── lib/              # Main application source code
│   ├── config/       # Content configuration
│   │   └── content/  # Static content definitions
│   ├── controllers/  # Business logic controllers
│   ├── models/       # Data models
│   ├── pages/        # Page widgets (26 pages)
│   ├── providers/    # Provider setup
│   ├── routing/      # GoRouter configuration
│   ├── services/     # External service integrations (analytics, consent, contact)
│   ├── theme/        # Design system (colors, decorations, spacing, typography)
│   ├── widgets/      # Reusable components
│   │   ├── common/   # Shared widgets
│   │   ├── consent/  # Cookie consent UI
│   │   ├── decorative/ # Visual elements
│   │   ├── docs/     # Documentation components
│   │   ├── modals/   # Dialog components
│   │   └── sections/ # Page sections
│   ├── app.dart      # Main App widget
│   └── main.dart     # Application entry point
├── marketing/        # Marketing related assets
├── reports/          # Compliance and policy reports
├── scripts/          # Utility scripts (e.g., add_function_coverage.dart)
├── test/             # Unit and Widget tests
├── test_driver/      # Flutter driver tests
├── web/              # Web specific files (index.html, manifest, SEO files)
└── workers/          # Cloudflare Workers backend services
    └── contact-form/ # Contact form worker
```

## Building and Running

### Development Server

```bash
flutter pub get          # Install dependencies
flutter run -d chrome    # Run development server in Chrome
```

### Production Build

```bash
flutter build web        # Create a production-ready web build
```

### Sentry Configuration

Sentry is configured via compile-time environment variables. Example build command:

```bash
flutter build web \
  --dart-define=SENTRY_DSN=your-dsn \
  --dart-define=ENVIRONMENT=production \
  --dart-define=APP_VERSION=2.0.0
```

## Testing

The project includes a comprehensive testing suite:

*   **Unit Tests:** Fast tests for individual functions and classes.
*   **Widget Tests:** Tests for UI components.
*   **Integration Tests:** Tests for application flows.
*   **E2E Tests (Playwright):** End-to-end tests for the deployed application.

### Running Tests

```bash
flutter test             # Run all unit and widget tests
flutter test --coverage  # Run tests with coverage reporting
```

**Test Status:**
*   Unit and Widget tests: **Passed** (as of last run).
*   E2E tests: **Blocked** due to `chromedriver` not being installed. To run E2E tests, `chromedriver` must be installed (`brew install chromedriver` on macOS).

**Coverage:** The CI pipeline generates a detailed coverage report and badge.

## Development Conventions

*   **Code Style:** Enforced by `flutter_lints` as configured in `analysis_options.yaml`.
*   **Routing:** All navigation is handled using GoRouter.
*   **Content:** Static site content is managed in `content.yaml` and loaded via `ContentLoader`.
*   **State Management:** `Provider` for app-wide state, `ValueNotifier` for simple UI state like the cookie banner.
*   **Theme:** Centralized theme system in `lib/theme/` for consistent UI.

## CI/CD

The project uses GitHub Actions for Continuous Integration and Deployment:

*   **CI Workflow (`.github/workflows/ci.yml`):**
    *   Triggers on `push` and `pull_request` to `main`.
    *   Runs `flutter analyze` and `flutter test --coverage`.
    *   Generates and uploads a coverage report and badge.
    *   Comments coverage results on Pull Requests.
    *   Builds the web application (`flutter build web --release`).
    *   Validates Subresource Integrity (SRI) hashes for critical JavaScript files.
    *   Deploys the web build to Cloudflare Pages (on `main` branch pushes).
    *   Deploys the coverage report to GitHub Pages (on `main` branch pushes).

## Key Files

*   `pubspec.yaml`: Project dependencies and metadata.
*   `content.yaml`: All static site content.
*   `analysis_options.yaml`: Dart linter rules.
*   `web/index.html`: Main HTML shell for the web application, including SEO meta and SRI hashes.
*   `lib/main.dart`: Application entry point and Sentry/GTM initialization.
*   `lib/app.dart`: Main Flutter widget, GoRouter setup, and consent handling.
*   `docs/architecture.md`: Detailed project architecture documentation.
