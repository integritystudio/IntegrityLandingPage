# Changelog — Version 1.1

All notable changes to the IntegrityStudio.ai Flutter project.

---

## [2026-03-14] - Code Quality & Widget Deduplication Sprint

### Widget Extraction & Consolidation

**#91: Extract Button Base, Trust Badge, and Page Shell Primitives**
- Extracted `TrustBadge` to `lib/widgets/common/trust_badge.dart`; added `SubPageShell` to `lib/widgets/navigation/sub_page_shell.dart`
- Migrated `features_page.dart` to `SubPageShell` as working example
- Replaced magic `100` with `AppSpacing.radiusFull` in features_page
- Button primitives skipped — `HoverableButtonMixin` already serves as the base
- Commits: `33ded94`, `91b186d`, `6f9da15`, `09a4b58`

**#153: Consolidation of `_StatCard` and `DocStatCard`**
- Added `backgroundColor`, `borderColor`, and `borderRadius` optional params to `DocStatCard` (defaults preserve existing doc-page visuals)
- `_StatCard` in security_page replaced with `DocStatCard(backgroundColor: gray700, borderColor: gray600, borderRadius: radiusSM)`
- Widget tests added for default and override behavior
- Commit: `0403a5f`

**#154: Add Optional `IconData icon` Parameter to `_AlertBanner`**
- Added optional `icon` parameter to `_AlertBanner` with default `LucideIcons.alertTriangle`
- Enables future use cases without breaking changes
- Commit: `20d52bf`

**#155: Extract Badge Pill Widget from `_HeroSection`**
- Extracted `_HeroBadge` widgets from features_page and status_page
- Eliminates ~20-30 lines of duplicate code (identical structure, different colors/icons)
- Commit: `20d52bf`

**Phase 3a: Extract GradientPillBadge, Consolidate Hero Sections**
- Extracted shared `GradientPillBadge` to `lib/widgets/common/gradient_pill_badge.dart` (optional icon + label, blue-purple gradient pill)
- Replaced `_CareersHeroSection` (careers_page) with `MarketingHeroSection` + `GradientPillBadge`
- Replaced `_ContactHeroSection` (contact_page) with `MarketingHeroSection` + `GradientPillBadge`
- Replaced `_HeroBadge` (features_page) with `GradientPillBadge`
- 3 private classes removed, ~185 lines eliminated, 7 widget tests added
- Commit: `1de0043`

**#156: Replace Hardcoded 'Key Metrics' String in `_MetricsSection`**
- Added `metricsTitle` field to `StatusContent` (default 'Key Metrics')
- Replaced hardcoded string with content-driven constant
- Commit: `20d52bf`

**#157: Replace Raw String `'Operational'` Comparison in `_ServiceRow`**
- `_ServiceRow` now uses `service.isOperational` (computed getter from `status == 'Operational'`)
- Removed stored bool field; defined local constant
- Commits: `1a3c2cc`, `20d52bf`

**#158: Remove Dead Code `_handleNavSelection` from SharedAppBar**
- Removed unreferenced `_handleNavSelection` method after #136 popup menu migration
- Method was fully unused after migration to `PopupMenuButton<int>` with `onTap`-based handlers
- Commit: `3abae95`

### Navigation & Layout Hardening

**#100: Consider Animation Reset Pattern for disableAnimations Toggle**
- Added `_controller.reset()` after `_controller.stop()` in `buttons.dart` and `animated_orb.dart`
- Jump-to-start accepted: completes frame callbacks cleanly, renders 0.0 initial state consistently
- Commit: `6e22745`

**#136: SharedAppBar Nav Item Count Scalability**
- Added `kMaxInlineNavItems = 7` constant to track desktop nav item capacity
- Both mobile and desktop popup menus migrated to `PopupMenuButton<int>` with index keys and `_handleNavItem` per item
- Eliminates value-collision and open-redirect risks
- 5 widget tests added including boundary case at 8 items
- Commit: `691376e`

### E2E Test Coverage & Content Accessibility

**#111: Documentation Page Content Rendering**
- Resolved via Flutter semantics tree: `SemanticsBinding.instance.ensureSemantics()` enables ARIA labels in CanvasKit
- `Semantics` wrappers on 8 doc components expose content to Playwright via `page.getByLabel()`
- E2E spec `docs-content.spec.ts` tests 3 representative pages with graceful skip on Flutter #151929
- Commits: `f99cc8b` + widget test commits

**#114: 404 Error Recovery UI Validation**
- Added 3 tests to `routing.spec.ts` `404 Handling` block:
  1. URL preservation — unknown route not redirected to `/`
  2. Mobile viewport — unknown route renders Flutter at 375×667
  3. HTTP-level — CDN returns 200 + SPA HTML without a browser
- Canvas-level assertions ("404" text, recovery links) remain infeasible due to Flutter canvas rendering
- Sentry error reporting untestable since errorBuilder renders LandingPage without an error event
- Commits: `892aed0`, `cb26c67`

**#117: Mobile Hamburger Menu and Touch Interactions**
- Resolved via #111 Semantics workaround: `Semantics` wrappers on `PopupMenuButton` and `PopupMenuItem`
- Enables ARIA label exposure to Playwright via `page.getByLabel()`
- Tested interactions:
  - Hamburger menu detection via semantics label
  - Hamburger menu open and nav item detection
  - Hamburger menu item navigation (tap Docs, verify URL change)
- Remaining infeasible (Flutter canvas): touch fling scroll, bottom sheet swipe, overlay opacity feedback
- Commits: various navigation refactor commits

### E2E Test Reliability Fixes

**#142: GET from Unauthorized Origin Not Tested on CSRF Endpoint**
- Added test for unauthorized origin GET request
- Commit: `f21e366`

**#143: Rate-Limit 429 Can Mask Validation Failures in Form Tests**
- Updated form validation tests to skip on 429 responses
- Prevents 429 from masking actual validation assertion failures
- Commit: `6249a97`

**#144: CSRF Token Endpoint Content-Type Assertion Unconditional on 503**
- Made content-type assertion conditional on 200 response
- Prevents assertion error on 503 service unavailable
- Commit: `279e477`

**#145: No CSRF Token Round-Trip Test (GET → POST)**
- Deferred — would trigger real email delivery unless mocked. Consider integration test suite.

**#146: "POST response is JSON" Test Missing 429 Guard**
- Added 429 skip guard to prevent HTML body assertion failure on rate-limit responses
- Commit: `5a3831d`

**#147: CSRF Token Format Test Uses Inconsistent Skip Pattern**
- Replaced `test.skip(response.status() !== 200, ...)` with `if (condition) { test.skip(); return; }` pattern
- Ensures execution halts before `response.json()` on non-200 responses
- Commit: `5a3831d`

**#148: Origin Gating Tests Don't Assert Response Body**
- Added error body assertions to unauthorized-origin POST and GET tests
- Strengthens security boundary signal
- Commit: `5a3831d`

**#149: Submission Flow Tests — Post-Await Skip Pattern Inconsistency**
- Updated tests at lines 247 and 263 to use consistent skip pattern
- Guards `response.json()` calls on 403 responses only (429 may return HTML)
- Commit: `49d4ab5`

**#150: Form Validation Tests — Soft Skip Pattern Doesn't Halt**
- Replaced soft skip with conditional halt for all 4 form validation tests
- Pattern now consistent with #147 fix
- Commit: `953ecfa`

**#151: JSDoc Worker URL Comment Hardcoded**
- Updated JSDoc to reference `CONTACT_WORKER_URL` constant instead of hardcoded URL
- Prevents documentation drift on constant updates
- Commit: `95c0310`

**#152: Redundant WORKER_URL Constant Alias**
- Removed `const WORKER_URL = CONTACT_WORKER_URL;` alias
- Use `CONTACT_WORKER_URL` directly
- Commit: `95c0310`

### Code Quality & Testing Improvements (code-reviewer findings)

**L01: Tighten manifest.json assertions in routing.spec.ts**
- Replaced `toBeDefined()` with `toBeTruthy()` on manifest.json `name` and `short_name`
- `toBeDefined()` passes for falsy values (`null`, `false`, `''`); `toBeTruthy()` is more meaningful
- Commit: `809bbdb`

**L02: Add robots.txt Disallow assertion in routing.spec.ts**
- Added `Sitemap` assertion to `robots.txt` test
- Prevents vacuous tests that only check for presence of a header
- Test now validates both `User-agent` and `Sitemap` directives

**L03: Document service worker availability policy in routing.spec.ts**
- Added JSDoc comment explaining why `flutter_service_worker.js` accepts both `[HTTP_OK, HTTP_NOT_FOUND]`
- Documents this is intentional permanent policy (Flutter only generates file for release builds with `--pwa-strategy=offline-first`)
- Commit: `809bbdb`

**L04: Extract blog route constants in routing.spec.ts**
- Extracted `SPA_ROUTE_BLOG` and `SPA_ROUTE_INTERNSHIP` constants to `e2e/tests/constants.ts`
- Updated redirect tests (lines 197–246) to use named constants instead of inline strings
- Improves maintainability and consistency with `spaRoutes` array pattern

**L05: Use static test fixture for blog article assertions in routing.spec.ts**
- Blog article slugs already extracted in prior session (`BLOG_ARTICLE_SLUG`, `BLOG_ARTICLE_NESTED_SLUG`, `BLOG_ARTICLE_FLAT_SLUG`)
- Documented external dependency on deployed articles with JSDoc comment

**M01: Remove duplicate trackFormSubmit method**
- Removed `trackFormSubmit()` method from `analytics.dart:190` that duplicated `trackFormSubmission` with hardcoded `success: true`
- Migrated 2 call sites to `trackFormSubmission(formType:, success: true)`
- Eliminates parameter hiding and improves API clarity
- Commit: `8b6321e`

**M02: Extract magic number for consent update wait time**
- Extracted magic number `500` to named constant `consentWaitForUpdateMs` in `tracking_web.dart:6`
- Aligns with project rule: no magic numbers or strings
- Commit: `8b6321e`

**M03: Gate debugPrint on kDebugMode in consent_manager**
- Wrapped bare `debugPrint('Marketing tracking initialized with consent')` with `if (kDebugMode)` guard
- Matches pattern in other services; prevents debug output in release builds
- Commit: `5226961`

**L09: Remove unused fbPixelId constant**
- Removed unused `const fbPixelId` from `tracking_web.dart:14`
- Pixel is loaded via `web/js/meta-pixel.js`; constant was redundant
- Commit: `8b6321e`

**M05: Remove unnecessary Builder wrapper in careers/contact hero sections**
- Removed `Builder` widget wrapper from `careers_page.dart:53–59` and `contact_page.dart:64–70`
- `BuildContext` is already available from enclosing `build()` method for `ResponsiveUtils.isMobile()` call
- Reduces widget hierarchy depth; matches pattern in `status_page` and `features_page`

**M06: Add retry delay comment for CSRF token flow**
- Added JSDoc comment explaining why CSRF 403 retry branch skips exponential backoff
- Correct optimization (token refresh doesn't require delay), but differs from 500/504 retry logic; comment prevents future confusion
- Commit: `5226961`

**L12: Resolve validData shadowing in contact_service_test**
- Renamed local `const validData` to `const validFormData` in `isFormValid` test (line 214)
- Eliminates shadowing of group-scope `validData` fixture (line 250)
- Improves test clarity if tests are reorganized

**#106: Remove Content Static Facade**
- Removed `Content` facade class (~210 lines of delegation)
- Migrated all 12 consumer files to `ContentLoader.*` directly
- Commit: `be964f2`

**M04: Validate retry-after header and synthetic submissionId**
- Added validation to reject zero/negative retry-after values (header + body)
- Prefixed synthetic fallback submissionId with `local_` to distinguish from server-issued IDs
- Added 3 edge-case tests for retry-after validation
- Commits: `747b40a`, `e0e71b7`

**M08: Apply safe-cast pattern to _fetchCsrfToken GET response**
- Added `is! Map<String, dynamic>` guard before unsafe cast
- Returns `null` gracefully instead of throwing `TypeError` on non-map responses (e.g., HTML error pages)
- Commit: `1ca1d0b`

**L06: Report analytics initialization exceptions to Sentry**
- Added `await ErrorTrackingService.captureException()` to `AnalyticsService.initialize()` and `FacebookPixelService.initialize()`
- Ensures initialization exceptions are captured and reported to error tracking
- Commits: `fd558ca`, `177a115`

**L07: Reset _loadCompleter in ContentLoader.loadFromString**
- Added `_loadCompleter = null` after loading from string in test helper
- Prevents stale completers from blocking subsequent `load()` calls in tests that chain `loadFromString` without explicit `reset()`
- Commit: `f40f119`

**L10: GradientPillBadge icon color parameterization**
- Added optional `iconColor` parameter (defaults to `AppColors.blue400` to match label text)
- Features page explicitly passes `AppColors.success` for checkCircle icon
- Added test coverage for custom color parameter
- Commit: `d6f9142`

**L11: Add page-level tests for contact_page and features_page heroes**
- Added 37 smoke tests: 20 for contact page, 17 for features page
- Coverage: hero badge/headline/subheadline, quick contact cards, support info, footer, responsive layout, back button
- Fixed case-sensitive assertion bug in `contact_service_test.dart:960` (`'Gateway Timeout'` vs `'timeout'`)
- Extracted hero magic strings to `ContactContentVariants` constants
- Widened `PagePumpFunction` to accept `onShowCookieSettings` (removed adapter wrappers)
- Commit: `2bccbb6`

---

## [2026-03-15] - Phase 3b Completion & Code Quality Fixes

### Widget Consolidation

**Phase 3b: Consolidate StatCard / StatBadge Variants**
- Consolidated `_TimelineCard` (eu_ai_act_page) and `_StatBadge` (docs_tracing_page) into `DocStatCard` via new `valueStyle` and `constraints` params
- `about_page::_StatCard` and `social_proof_section::_StatCard` not consolidated (structurally too different)
- Commit: `f10c523`

### Code Quality Fixes

**L13: Use findsNWidgets in page hero assertions**
- Replaced `findsWidgets` with `findsNWidgets(2)` in contact_page_test (both texts appear in desktop+mobile responsive variants)
- careers_page_test.dart:104 already uses `findsOneWidget`
- Commit: `8faa05b`

**L14: Dead hover color branch in _QuickContactCard**
- Removed dead ternary `_isHovered ? AppColors.gray800 : AppColors.gray800` — both branches identical
- Using `AppColors.gray800` directly
- Commit: `48f8853`

**L15: Update buildBadge helper to accept iconColor parameter**
- Added `iconColor` param to `buildBadge` helper in gradient_pill_badge_test
- Updated test to use helper consistently
- Commit: `b74863d`

**L08: Closed — @visibleForTesting on _dio field**
- Invalid: `_dio` is private; `@visibleForTesting` only applies to public members. Test-only access already gated via public `setDioForTesting()`.

---
