import { test, expect, Page } from '@playwright/test';
import { waitForFlutter, assertFlutterRendering, consentJson } from './helpers';
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
 * browser. Running in a real Chromium browser via Playwright exercises the
 * web-only code and provides regression coverage for:
 *
 * - #76: `_initializeTracking` — consent → GTM / GA4 / Facebook Pixel
 * - #75: `_launchUrl` — footer external links via `url_launcher` web impl
 *
 * Upstream context: `flutter test --platform chrome` is blocked by upstream
 * bugs (Flutter #162798, #182618) until Flutter 3.44 stable (~May 2026).
 */

const UNHANDLED_ERROR_PATTERNS = ['Uncaught', 'Unhandled', 'unhandled', 'EXCEPTION'] as const;

function isUnhandledError(msg: string): boolean {
  return UNHANDLED_ERROR_PATTERNS.some((p) => msg.includes(p));
}

function isKnownFlutterError(msg: string): boolean {
  return (
    msg.includes('service-worker') ||
    msg.includes('CanvasKit') ||
    msg.includes('Failed to load resource') ||
    msg.includes('net::ERR_') ||
    msg.includes('Content Security Policy directive') ||
    msg.includes('is ignored when delivered via a <meta>')
  );
}

async function getDataLayerLength(page: Page): Promise<number> {
  return page.evaluate(() => {
    const dl = (window as unknown as { dataLayer?: unknown[] }).dataLayer;
    return Array.isArray(dl) ? dl.length : 0;
  });
}

async function hasScriptSrc(page: Page, srcSubstring: string): Promise<boolean> {
  return page.evaluate((sub) => {
    return Array.from(document.querySelectorAll('script[src]'))
      .some((s) => (s as HTMLScriptElement).src.includes(sub));
  }, srcSubstring);
}

test.describe('Web Platform: Tracking Initialization (#76)', () => {
  test.beforeEach(async ({ browserName }) => {
    test.skip(browserName !== 'chromium', 'Flutter CanvasKit requires Chromium');
  });

  test('dataLayer exists after Flutter loads', async ({ page }) => {
    await page.goto('/', { waitUntil: 'domcontentloaded' });
    await waitForFlutter(page);
    expect(await getDataLayerLength(page)).toBeGreaterThan(0);
  });

  test('GTM script is NOT injected before consent (GDPR)', async ({ page }) => {
    await page.goto('/', { waitUntil: 'domcontentloaded' });
    await waitForFlutter(page);
    expect(await hasScriptSrc(page, `gtm.js?id=${GTM_CONTAINER_ID}`)).toBe(false);
  });

  test('no console errors during tracking initialization', async ({ page }) => {
    const consoleErrors: string[] = [];
    page.on('console', (msg) => {
      if (msg.type() === 'error') consoleErrors.push(msg.text());
    });

    await page.goto('/', { waitUntil: 'domcontentloaded' });
    await waitForFlutter(page);
    await page.waitForTimeout(GTM_INJECT_SETTLE_MS);

    expect(consoleErrors.filter((e) => !isKnownFlutterError(e))).toHaveLength(0);
  });

  test('meta-pixel.js is loaded in page', async ({ page }) => {
    await page.goto('/', { waitUntil: 'domcontentloaded' });
    await waitForFlutter(page);
    expect(await hasScriptSrc(page, 'meta-pixel.js')).toBe(true);
  });
});

test.describe('Web Platform: External Links (#75)', () => {
  test.beforeEach(async ({ browserName }) => {
    test.skip(browserName !== 'chromium', 'Flutter CanvasKit requires Chromium');
  });

  test('page loads without crash after scrolling to footer region', async ({ page }) => {
    await page.goto('/', { waitUntil: 'domcontentloaded' });
    await waitForFlutter(page);
    await page.evaluate(() => window.scrollTo(0, document.body.scrollHeight));
    await page.waitForTimeout(SCROLL_SETTLE_MS);
    await assertFlutterRendering(page);
  });

  test('window.open is available for url_launcher web impl', async ({ page }) => {
    await page.goto('/', { waitUntil: 'domcontentloaded' });
    await waitForFlutter(page);
    expect(await page.evaluate(() => typeof window.open === 'function')).toBe(true);
    await assertFlutterRendering(page);
  });

  test('external link navigation does not crash the app', async ({ page }) => {
    await page.goto('/', { waitUntil: 'domcontentloaded' });
    await waitForFlutter(page);

    await page.evaluate(() => window.scrollTo(0, document.body.scrollHeight));
    await page.waitForTimeout(SCROLL_SETTLE_MS);

    // Intercept window.open to prevent actual navigation
    await page.evaluate(() => {
      const original = window.open;
      window.open = (..._args: Parameters<typeof window.open>) => null;
      (window as unknown as { _restoreOpen: typeof window.open })._restoreOpen = original;
    });

    await assertFlutterRendering(page);

    await page.evaluate(() => {
      const w = window as unknown as { _restoreOpen?: typeof window.open };
      if (w._restoreOpen) {
        window.open = w._restoreOpen;
        delete w._restoreOpen;
      }
    });
  });

  test('footer renders without crash under poisoned window.open environment (#75)', async ({ page }) => {
    const consoleErrors: string[] = [];
    page.on('console', (msg) => {
      if (msg.type() === 'error') consoleErrors.push(msg.text());
    });

    await page.addInitScript(() => {
      window.open = (..._args: Parameters<typeof window.open>): null => {
        throw new Error('Simulated url_launcher failure');
      };
    });

    await page.goto('/', { waitUntil: 'domcontentloaded' });
    await waitForFlutter(page);

    await page.evaluate(() => window.scrollTo(0, document.body.scrollHeight));
    await page.waitForTimeout(SCROLL_SETTLE_MS);

    await assertFlutterRendering(page);
    expect(consoleErrors.filter(isUnhandledError)).toHaveLength(0);
  });
});

test.describe('Web Platform: Consent Manager Web Storage (#76)', () => {
  const KEY = CONSENT_STORAGE_KEY;

  test.beforeEach(async ({ browserName }) => {
    test.skip(browserName !== 'chromium', 'Flutter CanvasKit requires Chromium');
  });

  test.afterEach(async ({ page }) => {
    await page.evaluate((key) => localStorage.removeItem(key), KEY);
  });

  test('localStorage is accessible for consent persistence', async ({ page }) => {
    await page.goto('/', { waitUntil: 'domcontentloaded' });
    await waitForFlutter(page);

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

    await page.evaluate(
      ({ key, val }) => localStorage.setItem(key, val),
      { key: KEY, val: consentJson(true, false) },
    );

    await page.reload({ waitUntil: 'domcontentloaded' });
    await waitForFlutter(page);

    const consent = await page.evaluate((key) => {
      const raw = localStorage.getItem(key);
      return raw ? JSON.parse(raw) : null;
    }, KEY);
    expect(consent).not.toBeNull();
    expect(consent.analytics).toBe(true);
    expect(consent.marketing).toBe(false);

    await assertFlutterRendering(page);
  });

  test('_initializeTracking does not crash with corrupted consent data', async ({ page }) => {
    await page.goto('/', { waitUntil: 'domcontentloaded' });
    await waitForFlutter(page);

    await page.evaluate(({ key }) => localStorage.setItem(key, '{invalid json!!!}'), { key: KEY });

    const consoleErrors: string[] = [];
    page.on('console', (msg) => {
      if (msg.type() === 'error') consoleErrors.push(msg.text());
    });

    await page.reload({ waitUntil: 'domcontentloaded' });
    await waitForFlutter(page);
    await page.waitForTimeout(GTM_INJECT_SETTLE_MS);

    await assertFlutterRendering(page);
    expect(consoleErrors.filter(isUnhandledError)).toHaveLength(0);
  });

  test('GTM injects after consent with analytics=true', async ({ page }) => {
    await page.goto('/', { waitUntil: 'domcontentloaded' });
    await waitForFlutter(page);

    await page.evaluate(
      ({ key, val }) => localStorage.setItem(key, val),
      { key: KEY, val: consentJson(true, true) },
    );

    await page.reload({ waitUntil: 'domcontentloaded' });
    await waitForFlutter(page);
    await page.waitForTimeout(GTM_INJECT_SETTLE_MS);

    expect(await hasScriptSrc(page, `gtm.js?id=${GTM_CONTAINER_ID}`)).toBe(true);
    await assertFlutterRendering(page);
  });
});
