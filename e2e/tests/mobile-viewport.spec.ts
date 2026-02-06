import { test, expect, devices } from '@playwright/test';
import { waitForFlutter, assertFlutterRendering } from './helpers';

/**
 * E2E tests for mobile viewport behavior.
 *
 * Validates that the Flutter web app loads and functions correctly
 * on mobile device viewports. Tests responsive behavior critical
 * for enterprise users accessing the site on mobile devices.
 */
test.describe('Mobile Viewport', () => {
  const mobileViewports = [
    { name: 'iPhone 13', ...devices['iPhone 13'] },
    { name: 'Pixel 5', ...devices['Pixel 5'] },
    { name: 'iPad Mini', ...devices['iPad Mini'] },
  ];

  for (const device of mobileViewports) {
    test.describe(`${device.name}`, () => {
      test.use({ viewport: device.viewport, userAgent: device.userAgent });

      test('homepage loads on mobile viewport', async ({ page }) => {
        const response = await page.goto('/', {
          waitUntil: 'domcontentloaded',
        });

        expect(response?.status()).toBe(200);
        await waitForFlutter(page);
        await assertFlutterRendering(page);
      });

      test('pricing page loads on mobile viewport', async ({ page }) => {
        const response = await page.goto('/pricing', {
          waitUntil: 'domcontentloaded',
        });

        expect(response?.status()).toBe(200);
        await waitForFlutter(page);
        await assertFlutterRendering(page);
      });

      test('contact page loads on mobile viewport', async ({ page }) => {
        const response = await page.goto('/contact', {
          waitUntil: 'domcontentloaded',
        });

        expect(response?.status()).toBe(200);
        await waitForFlutter(page);
        await assertFlutterRendering(page);
      });
    });
  }

  test.describe('viewport meta tag', () => {
    test('has correct viewport meta for mobile', async ({ request }) => {
      const response = await request.get('/');
      const html = await response.text();

      expect(html).toContain('name="viewport"');
      expect(html).toContain('width=device-width');
      expect(html).toContain('initial-scale=1.0');
    });
  });

  test.describe('touch interactions', () => {
    test.use({ ...devices['iPhone 13'] });

    test('scrolling works on mobile', async ({ page }) => {
      await page.goto('/');
      await waitForFlutter(page);

      // Simulate mobile scroll via touch gestures
      await page.touchscreen.tap(200, 400);
      await page.evaluate(() => window.scrollBy(0, 500));

      // App should still be functional after scroll
      await assertFlutterRendering(page);
    });
  });
});
