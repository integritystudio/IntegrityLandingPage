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

### #54: Unused `iconWidget` field on _SocialLink

**Severity:** LOW
**Category:** Dead Code
**File:** `lib/widgets/sections/footer_section.dart:294`

`_SocialLink` declares an `iconWidget` field (line 294) with an assertion requiring either `icon` or `iconWidget`. However, neither of the two usages (lines 126-136) pass `iconWidget` — they always pass `icon`. The field and assertion are dead code.

**Fix:** Remove `iconWidget` field and the assertion. Simplify to require `icon` directly.

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

### #61: Hardcoded '/signup?tier=Team' in landing_page.dart

**Severity:** LOW
**Category:** Consistency
**File:** `lib/pages/landing_page.dart:117,179`

`'/signup?tier=Team'` appears twice as a hardcoded string. `Routes.signupTeam` already exists in constants (`lib/config/content/constants.dart:88`) with the same value.

**Fix:** Replace both occurrences with `Routes.signupTeam`.

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

## Code Review Findings: Changelog & Test Quality (2026-03-06)

Findings from code-reviewer audit of commit 65495a5. HIGH/MEDIUM items fixed same session.

### #69: HoverTextLink test — no coverage for Semantics label when onTap is null ✅ Done

**Severity:** LOW
**Category:** Test Coverage
**File:** `test/widgets/common/hover_text_link_test.dart`
**Resolved:** 2026-03-06 — Added `'has Semantics label even without onTap'` test verifying label and button role when onTap is null.

---

### #70: HoverTextLink test — custom style does not verify fontSize preservation ✅ Done

**Severity:** LOW
**Category:** Test Coverage
**File:** `test/widgets/common/hover_text_link_test.dart`
**Resolved:** 2026-03-06 — Added `fontSize` assertion to `'applies custom style preserving all properties'` test.

---

### #71: Changelog version history table missing 2026-02-13 and 2026-02-27 entries

**Severity:** LOW
**Category:** Documentation
**File:** `docs/changelog/1.0/CHANGELOG.md` (Version History table)

The version history table at the bottom of the changelog jumps from 1.9 (2026-02-01) to 2.0 (2026-03-06). Missing entries for 2026-02-13 (security hardening, added as 1.10 this session) and 2026-02-27 sessions that resolved #31, #37-50. The 2026-02-27 work has a prose section but no version row.

**Fix:** Add a row for the 2026-02-27 session:
```
| 2026-02-27 | 1.11 | ast-grep findings, contact_section_test quality hardening |
```
Reorder version numbers to maintain descending chronological order.

---

### #72: Changelog #62 entry claims "−22 lines net" without distinguishing source vs test

**Severity:** LOW
**Category:** Documentation Accuracy
**File:** `docs/changelog/1.0/CHANGELOG.md`

The #62 entry says "removed dead code (−22 lines net)" but this net figure excludes the 201-line test file added in the same commit. The claim is technically about widget source code only but the phrasing is ambiguous. Could mislead someone reviewing the commit's actual `--stat` output (346 insertions, 282 deletions).

**Fix:** Clarify: "removed dead code (−22 lines net in widget source)" or remove the line count claim entirely.

---

## Open Issues Priority Matrix (2026-03-06)

| Issue | Severity | Category |
|-------|----------|----------|
| #51 Magic numbers in footer | LOW | Code Quality |
| #54 Unused iconWidget field | LOW | Dead Code |
| #57 Stale hardcoded copyright year | LOW | Stale Data |
| #58 Routes.euAiAct is external URL | LOW | Consistency |
| #59 Duplicate route aliases | LOW | Consistency |
| #61 Hardcoded signup route in landing page | LOW | Consistency |
| #65 Flat route list in app_router | LOW | Maintainability |
| #66 Repetitive onBack callback | LOW | DRY Violation |
| #68 Repetitive onChanged closures | LOW | DRY Violation |
| #71 Changelog version history table gaps | LOW | Documentation |
| #72 Changelog #62 line count ambiguous | LOW | Documentation |
| #73 Footer test: pure-unit constants test has limited value | LOW | Test Quality |
| #74 Footer test: mobile bottom bar labels not covered | LOW | Test Coverage |

---

### #73: Footer test — pure-unit constants test has limited value

**Severity:** LOW
**Category:** Test Quality
**File:** `test/widgets/sections/footer_section_test.dart`

The `'test constants match expected counts'` test asserts `hasLength` on file-scope constants. These are compile-time tautologies — the constants are defined in the same file. The test documents expected shape but does not verify the widget. Consider replacing with widget-driven assertions or removing entirely since the regression test already validates rendered labels.

---

### #74: Footer test — mobile bottom bar labels not covered

**Severity:** LOW
**Category:** Test Coverage
**File:** `test/widgets/sections/footer_section_test.dart`

Desktop legal labels (`Privacy Policy`, `Terms of Service`, etc.) are tested, but the mobile bottom bar renders abbreviated labels (`Privacy`, `Terms`, `Cookies`). No test currently validates these mobile-specific labels. The `_legalLabels` constant only covers desktop. A mobile-specific test or a separate `_mobileLegalLabels` constant would close this gap.

---

*Last updated: 2026-03-06*
*Migrated items: 9 (3 HIGH, 6 MEDIUM) → docs/changelog/1.0/CHANGELOG.md*
*Remaining open: 13 LOW severity issues (#69, #70 fixed earlier; #73, #74 added this session)*
