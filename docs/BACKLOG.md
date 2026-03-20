# Backlog

Open and deferred items only. Completed items are migrated to `docs/changelog/1.0/CHANGELOG.md` and `docs/changelog/1.1/CHANGELOG.md`.

---

## Deferred: OAuth Security (#8-#10)

These issues are **deferred** because this is a landing page with placeholder OAuth callback UI and no OAuth backend.
When OAuth is implemented, these MUST be added.

| Issue | Severity | Description |
|-------|----------|-------------|
| #8 OAuth State Validation | CRITICAL | CSRF via unvalidated `state` parameter |
| #9 PKCE Implementation | CRITICAL | Authorization code interception (RFC 7636) |

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

Sentry `ingest.sentry.io` endpoint shared across staging and prod. CSP allows only one DSN per environment. Report DSN collision ignored when worker's `ENVIRONMENT` env var is not set (CF free plan limit).

**Status:** Accepted for landing page use case. Documented in `web/_headers`. If env-specific reporting is needed, use a build script to replace the DSN.

---

## Deferred: Chrome Platform Tests (#77)

### #77: `flutter test --platform chrome` Hangs Indefinitely

**Severity:** CRITICAL
**Category:** Test Infrastructure (Platform-Level)
**File:** N/A — Flutter SDK issue
**Source:** Session 2026-02-12, validated 2026-02-25

`flutter test --platform chrome` (CanvasKit + headless Chrome) hangs on **exit** after all tests pass. Affects CI pipelines: test suite completes, Chrome stays alive, process never exits until CI timeout.

**Upstream:** [Flutter #162798](https://github.com/flutter/flutter/issues/162798) — OPEN, marked for next stable release.

**Workaround:** N/A effective. Blocking factor.

**Status:** Blocked — `flutter test --platform chrome` hangs indefinitely (upstream Flutter issue #162798). Next stable v3.44 planned May 2026 with fix.

---

## Deferred: E2E Test Coverage Limitations (Flutter Canvas)

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

**Status:** Deferred — Flutter SPA serves the same index.html for all routes; per-route meta requires Cloudflare Workers or edge-side rendering to inject dynamic tags. P3 SEO enhancement.

---


## Feature: Resume Upload on Careers Contact Form (#132)

### #132: Add File Upload to /contact?ref=careers

**Priority**: P2 | **Source**: session 2026-03-11

Add a file upload button (resume PDF/DOCX) to the contact form when `ref=careers`. Recommended architecture:

```
Browser (file_picker) → multipart POST → CF Worker → R2 bucket → Resend (path: r2_url)
```

This keeps CPU usage minimal and avoids the Cloudflare Workers free plan 10ms CPU limit. For a typical resume PDF (100KB–2MB), direct base64 encoding in the Worker might also work but is less reliable on the free tier.

**Key constraints:**
- `file_picker` package recommended for Flutter web file selection
- Resend supports attachments via `attachments[].path` (public URL) or `attachments[].content` (base64)
- Resend limit: 40MB per email (~30MB raw after base64 overhead)
- CF Workers free plan: 10ms CPU limit — base64 encoding large files can exceed this
- R2 approach avoids CPU-bound encoding; Resend fetches from the R2 URL server-side
- Blocked file types (Resend): `.exe`, `.bat`, `.js`, `.ps1`, etc. PDFs/DOCX are fine

**Implementation steps:**
1. Add `file_picker` dependency, show upload widget on `/contact?ref=careers`
2. Create R2 bucket for resume uploads
3. Update CF Worker to accept multipart POST, write file to R2, pass R2 URL to Resend
4. Add file type/size validation (client + server)

**Status:** Deferred — requires R2 bucket provisioning and Worker update.

---

### #133: Revert Careers CTA to "Submit Your Resume" After File Upload

**Priority**: P3 | **Source**: session 2026-03-11

Once #132 (resume upload) is implemented, revert the careers page CTA and copy:
- Button text: "Keep in Touch" → "Submit Your Resume"
- Description: restore "Send us your resume and a brief introduction..." (add "resume" back)

**Status:** Blocked on #132.

---

## Deferred: Server-Side Security Headers

These issues require **server-side HTTP response header configuration** and cannot be fixed in the Flutter app.

---

### S01: Add `frame-ancestors` CSP Header for Clickjacking Protection

**Priority:** P1 | **Source:** session 2026-03-20, code-reviewer (commit ec1fc78)

**Status:** Blocked on server configuration

The `frame-ancestors` directive controls who can embed this site in an iframe (clickjacking defense). The directive is currently missing from **both** the HTTP response headers and the `<meta>` CSP tag. CSP directives in `<meta>` tags are silently ignored for `frame-ancestors` — it **must** be delivered via HTTP response header.

**Required:**
- Add `frame-ancestors 'self';` to the server's CSP HTTP response header (production domain only)
- Remove from `<meta>` tag (already removed in ec1fc78)
- This requires Cloudflare Workers (`_headers` file) or similar edge configuration, not Flutter app changes

**File:** Server configuration (e.g., `web/_headers` or Cloudflare Workers config)

**Reason deferred:** Requires server-side deployment; cannot be fixed in Flutter app.

---

## Open Items

### M07: Add retry count assertion to 500 retry test

**Priority:** P2 | **Source:** session 2026-03-14, code-reviewer (commit 2fce62a)

`contact_service_test.dart:377–390` — Test named `'handles 500 internal server error with retries'` only asserts the final error message; it does not verify that the retry loop actually ran `_maxRetries` times. `_MockDio` lacks a `postCallCount` field. Add counter to `_MockDio` and assert `postCallCount == 3` (1 initial + 2 retries).

**File:** `test/services/contact_service_test.dart:377–390`

**Status:** Done — `f921d20` (2026-03-17). Added `postCallCount` to `_MockDio`, asserted `== 3`. Extended in `44a2450` to cover 504, connectionTimeout, receiveTimeout retry paths.

---

## Code Quality: UI Widget Duplication Investigation

### #134: Investigate and Consolidate Duplicated Page Scaffold Pattern

**Priority:** P2 | **Source:** `scripts/find_duplication.sh` run 2026-03-17 (54 similar pairs found)

8 page widgets share a near-identical scaffold/build pattern (78% similar): `AboutPage`, `CareersPage`, `FeaturesPage`, `PricingPage`, `RequestFailurePage`, `RequestSuccessPage`, `StatusPage`, `ContactPage`. Extract a shared base page scaffold widget or mixin to eliminate boilerplate.

**Files:** `lib/pages/{about,careers,features,pricing,request_failure,request_success,status,contact}_page.dart`
**Impl doc:** `docs/duplication/134-page-scaffold.md`
**Status:** Done — `bafeb87` (2026-03-17). Moved analytics into `SubPageShell`, refactored 7 pages. -155 lines, 2444 tests pass.

---

### #135: Investigate and Consolidate Duplicated Button Widget Constructors

**Priority:** P2 | **Source:** `scripts/find_duplication.sh` run 2026-03-17

4 button widgets in `buttons.dart` have 75–85% similar constructors: `AnimatedGradientBorderButton`, `GradientButton`, `OutlineButton`, `AppTextButton`. Evaluate extracting shared parameter handling or a common base class.

**Files:** `lib/widgets/common/buttons.dart`
**Impl doc:** `docs/duplication/135-button-constructors.md`
**Status:** Done — `f28cc6c` (2026-03-17). Extracted `BaseActionButton` abstract class, 3 buttons use super.* params. AppTextButton excluded (different fields). 21 new tests, 2492 pass.

---

### #136: Investigate and Consolidate Duplicated Info Card Patterns

**Priority:** P3 | **Source:** `scripts/find_duplication.sh` run 2026-03-17

Multiple card-style widgets share Container+decoration+Column layout (70–78% similar): `_MethodologyCard` (sources), `_TechSection` (status), `_FeatureItem` (features), `_ChannelCard` / `_AlertTypeCard` (docs_alerts), `_HealthMetricCard` (docs_quickstart), `DocFeatureCard` (doc_components), `_ResourceLink` (compliance). Evaluate a shared `InfoCard` or `ContentCard` widget.

**Files:** `lib/pages/{sources,status,features,docs_alerts,docs_quickstart,compliance}_page.dart`, `lib/widgets/docs/doc_components.dart`
**Impl doc:** `docs/duplication/136-info-card-pattern.md`
**Status:** Done — `e8da224` (2026-03-20). Extended InfoCard with iconSpacing, iconContainerPadding, iconContainerBorderRadius, onTap, trailingWidget. Refactored _MethodologyCard and _ResourceLink to use InfoCard. -86 lines, 2565 tests pass.

---

### #137: Investigate and Consolidate Duplicated Chip/Badge Patterns

**Priority:** P3 | **Source:** `scripts/find_duplication.sh` run 2026-03-17

Badge and chip widgets share similar Container+Row+decoration layout (71–75% similar): `_HeroBadge` (status), `_AlertTypePreview` (docs_alerts), `_HealthComponentChip` (status), `_DifferentiatorCard` (comparison), `_StatusChip` (status), `TrustBadge` / `_TrustIndicator` (hero_section). Evaluate a shared badge/chip base widget.

**Files:** `lib/pages/{status,docs_alerts,comparison}_page.dart`, `lib/widgets/common/trust_badge.dart`, `lib/widgets/sections/hero_section.dart`
**Impl doc:** `docs/duplication/137-chip-badge-pattern.md`
**Status:** Done — `3c24e23` (2026-03-17). Extracted `ChipBadge`, replaced 4 widgets (_HeroBadge, _StatusChip, _HealthComponentChip, _AlertTypePreview). TrustBadge/TrustIndicator/DifferentiatorCard excluded (too different). -91 lines, 2471 tests pass.

---

### #138: Investigate Timeline vs DocNumberedList Duplication

**Priority:** P3 | **Source:** `scripts/find_duplication.sh` run 2026-03-17

`_Timeline` (docs_tracing_page) and `DocNumberedList` (doc_components) are 71% similar — both render ordered vertical lists with numbered indicators. Evaluate whether `_Timeline` can be refactored to use `DocNumberedList` or a shared base.

**Files:** `lib/pages/docs_tracing_page.dart`, `lib/widgets/docs/doc_components.dart`
**Impl doc:** `docs/duplication/138-timeline-numbered-list.md`
**Status:** Done — `0d30da6` (2026-03-17). Extracted `VerticalIndicatorList`, refactored both widgets. -20 lines, 2456 tests pass.

---

### T01: Enhance Mock ProvisioningDio for Multiple Different Per-Attempt Responses

**Priority:** P4 | **Source:** session 2026-03-20, code-reviewer (commit 5c35e10)

`test/services/provisioning_service_test.dart` — Current `MockProvisioningDio` supports per-attempt error injection via `_postErrorAttempts` and `_getErrorAttempts` maps, but success responses are stored in a single global `_mockGetResponseData` / `_mockPostResponseData` map. If a future test needs different response data on different retry attempts (e.g., attempt 1 returns 500, attempt 2 returns 200+data), the mock cannot represent this without significant refactoring.

**Current behavior:** Per-attempt responses fall back to the same global response data.
**Limitation:** Not blocking; no current tests need this. Enhancement for future test complexity.

**File:** `test/services/provisioning_service_test.dart:395–415`

**Status:** Done — `5367b9e` (2026-03-20). Added _postResponseAttempts/_getResponseAttempts maps; fixed mockGetResponse per-attempt storage; standardized counter pattern. 3 new tests, 2568 pass.

---

## API Provisioning Integration

### M08: Add CORS Headers and OPTIONS Handling to Sender Worker

**Priority:** P2 | **Source:** session 2026-03-20, api-provisioning.md review

`workers/sender-worker/src/index.ts` — Sender Worker `/send` endpoint does not set `Access-Control-Allow-Origin` headers or handle OPTIONS preflight requests. Browser-based Flutter Web deployments will fail with CORS rejection errors.

**Required:**
- Add `corsHeaders` with allowed origin(s) (staging, production, local dev)
- Handle OPTIONS method with 204 No Content + CORS headers
- Apply CORS headers to all POST responses
- Suggested origins: `https://staging.example.com`, `https://www.example.com`, `http://localhost:8081` (dev)

**Files:** `workers/sender-worker/src/index.ts`, `workers/sender-worker/src/index.test.ts` (add OPTIONS preflight test)

**Status:** Done — `e0b9858` (2026-03-20). Added `getCorsHeaders` reusing `ALLOWED_ORIGINS` from `workers/constants.ts`. Non-browser requests (no Origin) pass through; disallowed origins return 403; OPTIONS returns 204. 4 new tests, 16 total passing.

---

### M09: Remove Redundant `onBack` Getter in ProvisionPage

**Priority:** P2 | **Source:** session 2026-03-20, code-reviewer (commit 84fb4f2)

`lib/pages/provision_page.dart:188` — The getter `VoidCallback? get onBack => widget.onBack;` creates an unnecessary indirection. In `auth_page.dart`, `widget.onBack` is accessed directly everywhere. Remove the getter and replace `build()` references (lines 84-89) with direct `widget.onBack` calls to match the pattern in auth_page.

**File:** `lib/pages/provision_page.dart:84-89, 188`

**Status:** Done — `171c1fb` (2026-03-20). Removed getter, replaced with direct `widget.onBack` access.

---

### M10: Extract Duplicated Spacing Ternaries in AuthPage

**Priority:** P2 | **Source:** session 2026-03-20, code-reviewer (commit 84fb4f2)

`lib/pages/auth_page.dart:165-167, 187-189, 202-204` — The pattern `SizedBox(height: _mode == AuthMode.signUp ? AppSpacing.lg : AppSpacing.md)` appears three times inline. Extract to a single `final fieldSpacing` variable at the top of `build()` to reduce allocations and improve readability.

**File:** `lib/pages/auth_page.dart`

**Status:** Done — `9deac24` (2026-03-20). Extracted `spacingAfterSubtitle` and `spacingBetweenFields` locals in `build()`.

---

### M11: Reset `_isLoading` on Auth Success Path

**Priority:** P2 | **Source:** session 2026-03-20, code-reviewer (commit 84fb4f2)

`lib/pages/auth_page.dart:99-121` — In `_submit()`, on the success branch (`AuthSuccess`), the code calls `context.go(Routes.provision, extra: response)` and returns without setting `_isLoading = false`. If navigation fails, the button remains permanently disabled. Move `_isLoading = false` inside a `try/finally` or explicitly on the success branch before navigating.

**File:** `lib/pages/auth_page.dart:99-121`

**Status:** Done — `f72fb4a` (2026-03-20). Added `setState(() => _isLoading = false)` on success branch before `context.go()`.

---

### M12: Map Server Error Strings to User-Friendly Messages

**Priority:** P2 | **Source:** session 2026-03-20, code-reviewer (commit 84fb4f2)

`lib/pages/auth_page.dart:233` and `lib/pages/provision_page.dart:233` — Raw server error strings are surfaced directly in `Alert.error` via `_errorMessage` set from `response.error`. If the backend returns a verbose technical string (stack trace, internal path, etc.), it exposes implementation details to users. Add a mapping layer between service errors and user-friendly messages.

**File:** `lib/pages/{auth,provision}_page.dart`

**Status:** Done — `6bc66ea` (2026-03-20). Added `_sanitizeError()` in both pages; passes through short single-line messages, falls back to generic for verbose/stack-trace errors.

---

### M13: Lowercase and Trim Email for `userId` in ProvisioningEvent

**Priority:** P3 | **Source:** session 2026-03-20, code-reviewer (commit 84fb4f2)

`lib/pages/provision_page.dart:47-51` — `userId` is set to raw `widget.auth.email` without normalization. This conflates PII with the user ID concept and allows case-variation duplicates (e.g., `user@example.com` and `User@Example.Com` create two accounts). Lowercase and trim: `widget.auth.email.toLowerCase().trim()`.

**File:** `lib/pages/provision_page.dart:47`

**Status:** Done — `2876b46` (2026-03-20). Added `.toLowerCase().trim()` on `widget.auth.email` when setting `userId`.

---

### M14: Add Copy Button for API Key Display

**Priority:** P3 | **Source:** session 2026-03-20, code-reviewer (commit 84fb4f2)

`lib/pages/provision_page.dart:155-165` — API key is displayed in `SelectableText` with no copy-to-clipboard affordance. For security-sensitive values, add a dedicated `IconButton` with `Clipboard.setData()` and visual confirmation (e.g., toast or button state change).

**File:** `lib/pages/provision_page.dart`

**Status:** Done — `bc59b8b`, `7ffbeb0` (2026-03-20). Replaced `SelectableText` with `CopyableCodeField` widget with built-in copy-to-clipboard button.

---

### M15: Add Maximum Password Length Validation

**Priority:** P3 | **Source:** session 2026-03-20, code-reviewer (commit 84fb4f2)

`lib/pages/auth_page.dart:77` — `_isPasswordValid` enforces `length >= 8` but no upper bound. Extremely long passwords (e.g., 10,000 chars) would pass client validation and trigger a DoS on the auth endpoint if the server doesn't limit. Add `_password.length <= 128` (or server limit) check.

**File:** `lib/pages/auth_page.dart:77`

**Status:** Done — `9581ce8`, `39e54fa` (2026-03-20). Added `_minPasswordLength = 8` and `_maxPasswordLength = 128` constants; `_isPasswordValid` now enforces both bounds.

---

### M16: Move Analytics Tracking to `didChangeDependencies`

**Priority:** P3 | **Source:** session 2026-03-20, code-reviewer (commit 84fb4f2)

`lib/pages/auth_page.dart:50-52` — `AnalyticsService.trackPageView` is called in `initState`, which runs before the first frame is rendered. If route transitions are async (GoRouter with redirect guards), the page may be torn down before being displayed, skewing analytics. Move to `didChangeDependencies` (first call only) or defer via `WidgetsBinding.instance.addPostFrameCallback`.

**File:** `lib/pages/auth_page.dart:50-52`

**Status:** Done — `a5767c4` (2026-03-20). Added `_pageViewTracked` flag; analytics call moved to `didChangeDependencies` (first call only).

---

### L19: Add Comment About `_email` Preservation on Mode Toggle

**Priority:** P4 | **Source:** session 2026-03-20, code-reviewer (commit 84fb4f2)

`lib/pages/auth_page.dart:93-98` — When a user switches from sign-up to sign-in, `_password`, `_confirmPassword`, and visibility booleans are reset, but `_email` is preserved. This is likely intentional UX, but it's undocumented asymmetry. Add a brief comment explaining the decision to prevent future developers from treating it as an accidental omission.

**File:** `lib/pages/auth_page.dart`

**Status:** Done — `a5767c4` (2026-03-20). Added inline comment in `_toggleMode()` explaining intentional `_email` preservation.

---

### L20: Fix Alert Double-Spacing Issue

**Priority:** P4 | **Source:** session 2026-03-20, code-reviewer (commit 84fb4f2)

`lib/widgets/alert.dart:157` and usage in `lib/pages/{auth,provision}_page.dart` — `Alert` has hardcoded `margin: EdgeInsets.only(bottom: AppSpacing.lg)`. Both pages add `SizedBox(height: AppSpacing.md)` after `Alert.error`, resulting in `AppSpacing.lg + AppSpacing.md` total gap. Review whether `Alert` should have no intrinsic margin (callers own spacing) or whether the post-alert `SizedBox` should be removed.

**File:** `lib/widgets/alert.dart`, `lib/pages/{auth,provision}_page.dart`

**Status:** Done — `a5767c4` (2026-03-20). Removed redundant `SizedBox(height: AppSpacing.md)` after `Alert.error` in auth_page and provision_page; Alert's own `AppSpacing.lg` bottom margin provides sufficient spacing.

---

### M17: Pipe sanitizeServerError Through sanitizeUserInput

**Priority:** P3 | **Source:** session 2026-03-20, code-reviewer (commit 9f826b2)

`lib/utils/security_utils.dart` — `sanitizeServerError` passes short, single-line strings directly without HTML-escaping. A payload like `<img src=x onerror=...>` (27 chars, no newlines) passes through verbatim. Pipe through `sanitizeUserInput` before returning for consistency with the rest of `SecurityUtils`.

**File:** `lib/utils/security_utils.dart`

**Status:** Done — `4554f81` (2026-03-20). Piped through `sanitizeUserInput`; HTML special chars now escaped before display.

---

### L21: Move Password Length Constants to Shared Constants

**Priority:** P4 | **Source:** session 2026-03-20, code-reviewer (commit 9f826b2)

`lib/pages/auth_page.dart:88-89` — `_minPasswordLength = 8` and `_maxPasswordLength = 128` declared in `_AuthPageState`. Password constraints are cross-cutting policy; move to shared constants so server-side and UI stay in sync.

**File:** `lib/pages/auth_page.dart`, shared constants file

**Status:** Done — `e8ab121` (2026-03-20). Extracted `PasswordPolicy` class to `constants.dart`; placeholder interpolates from `PasswordPolicy.minLength`/`maxLength`.

---

### L22: Narrow `sanitizeServerError` Stack-Trace Heuristic

**Priority:** P4 | **Source:** session 2026-03-20, code-reviewer (commit d7b597e)

`lib/utils/security_utils.dart` — The `' at '` substring check in `sanitizeServerError` is too broad; legitimate messages like `"Failed at validation step"` are replaced by the generic fallback. Narrow to match stack-trace patterns (e.g., `' at '` followed by path/digit, or check for `.js:` / `.dart:`).

**File:** `lib/utils/security_utils.dart`

**Status:** Done — `4554f81` (2026-03-20). Replaced `' at '` substring check with `_stackTracePattern` regex; natural language like "Failed at validation step" no longer triggers the generic fallback.

---

### L23: Update Password Placeholder to Reflect Max Length

**Priority:** P4 | **Source:** session 2026-03-20, code-reviewer (commit d7b597e)

`lib/pages/auth_page.dart` — Placeholder text `'Minimum 8 characters'` does not reflect the 128-char ceiling added in M15.

**File:** `lib/pages/auth_page.dart`

**Status:** Done — (2026-03-20). Updated placeholder to `'8–128 characters'`.

---

## Code Review Findings (Last 4 Commits: 00d7127, 94d26d0, e623040, e89fd7d)

**Date:** 2026-03-20 | **Reviewer:** code-reviewer agent

### R01: Add Clarifying Comment for `sanitizeServerError` Multi-Line Guard

**Priority:** P3 | **Severity:** Medium | **Source:** code-reviewer (commit 00d7127)

`lib/utils/security_utils.dart:218–223` — The `raw.contains('\r')` guard blocks CRLF multi-line messages, but the same control characters are also stripped by `sanitizeUserInput` via the `codeUnit < 32` check (line 49). This creates redundancy with unclear layering intent. Add a comment explaining whether this is a defense-in-depth measure or if one guard should be removed.

**File:** `lib/utils/security_utils.dart:218–223`

**Status:** Open — Needs clarifying comment

---

### R02: Document `_stackTracePattern` Extension List Limitations

**Priority:** P4 | **Severity:** Low | **Source:** code-reviewer (commit 00d7127)

`lib/utils/security_utils.dart:210` — The regex matches `.dart|.js|.ts|.cjs|.mjs|.wasm` file extensions but not `.py` or `.rb`. This is a known accepted-risk gap for the current deployed stack, but it is undocumented in the code comment. Add a brief note that the extension list is intentionally limited to current runtimes and should be extended if the backend runtime changes.

**File:** `lib/utils/security_utils.dart:205–210`

**Status:** Open — Needs documentation update

---

### R03: Add Isolated Test for Bare Carriage Return (`\r`) in `sanitizeServerError`

**Priority:** P4 | **Severity:** Low | **Source:** code-reviewer (commit 00d7127)

`test/utils/security_utils_test.dart:396–401` — The CRLF test uses `'line1\r\nline2'`, which would be blocked by the pre-existing `contains('\n')` check alone. The test does not isolate the `\r`-specific guard. Add a test with bare `'line1\rline2'` to verify the new `\r` guard independently.

**File:** `test/utils/security_utils_test.dart`

**Status:** Open — Needs additional test case

---

### R04: Add Performance Comment to `_stackTracePattern` Static Final

**Priority:** P4 | **Severity:** Low | **Source:** code-reviewer (commit 00d7127)

`lib/utils/security_utils.dart:209–210` — `_stackTracePattern` is correctly declared `static final` (compile once, reuse), but the performance motivation is undocumented. Add a one-liner explaining that `RegExp` compilation is expensive and should not be repeated in hot loops.

**File:** `lib/utils/security_utils.dart:209–210`

**Status:** Open — Needs documentation update

---

### R05: Dedup `PasswordPolicy.minLength` Test Assertions

**Priority:** P3 | **Severity:** Medium | **Source:** code-reviewer (commit 94d26d0)

`test/config/constants_test.dart:93–107` — Tests `'minLength is at least 8 characters'` (asserts `greaterThanOrEqualTo(8)`) and `'minLength is 8 for DOS protection'` (asserts `equals(8)`) both verify the same property. The `equals(8)` assertion strictly subsumes the `greaterThanOrEqualTo(8)` one, adding noise and creating redundant failure modes. Remove one or rephrase to cover a distinct property (e.g., `minLength < maxLength / 2` as a proportionality check).

**File:** `test/config/constants_test.dart:93–107`

**Status:** Open — Refactor to eliminate duplicate coverage

---

### R06: Remove Backlog ID from Test Group Name

**Priority:** P4 | **Severity:** Low | **Source:** code-reviewer (commit 94d26d0)

`test/config/constants_test.dart:92` — Test group is named `'PasswordPolicy (L21: shared constants)'`, embedding a transient backlog ID. Once the item is archived, the label becomes misleading. Use a plain descriptive name like `'PasswordPolicy'`.

**File:** `test/config/constants_test.dart:92`

**Status:** Open — Rename test group

---

### R07: Add Boundary Tests for `PasswordPolicy` Min/Max Length

**Priority:** P4 | **Severity:** Low | **Source:** code-reviewer (commit 94d26d0)

`test/config/constants_test.dart` — No test verifies what happens when a password is exactly `minLength` or exactly `maxLength` characters. These boundary values are the most likely to regress if constants shift. Add tests in the auth-page widget tests (not here) to verify passwords of exactly 8 and 128 chars pass validation.

**File:** `test/pages/auth_page.dart` (or integrate into existing validation tests)

**Status:** Open — Add boundary value tests

---

### R08: Update TDD Report with Current `_stackTracePattern` Regex

**Priority:** P4 | **Severity:** Low | **Source:** code-reviewer (commit e623040)

`docs/TDD_SESSION_REPORT.md:55–58` — The code snippet shows the original regex `\.(dart|js|ts):\d` from commit `4554f81`, but commit `00d7127` extended it to include `cjs|mjs|wasm`. The report was not updated to reflect the amended pattern. Update the snippet to match current source.

**File:** `docs/TDD_SESSION_REPORT.md:55–58`

**Status:** Open — Update documentation snapshot

---

### R09: Back-Fill Commit Hashes in Changelog v1.1

**Priority:** P4 | **Severity:** Low | **Source:** code-reviewer (commit e89fd7d)

`docs/changelog/1.1/CHANGELOG.md:398` (M14, M15, M16, L19, L20) — Entries read `Commit: session 2026-03-20` instead of real git hashes. This breaks traceability. Back-fill with actual commit hashes from `git log`.

**File:** `docs/changelog/1.1/CHANGELOG.md`

**Status:** Open — Add missing commit references

---

### R10: Remove Duplicate M07 Entry from Open Items

**Priority:** P4 | **Severity:** Low | **Source:** code-reviewer (commit e89fd7d)

`docs/BACKLOG.md:162–171` — M07 is listed in the changelog as done but still appears under `## Open Items` with a `Status: Done` footnote. The migration was supposed to remove Done items. Remove the M07 entry from this file.

**File:** `docs/BACKLOG.md:162–171`

**Status:** Open — Clean up duplicate entry

---

*Last updated: 2026-03-20 (migrated M07, #134–#138, T01, M08–M16, L19–L20, M17, L21, L22 to changelog/1.1; added code review findings R01–R10)*
