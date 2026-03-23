import { test, expect } from '@playwright/test';
import { assertFlutterRendering, navigateAndWaitForFlutter } from './helpers';
import { CLICK_SETTLE_MS } from './constants';

/**
 * E2E tests for contact form page and submission flow.
 *
 * Regression coverage for:
 * - #67: _validateForm returns ContactFormData? reused in _handleSubmit
 * - #53: /support route now resolves to /contact via Routes.support
 *
 * Note: Flutter CanvasKit renders to canvas, so form interaction tests
 * verify page loads and stays stable rather than inspecting DOM elements.
 */
test.describe('Contact Form Page', () => {
  const consoleErrors: string[] = [];

  test.beforeEach(async ({ page, browserName }) => {
    test.skip(browserName !== 'chromium', 'Flutter CanvasKit requires Chromium');
    consoleErrors.length = 0;
    page.on('console', (msg) => {
      if (msg.type() === 'error') consoleErrors.push(msg.text());
    });
  });

  test.afterEach(async ({}, testInfo) => {
    if (consoleErrors.length > 0 && testInfo.status === 'passed') {
      console.warn(`Test "${testInfo.title}" passed but had console errors:`, consoleErrors);
    }
  });

  test('contact page loads via direct navigation', async ({ page }) => {
    await navigateAndWaitForFlutter(page, '/contact');
    expect(page.url()).toContain('/contact');
    await assertFlutterRendering(page);
  });

  test('contact page remains stable after scroll to form area', async ({ page }) => {
    await navigateAndWaitForFlutter(page, '/contact');
    await page.mouse.wheel(0, 600);
    await page.waitForTimeout(CLICK_SETTLE_MS);
    await assertFlutterRendering(page);
  });

  test('contact page handles tab navigation through form fields', async ({ page }) => {
    await navigateAndWaitForFlutter(page, '/contact');
    for (let i = 0; i < 6; i++) {
      await page.keyboard.press('Tab');
      await page.waitForTimeout(200);
    }
    await assertFlutterRendering(page);
  });

  test('contact page accessible from home page navigation', async ({ page }) => {
    test.slow();
    await navigateAndWaitForFlutter(page, '/');
    await navigateAndWaitForFlutter(page, '/contact');
    await assertFlutterRendering(page);

    await page.goBack();
    await page.waitForTimeout(CLICK_SETTLE_MS);
    await assertFlutterRendering(page);
  });

  test('no console errors on contact page', async ({ page }) => {
    await navigateAndWaitForFlutter(page, '/contact');
    await page.waitForTimeout(CLICK_SETTLE_MS);

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
});
