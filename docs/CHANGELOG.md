# Changelog

All notable changes to the IntegrityStudio.ai Flutter project.

---

## [2026-02-01] - Routing Consolidation & Twitter/X Removal

### Routing Documentation Consolidation

- Created `docs/routes.md` - comprehensive routing architecture document
  - GoRouter + ShellRoute pattern explanation
  - All 27 routes organized by category
  - Cookie banner pattern documentation
  - Deep linking configuration
- Consolidated README.md Route Status section (65 lines → 5 lines)
- `6912ae7` docs: consolidate routing documentation into docs/routes.md

### Demo Routing Consolidation

- All demo/CTA buttons now route to internal `/demo` page instead of external Calendly links
- Updated: contact_page, about_page, landing_page, signup_page
- Fixed contact form worker URL and CSP configuration
- `dadc9d5` feat(nav): route all demo buttons to /demo page
- `e24c704` fix(contact): use existing worker URL and update CSP to match

### Twitter/X Branding Removal

- Removed all Twitter/X references from codebase
- Social links now use LinkedIn and GitHub only
- Updated JSON-LD schema and test fixtures
- Enhanced schema.org structured data
- `54517f8` chore: remove Twitter/X branding and enhance JSON-LD schema
- `dc64fd4` fix(test): remove X/Twitter references from test fixtures
- `812529a` test(contact): update tests for X/Twitter removal

### Blog Updates

- Added EU AI Act enterprise guide cross-post
- Added internal cross-links between blog posts
- Standardized blog footers
- Fixed blog post ordering (newest first)
- `8548407` feat(blog): add EU AI Act enterprise guide cross-post
- `79c4a79` docs(blog): add internal cross-links and standardize footers

---

## [2026-01-31] - Test Optimization & Social Migration

### Test Performance Optimization

- Page test runtime reduced: 144s → 51s (65% improvement)
- Added semantic labels for direct widget access without scrolling
- Removed duplicate navigation tests (exist in integration suite)
- `2fe6cc1` perf(tests): add semantic labels and remove duplicate nav tests

### Test Anti-Patterns Remediation

Removed widget type assertions testing implementation details:

| File | Tests Removed |
|------|---------------|
| docs_alerts_page_test.dart | `find.byType(Table)` assertion |
| comparison_page_test.dart | `find.byType(DataTable)` assertion |
| docs_interoperability_page_test.dart | 7 redundant widget type tests |
| docs_observability_page_test.dart | 6 tests (entire doc components group) |
| signup_page_test.dart | 2 tests (back button, Wrap widget) |

- Page tests: 705 → 690
- `809bab1` refactor(tests): remove widget type assertions testing implementation details

### ContentLoader Test Consolidation

| Metric | Before | After | Change |
|--------|--------|-------|--------|
| content_loader_test.dart | 747 lines | 387 lines | -48% |
| test_content.dart | 476 lines | 724 lines | +248 |
| Combined | 1,223 lines | 1,111 lines | -9% |

- Extracted test YAML to `contentLoaderTestYaml` constant
- Added shared `setUpContentLoaderTest()` / `tearDownContentLoaderTest()` helpers
- Removed 6 weak type assertion tests
- Fixed 3 conditional tests with proper setUp/tearDown
- Simplified API surface verification (127 → 50 lines)
- `08f30f2` refactor(test): consolidate content_loader_test.dart

### Twitter to X Migration

- Migrated all Twitter branding to X platform branding
- Updated social links, icons, and references
- `5bf13d4` refactor(social): complete Twitter to X migration
- `c1ae24a` refactor(social): migrate Twitter branding to X

### Blog & Content Updates

- Added LLM cost optimization guide to blog listing
- Blog posts now ordered by publish date (newest first)
- Rewrote EU AI Act article for non-technical audience
- Reduced content.yaml caching to 1 hour
- `293b29d` feat(blog): add LLM cost optimization guide to blog listing
- `92e5207` fix(blog): order posts by publish date (newest first)
- `af8ff95` refactor(blog): rewrite EU AI Act article for non-technical audience
- `24db399` fix(cache): reduce content.yaml caching to 1 hour

---

## [2026-01-30] - CI Fix & Section Test Consolidation

### CI Failure Fix

- Fixed 11 unused `test_helpers.dart` imports blocking deployment
- Root cause: Previous test consolidation removed usage but left imports
- `2d62bdf` fix(test): remove unused test_helpers imports

### Section Test Consolidation

| File | Before | After | Reduction |
|------|--------|-------|-----------|
| services_section_test.dart | 107 lines | 67 lines | 37% |
| resources_section_test.dart | 145 lines | 130 lines | 10% |
| about_section_test.dart | 114 lines | 92 lines | 19% |
| **Total** | **366 lines** | **289 lines** | **21%** |

- Replaced local `buildTestWidget()` with shared `testableSection()`
- Replaced local `setLargeViewport()` with shared `setScreenSize()`
- Added `pumpAndSettle()` calls for proper widget initialization

### RenderFlex Overflow Fixes

- Fixed RenderFlex overflow errors at narrow viewports
- Added `Flexible` wrappers and `TextOverflow.ellipsis` to app bar titles
- Fixed pages: contact_page, pricing_page, careers_page, landing_page
- Added test helpers: `isOverflowError()`, `clearOverflowExceptions()`, `pumpFrames()`

---

## [2026-01-29] - Major Refactoring Sprint

### Theme Test Consolidation

| File | Before | After | Reduction |
|------|--------|-------|-----------|
| colors_test.dart | 262 lines | 156 lines | 40% |
| spacing_test.dart | 596 lines | 442 lines | 26% |
| typography_test.dart | 397 lines | 301 lines | 24% |
| theme_test.dart | 215 lines | 0 (deleted) | 100% |
| **Total** | **1,785 lines** | **1,214 lines** | **32%** |

- Applied Dart 3 records for table-driven tests: `<String, (Color, int)>{}`
- Deleted duplicate theme_test.dart
- `ba3b0e4` refactor(test): consolidate theme tests with table-driven patterns

### Widget Test Consolidation (5 Sessions)

**Final Results (11 files):**

| File | Before | After | Reduction |
|------|--------|-------|-----------|
| contact_section_test.dart | 70 | 33 | 53% |
| cookie_banner_test.dart | 44 | 21 | 52% |
| form_fields_test.dart | 36 | 15 | 58% |
| doc_components_test.dart | 36 | 9 | 75% |
| buttons_test.dart | 28 | 7 | 75% |
| cards_test.dart | 26 | 7 | 73% |
| alert_test.dart | 25 | 10 | 60% |
| containers_test.dart | 26 | 6 | 77% |
| tabbed_features_section_test.dart | 21 | 9 | 57% |
| footer_section_test.dart | 20 | 7 | 65% |
| pricing_section_test.dart | 19 | 6 | 68% |
| **Grand Total** | **351** | **130** | **63%** |

Key patterns applied:
- Reusable helpers: `buildBanner()`, `pumpBannerAndWait()`
- Combined rendering tests: 6 separate "renders X" → 1 comprehensive test
- Loop-based variant testing using Dart 3 records
- GlassCard: Loop over `GlassCardTier.values`

Commits:
- `52a2333` refactor(test): consolidate contact section tests
- `eda637a` refactor(test): consolidate cookie banner tests
- `e4b18af` refactor(test): consolidate form fields tests
- `0e3ef88` refactor(test): consolidate doc components tests
- `e4c06a6` refactor(test): consolidate common widget tests
- `b4e3f5b` refactor(test): consolidate remaining widget tests

### Page Test Consolidation

**Priority 1 - Overflow Error Helpers:**
- Added to test_helpers.dart: `isOverflowError()`, `clearOverflowExceptions()`, `setUpOverflowErrorSuppression()`, `tearDownOverflowErrorSuppression()`
- Net reduction: -151 lines across 11 page test files
- `00fffa3` refactor(test): consolidate overflow error suppression across page tests

**Priority 3 - Standard Test Patterns:**
- Added helpers: `testPageStructure()`, `testBackButtonCallback()`, `testBackButtonCallbacks()`, `testResponsiveLayout<T>()`
- Net reduction: -343 lines across 12 page test files
- `6b19ab2` refactor(test): consolidate standard page test patterns

**Cumulative:** -494 lines removed from page tests

### Navigation Refactor (GoRouter Migration)

| Metric | Before | After |
|--------|--------|-------|
| Lines in app.dart | ~510 | 79 |
| Lines per new route | ~15 | ~6 |
| Route definitions | Scattered | Centralized in app_router.dart |
| Cookie banner | Repeated per route | Single ShellRoute wrapper |

- Replaced all `Navigator.pushNamed`/`pop` with `context.go()` for proper SPA behavior
- Added `cookieBannerNotifier` (ValueNotifier) for banner state without router recreation
- Fixed Navigator.pop() causing full app refresh

Commits:
- `d0c92c1` refactor(routing): migrate Navigator to GoRouter across all pages
- `d3049dd` fix(nav): use GoRouter context.go() instead of Navigator.pop()
- `192dbea` fix(routing): prevent router recreation from resetting navigation
- `5b2a392` fix(nav): migrate all Navigator.pushNamed to GoRouter context.go

### New Documentation Pages

- `/help-center` - FAQ and support options (`743fc8d`)
- `/docs/agents` - AI agents observability documentation (`65657f1`)
- `/api/toolkit` - API toolkit and SDK documentation (`65657f1`)
- `/compliance` - Compliance and governance features (`65657f1`)
- `/support` now redirects to `/help-center` (`f44be63`)

### Test Coverage Improvement Sprint

**Overall: 92.1% → 94.0%** (+250 tests, 1933 total)

| File | Before | After | Change |
|------|--------|-------|--------|
| `consent_manager.dart` | 35.5% | 93.0% | +57.5% |
| `landing_controller.dart` | 70.0% | 100% | +30.0% |
| `app_router.dart` | 74.4% | 100% | +25.6% |
| `landing_page.dart` | 69.6% | 94.2% | +24.6% |
| `contact_section.dart` | 67.3% | 87.8% | +20.5% |

**ConsentManager Dependency Injection:**
- Added interfaces: `ConsentStorage`, `PlatformCheck`, `TrackingService`, `AnalyticsAdapter`
- Added `configureDependencies()` / `resetDependencies()` for test mocking
- `63d1a26` test: update consent tests to use cookieBannerNotifier API

---

## [2026-01-28] - Security Page & Contact Improvements

### New Features

**Security Page (`/security`):**
- Converted static `security.html` to Flutter page with consistent styling
- Added enterprise security sections:
  - Our Security Commitment (stats overview)
  - Authentication Security (OAuth 2.0, MFA, session management)
  - Data Protection (encryption, database security)
  - Access Control (RBAC)
  - Enterprise Identity & Access (SSO/SAML, audit logging)
  - Compliance & Governance (data retention, PII detection)
  - Enterprise-Grade Capabilities (anomaly detection, SLA dashboards)
  - API Security
  - Best Practices
  - Production Checklist
  - Vulnerability Reporting
- Content externalized to `lib/config/content/security_content.dart`
- Added route in `lib/app.dart`

**Contact Section Updates:**
- Added phone number with `tel:` link
- Added Google Maps URL for location button
- Updated Calendly demo link from 30min to 15min

### Bug Fixes

**TypeScript:**
- Fixed type errors in contact form worker tests (added response type assertions)

**Footer:**
- Fixed hardcoded social URLs to use `ExternalUrls` constants
- Corrected LinkedIn URL mismatch

### Content Updates

- Commented out SOC 2 Type II certification (pending)
- Commented out VPC/private deployment (not yet implemented)
- Updated SOC 2 stat to show "Certification Pending"
- Updated token rotation from 90 days to 60 days

### Files Added/Modified

- `lib/pages/security_page.dart` (new)
- `lib/config/content/security_content.dart` (new)
- `lib/config/content.dart` (export added)
- `lib/config/content/constants.dart` (routes, URLs)
- `lib/config/content/contact_content.dart` (phone, location URL)
- `lib/widgets/sections/footer_section.dart` (use constants)
- `lib/app.dart` (security route)
- `workers/contact-form/src/index.test.ts` (type fixes)
- Deleted `security.html`

---

## [2025-12-26] - WhyLabs Migration Guide & Team Updates

### New Content Published

**WhyLabs Migration Guide:**
- Comprehensive HTML migration guide for teams affected by WhyLabs shutdown
- Feature comparison tables (data quality, LLM monitoring, compliance)
- Step-by-step migration instructions (6 phases)
- Code migration examples (Python, TypeScript)
- Data export scripts for WhyLabs API
- FAQ section addressing common migration concerns
- Target deadline: WhyLabs SaaS shutdown March 9, 2025

**Files Added:**
- `web/resources/whylabs-migration-guide.html`

### Marketing Content

**LinkedIn Post:**
- Created LinkedIn post promoting Best LLM Monitoring Tools guide
- Added to `marketing/linkedin-posts/2024-12-24-llm-monitoring-guide.md`

### About Page Updates

**Team Section:**
- Added team members to "Meet the Team" section
- Updated `lib/config/content/about_content.dart`

### Bug Fixes

**LLM Monitoring Guide:**
- Corrected factual errors in Best LLM Monitoring Tools (2025 Guide)
- Updated `web/blog/best-llm-monitoring-tools-2025.html`

---

## [2024-12-24] - Best LLM Monitoring Tools Guide

### New Content Published

**Best LLM Monitoring Tools (2025 Guide):**
- Comprehensive comparison of 11 LLM observability platforms
- Covers: Phoenix, Helicone, LangSmith, Langfuse, Datadog, Fiddler, Arize, OpenLLMetry
- Includes pricing, features, pros/cons for each tool
- EU AI Act compliance considerations
- Cost optimization strategies
- Written in aledlie.com informal, technically-deep style

**Files Added:**
- `web/blog/best-llm-monitoring-tools-2025.html`
- Updated `lib/config/content/resources_content.dart`

---

## [2024-12-24] - Brand Assets & Infrastructure

### Brand Assets Completed

**Logo & Branding:**
- [x] Logo (SVG, PNG) for social sharing
- [x] Favicon variants for all platforms (16x16, 32x32, 48x48, ICO)
- [x] Apple Touch Icon (180x180)
- [x] PWA Icons (192x192, 512x512)
- [x] OG Image (1200x630) for social sharing

**Legal Pages:**
- [x] Privacy Policy page (`/privacy`)
- [x] Terms of Service page (`/terms`)
- [x] Sources page with citations and methodology (`/sources`)

**Infrastructure:**
- [x] Cloudflare Pages routing configuration
- [x] Security headers (X-Frame-Options, CSP, etc.)
- [x] Route handlers for /privacy and /terms

**Bug Fixes:**
- [x] Mobile/tablet layout overflow bugs resolved
- [x] Cookie banner mobile layout fixed
- [x] Blog page mobile layout overflow fixed

**Testing:**
- [x] Comprehensive landing page tests
- [x] Sources page and footer tests
- [x] Consent and analytics service unit tests
- [x] Cookie banner widget tests

---

## [2024-12-24] - Legal Compliance & Documentation

### Legal Compliance Fixes

**SOC 2 Claim Remediation:**
- Changed "SOC 2 Type II" to "Enterprise Security" in trust indicators
- Updated comparison page to show "In progress (Q2 2025)" instead of "Certified"
- Files updated: `content.dart`, `hero_section.dart`, `social_proof_section.dart`, blog HTML

**GDPR Cookie Consent (Already Implemented):**
- Verified consent mode defaults to DENIED on app start
- GTM script only loads after explicit user consent
- Cookie banner displays if no prior consent exists
- Full granular consent options (Essential/Analytics/Marketing)

**EU AI Act Compliance Disclaimers:**
- Added `ComplianceDisclaimers` class with full legal text
- Footer now displays general platform disclaimer
- Compliance & Governance service card shows EU AI Act disclaimer
- Files: `constants.dart`, `footer_section.dart`, `services_content.dart`

**Statistics Source Citations:**
- Added `CitedStatistic` class with `value`, `label`, `source`, `sourceUrl`, `type`
- Added `AppStatistics` with all statistics and their sources
- Social proof section now shows source tooltips on hover
- Added source disclaimer at bottom of stats section
- Statistic types: `industry`, `customerData`, `platformMetric`, `slaTarget`

### Documentation Updates

**FLUTTER_ARCHITECTURE_GUIDELINES.md:**
- Added Consent Flow Architecture diagram
- Added Compliance Disclaimer Placement diagram
- Added Statistics Source Attribution diagram

### Statistics Sources Added

| Statistic | Value | Source |
|-----------|-------|--------|
| Debugging improvement | 73% | Aggregated customer data, Q4 2024 |
| Cost reduction | 30-50% | Customer-reported savings, 2024 |
| Market size | $2.9B+ | Grand View Research, 2024 |
| Market growth | 25.47% | Grand View Research, 2024 |
| Enterprise budgets | 98% | Gartner CIO Survey 2024 |
| Setup time | 5min | Median onboarding time |
| Uptime | 99.9% | SLA target |

---

## [December 2024] - Initial Implementation

### Landing Page Sections Implemented

**Core Sections:**
- Hero section with animations and responsive layout
- Features/Platform section (tabbed features)
- Navigation header (sticky, mobile menu)
- Footer section
- Pricing section with toggle
- CTA section

**Additional Sections:**
- About section - Company info display
- Services section - Service offerings
- Resources section - Blog/resources display
- Contact section - Form with validation
- Social proof section - Customer testimonials, trust badges
- Status section - Status indicators
- Tabbed features section - Feature showcase

### Pages

- Landing page (`lib/pages/landing_page.dart`) - Composes 12 sections
- Blog page (`lib/pages/blog_page.dart`) - Article display with filtering

### Content Published

**AI Observability Platform Strategy Series:**
- AI Observability Platform Strategy Overview
- Market Analysis: AI Observability Landscape
- Competitive Landscape Analysis
- Regulatory Drivers & EU AI Act Impact
- Growth Strategy & Go-to-Market
- Strategic Recommendations

**Agentic AI Content:**
- End-to-End Agentic Observability Lifecycle Guide

### Technical Implementation

**Architecture:**
- Content externalization in `config/content.dart`
- Theme system (colors, typography, spacing)
- Reusable widget library (buttons, cards, containers)
- Analytics service with GDPR compliance
- Sentry error tracking integration

**Testing:**
- Comprehensive widget tests for all sections
- Unit tests for content models
- Integration tests for landing page
- Function-level coverage reporting in CI/CD

**CI/CD:**
- GitHub Actions workflow
- Cloudflare Pages deployment
- Coverage reports deployed to GitHub Pages
- Function coverage script (`scripts/add_function_coverage.dart`)

### Design System

- Color palette (blue/indigo/purple theme)
- Typography scale with Inter font
- Spacing system (4px grid)
- Glass morphism cards
- Gradient buttons
- Animated orbs

---

## Known Non-Issues

Items that appear in console but are not tech debt:

- `content.js` errors - Browser extension artifacts, not application code
- `Intl.v8BreakIterator` deprecation - Flutter SDK internal, safe to ignore

---

## Version History

| Date | Version | Changes |
|------|---------|---------|
| 2026-02-01 | 1.9 | Routing consolidation, Twitter/X removal, blog updates |
| 2026-01-31 | 1.8 | Test optimization (144s→51s), Twitter→X migration, content caching |
| 2026-01-30 | 1.7.1 | CI fix, section test consolidation, RenderFlex overflow fixes |
| 2026-01-29 | 1.7 | GoRouter migration, help center, docs pages (agents, toolkit, compliance) |
| 2026-01-29 | 1.6 | Test coverage sprint: 92.1%→94.0%, consent_manager DI refactor |
| 2026-01-28 | 1.5 | Security page, contact improvements, TypeScript fixes |
| 2025-12-26 | 1.4 | WhyLabs migration guide, team members, LinkedIn post, blog fixes |
| 2024-12-24 | 1.3 | Brand assets (logo, favicon, og-image), legal pages, infrastructure |
| 2024-12-24 | 1.2 | Legal compliance fixes (SOC 2, EU AI Act disclaimers, statistics citations) |
| 2024-12-24 | 1.1 | Documentation updates, changelog consolidation |
| 2024-12-16 | 1.0 | Initial implementation complete |

---

*For detailed implementation plans, see:*
- `FLUTTER_LANDING_PAGE_PLAN.md` - Original implementation plan
- `FLUTTER_ARCHITECTURE_GUIDELINES.md` - Architecture patterns
- `CONTENT_STRATEGY.md` - Marketing and content strategy
