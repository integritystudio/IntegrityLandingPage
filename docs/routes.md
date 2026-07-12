# Routing Architecture

This document describes the current routing implementation for IntegrityStudio.ai.

## Overview

The application uses [GoRouter](https://pub.dev/packages/go_router) for declarative, URL-based routing with deep linking support.

### Key Files

| File | Purpose |
|------|---------|
| `lib/routing/app_router.dart` | Route definitions and redirects |
| `lib/routing/cookie_shell.dart` | Cookie banner wrapper via ShellRoute |
| `lib/app.dart` | Router initialization |

## Architecture

```
┌─────────────────────────────────────────────┐
│               MaterialApp.router            │
│                     │                       │
│              ┌──────▼──────┐                │
│              │   GoRouter  │                │
│              └──────┬──────┘                │
│                     │                       │
│           ┌─────────▼─────────┐             │
│           │    ShellRoute     │             │
│           │ (CookieBannerShell)│            │
│           └─────────┬─────────┘             │
│                     │                       │
│    ┌────────────────┼────────────────┐      │
│    │                │                │      │
│    ▼                ▼                ▼      │
│ GoRoute('/')   GoRoute('/blog')   GoRoute('/about')  │
│                    ...                      │
└─────────────────────────────────────────────┘
```

### Cookie Banner Pattern

The `ShellRoute` wraps all pages with a cookie consent banner:

```dart
ShellRoute(
  builder: (context, state, child) => CookieBannerShell(
    onConsentGiven: onConsentGiven,
    child: child,
  ),
  routes: [ /* all GoRoutes */ ],
)
```

Banner visibility is controlled via `cookieBannerNotifier` (ValueNotifier) to avoid router recreation.

### Navigation

Use GoRouter's `context.go()` for navigation:

```dart
// Correct
context.go('/pricing');

// Incorrect - do not use Navigator
Navigator.pushNamed(context, '/pricing');
```

## Routes

### Main Pages

| Route | Page Widget | Has Cookie Settings |
|-------|-------------|---------------------|
| `/` | `LandingPage` | Yes (accepts `?section=` query param) |
| `/about` | `AboutPage` | Yes |
| `/features` | `FeaturesPage` | Yes |
| `/pricing` | `PricingPage` | Yes |
| `/contact` | `ContactPage` | Yes (accepts `?ref=` query param) |
| `/demo` | `DemoPage` | No |
| `/careers` | `CareersPage` | Yes |
| `/status` | `StatusPage` | Yes |

### Auth & Result Pages

| Route | Page Widget | Has Cookie Settings |
|-------|-------------|---------------------|
| `/signup` | `SignupPage` | No (accepts `?tier=` query param, default `starter`) |
| `/login` | `AuthPage(mode: AuthMode.signIn)` | No (renamed from `/signin`) |
| `/request_success` | `RequestSuccessPage` | Yes |
| `/request_failure` | `RequestFailurePage` | Yes (failure detail passed via `state.extra`; auto-redirects to `/login` on existing-user errors) |
| `/oauth/callback` | `OAuthCallbackPage` | No (accepts `?code=`, `?state=`, `?error=`, `?error_description=`, `?success=`) |
| `/support` | `HelpCenterPage` | No |

### Provisioning & Billing (authenticated)

These routes back the signup → provision → dashboard/billing flow. Most are **guarded by `state.extra`**: the builder expects a typed args object passed via `context.go(path, extra: ...)`, and the route's own `redirect` sends the user away when it is absent — so deep-linking straight to them is not supported except where query-param fallbacks are noted.

| Route | Page Widget | Guard (redirect when `extra` missing) |
|-------|-------------|----------------------------------------|
| `/provision` | `ProvisionPage` | Needs `AuthSuccess` extra **or** `?jwt=` + `?email=` query params; else → `/login` |
| `/checkout` | `CheckoutPage` | Needs `CheckoutArgs` extra; else → `/` |
| `/checkout-success` | `CheckoutSuccessPage` | None — accepts `?email=` and `?tier=` (default `growth`) |
| `/dashboard` | `DashboardPage` | Needs `DashboardArgs` extra; else → `/login` |
| `/health` | `SenderHealthPage` | None (diagnostic page) |
| `/billing` | `BillingStatusPage` | Needs `BillingStatusArgs` extra; else → `/login` |
| `/usage` | `UsageSummaryPage` | Needs `UsageSummaryArgs` extra; else → `/login` |
| `/entitlements` | `EntitlementsPage` | Needs `EntitlementsArgs` extra; else → `/login` |
| `/quota` | `QuotaStatusPage` | Needs `QuotaStatusArgs` extra; else → `/login` |

Path constants for these live in `Routes` (`lib/config/content/constants.dart`).

### Blog & Content

| Route | Page Widget |
|-------|-------------|
| `/blog` | `BlogPage` |
| `/sources` | `SourcesPage` |
| `/whylabs-alternative` | `ComparisonPage.whylabs()` |
| `/compare/arize-ai-alternative` | `ComparisonPage.arize()` |

### Legal & Security

| Route | Page Widget |
|-------|-------------|
| `/privacy` | `LegalPage.privacy()` |
| `/terms` | `LegalPage.terms()` |
| `/cookies` | `LegalPage.cookies()` |
| `/accessibility` | `LegalPage.accessibility()` |
| `/security` | `SecurityPage` |

### Documentation

| Route | Page Widget |
|-------|-------------|
| `/docs` | `DocsIndexPage` |
| `/docs/llm-observability` | `DocsObservabilityPage` |
| `/docs/tracing` | `DocsTracingPage` |
| `/docs/integrations` | `DocsInteroperabilityPage` |
| `/docs/quickstart` | `DocsQuickstartPage` |
| `/docs/alerts` | `DocsAlertsPage` |
| `/docs/agents` | `DocsAgentsPage` |
| `/api` | `DocsApiPage` |
| `/api/toolkit` | `ApiToolkitPage` (back goes to `/docs`) |

### Compliance

| Route | Page Widget |
|-------|-------------|
| `/compliance` | `CompliancePage` |
| `/eu-ai-act` | `EuAiActPage` |

## Redirects

Handled in the `redirect` callback:

| From | To |
|------|-----|
| `/docs/security/audit-trails` | `/docs/tracing` |
| `/reports/*` | `/docs` |

## Error Handling

Unknown routes display the `LandingPage` via `errorBuilder`.

## Deep Linking

Deep linking is enabled via:

1. `usePathUrlStrategy()` in `main.dart` - uses clean URLs without `#`
2. No `initialLocation` set - GoRouter reads browser URL on startup
3. `<base href="/">` in `web/index.html` - correct path resolution

## Adding a New Route

1. Create page widget in `lib/pages/`
2. Import in `lib/routing/app_router.dart`
3. Add `GoRoute` inside the appropriate route group function
4. Update this document

## Testing

Router tests are in `test/routing/`:
- Route resolution
- Redirect behavior
- Query parameter handling
- Deep link scenarios
