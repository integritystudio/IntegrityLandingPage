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
