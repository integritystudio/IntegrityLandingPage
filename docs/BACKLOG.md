# Security & Infrastructure Backlog

Open and deferred items only. Completed items are documented in `docs/changelog/1.0/CHANGELOG.md` and `docs/changelog/1.1/CHANGELOG.md`.

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

## Deferred: ContentLoader Static Facade (#106)

### #106: Remove Content Static Facade (190-line delegation)

**Severity:** LOW
**Category:** Code Quality (Dead Code)
**File:** `lib/config/content/content.dart`

After #105 collapses `ContentLoader` to static-only, the `Content` facade becomes a simple forwarding wrapper. Removing it eliminates 190 lines of trivial delegation, but production code depends on `Content.*` static getters for public API stability.

**Status:** Deferred — Conditional on #105 (completed 2026-03-12). Blocked by API stability concerns (production code depends on `Content.*` static getters).

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

## E2E Test Quality: Low-Priority Assertions (code-reviewer findings)

### L01: Tighten manifest.json assertions in routing.spec.ts

**Priority:** P4 | **Source:** session 2026-03-14, code-reviewer

Replace `toBeDefined()` with `toBeTruthy()` on `manifest.json` name and short_name (lines 76–77). `toBeDefined()` passes for `null`, `false`, or `''`; a more meaningful assertion is needed.

**File:** `e2e/tests/routing.spec.ts:76–77`

**Status:** Deferred — low-priority assertion tightening, not a functional gap.

---

### L02: Add robots.txt Disallow assertion in routing.spec.ts

**Priority:** P4 | **Source:** session 2026-03-14, code-reviewer

Line 85 checks only for `'User-agent'`. A `robots.txt` with only that header is vacuous. Add assertion for `Disallow` or `Sitemap` to make the test more meaningful.

**File:** `e2e/tests/routing.spec.ts:85`

**Status:** Deferred — low-priority assertion strengthening.

---

### L03: Document service worker availability policy in routing.spec.ts

**Priority:** P4 | **Source:** session 2026-03-14, code-reviewer

Lines 121–124 intentionally allow `[HTTP_OK, HTTP_NOT_FOUND]` for `flutter_service_worker.js`. Document whether this is permanent policy or expected to tighten (known gap).

**File:** `e2e/tests/routing.spec.ts:121–124`

**Status:** Deferred — clarification-only; add inline comment explaining the loose assertion rationale.

---

### L04: Extract blog route constants in routing.spec.ts

**Priority:** P4 | **Source:** session 2026-03-14, code-reviewer

Lines 199–248 use `/blog` and `/internship` as inline strings in redirect tests. Add named constants (e.g., `SPA_ROUTE_BLOG`, `SPA_ROUTE_INTERNSHIP`) to align with `spaRoutes` array pattern.

**File:** `e2e/tests/routing.spec.ts:199–248`

**Status:** Deferred — low-priority constant extraction for consistency.

---

### L05: Use static test fixture for blog article assertions in routing.spec.ts

**Priority:** P4 | **Source:** session 2026-03-14, code-reviewer

Lines 155, 165, 173 reference hardcoded article slugs (`best-llm-monitoring-tools-2025.html`, `ai-observability-platform-strategy/index.html`, `ai-observability-platform-strategy.html`). If articles are removed or renamed, tests fail for wrong reasons. Consider asserting on a static fixture article committed to the repo, or document this external dependency explicitly.

**File:** `e2e/tests/routing.spec.ts:155, 165, 173`

**Status:** Deferred — low-priority risk mitigation; requires creating a test fixture article or updating test patterns.

---

*Last updated: 2026-03-14 (migrated #91–#158 to docs/changelog/1.1/CHANGELOG.md)*
