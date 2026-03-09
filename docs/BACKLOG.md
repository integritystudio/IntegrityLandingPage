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

### Next Steps

1. **Upgrade to Flutter 3.41.4** and re-apply the `--disable-gpu` patch — 3.41 may have the `package:test` WebSocket fix that 3.38 lacks (3.41.4 includes `[stable] Update test package and related packages for stable release`)
2. **Wait for Flutter 3.43+ stable** — the `--disable-gpu` fix (PR #182618) will ship in the next stable release after 3.42 beta promotion
3. **Switch to master channel** — risky for a production project, but would immediately unblock

---

## Deferred: Platform-Limited Test Coverage Gaps

These changelog items have error-handling code that cannot be tested without `flutter test --platform chrome`.
When web-platform CI is added, these MUST be covered.

### #75: `_launchUrl` Error Handling Test Coverage

**Severity:** LOW
**Category:** Test Coverage
**File:** `lib/widgets/sections/footer_section.dart:13-26`

`_launchUrl` wraps `launchUrl()` in try/catch with `ErrorTrackingService.captureException`. The error path cannot be triggered in native widget tests because `url_launcher` uses platform channels that cannot be mocked to throw from the call site.

**Status:** Deferred until web-platform test CI is available.

---

### #76: `_initializeTracking` Error Handling Test Coverage

**Severity:** LOW
**Category:** Test Coverage
**File:** `lib/app.dart:36-66`

`_initializeTracking()` is wrapped in try/catch, but the tracking branches (`kIsWeb`, `ConsentManager.hasConsent()`, `TrackingWeb.*`) are unreachable in native tests. `kIsWeb` is a compile-time constant — native tests always evaluate to `false`, skipping all tracking logic. See `test/app_test.dart:690-701`.

**Status:** Deferred until web-platform test CI is available.

---

## Open: AnalyticsService Test Observability

**Severity:** MEDIUM
**Category:** Test Quality
**File:** `test/controllers/landing_controller_test.dart`

Controller analytics tests (e.g. `trackTierSelection`, `handleGetStarted`, `handleFeatureInteraction`) use `returnsNormally` to verify no exception is thrown, but cannot detect regressions in analytics call arguments. If `AnalyticsService.trackPricingView` were called with the wrong tier string or stopped being called entirely, these tests would still pass.

**Recommendation:** Introduce an `AnalyticsService` mock/spy (e.g. via a static `trackPricingView` call log or dependency injection) to assert that analytics methods are called with the correct arguments.

**Status:** Open — vacuous `expect(true, isTrue)` assertions were replaced with `returnsNormally` in commit `09f2cf0`, but argument verification requires AnalyticsService to be mockable.

---

## Open: Extract Test Constants to Shared File

**Severity:** LOW
**Category:** Test Quality
**File:** `test/pages/landing_page_test.dart`

`kShortAnimationSettle`, `kNavigationSettle`, `kScrollToPricingOffset`, and `kScrollToCTAOffset` are defined at the top of `landing_page_test.dart`. If other test files use the same raw durations/offsets, these constants should be moved to `test/helpers/test_constants.dart` to avoid redeclaration.

**Status:** Ready to implement — raw duplicates already exist in `hero_section_test.dart` (7), `cta_section_test.dart` (5), `docs_api_page_test.dart` (2), `docs_quickstart_page_test.dart` (3), `eu_ai_act_page_test.dart` (1), `about_page_test.dart` (2).

---

## Open: BACKLOG Entry Numbering

**Severity:** LOW
**Category:** Documentation
**File:** `docs/BACKLOG.md`

Recent backlog entries (AnalyticsService mock, test constants) lack tracking numbers (`#N`) unlike earlier numbered items. Add sequential IDs for consistency.

**Status:** Open

---

## Open: Hardcoded Content Duplicating content.yaml

### "Book a 15-minute call" duplicated in Dart source

**Severity:** LOW
**Category:** Code Quality (DRY)
**Files:** `lib/config/content/contact_content.dart:106`, `lib/pages/contact_page.dart:175`

The string `'Book a 15-minute call'` is hardcoded in two Dart files despite being defined in `content.yaml` (line 761, contact methods). These should read from the yaml-loaded contact method value instead of duplicating the string.

**Status:** Open

---

### "Austin, TX" hardcoded in about page

**Severity:** LOW
**Category:** Code Quality (DRY)
**File:** `lib/pages/about_page.dart:458`

`_StatData('Austin, TX', 'Headquarters', ...)` hardcodes the location instead of using `CompanyInfo.locationCity` / `CompanyInfo.locationRegion` which are defined in constants and content.yaml.

**Status:** Open

---

### `privacy@integritystudio.ai` hardcoded in legal page

**Severity:** LOW
**Category:** Code Quality
**File:** `lib/pages/legal_page.dart:325,410,755`

The privacy contact email `privacy@integritystudio.ai` is hardcoded 3 times in the legal page with no content.yaml entry. Consider adding a `company.contact.privacy_email` key to content.yaml if this email should be centrally managed.

**Status:** Open

---

### Hardcoded "5-minute" setup claims in marketing copy

**Severity:** LOW
**Category:** Content Consistency
**Files:** `lib/config/content/comparison_content.dart:53,212,242`, `lib/config/content/resources_content.dart:29`, `lib/config/content/services_content.dart:111`, `lib/pages/docs_quickstart_page.dart:107,132`, `lib/pages/docs_index_page.dart:222`

Multiple files contain hardcoded "5-minute" or "under 5 minutes" setup time claims in marketing copy. `PlatformMetrics.setupTime` now reads `"15 min"` from content.yaml, but these prose strings are separate. Consider using a shared constant or content.yaml value for the prose variant.

**Status:** Open

---

*Last updated: 2026-03-08*
*Migrated items: 24 total → docs/changelog/1.0/CHANGELOG.md:*
  *- 9 items (3 HIGH, 6 MEDIUM) from Flutter expert audit*
  *- 13 items (all LOW) from backlog implementation sprint*
  *- 2 items (all LOW) from code review test coverage findings*
*Remaining open: 1 blocked (#77) + 5 deferred (OAuth #8-#10, test coverage #75-#76) + 7 open (AnalyticsService mock, test constants, entry numbering, 4 hardcoded content items)*
