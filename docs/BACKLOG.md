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

**Status:** Done (commit 18864e3, 2026-03-15) — `_TimelineCard` and `_StatBadge` consolidated into `DocStatCard` via new `valueStyle` and `constraints` params. `about_page::_StatCard` and `social_proof_section::_StatCard` not consolidated (structurally too different).

---

## Code Quality Findings from Phase 3a (code-reviewer results)

### M07: Add retry count assertion to 500 retry test

**Priority:** P2 | **Source:** session 2026-03-14, code-reviewer (commit 2fce62a)

`contact_service_test.dart:377–390` — Test named `'handles 500 internal server error with retries'` only asserts the final error message; it does not verify that the retry loop actually ran `_maxRetries` times. `_MockDio` lacks a `postCallCount` field. Add counter to `_MockDio` and assert `postCallCount == 3` (1 initial + 2 retries).

**File:** `test/services/contact_service_test.dart:377–390`

**Status:** Deferred — test coverage gap.

---

### L13: Use findsOneWidget instead of findsWidgets in page hero assertions

**Priority:** P4 | **Source:** session 2026-03-14, code-reviewer (commit 2bccbb6)

`contact_page_test.dart:90` and `:112` use `findsWidgets` (any count >= 1) for `'Get in Touch'` headline and `'Schedule a Demo'` card title. If a layout bug renders duplicates, the test still passes. Replace with `findsOneWidget` or `findsNWidgets(n)` with the expected count. Audit same pattern across other page tests (`careers_page_test.dart:104`).

**Files:** `test/pages/contact_page_test.dart`, `test/pages/careers_page_test.dart`

**Status:** Done (2026-03-15) — replaced `findsWidgets` with `findsNWidgets(2)` in contact_page_test (both texts appear in desktop+mobile responsive variants). careers_page_test.dart:104 already uses `findsOneWidget`.

---

### L14: Dead hover color branch in _QuickContactCard

**Priority:** P4 | **Source:** session 2026-03-14, code-reviewer (commit 2bccbb6)

`contact_page.dart:165` — `color: _isHovered ? AppColors.gray800 : AppColors.gray800` — both branches identical. The conditional is dead code. Remove the ternary and use `AppColors.gray800` directly.

**File:** `lib/pages/contact_page.dart:165`

**Status:** Done (2026-03-15) — removed dead ternary, using `AppColors.gray800` directly.

---

### L15: Update buildBadge helper to accept iconColor parameter

**Priority:** P4 | **Source:** session 2026-03-15, code-reviewer (commit d6f9142)

`gradient_pill_badge_test.dart:73-81` — The new "icon uses custom color when provided" test uses inline `testableWidget()` instead of the `buildBadge()` helper. Update the helper to accept an optional `iconColor` parameter so both tests can use it consistently.

**File:** `test/widgets/common/gradient_pill_badge_test.dart:9-13, 73-84`

**Status:** Done (2026-03-15) — added `iconColor` param to `buildBadge` helper, updated test to use it.

---

*Last updated: 2026-03-15 (Phase 3b done — _TimelineCard, _StatBadge consolidated into DocStatCard)*

*Updated 2026-03-15 (L15 appended from L10 code-reviewer findings)*

*Previous: 2026-03-14 (Phase 3a code-reviewer findings appended; magic number `size: 16` → `AppSpacing.iconSM` fixed)*

*Updated 2026-03-14 (commit 2fce62a code-reviewer findings: M06–M08, L12 appended)*

*Updated 2026-03-14 (L02, L04, L12, M05 done; L08 closed as invalid)*

*Updated 2026-03-14 (migrated 12 Done items to docs/changelog/1.1/CHANGELOG.md): L01–L05, M01–M03, L09, M05, M06, L12*

*Updated 2026-03-14 (code-reviewer commit 2bccbb6: L13, L14 added; L11 updated with follow-up refactor f241d00)*
