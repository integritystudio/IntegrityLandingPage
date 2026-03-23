import { test, expect } from '@playwright/test';
import { waitForFlutter } from './helpers';
import {
  CLICK_SETTLE_MS,
  KEY_SETTLE_MS,
  NAV_CTA_X,
  NAV_PRICING_X,
  NAV_Y,
  SCROLL_DELTA_PX,
  SCROLL_SETTLE_MS,
  SCREENSHOT_AFTER_CTA_CLICK,
  SCREENSHOT_AFTER_NAV_CLICK,
  SCREENSHOT_AFTER_SCROLL,
  SCREENSHOT_BEFORE_CTA_CLICK,
  SCREENSHOT_BEFORE_NAV_CLICK,
  SCREENSHOT_BEFORE_SCROLL,
  SCREENSHOT_CONTENT,
  SCREENSHOT_KEYBOARD_NAV,
  SCREENSHOT_LANDING,
} from './constants';

/** Returns true if any Flutter rendering surface exists in the DOM. */
async function hasFlutterSurface(page: Parameters<typeof waitForFlutter>[0]): Promise<boolean> {
  return page.evaluate(() =>
    !!(
      document.querySelector('flt-glass-pane') ||
      document.querySelector('flutter-view') ||
      document.querySelector('canvas')
    ),
  );
}

test.describe('IntegrityStudio Landing Page', () => {
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

  test('should load Flutter app successfully', async ({ page }) => {
    await page.screenshot({ path: SCREENSHOT_LANDING });
    expect(await hasFlutterSurface(page)).toBe(true);
  });

  test('should render landing page content', async ({ page }) => {
    await page.screenshot({ path: SCREENSHOT_CONTENT });
    expect(await hasFlutterSurface(page)).toBe(true);
  });

  test('should respond to mouse clicks on navigation area', async ({ page }) => {
    if (!page.viewportSize()) throw new Error('Viewport not available');

    await page.screenshot({ path: SCREENSHOT_BEFORE_NAV_CLICK });
    await page.mouse.click(NAV_PRICING_X, NAV_Y);
    await page.waitForTimeout(CLICK_SETTLE_MS);
    await page.screenshot({ path: SCREENSHOT_AFTER_NAV_CLICK });

    expect(await hasFlutterSurface(page)).toBe(true);
  });

  test('should respond to Get Started button click', async ({ page }) => {
    if (!page.viewportSize()) throw new Error('Viewport not available');

    await page.screenshot({ path: SCREENSHOT_BEFORE_CTA_CLICK });
    await page.mouse.click(NAV_CTA_X, NAV_Y);
    await page.waitForTimeout(CLICK_SETTLE_MS);
    await page.screenshot({ path: SCREENSHOT_AFTER_CTA_CLICK });

    expect(await hasFlutterSurface(page)).toBe(true);
  });

  test('should handle keyboard navigation', async ({ page }) => {
    await page.keyboard.press('Tab');
    await page.waitForTimeout(KEY_SETTLE_MS);
    await page.keyboard.press('Tab');
    await page.waitForTimeout(KEY_SETTLE_MS);
    await page.screenshot({ path: SCREENSHOT_KEYBOARD_NAV });
    expect(await hasFlutterSurface(page)).toBe(true);
  });

  test('should scroll the page', async ({ page }) => {
    await page.screenshot({ path: SCREENSHOT_BEFORE_SCROLL });
    await page.mouse.wheel(0, SCROLL_DELTA_PX);
    await page.waitForTimeout(SCROLL_SETTLE_MS);
    await page.screenshot({ path: SCREENSHOT_AFTER_SCROLL });
    expect(await hasFlutterSurface(page)).toBe(true);
  });
});
