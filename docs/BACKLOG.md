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

## Code Quality Findings (code-reviewer results)

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
**Status:** Open

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

*Last updated: 2026-03-17 (completed #134, #135, M07, #137, #138; review fixes in 44a2450)*

*Previous: 2026-03-15 (Phase 3b done, L15 appended)*

*Previous: 2026-03-14 (migrated 12 Done items to changelog): L01–L05, M01–M03, L09, M05, M06, L12*
