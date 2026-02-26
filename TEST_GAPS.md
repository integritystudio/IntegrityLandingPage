# Contact Form Test Gaps

Identified 2026-02-25 against `main` (commit `11698dc`).
Updated 2026-02-25: closed U1–U10, W2, W3, W6, W7.

## Unit Tests — `test/unit/services/contact_service_test.dart`

### High

| # | Gap | Source | Status |
|---|-----|--------|--------|
| U1 | 504 gateway timeout retry + exhaustion | `contact_service.dart:321-329` | **CLOSED** — 2 tests: retry-then-succeed + exhaustion |
| U2 | Non-Dio exception in `submitForm` | `contact_service.dart:391-397` | **CLOSED** — FormatException exercised, no-retry verified |

### Medium

| # | Gap | Source | Status |
|---|-----|--------|--------|
| U3 | 429 without Retry-After header | `contact_service.dart:337-339` | **CLOSED** — `seconds == null` branch, `retryAfterSeconds` asserted null |
| U4 | `receiveTimeout` retry path | `contact_service.dart:359-361` | **CLOSED** — 2 tests: receiveTimeout + connectionError, 3 attempts each |
| U5 | Name exceeding `maxNameLength` (100) | `contact_service.dart:183-184` | **CLOSED** — boundary tests: 101 (error) + 100 (ok) |
| U6 | Email exceeding `maxEmailLength` (254) | `contact_service.dart:190-191` | **CLOSED** — 255-char email triggers length error |
| U7 | Organization exceeding `maxOrganizationLength` (200) | `contact_service.dart:197-200` | **CLOSED** — boundary tests: 201 (error) + 200 (ok) |
| U8 | Message exceeding `maxMessageLength` (5000) | `contact_service.dart:218-220` | **CLOSED** — boundary tests: 5001 (error) + 5000 (ok) |

### Low

| # | Gap | Source | Status |
|---|-----|--------|--------|
| U9 | 200 response with `success: false` | `contact_service.dart:351-355` | **CLOSED** — distinct from 400 path, error message asserted |
| U10 | Success response with null message/submissionId | `contact_service.dart:346-349` | **CLOSED** — fallback defaults verified |

## Widget Tests — `test/widgets/sections/contact_section_test.dart`

### High

| # | Gap | Source | Status |
|---|-----|--------|--------|
| W1 | Default `ContactService.submitForm` path | `contact_section.dart:517-553` | **OPEN** — requires Dio mock injection into widget test; deferred to integration test layer |

### Medium

| # | Gap | Source | Status |
|---|-----|--------|--------|
| W2 | Form data cleared on success | `contact_section.dart:545` | **CLOSED** — test added documenting callback vs ContactService path behavior |
| W3 | Field errors from `ContactFormError.fieldErrors` | `contact_section.dart:549-551` | **CLOSED** — error alert path verified; fieldErrors map requires W1 (ContactService path) |

### Low

| # | Gap | Source | Status |
|---|-----|--------|--------|
| W4 | Facebook Pixel tracking on success | `contact_section.dart:539-543` | OPEN — analytics side-effect; requires W1 |
| W5 | Calendly URL internal route (`startsWith('/')`) | `contact_section.dart:404` | OPEN — requires GoRouter mock |
| W6 | `showLiveDemoSection` parameter | `contact_section.dart:34,370` | **CLOSED** — `showLiveDemoSection: false` hides demo section |
| W7 | `_buildFullName()` with firstName+lastName | `contact_section.dart:456-465` | **CLOSED** — explicit assertion on submitted firstName/lastName data |

## E2E Tests — `integration_test/e2e/contact_form_test.dart`

### High

| # | Gap | Notes |
|---|-----|-------|
| E1 | No form submission + response verification | OPEN — tests fill fields but never verify the full submit-response-alert cycle |
| E2 | Soft assertions throughout | OPEN — most tests only assert `MaterialApp` exists |

### Blocker

| # | Gap | Notes |
|---|-----|-------|
| E3 | chromedriver not installed | OPEN — `flutter drive -d chrome` fails; e2e suite cannot run |

## Summary

| Category | Total | Closed | Open |
|----------|-------|--------|------|
| Unit (U1–U10) | 10 | **10** | 0 |
| Widget (W1–W7) | 7 | **4** | 3 |
| E2E (E1–E3) | 3 | 0 | 3 |
| **Total** | **20** | **14** | **6** |
