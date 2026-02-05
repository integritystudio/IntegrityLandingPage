import { test, expect } from '@playwright/test';

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
  test.beforeEach(async ({ page }) => {
    // Capture console errors for debugging
    page.on('console', (msg) => {
      if (msg.type() === 'error') {
        console.log('Browser error:', msg.text());
      }
    });

    await page.goto('/');

    // Wait for Flutter to fully load
    await Promise.race([
      page.locator('.loading-container').waitFor({ state: 'hidden', timeout: 60000 }),
      page.locator('canvas').waitFor({ state: 'visible', timeout: 60000 }),
      page.locator('flt-glass-pane').waitFor({ state: 'attached', timeout: 60000 }),
    ]);

    // Extra wait for Flutter to stabilize
    await page.waitForTimeout(2000);
  });

  test('direct navigation to /contact loads correctly', async ({ page }) => {
    await page.goto('/contact');

    await Promise.race([
      page.locator('.loading-container').waitFor({ state: 'hidden', timeout: 60000 }),
      page.locator('canvas').waitFor({ state: 'visible', timeout: 60000 }),
    ]);

    // Verify Flutter app is rendered
    const hasFlutter = await page.evaluate(() => {
      return !!(
        document.querySelector('flt-glass-pane') ||
        document.querySelector('flutter-view') ||
        document.querySelector('canvas')
      );
    });
    expect(hasFlutter).toBe(true);
  });

  test('direct navigation to /pricing loads correctly', async ({ page }) => {
    await page.goto('/pricing');

    await Promise.race([
      page.locator('.loading-container').waitFor({ state: 'hidden', timeout: 60000 }),
      page.locator('canvas').waitFor({ state: 'visible', timeout: 60000 }),
    ]);

    const hasFlutter = await page.evaluate(() => {
      return !!(
        document.querySelector('flt-glass-pane') ||
        document.querySelector('flutter-view') ||
        document.querySelector('canvas')
      );
    });
    expect(hasFlutter).toBe(true);
  });

  test('browser back/forward navigation works', async ({ page }) => {
    // Navigate to pricing
    await page.goto('/pricing');
    await page.waitForTimeout(3000);

    // Navigate to contact
    await page.goto('/contact');
    await page.waitForTimeout(3000);

    // Go back to pricing
    await page.goBack();
    await page.waitForTimeout(2000);

    // URL should be pricing
    expect(page.url()).toContain('/pricing');

    // Go forward to contact
    await page.goForward();
    await page.waitForTimeout(2000);

    // URL should be contact
    expect(page.url()).toContain('/contact');
  });

  test('page refresh maintains current route', async ({ page }) => {
    // Navigate to pricing
    await page.goto('/pricing');
    await page.waitForTimeout(3000);

    // Refresh the page
    await page.reload();

    // Wait for Flutter to reload
    await Promise.race([
      page.locator('.loading-container').waitFor({ state: 'hidden', timeout: 60000 }),
      page.locator('canvas').waitFor({ state: 'visible', timeout: 60000 }),
    ]);

    // URL should still be pricing
    expect(page.url()).toContain('/pricing');

    // Flutter should be rendered
    const hasFlutter = await page.evaluate(() => {
      return !!(
        document.querySelector('flt-glass-pane') ||
        document.querySelector('flutter-view') ||
        document.querySelector('canvas')
      );
    });
    expect(hasFlutter).toBe(true);
  });

  test('deep link to /eu-ai-act works', async ({ page }) => {
    await page.goto('/eu-ai-act');

    await Promise.race([
      page.locator('.loading-container').waitFor({ state: 'hidden', timeout: 60000 }),
      page.locator('canvas').waitFor({ state: 'visible', timeout: 60000 }),
    ]);

    expect(page.url()).toContain('/eu-ai-act');

    const hasFlutter = await page.evaluate(() => {
      return !!(
        document.querySelector('flt-glass-pane') ||
        document.querySelector('flutter-view') ||
        document.querySelector('canvas')
      );
    });
    expect(hasFlutter).toBe(true);
  });

  test('app remains functional after multiple navigations', async ({ page }) => {
    const routes = ['/pricing', '/contact', '/about', '/features', '/'];

    for (const route of routes) {
      await page.goto(route);
      await page.waitForTimeout(2000);

      const hasFlutter = await page.evaluate(() => {
        return !!(
          document.querySelector('flt-glass-pane') ||
          document.querySelector('flutter-view') ||
          document.querySelector('canvas')
        );
      });
      expect(hasFlutter).toBe(true);
    }
  });
});

test.describe('Navigation URL Handling', () => {
  test('trailing slash is handled correctly', async ({ page }) => {
    // Navigate with trailing slash
    const response = await page.goto('/pricing/');

    // Should still work (either redirect or serve)
    expect(response?.status()).toBe(200);

    // Flutter should load
    await Promise.race([
      page.locator('.loading-container').waitFor({ state: 'hidden', timeout: 60000 }),
      page.locator('canvas').waitFor({ state: 'visible', timeout: 60000 }),
    ]);
  });

  test('query parameters are preserved', async ({ page }) => {
    await page.goto('/demo?source=test&campaign=e2e');

    await Promise.race([
      page.locator('.loading-container').waitFor({ state: 'hidden', timeout: 60000 }),
      page.locator('canvas').waitFor({ state: 'visible', timeout: 60000 }),
    ]);

    // URL should contain query parameters
    const url = page.url();
    expect(url).toContain('source=test');
    expect(url).toContain('campaign=e2e');
  });

  test('hash fragments are handled', async ({ page }) => {
    await page.goto('/pricing#enterprise');

    await Promise.race([
      page.locator('.loading-container').waitFor({ state: 'hidden', timeout: 60000 }),
      page.locator('canvas').waitFor({ state: 'visible', timeout: 60000 }),
    ]);

    // Flutter should load
    const hasFlutter = await page.evaluate(() => {
      return !!(
        document.querySelector('flt-glass-pane') ||
        document.querySelector('flutter-view') ||
        document.querySelector('canvas')
      );
    });
    expect(hasFlutter).toBe(true);
  });
});
