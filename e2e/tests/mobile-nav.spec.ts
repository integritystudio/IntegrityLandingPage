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
 * Covers gaps identified in mobile testing:
 * - Legal pages on mobile viewports
 * - Docs pages on mobile viewports
 * - Mobile scroll behavior across page types
 * - Auth pages on mobile viewports
 */

test.describe('Mobile Navigation', () => {
  test.use({
    viewport: devices['iPhone 13'].viewport,
    userAgent: devices['iPhone 13'].userAgent,
  });

  test.beforeEach(async ({ browserName }) => {
    test.skip(browserName !== 'chromium', 'Flutter CanvasKit requires Chromium');
  });

  // -------------------------------------------------------------------------
  // Legal pages on mobile (previously untested on mobile viewports)
  // -------------------------------------------------------------------------

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

  // -------------------------------------------------------------------------
  // Docs pages on mobile (previously untested on mobile viewports)
  // -------------------------------------------------------------------------

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

  // -------------------------------------------------------------------------
  // Auth pages on mobile (previously untested on mobile viewports)
  // -------------------------------------------------------------------------

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

  // -------------------------------------------------------------------------
  // Mobile scroll on different page types
  // -------------------------------------------------------------------------

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

  // -------------------------------------------------------------------------
  // Pricing page on mobile (#110)
  // -------------------------------------------------------------------------

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

  // -------------------------------------------------------------------------
  // Hamburger menu interactions via semantics (#117)
  // -------------------------------------------------------------------------

  test.describe('hamburger menu interactions (semantics)', () => {
    test.setTimeout(TEST_TIMEOUT_MS);

    test('hamburger menu is detectable via semantics', async ({ page }) => {
      await navigateAndWaitForFlutter(page, '/');
      await enableFlutterSemantics(page);

      try {
        await waitForSemantics(page, /navigation menu/i, SEMANTICS_TIMEOUT_MS);
      } catch {
        test.skip(true, 'Flutter semantics tree not available (Flutter #151929)');
        return;
      }

      await expect(page.getByLabel(/navigation menu/i).first()).toBeAttached();
    });

    test('hamburger menu opens and shows nav items', async ({ page }) => {
      await navigateAndWaitForFlutter(page, '/');
      await enableFlutterSemantics(page);

      try {
        await waitForSemantics(page, /navigation menu/i, SEMANTICS_TIMEOUT_MS);
      } catch {
        test.skip(true, 'Flutter semantics tree not available (Flutter #151929)');
        return;
      }

      await page.getByLabel(/navigation menu/i).first().click();
      await page.waitForTimeout(CLICK_SETTLE_MS);

      const navItems = page.getByLabel(/navigate to/i);
      await expect(navItems.first()).toBeAttached({ timeout: SEMANTICS_TIMEOUT_MS });
    });

    test('hamburger menu item navigates to route', async ({ page }) => {
      await navigateAndWaitForFlutter(page, '/');
      await enableFlutterSemantics(page);

      try {
        await waitForSemantics(page, /navigation menu/i, SEMANTICS_TIMEOUT_MS);
      } catch {
        test.skip(true, 'Flutter semantics tree not available (Flutter #151929)');
        return;
      }

      await page.getByLabel(/navigation menu/i).first().click();
      await page.waitForTimeout(CLICK_SETTLE_MS);

      const docsItem = page.getByLabel(/navigate to docs/i).first();
      await expect(docsItem).toBeAttached({ timeout: SEMANTICS_TIMEOUT_MS });
      await docsItem.click();
      await page.waitForURL('**/docs', { timeout: ROUTE_CHANGE_TIMEOUT_MS });

      expect(page.url()).toContain('/docs');
    });
  });

  // -------------------------------------------------------------------------
  // Tablet viewport (iPad)
  // -------------------------------------------------------------------------

  test.describe('tablet viewport', () => {
    test.use({
      viewport: devices['iPad Mini'].viewport,
      userAgent: devices['iPad Mini'].userAgent,
    });

    test('/features loads on tablet', async ({ page }) => {
      await navigateAndWaitForFlutter(page, '/features');
      expect(page.url()).toContain('/features');
      await assertFlutterRendering(page);
    });

    test('/eu-ai-act loads on tablet', async ({ page }) => {
      await navigateAndWaitForFlutter(page, '/eu-ai-act');
      expect(page.url()).toContain('/eu-ai-act');
      await assertFlutterRendering(page);
    });

    test('/pricing loads on tablet', async ({ page }) => {
      await navigateAndWaitForFlutter(page, '/pricing');
      expect(page.url()).toContain('/pricing');
      await assertFlutterRendering(page);
    });
  });
});
