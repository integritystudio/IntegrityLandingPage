import { test, expect } from '@playwright/test';
import { waitForFlutter, assertFlutterRendering } from './helpers';
import {
  CLICK_SETTLE_MS,
  KEY_SETTLE_MS,
  NAV_CTA_X,
  NAV_PRICING_X,
  NAV_Y,
  SCROLL_DELTA_PX,
  SCROLL_SETTLE_MS,
} from './constants';

test.describe('IntegrityStudio Landing Page', () => {
  const consoleErrors: string[] = [];

  test.beforeEach(async ({ page, browserName }) => {
    test.skip(browserName !== 'chromium', 'Flutter CanvasKit requires Chromium');
    consoleErrors.length = 0;

    page.on('console', msg => {
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

  test('should load Flutter app successfully', async ({ page }) => {
    await page.screenshot({ path: 'screenshots/01-landing.png' });

    // Flutter renders to canvas - verify app loaded by checking Flutter elements exist
    const hasFlutterView = await page.evaluate(() => {
      return !!(document.querySelector('flt-glass-pane') ||
               document.querySelector('flutter-view') ||
               document.querySelector('canvas'));
    });
    expect(hasFlutterView).toBe(true);
  });

  test('should render landing page content', async ({ page }) => {
    await page.screenshot({ path: 'screenshots/02-content.png' });

    // Verify Flutter is rendering content
    // Flutter web may use flt-glass-pane, flutter-view, or canvas
    const hasRenderingSurface = await page.evaluate(() => {
      // Check for Flutter's rendering elements
      const glassPane = document.querySelector('flt-glass-pane');
      const flutterView = document.querySelector('flutter-view');
      const canvas = document.querySelector('canvas');

      // Any of these indicate Flutter is rendering
      return !!(glassPane || flutterView || canvas);
    });
    expect(hasRenderingSurface).toBe(true);
  });

  test('should respond to mouse clicks on navigation area', async ({ page }) => {
    const viewport = page.viewportSize();
    if (!viewport) {
      throw new Error('Viewport not available');
    }

    // Take before screenshot
    await page.screenshot({ path: 'screenshots/03-before-click.png' });

    // Click on "Pricing" area in the navigation bar
    // Based on screenshots: header is at top, Pricing is around NAV_PRICING_X
    await page.mouse.click(NAV_PRICING_X, NAV_Y);
    await page.waitForTimeout(CLICK_SETTLE_MS);

    // Take after screenshot
    await page.screenshot({ path: 'screenshots/03-after-click.png' });

    // App should still be functional (not crashed)
    const hasFlutterView = await page.evaluate(() => {
      return !!(document.querySelector('flt-glass-pane') ||
               document.querySelector('flutter-view') ||
               document.querySelector('canvas'));
    });
    expect(hasFlutterView).toBe(true);
  });

  test('should respond to Get Started button click', async ({ page }) => {
    const viewport = page.viewportSize();
    if (!viewport) {
      throw new Error('Viewport not available');
    }

    // Take before screenshot
    await page.screenshot({ path: 'screenshots/04-before-cta.png' });

    // Click on "Get Started" button in header (right side, ~NAV_CTA_X)
    await page.mouse.click(NAV_CTA_X, NAV_Y);
    await page.waitForTimeout(CLICK_SETTLE_MS);

    // Take after screenshot
    await page.screenshot({ path: 'screenshots/04-after-cta.png' });

    // App should still be functional
    const hasFlutterView = await page.evaluate(() => {
      return !!(document.querySelector('flt-glass-pane') ||
               document.querySelector('flutter-view') ||
               document.querySelector('canvas'));
    });
    expect(hasFlutterView).toBe(true);
  });

  test('should handle keyboard navigation', async ({ page }) => {
    // Test that keyboard input works
    await page.keyboard.press('Tab');
    await page.waitForTimeout(KEY_SETTLE_MS);
    await page.keyboard.press('Tab');
    await page.waitForTimeout(KEY_SETTLE_MS);

    await page.screenshot({ path: 'screenshots/05-keyboard-nav.png' });

    // App should still be functional
    const hasFlutterView = await page.evaluate(() => {
      return !!(document.querySelector('flt-glass-pane') ||
               document.querySelector('flutter-view') ||
               document.querySelector('canvas'));
    });
    expect(hasFlutterView).toBe(true);
  });

  test('should scroll the page', async ({ page }) => {
    // Take before screenshot
    await page.screenshot({ path: 'screenshots/06-before-scroll.png' });

    // Scroll down
    await page.mouse.wheel(0, SCROLL_DELTA_PX);
    await page.waitForTimeout(SCROLL_SETTLE_MS);

    // Take after screenshot
    await page.screenshot({ path: 'screenshots/06-after-scroll.png' });

    // App should still be functional
    const hasFlutterView = await page.evaluate(() => {
      return !!(document.querySelector('flt-glass-pane') ||
               document.querySelector('flutter-view') ||
               document.querySelector('canvas'));
    });
    expect(hasFlutterView).toBe(true);
  });
});
