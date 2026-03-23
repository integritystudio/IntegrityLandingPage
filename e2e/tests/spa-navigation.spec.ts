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
 */
test.describe('SPA Navigation', () => {
  const consoleErrors: string[] = [];

  test.beforeEach(async ({ page, browserName }) => {
    test.skip(browserName !== 'chromium', 'Flutter CanvasKit requires Chromium');
    consoleErrors.length = 0;

    page.on('console', (msg) => {
      if (msg.type() === 'error') consoleErrors.push(msg.text());
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
    test.slow();
    await navigateAndWaitForFlutter(page, '/pricing');
    await navigateAndWaitForFlutter(page, '/contact');

    await page.goBack();
    await waitForRoute(page, /\/pricing/);
    expect(page.url()).toContain('/pricing');

    await page.goForward();
    await waitForRoute(page, /\/contact/);
    expect(page.url()).toContain('/contact');
  });

  test('page refresh maintains current route', async ({ page }) => {
    test.slow();
    await navigateAndWaitForFlutter(page, '/pricing');
    await page.reload();
    await waitForFlutter(page);
    expect(page.url()).toContain('/pricing');
    await assertFlutterRendering(page);
  });

  test('deep link to /eu-ai-act works', async ({ page }) => {
    await navigateAndWaitForFlutter(page, '/eu-ai-act');
    expect(page.url()).toContain('/eu-ai-act');
    await assertFlutterRendering(page);
  });

  test('app remains functional after multiple navigations', async ({ page }) => {
    test.slow();
    for (const route of ['/pricing', '/contact', '/about', '/features', '/']) {
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
    const response = await page.goto('/pricing/', { waitUntil: 'domcontentloaded' });
    expect(response?.status()).toBe(200);
    await waitForFlutter(page);
    await assertFlutterRendering(page);
  });

  test('query parameters are preserved', async ({ page }) => {
    await page.goto('/demo?source=test&campaign=e2e', { waitUntil: 'domcontentloaded' });
    await waitForFlutter(page);
    expect(page.url()).toContain('source=test');
    expect(page.url()).toContain('campaign=e2e');
  });

  test('hash fragments are handled', async ({ page }) => {
    await page.goto('/pricing#enterprise', { waitUntil: 'domcontentloaded' });
    await waitForFlutter(page);
    await assertFlutterRendering(page);
  });
});

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
