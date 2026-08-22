# IntegrityStudio.ai Architecture

## Overview

Enterprise AI Observability Platform landing page built with Flutter Web, deployed on Cloudflare Pages with Cloudflare Workers backend.

## Tech Stack

| Layer | Technology |
|-------|------------|
| Frontend | Flutter 3.x (Web) |
| Routing | GoRouter |
| State | Provider, ValueNotifier |
| Backend | Cloudflare Workers |
| Hosting | Cloudflare Pages |
| Domain | integritystudio.ai |
| Icons | Lucide Icons |

## Directory Structure

```
lib/
├── config/           # Content configuration
│   └── content/      # Static content definitions (16 files)
├── controllers/      # Business logic controllers
├── models/           # Data models (consent, contact, dashboard, provisioning; freezed-generated)
├── pages/            # Page widgets (40 pages)
├── routing/          # GoRouter configuration
│   ├── app_router.dart   # Route definitions, redirects
│   └── cookie_shell.dart # Cookie consent ShellRoute wrapper
├── services/         # External service integrations
├── theme/            # Design system
├── utils/            # Security utilities
├── widgets/          # Reusable components
│   ├── common/       # Shared widgets (17 files: alert, buttons, cards, chip_badge, containers, copyable_code_field, dashboard_scaffold, error_card, form_fields, gradient_page_shell, gradient_pill_badge, hover_text_link, info_card, status_badge, status_icon, trust_badge, vertical_indicator_list)
│   ├── consent/      # Cookie consent banner
│   ├── decorative/   # Animated orb
│   ├── docs/         # Documentation components (DocCallout, DocBulletList, DocInlineWarning, DocStatCard, DocFeatureCard, DocNumberedList)
│   ├── modals/       # Demo modal
│   ├── navigation/   # SharedAppBar, DocsPageScaffold, SubPageShell
│   └── sections/     # Page sections (14 section widgets)
├── app.dart          # App widget
└── main.dart         # Entry point
```

## Core Patterns

### Content Loading

```dart
// lib/services/content_loader.dart
// Static-only pattern: ContentLoader.load() / ContentLoader.loadFromString()
// Coalesces concurrent calls via Completer, 1-hour cache
```

All site content is defined in `content.yaml` at project root. Content constants live in `lib/config/content/constants.dart` (routes, CTA text sourced from YAML, variants, external URLs).

### Routing

All navigation uses GoRouter via `context.go()`. Routes are organized into groups:
- `_homeRoute` / `_mainPageRoutes` — primary pages with cookie settings
- `_authRoutes` — login, signup, provision, checkout, checkout-success, dashboard, billing, usage, entitlements, quota, health, request result pages, help center
- `_blogRoutes` — blog, comparisons, sources
- `_legalRoutes` — privacy, terms, cookies, accessibility, security
- `_docsRoutes` — documentation, API, compliance

See [routes.md](routes.md) for the full route table.

### State Management

| Pattern | Use Case |
|---------|----------|
| Provider | Controllers, app-wide state |
| ValueNotifier | Cookie consent banner visibility |

### Theme System

```
lib/theme/
├── colors.dart       # Color palette
├── decorations.dart  # Box decorations, gradients
├── spacing.dart      # Spacing constants
├── theme.dart        # ThemeData configuration
└── typography.dart   # Text styles
```

### Documentation Pages

Documentation pages use `DocsPageScaffold` (extracted shared scaffold) with `DocsHeroSection` and reusable components from `lib/widgets/docs/doc_components.dart`:
- `DocCallout` (info, warning, tip named constructors)
- `DocBulletList` (with optional checkmarks)
- `DocInlineWarning`
- `DocStatCard` (stat display with optional `valueStyle` and `constraints`)
- `DocFeatureCard`, `DocNumberedList`

## Services

| Service | Purpose |
|---------|---------|
| `content_loader.dart` | Static YAML content loading with Completer-based coalescing |
| `consent_manager.dart` | Cookie preference storage |
| `contact_service.dart` | Form submission to Workers with CSRF |
| `analytics.dart` | Analytics integration |
| `tracking.dart` | Platform-conditional tracking (web/none) |
| `http_status.dart` | HTTP status code constants |
| `security_utils.dart` | Input sanitization, CSP nonce |
| `dashboard_service.dart` | Dashboard data fetching from Workers |
| `oauth_service.dart` | OAuth flow (platform-conditional web/stub) |
| `provisioning_service.dart` | Signup/signin calls to sender-worker |
| `auth_storage.dart` | JWT/session persistence (platform-conditional web/stub) |
| `url_launcher.dart` | External URL opening (platform-conditional web/stub) |

## Backend (Cloudflare Workers)

```
workers/
├── lib/              # Shared HTTP, validation, and constants (shared test suite)
├── contact-form/     # Resend email delivery, CSRF protection, KV rate limiting
├── sender-worker/    # Inline Auth0+Supabase signup/signin; HMAC-signs /send events to receiver
├── receiver-worker/  # Local stub/test double only — NOT deployed (production receiver lives in observability-toolkit repo)
├── api-gateway/      # Usage ingest, aggregation, auth, quota
├── stripe-webhook/   # Stripe subscription lifecycle, checkout, dead-letter queue
└── bootstrap-worker/ # Bootstrap operations
```

## Testing Structure

```
test/
├── unit/             # Content, models, services, theme tests
├── services/         # Service integration tests
├── controllers/      # Controller tests
├── widgets/          # Widget tests (common, consent, decorative, docs, modals, navigation, sections)
├── pages/            # Page render tests (22 page test files)
├── routing/          # Router tests
├── integration/      # Multi-page flow tests (9 flow tests)
├── config/           # Constants and models tests
├── utils/            # Security utils tests
└── helpers/          # Test utilities, content fixtures, constants
```

## Static Assets

```
web/
├── blog/             # Static blog HTML
├── docs/             # Static documentation
├── icons/            # Favicons, PWA icons
├── images/           # Logos, OG images
├── resources/        # Downloadable guides
├── _headers          # Cloudflare headers
├── _redirects        # Cloudflare redirects
├── manifest.json     # PWA manifest
├── robots.txt        # SEO
└── sitemap.xml       # SEO
```

## Deployment

1. **Build**: `flutter build web`
2. **Deploy**: Push to `main` triggers Cloudflare Pages
3. **Workers**: Deployed via Wrangler CLI

## Key Files

| File | Purpose |
|------|---------|
| `content.yaml` | All site content |
| `pubspec.yaml` | Flutter dependencies |
| `analysis_options.yaml` | Lint rules |
| `web/index.html` | HTML shell, SEO meta |

## Social Links

- LinkedIn, GitHub only (no Twitter/X)
