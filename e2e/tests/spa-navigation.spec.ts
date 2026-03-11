import { test, expect } from '@playwright/test';
import { waitForFlutter, assertFlutterRendering, navigateAndWaitForFlutter, waitForRoute } from './helpers';

/**
 * E2E tests for SPA navigation behavior.
 *
 * Validates that Flutter web app handles client-side navigation correctly:
 * - Navigation between pages without full reload
 * - Browser back/forward functionality
 * - Direct URL navigation
 * - Deep linking
 *
 * Critical for enterprise to ensure consistent navigation experience.
 */
test.describe('SPA Navigation', () => {
  // Collect console errors for debugging
  const consoleErrors: string[] = [];

  test.beforeEach(async ({ page, browserName }) => {
    test.skip(browserName !== 'chromium', 'Flutter CanvasKit requires Chromium');
    consoleErrors.length = 0; // Reset for each test

    page.on('console', (msg) => {
      if (msg.type() === 'error') {
        consoleErrors.push(msg.text());
      }
    });

    await page.goto('/', { waitUntil: 'domcontentloaded' });
    await waitForFlutter(page);
  });

  test.afterEach(async ({}, testInfo) => {
    if (consoleErrors.length > 0 && testInfo.status === 'passed') {
      console.warn(`Test "${testInfo.title}" passed but had console errors:`, consoleErrors);
    }
  });

  test('direct navigation to /contact loads correctly', async ({ page }) => {
    await navigateAndWaitForFlutter(page, '/contact');
    await assertFlutterRendering(page);
  });

  test('direct navigation to /pricing loads correctly', async ({ page }) => {
    await navigateAndWaitForFlutter(page, '/pricing');
    await assertFlutterRendering(page);
  });

  test('browser back/forward navigation works', async ({ page }) => {
    test.slow(); // beforeEach + 2 navigations + back/forward
    // Navigate to pricing
    await navigateAndWaitForFlutter(page, '/pricing');

    // Navigate to contact
    await navigateAndWaitForFlutter(page, '/contact');

    // Go back to pricing
    await page.goBack();
    await waitForRoute(page, /\/pricing/);

    // URL should be pricing
    expect(page.url()).toContain('/pricing');

    // Go forward to contact
    await page.goForward();
    await waitForRoute(page, /\/contact/);

    // URL should be contact
    expect(page.url()).toContain('/contact');
  });

  test('page refresh maintains current route', async ({ page }) => {
    test.slow(); // beforeEach + navigation + reload
    // Navigate to pricing
    await navigateAndWaitForFlutter(page, '/pricing');

    // Refresh the page
    await page.reload();
    await waitForFlutter(page);

    // URL should still be pricing
    expect(page.url()).toContain('/pricing');

    // Flutter should be rendered
    await assertFlutterRendering(page);
  });

  test('deep link to /eu-ai-act works', async ({ page }) => {
    await navigateAndWaitForFlutter(page, '/eu-ai-act');
    expect(page.url()).toContain('/eu-ai-act');
    await assertFlutterRendering(page);
  });

  test('app remains functional after multiple navigations', async ({ page }) => {
    test.slow(); // 5 full page navigations, each reloads Flutter
    const routes = ['/pricing', '/contact', '/about', '/features', '/'];

    for (const route of routes) {
      await navigateAndWaitForFlutter(page, route);
      await assertFlutterRendering(page);
    }
  });
});

test.describe('Navigation URL Handling', () => {
  test.beforeEach(async ({ browserName }) => {
    test.skip(browserName !== 'chromium', 'Flutter CanvasKit requires Chromium');
  });

  test('trailing slash is handled correctly', async ({ page }) => {
    // Navigate with trailing slash
    const response = await page.goto('/pricing/', { waitUntil: 'domcontentloaded' });

    // Should still work (either redirect or serve)
    expect(response?.status()).toBe(200);

    // Flutter should load
    await waitForFlutter(page);
    await assertFlutterRendering(page);
  });

  test('query parameters are preserved', async ({ page }) => {
    await page.goto('/demo?source=test&campaign=e2e', { waitUntil: 'domcontentloaded' });
    await waitForFlutter(page);

    // URL should contain query parameters
    const url = page.url();
    expect(url).toContain('source=test');
    expect(url).toContain('campaign=e2e');
  });

  test('hash fragments are handled', async ({ page }) => {
    await page.goto('/pricing#enterprise', { waitUntil: 'domcontentloaded' });
    await waitForFlutter(page);
    await assertFlutterRendering(page);
  });
});

// ---------------------------------------------------------------------------
// Anchor / deep-link navigation within doc sections (#119)
// ---------------------------------------------------------------------------

test.describe('Doc Section Anchor Navigation', () => {
  test.beforeEach(async ({ browserName }) => {
    test.skip(browserName !== 'chromium', 'Flutter CanvasKit requires Chromium');
  });

  const docAnchors = [
    '/docs/quickstart#installation',
    '/docs/quickstart#overview',
    '/api#endpoints',
    '/docs#getting-started',
  ];

  for (const anchor of docAnchors) {
    test(`${anchor} loads without error`, async ({ page }) => {
      await page.goto(anchor, { waitUntil: 'domcontentloaded' });
      await waitForFlutter(page);
      await assertFlutterRendering(page);
    });
  }

  test('anchor in URL is preserved on load', async ({ page }) => {
    await page.goto('/pricing#enterprise', { waitUntil: 'domcontentloaded' });
    await waitForFlutter(page);
    // URL hash should still contain the fragment
    expect(page.url()).toContain('#enterprise');
    await assertFlutterRendering(page);
  });

  test('anchor navigation does not break back button', async ({ page }) => {
    test.slow();
    await page.goto('/pricing', { waitUntil: 'domcontentloaded' });
    await waitForFlutter(page);

    await page.goto('/pricing#enterprise', { waitUntil: 'domcontentloaded' });
    await page.goBack();
    await waitForFlutter(page);

    expect(page.url()).toContain('/pricing');
    await assertFlutterRendering(page);
  });
});
