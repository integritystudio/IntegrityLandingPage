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


*Last updated: 2026-03-06*
*Migrated items: 22 total → docs/changelog/1.0/CHANGELOG.md:*
  *- 9 items (3 HIGH, 6 MEDIUM) from Flutter expert audit*
  *- 13 items (all LOW) from backlog implementation sprint*
*Remaining open: 0 + 3 deferred (OAuth #8-#10)*
