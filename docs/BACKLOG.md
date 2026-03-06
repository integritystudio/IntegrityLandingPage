# Security & Infrastructure Backlog

Open and deferred items only. Completed items are documented in `docs/CHANGELOG.md`.

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

## Testing Infrastructure

### E3: chromedriver not installed ✅ Done

**Severity:** LOW
**Category:** Testing Infrastructure
**Resolved:** 2026-03-01 — chromedriver v145.0.7632.117 installed at `~/.local/bin/chromedriver`, matching Chrome v145.0.7632.117.

---

## Code Quality: ast-grep Review Findings (2026-02-25)

### #31: console.log in e2e tests ✅ Done

**Severity:** WARNING
**Category:** Code Quality
**Resolved:** 2026-02-27 — console.log calls replaced with array capture + afterEach warning pattern in both spec files. Debug artifact on line 27 removed.

---

### #32-36: `let` used where `const` suffices — kvFailureCount, kvCircuitResetAt, evicted, mismatch, i ✅ False Positives

**Severity:** INFO
**Category:** Code Quality
**Resolved:** 2026-02-27 — All verified as reassigned:
- `kvFailureCount` / `kvCircuitResetAt`: module-scoped circuit breaker state, mutated by request handlers
- `evicted` / `mismatch` / `i`: mutated in loop bodies via `++`, `|=`, `++`

All five are correctly typed as `let`; ast-grep rule produced false positives.

---

### #37: Magic numbers in e2e tests ✅ Done

**Severity:** LOW
**Category:** Code Quality
**Resolved:** 2026-03-01 — Created `e2e/tests/constants.ts` with named constants for timeout durations (FLUTTER_INIT_TIMEOUT_MS, ROUTE_CHANGE_TIMEOUT_MS, CLICK_SETTLE_MS, etc.), nav bar pixel coordinates (NAV_Y, NAV_PRICING_X, NAV_CTA_X), scroll delta (SCROLL_DELTA_PX), and screenshot output paths (9 constants). Updated landing-page.spec.ts and helpers.ts. Removed unused import. (00b36c3, 39074bf)

---

### #38: Magic numbers in contact-form worker ✅ Done

**Severity:** LOW
**Category:** Code Quality
**Resolved:** 2026-02-27 — Added `IN_MEMORY_CLEANUP_THRESHOLD`, `KV_CIRCUIT_RESET_COOLDOWN_MS`, `KV_CIRCUIT_RESET_JITTER_MS`, `MIN_KV_TTL_SECONDS`, `IDEMPOTENCY_TTL_SECONDS`. All inline literals replaced.

---

## Code Quality: contact_section_test.dart Review (2026-02-26)

Findings from expert code-reviewer audit. H1, H3, H4, M3, M8, M9 were fixed this session.

### #39: Index-based field selectors in fillAndSubmitForm (H2) ✅ Done

**Severity:** HIGH
**Category:** Test Quality
**Resolved:** 2026-02-27 — Added `key: ValueKey(field.name)` to all form field widgets in `_buildField`. Migrated `fillAndSubmitForm` and 3 additional inline test locations to `find.byKey()` selectors.

---

### #40-45: contact_section_test MEDIUM issues ✅ Done

**Resolved:** 2026-02-27
- **#40**: Magic integers → `containsAll` on field/method names
- **#41**: Renamed misleading test to `'displays generic error alert when callback returns false'`
- **#42**: Extracted section heading constants (`kSectionGetInTouch`, `kSectionFollowUs`, `kSectionSendMessage`, `kSectionLiveDemo`)
- **#43**: Added `setUpAll(() => initializeTestContent())` at outer group scope
- **#44**: Extracted `buildRouterWidget` helper; W5 GoRouter test reduced from 35 inline lines
- **#45**: Removed W4 Facebook Pixel duplicate group; added documentation comment to W1

---

### #46-50: contact_section_test LOW issues ✅ Done

**Resolved:** 2026-02-27
- **#46**: Added comment to `setLargeViewport` explaining 1920×1080 vs shared 1440×900 intent
- **#47**: Renamed `'renders with empty content'` → `'renders with partial content override'`
- **#48**: Wrapped external URL test in `buildRouterWidget`; asserts `'Demo Page' findsNothing` after tap
- **#49**: Consolidated redundant `pump()` calls in `fillAndSubmitForm` and 3 inline fill sites
- **#50**: Changed `findsWidgets` → `findsOneWidget` for form label assertions

---

## Priority Matrix

| Issue | Severity | Category | Status |
|-------|----------|----------|--------|
| E3 chromedriver not installed | LOW | Testing Infra | ✅ Done — 2026-03-01 (v145.0.7632.117) |
| E4 flutter drive CSP hang | HIGH | Testing Infra | ✅ Done — 2026-03-01 (use --profile flag) |
| E5 contact_form_test enterText + placeholder | HIGH | Testing Infra | ✅ Done — 2026-03-01 (directEnterText + 'Doe' not 'Smith') |
| #8-10 OAuth (deferred) | CRITICAL | Security | N/A until OAuth backend |
| #23 KV consistency | HIGH | Reliability | Accepted risk |
| #30 Multi-env CSP | LOW | Infrastructure | Accepted |
| #31 console.log in e2e | WARNING | Code Quality | ✅ Done — 2026-02-27 |
| #32-36 prefer-const (5) | INFO | Code Quality | ✅ False positive — all vars are reassigned (module-scoped circuit breaker state and loop counters) |
| #37 magic numbers in e2e tests | LOW | Code Quality | ✅ Done — 2026-03-01 (constants.ts + landing-page.spec.ts + helpers.ts) |
| #38 magic numbers in worker | LOW | Code Quality | ✅ Done — 2026-02-27 |
| #39 Index-based field selectors | HIGH | Test Quality | ✅ Done — 2026-02-27 (ValueKey added to widget + all test selectors migrated) |
| #40-45 contact_section_test (6) | MEDIUM | Test Quality | ✅ Done — 2026-02-27 |
| #46-50 contact_section_test (5) | LOW | Test Quality | ✅ Done — 2026-02-27 |

---

## Code Quality: Widget Review & Quality Hardening (2026-03-01)

### youtube_player_iframe Integration

**Severity:** LOW
**Category:** Code Quality/Feature
**File:** `lib/widgets/modals/demo_modal.dart:121`
**Status:** Open — identified as TODO during bug-fix session

DemoModal has placeholder video player. TODO comment marks need to integrate `youtube_player_iframe` or similar package for actual video embedding. Deferred pending project requirements for video hosting.

---

### ContactSection._content Heuristic Edge Case ✅ Done

**Severity:** LOW
**Category:** Code Quality/Edge Case
**File:** `lib/widgets/sections/contact_section.dart:39-41`
**Resolved:** 2026-03-01 — Made `content` nullable; null-sentinel pattern replaces fragile `formFields.isEmpty` heuristic (4395245).

---

### E4: `flutter drive -d chrome` hangs indefinitely ✅ Done

**Severity:** HIGH
**Category:** Testing Infrastructure
**Resolved:** 2026-03-01

**Root cause:** `web/index.html` has a strict CSP without `'unsafe-inline'` in `script-src` and without `ws://localhost:*` in `connect-src`. Flutter's DDC debug build injects DWDS (Dart Web Dev Service) which:
1. Executes inline scripts → blocked by CSP
2. Connects via WebSocket to localhost → blocked by CSP

Result: `window.$flutterDriver` is never registered → `waitUntilExtensionInstalled` waits up to 365 days (default timeout).

**Fix:** Add `--profile` flag to all `flutter drive` invocations. Profile mode uses dart2js (not DDC), no DWDS injection, CSP-safe.

```bash
flutter drive \
  --driver=test_driver/integration_test.dart \
  --target=integration_test/e2e/<test>.dart \
  --driver-port=4444 \
  --profile \
  -d chrome
```

Smoke test and full landing_page_test confirmed passing with this fix.

---

### E5: contact_form_test.dart — all 14 tests failing (enterText + placeholder collision) ✅ Done

**Severity:** HIGH
**Category:** Testing Infrastructure
**Resolved:** 2026-03-01

**Root causes (2):**

1. **`tester.enterText()` broken in `IntegrationTestWidgetsFlutterBinding`**: `LiveTestWidgetsFlutterBinding.showKeyboard()` does not call `testTextInput.register()`, leaving `testTextInput._client = null`. In profile mode (dart2js), asserts are disabled so the null dereference produces a TypeError that serializes as an empty string in flutter drive output.

2. **Test data `'Smith'` collides with lastName placeholder `"Smith"`**: Flutter's `InputDecorator` keeps hint text as a `Text` widget at opacity 0 even when the field has a value. `find.text('Smith')` matches both the hint `Text` and the `EditableText`, so `findsOneWidget` fails with 2 matches.

**Fixes:**
- Replaced `tester.enterText()` with `directEnterText()` helper that calls `EditableTextState.updateEditingValue()` directly, bypassing `testTextInput`
- Changed test data from `'Smith'` to `'Doe'` to avoid placeholder collision
- Added `scrollUntilVisible` (from previous session) to reliably reach contact section

All 14 tests now pass consistently. Smoke test also passes.

---

## Code Quality: Flutter Expert Audit — Most Edited Files (2026-03-06)

Findings from flutter-expert code audit of the 7 most frequently edited Dart files in git history.
Cross-referenced against Flutter framework source (widget lifecycle, Semantics, GlobalKey patterns).

### #51: Magic numbers in footer_section.dart

**Severity:** LOW
**Category:** Code Quality
**File:** `lib/widgets/sections/footer_section.dart:96,117,199`

Three inline magic numbers bypass project conventions:
- Line 96: `width: 150` — hardcoded mobile link column width in `_buildMobileLayout`
- Line 117: `maxWidth: 280` — brand column max width in `_buildBrandColumn`
- Line 199: `fontSize: 11` — compliance disclaimer font size bypasses `AppTypography`

**Fix:** Add named constants to `AppSpacing` (or a footer-specific section) and use an `AppTypography` style for the disclaimer.

---

### #52: _linkSections getter re-allocates list on every build ✅ Done

**Severity:** MEDIUM
**Category:** Performance
**File:** `lib/widgets/sections/footer_section.dart`
**Resolved:** 2026-03-06 — Converted top-level getter to `const _linkSections` list. Zero allocations per build.

---

### #53: Mixed hardcoded routes and Routes constants in footer ✅ Done

**Severity:** MEDIUM
**Category:** Consistency
**File:** `lib/widgets/sections/footer_section.dart`
**Resolved:** 2026-03-06 — Replaced `'/features'` → `Routes.features` and `'/support'` → `Routes.support`. All footer links now use Routes constants.

---

### #54: Unused `iconWidget` field on _SocialLink

**Severity:** LOW
**Category:** Dead Code
**File:** `lib/widgets/sections/footer_section.dart:294`

`_SocialLink` declares an `iconWidget` field (line 294) with an assertion requiring either `icon` or `iconWidget`. However, neither of the two usages (lines 126-136) pass `iconWidget` — they always pass `icon`. The field and assertion are dead code.

**Fix:** Remove `iconWidget` field and the assertion. Simplify to require `icon` directly.

---

### #55: _launchUrl missing error handling ✅ Done

**Severity:** HIGH
**Category:** Bug Risk
**File:** `lib/widgets/sections/footer_section.dart:11-15`
**Resolved:** 2026-03-06 — Added try/catch with `ErrorTrackingService.captureException` around `launchUrl` call in `_launchUrl`. Added `analytics.dart` import.

---

### #56: _initializeTracking async error not handled ✅ Done

**Severity:** HIGH
**Category:** Bug Risk
**File:** `lib/app.dart:36-58`
**Resolved:** 2026-03-06 — Wrapped `_initializeTracking` body in try/catch with `ErrorTrackingService.captureException`. `analytics.dart` was already imported.

---

### #57: Stale hardcoded copyright year in CompanyInfo

**Severity:** LOW
**Category:** Stale Data
**File:** `lib/config/content/constants.dart:17`

`CompanyInfo.copyright` is hardcoded as `'© 2025 Integrity Studio. All rights reserved.'`. Meanwhile, `FooterSection._buildBottomBar` dynamically computes `DateTime.now().year`. The constant is stale and inconsistent.

**Fix:** Either remove the constant (it's unused if footer already computes year), or make it a getter:
```dart
static String get copyright =>
    '\u00A9 ${DateTime.now().year} Integrity Studio. All rights reserved.';
```

---

### #58: Routes.euAiAct is an external URL in internal Routes class

**Severity:** LOW
**Category:** Consistency
**File:** `lib/config/content/constants.dart:107`

`Routes.euAiAct` is `'https://integritystudio.ai/docs/tracing#eu-ai-act'` — a full external URL. All other `Routes` members are internal path strings (e.g., `/pricing`, `/docs`). This belongs in `ExternalUrls`.

**Fix:** Move to `ExternalUrls.euAiAct` and update all references (grep for `Routes.euAiAct`).

---

### #59: Duplicate route aliases — Routes.support/contact and Routes.docsApi/api

**Severity:** LOW
**Category:** Consistency
**File:** `lib/config/content/constants.dart:86,108-109,100`

Two pairs of constants resolve to the same path:
- `Routes.support = '/contact'` (line 108) duplicates `Routes.contact = '/contact'` (line 86)
- `Routes.docsApi = '/api'` (line 100) duplicates `Routes.api = '/api'` (line 109)

This creates confusion about which to use and risks divergence if one is updated without the other.

**Fix:** Remove the duplicates. Keep the canonical names (`Routes.contact`, `Routes.api`) and update all references to `Routes.support` and `Routes.docsApi`.

---

### #60: @visibleForTesting as comments instead of annotations ✅ Done

**Severity:** MEDIUM
**Category:** Bug Risk
**File:** `lib/services/contact_service.dart`
**Resolved:** 2026-03-06 — Replaced 4 comment-only `/// @visibleForTesting` with actual `@visibleForTesting` annotations. Imported from `package:flutter/foundation.dart`.

---

### #61: Hardcoded '/signup?tier=Team' in landing_page.dart

**Severity:** LOW
**Category:** Consistency
**File:** `lib/pages/landing_page.dart:117,179`

`'/signup?tier=Team'` appears twice as a hardcoded string. `Routes.signupTeam` already exists in constants (`lib/config/content/constants.dart:88`) with the same value.

**Fix:** Replace both occurrences with `Routes.signupTeam`.

---

### #62: _NavLink and _FooterLink are duplicate hover-link widgets ✅ Done

**Severity:** MEDIUM
**Category:** DRY Violation
**File:** `lib/widgets/common/hover_text_link.dart`
**Resolved:** 2026-03-06 — Extracted shared `HoverTextLink` widget with `defaultColor`, `hoverColor`, `style`, `padding` params. Includes `Semantics` with `onTap`. Replaced `_FooterLink` and `_NavLink` in both files.

---

### #63: _NavLink missing Semantics annotation ✅ Done

**Severity:** HIGH
**Category:** Accessibility
**File:** `lib/pages/landing_page.dart:364-381`
**Resolved:** 2026-03-06 — Wrapped `_NavLink.build` content in `Semantics(button: true, label: widget.text)` to match `_FooterLink` pattern.

---

### #64: Scroll depth analytics fires on every pixel ✅ Done

**Severity:** MEDIUM
**Category:** Performance
**File:** `lib/pages/landing_page.dart`
**Resolved:** 2026-03-06 — Scroll analytics now tracks only 25% milestones (25, 50, 75, 100) with deduplication via `_lastTrackedMilestone`. Eliminates 60+ redundant events/second.

---

### #65: app_router.dart — large flat route list

**Severity:** LOW
**Category:** Maintainability
**File:** `lib/routing/app_router.dart:54-302`

30+ routes in a single flat `routes:` list inside `ShellRoute`. No grouping or organization beyond comments. Adding or finding routes is error-prone.

**Fix:** Extract route groups into helper methods:
```dart
routes: [
  _homeRoute(onShowCookieSettings),
  ..._blogRoutes(),
  ..._docsRoutes(),
  ..._legalRoutes(),
  ..._mainPageRoutes(onShowCookieSettings),
]
```

---

### #66: Repetitive onBack callback in every route

**Severity:** LOW
**Category:** DRY Violation
**File:** `lib/routing/app_router.dart` (throughout)

Nearly every route passes `onBack: () => context.go('/')`. This is repeated 25+ times. If the back behavior changes, every route must be updated.

**Fix:** Define a shared helper or pass it via an `InheritedWidget`. Alternatively, if all pages should go home on back, use `context.go(Routes.home)` inline in page widgets directly and remove the `onBack` parameter.

---

### #67: ContactSection form data duplication on submit ✅ Done

**Severity:** MEDIUM
**Category:** Code Quality
**File:** `lib/widgets/sections/contact_section.dart`
**Resolved:** 2026-03-06 — `_validateForm()` now returns `ContactFormData?` (null on failure). `_handleSubmit` reuses the validated data directly, eliminating duplicate construction and potential validate/submit divergence.

---

### #68: Repetitive onChanged closures in ContactSection._buildField

**Severity:** LOW
**Category:** DRY Violation
**File:** `lib/widgets/sections/contact_section.dart:215-327`

The `_buildField` switch statement has 6 cases (select, textarea, email, phone, url, default text). Each case has a nearly identical `onChanged` closure:
```dart
onChanged: (value) {
  setState(() {
    _formData[field.name] = value;
    _fieldErrors.remove(field.name);
  });
}
```

Duplicated 6 times with the only variation being the select case checking `value != null`.

**Fix:** Extract a shared method:
```dart
void _onFieldChanged(String fieldName, String value) {
  setState(() {
    _formData[fieldName] = value;
    _fieldErrors.remove(fieldName);
  });
}
```
Then use `onChanged: (v) => _onFieldChanged(field.name, v)` in each case.

---

## Updated Priority Matrix (2026-03-06)

| Issue | Severity | Category | Status |
|-------|----------|----------|--------|
| #51 Magic numbers in footer | LOW | Code Quality | Open |
| #52 _linkSections re-allocates every build | MEDIUM | Performance | ✅ Done — 2026-03-06 |
| #53 Mixed hardcoded/constant routes in footer | MEDIUM | Consistency | ✅ Done — 2026-03-06 |
| #54 Unused iconWidget field | LOW | Dead Code | Open |
| #55 _launchUrl missing error handling | HIGH | Bug Risk | ✅ Done — 2026-03-06 |
| #56 _initializeTracking async error unhandled | HIGH | Bug Risk | ✅ Done — 2026-03-06 |
| #57 Stale hardcoded copyright year | LOW | Stale Data | Open |
| #58 Routes.euAiAct is external URL | LOW | Consistency | Open |
| #59 Duplicate route aliases | LOW | Consistency | Open |
| #60 @visibleForTesting as comments | MEDIUM | Bug Risk | ✅ Done — 2026-03-06 |
| #61 Hardcoded signup route in landing page | LOW | Consistency | Open |
| #62 Duplicate hover-link widgets | MEDIUM | DRY Violation | ✅ Done — 2026-03-06 |
| #63 _NavLink missing Semantics | HIGH | Accessibility | ✅ Done — 2026-03-06 |
| #64 Scroll analytics fires every pixel | MEDIUM | Performance | ✅ Done — 2026-03-06 |
| #65 Flat route list in app_router | LOW | Maintainability | Open |
| #66 Repetitive onBack callback | LOW | DRY Violation | Open |
| #67 Form data built twice on submit | MEDIUM | Code Quality | ✅ Done — 2026-03-06 |
| #68 Repetitive onChanged closures | LOW | DRY Violation | Open |

---

*Last updated: 2026-03-06 | Flutter expert audit: 18 issues (#51-#68) across 7 most-edited files — 3 HIGH fixed, 6 MEDIUM fixed, 9 LOW open*
