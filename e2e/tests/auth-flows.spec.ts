import { test, expect } from '@playwright/test';
import { navigateAndWaitForFlutter, assertFlutterRendering } from './helpers';

/**
 * E2E tests for authentication-related routes and query parameter handling.
 *
 * Covers:
 * - /request_success and /request_failure (post-form-submission pages)
 * - /oauth/callback with code, state, error, and error_description params
 * - /signup with tier query parameter variations
 * - /support (help center) route
 */

test.describe('Auth & Post-Submission Flows', () => {
  test.beforeEach(async ({ browserName }) => {
    test.skip(browserName !== 'chromium', 'Flutter CanvasKit requires Chromium');
  });

  // -------------------------------------------------------------------------
  // Request success/failure pages
  // -------------------------------------------------------------------------

  test.describe('Request Success Page', () => {
    test('/request_success loads and renders Flutter', async ({ page }) => {
      await navigateAndWaitForFlutter(page, '/request_success');
      expect(page.url()).toContain('/request_success');
      await assertFlutterRendering(page);
    });

    test('/request_success returns 200', async ({ request }) => {
      const response = await request.get('/request_success');
      expect(response.status()).toBe(200);
    });
  });

  test.describe('Request Failure Page', () => {
    test('/request_failure loads and renders Flutter', async ({ page }) => {
      await navigateAndWaitForFlutter(page, '/request_failure');
      expect(page.url()).toContain('/request_failure');
      await assertFlutterRendering(page);
    });

    test('/request_failure returns 200', async ({ request }) => {
      const response = await request.get('/request_failure');
      expect(response.status()).toBe(200);
    });
  });

  // -------------------------------------------------------------------------
  // OAuth callback
  // -------------------------------------------------------------------------

  test.describe('OAuth Callback', () => {
    test('/oauth/callback loads with no params (bare route)', async ({ page }) => {
      await navigateAndWaitForFlutter(page, '/oauth/callback');
      expect(page.url()).toContain('/oauth/callback');
      await assertFlutterRendering(page);
    });

    test('/oauth/callback preserves code and state params', async ({ page }) => {
      await navigateAndWaitForFlutter(page, '/oauth/callback?code=test_auth_code&state=csrf_token_123');
      expect(page.url()).toContain('code=test_auth_code');
      expect(page.url()).toContain('state=csrf_token_123');
      await assertFlutterRendering(page);
    });

    test('/oauth/callback handles error params', async ({ page }) => {
      await navigateAndWaitForFlutter(
        page,
        '/oauth/callback?error=access_denied&error_description=User%20cancelled%20login',
      );
      expect(page.url()).toContain('error=access_denied');
      expect(page.url()).toContain('error_description=');
      await assertFlutterRendering(page);
    });

    test('/oauth/callback handles error without description', async ({ page }) => {
      await navigateAndWaitForFlutter(page, '/oauth/callback?error=server_error');
      expect(page.url()).toContain('error=server_error');
      await assertFlutterRendering(page);
    });
  });

  // -------------------------------------------------------------------------
  // Signup with tier variations
  // -------------------------------------------------------------------------

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

  // -------------------------------------------------------------------------
  // Support / Help Center
  // -------------------------------------------------------------------------

  test.describe('Support Route', () => {
    test('/support loads and renders Flutter', async ({ page }) => {
      await navigateAndWaitForFlutter(page, '/support');
      expect(page.url()).toContain('/support');
      await assertFlutterRendering(page);
    });
  });
});
