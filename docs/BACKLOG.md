# Backlog

Open and deferred items only. Completed items are migrated to `docs/changelog/1.0/CHANGELOG.md`, `docs/changelog/1.1/CHANGELOG.md`, and `docs/changelog/1.2/CHANGELOG.md`.

**Last Updated:** 2026-03-25 | **Phase:** V02 & Health Monitoring Complete; OTEL Implementation (L22-L25) migrated to v1.2 (4 items); 51+ items in v1.2; 1 remaining design-decision item (T28); 1 new performance optimization item added (W01: Valibot migration)

---

## Phase 4 Remaining Items (Substantially Complete)

**Status:** Phase 1–4 substantially complete as of 2026-03-20.

**Completed in this session (2026-03-20 to 2026-03-21):**
- ✅ Sender-Worker UI Implementation — AuthPage, ProvisionPage, SenderHealthPage with JWT flow (commit 9ea6256)
- ✅ Quota Durable Object Integration (T26) — Wire quota checks into API gateway routes with fail-open logic (commits bb1d810, d58f382, 3483538)
- ✅ Quota Integration Tests (T27) — 25 comprehensive tests covering limits, idempotency, plan tiers (commit 6bc3cd8)
- ✅ Security Fixes — JWT issuer validation (V-02, commit 00bfaaf), timing-safe hash comparisons H19 (commit 0f9cece)
- ✅ Code Review — 10+ findings addressed; 6 backlog items marked Done (R02, R04, R07, R08, R09, R10)
- ✅ V02 Dashboard Core Pages — Usage summary page (55c4a86, e066900) + billing status display page (979ab7c, 60fd1ff) with DashboardService
- ✅ V02 Code Review Findings Documented — Backlog items H2, M30-M32, L10-L11, V02-Remaining 5 components (commit 80b288a)
- ✅ Roadmap Updated — V02 status reflects complete core pages + code review findings + remaining work (commits 81d3c24, 7f2e699)
- ✅ H1: Zod Schemas for Stripe Event Payloads — CheckoutSessionSchema, SubscriptionSchema, InvoiceSchema; all `as any` casts replaced with `safeParse` (commit 29a71d1)
- ✅ V02: Quota Visualization — QuotaStatusPage at `/quota` with minute burst + monthly limits, GET /quota/status endpoint (commits 9f93f67, e3ff7f3)
- ✅ V02: Usage Charts — Daily bar chart with quota reference line and threshold coloring, fixed shouldRepaint (commits c78bbf1, 809496a)
- ✅ V02: Entitlements Display — EntitlementsPage at `/entitlements` with auto-generated feature flags (commit 9f93f67)
- ✅ Code Review Cycle — H1 Zod schema findings documented + code review addressing H1/H2/M4 findings (commits fc91224, e3ff7f3)
- ✅ Backlog Updated — V02 quota visualization and entitlements display marked done (commit 52a2d4c)
- ✅ V02: Org Switcher Dashboard Hub — DashboardPage at `/dashboard`, DropdownButton org switcher, nav cards to billing/usage/quota/entitlements, fetchOrgList GET /v1/orgs with retry (commits 91cdae3, 226b568)
- ✅ V02: Real-time Usage Polling — 30s Timer.periodic + WidgetsBindingObserver resume refresh on UsageSummaryPage; in-flight guard prevents overlapping fetches (commits f6581fd, d14280c)

**Remaining for v1 release:**

### V02: Flutter Dashboard UI

**Priority:** P1 | **Estimated:** 10–12 hours

Implement authenticated dashboard with org switching, billing status, usage summaries, and entitlements display:

1. Create dashboard page with org switcher dropdown
2. Display current plan, billing status, next renewal date
3. Show monthly usage vs quota (bar/line chart for metrics)
4. Display feature entitlements grid (enabled/disabled flags)
5. Link to Stripe Customer Portal for billing self-service
6. Add real-time usage polling (refresh every 30s or on focus)
7. Error boundary and loading states for all async operations

**Architecture:**
- Use `provisioning_service.dart` for bootstrap/org context
- Integrate with `GET /v1/orgs/:id/dashboard`, `/v1/orgs/:id/usage/summary`, `/v1/orgs/:id/entitlements`
- Local state: active_org, entitlements, usage_snapshot (cached, TTL 30s)
- Global state: org_list, billing_status (cached, TTL 5min)

**Files to create:**
- `lib/pages/dashboard_page.dart`
- `lib/widgets/sections/dashboard_section.dart`
- `lib/services/dashboard_service.dart` (API client wrapper)

**Status:** ✅ ALL STEPS COMPLETE — Bootstrap flow complete; ✅ org switcher (step 1): `DashboardPage` at `/dashboard`, DropdownButton org switcher + nav cards to all sub-pages (commits 91cdae3, 226b568); ✅ billing status display (step 2): `BillingStatusPage` at `/billing`, plan name + status badge + renewal date, loading/error states, retry (commits 979ab7c, 60fd1ff); ✅ usage summary display (step 3): `UsageSummaryPage` at `/usage`, progress bar + per-metric breakdown (commits 55c4a86, e066900); ✅ usage charts (step 3): `_DailyBarChart` with `CustomPainter`, daily bar chart with quota reference line and threshold coloring (commits c78bbf1, 809496a); ✅ quota visualization (step 3 extended): `QuotaStatusPage` at `/quota`, minute burst + monthly limits with Unlimited label support, plan badge, fail-open DO handling (commits 9f93f67, e3ff7f3); ✅ entitlements display (step 4): `EntitlementsPage` at `/entitlements` with auto-generated feature flags (commit 9f93f67); ✅ Stripe Customer Portal link (step 5): `POST /v1/orgs/:id/billing-portal` with role check (owner/billing_admin), Stripe session creation, `fetchBillingPortalUrl` in DashboardService, "Manage Billing" button on BillingStatusPage (7 tests); ✅ real-time polling (step 6): 30s Timer.periodic + app-resume refresh on UsageSummaryPage, in-flight guard (commits f6581fd, d14280c). Code review findings: 1 H2-V02 latent JWT risk, 3 M-level (M30-M32: telemetry/validation/duplication), 2 L-level (L10-L11: decoration/docs) documented (80b288a).

---

## Deferred: OAuth Security (#8-#10) — ✅ COMPLETE

| Issue | Severity | Status |
|-------|----------|--------|
| #8 OAuth State Validation | CRITICAL | ✅ Done — `OAuthService.validateCallback()` with constant-time compare; CSRF rejection tracked in analytics (commit b957544) |
| #9 PKCE Implementation | CRITICAL | ✅ Done — `OAuthService.buildAuthorizationUrl()` with RFC 7636 S256 challenge; sessionStorage scoped; conditional web/stub exports (commit b957544) |

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

### M18-V01: Mutable JWT Claims (Phase 1 Remediation)

**Severity:** CRITICAL — ✅ FULLY REMEDIATED
**Category:** Security — Access Control Staleness
**File:** `workers/lib/types.zod.ts:39-45` | Commit: `312070b`

JWT tokens from Supabase included mutable billing state claims (`default_org_plan` and `default_org_billing_status`) that reflect values at token issuance time (up to 3600s stale). When these values change via Stripe webhooks, JWT claims remain immutable, violating SOC 2 CC6.1 (system monitoring) and creating stale-read access control vulnerabilities.

**Remediation completed:**
- ✅ Removed both claims from `JWTPayloadSchema` (commit `312070b`)
- ✅ Code already queries fresh values from database (`orgs.ts`)
- ✅ Added `.passthrough()` for backward compatibility with old tokens
- ✅ Supabase Custom Access Token Hook updated via migration `20260326000000_update_custom_access_token_hook.sql` — hook now emits only `org_ids`, `default_org_id`, `default_org_role`
- ✅ Hook enabled in `supabase/config.toml`
- ✅ `TWO_LAYER_AUTH_ARCHITECTURE.md` updated to reflect compliant JWT claims

**Status:** ✅ Complete.

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

## Completed: Content Magic String Extraction (Session 2026-04-02)

### C01: Extract Magic Strings to Named Constants in contact_content.dart ✅ COMPLETE

**Priority:** P2 | **Source:** session 2026-04-02 | **Estimated:** 4 hours
**Status:** ✅ COMPLETE (commits 8ae748f, e8f2b6f)

Migrated all hardcoded strings in `contact_content.dart` to named constants in `ContactContentVariants` for improved maintainability and type-safe test references.

#### Pattern Used: Search-Replace Migration

**Code Pattern:**
- **Mode:** Literal string replacement in Dart files
- **Target:** Hardcoded string values in field definitions, object initializers, and test assertions
- **Replacement:** Reference to `ContactContentVariants.CONSTANT_NAME`
- **Verification:** Updated tests to use `ContactContentVariants.*` references instead of hardcoded strings

**Search-Replace Workflow:**
```dart
// BEFORE: Hardcoded inline
ContactFormFieldContent(
  name: 'firstName',
  label: 'First Name',
  placeholder: 'John',
  type: 'text',
)

// AFTER: Named constants
ContactFormFieldContent(
  name: firstNameFieldName,
  label: firstNameLabel,
  placeholder: firstNamePlaceholder,
  type: textFieldType,
)
```

#### Extracted Constants (27 total)

**Field Names & Labels** (14 constants)
| Constant | Value | Source | Dart Defined | YAML Source |
|----------|-------|--------|--------------|-------------|
| `firstNameFieldName` | `'firstName'` | Form field | ✅ Yes | ✅ `content.yaml:contact.form_fields[0].name` |
| `firstNameLabel` | `'First Name'` | Form field | ✅ Yes | ✅ `content.yaml:contact.form_fields[0].label` |
| `lastNameFieldName` | `'lastName'` | Form field | ✅ Yes | ✅ `content.yaml:contact.form_fields[1].name` |
| `lastNameLabel` | `'Last Name'` | Form field | ✅ Yes | ✅ `content.yaml:contact.form_fields[1].label` |
| `emailFieldName` | `'email'` | Form field | ✅ Yes | ✅ `content.yaml:contact.form_fields[2].name` |
| `emailLabel` | `'Work Email'` | Form field | ✅ Yes | ✅ `content.yaml:contact.form_fields[2].label` |
| `companyFieldName` | `'company'` | Form field | ✅ Yes | ✅ `content.yaml:contact.form_fields[3].name` |
| `companyLabel` | `'Company'` | Form field | ✅ Yes | ✅ `content.yaml:contact.form_fields[3].label` |
| `companySizeFieldName` | `'companySize'` | Form field | ✅ Yes | ✅ `content.yaml:contact.form_fields[4].name` |
| `companySizeLabel` | `'Company Size'` | Form field | ✅ Yes | ✅ `content.yaml:contact.form_fields[4].label` |
| `useCaseFieldName` | `'useCase'` | Form field | ✅ Yes | ✅ `content.yaml:contact.form_fields[5].name` |
| `useCaseLabel` | `'Primary Interest'` | Form field | ✅ Yes | ✅ `content.yaml:contact.form_fields[5].label` |
| `messageFieldName` | `'message'` | Form field | ✅ Yes | ✅ `content.yaml:contact.form_fields[6].name` |
| `messageLabel` | `'Message'` | Form field | ✅ Yes | ✅ `content.yaml:contact.form_fields[6].label` |

**Field Placeholders** (6 constants)
| Constant | Value | Dart Defined | YAML Source |
|----------|-------|--------------|-------------|
| `firstNamePlaceholder` | `'John'` | ✅ Yes | ✅ `content.yaml:contact.form_fields[0].placeholder` |
| `lastNamePlaceholder` | `'Smith'` | ✅ Yes | ✅ `content.yaml:contact.form_fields[1].placeholder` |
| `emailPlaceholder` | `'john@company.com'` | ✅ Yes | ✅ `content.yaml:contact.form_fields[2].placeholder` |
| `companyPlaceholder` | `'Acme Inc.'` | ✅ Yes | ✅ `content.yaml:contact.form_fields[3].placeholder` |
| `selectPlaceholder` | `'Select...'` | ✅ Yes | ✅ `content.yaml:contact.form_fields[4-5].placeholder` |
| `messagePlaceholder` | `'Tell us about your AI observability needs...'` | ✅ Yes | ✅ `content.yaml:contact.form_fields[6].placeholder` |

**Field Types** (4 constants)
| Constant | Value | Dart Defined | YAML Source |
|----------|-------|--------------|-------------|
| `textFieldType` | `'text'` | ✅ Yes | ✅ `content.yaml:contact.form_fields[0,1,3].type` |
| `emailFieldType` | `'email'` | ✅ Yes | ✅ `content.yaml:contact.form_fields[2].type` |
| `selectFieldType` | `'select'` | ✅ Yes | ✅ `content.yaml:contact.form_fields[4,5].type` |
| `textareaFieldType` | `'textarea'` | ✅ Yes | ✅ `content.yaml:contact.form_fields[6].type` |

**Field Options Arrays** (2 constants)
| Constant | Items | Dart Defined | YAML Source |
|----------|-------|--------------|-------------|
| `companySizeOptions` | `['1-10 employees', '11-50 employees', '51-200 employees', '201-1,000 employees', '1,000+ employees']` | ✅ Yes | ✅ `content.yaml:contact.form_fields[4].options` |
| `useCaseOptions` | `['LLM Monitoring & Cost Tracking', 'Agent Observability', 'EU AI Act Compliance', 'General AI Observability', 'Enterprise Evaluation', 'Partnership Inquiry']` | ✅ Yes | ✅ `content.yaml:contact.form_fields[5].options` |

**Contact Method Labels** (6 constants)
| Constant | Value | Dart Defined | YAML Source |
|----------|-------|--------------|-------------|
| `emailMethodLabel` | `'Email'` | ✅ Yes | ✅ `content.yaml:contact.contact_methods[0].label` |
| `scheduleADemoMethodLabel` | `'Schedule a Demo'` | ✅ Yes | ✅ `content.yaml:contact.contact_methods[1].label` |
| `phoneMethodLabel` | `'Phone'` | ✅ Yes | ✅ `content.yaml:contact.contact_methods[2].label` |
| `locationMethodLabel` | `'Location'` | ✅ Yes | ✅ `content.yaml:contact.contact_methods[3].label` |
| `linkedinMethodLabel` | `'LinkedIn'` | ✅ Yes | ✅ `content.yaml:contact.contact_methods[4].label` |
| `githubMethodLabel` | `'GitHub'` | ✅ Yes | ✅ `content.yaml:contact.contact_methods[5].label` |

**Contact Method Values** (3 constants)
| Constant | Value | Dart Defined | YAML Source |
|----------|-------|--------------|-------------|
| `scheduleADemoMethodValue` | `'Book a 15-minute call'` | ✅ Yes | ✅ `content.yaml:contact.contact_methods[1].value` |
| `linkedinMethodValue` | `'Follow us'` | ✅ Yes | ✅ `content.yaml:contact.contact_methods[4].value` |
| `githubMethodValue` | `'integritystudio'` | ✅ Yes | ✅ `content.yaml:contact.contact_methods[5].value` |

**Content Page Strings** (4 constants)
| Constant | Value | Dart Defined | YAML Source |
|----------|-------|--------------|-------------|
| `sectionId` | `'contact'` | ✅ Yes | ✅ `content.yaml:contact.section_id` |
| `contentTitle` | `'Get in Touch'` | ✅ Yes | ✅ `content.yaml:contact.title` |
| `contentSubtitle` | `"Let's discuss how we can help"` | ✅ Yes | ✅ `content.yaml:contact.subtitle` |
| `contentDescription` | `"Whether you're evaluating..."` | ✅ Yes | ✅ `content.yaml:contact.description` |

#### Files Modified

**1. lib/config/content/contact_content.dart** (138 lines changed)
- Added 27 new named constants to `ContactContentVariants` class
- Updated `_formFields` array: 7 field definitions now reference placeholders, types, and options constants
- Updated `_contactMethods` array: 6 method definitions now reference label and value constants
- Updated `current` property: uses `sectionId`, `contentTitle`, `contentSubtitle`, `contentDescription` constants

**2. test/config/contact_content_test.dart** (204 → 373 lines, +169 lines)
- Updated 5 existing tests to reference constants instead of hardcoded strings:
  - `sectionId is contact` → uses `ContactContentVariants.sectionId`
  - Contact methods tests → use `emailMethodLabel`, `scheduleADemoMethodLabel` constants
  - Field type tests → use `emailFieldType`, `textareaFieldType` constants
- Added 44 new verification tests (11 new test groups):
  - `field placeholders` group (6 tests)
  - `field types` group (4 tests)
  - `field options` group (2 tests)
  - `contact method labels and values` group (9 tests)
  - `content strings` group (4 tests)
  - `field placeholders match constants` group (7 tests)
  - `field types match constants` group (7 tests)
  - `field options match constants` group (2 tests)

#### Test Coverage

- **Total tests added:** 62 tests (38 original + 24 new)
- **All tests passing:** ✅ 100/100 tests PASS
- **Test strategy:** Each constant verified for non-empty existence + matched against actual field/method definitions
- **Command:** `flutter test test/config/contact_content_test.dart`

#### Important: Hardcoded Constants Require Manual Sync

**ContactContentVariants constants are NOT dynamically loaded from YAML.**

Each constant (e.g., `firstNameLabel = 'First Name'`) is hardcoded in Dart source. This enables:
- Type-safe constant references in production code and tests
- Compile-time typo detection
- Zero-cost abstraction (no runtime lookups)

**Trade-off:** Constants must be manually kept in sync with `content.yaml`. This is enforced via verification tests (below) that confirm each constant value matches the corresponding field in loaded YAML. If YAML is updated, tests will fail and force the Dart constants to be updated.

#### Verification Strategy

Each constant is verified via two test types:

1. **Constant Existence Test** (e.g., "firstNamePlaceholder is non-empty")
   ```dart
   test('firstNamePlaceholder is non-empty', () {
     expect(ContactContentVariants.firstNamePlaceholder, isNotEmpty);
   });
   ```

2. **Constant Match Test** (e.g., "firstName placeholder matches constant")
   ```dart
   test('firstName placeholder matches constant', () {
     final field = fields.firstWhere((f) => f.name == ContactContentVariants.firstNameFieldName);
     expect(field.placeholder, equals(ContactContentVariants.firstNamePlaceholder));
   });
   ```

#### Architecture Notes

**ContentLoader Loading Model**
- **NOT lazy-loaded:** Entire `content.yaml` loaded upfront via explicit `ContentLoader.load()` call (typically in `main.dart`)
- **Concurrent call safety:** Multiple calls to `load()` await same `Completer` — only one `rootBundle.loadString()` issued
- **Caching:** Results cached in `_mapCache`, `_listCache`, etc. to avoid YamlMap deep-copies on every property access during Flutter builds
- **Constraint:** All `ContentLoader.*` getters throw `StateError` if called before `load()` completes
- **Pattern:** App initialization must ensure `await ContentLoader.load()` before accessing any content

**Why Dart Constants in Contact Model?**
- **Type safety:** Dart compiler enforces constant references; typos caught at build time
- **Test reference:** Tests use the same constants as the production code, eliminating string duplication
- **Single source of truth:** Field names, labels, types defined once in model, used everywhere
- **YAML source:** Values originate from `content.yaml`, loaded via explicit `ContentLoader.load()` call (NOT lazy-loaded). Constants are hardcoded in Dart source and must be kept in sync with YAML via verification tests

**YAML → Dart Flow:**
1. App startup: `ContentLoader.load()` called explicitly (typically in `main.dart`), reads `content.yaml` via `rootBundle.loadString()`
   - Loads entire YAML once upfront (NOT lazy-loaded per-property)
   - Concurrent calls to `load()` await the same `Completer` — only one asset read
   - Throws `ContentLoadException` if asset missing or parse fails
2. Caching: Results cached in `_mapCache`, `_listCache`, `_stringListCache`, `_stringMapCache`
   - Avoids repeated YamlMap deep-copies during Flutter build cycles
   - Cache cleared on `reset()` (for testing) or next `load()`
3. `ContentLoader.* getters` (e.g., `ContentLoader.contactTitle`) retrieve cached values from loaded YAML
4. `ContactContentVariants` constants defined in Dart source as named static consts
   - Reference same source values from YAML (values must match)
   - Enable type-safe references in tests and production code
   - Compiler enforces constant refs; typos caught at build time
5. `AppContent.contact` property creates fresh `ContactContent` instance using `ContentLoader` getters at runtime
   - Both `ContactVariants` constants AND `AppContent` values reference same YAML source

**Key architectural note:** `ContactContentVariants` constants are NOT dynamically loaded from YAML; they are hardcoded in Dart source with values matching the YAML file. This enables type-safe test assertions like `expect(field.label, equals(ContactContentVariants.firstNameLabel))` without string duplication. To keep constants in sync with YAML, verification tests confirm each constant matches its field in the loaded content (see "Verification Strategy" section above).

#### Future Migration Targets (Similar Pattern)

Apply same extraction pattern to other content files:

| File | Constants to Extract | Test File | Reuse Opportunity |
|------|---------------------|-----------|-------------------|
| `pricing_content.dart` | Tier names ('Starter', 'Team', 'Enterprise') × 2 variants | `pricing_content_test.dart` | **HIGH** — duplicated in `current` & `legacy` |
| `features_content.dart` | Feature titles (6 items) × 2 variants | `features_content_test.dart` | **HIGH** — duplicated in `_currentFeatures` & `_legacyFeatures` |
| `footer_content.dart` | Link group titles & labels (6+ items) | `footer_content_test.dart` | **MEDIUM** — used once but referenced in tests |
| `status_content.dart` | Metric labels & service names (8 items) | `status_content_test.dart` | **MEDIUM** — hardcoded in object initializers |
| `hero_content.dart` | Headlines & badges (4 variants × 3 versions) | `hero_content_test.dart` | **MEDIUM** — A/B test variants |

**Recommendation:** Apply to `pricing_content.dart` next (eliminates duplication between `current` and `legacy` variants).

---

## Open Items

## Payment Processor Security Remediation

Deferred security hardening for the two-layer authentication and billing system. Findings documented in `docs/security/SECURITY_VULNERABILITY_REPORT.md` and `docs/reports/JWT_COMPLIANCE_REVIEW.md`.

**Completed this session:**
- ✅ V-06: `nbf` claim validation with `NBF_CLOCK_SKEW_SECONDS` constant (commit 3f593b9)
- ✅ V-18: `aud` claim validation; explicit typed fields on `JwtPayload` (commit 3f593b9)
- ✅ V-22: `X-Content-Type-Options: nosniff` + `Cache-Control: no-store` on all api-gateway and sender-worker responses (commit 30d990f)
- ✅ T28 (code): `blockConcurrencyWhile` cold-start guard + durability SLA documented (commit 6251629)
- ✅ Enterprise Stripe checkout: enterprise signup now creates Auth0 account + Supabase org; routes to `/checkout`; graceful fallback to `/request_success` when no Stripe price configured (commit f14ba4a)

---

### T28: Handle Persistent Storage Data Loss Risk in Quota DO

**Priority:** P3 | **Source:** session 2026-03-20, quota commit review (523518f)
**Estimated:** 2–3 hours

Quota state is lazily persisted to Durable Object storage every 10 seconds (`workers/api-gateway/src/durable-objects/quota.ts:174–177`). If the DO crashes or is evicted between saves, up to 10 seconds of quota usage is lost (counts are dropped, monthly counter reverts).

**Scope:**
1. Evaluate risk appetite: Is 10-second data loss acceptable for quota tracking? (likely yes for low-tier plans, needs confirmation)
2. If higher durability is required:
   - Change save interval to synchronous: save immediately after every reservation (impacts latency)
   - OR batch saves: write to Durable Object every 100 requests OR 5 seconds (hybrid approach)
   - OR implement eventual consistency mode: accept up-to-10s drift, document in API contract
3. Document the chosen strategy in `workers/docs/QUOTA_DURABLE_OBJECTS.md` with:
   - Data consistency SLA
   - Acceptable loss window
   - When DO eviction is expected (low-traffic orgs evicted after 15 min idle)
4. Add monitoring: Cloudflare Durable Object metrics dashboard to track eviction rate

**Files to modify:**
- `workers/api-gateway/src/durable-objects/quota.ts` — Adjust save strategy (if needed)
- `workers/docs/QUOTA_DURABLE_OBJECTS.md` — Document durability guarantees and trade-offs

**Status:** Deferred — Documented but requires risk/latency trade-off decision and monitoring setup.

---

## Performance: Migrate Cloudflare Workers Validation from Zod to Valibot

### W01: Replace Zod with Valibot for Edge Function Validation

**Priority:** P2 | **Source:** session 2026-03-25, performance analysis
**Estimated:** 4–6 hours
**Context:** `functions/src/` Cloudflare Workers use Zod for validation. Valibot is significantly faster and smaller for edge functions.

**Analysis:** See `docs/VALIBOT_ANALYSIS.md` for full comparison. Key findings:
- **Bundle size:** Valibot 1.91 KB vs Zod 16.57 KB (90% reduction)
- **Startup:** Valibot 54 μs vs Zod ~864 μs (16x faster cold starts)
- **Impact:** Every KB shipped globally to edge datacenters; smaller bundle = faster parsing = lower CPU milliseconds billed
- **Trade-off:** Valibot slower on invalid data (exception-based), but Zod remains better for server-side Node.js (keep in api-gateway)

**Scope:**
1. Audit validation schemas in `functions/src/` — identify all Zod usage
2. Migrate schemas to Valibot API (mostly 1:1 mapping)
3. Update type exports: `z.infer<typeof S>` → `v.infer<typeof S>`
4. Benchmark with Wrangler: measure bundle size reduction and cold start improvement
5. Update `functions/package.json` to add Valibot + remove Zod dependency (if not shared with api-gateway)
6. Run `npm test` in functions/ directory to verify no regressions
7. Document in `functions/MIGRATION.md` if Valibot is adopted long-term

**Files to modify:**
- `functions/src/` (all validation schemas)
- `functions/package.json` (add valibot dependency)
- `functions/tsconfig.json` (if needed for types)

**Decision point:** Should api-gateway continue using Zod (server-side, better ecosystem) while functions/ uses Valibot (edge, better perf)?
- **Recommendation:** Yes — different contexts. Keep Zod in api-gateway (Node.js), migrate functions/ to Valibot (edge).

**Files to check:**
- `functions/src/_middleware.ts` — entry point; check if validates requests
- `functions/src/` — all TypeScript files for `z.` references

**Status:** Open — awaiting implementation. Analysis completed and documented in `docs/VALIBOT_ANALYSIS.md`.

---

## W02: Receiver CI deploy — target the correct Cloudflare account for `/memberships`

**Priority:** P1 | **Source:** session 2026-06-26, receiver CI deploy investigation
**Estimated:** 1–2 hours
**Reference commit:** d3f001d (`docs(claude): document worker deployment strategy and Doppler config`)

**Context:** The `api-provisioning-receiver` deploy job (in `integritystudio/observability-toolkit`, `.github/workflows/api-provisioning-receiver-test.yml`) fails on every push to `main` with:

```
✘ A request to the Cloudflare API (/memberships) failed.
  Authentication failed (status: 400) [code: 9106]
```

Root cause: the deploy step only exports `CLOUDFLARE_API_TOKEN` (from Doppler `CLOUDFLARE_WORKER_TOKEN`). With no account id set, wrangler calls `/memberships` to auto-discover the account, but the scoped Workers token cannot read `/memberships`, so it 400s. Verified: the same token returns 200 against `accounts/<id>/workers/scripts`, and 9106 against `/memberships`.

**Problem to resolve:** The interim fix exports the **doppler-stored `CLOUDFLARE_ACCOUNT_ID`** so wrangler skips `/memberships`. That value should not be trusted blindly — confirm it is the correct **Integrity Studio Cloudflare account id** (the account that owns `api-provisioning-receiver`), and pass that explicitly rather than relying on whatever happens to be stored in Doppler.

**Scope:**
1. Confirm the canonical Integrity Studio Cloudflare account id (the one owning the deployed `sender-worker` / `api-provisioning-receiver`).
2. Verify `CLOUDFLARE_ACCOUNT_ID` in Doppler `integrity-studio/prd` matches that account id; correct it if it diverges.
3. Pin the account in the deploy step (export `CLOUDFLARE_ACCOUNT_ID`, or set `account_id` in `wrangler.toml`) so wrangler never falls back to the `/memberships` discovery call.
4. Re-deploy from `main` and confirm the deploy job is green and `modified_on` updates in Cloudflare.

**Files to modify:**
- `observability-toolkit/.github/workflows/api-provisioning-receiver-test.yml` (deploy step)
- Optionally `observability-toolkit/services/api-provisioning-receiver/wrangler.toml` (pin `account_id`)

**Status:** Open — root cause confirmed; awaiting account-id verification and CI fix. (Receiver source itself is current in prod via a manual `wrangler deploy` this session.)

---

## W03: Reconcile stale `receiver-worker` references in provisioning docs

**Priority:** P2 | **Source:** session 2026-06-26, docs audit for `receiver-worker`
**Estimated:** 2–3 hours

**Context:** `workers/receiver-worker/` is a **local stub / test double**; its deployed Cloudflare instance was deleted this session (orphan — nothing bound to it). The production receiver is **`api-provisioning-receiver`** (separate `observability-toolkit` repo), reached by `sender-worker` via a service binding, not an HTTP URL. The critical doc references that would mislead a reader into deploying or wiring the dead stub were already fixed and committed this session (`CLAUDE.md` deployment table + architecture lines, `workers/receiver-worker/README.md` banner, warning banners on `docs/provisioning-environment-setup.md` and `docs/PROVISIONING_SETUP_SUMMARY.md`).

**Remaining (medium) — docs that describe the stub as if it were production; warned but not yet rewritten:**
1. ✅ `docs/provisioning-environment-setup.md` — misleading sections already removed; banner finalized (W03-pending pointer dropped).
2. ✅ `docs/PROVISIONING_SETUP_SUMMARY.md` — obsolete `RECEIVER_WORKER_URL` / `receiver-worker.integritystudio.ai` config + deploy/curl blocks annotated with the current service-binding model; "service bindings" future-work items marked done.
3. ✅ `docs/inter-worker-contract-validation.md` — added "what this validates" banner (local stub vs production); deploy checklist + config matrix rewritten to the `RECEIVER` service binding; pointer to `observability-toolkit` for production contract validation.
4. ✅ `docs/payments-integration-wire.md` — `inboxPayloadSchema` location corrected to `api-provisioning-receiver`; receiver refs + error table updated to the service-binding model.
5. ✅ `docs/api-provisioning.md` — health-response example now `{ service: "api-provisioning-receiver" }`; added receiver-identity/service-binding note; impl-status receiver path clarified.
6. ✅ `PROVISIONING_E2E_RESULTS.md` and `PROVISIONING_MANUAL_TEST.md` — deprecation banners added (local-stub only); point to `observability-toolkit` integration tests for production.
7. ✅ `docs/user-provisioning-workflow.md` — 2 refs updated to `api-provisioning-receiver` (+ "via service binding"). `docs/REFACTOR.md` — verified: its 2 refs describe the in-repo stub source dir for a Zod validation refactor, which is accurate; left as-is.

**Not in scope (correct, leave as-is):** `README.md` / `package.json` lint+test loops, `CLAUDE.md` dir tree, `workers/receiver-worker/wrangler.toml` name, `docs/changelog/1.2/CHANGELOG.md`, `workers/lib/TYPES.md`, `.serena/memories/*` — these correctly reference the local stub source or historical changelog.

**Status:** ✅ Done (2026-06-26) — all medium doc rewrites complete; provisioning docs reconciled to the service-binding model (`sender-worker` → `api-provisioning-receiver`). See also [[W02]] (receiver CI deploy).

---

## W04: Provisioning workers — monitoring, alerting & dashboards

**Priority:** P2 | **Source:** session 2026-06-27, reconciled from `docs/PROVISIONING_SETUP_SUMMARY.md` open items ("Monitoring and alerting — must implement", "Monitoring Dashboards — Cloudflare Analytics")
**Estimated:** 4–6 hours

**Context:** `sender-worker` has `[observability.logs]` with `invocation_logs = true` (`workers/sender-worker/wrangler.toml`), so logs are captured, but there is **no alerting and no dashboard** for the provisioning path (`sender-worker` → `api-provisioning-receiver`). The setup summary flagged this as "must implement" but it was never tracked as a real item. `api-provisioning-receiver` lives in the `observability-toolkit` repo, so end-to-end provisioning observability spans both repos.

**Scope:**
1. Define the signals that matter: `/send` error rate (esp. 502 "receiver-worker unreachable", 500 `INTERNAL_ERROR`), receiver 401s (signature/replay failures — possible attack or key-rotation drift), provisioning latency, Auth0/Supabase call failures.
2. Stand up a dashboard (Cloudflare Workers Analytics, or route through the existing OTEL pipeline — see `ingest.integritystudio.ai` / `observability-toolkit`) covering sender + receiver.
3. Add alerting on error-rate and 401-spike thresholds (channel/owner TBD).
4. Document the dashboard + alert runbook; cross-link from `docs/api-provisioning.md`.

**Notes / overlap:**
- [[T28]] already calls for a Cloudflare Durable Object metrics dashboard for quota eviction — narrower, but fold into the same dashboard effort if convenient.
- Receiver-side instrumentation belongs in `observability-toolkit`; coordinate across repos.

**Files to touch:**
- `workers/sender-worker/wrangler.toml` (if exporting metrics/OTEL beyond logs)
- `docs/api-provisioning.md` (link runbook)
- `observability-toolkit` (receiver-side spans/metrics)

**Status:** Open — reconciled from setup-summary intentions; needs signal definition + alert-channel decision. See also [[T28]].

---

## W05: Verify & document prod secret durability + rotation cadence under Doppler

**Priority:** P3 | **Source:** session 2026-06-27, reconciled from `docs/PROVISIONING_SETUP_SUMMARY.md` open items ("Secrets backed up (1Password/Vault) — must implement", "Secret rotation documented (quarterly)")
**Estimated:** 1–2 hours

**Context:** The setup summary's "back up secrets to 1Password/Vault" action predates the move to **Doppler** as the managed secret store (`doppler --project integrity-studio --config dev|prd`, used by every worker's `deploy:prd` script and CI). Doppler is now the system of record for worker secrets, which largely supersedes a manual vault backup. This item reconciles the stale intention rather than implementing 1Password.

**Scope:**
1. Confirm Doppler `integrity-studio/prd` holds the canonical copy of all provisioning secrets (`SHARED_SECRET`, `SIGNING_KEYS`/`ACTIVE_KEY_ID`, `AUTH0_*`, `SUPABASE_*`, `STRIPE_*`) and that Doppler's own retention/backup is acceptable as the durability story.
2. Document whether an additional offline backup (1Password/Vault) is still required by policy, or formally accept Doppler as sufficient.
3. Document the secret-rotation cadence and procedure. **Note:** the rotation *mechanism* is already implemented and documented in code (`SIGNING_KEYS` + `ACTIVE_KEY_ID` + `x-key-id`, procedure in `workers/sender-worker/src/index.ts:150-158`) — this item is the operational policy/cadence, not new code.

**Files to touch:**
- `docs/provisioning-environment-setup.md` (secret durability + rotation cadence)
- `CLAUDE.md` "Secret Rotation" section (confirm/expand)

**Status:** Open — verification + documentation only; key-rotation mechanism already shipped. See also [[W02]] (Doppler-stored `CLOUDFLARE_ACCOUNT_ID`).

---


*Last updated: 2026-03-21 — backlog-implementer + backlog-migrate + auto-error-resolver session: L6/L7/L10/L11/L12/L13 marked done (38c339c); M36 fixed (7d86372); L5 env binding added (5c7a443, 8cdaa09, 306ccfc); 27 items migrated to v1.2; CSP test failure diagnosed and fixed (47b4dc3); L16 + M37 migrated to v1.2 changelog (2 completed items). Test Status: ✅ ALL 2631 TESTS PASSING. Remaining: T25, T28, V02-Remaining, M34, M38, M39 (6 deferred/design-decision items). Score: 9/10.*

*Backlog-implementer continuation (2026-03-21): L16 refactored (AppDecorations.card() 5786939, PASS); M34 fixed with soft-delete + active-only filter (33aa1a2, cf5059c, PASS); M37 verified done (no new commits). Test Status: ✅ 61 stripe-webhook tests passing. Remaining open items: 4 (T25, T28, M38, M39 require design decisions). Items completed: 2 (L16, M34). Score: 9/10.*

*Backlog-implementer session (2026-03-21): H3 DB filter fix (b2d23fe, PASS); H4 stripe_customer_id validation (162983d, PASS); M40 audit log waitUntil (8f999e6, PASS); M41 APP_URL env escalation (826d2f3, PASS); M42 503 retry + test fix (8b6120f, 51f8ad8, PASS); L20 error sanitization (32ee699, PASS); L21 insert call count assertion (32ee699, PASS); L22 billing_admin audit log count (user-applied); L23 sanitize read endpoint errors + fetchOrgList (15da535, c586ee8, 2ece18a, PASS). Test Status: ✅ 35 Dart + 17 TS tests passing. Items completed: 9. Remaining: T25, T28, M18 (design decisions / external deps). Score: 9/10.*

*Backlog-implementer session (2026-03-21): OTEL-1 POST /v1/ingest/otel implemented — OtelSpanSchema, IngestOtelRequestSchema, handleIngestOtel with API-key auth + quota enforcement + attribute size caps (1b771e3, c40a1c8, PASS); 10 new tests. Payments roadmap "Telemetry/monitoring setup" item DONE. Test Status: ✅ 120 api-gateway tests passing. Items completed: 1. Remaining: T28 (design decision). Score: 9/10.*

*Backlog-implementer session (2026-03-21): L23 rate-limit headers forwarded (e743c68, PASS); L25 OTEL_INGEST_ROUTE exported (2aa30eb, PASS); L24 start_time_ms upper bound refine (32658b9, PASS); L22 makeOpts typed as SupabaseClient|undefined (ce4c563, PASS); final review high finding addressed — applyRateLimitHeaders helper + boundary tests (5e5d2c4). Test Status: ✅ 122 api-gateway tests passing. Items completed: 4 (L22-L25). Remaining: T28 (design decision). Score: 10/10.*
