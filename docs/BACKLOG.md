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

## Done: Widget Duplication Consolidation (#88)

**Severity:** MEDIUM
**Category:** Code Quality (DRY)
**Analysis:** [docs/duplicate-findings.md](duplicate-findings.md)

294 widgets scanned; 358 duplicate pairs found at >=70% Jaccard similarity. Primary source: docs pages re-declare private widgets (`_SimpleTable`, `_CodeBlock`, `_BulletList`, `_DocSection`, `_FeatureCard`, `_InfoCallout`/`_WarningCallout`/`_SuccessCallout`) that already exist as shared components in `lib/widgets/docs/doc_components.dart`. 27 pairs are 100% byte-identical.

**Phases:**
1. Replace private docs widgets with shared `doc_components.dart` equivalents (~200 pairs eliminated)
2. Extract `DocsPageScaffold` for 7 docs pages (~21 pairs)
3. Extract shared hero/page templates (~30 pairs)
4. Low-priority: button base, trust badge, page shells (~10 pairs)

**Status:** Done — Phase 1 complete. Replaced private docs widgets with shared `doc_components.dart` equivalents across all 5 target pages (agents, tracing, api, alerts, quickstart). ~200 duplicate pairs eliminated. Commits: 3aae289 (doc_components enhancements), a51ccfb, 088d9a0, c1e167f, 969e8e1, 41bd76c. Phases 2-4 deferred.

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

**Status:** Done — increased `FLUTTER_INIT_TIMEOUT_MS` from 90s to 120s and global test timeout from 120s to 180s to accommodate production CDN latency. Commit 13f5a05.

---

## Deferred: Widget Refactoring Phases 2-4 (#88 Follow-up)

Phases 2-4 of #88 Widget Duplication Consolidation were deferred after Phase 1 completed. These represent the next refactoring targets to reach 100% duplication elimination.

### #89: Extract DocsPageScaffold for Docs Pages

**Severity:** MEDIUM
**Category:** Code Quality (DRY)
**Files:** `lib/pages/docs_*.dart` (7 pages: agents, alerts, api, interop, observability, quickstart, tracing)
**Source:** Session 2026-03-09 (#88 Phase 2 deferred)

All 7 docs pages share similar page structure: hero section, navigation, content area, footer. Extracting `DocsPageScaffold(title, description, child, accentColor)` would eliminate ~21 duplicate pairs. Requires parameterizing hero color and content area height.

**Status:** Deferred — Phase 1 consolidation complete. Schedule Phase 2 after other medium-priority items.

---

### #90: Extract Shared Page Hero and Template Components

**Severity:** MEDIUM
**Category:** Code Quality (Architecture)
**Files:** `lib/pages/`, `lib/widgets/docs/`
**Source:** Session 2026-03-09 (#88 Phase 3 deferred)

Hero sections, feature grids, and step templates repeat across multiple pages. Creating `PageHeroSection(title, icon, description, color)` and consolidating grid/step layouts would eliminate ~30 duplicate pairs. Requires careful parameterization of conditional content (e.g., cards vs steps vs metrics).

**Status:** Deferred — Phase 1 consolidation complete.

---

### #91: Extract Button Base, Trust Badge, and Page Shell Primitives

**Severity:** LOW
**Category:** Code Quality (Consolidation)
**Files:** `lib/pages/`, `lib/widgets/`
**Source:** Session 2026-03-09 (#88 Phase 4 deferred)

Low-priority consolidation of button base styles, trust badge variants, and page shell patterns. ~10 duplicate pairs. Lower ROI than phases 2-3.

**Status:** Deferred — Low priority, schedule after critical items.

---

## Deferred: Code Review Findings (#88 Implementation)

Code reviewer identified medium and low findings during #88 Phase 1 consolidation. These are deferred architectural improvements, not correctness issues.

### #92: Consolidate _WarningCallout and _WarningAlert Variants

**Severity:** MEDIUM
**Category:** Code Quality (Consistency)
**Files:** `lib/pages/docs_api_page.dart:744` (_WarningCallout), `lib/pages/docs_quickstart_page.dart:1101` (_WarningAlert)
**Source:** Code review (session 2026-03-09)

Three visually distinct warning callout styles exist post-#88:
1. `DocCallout.warning` — column layout with left border, requires title
2. `_WarningCallout` (api_page) — row layout with left border, no title param
3. `_WarningAlert` (quickstart_page) — full border layout with warning color

The api_page and quickstart_page variants cannot be directly replaced with `DocCallout.warning` because they use different layouts (Row vs Column, full border vs left border). Decision: keep as-is per reviewer PASS, but this is a missed consolidation opportunity and creates visual/API inconsistency.

**Status:** Deferred — Pre-existing architectural inconsistency, lower priority than Phase 2 extraction.

---

### #93: Document DocBulletList bulletColor Behavior When checked=true

**Severity:** LOW
**Category:** Code Quality (Documentation)
**File:** `lib/widgets/docs/doc_components.dart` (DocBulletList class)
**Source:** Code review (session 2026-03-09)

The `DocBulletList` class silently ignores `bulletColor` param when `checked: true` is set. Current doc comment (`/// Set [checked] to true to show checkmark icons instead of bullet characters.`) is correct but doesn't warn callers that `bulletColor` is ignored. No active callers currently pass both params, but this is a potential footgun.

**Status:** Deferred — Add doc comment clarification: `/// When [checked] is true, [bulletColor] is ignored and success color is used instead.`

---

### #94: Add const Optimization to DocCallout Call Sites

**Severity:** LOW
**Category:** Code Quality (Performance)
**Files:** `lib/pages/docs_agents_page.dart`, `lib/pages/docs_tracing_page.dart`, `lib/pages/docs_quickstart_page.dart`
**Source:** Code review (session 2026-03-09)

`DocCallout` named constructors are `const`-compatible when all params are literals. Several call sites omit `const` keyword (e.g., quickstart_page lines 238, 488, 522, 675, 742), while others use `const` (agents_page lines 259, 338). Inconsistent use represents minor missed optimization, not a correctness issue.

**Status:** Deferred — Optional cleanup. Add `const` to all literal-param `DocCallout` calls when polishing docs pages.

---

## Open: High-Similarity Widget Duplication (>90%)

Detected by `scripts/find_duplication.sh` on 2026-03-09. Only pairs >90% Jaccard similarity listed. DocsPage scaffolding pairs (93%) already tracked by #89; _WarningAlert/_DangerAlert pairs (92-100%) already tracked by #92.

### #95: Migrate api_toolkit_page Private Widgets to Shared doc_components

**Severity:** MEDIUM
**Category:** Code Quality (DRY)
**Files:** `lib/pages/api_toolkit_page.dart`, `lib/widgets/docs/doc_components.dart`
**Source:** Duplication scan 2026-03-09

`api_toolkit_page.dart` was not included in #88 Phase 1 and still declares private widgets that are near-identical to shared `doc_components.dart` equivalents:

| Private Widget | Shared Equivalent | Similarity |
|---------------|-------------------|------------|
| `_StatCard` (lines 207-247) | `DocStatCard` (doc_components) | 97% vs docs_api_page, docs_observability_page |
| `_DocSection` (lines 817-869) | `DocSection` (doc_components:6-66) | 82% (also 91% vs security_page `_SecurityCard`) |
| `_CodeBlock` (lines 871-913) | `DocCodeBlock` (doc_components:130-172) | 92% |
| `_SimpleTable` (lines 915-970) | `DocTable` (doc_components:176-240) | 80% |

**Status:** Done — all 5 private widgets (`_StatCard`, `_DocSection`, `_CodeBlock`, `_SimpleTable`, `_BulletList`) replaced with shared `doc_components.dart` equivalents. Uncommitted.

---

### #96: Extract Shared _StatCard Widget Across 3 Pages

**Severity:** MEDIUM
**Category:** Code Quality (DRY)
**Files:** `lib/pages/api_toolkit_page.dart:207-247`, `lib/pages/docs_api_page.dart:159-199`, `lib/pages/docs_observability_page.dart:159-199`
**Source:** Duplication scan 2026-03-09

Three pages declare nearly identical `_StatCard` widgets (97% Jaccard similarity). Extracted `DocStatCard` to `lib/widgets/docs/doc_components.dart` with optional `accentColor` parameter and replaced all three private declarations.

Additional lower-similarity matches: `eu_ai_act_page::_TimelineCard` (85%), `security_page::_StatCard` (81-84%) — not yet migrated.

**Status:** Done — `DocStatCard` extracted to `doc_components.dart`, private `_StatCard` removed from all 3 pages. Uncommitted.

---

### #97: security_page _SecurityCard Duplicates DocSection (91%)

**Severity:** LOW
**Category:** Code Quality (DRY)
**Files:** `lib/pages/security_page.dart:446-498`, `lib/widgets/docs/doc_components.dart:6-66`
**Source:** Duplication scan 2026-03-09

`security_page::_SecurityCard` is 91% similar to `api_toolkit_page::_DocSection` and 85% similar to shared `DocSection`. `security_page` was not included in #88 Phase 1. Candidate for replacement with `DocSection` after verifying visual parity.

**Status:** Done — replaced with shared `DocSection` from `doc_components.dart`. All 11 call sites updated. Commit c16f227.

---

## Open: Test Timeout Prevention (Animation & Settle Fixes)

**Category:** Test Infrastructure (Widget Tests)
**Source:** Session 2026-03-09 (code review: test timeouts & animation hang prevention)

### #98: Fix scrollUntilVisible() Unbounded pumpAndSettle Loop

**Severity:** HIGH
**Category:** Test Infrastructure (Correctness)
**File:** `test/helpers/test_helpers.dart:87-98`
**Source:** Code review session 2026-03-09, fix #2

`scrollUntilVisible()` calls `pumpAndSettle()` inside a loop (up to 50 iterations). If the target widget is never found, the test silently passes after 50 × 5s timeout = 250s. When the page contains repeating animations, each `pumpAndSettle()` hangs indefinitely (separate issue now gated by #98 replacement).

**Fix:** Replace `await pumpAndSettle()` with `await pump(const Duration(milliseconds: 100))` (lines 95), and add assertion after loop: `expect(finder.evaluate().isNotEmpty, true, reason: 'Element not found after $maxScrolls scrolls')` to prevent silent failures.

**Status:** Done — replaced `pumpAndSettleWithTimeout()` with `pump(const Duration(milliseconds: 100))` and added post-loop assertion. Commit a8fe6f6.

---

### #99: Add Clarifying Comment to didChangeDependencies Re-entry Guard

**Severity:** LOW
**Category:** Code Quality (Documentation)
**Files:**
- `lib/widgets/common/buttons.dart:237-241`
- `lib/widgets/decorative/animated_orb.dart:74-81`
**Source:** Code review session 2026-03-09

The `else if (!_controller.isAnimating)` guard in both `didChangeDependencies` methods prevents re-entrant `repeat()` calls on dependency changes. Purpose is non-obvious; a brief comment prevents future misreading as dead code.

**Suggested comment:**
```dart
// Guard against re-entrant calls on subsequent dependency changes
// (e.g., theme or MediaQuery updates after initial mount).
} else if (!_controller.isAnimating) {
```

**Status:** Deferred — low priority polish.

---

### #100: Consider Animation Reset Pattern for disableAnimations Toggle

**Severity:** LOW
**Category:** Code Quality (Edge Case)
**Files:**
- `lib/widgets/common/buttons.dart:237-241`
- `lib/widgets/decorative/animated_orb.dart:74-81`
**Source:** Code review session 2026-03-09

If user toggles `disableAnimations` from `true→false` at runtime (rare but possible via system accessibility settings), `didChangeDependencies` resumes animation from the stopped position, not from 0. This causes a visible jump/snap in the animation. A `_controller.reset()` before `repeat()` would fix, at the cost of a jump-to-start visual discontinuity. This is a product design decision and low-priority.

**Status:** Deferred — edge case, lower priority. Requires decision on whether jump-to-start is acceptable.

---

### #101: Add Header Warning to Inactive Test File

**Severity:** LOW
**Category:** Test Infrastructure (Documentation)
**File:** `test/widgets/sections/social_proof_section_test.dart.inactive`
**Source:** Code review session 2026-03-09

The `.inactive` file contains ~50 bare `pumpAndSettle()` calls not converted to `pumpAndSettleWithTimeout()` (commit d61fbea). If the file is ever reactivated without updating these calls, tests will timeout.

**Fix:** Add header comment:
```dart
/// WARNING: This file contains 50+ pumpAndSettle() calls not yet converted to
/// pumpAndSettleWithTimeout(). Before reactivating this test file, run:
/// sed -i '' 's/pumpAndSettle()/pumpAndSettleWithTimeout()/g' social_proof_section_test.dart.inactive
```

**Status:** Deferred — optional documentation. Low-priority safety note.

---

## Open: Test Coverage Gaps (#95/#96 Implementation)

**Category:** Test Coverage
**Source:** Session 2026-03-09 (#95/#96 widget consolidation)

### #102: Add Unit Tests for DocStatCard Widget

**Severity:** MEDIUM
**Category:** Test Coverage
**File:** `lib/widgets/docs/doc_components.dart` (`DocStatCard` class)
**Source:** Session 2026-03-09 (#96 implementation)

`DocStatCard` was extracted as a new shared widget in `doc_components.dart` but has no unit test coverage in `test/widgets/docs/doc_components_test.dart`. Tests should verify:
- Renders `value` and `label` text
- Default `accentColor` falls back to `AppColors.blue400`
- Custom `accentColor` applies to value text
- `const` constructor works with all-literal params

**Status:** Done — 4 tests added to `doc_components_test.dart` covering value/label render, default/custom accentColor, and const constructor. Commit 9420f48.

---

### #103: Add Page-Level Test for api_toolkit_page

**Severity:** LOW
**Category:** Test Coverage
**File:** `lib/pages/api_toolkit_page.dart`
**Source:** Session 2026-03-09 (#95 implementation)

`api_toolkit_page.dart` has no corresponding test file (`test/pages/api_toolkit_page_test.dart` does not exist). Other docs pages (`docs_api_page`, `docs_observability_page`) have page-level tests. After #95 migration, the page now uses shared `DocStatCard`, `DocSection`, `DocCodeBlock`, `DocTable`, and `DocBulletList` — a smoke test confirming the page renders without errors would catch integration issues.

**Status:** Done — `test/pages/api_toolkit_page_test.dart` created with 10 tests: page structure, title, navigation callbacks, and responsive layout. Also parameterized `testBackButtonCallbacks()` in test_helpers.dart. Commit b53dd07.

---

*Last updated: 2026-03-09 (widget duplication analysis + backlog migration + animation/test timeout fixes + #95/#96 done + test gaps #102/#103)*
*Migrated items: 32 total → docs/changelog/1.0/CHANGELOG.md:*
  *- 9 items (3 HIGH, 6 MEDIUM) from Flutter expert audit (2026-02-13)*
  *- 13 items (all LOW) from backlog implementation sprint (2026-02-13)*
  *- 2 items (all LOW) from code review test coverage findings (2026-02-13)*
  *- 8 items (1 MEDIUM, 7 LOW) from test quality & code quality session (2026-03-09)*
*Remaining open: 0 open + 1 blocked (#77) + 5 deferred (OAuth #8-#10, test coverage #75-#76) + 1 deferred (#78 intermittent timeout)*
*Migrated this session (2026-03-09): #79 (anchor nav), #80 (shader format), #81 (analytics spy), #82 (test constants), #83 (backlog numbering), #84 (15-min call), #85 (Austin TX), #86 (privacy email), #87 (5-min setup)*
*Appended this session (2026-03-09): #89 (DocsPageScaffold), #90 (hero templates), #91 (button/badge/shell), #92 (_WarningCallout variants), #93 (DocBulletList bulletColor doc), #94 (const optimization), #95 (api_toolkit_page migration), #96 (shared _StatCard), #97 (security_page _SecurityCard)*
*Appended this session continued (2026-03-09): #98 (scrollUntilVisible loop), #99 (didChangeDependencies comment), #100 (animation reset on toggle), #101 (inactive file warning)*
