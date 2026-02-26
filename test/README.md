# Test Architecture

This project uses four test frameworks at different layers of the testing pyramid.

## Directories

### `test/` — Unit & Widget Tests (Dart)

Primary test suite. Runs via `flutter test`. ~1978 tests, ~94% coverage.

| Subdirectory | Purpose |
|---|---|
| `unit/` | Pure logic: theme tokens, content models, services, config |
| `pages/` | Individual page widget rendering and interaction |
| `widgets/` | Reusable component rendering and callbacks |
| `services/` | Service layer: analytics, consent, contact, content |
| `controllers/` | Business logic controllers |
| `routing/` | GoRouter config, redirects, cookie shell |
| `providers/` | Provider setup |
| `integration/` | Multi-page user flows using Dart test framework |
| `helpers/` | Shared utilities: viewport setup, overflow suppression, mocks, content fixtures |

### `integration_test/` — Flutter Integration Tests (Dart)

On-device integration tests using Flutter's `integration_test` package. Tests run against a real Flutter app instance.

```bash
flutter test integration_test/
```

| File | Coverage |
|---|---|
| `consent_flow_test.dart` | Cookie consent banner interaction |
| `contact_form_test.dart` | Contact form submission flow |
| `landing_page_test.dart` | Full landing page rendering |
| `navigation_test.dart` | Route navigation between pages |

### `e2e/` — Browser E2E Tests (Playwright)

External browser tests using Playwright (Node.js). Tests the deployed/served app from the outside.

```bash
cd e2e && npm test
```

Tests: accessibility, cache headers, landing page content, mobile viewport, routing, SPA navigation.

### `test_driver/` — Integration Test Driver

Flutter test driver entry point for running `integration_test/` tests on a device/browser.

```bash
flutter drive --driver=test_driver/integration_test.dart --target=integration_test/e2e/landing_page_test.dart -d chrome
```

## Shared Helpers

- `test/helpers/test_helpers.dart` — Viewport utilities, overflow suppression, widget wrappers, page structure tests, assertion helpers
- `test/helpers/test_content.dart` — Content fixtures for testing without loading `content.yaml`
- `test/integration/helpers/integration_test_helpers.dart` — GoRouter-specific helpers (route pumping, navigation, form filling); re-exports shared helpers

## Key Conventions

- Two `pump()` calls for widget tree to stabilize
- `setDesktopSize(tester)` / `setMobileSize(tester)` for responsive tests
- `pumpFrames()` for pages with continuous animations (avoids `pumpAndSettle` timeout)
- `setUpOverflowErrorSuppression()` in `setUp()`, tear down in `tearDown()`
- `IntegrationMocks.resetAll()` between tests that use mocked services
