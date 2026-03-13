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

## Deferred: Widget Refactoring Phase 3 (#91)

### #91: Extract Button Base, Trust Badge, and Page Shell Primitives

**Severity:** LOW
**Category:** Code Quality (DRY)
**Files:**
- `lib/widgets/buttons/` — base button primitives (ButtonBase, TextButton, GhostButton patterns)
- `lib/widgets/trust/` — `TrustBadge`, `CertificationBadge` shared components
- `lib/widgets/shells/` — AppShell layout primitives (SliverAppBar + Footer template)
**Source:** Code review session 2026-02-26

Recurring patterns across pages (button wrappers, trust badges, AppShell + Footer scaffolding). Low impact on current backlog but benefits future page additions.

**Status:** Deferred — Low priority, schedule after critical items.

---

## Deferred: ContentLoader Static Facade (#106)

### #106: Remove Content Static Facade (190-line delegation)

**Severity:** LOW
**Category:** Code Quality (Dead Code)
**File:** `lib/config/content/content.dart`

After #105 collapses `ContentLoader` to static-only, the `Content` facade becomes a simple forwarding wrapper. Removing it eliminates 190 lines of trivial delegation, but production code depends on `Content.*` static getters for public API stability.

**Status:** Deferred — Conditional on #105 (completed 2026-03-12). Blocked by API stability concerns (production code depends on `Content.*` static getters).

---

## Deferred: Layout Bugs and Minor Enhancements (#100, #136)

### #100: Consider Animation Reset Pattern for disableAnimations Toggle

**Severity:** LOW
**Category:** Code Quality (Edge Case)
**Files:**
- `lib/widgets/common/buttons.dart:237-241`
- `lib/widgets/decorative/animated_orb.dart:74-81`
**Source:** Code review session 2026-03-09

In test teardown with `disableAnimations=true`, animations are disabled AFTER `initState` but ongoing animations were already scheduled. The guard `if (controller.isAnimating)` prevents spurious rebuilds but an explicit `reset()` (jump-to-end + reset controller) would be cleaner. Lower priority.

**Status:** Deferred — edge case, lower priority. Requires decision on whether jump-to-start is acceptable (skips animation visually but completes all frame callbacks).

---

### #136: SharedAppBar Nav Item Count Scalability

**Severity:** LOW
**Category:** Layout / UX
**File:** `lib/widgets/navigation/shared_app_bar.dart`
**Source:** SliverAppBar overflow fix 2026-03-11

The inline desktop nav (7 items + CTA) required reducing NavLink padding from `md` to `sm` and using the desktop breakpoint (>=1024px) instead of tablet (>=768px) for the compact/inline nav switch. Adding further nav items will re-introduce overflow. Consider `OverflowBar` or a "More..." dropdown for future scalability.

**Status:** Deferred — current layout fits at desktop widths after padding reduction.

---

## Deferred: E2E Test Coverage Limitations (Flutter Canvas)

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

**Status:** Deferred — Flutter web canvas rendering limitation (confirmed). Cannot inspect rendered content from Playwright. Future options: debug endpoint, accessibility tree, or visual regression.

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

**Status:** Deferred — error page content is rendered to Flutter canvas; cannot inspect for "404" text or links. Unknown route rendering is already covered by redirect-rules.spec.ts unknown route tests.

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

### #117: Mobile Hamburger Menu and Touch Interactions

**Severity:** MEDIUM
**Category:** E2E Test Coverage (Flutter Canvas Limitation)
**Files:** `e2e/tests/mobile-nav.spec.ts`
**Source:** Coverage gap analysis 2026-03-11

Mobile pages load ✓, but mobile-specific interactions are untested:
- Hamburger menu tap to open/close
- Touch scroll responsiveness (fling)
- Bottom sheet dismissal (swipe/tap outside)
- Overlay opacity feedback

**Status:** Deferred — confirmed Flutter canvas limitation. Mobile nav renders to canvas; no DOM selector available for hamburger tap detection without refactoring navigation to HTML.

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

## Code Review Findings — Session 2026-03-12 (#109/#131 Backlog Sprint)

**Source:** Code reviewer (per-item and full-stack reviews of #109/#131 implementation)

### #142: GET from Unauthorized Origin Not Tested on CSRF Endpoint

**Severity:** MEDIUM
**Category:** E2E Test Coverage (Origin Gating Gap)
**File:** `e2e/tests/contact-worker.spec.ts`
**Source:** Full-stack review (session 2026-03-12, commits e912b39 + 9dd26d9 + 8c1c113)

**Status:** Done — commit f21e366 (2026-03-12)

---

### #143: Rate-Limit 429 Can Mask Validation Failures in Form Tests

**Severity:** MEDIUM
**Category:** E2E Test Reliability (Non-Determinism)
**File:** `e2e/tests/contact-worker.spec.ts:144-189`
**Source:** Full-stack review (session 2026-03-12)

**Status:** Done — commit 6249a97 (2026-03-12)

---

### #144: CSRF Token Endpoint Content-Type Assertion Unconditional on 503

**Severity:** LOW
**Category:** E2E Test Reliability (Assertion Tightness)
**File:** `e2e/tests/contact-worker.spec.ts:117-124`
**Source:** Per-item review of #131 (session 2026-03-12)

**Status:** Done — commit 279e477 (2026-03-12)

---

### #145: No CSRF Token Round-Trip Test (GET → POST)

**Severity:** LOW
**Category:** E2E Test Coverage (Happy Path)
**File:** `e2e/tests/contact-worker.spec.ts`
**Source:** Full-stack review (session 2026-03-12)

No test fetches a valid CSRF token via GET and replays it on a POST submission. The full happy-path round-trip (GET token → POST with `X-CSRF-Token` header → success/failure response) is untested. This would be the only test confirming the CSRF handshake works end-to-end.

**Fix:** Add test that GETs a CSRF token, then POSTs with it in `X-CSRF-Token`. Skip on 503 (CSRF_SECRET not configured). On 200, assert body structure. Would trigger real Resend call — either mock or accept as integration test risk.

**Status:** Deferred — would trigger real email delivery unless Resend is mocked or a test recipient is used. Consider adding to integration test suite rather than e2e.

---

---

### #146: "POST response is JSON" Test Missing 429 Guard

**Severity:** MEDIUM
**Category:** E2E Test Reliability (Rate-Limit Coverage)
**File:** `e2e/tests/contact-worker.spec.ts:197-207`
**Source:** Full-stack review (session 2026-03-12, code-reviewer agent)

Test hits the same worker endpoint without a 429 skip guard, unlike the three adjacent form validation tests fixed in #143. A 429 from CF edge may return an HTML body, causing the `content-type: application/json` assertion to fail with a confusing error. Identical gap to #143 but not addressed in that commit.

**Status:** Done — commit 5a3831d (2026-03-12)

---

### #147: CSRF Token Format Test Uses Inconsistent Skip Pattern

**Severity:** MEDIUM
**Category:** E2E Test Reliability (API Misuse)
**File:** `e2e/tests/contact-worker.spec.ts:145-148`
**Source:** Full-stack review (session 2026-03-12, code-reviewer agent)

Line 145 still uses `test.skip(response.status() !== 200, ...)` mid-test (called after `await`), while #144 (commit 279e477) established the correct `if (condition) { test.skip(); return; }` pattern to halt execution. The conditional version doesn't guarantee execution stops, causing the `response.json()` call to risk throwing on a non-200 HTML body.

**Status:** Done — commit 5a3831d (2026-03-12)

---

### #148: Origin Gating Tests Don't Assert Response Body

**Severity:** MEDIUM
**Category:** E2E Test Coverage (Security Boundary)
**File:** `e2e/tests/contact-worker.spec.ts:71-81, 84-89`
**Source:** Full-stack review (session 2026-03-12, code-reviewer agent)

Both POST and GET unauthorized-origin tests assert only the status code (`[403, 429]`), not whether the response contains an error message. Tests at line 237 assert `body.error` is defined. For a security boundary, asserting that rejection includes an error payload strengthens the signal and prevents silent failures.

**Status:** Done — commit 5a3831d (2026-03-12)

---

### #149: Submission Flow Tests — Post-Await Skip Pattern Inconsistency

**Severity:** MEDIUM
**Category:** E2E Test Reliability (Skip Pattern)
**File:** `e2e/tests/contact-worker.spec.ts:247-251, 263-264`
**Source:** Full-stack review (session 2026-03-12, code-reviewer agent)

The `submission flow` tests at lines 247 and 263 still use `test.skip(condition, msg)` after an `await`. This is the same pattern that was fixed in #147 for the CSRF token format test. When a 429 is returned with an HTML body, `response.json()` on line 250 will run unconditionally and throw a JSON parse error, surfacing as test infrastructure failure rather than a clean skip.

**Fix:** Replace with `if (status === 200) { test.skip(); return; }` pattern established in #147, and guard `response.json()` calls on 403 responses only (429 may return HTML).

**Status:** Done — commit 49d4ab5 (2026-03-12)

---

### #150: Form Validation Tests — Soft Skip Pattern Doesn't Halt

**Severity:** MEDIUM
**Category:** E2E Test Reliability (Skip Pattern Consistency)
**File:** `e2e/tests/contact-worker.spec.ts:179, 192, 204, 217`
**Source:** Full-stack review (session 2026-03-12, code-reviewer agent)

The three form validation tests use `test.skip(condition, msg)` with a message argument. This is the "soft" variant — it does not throw or halt execution; it marks the test skipped and continues to the next line. Assertions at lines 181, 193, 205, 219 execute even when skipped. Currently not harmful (broad assertions fail on 429), but intent is unclear and pattern is inconsistent with the `if-guard + test.skip() + return` pattern established in #147.

**Status:** Done — commit 953ecfa (2026-03-12)

---

### #151: JSDoc Worker URL Comment Hardcoded

**Severity:** LOW
**Category:** Code Quality (Documentation Drift)
**File:** `e2e/tests/contact-worker.spec.ts:22`
**Source:** Full-stack review (session 2026-03-12, code-reviewer agent)

JSDoc comment hardcodes `Worker URL: https://integrity-studio-contact.alyshia-b38.workers.dev` while the actual worker URL is driven by the `CONTACT_WORKER_URL` constant (line 2). The comment will silently drift if the constant is updated.

**Status:** Done — commit 95c0310 (2026-03-12)

---

### #152: Redundant WORKER_URL Constant Alias

**Severity:** LOW
**Category:** Code Quality (Dead Code)
**File:** `e2e/tests/contact-worker.spec.ts:26`
**Source:** Full-stack review (session 2026-03-12, code-reviewer agent)

Line 26 defines `const WORKER_URL = CONTACT_WORKER_URL;` as a no-op alias without adding value. Use `CONTACT_WORKER_URL` directly or rename at the import site to clarify intent.

**Status:** Done — commit 95c0310 (2026-03-12)

---

*Last updated: 2026-03-12 (migrated 44 Done items to docs/changelog/1.0/CHANGELOG.md; appended #142-#145 code review findings from #109/#131 sprint; appended #146-#148 follow-up gaps from full-stack review; marked #146-#148 Done; appended #149-#152 pre-existing gaps from full-stack review; marked #149-#152 Done after test reliability sprint)*
