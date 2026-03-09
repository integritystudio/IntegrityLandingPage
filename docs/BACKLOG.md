# Security & Infrastructure Backlog

Open and deferred items only. Completed items are documented in `docs/changelog/1.0/CHANGELOG.md`.

---

## Deferred: OAuth Security (#8-#10)

These issues are **deferred** because this is a landing page with placeholder OAuth callback UI and no OAuth backend.
When OAuth is implemented, these MUST be added.

| Issue | Severity | Description |
|-------|----------|-------------|
| #8 OAuth State Validation | CRITICAL | CSRF via unvalidated `state` parameter |
| #9 PKCE Implementation | CRITICAL | Authorization code interception (RFC 7636) |
| #10 Auth Code Validation | CRITICAL | Success shown before token exchange |

See git history for full implementation plans (removed from backlog on 2026-02-12 migration to CHANGELOG).

---

## Accepted Risk

### #23: KV Eventual Consistency Window

**Severity:** HIGH (accepted risk)
**Category:** Reliability
**File:** `workers/contact-form/src/index.ts:130-152`

KV is eventually consistent. Two requests from same IP at different datacenters can both read count=4, both increment to 5. Rate limit can be exceeded by ~2-3x.

**Status:** Accepted risk for contact form use case.

---

### #30: Multi-Environment CSP Endpoints

**Severity:** LOW (accepted)
**Category:** Infrastructure
**File:** `web/_headers`

CSP report-uri/report-to endpoints shared across staging/production. Staging is Cloudflare Pages preview deployments using the same `_headers` file. All reports go to the same Sentry project.

**Status:** Accepted for landing page use case. Documented in `web/_headers`. If env-specific reporting is needed, use a build script to replace the DSN.

---




## Blocked: Chrome Platform Tests (#77)

**Severity:** CRITICAL
**Category:** Test Infrastructure
**Status:** Blocked — `flutter test --platform chrome` hangs indefinitely

`flutter test --platform chrome` never executes — hangs at "loading" forever, even on a trivial empty test. This blocks all web-only test coverage (#75, #76) and prevents testing `kIsWeb` branches.

### Root Cause (confirmed 2026-03-08)

Two upstream bugs in Flutter's `ChromiumLauncher` (`flutter_tools/lib/src/web/chrome.dart:249-254`):

1. **`--disable-gpu` flag** — Flutter passes `--disable-gpu` when launching headless Chrome for tests. This disables WebGL, which CanvasKit/SkWasm requires to initialize. Without WebGL, the Flutter web app never loads and the test runner hangs waiting for a response.
2. **`package:test` Chrome runner WebSocket hang** — even after patching out `--disable-gpu`, the `package:test` browser manager on Flutter 3.38.5 fails to establish WebSocket communication with headless Chrome. The test compiles and Chrome launches, but the runner never receives a response.

### Upstream Issues

- [flutter/flutter#177008](https://github.com/flutter/flutter/issues/177008) — `flutter test --platform chrome --wasm` hangs (CLOSED 2026-02-23, fix merged)
- [flutter/flutter#162798](https://github.com/flutter/flutter/issues/162798) — `flutter test --platform chrome` hangs on loading (OPEN, same root cause)
- [flutter/flutter#182618](https://github.com/flutter/flutter/pull/182618) — `[web] Remove --disable-gpu from flutter chrome tests` (merged to master 2026-02-23)

### Fix Availability

| Channel | Version | `--disable-gpu` fix? |
|---------|---------|---------------------|
| stable  | 3.38.5 (current) | No |
| stable  | 3.41.4 (latest)  | No |
| beta    | 3.42.0-0.4.pre   | No |
| master  | HEAD             | Yes (PR #182618)    |

The fix removes `'--disable-gpu'` from the headless Chrome args. It landed on master but has not been cherry-picked to any stable or beta release as of 2026-03-08.

### Environment

- Flutter 3.38.5 (stable, 2025-12-11)
- Chrome 145.0.7632.160
- ChromeDriver 145.0.7632.117
- macOS 26.2 (darwin-arm64)
- `flutter doctor`: Chrome detected, no issues reported

### What Was Tried

1. `flutter test --platform chrome test/web_smoke_test.dart` — hangs at "loading" (60s timeout, 0 tests ran)
2. `flutter test --platform chrome --wasm test/web_smoke_test.dart` — compiles wasm successfully, still hangs at "loading"
3. `CHROME_EXECUTABLE=... flutter test --platform chrome` — same hang
4. `flutter test --platform chrome -v` — verbose log stops at "Found 1 files which will be executed as Widget Tests", never reaches Chrome launch
5. `flutter drive -d chrome --headless` with ChromeDriver — connected to debug service (`ws://127.0.0.1:…/ws`), DDC loaded 666/666 scripts, then hung indefinitely. Same `--disable-gpu`/WebGL failure.
6. `dart_test.yaml` with `override_platforms` — does NOT control Flutter's `ChromiumLauncher`, so cannot override Chrome flags. Not a viable workaround.
7. **Local SDK patch** — removed `'--disable-gpu'` from `chrome.dart:252`, deleted `flutter_tools.snapshot` to force recompile. Flutter rebuilt the tool, but `flutter test --platform chrome` still hung at "loading". Confirms the `--disable-gpu` fix alone is insufficient on Flutter 3.38.5; the `package:test` WebSocket runner has a separate bug at this SDK version.

### Prerequisite Fix Applied

`test/helpers/test_content.dart` previously used `dart:io` (`File.existsSync`) which caused a compile error on web. Fixed with conditional imports:
- `load_content_native.dart` — `dart:io` file read
- `load_content_web.dart` — `rootBundle.loadString()` for browser
- `load_content_stub.dart` — fallback stub
- `flutter_test_config.dart` — `kIsWeb` branch with `TestWidgetsFlutterBinding.ensureInitialized()`

### Unblocks

- **#75**: `_launchUrl` error handling test (`footer_section.dart:13-26`)
- **#76**: `_initializeTracking` error handling test (`app.dart:36-66`)
- All `kIsWeb` branch coverage in `app.dart` (currently ~50% native ceiling)

### Research Update (2026-03-08)

- **PR #182618** merged to master Feb 23, 2026 but NOT cherry-picked to stable or beta
- **Flutter 3.41** (latest stable, Feb 2026) branch cutoff was Jan 6 — fix missed the train
- **Issue #162798** (WebSocket hang) remains OPEN with no upstream fix
- **`package:test` version** is SDK-bundled via `flutter_test` (pubspec.lock shows only `test_api: 0.7.7` transitive) — cannot be independently upgraded to 1.25.12
- **Upgrading to 3.41 alone will NOT fix this** — both bugs remain unpatched in all stable/beta releases
- **Next stable with the fix: Flutter 3.44 (May 2026)** — branch cutoff April 7, 2026

### Next Steps

1. ~~**File cherry-pick request** for PR #182618 to stable~~ — DONE 2026-03-08, [comment posted](https://github.com/flutter/flutter/pull/182618#issuecomment-4021062481)
2. ~~**Test on master channel**~~ — DONE 2026-03-08. Tested on Flutter master 3.42.0-1.0.pre-441 (Dart 3.12.0, `test_api` 0.7.10). **Still hangs at "loading"** after 90s. Confirms `--disable-gpu` fix alone is insufficient — the `package:test` WebSocket hang (#162798) is a separate, independent bug
3. **Wait for Flutter 3.44 stable (May 2026)** — the `--disable-gpu` fix (PR #182618) ships automatically if it lands before the April 7 cutoff
4. ~~**Playwright workaround**~~ — DONE 2026-03-09. Added `e2e/tests/web-platform.spec.ts` (11 tests, all passing) covering:
   - #76: `_initializeTracking` consent → GTM/GA4/FB Pixel flow, corrupted data resilience, consent persistence across reload
   - #75: `_launchUrl` web platform availability (window.open), footer scroll stability
   - GDPR: GTM not injected before consent, meta-pixel.js loaded, dataLayer initialized
   - Shared constants added to `e2e/tests/constants.ts` (CONSENT_STORAGE_KEY, GTM_CONTAINER_ID, etc.)

---

## Deferred: Platform-Limited Test Coverage Gaps

These changelog items have error-handling code that cannot be tested without `flutter test --platform chrome`.
When web-platform CI is added, these MUST be covered.

### #75: `_launchUrl` Error Handling Test Coverage

**Severity:** LOW
**Category:** Test Coverage
**File:** `lib/widgets/sections/footer_section.dart:13-26`

`_launchUrl` wraps `launchUrl()` in try/catch with `ErrorTrackingService.captureException`. The error path cannot be triggered in native widget tests because `url_launcher` uses platform channels that cannot be mocked to throw from the call site.

**Status:** Partially covered by Playwright e2e (`e2e/tests/web-platform.spec.ts`). Happy path (web platform link opening) verified. Error path (catch block with `ErrorTrackingService.captureException`) still requires `flutter test --platform chrome` for unit-level coverage.

---

### #76: `_initializeTracking` Error Handling Test Coverage

**Severity:** LOW
**Category:** Test Coverage
**File:** `lib/app.dart:36-66`

`_initializeTracking()` is wrapped in try/catch, but the tracking branches (`kIsWeb`, `ConsentManager.hasConsent()`, `TrackingWeb.*`) are unreachable in native tests. `kIsWeb` is a compile-time constant — native tests always evaluate to `false`, skipping all tracking logic. See `test/app_test.dart:690-701`.

**Status:** Partially covered by Playwright e2e (`e2e/tests/web-platform.spec.ts`). Tests verify: consent persistence, corrupted data resilience (exercises try/catch), GTM injection after consent, and no unhandled errors. Unit-level mock coverage of `ErrorTrackingService.captureException` still requires `flutter test --platform chrome`.

---

## ~~Open~~ Done: AnalyticsService Test Observability (#81)

**Severity:** MEDIUM
**Category:** Test Quality
**File:** `test/controllers/landing_controller_test.dart`

Controller analytics tests (e.g. `trackTierSelection`, `handleGetStarted`, `handleFeatureInteraction`) use `returnsNormally` to verify no exception is thrown, but cannot detect regressions in analytics call arguments. If `AnalyticsService.trackPricingView` were called with the wrong tier string or stopped being called entirely, these tests would still pass.

**Recommendation:** Introduce an `AnalyticsService` mock/spy (e.g. via a static `trackPricingView` call log or dependency injection) to assert that analytics methods are called with the correct arguments.

**Status:** Done — `@visibleForTesting` call log spy added to `lib/services/analytics.dart` (`enableCallLog()`, `resetForTesting()`, `callLog`). All 8 controller analytics tests upgraded from `returnsNormally` to argument-verifying assertions. Committed in `678b892`.

---

## ~~Open~~ Done: Extract Test Constants to Shared File (#82)

**Severity:** LOW
**Category:** Test Quality
**File:** `test/pages/landing_page_test.dart`

`kShortAnimationSettle`, `kNavigationSettle`, `kScrollToPricingOffset`, and `kScrollToCTAOffset` are defined at the top of `landing_page_test.dart`. If other test files use the same raw durations/offsets, these constants should be moved to `test/helpers/test_constants.dart` to avoid redeclaration.

**Status:** Done — `test/helpers/test_constants.dart` created with all 4 constants. Landing page test definitions removed; 7 test files updated to import and use the shared constants. Committed in `d00205b`.

---

## ~~Open~~ Done: BACKLOG Entry Numbering (#83)

**Severity:** LOW
**Category:** Documentation
**File:** `docs/BACKLOG.md`

Recent backlog entries (AnalyticsService mock, test constants) lack tracking numbers (`#N`) unlike earlier numbered items. Add sequential IDs for consistency.

**Status:** Done — IDs #81–#87 assigned to all unnumbered entries in this session.

---

## ~~Open~~ Done: Hardcoded Content Duplicating content.yaml

### ~~Open~~ Done: "Book a 15-minute call" duplicated in Dart source (#84)

**Severity:** LOW
**Category:** Code Quality (DRY)
**Files:** `lib/config/content/contact_content.dart:106`, `lib/pages/contact_page.dart:175`

The string `'Book a 15-minute call'` is hardcoded in two Dart files despite being defined in `content.yaml` (line 761, contact methods). These should read from the yaml-loaded contact method value instead of duplicating the string.

**Status:** Done — added `Content.contactScheduleDemoValue` accessor to `content_loader.dart` (reads `contact.contact_methods[label='Schedule a Demo'].value` from yaml). `contact_page.dart:175` now uses the accessor. Committed in `23cab05`.

---

### ~~Open~~ Done: "Austin, TX" hardcoded in about page (#85)

**Severity:** LOW
**Category:** Code Quality (DRY)
**File:** `lib/pages/about_page.dart:458`

`_StatData('Austin, TX', 'Headquarters', ...)` hardcodes the location instead of using `CompanyInfo.locationCity` / `CompanyInfo.locationRegion` which are defined in constants and content.yaml.

**Status:** Done — added `CompanyInfo.locationRegionAbbrev = 'TX'` to `constants.dart`. `about_page.dart:458` now uses `'${CompanyInfo.locationCity}, ${CompanyInfo.locationRegionAbbrev}'`. Committed in `23cab05` + `ff68a7f`.

---

### ~~Open~~ Done: `privacy@integritystudio.ai` hardcoded in legal page (#86)

**Severity:** LOW
**Category:** Code Quality
**File:** `lib/pages/legal_page.dart:325,410,755`

The privacy contact email `privacy@integritystudio.ai` is hardcoded 3 times in the legal page with no content.yaml entry.

**Status:** Done — added `CompanyInfo.privacyEmail = 'privacy@integritystudio.ai'` to `constants.dart`. All 3 occurrences in `legal_page.dart` use `${CompanyInfo.privacyEmail}`. Committed in `23cab05`.

---

### ~~Open~~ Done: Hardcoded "5-minute" setup claims in marketing copy (#87)

**Severity:** LOW
**Category:** Content Consistency
**Files:** `lib/config/content/comparison_content.dart:53,212,242`, `lib/config/content/resources_content.dart:29`, `lib/config/content/services_content.dart:111`, `lib/pages/docs_quickstart_page.dart:107,132`, `lib/pages/docs_index_page.dart:222`

Multiple files contain hardcoded "5-minute" or "under 5 minutes" setup time claims inconsistent with `PlatformMetrics.setupTime` ("15 min" from content.yaml).

**Status:** Done — comparison_content.dart literals updated; docs pages use `PlatformMetrics.setupTime`; dead-code variants updated; stale doc comment and test stub fixed. Committed in `8ae8936` + `eca800a`. Note: `content.yaml` prose strings at lines 465, 832 still contain "5 minutes" (pre-existing yaml content inconsistency, out of code scope).

## Open: E2E Test Timeout and Navigation Issues

**Category:** Test Infrastructure (Playwright)
**Source:** Session 2026-03-09 (e2e suite run)

### #78: E2E Route Load Timeout on Production

**Severity:** MEDIUM
**Category:** Test Infrastructure
**Files:** `e2e/tests/backlog-sprint.spec.ts:85`, `e2e/tests/scroll-analytics.spec.ts:43`

Two Playwright e2e tests timeout waiting for Flutter to initialize on production routes:
- `backlog-sprint.spec.ts:85` — `/docs/tracing` route fails with `TimeoutError: page.waitForFunction: Timeout 90000ms exceeded`
- `scroll-analytics.spec.ts:43` — `incremental scrolling` test fails with `mouse.wheel: Test timeout of 120000ms exceeded`

**Root cause:** Unknown — likely production site performance variance or network latency. Tests run successfully against local dev server.

**Status:** Deferred (intermittent, may be infrastructure-dependent). Monitor test runs; if consistently fails, investigate production CDN/route performance.

---

### #79: E2E Anchor Navigation Response Undefined

**Severity:** LOW
**Category:** Test Infrastructure
**File:** `e2e/tests/footer-links.spec.ts:75`

Test `anchor route #features navigates to home page` fails with:
```
Error: expect(received).toBe(expected) // Object.is equality
Expected: 200
Received: undefined
```

At line: `expect(response?.status()).toBe(200);`

**Root cause:** Hash navigation (`page.goto('/#features')`) is client-side only — `response` object is undefined for anchor-only navigations. The test should check if response is null before asserting status.

**Fix:** Change assertion from `expect(response?.status()).toBe(200)` to `expect(response === null || response.status() === 200).toBe(true)` (accept null response for hash-only navigation).

**Status:** Done — Fixed in `e2e/tests/footer-links.spec.ts` with `if (response) { expect(response.status()).toBe(200); }`. Committed in `a902ef5`.

---

### #80: Flutter SDK ink_sparkle.frag Shader Format Version Mismatch

**Severity:** MEDIUM
**Category:** Flutter SDK
**Root cause:** Stale compiled shader artifacts from previous Flutter version

During `flutter test` run, shader format version mismatch causes 36 test failures in `cookie_banner_test.dart`:
```
Exception: Asset 'shaders/ink_sparkle.frag' manifest could not be decoded: INVALID_ARGUMENT:
Unsupported runtime stages format version. Expected 1, got 0.
```

**Upstream context:** Flutter PR #175470 (merged Dec 2, 2025) introduced flatbuffer format versioning for impellerc. Stale pre-versioning compiled artifacts (v0) trigger the error when loaded by new engine expecting v1.

**Workaround applied:** `flutter clean && flutter pub get` clears artifacts and forces recompile with correct format version. After clean, all 2319 tests pass.

**Status:** Closed (workaround in place). Recommend running `flutter clean` on CI before test runs or upgrading to a newer Flutter stable that backports the engine fix.

---

*Last updated: 2026-03-09 (e2e suite and Flutter test completion)*
*Migrated items: 24 total → docs/changelog/1.0/CHANGELOG.md:*
  *- 9 items (3 HIGH, 6 MEDIUM) from Flutter expert audit*
  *- 13 items (all LOW) from backlog implementation sprint*
  *- 2 items (all LOW) from code review test coverage findings*
*Remaining open: 1 blocked (#77) + 5 deferred (OAuth #8-#10, test coverage #75-#76) + 1 deferred (#78 intermittent timeout)*
*Closed this session: #79 (anchor nav), #80 (shader format), #81 (analytics spy), #82 (test constants), #83 (backlog numbering), #84 (15-min call), #85 (Austin TX), #86 (privacy email), #87 (5-min setup)*
