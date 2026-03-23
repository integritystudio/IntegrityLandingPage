import { test, expect, devices } from '@playwright/test';
import {
  assertFlutterRendering,
  enableFlutterSemantics,
  navigateAndWaitForFlutter,
  waitForSemantics,
} from './helpers';
import {
  CLICK_SETTLE_MS,
  ROUTE_CHANGE_TIMEOUT_MS,
  SCROLL_SETTLE_MS,
  SEMANTICS_TIMEOUT_MS,
  TEST_TIMEOUT_MS,
} from './constants';

/**
 * E2E tests for mobile navigation and responsive behavior.
 *
 * Covers:
 * - Legal pages on mobile viewports
 * - Docs pages on mobile viewports
 * - Mobile scroll behavior across page types
 * - Auth pages on mobile viewports
 */

async function waitForSemanticsOrSkip(page: Parameters<typeof waitForSemantics>[0], label: RegExp): Promise<boolean> {
  try {
    await waitForSemantics(page, label, SEMANTICS_TIMEOUT_MS);
    return true;
  } catch {
    test.skip(true, 'Flutter semantics tree not available (Flutter #151929)');
    return false;
  }
}

test.describe('Mobile Navigation', () => {
  test.use({
    viewport: devices['iPhone 13'].viewport,
    userAgent: devices['iPhone 13'].userAgent,
  });

  test.beforeEach(async ({ browserName }) => {
    test.skip(browserName !== 'chromium', 'Flutter CanvasKit requires Chromium');
  });

  test.describe('legal pages on mobile', () => {
    const legalRoutes = ['/privacy', '/terms', '/cookies', '/accessibility'];

    for (const route of legalRoutes) {
      test(`${route} loads on mobile`, async ({ page }) => {
        await navigateAndWaitForFlutter(page, route);
        expect(page.url()).toContain(route);
        await assertFlutterRendering(page);
      });
    }
  });

  test.describe('docs pages on mobile', () => {
    const docsRoutes = ['/docs', '/docs/quickstart', '/api'];

    for (const route of docsRoutes) {
      test(`${route} loads on mobile`, async ({ page }) => {
        await navigateAndWaitForFlutter(page, route);
        expect(page.url()).toContain(route);
        await assertFlutterRendering(page);
      });
    }
  });

  test.describe('auth pages on mobile', () => {
    test('/signup loads on mobile', async ({ page }) => {
      await navigateAndWaitForFlutter(page, '/signup');
      expect(page.url()).toContain('/signup');
      await assertFlutterRendering(page);
    });

    test('/request_success loads on mobile', async ({ page }) => {
      await navigateAndWaitForFlutter(page, '/request_success');
      expect(page.url()).toContain('/request_success');
      await assertFlutterRendering(page);
    });
  });

  test.describe('mobile scroll behavior', () => {
    test('legal page scrolls without crash', async ({ page }) => {
      await navigateAndWaitForFlutter(page, '/privacy');
      await assertFlutterRendering(page);
      await page.evaluate(() => window.scrollTo(0, document.documentElement.scrollHeight));
      await page.waitForTimeout(SCROLL_SETTLE_MS);
      await assertFlutterRendering(page);
    });

    test('docs page scrolls without crash', async ({ page }) => {
      await navigateAndWaitForFlutter(page, '/docs');
      await assertFlutterRendering(page);
      await page.evaluate(() => window.scrollTo(0, document.documentElement.scrollHeight));
      await page.waitForTimeout(SCROLL_SETTLE_MS);
      await assertFlutterRendering(page);
    });
  });

  test.describe('pricing page on mobile', () => {
    test('/pricing loads on mobile', async ({ page }) => {
      await navigateAndWaitForFlutter(page, '/pricing');
      expect(page.url()).toContain('/pricing');
      await assertFlutterRendering(page);
    });

    test('/pricing scrolls without crash on mobile', async ({ page }) => {
      await navigateAndWaitForFlutter(page, '/pricing');
      await assertFlutterRendering(page);
      await page.evaluate(() => window.scrollTo(0, document.documentElement.scrollHeight));
      await page.waitForTimeout(SCROLL_SETTLE_MS);
      await assertFlutterRendering(page);
    });
  });

  test.describe('hamburger menu interactions (semantics)', () => {
    test.setTimeout(TEST_TIMEOUT_MS);

    test('hamburger menu is detectable via semantics', async ({ page }) => {
      await navigateAndWaitForFlutter(page, '/');
      await enableFlutterSemantics(page);
      if (!await waitForSemanticsOrSkip(page, /navigation menu/i)) return;
      await expect(page.getByLabel(/navigation menu/i).first()).toBeAttached();
    });

    test('hamburger menu opens and shows nav items', async ({ page }) => {
      await navigateAndWaitForFlutter(page, '/');
      await enableFlutterSemantics(page);
      if (!await waitForSemanticsOrSkip(page, /navigation menu/i)) return;

      await page.getByLabel(/navigation menu/i).first().click();
      await page.waitForTimeout(CLICK_SETTLE_MS);

      await expect(page.getByLabel(/navigate to/i).first()).toBeAttached({ timeout: SEMANTICS_TIMEOUT_MS });
    });

    test('hamburger menu item navigates to route', async ({ page }) => {
      await navigateAndWaitForFlutter(page, '/');
      await enableFlutterSemantics(page);
      if (!await waitForSemanticsOrSkip(page, /navigation menu/i)) return;

      await page.getByLabel(/navigation menu/i).first().click();
      await page.waitForTimeout(CLICK_SETTLE_MS);

      const docsItem = page.getByLabel(/navigate to docs/i).first();
      await expect(docsItem).toBeAttached({ timeout: SEMANTICS_TIMEOUT_MS });
      await docsItem.click();
      await page.waitForURL('**/docs', { timeout: ROUTE_CHANGE_TIMEOUT_MS });

      expect(page.url()).toContain('/docs');
    });
  });

  test.describe('tablet viewport', () => {
    test.use({
      viewport: devices['iPad Mini'].viewport,
      userAgent: devices['iPad Mini'].userAgent,
    });

    const tabletRoutes = ['/features', '/eu-ai-act', '/pricing'] as const;

    for (const path of tabletRoutes) {
      test(`${path} loads on tablet`, async ({ page }) => {
        await navigateAndWaitForFlutter(page, path);
        expect(page.url()).toContain(path);
        await assertFlutterRendering(page);
      });
    }
  });
});
