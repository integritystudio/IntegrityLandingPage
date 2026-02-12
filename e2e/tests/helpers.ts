import { expect, Page } from '@playwright/test';

/**
 * Wait for Flutter to fully initialize.
 *
 * Uses a deterministic approach instead of arbitrary timeouts:
 * 1. Wait for loading container to be hidden OR Flutter rendering surface to appear
 * 2. Verify Flutter is actually rendering content
 *
 * @param page - Playwright page object
 * @param timeout - Maximum time to wait in milliseconds (default: 90000)
 */
export async function waitForFlutter(page: Page, timeout = 90000): Promise<void> {
  // Wait for Flutter rendering surface to appear.
  // Note: waitForFunction(fn, arg, options) - pass undefined as arg to avoid
  // Playwright treating the options object as a function argument.
  // We only check for the rendering surface (flutter-view/canvas), not the
  // loading container, because the production site's .flutter-ready class
  // is never applied so the loading container stays visible in the DOM
  // even after Flutter renders.
  await page.waitForFunction(
    () => {
      return !!(
        document.querySelector('flt-glass-pane') ||
        document.querySelector('flutter-view') ||
        document.querySelector('canvas')
      );
    },
    undefined,
    { timeout }
  );
}

/**
 * Assert that Flutter is rendering.
 *
 * @param page - Playwright page object
 */
export async function assertFlutterRendering(page: Page): Promise<void> {
  const hasFlutter = await page.evaluate(() => {
    return !!(
      document.querySelector('flt-glass-pane') ||
      document.querySelector('flutter-view') ||
      document.querySelector('canvas')
    );
  });
  expect(hasFlutter).toBe(true);
}

/**
 * Wait for Flutter route change to complete.
 *
 * @param page - Playwright page object
 * @param urlPattern - URL pattern to match (string or regex)
 * @param timeout - Maximum time to wait in milliseconds (default: 10000)
 */
export async function waitForRoute(
  page: Page,
  urlPattern: string | RegExp,
  timeout = 10000
): Promise<void> {
  await page.waitForURL(urlPattern, { timeout });
  // Give Flutter a moment to render the new route content
  await page.waitForFunction(
    () => {
      const canvas = document.querySelector('canvas');
      return canvas !== null;
    },
    undefined,
    { timeout: 5000 }
  );
}

/**
 * Navigate to a route and wait for Flutter to load.
 *
 * @param page - Playwright page object
 * @param path - Route path to navigate to
 */
export async function navigateAndWaitForFlutter(
  page: Page,
  path: string
): Promise<void> {
  await page.goto(path, { waitUntil: 'domcontentloaded' });
  await waitForFlutter(page);
}
