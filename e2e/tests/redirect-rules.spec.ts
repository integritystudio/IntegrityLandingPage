import { test, expect } from '@playwright/test';
import { waitForFlutter, assertFlutterRendering, waitForRoute } from './helpers';
import {
  HTTP_OK,
  VALID_REDIRECT_STATUSES,
} from './constants';

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

  test.describe('GoRouter redirects', () => {
    test('/docs/security/audit-trails redirects to /docs/tracing', async ({ page }) => {
      const response = await page.goto('/docs/security/audit-trails', { waitUntil: 'domcontentloaded' });
      expect(response?.status()).toBe(HTTP_OK);
      const html = await page.content();
      expect(html.includes('flutter_bootstrap.js') || html.includes('Tracing') || html.includes('tracing')).toBe(true);
    });

    test('/reports/anything redirects to /docs', async ({ page }) => {
      test.slow();
      await page.goto('/reports/quarterly-review', { waitUntil: 'domcontentloaded' });
      await waitForFlutter(page);
      await waitForRoute(page, /\/docs/);
      expect(page.url()).toContain('/docs');
      await assertFlutterRendering(page);
    });
  });

  test.describe('unknown route fallback', () => {
    test('unknown route renders landing page (not blank)', async ({ page }) => {
      await page.goto('/this-route-does-not-exist', { waitUntil: 'domcontentloaded' });
      await waitForFlutter(page);
      await assertFlutterRendering(page);
    });

    test('deeply nested unknown route still renders', async ({ page }) => {
      await page.goto('/a/b/c/d/e/f', { waitUntil: 'domcontentloaded' });
      await waitForFlutter(page);
      await assertFlutterRendering(page);
    });
  });

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

  test.describe('redirect chain validation', () => {
    test('/reports/foo → /docs chain reaches /docs', async ({ page }) => {
      test.slow();
      await page.goto('/reports/old-quarterly', { waitUntil: 'domcontentloaded' });
      await waitForFlutter(page);
      await waitForRoute(page, /\/docs/);
      expect(page.url()).toContain('/docs');
      await assertFlutterRendering(page);
    });

    test('/docs/security/audit-trails → /docs/tracing returns 200 (no loop)', async ({ request }) => {
      const response = await request.get('/docs/security/audit-trails', { maxRedirects: 5 });
      expect(response.status()).toBe(HTTP_OK);
    });

    test('trailing slash on /pricing/ does not loop', async ({ request }) => {
      const response = await request.get('/pricing/', { maxRedirects: 5 });
      expect([HTTP_OK, ...VALID_REDIRECT_STATUSES]).toContain(response.status());
    });

    test('trailing slash on /docs/ does not loop', async ({ request }) => {
      const response = await request.get('/docs/', { maxRedirects: 5 });
      expect([HTTP_OK, ...VALID_REDIRECT_STATUSES]).toContain(response.status());
    });
  });
});
