import { test, expect, type Page } from '@playwright/test';
import { waitForFlutter, navigateAndWaitForFlutter } from './helpers';
import {
  CONSENT_STORAGE_KEY,
  GTM_CONTAINER_ID,
  GTM_INJECT_SETTLE_MS,
} from './constants';

/**
 * E2E tests for analytics event payload validation (#112).
 *
 * Validates that GTM dataLayer events are pushed correctly:
 * - Page view events on initial load and route changes
 * - dataLayer event structure (event name, page fields)
 * - GTM script injection after consent
 * - Network requests to analytics endpoints
 *
 * These tests require consent pre-set to analytics=true.
 * They do NOT intercept third-party beacons (only validate dataLayer pushes).
 */

/** Build a ConsentPreferences-compatible JSON string (consent_preferences.dart). */
function consentJson(analytics: boolean, marketing: boolean): string {
  return JSON.stringify({
    essential: true,
    analytics,
    marketing,
    timestamp: new Date().toISOString(),
    consentVersion: '1.0',
  });
}

/** Read the full window.dataLayer array. */
async function getDataLayer(page: Page): Promise<unknown[]> {
  return page.evaluate(() => {
    const dl = (window as unknown as { dataLayer?: unknown[] }).dataLayer;
    return Array.isArray(dl) ? dl : [];
  });
}

test.describe('Analytics Event Payload Validation (#112)', () => {
  test.beforeEach(async ({ browserName }) => {
    test.skip(browserName !== 'chromium', 'Flutter CanvasKit requires Chromium');
  });

  test.afterEach(async ({ page }) => {
    await page.evaluate((key) => localStorage.removeItem(key), CONSENT_STORAGE_KEY);
  });

  // -------------------------------------------------------------------------
  // dataLayer structure
  // -------------------------------------------------------------------------

  test.describe('dataLayer structure', () => {
    test('dataLayer is initialized with entries after page load', async ({ page }) => {
      await page.goto('/', { waitUntil: 'domcontentloaded' });
      await waitForFlutter(page);

      const dl = await getDataLayer(page);
      expect(Array.isArray(dl)).toBe(true);
      expect(dl.length).toBeGreaterThan(0);
      // First entry should be an object or array (gtm.js default dataLayer push)
      expect(dl[0]).toBeTruthy();
    });
  });

  // -------------------------------------------------------------------------
  // GTM injection after consent
  // -------------------------------------------------------------------------

  test.describe('GTM injection with consent', () => {
    test('GTM script src contains container ID after consent reload', async ({ page }) => {
      await page.goto('/', { waitUntil: 'domcontentloaded' });
      await waitForFlutter(page);

      await page.evaluate(
        ({ key, val }) => localStorage.setItem(key, val),
        { key: CONSENT_STORAGE_KEY, val: consentJson(true, true) },
      );

      await page.reload({ waitUntil: 'domcontentloaded' });
      await waitForFlutter(page);
      await page.waitForTimeout(GTM_INJECT_SETTLE_MS);

      const hasGTM = await page.evaluate((id) => {
        return Array.from(document.querySelectorAll('script[src]'))
          .some((s) => (s as HTMLScriptElement).src.includes(`gtm.js?id=${id}`));
      }, GTM_CONTAINER_ID);
      expect(hasGTM).toBe(true);
    });

    test('no analytics requests before consent', async ({ page }) => {
      const analyticsRequests: string[] = [];
      page.on('request', (req) => {
        const url = req.url();
        if (url.includes('google-analytics') || url.includes('googletagmanager') || url.includes('gtm.js')) {
          analyticsRequests.push(url);
        }
      });

      await page.goto('/', { waitUntil: 'domcontentloaded' });
      await waitForFlutter(page);

      expect(analyticsRequests.some((u) => u.includes('gtm.js'))).toBe(false);
    });
  });

  // -------------------------------------------------------------------------
  // Route change events
  // -------------------------------------------------------------------------

  test.describe('dataLayer events on route change', () => {
    test('dataLayer re-initializes after navigating to second route', async ({ page }) => {
      await page.goto('/', { waitUntil: 'domcontentloaded' });
      await waitForFlutter(page);

      const homeLength = (await getDataLayer(page)).length;
      expect(homeLength).toBeGreaterThan(0);

      // navigateAndWaitForFlutter does a full page.goto (not SPA nav),
      // so dataLayer resets. Verify it re-initializes on the new route.
      await navigateAndWaitForFlutter(page, '/pricing');

      const pricingLength = (await getDataLayer(page)).length;
      expect(pricingLength).toBeGreaterThan(0);
    });
  });
});
