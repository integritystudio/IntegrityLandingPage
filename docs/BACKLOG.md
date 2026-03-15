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

## Done: ContentLoader Static Facade (#106)

### #106: Remove Content Static Facade (190-line delegation)

**Severity:** LOW
**Category:** Code Quality (Dead Code)
**File:** `lib/services/content_loader.dart`

**Status:** Done 2026-03-14 — Removed `Content` facade class (~210 lines). All 12 consumer files migrated to `ContentLoader.*`. 2395 tests pass.


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


---


### M04: Validate retry-after header and synthetic submissionId

**Priority:** P2 | **Source:** session 2026-03-14, code-reviewer

`contact_service.dart:362–377` — two issues:
1. `retry-after` parsing (line 362) does not validate integer is positive; could show "try again in 0 seconds"
2. Synthetic fallback `submissionId` (line 376) looks like a real ID and could confuse deduplication logic

**File:** `lib/services/contact_service.dart:362–377`

**Status:** Deferred — edge case validation.

---

### L06: Report analytics initialization exceptions to Sentry

**Priority:** P3 | **Source:** session 2026-03-14, code-reviewer

`analytics.dart:65–71` and `facebook_pixel_service.dart:540–545` — init exceptions swallowed without Sentry reporting. Add `ErrorTrackingService.captureException(e, context: 'AnalyticsService.initialize')` in catch blocks.

**File:** `lib/services/analytics.dart:65–71`, `lib/services/facebook_pixel_service.dart:540–545`

**Status:** Deferred — observability gap.

---

### L07: Reset _loadCompleter in ContentLoader.loadFromString

**Priority:** P3 | **Source:** session 2026-03-14, code-reviewer

`content_loader.dart:104` — `loadFromString` in test helper does not reset `_loadCompleter`. If a test calls `load()` then `loadFromString` without `reset()`, subsequent `load()` will await stale completer indefinitely.

**File:** `lib/services/content_loader.dart:104`

**Status:** Deferred — test harness robustness.

---

### L08: Add @visibleForTesting to _dio field

**Priority:** P4 | **Source:** session 2026-03-14, code-reviewer

`contact_service.dart:132` — `_dio` mutable static has test setter but field itself lacks `@visibleForTesting` annotation. Add annotation to field (line 132) to clarify test-only access.

**File:** `lib/services/contact_service.dart:132`

**Status:** Closed 2026-03-14 — Invalid. `_dio` is private; `@visibleForTesting` only applies to public members (dart analyzer rejects it). Test-only access is already gated via public `setDioForTesting()` which has the annotation.

---

## Refactor: Widget Duplication Reduction

### Phase 3b: Consolidate StatCard / StatBadge Variants

**Priority:** P3 | **Source:** duplication analysis 2026-03-14

Consolidate `_StatCard`, `_StatBadge`, and `_TimelineCard` variants with the existing `DocStatCard` in `doc_components.dart`. These share 73-76% structural similarity but differ in decoration.

**Impact:** Eliminates ~3 duplicate pairs.

**Reference:** [`docs/duplicate-findings.md`](duplicate-findings.md) — see "76% — `_TimelineCard` ~ `DocStatCard`" and "73% — Cross-page card patterns"

**Status:** Open.

---

## Code Quality Findings from Phase 3a (code-reviewer results)

### L10: GradientPillBadge icon color hardcoded to AppColors.success

**Priority:** P3 | **Source:** session 2026-03-14, code-reviewer (commit 1de0043)

`gradient_pill_badge.dart:50` — icon color is hardcoded to `AppColors.success` (green). This is semantically correct for `LucideIcons.checkCircle` on features_page, but the widget is general-purpose (accepts any `IconData?`). A caller passing a non-check icon (bell, star, info) will render green, which is misleading. Add optional `iconColor` parameter defaulting to `AppColors.blue400` (matching label text color).

**File:** `lib/widgets/common/gradient_pill_badge.dart:50`

**Status:** Deferred — API extensibility.

---

### L11: Missing page-level tests for contact_page and features_page heroes

**Priority:** P3 | **Source:** session 2026-03-14, code-reviewer (commit 1de0043)

No `contact_page_test.dart` or `features_page_test.dart` exist. After Phase 3a refactor, hero sections for contact (`"We're Here to Help"`, `"Get in Touch"`) and features (`FeaturesContentVariants.complianceBadge`, pageTitle) have no page-level smoke tests. If future edits break the wiring (wrong string, missing badge), there is no fast feedback.

**Files:** `test/pages/contact_page_test.dart`, `test/pages/features_page_test.dart`

**Status:** Done 2026-03-14 — Added 37 page-level smoke tests (20 contact, 17 features) covering hero badge/headline/subheadline, quick contact cards, support info, footer, responsive layout, and back button callback. Also fixed case-sensitive assertion bug in `contact_service_test.dart:960` (`'Gateway Timeout'` vs `'timeout'`). Follow-up refactor (f241d00): extracted hero magic strings to `ContactContentVariants` constants, widened `PagePumpFunction` to accept `onShowCookieSettings` (removing adapter wrappers), added missing `initializeTestContent()` in `features_page_test.dart`.

---

### M07: Add retry count assertion to 500 retry test

**Priority:** P2 | **Source:** session 2026-03-14, code-reviewer (commit 2fce62a)

`contact_service_test.dart:377–390` — Test named `'handles 500 internal server error with retries'` only asserts the final error message; it does not verify that the retry loop actually ran `_maxRetries` times. `_MockDio` lacks a `postCallCount` field. Add counter to `_MockDio` and assert `postCallCount == 3` (1 initial + 2 retries).

**File:** `test/services/contact_service_test.dart:377–390`

**Status:** Deferred — test coverage gap.

---

### M08: Apply safe-cast pattern to _fetchCsrfToken GET response

**Priority:** P2 | **Source:** session 2026-03-14, code-reviewer (commit 2fce62a)

`contact_service.dart:266` — `_fetchCsrfToken` uses unsafe cast `response.data as Map<String, dynamic>` on GET response. If the worker returns 2xx with a non-map body (e.g., HTML error page during maintenance), this throws `TypeError` instead of `DioException`. POST branch uses safe pattern `response.data is Map`. Apply the same pattern to the GET branch for consistency.

**File:** `lib/services/contact_service.dart:266`

**Status:** Deferred — type safety improvement.

---

### L13: Use findsOneWidget instead of findsWidgets in page hero assertions

**Priority:** P4 | **Source:** session 2026-03-14, code-reviewer (commit 2bccbb6)

`contact_page_test.dart:90` and `:112` use `findsWidgets` (any count >= 1) for `'Get in Touch'` headline and `'Schedule a Demo'` card title. If a layout bug renders duplicates, the test still passes. Replace with `findsOneWidget` or `findsNWidgets(n)` with the expected count. Audit same pattern across other page tests (`careers_page_test.dart:104`).

**Files:** `test/pages/contact_page_test.dart`, `test/pages/careers_page_test.dart`

**Status:** Open.

---

### L14: Dead hover color branch in _QuickContactCard

**Priority:** P4 | **Source:** session 2026-03-14, code-reviewer (commit 2bccbb6)

`contact_page.dart:165` — `color: _isHovered ? AppColors.gray800 : AppColors.gray800` — both branches identical. The conditional is dead code. Remove the ternary and use `AppColors.gray800` directly.

**File:** `lib/pages/contact_page.dart:165`

**Status:** Open.

---

*Last updated: 2026-03-14 (Phase 3a code-reviewer findings appended; magic number `size: 16` → `AppSpacing.iconSM` fixed)*

*Updated 2026-03-14 (commit 2fce62a code-reviewer findings: M06–M08, L12 appended)*

*Updated 2026-03-14 (L02, L04, L12, M05 done; L08 closed as invalid)*

*Updated 2026-03-14 (migrated 12 Done items to docs/changelog/1.1/CHANGELOG.md): L01–L05, M01–M03, L09, M05, M06, L12*

*Updated 2026-03-14 (code-reviewer commit 2bccbb6: L13, L14 added; L11 updated with follow-up refactor f241d00)*
