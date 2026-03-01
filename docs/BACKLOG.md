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

### E3: chromedriver not installed

**Severity:** LOW
**Category:** Testing Infrastructure
**Source:** `TEST_GAPS.md`

`flutter drive -d chrome` fails because chromedriver is not installed. Fix: `brew install chromedriver` (local) or add to CI pipeline.

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
| E3 chromedriver not installed | LOW | Testing Infra | Open — `brew install chromedriver` |
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

*Last updated: 2026-03-01 | Fixed 8 widget bugs (8f31e0b) + 4 OTEL quality issues + ContactSection heuristic (4395245) + #37 e2e magic numbers (00b36c3)*
