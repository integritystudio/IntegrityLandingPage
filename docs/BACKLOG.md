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

| Issue | Severity | Effort | Business Impact | Recommended Sprint |
|-------|----------|--------|-----------------|-------------------|
| #4 CSP Reporting | HIGH | Medium | Security visibility | Current |
| #6 E2E Routing | HIGH | Medium-High | Regression prevention | Current |

## Related Completed Issues

- [x] #1: Add SRI to external scripts (94c6c3e)
- [x] #2: CSP hash CI validation (94c6c3e)
- [x] #3: Rate limiting graceful degradation (94c6c3e)
- [x] #5: Resend API timeout (94c6c3e)

---

*Last updated: 2026-02-04*
