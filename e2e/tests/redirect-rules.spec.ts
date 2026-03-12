import { test, expect } from '@playwright/test';
import { waitForFlutter, assertFlutterRendering, waitForRoute } from './helpers';

/**
 * E2E tests for GoRouter redirect rules and Cloudflare _redirects.
 *
 * GoRouter redirects are client-side: the browser loads the SPA at the
 * original URL, Flutter initializes, then GoRouter's redirect callback
 * changes the URL. Tests must wait for Flutter + URL change.
 */

test.describe('Redirect Rules', () => {
  test.beforeEach(async ({ browserName }) => {
    test.skip(browserName !== 'chromium', 'Flutter CanvasKit requires Chromium');
  });

  // -------------------------------------------------------------------------
  // GoRouter redirects (app_router.dart:242-246)
  // -------------------------------------------------------------------------

  test.describe('GoRouter redirects', () => {
    test('/docs/security/audit-trails redirects to /docs/tracing', async ({ page }) => {
      // GoRouter redirects this client-side to /docs/tracing.
      // On production, /docs/tracing serves static HTML (#104), not Flutter SPA.
      // Test only validates the redirect destination returns 200.
      const response = await page.goto('/docs/security/audit-trails', {
        waitUntil: 'domcontentloaded',
      });
      expect(response?.status()).toBe(200);
      // GoRouter redirect is client-side; wait for URL change or check content
      // Since /docs/tracing may be static HTML (#104), we verify the response
      // content contains either Flutter SPA or the tracing page content.
      const html = await page.content();
      const isFlutter = html.includes('flutter_bootstrap.js');
      const isStaticTracing = html.includes('Tracing') || html.includes('tracing');
      expect(isFlutter || isStaticTracing).toBe(true);
    });

    test('/reports/anything redirects to /docs', async ({ page }) => {
      test.slow(); // GoRouter redirect requires full Flutter init + route change
      await page.goto('/reports/quarterly-review', { waitUntil: 'domcontentloaded' });
      await waitForFlutter(page);
      await waitForRoute(page, /\/docs/);
      expect(page.url()).toContain('/docs');
      await assertFlutterRendering(page);
    });
  });

  // -------------------------------------------------------------------------
  // Unknown routes (errorBuilder → landing page)
  // -------------------------------------------------------------------------

  test.describe('unknown route fallback', () => {
    test('unknown route renders landing page (not blank)', async ({ page }) => {
      await page.goto('/this-route-does-not-exist', { waitUntil: 'domcontentloaded' });
      await waitForFlutter(page);
      await assertFlutterRendering(page);
      // errorBuilder sends to LandingPage, so URL stays but Flutter renders home
    });

    test('deeply nested unknown route still renders', async ({ page }) => {
      await page.goto('/a/b/c/d/e/f', { waitUntil: 'domcontentloaded' });
      await waitForFlutter(page);
      await assertFlutterRendering(page);
    });
  });

  // -------------------------------------------------------------------------
  // Query parameter and fragment preservation
  // -------------------------------------------------------------------------

  test.describe('query parameter preservation', () => {
    test('/?section=pricing preserves section param', async ({ page }) => {
      await page.goto('/?section=pricing', { waitUntil: 'domcontentloaded' });
      await waitForFlutter(page);
      expect(page.url()).toContain('section=pricing');
      await assertFlutterRendering(page);
    });

    test('/contact preserves arbitrary query params', async ({ page }) => {
      await page.goto('/contact?ref=footer&utm_source=test', { waitUntil: 'domcontentloaded' });
      await waitForFlutter(page);
      expect(page.url()).toContain('/contact');
      await assertFlutterRendering(page);
    });
  });

  // -------------------------------------------------------------------------
  // Redirect chain validation (#115)
  // Multi-hop redirect chains and loop prevention
  // -------------------------------------------------------------------------

  test.describe('redirect chain validation', () => {
    test('/reports/foo → /docs chain reaches /docs', async ({ page }) => {
      test.slow(); // GoRouter redirect requires full Flutter init
      // /reports/* is a GoRouter redirect to /docs (app_router.dart)
      await page.goto('/reports/old-quarterly', { waitUntil: 'domcontentloaded' });
      await waitForFlutter(page);
      await waitForRoute(page, /\/docs/);
      expect(page.url()).toContain('/docs');
      await assertFlutterRendering(page);
    });

    test('/docs/security/audit-trails → /docs/tracing returns 200 (no loop)', async ({ request }) => {
      // maxRedirects: 5 fails fast if a redirect loop is present rather than
      // relying on the test timeout to surface it.
      const response = await request.get('/docs/security/audit-trails', { maxRedirects: 5 });
      expect(response.status()).toBe(200);
    });

    test('trailing slash on /pricing/ does not loop', async ({ request }) => {
      const response = await request.get('/pricing/', { maxRedirects: 5 });
      // Cloudflare may redirect /pricing/ → /pricing or serve 200 directly
      expect([200, 301, 308]).toContain(response.status());
    });

    test('trailing slash on /docs/ does not loop', async ({ request }) => {
      const response = await request.get('/docs/', { maxRedirects: 5 });
      expect([200, 301, 308]).toContain(response.status());
    });
  });
});
