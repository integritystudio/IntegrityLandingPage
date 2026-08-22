import { test, expect } from '@playwright/test';
import { navigateAndWaitForFlutter, assertFlutterRendering } from './helpers';

/**
 * E2E tests for authentication-related routes and query parameter handling.
 *
 * Covers:
 * - /request_success and /request_failure (post-form-submission pages)
 * - /signup with tier query parameter variations
 * - /support (help center) route
 */

test.describe('Auth & Post-Submission Flows', () => {
  test.beforeEach(async ({ browserName }) => {
    test.skip(browserName !== 'chromium', 'Flutter CanvasKit requires Chromium');
  });

  test.describe('Request Success Page', () => {
    test('/request_success loads and renders Flutter', async ({ page }) => {
      await navigateAndWaitForFlutter(page, '/request_success');
      expect(page.url()).toContain('/request_success');
      await assertFlutterRendering(page);
    });

    test('/request_success returns 200', async ({ request }) => {
      expect((await request.get('/request_success')).status()).toBe(200);
    });
  });

  test.describe('Request Failure Page', () => {
    test('/request_failure loads and renders Flutter', async ({ page }) => {
      await navigateAndWaitForFlutter(page, '/request_failure');
      expect(page.url()).toContain('/request_failure');
      await assertFlutterRendering(page);
    });

    test('/request_failure returns 200', async ({ request }) => {
      expect((await request.get('/request_failure')).status()).toBe(200);
    });
  });

  test.describe('Signup Tier Variations', () => {
    const tiers = ['Starter', 'Professional', 'Enterprise'];

    for (const tier of tiers) {
      test(`/signup?tier=${tier} loads and preserves param`, async ({ page }) => {
        await navigateAndWaitForFlutter(page, `/signup?tier=${tier}`);
        expect(page.url()).toContain('/signup');
        expect(page.url()).toContain(`tier=${tier}`);
        await assertFlutterRendering(page);
      });
    }

    test('/signup with no tier defaults to starter', async ({ page }) => {
      await navigateAndWaitForFlutter(page, '/signup');
      expect(page.url()).toContain('/signup');
      await assertFlutterRendering(page);
    });

    test('/signup with unknown tier still renders', async ({ page }) => {
      await navigateAndWaitForFlutter(page, '/signup?tier=InvalidTier');
      expect(page.url()).toContain('/signup');
      await assertFlutterRendering(page);
    });
  });

  test.describe('Support Route', () => {
    test('/support loads and renders Flutter', async ({ page }) => {
      await navigateAndWaitForFlutter(page, '/support');
      expect(page.url()).toContain('/support');
      await assertFlutterRendering(page);
    });
  });
});
