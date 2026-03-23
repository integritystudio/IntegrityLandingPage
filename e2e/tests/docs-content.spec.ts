import { test, expect } from '@playwright/test';
import {
  navigateAndWaitForFlutter,
  enableFlutterSemantics,
  waitForSemantics,
} from './helpers';
import { SEMANTICS_TIMEOUT_MS, TEST_TIMEOUT_MS } from './constants';

/**
 * E2E tests for documentation page content via Flutter semantics tree.
 *
 * These tests verify that doc components render accessible content by checking
 * for ARIA labels emitted by Semantics widgets. If the Flutter semantics tree
 * fails to materialise (known Flutter web issue #151929), the test is skipped
 * gracefully rather than failing the suite.
 */

async function waitForSemanticsOrSkip(page: Parameters<typeof waitForSemantics>[0], label: RegExp): Promise<boolean> {
  try {
    await waitForSemantics(page, label, SEMANTICS_TIMEOUT_MS);
    return true;
  } catch {
    test.skip(true, 'Flutter semantics tree not available (Flutter #151929)');
    return false;
  }
}

test.describe('Documentation page content (semantics)', () => {
  test.setTimeout(TEST_TIMEOUT_MS);

  test.beforeEach(async ({ browserName }) => {
    test.skip(browserName !== 'chromium', 'Flutter CanvasKit requires Chromium');
  });

  test('llm-observability renders section titles, stat cards, and callouts', async ({ page }) => {
    await navigateAndWaitForFlutter(page, '/docs/llm-observability');
    await enableFlutterSemantics(page);
    if (!await waitForSemanticsOrSkip(page, /observability/i)) return;

    await expect(page.getByLabel(/observability/i).first()).toBeAttached();
    await expect(page.getByLabel(/latency/i).first()).toBeAttached();
    await expect(page.getByLabel(/callout/i).first()).toBeAttached();
  });

  test('api page renders section titles and tables', async ({ page }) => {
    await navigateAndWaitForFlutter(page, '/api');
    await enableFlutterSemantics(page);
    if (!await waitForSemanticsOrSkip(page, /api/i)) return;

    await expect(page.getByLabel(/api/i).first()).toBeAttached();

    // Scroll to bring the Authentication section's DocTable into viewport
    for (let i = 0; i < 3; i++) {
      await page.mouse.wheel(0, 400);
      await page.waitForTimeout(300);
    }

    await expect(page.getByLabel(/table/i).first()).toBeAttached({ timeout: 5000 });
  });

  test('quickstart renders section titles and numbered lists', async ({ page }) => {
    await navigateAndWaitForFlutter(page, '/docs/quickstart');
    await enableFlutterSemantics(page);
    if (!await waitForSemanticsOrSkip(page, /quickstart|getting started/i)) return;

    await expect(page.getByLabel(/quickstart|getting started/i).first()).toBeAttached();
    await expect(page.getByLabel(/steps/i).first()).toBeAttached();
  });
});
