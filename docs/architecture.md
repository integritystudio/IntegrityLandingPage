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

## Directory Structure

```
lib/
├── config/           # Content configuration
│   └── content/      # Static content definitions
├── controllers/      # Business logic controllers
├── models/           # Data models
├── pages/            # Page widgets (26 pages)
├── providers/        # Provider setup
├── routing/          # GoRouter configuration
├── services/         # External service integrations
├── theme/            # Design system
├── widgets/          # Reusable components
│   ├── common/       # Shared widgets
│   ├── consent/      # Cookie consent UI
│   ├── decorative/   # Visual elements
│   ├── docs/         # Documentation components
│   ├── modals/       # Dialog components
│   └── sections/     # Page sections
├── app.dart          # App widget
└── main.dart         # Entry point
```

## Core Patterns

### Routing

All navigation uses GoRouter via `context.go()`:

```dart
// lib/routing/app_router.dart - Central route configuration
// lib/routing/cookie_shell.dart - Consent state via ValueNotifier
```

Key routes:
- `/` - Landing page
- `/demo` - Demo request (all CTAs route here)
- `/pricing` - Pricing page
- `/docs/*` - Documentation pages
- `/blog/*` - Blog posts

### Content Loading

```dart
// lib/services/content_loader.dart
// Loads from content.yaml with 1-hour cache
```

Site content is defined in `content.yaml` at project root, covering:
- Hero section
- Features
- Pricing tiers
- Testimonials
- FAQ

### State Management

| Pattern | Use Case |
|---------|----------|
| Provider | Controllers, app-wide state |
| ValueNotifier | Cookie consent banner |

### Theme System

```
lib/theme/
├── colors.dart       # Color palette
├── decorations.dart  # Box decorations, gradients
├── spacing.dart      # Spacing constants
├── theme.dart        # ThemeData configuration
└── typography.dart   # Text styles
```

## Services

| Service | Purpose |
|---------|---------|
| `content_loader.dart` | YAML content loading with cache |
| `consent_manager.dart` | Cookie preference storage |
| `contact_service.dart` | Form submission to Workers |
| `analytics.dart` | Analytics integration |
| `tracking.dart` | Platform-conditional tracking |

## Backend (Cloudflare Workers)

```
workers/contact-form/
├── src/              # Worker source
├── wrangler.toml     # Cloudflare config
└── vitest.config.ts  # Worker tests
```

Handles contact form submissions with email delivery.

## Testing Structure

```
test/
├── unit/             # Fast unit tests (~5-11s)
├── services/         # Service tests (~5s)
├── controllers/      # Controller tests (~4s)
├── widgets/          # Widget tests (~40s)
├── pages/            # Page tests (~51s)
├── routing/          # Router tests (~26s)
├── integration/      # Flow tests (~28s)
└── helpers/          # Test utilities
```

**Stats**: 1978+ passing tests, ~94% coverage

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
