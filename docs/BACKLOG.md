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

*Last updated: 2026-03-01 | Fixed 8 widget bugs (8f31e0b) + 4 OTEL quality issues + ContactSection heuristic (4395245) + #37 e2e magic numbers (00b36c3) + E4 flutter drive CSP hang (profile mode fix) + E5 contact_form_test enterText + placeholder fix*
