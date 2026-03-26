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
  SPA_ROUTE_BLOG,
  SPA_ROUTE_INTERNSHIP,
  SRI_HASH_PREFIX,
  TEST_TIMEOUT_MS,
  VALID_REDIRECT_STATUSES,
} from './constants';

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
        const response = await page.goto(route.path, { waitUntil: 'domcontentloaded' });
        expect(response?.status()).toBe(HTTP_OK);
        expect(await page.content()).toContain(FLUTTER_BOOTSTRAP_SCRIPT);
        await waitForFlutter(page);
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
      expect(text).toContain('Sitemap');
    });

    test('favicon is accessible', async ({ request }) => {
      const response = await request.get('/icons/favicon-32x32.png');
      expect(response.status()).toBe(HTTP_OK);
      expect(response.headers()['content-type']).toContain('image/png');
    });

    test('apple-touch-icon is accessible', async ({ request }) => {
      const response = await request.get('/icons/apple-touch-icon.png');
      expect(response.status()).toBe(HTTP_OK);
      expect(response.headers()['content-type']).toContain('image/png');
    });

    test('Meta Pixel JS is accessible with correct content', async ({ request }) => {
      const response = await request.get('/js/meta-pixel.js');
      expect(response.status()).toBe(HTTP_OK);
      expect(await response.text()).toContain('fbq');
    });

    test('GTM Init JS is accessible with correct content', async ({ request }) => {
      const response = await request.get('/js/gtm-init.js');
      expect(response.status()).toBe(HTTP_OK);
      expect(await response.text()).toContain('dataLayer');
    });

    test('Flutter service worker is accessible', async ({ request }) => {
      const response = await request.get('/flutter_service_worker.js');
      // Service worker may not exist on all build configs; 404 is valid.
      expect([HTTP_OK, HTTP_NOT_FOUND]).toContain(response.status());
    });
  });

  test.describe('Blog Routing', () => {
    test('/blog serves Flutter SPA (listing page)', async ({ page, browserName }) => {
      test.skip(browserName !== 'chromium', 'Flutter CanvasKit requires Chromium');
      const response = await page.goto('/blog', { waitUntil: 'domcontentloaded' });
      expect(response?.status()).toBe(HTTP_OK);
      expect(await page.content()).toContain(FLUTTER_BOOTSTRAP_SCRIPT);
      await waitForFlutter(page);
    });

    test('blog article HTML files are served directly', async ({ request }) => {
      const response = await request.get(`/blog/${BLOG_ARTICLE_SLUG}`);
      expect(response.status()).toBe(HTTP_OK);
      const html = await response.text();
      expect(html).toContain('<html');
      expect(html).not.toContain(FLUTTER_BOOTSTRAP_SCRIPT);
    });

    test('nested blog article HTML files are served directly', async ({ request }) => {
      const response = await request.get(`/blog/${BLOG_ARTICLE_NESTED_SLUG}`);
      expect(response.status()).toBe(HTTP_OK);
      expect(await response.text()).toContain('<html');
    });

    test('blog articles return HTML content type', async ({ request }) => {
      const response = await request.get(`/blog/${BLOG_ARTICLE_FLAT_SLUG}`);
      expect(response.status()).toBe(HTTP_OK);
      expect(response.headers()['content-type']).toContain('text/html');
    });

    test('nonexistent blog article falls back to SPA', async ({ request }) => {
      const response = await request.get('/blog/nonexistent-article-xyz.html');
      const status = response.status();
      expect([HTTP_OK, HTTP_NOT_FOUND]).toContain(status);
      if (status === HTTP_OK) {
        expect(await response.text()).toContain(FLUTTER_BOOTSTRAP_SCRIPT);
      }
    });
  });

  test.describe('Blog Redirect Behavior', () => {
    // Regression tests for /blog 308→/ bug (fixed in 0c1b161).

    test('/blog redirects to /blog/ (not /)', async ({ request }) => {
      const response = await request.get(SPA_ROUTE_BLOG, { maxRedirects: 0 });
      expect(VALID_REDIRECT_STATUSES).toContain(response.status());
      expect(response.headers()['location']).toMatch(/\/blog\/$/);
    });

    test('/blog does NOT redirect to /', async ({ request }) => {
      const response = await request.get(SPA_ROUTE_BLOG, { maxRedirects: 0 });
      const location = response.headers()['location'] ?? '';
      expect(location).not.toBe('/');
      expect(location).not.toMatch(/^https?:\/\/[^/]+\/$/);
    });

    test('/blog redirect chain lands on blog page (200)', async ({ request }) => {
      const response = await request.get(SPA_ROUTE_BLOG);
      expect(response.status()).toBe(HTTP_OK);
      expect(await response.text()).toContain(FLUTTER_BOOTSTRAP_SCRIPT);
    });

    test('/blog/ serves 200 directly (no redirect)', async ({ request }) => {
      const response = await request.get(`${SPA_ROUTE_BLOG}/`, { maxRedirects: 0 });
      expect(response.status()).toBe(HTTP_OK);
    });

    test('/internship redirects to /internship/ (not /)', async ({ request }) => {
      const response = await request.get(SPA_ROUTE_INTERNSHIP, { maxRedirects: 0 });
      const location = response.headers()['location'] ?? '';
      expect(VALID_REDIRECT_STATUSES).toContain(response.status());
      expect(location).toMatch(/\/internship\/$/);
      expect(location).not.toBe('/');
    });
  });

  test.describe('404 Handling', () => {
    test('Unknown route URL is preserved (no redirect to /)', async ({ page, browserName }) => {
      test.skip(browserName !== 'chromium', 'Flutter CanvasKit requires Chromium');
      const unknownPath = '/nonexistent-page-url-guard-abc';
      const response = await page.goto(unknownPath, { waitUntil: 'domcontentloaded' });
      expect(response?.status()).toBe(HTTP_OK);
      await waitForFlutter(page);
      expect(page.url()).toContain(unknownPath);
    });

    test('Unknown route loads Flutter on mobile viewport', async ({ page, browserName }) => {
      test.skip(browserName !== 'chromium', 'Flutter CanvasKit requires Chromium');
      await page.setViewportSize({ width: MOBILE_VIEWPORT_WIDTH, height: MOBILE_VIEWPORT_HEIGHT });
      const response = await page.goto('/nonexistent-mobile-route-xyz', { waitUntil: 'domcontentloaded' });
      expect(response?.status()).toBe(HTTP_OK);
      expect(await page.content()).toContain(FLUTTER_BOOTSTRAP_SCRIPT);
      await waitForFlutter(page);
      await assertFlutterRendering(page);
    });

    test('Unknown route HTTP response is 200 with SPA content', async ({ request }) => {
      const response = await request.get('/nonexistent-route-http-level-xyz');
      expect(response.status()).toBe(HTTP_OK);
      expect(await response.text()).toContain(FLUTTER_BOOTSTRAP_SCRIPT);
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

      await expect(page.getByLabel(/navigate to home/i).first()).toBeAttached();
      await expect(page.getByLabel(/navigation menu/i).first()).toBeAttached();
    });
  });

  test.describe('Security Headers', () => {
    test('CSP header is present with reporting directives', async ({ request }) => {
      const response = await request.get('/');
      expect(response.status()).toBe(HTTP_OK);
      const html = await response.text();
      expect(html).toContain('Content-Security-Policy');
      const reportTo = response.headers()['report-to'];
      expect(reportTo).toContain(CSP_REPORT_GROUP);
    });

    test('SRI attributes are present on external scripts', async ({ request }) => {
      const html = await (await request.get('/')).text();
      expect(html).toContain(`integrity="${SRI_HASH_PREFIX}`);
      expect(html).toContain('crossorigin="anonymous"');
    });
  });
});
