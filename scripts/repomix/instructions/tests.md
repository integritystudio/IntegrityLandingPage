# Repomix Instruction: Test Suite Context

This pack contains the full test suite for IntegrityStudio.ai — Flutter widget/unit/integration
tests and Cloudflare Workers Vitest suites. Use it when writing new tests, diagnosing test
failures, reviewing coverage patterns, or understanding how existing behavior is asserted.

## What Is Included

| Path | Contents |
|------|----------|
| `test/` | Flutter unit, widget, integration tests (~359K tokens) |
| `integration_test/` | Flutter E2E integration tests (Playwright via semantics) |
| `workers/*/src/**/*.test.ts` | Vitest suites for all five workers |

## Navigation

- **Test helpers**: `test/helpers/` — `test_helpers.dart`, `test_content.dart`, `test_constants.dart`
- **Mock services**: `test/integration/helpers/mock_services.dart`
- **Worker test patterns**: each worker's `src/*.test.ts` mirrors its source file
- **Coverage report**: https://aledlie.github.io/IntegrityLandingPage/

## Key Patterns

- Flutter widget tests use `testWidgets` + `MockGoRouter` from `test_helpers.dart`
- Content is injected via `TestContent` stubs, not real YAML loading
- Worker tests use Vitest `vi.fn()` mocks for Supabase, KV, and Durable Objects
- E2E tests must call `enableFlutterSemantics()` before interacting with Flutter canvas widgets

## Known Gaps

- `social_proof_section_test.dart` is inactive (`.inactive` extension)
- Sender-worker has 15 known failing tests (pre-existing, not a regression)
- `_launchUrl` and `_initializeTracking` error paths are untestable in the test environment
