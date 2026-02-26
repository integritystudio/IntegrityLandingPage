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

## Code Quality: ast-grep Review Findings (2026-02-25)

### #31: console.log in e2e tests

**Severity:** WARNING
**Category:** Code Quality
**Rule:** `no-console-log`

| File | Line | Code |
|------|------|------|
| `e2e/tests/landing-page.spec.ts` | 8 | `console.log('Browser error:', msg.text())` |
| `e2e/tests/landing-page.spec.ts` | 27 | `console.log('Flutter app loaded successfully!')` |
| `e2e/tests/spa-navigation.spec.ts` | 24 | `console.log('Browser error:', msg.text())` |

**Fix:** Replace with a silent handler or Playwright's built-in `page.on('console')` filtering. Remove line 27 entirely (debug artifact).

---

### #32: `let` used where `const` suffices — `kvFailureCount`

**Severity:** INFO
**Category:** Code Quality
**Rule:** `prefer-const`
**File:** `workers/contact-form/src/index.ts:50`
**Code:** `let kvFailureCount = 0;`
**Fix:** Verify runtime reassignment. If module-scoped and mutated, this is a false positive; otherwise use `const`.

---

### #33: `let` used where `const` suffices — `kvCircuitResetAt`

**Severity:** INFO
**Category:** Code Quality
**Rule:** `prefer-const`
**File:** `workers/contact-form/src/index.ts:52`
**Code:** `let kvCircuitResetAt = 0;`
**Fix:** Same as #32 — verify runtime reassignment.

---

### #34: `let` used where `const` suffices — `evicted`

**Severity:** INFO
**Category:** Code Quality
**Rule:** `prefer-const`
**File:** `workers/contact-form/src/index.ts:87`
**Code:** `let evicted = 0;`
**Fix:** Replace with `const` if value is never reassigned in its scope.

---

### #35: `let` used where `const` suffices — `mismatch`

**Severity:** INFO
**Category:** Code Quality
**Rule:** `prefer-const`
**File:** `workers/contact-form/src/index.ts:251`
**Code:** `let mismatch = 0;`
**Fix:** Replace with `const` if value is never reassigned in its scope.

---

### #36: `let` used where `const` suffices — `i`

**Severity:** INFO
**Category:** Code Quality
**Rule:** `prefer-const`
**File:** `workers/contact-form/src/index.ts:252`
**Code:** `let i = 0;`
**Fix:** If used as a loop counter with reassignment, this is a false positive. Otherwise use `const`.

---

### #37: Magic numbers in e2e tests

**Severity:** LOW
**Category:** Code Quality
**Rule:** `magic-number`
**Files:** `e2e/tests/landing-page.spec.ts`, `e2e/tests/*.spec.ts`, `workers/contact-form/src/index.ts`
**Count:** 117 instances (viewport sizes, timeouts, HTTP status codes, rate limits)
**Fix:** Extract repeated values into named constants (e.g., `VIEWPORT_WIDTH`, `RATE_LIMIT_WINDOW_MS`, `HTTP_429`).

---

### #38: Magic numbers in contact-form worker

**Severity:** LOW
**Category:** Code Quality
**Rule:** `magic-number`
**File:** `workers/contact-form/src/index.ts`
**Fix:** Extract rate-limit thresholds, timeout values, and HTTP status codes into a config/constants block at the top of the file.

---

## Priority Matrix

| Issue | Severity | Category | Status |
|-------|----------|----------|--------|
| #8-10 OAuth (deferred) | CRITICAL | Security | N/A until OAuth backend |
| #23 KV consistency | HIGH | Reliability | Accepted risk |
| #30 Multi-env CSP | LOW | Infrastructure | Accepted |
| #31 console.log in e2e | WARNING | Code Quality | Open |
| #32-36 prefer-const (5) | INFO | Code Quality | Open — verify reassignment |
| #37-38 magic numbers | LOW | Code Quality | Open |

---

*Last updated: 2026-02-25 | Added #31-#38 from ast-grep code review*
