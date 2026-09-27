# Test Architecture

This project uses three test frameworks at different layers of the testing pyramid.

## Directories

### `test/` — Unit & Widget Tests (Dart)

Primary test suite. Runs via `flutter test`. ~2836 tests.

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

### `e2e/` — Browser E2E Tests (Playwright)

External browser tests using Playwright (Node.js). Tests the deployed/served app from the outside.

```bash
cd e2e && npm test
```

Tests: accessibility, cache headers, landing page content, mobile viewport, routing, SPA navigation.

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
