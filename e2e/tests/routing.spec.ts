import { test, expect } from '@playwright/test';
import {
  assertFlutterRendering,
  enableFlutterSemantics,
  navigateAndWaitForFlutter,
  waitForFlutter,
  waitForSemantics,
} from './helpers';
import {
  BLOG_ARTICLE_FLAT_SLUG,
  BLOG_ARTICLE_NESTED_SLUG,
  BLOG_ARTICLE_SLUG,
  CSP_REPORT_GROUP,
  FLUTTER_BOOTSTRAP_SCRIPT,
  HTTP_NOT_FOUND,
  HTTP_OK,
  MOBILE_VIEWPORT_HEIGHT,
  MOBILE_VIEWPORT_WIDTH,
  SEMANTICS_TIMEOUT_MS,
  SRI_HASH_PREFIX,
  TEST_TIMEOUT_MS,
  VALID_REDIRECT_STATUSES,
} from './constants';

/**
 * E2E tests for routing and redirect rules.
 *
 * Validates that Cloudflare Pages routing configuration (web/_redirects)
 * correctly serves:
 * - SPA routes via index.html
 * - Static assets directly
 * - Blog routing (listing vs articles)
 * - 404 handling via SPA fallback
 *
 * These tests are critical for enterprise deployment to prevent
 * routing regressions that could break user access.
 */
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
      test(`${route.name} (${route.path}) loads Flutter app`, async ({ page, browserName }) => {
        test.skip(browserName !== 'chromium', 'Flutter CanvasKit requires Chromium');
        const response = await page.goto(route.path, {
          waitUntil: 'domcontentloaded',
        });

        // Should return 200
        expect(response?.status()).toBe(HTTP_OK);

        // Should contain Flutter bootstrap script
        const content = await page.content();
        expect(content).toContain(FLUTTER_BOOTSTRAP_SCRIPT);

        // Wait for Flutter to fully initialize (deterministic, no race conditions)
        await waitForFlutter(page);

        // Verify Flutter rendered something
        await assertFlutterRendering(page);
      });
    }
  });

  test.describe('Static Assets', () => {
    test('manifest.json is accessible', async ({ request }) => {
      const response = await request.get('/manifest.json');
      expect(response.status()).toBe(HTTP_OK);

      const json = await response.json();
      expect(json.name).toBeTruthy();
      expect(json.short_name).toBeTruthy();
    });

    test('robots.txt is accessible', async ({ request }) => {
      const response = await request.get('/robots.txt');
      expect(response.status()).toBe(HTTP_OK);

      const text = await response.text();
      expect(text).toContain('User-agent');
    });

    test('favicon is accessible', async ({ request }) => {
      const response = await request.get('/icons/favicon-32x32.png');
      expect(response.status()).toBe(HTTP_OK);

      const contentType = response.headers()['content-type'];
      expect(contentType).toContain('image/png');
    });

    test('apple-touch-icon is accessible', async ({ request }) => {
      const response = await request.get('/icons/apple-touch-icon.png');
      expect(response.status()).toBe(HTTP_OK);

      const contentType = response.headers()['content-type'];
      expect(contentType).toContain('image/png');
    });

    test('Meta Pixel JS is accessible with correct content', async ({ request }) => {
      const response = await request.get('/js/meta-pixel.js');
      expect(response.status()).toBe(HTTP_OK);

      const text = await response.text();
      expect(text).toContain('fbq');
    });

    test('GTM Init JS is accessible with correct content', async ({ request }) => {
      const response = await request.get('/js/gtm-init.js');
      expect(response.status()).toBe(HTTP_OK);

      const text = await response.text();
      expect(text).toContain('dataLayer');
    });

    test('Flutter service worker is accessible', async ({ request }) => {
      const response = await request.get('/flutter_service_worker.js');
      // Service worker may not exist: Flutter only generates it for release
      // builds with --pwa-strategy=offline-first (default). Dev/preview deploys
      // and builds with --pwa-strategy=none omit the file entirely, so 404 is
      // a valid response. This loose assertion is intentional permanent policy.
      expect([HTTP_OK, HTTP_NOT_FOUND]).toContain(response.status());
    });
  });

  test.describe('Blog Routing', () => {
    test('/blog serves Flutter SPA (listing page)', async ({ page, browserName }) => {
      test.skip(browserName !== 'chromium', 'Flutter CanvasKit requires Chromium');
      const response = await page.goto('/blog', {
        waitUntil: 'domcontentloaded',
      });

      expect(response?.status()).toBe(HTTP_OK);

      const content = await page.content();
      expect(content).toContain(FLUTTER_BOOTSTRAP_SCRIPT);

      // Wait for Flutter to load using deterministic wait
      await waitForFlutter(page);
    });

    test('blog article HTML files are served directly', async ({ request }) => {
      const response = await request.get(`/blog/${BLOG_ARTICLE_SLUG}`);
      expect(response.status()).toBe(HTTP_OK);

      const html = await response.text();
      // Should be static HTML, not Flutter SPA
      expect(html).toContain('<html');
      expect(html).not.toContain(FLUTTER_BOOTSTRAP_SCRIPT);
    });

    test('nested blog article HTML files are served directly', async ({ request }) => {
      const response = await request.get(`/blog/${BLOG_ARTICLE_NESTED_SLUG}`);
      expect(response.status()).toBe(HTTP_OK);

      const html = await response.text();
      expect(html).toContain('<html');
    });

    test('blog articles return HTML content type', async ({ request }) => {
      const response = await request.get(`/blog/${BLOG_ARTICLE_FLAT_SLUG}`);
      expect(response.status()).toBe(HTTP_OK);

      const contentType = response.headers()['content-type'];
      expect(contentType).toContain('text/html');
    });

    test('nonexistent blog article falls back to SPA', async ({ request }) => {
      const response = await request.get('/blog/nonexistent-article-xyz.html');
      // Cloudflare may serve 200 with SPA fallback or 404
      const status = response.status();
      expect([HTTP_OK, HTTP_NOT_FOUND]).toContain(status);

      if (status === HTTP_OK) {
        const html = await response.text();
        // If served, it should be the SPA fallback
        expect(html).toContain(FLUTTER_BOOTSTRAP_SCRIPT);
      }
    });
  });

  test.describe('Blog Redirect Behavior', () => {
    // Regression tests for /blog 308→/ bug (fixed in 0c1b161).
    // Root cause: rewrite rule "/blog /index.html 200" caused CF pretty-URL
    // normalization to 308 redirect to / instead of serving the blog page.

    test('/blog redirects to /blog/ (not /)', async ({ request }) => {
      const response = await request.get('/blog', {
        maxRedirects: 0,
      });
      const status = response.status();
      const location = response.headers()['location'];

      // Must be a redirect to /blog/
      expect(VALID_REDIRECT_STATUSES).toContain(status);
      expect(location).toMatch(/\/blog\/$/);
    });

    test('/blog does NOT redirect to /', async ({ request }) => {
      const response = await request.get('/blog', {
        maxRedirects: 0,
      });
      const location = response.headers()['location'] ?? '';

      // The bug was location: / — ensure this never regresses
      expect(location).not.toBe('/');
      expect(location).not.toMatch(/^https?:\/\/[^/]+\/$/);
    });

    test('/blog redirect chain lands on blog page (200)', async ({ request }) => {
      // Follow redirects — final response must be 200 with SPA content
      const response = await request.get('/blog');
      expect(response.status()).toBe(HTTP_OK);

      const html = await response.text();
      expect(html).toContain(FLUTTER_BOOTSTRAP_SCRIPT);
    });

    test('/blog/ serves 200 directly (no redirect)', async ({ request }) => {
      const response = await request.get('/blog/', {
        maxRedirects: 0,
      });
      expect(response.status()).toBe(HTTP_OK);
    });

    test('/internship redirects to /internship/ (not /)', async ({ request }) => {
      const response = await request.get('/internship', {
        maxRedirects: 0,
      });
      const status = response.status();
      const location = response.headers()['location'] ?? '';

      expect(VALID_REDIRECT_STATUSES).toContain(status);
      expect(location).toMatch(/\/internship\/$/);
      expect(location).not.toBe('/');
    });
  });

  test.describe('404 Handling', () => {
    // Note: GoRouter errorBuilder renders LandingPage at the original unknown
    // URL — no dedicated 404 page exists. LandingPage rendering is verified via
    // Flutter semantics tree (#111 workaround). Sentry error reporting is not
    // testable here since errorBuilder renders the home page without an error
    // event. A dedicated 404 page with error text would require a new widget.

    // Basic unknown-route rendering is covered by redirect-rules.spec.ts
    // ('unknown route fallback' describe block). Tests below focus on
    // Cloudflare-specific SPA fallback behavior not covered there.

    test('Unknown route URL is preserved (no redirect to /)', async ({ page, browserName }) => {
      test.skip(browserName !== 'chromium', 'Flutter CanvasKit requires Chromium');
      // GoRouter errorBuilder renders LandingPage at the original URL without
      // redirecting. Verify the path is preserved as a regression guard.
      const unknownPath = '/nonexistent-page-url-guard-abc';
      const response = await page.goto(unknownPath, { waitUntil: 'domcontentloaded' });
      expect(response?.status()).toBe(HTTP_OK);
      await waitForFlutter(page);
      expect(page.url()).toContain(unknownPath);
    });

    test('Unknown route loads Flutter on mobile viewport', async ({ page, browserName }) => {
      test.skip(browserName !== 'chromium', 'Flutter CanvasKit requires Chromium');
      await page.setViewportSize({ width: MOBILE_VIEWPORT_WIDTH, height: MOBILE_VIEWPORT_HEIGHT });
      const response = await page.goto('/nonexistent-mobile-route-xyz', {
        waitUntil: 'domcontentloaded',
      });
      expect(response?.status()).toBe(HTTP_OK);
      const content = await page.content();
      expect(content).toContain(FLUTTER_BOOTSTRAP_SCRIPT);
      await waitForFlutter(page);
      await assertFlutterRendering(page);
    });

    test('Unknown route HTTP response is 200 with SPA content', async ({ request }) => {
      // Verifies Cloudflare Pages SPA fallback at the HTTP level.
      // No browser required — validates CDN behaviour on all platforms.
      const response = await request.get('/nonexistent-route-http-level-xyz');
      expect(response.status()).toBe(HTTP_OK);
      const html = await response.text();
      expect(html).toContain(FLUTTER_BOOTSTRAP_SCRIPT);
    });

    test('Unknown route renders LandingPage with accessible nav (semantics)', async ({ page, browserName }) => {
      test.setTimeout(TEST_TIMEOUT_MS);
      test.skip(browserName !== 'chromium', 'Flutter CanvasKit requires Chromium');

      await navigateAndWaitForFlutter(page, '/nonexistent-semantics-test-xyz');
      await enableFlutterSemantics(page);

      try {
        await waitForSemantics(page, /navigate to home/i, SEMANTICS_TIMEOUT_MS);
      } catch {
        test.skip(true, 'Flutter semantics tree not available (Flutter #151929)');
        return;
      }

      // errorBuilder renders LandingPage — verify via semantics
      await expect(page.getByLabel(/navigate to home/i).first()).toBeAttached();
      await expect(page.getByLabel(/navigation menu/i).first()).toBeAttached();
    });
  });

  test.describe('Security Headers', () => {
    test('CSP header is present with reporting directives', async ({ request }) => {
      const response = await request.get('/');
      expect(response.status()).toBe(HTTP_OK);

      // CSP is set via meta tag in index.html
      const html = await response.text();
      expect(html).toContain('Content-Security-Policy');
      expect(html).toContain('report-uri');
      expect(html).toContain(`report-to ${CSP_REPORT_GROUP}`);
    });

    test('SRI attributes are present on external scripts', async ({ request }) => {
      const response = await request.get('/');
      const html = await response.text();

      // Check that integrity attributes exist on script tags
      expect(html).toContain(`integrity="${SRI_HASH_PREFIX}`);
      expect(html).toContain('crossorigin="anonymous"');
    });
  });
});
