## Hybrid Testing Strategy for ProvisioningService — COMPLETE ✅

**Status**: Implementation complete and tested in CI (all 2736+ tests passing)

### What Was Done
Implemented hybrid testing approach combining unit (mocked), contract (no-network), and integration (staging) tests for the ProvisioningService Dart/TypeScript provisioning flow.

**Files Modified/Created:**
- `workers/receiver-worker/src/index.ts` — Added `apiKey` generation to response (was missing, critical fix)
- `test/helpers/mock_provisioning_dio.dart` — NEW: Extracted shared mock implementation
- `test/services/provisioning_service_test.dart` — 48 unit tests (mocked), all passing
- `test/services/provisioning_service_contract_test.dart` — NEW: 25 contract tests
- `test/services/provisioning_service_live_test.dart` — NEW: 7 live integration tests + 3 skipped
- `.github/workflows/ci.yml` — Added `integration-live` job (runs on main push only)

### Key Technical Fix
**Type Preservation Issue (CRITICAL)**:
- **Problem**: Tests passed locally but failed in CI with "Expected ProvisioningSuccess, got ProvisioningError"
- **Root Cause**: `Response<T>` generic type inference could cause `response.data` to not be recognized as `Map<String, dynamic>` in CI environment
- **Solution**: Changed MockProvisioningDio to explicitly use `Response<dynamic>` before casting to `Response<T>`
- **Impact**: All 7 failing tests now pass in CI

### Test Coverage
- **Unit tests** (48): Retry logic, error handling, field mapping validation
- **Contract tests** (25): Verify Dart API shapes match TypeScript Zod schemas
- **Integration tests** (7 live + 3 skipped): End-to-end staging validation
- **Total**: 80 provisioning-specific tests + 2656 other tests = 2736+ total passing

### CI Status
Latest run (#344): 
- ✅ All 2736 tests passed
- ✅ 7 live integration tests passed (staging)
- ✅ 3 live integration tests skipped (Stripe not configured, bootstrap requires token)
- ✅ All deployments successful
- ✅ Coverage report generated

### How It Works
1. **Unit tests** run on every PR + main (fast, mocked)
2. **Contract tests** run on every PR + main (fast, no network)
3. **Live tests** run on main push only (slow, hits staging, non-blocking with `continue-on-error: true`)

Guard: Live tests use `const _liveTestsEnabled = bool.fromEnvironment('LIVE_TESTS');` — automatically skip in `flutter test --coverage`

Run live tests manually:
```bash
flutter test test/services/provisioning_service_live_test.dart \
  --dart-define=LIVE_TESTS=true \
  --dart-define=SENDER_WORKER_URL=https://sender-worker.alyshia-b38.workers.dev
```
