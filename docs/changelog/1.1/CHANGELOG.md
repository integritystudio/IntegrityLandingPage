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

---
