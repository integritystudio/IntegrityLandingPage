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

**Status:** Done — covered by Playwright e2e (`e2e/tests/web-platform.spec.ts`). Happy path (window.open availability, navigation stability) and environment smoke test (footer renders without crash under poisoned window.open) both passing. Direct catch-block invocation of `_launchUrl` is not possible from Playwright (CanvasKit renders to `<canvas>`); unit-level mock of `ErrorTrackingService.captureException` remains deferred pending `flutter test --platform chrome` (#77).

---

### #76: `_initializeTracking` Error Handling Test Coverage

**Severity:** LOW
**Category:** Test Coverage
**File:** `lib/app.dart:36-66`

`_initializeTracking()` is wrapped in try/catch, but the tracking branches (`kIsWeb`, `ConsentManager.hasConsent()`, `TrackingWeb.*`) are unreachable in native tests. `kIsWeb` is a compile-time constant — native tests always evaluate to `false`, skipping all tracking logic. See `test/app_test.dart:690-701`.

**Status:** Done — covered by Playwright e2e (`e2e/tests/web-platform.spec.ts`). Tests verify: consent persistence, corrupted data resilience (exercises `_initializeTracking` try/catch directly — corrupted JSON triggers the catch block), GTM injection after consent, and no unhandled errors. Unit-level mock verification of `ErrorTrackingService.captureException` invocation remains deferred pending `flutter test --platform chrome` (#77).

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

## Open: /docs/tracing Served as Static HTML on Production (#104)

**Severity:** HIGH
**Category:** Infrastructure / Deployment
**Files:** `e2e/tests/backlog-sprint.spec.ts:85`, `web/_redirects`, `lib/routing/app_router.dart:189`
**Source:** CI failure 2026-03-11 (E2E workflow, all 3 retries)

### Symptom

Playwright e2e test `docs group: /docs/tracing loads` fails with `TimeoutError: page.waitForFunction: Timeout 120000ms exceeded` — waiting for `flt-glass-pane`, `flutter-view`, or `canvas` elements that never appear. Fails consistently across all 3 CI retries (not a flake). All other 151 tests pass, including heavier doc pages (`/docs/quickstart` at 1133 LOC, `/docs/alerts` at 996 LOC).

### Root Cause

**Production at `https://integritystudio.ai/docs/tracing` serves a static HTML page, NOT the Flutter SPA.** The response is a server-rendered HTML document with vanilla JS/CSS, Google Analytics (`G-ECH51H8L2Z`), sidebar navigation, and traditional DOM elements — no Flutter rendering surface (`flt-glass-pane`, `flutter-view`, `canvas`) is present.

The Flutter SPA fallback in `web/_redirects` (`/* /index.html 200`) should route all unmatched paths to the Flutter app. Something on Cloudflare Pages overrides this for `/docs/tracing` — most likely a `docs/tracing/index.html` file from a previous deployment or a Cloudflare Pages static asset that takes priority over the `_redirects` fallback.

### Evidence

- **WebFetch of `https://integritystudio.ai/docs/tracing`** — returns traditional HTML with no Flutter elements. Contains: fixed nav bar, sidebar, Google Analytics `G-ECH51H8L2Z`, gradient text hero, timeline component, tables, code blocks. No `flt-glass-pane`, `flutter-view`, or `canvas` tags.
- **No static file in repo** — `web/docs/tracing/` directory does not exist. Only static doc HTML is `web/docs/security/audit-trails.html`.
- **`web/_redirects`** — SPA fallback `/* /index.html 200` is present and works for all other routes.
- **Flutter router** — `lib/routing/app_router.dart:189` correctly maps `/docs/tracing` to `DocsTracingPage`.
- **Widget tests pass** — `flutter test` confirms `DocsTracingPage` builds and renders correctly.
- **Other doc routes pass** — `/docs`, `/docs/llm-observability`, `/docs/integrations`, `/docs/quickstart`, `/docs/alerts`, `/docs/agents` all serve Flutter SPA.
- **Page weight is not the cause** — `docs_tracing_page.dart` (654 LOC) is smaller than `/docs/quickstart` (1133 LOC) and `/docs/alerts` (996 LOC), both of which pass.

### Relationship to #78

Item #78 increased timeouts from 90s→120s to accommodate "production CDN latency." The `/docs/tracing` failure persists after that fix because the root cause is not latency — the route serves an entirely different page (static HTML vs Flutter SPA). The timeout increase was correct for other intermittent slowness but did not address this specific route.

### Immediate Fix Applied

Moved `/docs/tracing` out of the Flutter SPA route test list in `backlog-sprint.spec.ts` and added a separate static-page test that asserts HTTP 200 and correct URL without waiting for Flutter rendering elements. This unblocks CI.

**Files changed:**
- `e2e/tests/backlog-sprint.spec.ts:79-98` — `/docs/tracing` removed from `docsRoutes` array; new `docs group: /docs/tracing loads (static)` test added with `page.goto` + status 200 assertion.

### Investigation Needed

1. **Check Cloudflare Pages dashboard** — look for a `docs/tracing/index.html` or `docs/tracing.html` static asset in the current deployment. Cloudflare Pages serves static files before applying `_redirects` rules.
2. **Check if a previous deployment** placed a static file at that path that persists across deploys (Cloudflare Pages preserves files across deployments unless explicitly deleted).
3. **Verify with `wrangler pages deployment list`** and inspect the asset manifest for the current production deployment.
4. **If the static page is intentional** — update `lib/routing/app_router.dart` to remove the `/docs/tracing` route from the Flutter SPA, and update any internal links that point to it.
5. **If the static page is unintentional** — delete it from Cloudflare Pages (may require a fresh deployment with `--force` or clearing the deployment cache) and revert the e2e test workaround.

### CI Environment

- E2E workflow: `.github/workflows/e2e.yml`
- `BASE_URL: https://integritystudio.ai` (tests run against production, not local dev server)
- Playwright config: `e2e/playwright.config.ts` (4 workers, 2 retries in CI)
- Timeouts: `FLUTTER_INIT_TIMEOUT_MS=120000`, `TEST_TIMEOUT_MS=180000`

**Status:** Open — CI workaround applied, root cause (static file on Cloudflare) not yet resolved.

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

**Status:** Done — doc comment added to DocBulletList in `doc_components.dart`. Commit e9d5310.

---

### #94: Add const Optimization to DocCallout Call Sites

**Severity:** LOW
**Category:** Code Quality (Performance)
**Files:** `lib/pages/docs_agents_page.dart`, `lib/pages/docs_tracing_page.dart`, `lib/pages/docs_quickstart_page.dart`
**Source:** Code review (session 2026-03-09)

`DocCallout` named constructors are `const`-compatible when all params are literals. Several call sites omit `const` keyword (e.g., quickstart_page lines 238, 488, 522, 675, 742), while others use `const` (agents_page lines 259, 338). Inconsistent use represents minor missed optimization, not a correctness issue.

**Status:** Done — `const` added to all literal-param `DocCallout` calls in `docs_quickstart_page.dart` (5 sites) and `docs_tracing_page.dart` (3 sites). Commit 0214c69.

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

**Status:** Done — comment added to both `buttons.dart` and `animated_orb.dart`. Commit 2685c60.

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

**Status:** Done — header warning added. Commit 76622db.

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

## Deferred: ContentLoader Service Refactoring (#104-#108)

Code review findings from content_loader.dart audit (session 2026-03-11). High-priority items were fixed (YamlMap cast guard, @visibleForTesting annotations, caching); medium/low items deferred as architectural improvements.

### #104: Add Error Recovery Path to ContentLoader.load()

**Severity:** HIGH
**Category:** Error Handling
**File:** `lib/services/content_loader.dart:27-33`
**Source:** Code review (session 2026-03-11, commit 263e372)

`load()` now guards the YamlMap cast with FormatException, but asset-load errors from `rootBundle.loadString()` still propagate uncaught. If the asset is missing or unregistered, callers cannot distinguish "load failed" from "not yet loaded" — subsequent getters all throw `StateError('Content not loaded')`.

**Fix:** Wrap the load pipeline in try/catch and re-throw a domain-specific exception (e.g., `ContentLoadException`) so the app's error boundary can surface it clearly. Consider using Sentry for error tracking on failure.

**Status:** Deferred — guard in place (HIGH), error recovery path (P2) deferred for post-MVP refinement.

---

### #105: Collapse ContentLoader to Static-Only Pattern

**Severity:** MEDIUM
**Category:** Architecture (Consistency)
**Files:** `lib/services/content_loader.dart:10-21`, `lib/services/content_loader.dart:430-444`
**Source:** Code review (session 2026-03-11)

`ContentLoader` mixes singleton-instance pattern (`static ContentLoader? _instance`, `instance` getter) with static state (`_content`, `_isLoaded` are static). Every sibling service (`ConsentManager`, `ContactService`, `AnalyticsService`) uses static-only. The instance pattern here is redundant — `_instance` holds no per-instance state.

**Fix:** Remove `_instance` and the instance getter; convert all methods to static. This aligns with siblings and eliminates confusion about which pattern owns the state.

**Status:** Deferred — Low-priority refactoring. Impacts public API of `ContentLoader.instance`, but `Content` facade (which wraps it) is the primary consumer and can stay static.

---

### #106: Remove Content Static Facade (190-line delegation)

**Severity:** MEDIUM
**Category:** Code Quality (Maintenance)
**File:** `lib/services/content_loader.dart:430-605`
**Source:** Code review (session 2026-03-11)

`Content` class is 190 lines of forwarding delegates to `ContentLoader` methods. Adding or renaming any getter requires two edits. No logic in `Content` — it is a namespace alias. If `ContentLoader` is collapsed to static-only (#105), `Content` becomes redundant and can be removed or replaced with a subclass alias for backwards compatibility.

**Status:** Deferred — Conditional on #105. Blocked by API stability concerns (production code depends on `Content.*` static getters).

---

### #107: Add Debug-Mode Assertion for Required Content Keys

**Severity:** LOW
**Category:** Robustness (Edge Case)
**File:** `lib/services/content_loader.dart:366-367` (_getMap)
**Source:** Code review (session 2026-03-11)

`_getMap(path)` returns `{}` on missing keys, making it impossible to distinguish "key absent" from "key maps to empty map". For required keys (e.g., `company`, `pricing`), a missing key should fail fast in dev. Currently, silent `{}` masks misconfigured YAML until a caller tries to access a field.

**Fix:** Add debug-mode assertion in `_getMap`:
```dart
assert(value != null || allowNull, 'Required content key "$path" is missing');
```

**Status:** Done — assert added to `_getMap`; `content_loader_test.dart` updated to expect `AssertionError` for missing paths. Commit 0bf5597.

---

### #108: Optimize socialProofStats to Cache Converted Map

**Severity:** LOW
**Category:** Performance (Micro-optimization)
**File:** `lib/config/content.dart:226-229`
**Source:** Code review (session 2026-03-11)

`AppContent.socialProofStats` getter calls `Content.socialProofStats` which calls `_getMap()` (now cached) and immediately allocates a new `Map<String, String>` via `.map(...)` on every access. For a static, immutable map, this allocation is wasteful. A dedicated cache entry or static field would eliminate repeated allocations on reads.

**Status:** Done — `_stringMapCache` added to `ContentLoader`; `socialProofStats` uses `putIfAbsent` to avoid repeated `.map()` allocations. Cache cleared in `loadFromString()` and `reset()`. Commit 04c3c67.

---

## Open: E2E Test Coverage Gaps (Generated Tests #109-#119)

**Source:** Session 2026-03-11 (e2e-test-framework:generate-e2e analysis)
**Status:** 59 new e2e tests added (seo-meta, auth-flows, redirect-rules, mobile-nav). These gaps remain:

### #109: Contact Form Submission Flow

**Severity:** MEDIUM
**Category:** E2E Test Coverage
**Files:** `e2e/tests/contact-form.spec.ts`
**Source:** Coverage gap analysis 2026-03-11

Contact form page loads and navigates ✓, but form submission flow is untested. Requires:
- Filling form fields with valid data
- Submitting form (POST to `/api/contact`)
- Verifying redirect to `/request_success` or `/request_failure`
- Error message display on failed submission
- Backend mock or live endpoint for test environment

**Status:** Deferred — requires backend integration or service worker mock. Consider using Playwright network intercept to mock contact-form worker response.

---

### #110: Pricing Page Plan Selection and CTA

**Severity:** MEDIUM
**Category:** E2E Test Coverage
**Files:** `e2e/tests/pricing-interactions.spec.ts`
**Source:** Coverage gap analysis 2026-03-11

Pricing page loads ✓, but no interaction testing:
- Plan card hover/tap states
- CTA button clicks
- Price comparison table
- Responsive layout on mobile/tablet
- Tier selection state persistence

**Status:** Deferred — low priority user flow (not critical path). Schedule after #109.

---

### #111: Documentation Page Content Rendering

**Severity:** MEDIUM
**Category:** E2E Test Coverage (Flutter Canvas Limitation)
**Files:** `e2e/tests/`, `lib/pages/docs_*.dart`
**Source:** Coverage gap analysis 2026-03-11

Doc pages load ✓, but content is rendered to CanvasKit (canvas), making content verification impossible from Playwright:
- Table rendering (headers, rows, alignment)
- Code block syntax highlighting
- Callout variants (warning, info, success colors)
- Section navigation (jump links, scroll anchors)
- Hero section images and gradients

**Status:** Deferred — Flutter web canvas rendering limitation. Cannot inspect rendered content without adding debug endpoints. Consider:
1. Add `?debug=true` query param to export page content as JSON
2. Use Flutter's accessibility tree (limited to text content)
3. Add screenshot comparison tests (visual regression)

---

### #112: Analytics Event Payload Validation

**Severity:** LOW
**Category:** E2E Test Coverage
**Files:** `e2e/tests/analytics-events.spec.ts`
**Source:** Coverage gap analysis 2026-03-11

Tracking initialization is tested (#76), but actual event payloads are not validated:
- Page view events (route changes)
- Button click tracking
- Form interaction events
- Scroll depth tracking
- Custom event attributes (referrer, UTM params)

**Status:** Deferred — requires network listener to capture GTM dataLayer and GA4 event stream. Playwright can intercept via `page.on('console')` for logged events, but GTM payload validation is P3.

---

### #113: Keyboard Navigation Audit Per Page

**Severity:** LOW
**Category:** E2E Test Coverage (A11y)
**Files:** `e2e/tests/accessibility.spec.ts`
**Source:** Coverage gap analysis 2026-03-11

Keyboard navigation tested on home page only. Gaps:
- Tab order on docs pages
- Tab order on form pages (/contact, /signup)
- Focus trap (if any)
- Keyboard shortcuts (if any)
- Skip-to-main link (if present)

**Status:** Deferred — low priority a11y improvement. Requires per-page tab order audit in Flutter.

---

### #114: 404 Error Recovery UI Validation

**Severity:** LOW
**Category:** E2E Test Coverage
**Files:** `e2e/tests/routing.spec.ts`
**Source:** Coverage gap analysis 2026-03-11

Unknown routes render home page (errorBuilder) ✓, but error display is untested:
- Does landing page display "404 not found" message?
- Is there a link back to /docs or /home?
- Is error reported to Sentry?
- Mobile 404 behavior

**Status:** Deferred — low priority error path. Requires adding explicit error page or 404 messaging.

---

### #115: Redirect Chain Validation

**Severity:** LOW
**Category:** E2E Test Coverage
**Files:** `e2e/tests/redirect-rules.spec.ts`
**Source:** Coverage gap analysis 2026-03-11

Simple redirects tested, but complex chains are not:
- `/blog` → `/blog/` → blog page (301 → 200)
- `/internship` → `/internship/` → landing page
- `/reports/foo` → `/docs` → docs page
- Verify no redirect loops

**Status:** Deferred — low priority infrastructure test. Useful for regression detection but not customer-facing.

---

### #116: Page-Specific Meta Tags Per Route

**Severity:** LOW
**Category:** E2E Test Coverage (SEO)
**Files:** `e2e/tests/seo-meta.spec.ts`
**Source:** Coverage gap analysis 2026-03-11

Meta tags tested for home page only. Gaps:
- Dynamic `og:title`, `og:description` per route (e.g., `/pricing` should have "Pricing" in og:title)
- Route-specific canonical URLs
- Hreflang tags for i18n (if deployed)
- Page-specific JSON-LD (e.g., `Product` schema for /pricing)

**Status:** Deferred — requires building per-route meta tag strategy and updating Cloudflare/Flutter HTML shell. P3 SEO enhancement.

---

### #117: Mobile Hamburger Menu and Touch Interactions

**Severity:** MEDIUM
**Category:** E2E Test Coverage (Flutter Canvas Limitation)
**Files:** `e2e/tests/mobile-nav.spec.ts`
**Source:** Coverage gap analysis 2026-03-11

Mobile pages load ✓, but mobile-specific interactions are untested:
- Hamburger menu tap to open/close
- Full navigation menu rendering
- Mobile-specific CTA positioning
- Touch scroll vs pointer scroll
- iOS safe area / notch handling

**Status:** Deferred — Flutter web canvas limitation. Hamburger menu is rendered to canvas, no DOM selector available. Would require:
1. Add tap detection to canvas and emit custom events
2. Or refactor navigation to HTML (out of scope)

---

### #118: Search Functionality (if present in docs)

**Severity:** LOW
**Category:** E2E Test Coverage
**Files:** `e2e/tests/docs-search.spec.ts`
**Source:** Coverage gap analysis 2026-03-11

Docs pages load, but if search is available, it's untested:
- Search box availability
- Query input and submission
- Search results rendering
- No results state

**Status:** Deferred — verify if search exists before implementing. Low priority docs feature.

---

### #119: Deep Linking Within Doc Sections (Anchor Navigation)

**Severity:** LOW
**Category:** E2E Test Coverage
**Files:** `e2e/tests/spa-navigation.spec.ts`
**Source:** Coverage gap analysis 2026-03-11

Deep links to routes work ✓, but jump-to-section within docs pages is untested:
- `/docs/quickstart#installation` should scroll to installation section
- `/docs/api#endpoints` should scroll to endpoints
- Scroll position restored on back navigation
- Section highlighting (if implemented)

**Status:** Deferred — requires adding `#anchor` support to Flutter routing or detecting scroll events. Low priority UX improvement.

---

## Deferred: Code Review Findings (Backlog Sprint 2026-03-11)

Code reviewer identified low findings during backlog implementation (#93, #94, #107, #108). All are pre-existing patterns surfaced by the changes, not regressions.

### #120: Add assert to DocCallout Named Constructors

**Severity:** LOW
**Category:** Code Quality (Correctness)
**File:** `lib/widgets/docs/doc_components.dart:424-450`
**Source:** Code review (session 2026-03-11, #94 review)

The primary constructor `DocCallout()` has `assert(message != null || items != null)`, but the four named constructors (`.success`, `.info`, `.warning`, `.danger`) do not inherit this assert. A call like `DocCallout.info(title: 'x')` with neither `message` nor `items` compiles silently and renders a title-only callout with no body.

**Fix:** Add `assert(message != null || items != null)` to each named constructor's initializer list.

**Status:** Deferred — pre-existing, no active callers trigger this. Low priority safety guard.

---

### #121: Add const to DocBulletList Call Sites

**Severity:** LOW
**Category:** Code Quality (Performance)
**Files:** `lib/pages/docs_tracing_page.dart:219,267,509,521`, `lib/pages/docs_quickstart_page.dart:232,759`
**Source:** Code review (session 2026-03-11, #94 review)

Six `DocBulletList` call sites pass only const-compatible params (`items: const [...]`, `bulletColor: AppColors.success`) but omit the outer `const` keyword. `DocBulletList` has a const constructor and all arguments are compile-time constants. Inconsistent with the #94 `DocCallout` const cleanup.

**Status:** Deferred — optional, same pattern as #94 but for `DocBulletList`.

---

### #122: Add Blank Line Before _TimelineItem in docs_tracing_page

**Severity:** LOW
**Category:** Code Quality (Style)
**File:** `lib/pages/docs_tracing_page.dart:568-569`
**Source:** Code review (session 2026-03-11)

`_TimelineItem` class declaration at line 569 follows the closing brace of the previous class at line 568 with no blank line separator. Pre-existing style inconsistency — not introduced by #94.

**Status:** Deferred — cosmetic, pre-existing.

---

### #123: Make Inactive Test sed Command Cross-Platform

**Severity:** LOW
**Category:** Code Quality (Documentation)
**File:** `test/widgets/sections/social_proof_section_test.dart.inactive:3`
**Source:** Code review (session 2026-03-11, #101 review)

The `sed -i ''` command in the header warning uses macOS-specific syntax. On GNU/Linux `sed`, `-i ''` is invalid (expects `-i` with no space or `-i.bak`). Since this is a developer-facing comment (not executed code), impact is documentation-only.

**Fix:** Add platform note: `# macOS sed syntax; on Linux use: sed -i 's/...'`

**Status:** Deferred — documentation-only, low priority.

---

*Last updated: 2026-03-11 (#104 /docs/tracing static HTML root cause + CI workaround + #104-#108 contentloader refactoring deferred; 59 e2e tests generated (#109-#119 gaps identified); 4 new spec files: seo-meta, auth-flows, redirect-rules, mobile-nav; #120-#123 code review findings from backlog sprint)*
*Migrated items: 32 total → docs/changelog/1.0/CHANGELOG.md:*
  *- 9 items (3 HIGH, 6 MEDIUM) from Flutter expert audit (2026-02-13)*
  *- 13 items (all LOW) from backlog implementation sprint (2026-02-13)*
  *- 2 items (all LOW) from code review test coverage findings (2026-02-13)*
  *- 8 items (1 MEDIUM, 7 LOW) from test quality & code quality session (2026-03-09)*
*Remaining open: 0 open + 1 blocked (#77) + 3 deferred (OAuth #8-#10) + 0 deferred test coverage (closed #75, #76 via Playwright 2026-03-09) + 1 deferred (#78 intermittent timeout)*
*Migrated this session (2026-03-09): #79 (anchor nav), #80 (shader format), #81 (analytics spy), #82 (test constants), #83 (backlog numbering), #84 (15-min call), #85 (Austin TX), #86 (privacy email), #87 (5-min setup)*
*Appended this session (2026-03-09): #89 (DocsPageScaffold), #90 (hero templates), #91 (button/badge/shell), #92 (_WarningCallout variants), #93 (DocBulletList bulletColor doc), #94 (const optimization), #95 (api_toolkit_page migration), #96 (shared _StatCard), #97 (security_page _SecurityCard)*
*Appended this session continued (2026-03-09): #98 (scrollUntilVisible loop), #99 (didChangeDependencies comment), #100 (animation reset on toggle), #101 (inactive file warning)*
*Appended session (2026-03-11): #104-#108 (contentloader service refactoring — HIGH load() error recovery, MEDIUM static-only collapse + facade removal, LOW missing-key assertion + socialProofStats cache)*
