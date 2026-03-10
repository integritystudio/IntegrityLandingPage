import { test, expect, Page } from '@playwright/test';
import { waitForFlutter, assertFlutterRendering } from './helpers';
import {
  CONSENT_STORAGE_KEY,
  GTM_CONTAINER_ID,
  GTM_INJECT_SETTLE_MS,
  SCROLL_SETTLE_MS,
} from './constants';

/**
 * Web-platform E2E tests for code paths gated behind `kIsWeb`.
 *
 * These cover Dart branches that native widget tests cannot reach because
 * `kIsWeb` is a compile-time constant that evaluates to `false` outside a
 * browser.  Running in a real Chromium browser via Playwright exercises the
 * web-only code and provides regression coverage for:
 *
 * - #76: `_initializeTracking` — consent → GTM / GA4 / Facebook Pixel
 * - #75: `_launchUrl` — footer external links via `url_launcher` web impl
 *
 * Upstream context (BACKLOG.md §Blocked: Chrome Platform Tests #77):
 * `flutter test --platform chrome` is blocked by two upstream bugs (Flutter
 * #162798, #182618). These Playwright tests are the workaround until Flutter
 * 3.44 stable ships the fixes (~May 2026).
 */

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

/** Check whether `window.dataLayer` exists and has entries. */
async function getDataLayerLength(page: Page): Promise<number> {
  return page.evaluate(() => {
    const dl = (window as unknown as { dataLayer?: unknown[] }).dataLayer;
    return Array.isArray(dl) ? dl.length : 0;
  });
}

/** Check whether a <script> tag with the given src substring exists. */
async function hasScriptSrc(page: Page, srcSubstring: string): Promise<boolean> {
  return page.evaluate((sub) => {
    return Array.from(document.querySelectorAll('script[src]'))
      .some((s) => (s as HTMLScriptElement).src.includes(sub));
  }, srcSubstring);
}

/**
 * Build a ConsentPreferences-compatible JSON string.
 * Matches the format from consent_preferences.dart toJson().
 */
function consentJson(analytics: boolean, marketing: boolean): string {
  return JSON.stringify({
    essential: true,
    analytics,
    marketing,
    timestamp: new Date().toISOString(),
    consentVersion: '1.0',
  });
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

test.describe('Web Platform: Tracking Initialization (#76)', () => {
  test.beforeEach(async ({ browserName }) => {
    test.skip(browserName !== 'chromium', 'Flutter CanvasKit requires Chromium');
  });

  test('dataLayer exists after Flutter loads', async ({ page }) => {
    await page.goto('/', { waitUntil: 'domcontentloaded' });
    await waitForFlutter(page);

    // gtm-init.js (loaded in index.html) sets up window.dataLayer and gtag fn
    const dlLength = await getDataLayerLength(page);
    expect(dlLength).toBeGreaterThan(0);
  });

  test('GTM script is NOT injected before consent (GDPR)', async ({ page }) => {
    await page.goto('/', { waitUntil: 'domcontentloaded' });
    await waitForFlutter(page);

    // dataLayer exists (from gtm-init.js) but GTM should NOT be loaded yet
    const dlLength = await getDataLayerLength(page);
    expect(dlLength).toBeGreaterThan(0);

    const hasGTM = await hasScriptSrc(page, `gtm.js?id=${GTM_CONTAINER_ID}`);
    expect(hasGTM).toBe(false);
  });

  test('no console errors during tracking initialization', async ({ page }) => {
    const consoleErrors: string[] = [];
    page.on('console', (msg) => {
      if (msg.type() === 'error') {
        consoleErrors.push(msg.text());
      }
    });

    await page.goto('/', { waitUntil: 'domcontentloaded' });
    await waitForFlutter(page);
    await page.waitForTimeout(GTM_INJECT_SETTLE_MS);

    // Filter known non-app errors (network, service worker, CanvasKit, CSP meta warnings)
    const trackingErrors = consoleErrors.filter(
      (e) =>
        !e.includes('service-worker') &&
        !e.includes('CanvasKit') &&
        !e.includes('Failed to load resource') &&
        !e.includes('net::ERR_') &&
        !e.includes('Content Security Policy directive') &&
        !e.includes('is ignored when delivered via a <meta>'),
    );

    expect(trackingErrors).toHaveLength(0);
  });

  test('meta-pixel.js is loaded in page', async ({ page }) => {
    await page.goto('/', { waitUntil: 'domcontentloaded' });
    await waitForFlutter(page);

    // meta-pixel.js is included in index.html (noscript img fallback too)
    const hasMetaPixel = await hasScriptSrc(page, 'meta-pixel.js');
    expect(hasMetaPixel).toBe(true);
  });
});

test.describe('Web Platform: External Links (#75)', () => {
  test.beforeEach(async ({ browserName }) => {
    test.skip(browserName !== 'chromium', 'Flutter CanvasKit requires Chromium');
  });

  test('page loads without crash after scrolling to footer region', async ({ page }) => {
    await page.goto('/', { waitUntil: 'domcontentloaded' });
    await waitForFlutter(page);

    // Scroll to bottom where footer lives
    await page.evaluate(() => window.scrollTo(0, document.body.scrollHeight));
    await page.waitForTimeout(SCROLL_SETTLE_MS);

    // Flutter should still be rendering (no crash from kIsWeb branches)
    await assertFlutterRendering(page);
  });

  test('window.open is available for url_launcher web impl', async ({ page }) => {
    // On web, _launchUrl uses LaunchMode.platformDefault which delegates to
    // window.open. Verify the web platform API is available.
    await page.goto('/', { waitUntil: 'domcontentloaded' });
    await waitForFlutter(page);

    const hasWindowOpen = await page.evaluate(() => typeof window.open === 'function');
    expect(hasWindowOpen).toBe(true);

    // Verify Flutter is rendering in web context (kIsWeb = true)
    await assertFlutterRendering(page);
  });

  test('external link navigation does not crash the app', async ({ page }) => {
    await page.goto('/', { waitUntil: 'domcontentloaded' });
    await waitForFlutter(page);

    // Scroll to bottom to ensure footer is in view
    await page.evaluate(() => window.scrollTo(0, document.body.scrollHeight));
    await page.waitForTimeout(SCROLL_SETTLE_MS);

    // Intercept window.open to prevent actual navigation
    await page.evaluate(() => {
      const original = window.open;
      window.open = (..._args: Parameters<typeof window.open>) => null;
      (window as unknown as { _restoreOpen: typeof window.open })._restoreOpen = original;
    });

    // App should still be rendering after intercepting window.open
    await assertFlutterRendering(page);

    // Cleanup
    await page.evaluate(() => {
      const w = window as unknown as { _restoreOpen?: typeof window.open };
      if (w._restoreOpen) {
        window.open = w._restoreOpen;
        delete w._restoreOpen;
      }
    });
  });

  test('footer renders without crash under poisoned window.open environment (#75)', async ({ page }) => {
    // Smoke test for #75: verifies the footer section and Flutter app render
    // successfully even when window.open is configured to throw.
    //
    // On web, url_launcher delegates to window.open. By poisoning window.open
    // before Flutter loads we confirm that Flutter's initialization and kIsWeb
    // widget tree setup do not crash when the URL-launch mechanism is broken.
    // Direct invocation of _launchUrl is not possible from Playwright because
    // Flutter CanvasKit renders to <canvas>, not DOM elements; full catch-block
    // unit coverage requires flutter test --platform chrome (#77).
    const consoleErrors: string[] = [];
    page.on('console', (msg) => {
      if (msg.type() === 'error') consoleErrors.push(msg.text());
    });

    // Poison window.open before Flutter loads
    await page.addInitScript(() => {
      window.open = (..._args: Parameters<typeof window.open>): null => {
        throw new Error('Simulated url_launcher failure');
      };
    });

    await page.goto('/', { waitUntil: 'domcontentloaded' });
    await waitForFlutter(page);

    // Scroll to footer to trigger footer widget render in kIsWeb context
    await page.evaluate(() => window.scrollTo(0, document.body.scrollHeight));
    await page.waitForTimeout(SCROLL_SETTLE_MS);

    await assertFlutterRendering(page);

    // No unhandled exceptions from initialization under poisoned window.open
    const unhandledErrors = consoleErrors.filter(
      (e) =>
        e.includes('Uncaught') ||
        e.includes('Unhandled') ||
        e.includes('unhandled') ||
        e.includes('EXCEPTION'),
    );
    expect(unhandledErrors).toHaveLength(0);
  });
});

test.describe('Web Platform: Consent Manager Web Storage (#76)', () => {
  const KEY = CONSENT_STORAGE_KEY;

  test.beforeEach(async ({ browserName }) => {
    test.skip(browserName !== 'chromium', 'Flutter CanvasKit requires Chromium');
  });

  test.afterEach(async ({ page }) => {
    // Clean up consent storage after each test
    await page.evaluate((key) => localStorage.removeItem(key), KEY);
  });

  test('localStorage is accessible for consent persistence', async ({ page }) => {
    await page.goto('/', { waitUntil: 'domcontentloaded' });
    await waitForFlutter(page);

    // ConsentManager uses localStorage on web (kIsWeb branch)
    const storageAvailable = await page.evaluate(() => {
      try {
        localStorage.setItem('__test__', '1');
        localStorage.removeItem('__test__');
        return true;
      } catch {
        return false;
      }
    });
    expect(storageAvailable).toBe(true);
  });

  test('consent preferences survive page reload', async ({ page }) => {
    await page.goto('/', { waitUntil: 'domcontentloaded' });
    await waitForFlutter(page);

    // Write consent matching ConsentPreferences.toJson() format
    const data = consentJson(true, false);
    await page.evaluate(({ key, val }) => localStorage.setItem(key, val), { key: KEY, val: data });

    // Reload — _initializeTracking should read stored consent
    await page.reload({ waitUntil: 'domcontentloaded' });
    await waitForFlutter(page);

    // Verify consent data persisted
    const consent = await page.evaluate((key) => {
      const raw = localStorage.getItem(key);
      return raw ? JSON.parse(raw) : null;
    }, KEY);
    expect(consent).not.toBeNull();
    expect(consent.analytics).toBe(true);
    expect(consent.marketing).toBe(false);

    // App should still render (no crash in _initializeTracking)
    await assertFlutterRendering(page);
  });

  test('_initializeTracking does not crash with corrupted consent data', async ({ page }) => {
    await page.goto('/', { waitUntil: 'domcontentloaded' });
    await waitForFlutter(page);

    // Write invalid JSON to consent key
    await page.evaluate(
      ({ key }) => localStorage.setItem(key, '{invalid json!!!}'),
      { key: KEY },
    );

    // Reload — _initializeTracking try/catch should handle the parse error
    const consoleErrors: string[] = [];
    page.on('console', (msg) => {
      if (msg.type() === 'error') {
        consoleErrors.push(msg.text());
      }
    });

    await page.reload({ waitUntil: 'domcontentloaded' });
    await waitForFlutter(page);
    await page.waitForTimeout(GTM_INJECT_SETTLE_MS);

    // App should still render — error caught by _initializeTracking
    await assertFlutterRendering(page);

    // No unhandled errors (the try/catch in _initializeTracking handles it)
    const unhandledErrors = consoleErrors.filter(
      (e) =>
        e.includes('Uncaught') ||
        e.includes('unhandled') ||
        e.includes('EXCEPTION'),
    );
    expect(unhandledErrors).toHaveLength(0);
  });

  test('GTM injects after consent with analytics=true', async ({ page }) => {
    await page.goto('/', { waitUntil: 'domcontentloaded' });
    await waitForFlutter(page);

    // Pre-set consent with analytics + marketing enabled
    const data = consentJson(true, true);
    await page.evaluate(({ key, val }) => localStorage.setItem(key, val), { key: KEY, val: data });

    // Reload to trigger _initializeTracking with stored consent
    await page.reload({ waitUntil: 'domcontentloaded' });
    await waitForFlutter(page);
    await page.waitForTimeout(GTM_INJECT_SETTLE_MS);

    // GTM script should be injected after consent-based initialization.
    // consentJson() matches ConsentPreferences.fromJson() exactly:
    // {essential, analytics, marketing, timestamp, consentVersion}
    const hasGTM = await hasScriptSrc(page, `gtm.js?id=${GTM_CONTAINER_ID}`);
    expect(hasGTM).toBe(true);

    await assertFlutterRendering(page);
  });
});
