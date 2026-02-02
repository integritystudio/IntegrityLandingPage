# Fix Plan: Routing Boilerplate Refactor

**Status**: COMPLETED

## Summary

The routing refactor was successfully completed using **Option B: GoRouter Migration**.

### Key Commits
- `d0c92c1` - refactor(routing): migrate Navigator to GoRouter across all pages
- `9e36093` - fix(routing): use GoRouter context.go() for pricing tier signup navigation
- `9c0491c` - fix(routing): add usePathUrlStrategy for deep linking
- `b620d16` - fix(routing): enable deep linking by removing initialLocation
- `3e2d3b8` - refactor(routing): rename /help-center to /support
- `f44be63` - fix(routing): update /support redirect and add /docs/agents route
- `d3049dd` - fix(nav): use GoRouter context.go() instead of Navigator.pop()
- `dadc9d5` - feat(nav): route all demo buttons to /demo page

## Results

| Metric | Before | After |
|--------|--------|-------|
| Lines in app.dart | ~510 | 79 |
| Lines per new route | ~15 | ~6 |
| Route definitions | Scattered in app.dart | Centralized in app_router.dart |
| Cookie banner | Repeated in each route | Single ShellRoute wrapper |

## Implementation

### Architecture
- **Router**: `lib/routing/app_router.dart` (277 lines)
- **Cookie Shell**: `lib/routing/cookie_shell.dart` - ValueNotifier-based banner state
- **App**: `lib/app.dart` - Creates router once, uses `MaterialApp.router`

### Pattern Used
```dart
GoRouter(
  routes: [
    ShellRoute(
      builder: (context, state, child) => CookieBannerShell(
        onConsentGiven: onConsentGiven,
        child: child,
      ),
      routes: [
        GoRoute(path: '/', builder: ...),
        GoRoute(path: '/blog', builder: ...),
        // ... all routes
      ],
    ),
  ],
)
```

### Key Features
1. **ShellRoute**: Wraps all routes with cookie banner
2. **ValueNotifier**: Banner visibility without router recreation
3. **Deep linking**: Works with browser URLs via `usePathUrlStrategy()`
4. **Redirects**: Handled declaratively in `redirect` callback
5. **Error handling**: Unknown routes fall back to landing page

## Routes Implemented (27 total)

### Main Pages
- `/` - Landing page
- `/about` - About page
- `/features` - Features page
- `/pricing` - Pricing page
- `/contact` - Contact page
- `/demo` - Demo request page
- `/careers` - Careers page
- `/support` - Help center
- `/status` - Status page

### Blog & Content
- `/blog` - Blog listing
- `/whylabs-alternative` - WhyLabs comparison
- `/compare/arize-ai-alternative` - Arize comparison
- `/sources` - Sources/citations

### Signup
- `/signup` - Signup (with `?tier=` query param)

### Legal
- `/privacy` - Privacy policy
- `/terms` - Terms of service
- `/cookies` - Cookie policy
- `/accessibility` - Accessibility statement

### Documentation
- `/docs` - Docs index
- `/docs/llm-observability` - LLM observability guide
- `/docs/tracing` - Tracing docs
- `/docs/integrations` - Integrations docs
- `/docs/quickstart` - Quickstart guide
- `/docs/alerts` - Alerts docs
- `/docs/agents` - Agents docs
- `/api` - API docs
- `/api/toolkit` - API toolkit

### Compliance
- `/compliance` - Compliance overview
- `/eu-ai-act` - EU AI Act page
- `/security` - Security page

### Redirects
- `/docs/security/audit-trails` → `/docs/tracing`
- `/reports/*` → `/docs`

## Testing
- All navigation tests updated to use `context.go()`
- Router tests in `test/routing/`
- 1978+ tests passing
