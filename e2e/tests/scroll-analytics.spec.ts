import { test, expect } from '@playwright/test';
import { waitForFlutter, assertFlutterRendering } from './helpers';
import { SCROLL_SETTLE_MS } from './constants';

/**
 * E2E tests for scroll behavior and analytics milestone tracking.
 *
 * Regression coverage for:
 * - #64: Scroll depth analytics throttled to 25% milestones
 *   Previously fired on every pixel; now only fires at 25/50/75/100%
 *
 * Validates:
 * - Page remains stable through heavy scrolling
 * - No console errors during scroll
 * - Flutter rendering persists after scroll-to-bottom
 */
test.describe('Scroll Analytics Milestones', () => {
  const consoleErrors: string[] = [];

  test.beforeEach(async ({ page, browserName }) => {
    test.skip(browserName !== 'chromium', 'Flutter CanvasKit requires Chromium');
    consoleErrors.length = 0;

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
      console.warn(
        `Test "${testInfo.title}" passed but had console errors:`,
        consoleErrors,
      );
    }
  });

  test('incremental scrolling does not crash the app', async ({ page }) => {
    // Scroll in increments to trigger milestone boundaries (25%, 50%, 75%, 100%)
    for (let i = 0; i < 10; i++) {
      await page.mouse.wheel(0, 800);
      await page.waitForTimeout(300);
    }
    await page.waitForTimeout(SCROLL_SETTLE_MS);

    // App should still be functional after heavy scrolling
    await assertFlutterRendering(page);
  });

  test('rapid scroll does not produce console errors', async ({ page }) => {
    // Rapid scroll simulating fast mouse wheel
    for (let i = 0; i < 20; i++) {
      await page.mouse.wheel(0, 500);
      // Minimal delay to simulate rapid scrolling
      await page.waitForTimeout(50);
    }
    await page.waitForTimeout(SCROLL_SETTLE_MS);

    await assertFlutterRendering(page);

    // Filter out known Flutter/network/CSP warnings
    const realErrors = consoleErrors.filter(
      (e) =>
        !e.includes('service-worker') &&
        !e.includes('CanvasKit') &&
        !e.includes('Failed to load resource') &&
        !e.includes('Content Security Policy directive') &&
        !e.includes('is ignored when delivered via a <meta>'),
    );
    expect(realErrors).toHaveLength(0);
  });

  test('scroll to bottom and back to top', async ({ page }) => {
    test.slow(); // Full page scroll both directions

    // Scroll to bottom
    await page.evaluate(() => window.scrollTo(0, document.body.scrollHeight));
    await page.waitForTimeout(SCROLL_SETTLE_MS);
    await assertFlutterRendering(page);

    // Scroll back to top
    await page.evaluate(() => window.scrollTo(0, 0));
    await page.waitForTimeout(SCROLL_SETTLE_MS);
    await assertFlutterRendering(page);
  });
});
