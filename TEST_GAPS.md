# Contact Form Test Gaps

Identified 2026-02-25 against `main` (commit `11698dc`).

## Unit Tests — `test/unit/services/contact_service_test.dart`

### High

| # | Gap | Source | Notes |
|---|-----|--------|-------|
| U1 | 504 gateway timeout retry + exhaustion | `contact_service.dart:321-329` | Retryable 504 path and fallback after max retries both untested |
| U2 | Non-Dio exception in `submitForm` | `contact_service.dart:391-397` | General `catch (e, stackTrace)` block never exercised |

### Medium

| # | Gap | Source | Notes |
|---|-----|--------|-------|
| U3 | 429 without Retry-After header | `contact_service.dart:337-339` | Only tested with header present; `seconds == null` branch uncovered |
| U4 | `receiveTimeout` retry path | `contact_service.dart:359-361` | Only `connectionTimeout` tested; `receiveTimeout` and `connectionError` assumed equivalent |
| U5 | Name exceeding `maxNameLength` (100) | `contact_service.dart:183-184` | Length-limit validation tested for companySize/useCase but not name |
| U6 | Email exceeding `maxEmailLength` (254) | `contact_service.dart:190-191` | RFC length cap untested |
| U7 | Organization exceeding `maxOrganizationLength` (200) | `contact_service.dart:197-200` | Only null org tested |
| U8 | Message exceeding `maxMessageLength` (5000) | `contact_service.dart:218-220` | Optional field length cap untested |

### Low

| # | Gap | Source | Notes |
|---|-----|--------|-------|
| U9 | 200 response with `success: false` | `contact_service.dart:351-355` | 400 status tested but 200+success=false is a distinct code path |
| U10 | Success response with null message/submissionId | `contact_service.dart:346-349` | Fallback defaults (`"Thank you..."`, `sub_<timestamp>`) untested |

## Widget Tests — `test/widgets/sections/contact_section_test.dart`

### High

| # | Gap | Source | Notes |
|---|-----|--------|-------|
| W1 | Default `ContactService.submitForm` path | `contact_section.dart:517-553` | All widget tests inject `onFormSubmit`; the real submission branch is never exercised |

### Medium

| # | Gap | Source | Notes |
|---|-----|--------|-------|
| W2 | Form data cleared on success | `contact_section.dart:545` | `_formData.clear()` never verified |
| W3 | Field errors from `ContactFormError.fieldErrors` | `contact_section.dart:549-551` | Server-returned field errors not tested in widget context |

### Low

| # | Gap | Source | Notes |
|---|-----|--------|-------|
| W4 | Facebook Pixel tracking on success | `contact_section.dart:539-543` | Analytics side-effect; verify via mock if desired |
| W5 | Calendly URL internal route (`startsWith('/')`) | `contact_section.dart:404` | Only external URLs tested |
| W6 | `showLiveDemoSection` parameter | `contact_section.dart:34,370` | Default `true` tested implicitly; `false` never tested |
| W7 | `_buildFullName()` with firstName+lastName | `contact_section.dart:456-465` | Indirectly covered by field pairing tests but no explicit assertion on concatenated name |

## E2E Tests — `integration_test/e2e/contact_form_test.dart`

### High

| # | Gap | Notes |
|---|-----|-------|
| E1 | No form submission + response verification | Tests fill fields but never verify the full submit-response-alert cycle |
| E2 | Soft assertions throughout | Most tests only assert `MaterialApp` exists; pass even if contact section fails to render |

### Blocker

| # | Gap | Notes |
|---|-----|-------|
| E3 | chromedriver not installed | `flutter drive -d chrome` fails; e2e suite cannot run |
