import { test, expect, devices } from '@playwright/test';
import { waitForFlutter, assertFlutterRendering } from './helpers';

/**
 * E2E tests for mobile viewport behavior.
 *
 * Validates that the Flutter web app loads and functions correctly
 * on mobile device viewports.
 */
test.describe('Mobile Viewport', () => {
  const mobileViewports = [
    { name: 'iPhone 13', ...devices['iPhone 13'] },
    { name: 'Pixel 5', ...devices['Pixel 5'] },
    { name: 'iPad Mini', ...devices['iPad Mini'] },
  ];

  const mobileRoutes = ['/', '/pricing', '/contact'] as const;

  for (const device of mobileViewports) {
    test.describe(device.name, () => {
      test.use({ viewport: device.viewport, userAgent: device.userAgent });

      for (const path of mobileRoutes) {
        test(`${path} loads on ${device.name} viewport`, async ({ page, browserName }) => {
          test.skip(browserName !== 'chromium', 'Flutter CanvasKit requires Chromium');
          const response = await page.goto(path, { waitUntil: 'domcontentloaded' });
          expect(response?.status()).toBe(200);
          await waitForFlutter(page);
          await assertFlutterRendering(page);
        });
      }
    });
  }

  test.describe('viewport meta tag', () => {
    test('has correct viewport meta for mobile', async ({ request }) => {
      const html = await (await request.get('/')).text();
      expect(html).toContain('name="viewport"');
      expect(html).toContain('width=device-width');
      expect(html).toContain('initial-scale=1.0');
    });
  });

  test.describe('touch interactions', () => {
    test.use({
      viewport: devices['iPhone 13'].viewport,
      userAgent: devices['iPhone 13'].userAgent,
      hasTouch: true,
    });

    test('scrolling works on mobile', async ({ page, browserName }) => {
      test.skip(browserName !== 'chromium', 'Flutter CanvasKit requires Chromium');
      await page.goto('/', { waitUntil: 'domcontentloaded' });
      await waitForFlutter(page);
      await page.evaluate(() => window.scrollBy(0, 500));
      await assertFlutterRendering(page);
    });
  });
});
