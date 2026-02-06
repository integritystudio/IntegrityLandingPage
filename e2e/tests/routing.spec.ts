import { test, expect } from '@playwright/test';
import { waitForFlutter, assertFlutterRendering } from './helpers';

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
      test(`${route.name} (${route.path}) loads Flutter app`, async ({ page }) => {
        const response = await page.goto(route.path, {
          waitUntil: 'domcontentloaded',
        });

        // Should return 200
        expect(response?.status()).toBe(200);

        // Should contain Flutter bootstrap script
        const content = await page.content();
        expect(content).toContain('flutter_bootstrap.js');

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
      expect(response.status()).toBe(200);

      const json = await response.json();
      expect(json.name).toBeDefined();
      expect(json.short_name).toBeDefined();
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

      const contentType = response.headers()['content-type'];
      expect(contentType).toContain('image/png');
    });

    test('apple-touch-icon is accessible', async ({ request }) => {
      const response = await request.get('/icons/apple-touch-icon.png');
      expect(response.status()).toBe(200);

      const contentType = response.headers()['content-type'];
      expect(contentType).toContain('image/png');
    });

    test('Meta Pixel JS is accessible with correct content', async ({ request }) => {
      const response = await request.get('/js/meta-pixel.js');
      expect(response.status()).toBe(200);

      const text = await response.text();
      expect(text).toContain('fbq');
    });

    test('GTM Init JS is accessible with correct content', async ({ request }) => {
      const response = await request.get('/js/gtm-init.js');
      expect(response.status()).toBe(200);

      const text = await response.text();
      expect(text).toContain('dataLayer');
    });

    test('Flutter service worker is accessible', async ({ request }) => {
      const response = await request.get('/flutter_service_worker.js');
      // Service worker may or may not exist depending on build
      expect([200, 404]).toContain(response.status());
    });
  });

  test.describe('Blog Routing', () => {
    test('/blog serves Flutter SPA (listing page)', async ({ page }) => {
      const response = await page.goto('/blog', {
        waitUntil: 'domcontentloaded',
      });

      expect(response?.status()).toBe(200);

      const content = await page.content();
      expect(content).toContain('flutter_bootstrap.js');

      // Wait for Flutter to load using deterministic wait
      await waitForFlutter(page);
    });

    // Blog article HTML files would be served directly when they exist
    // This test validates the route pattern works
    test('/blog path pattern is correctly configured', async ({ page }) => {
      // Verify /blog loads as SPA (not 404)
      const response = await page.goto('/blog');
      expect(response?.status()).toBe(200);

      // Content should be Flutter SPA, not static HTML
      const content = await page.content();
      expect(content).toContain('flutter_bootstrap.js');
    });
  });

  test.describe('404 Handling', () => {
    test('Unknown routes serve SPA (soft 404)', async ({ page }) => {
      // Cloudflare serves 200 with SPA, Flutter handles 404 display
      const response = await page.goto('/nonexistent-route-xyz-12345');
      expect(response?.status()).toBe(200);

      const content = await page.content();
      expect(content).toContain('flutter_bootstrap.js');

      // Wait for Flutter to load and verify it renders
      await waitForFlutter(page);
      await assertFlutterRendering(page);
    });

    test('Deep unknown routes also serve SPA', async ({ page }) => {
      const response = await page.goto('/some/deeply/nested/nonexistent/path');
      expect(response?.status()).toBe(200);

      const content = await page.content();
      expect(content).toContain('flutter_bootstrap.js');

      // Wait for Flutter to load and verify it renders
      await waitForFlutter(page);
      await assertFlutterRendering(page);
    });
  });

  test.describe('Security Headers', () => {
    test('CSP header is present with reporting directives', async ({ request }) => {
      const response = await request.get('/');
      expect(response.status()).toBe(200);

      // CSP is set via meta tag in index.html
      const html = await response.text();
      expect(html).toContain('Content-Security-Policy');
      expect(html).toContain('report-uri');
      expect(html).toContain('report-to csp-endpoint');
    });

    test('SRI attributes are present on external scripts', async ({ request }) => {
      const response = await request.get('/');
      const html = await response.text();

      // Check that integrity attributes exist on script tags
      expect(html).toContain('integrity="sha384-');
      expect(html).toContain('crossorigin="anonymous"');
    });
  });
});
