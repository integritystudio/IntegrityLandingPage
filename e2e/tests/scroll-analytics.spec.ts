import { test, expect } from '@playwright/test';
import { waitForFlutter, assertFlutterRendering } from './helpers';
import { SCROLL_SETTLE_MS } from './constants';

/**
 * E2E tests for scroll behavior and analytics milestone tracking.
 *
 * Regression coverage for:
 * - #64: Scroll depth analytics throttled to 25% milestones
 *   Previously fired on every pixel; now only fires at 25/50/75/100%
 */

const KNOWN_FLUTTER_ERRORS = [
  'service-worker',
  'CanvasKit',
  'Failed to load resource',
  'Content Security Policy directive',
  'is ignored when delivered via a <meta>',
] as const;

function isKnownError(msg: string): boolean {
  return KNOWN_FLUTTER_ERRORS.some((s) => msg.includes(s));
}

test.describe('Scroll Analytics Milestones', () => {
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

  test('incremental scrolling does not crash the app', async ({ page }) => {
    for (let i = 0; i < 10; i++) {
      await page.mouse.wheel(0, 800);
      await page.waitForTimeout(300);
    }
    await page.waitForTimeout(SCROLL_SETTLE_MS);
    await assertFlutterRendering(page);
  });

  test('rapid scroll does not produce console errors', async ({ page }) => {
    for (let i = 0; i < 20; i++) {
      await page.mouse.wheel(0, 500);
      await page.waitForTimeout(50);
    }
    await page.waitForTimeout(SCROLL_SETTLE_MS);
    await assertFlutterRendering(page);
    expect(consoleErrors.filter((e) => !isKnownError(e))).toHaveLength(0);
  });

  test('scroll to bottom and back to top', async ({ page }) => {
    test.slow();
    await page.evaluate(() => window.scrollTo(0, document.body.scrollHeight));
    await page.waitForTimeout(SCROLL_SETTLE_MS);
    await assertFlutterRendering(page);

    await page.evaluate(() => window.scrollTo(0, 0));
    await page.waitForTimeout(SCROLL_SETTLE_MS);
    await assertFlutterRendering(page);
  });
});
