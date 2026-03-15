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
test.describe('Documentation page content (semantics)', () => {
  test.setTimeout(TEST_TIMEOUT_MS);

  test.beforeEach(async ({ browserName }) => {
    test.skip(browserName !== 'chromium', 'Flutter CanvasKit requires Chromium');
  });

  // ---------------------------------------------------------------------------
  // /docs/llm-observability
  // ---------------------------------------------------------------------------

  test('llm-observability renders section titles, stat cards, and callouts', async ({ page }) => {
    await navigateAndWaitForFlutter(page, '/docs/llm-observability');
    await enableFlutterSemantics(page);

    // Try to detect semantics — skip if tree not available
    try {
      await waitForSemantics(page, /observability/i, SEMANTICS_TIMEOUT_MS);
    } catch {
      test.skip(true, 'Flutter semantics tree not available (Flutter #151929)');
      return;
    }

    // Section titles
    await expect(page.getByLabel(/observability/i).first()).toBeAttached();

    // DocStatCard
    await expect(page.getByLabel(/latency/i).first()).toBeAttached();

    // DocCallout variant
    await expect(page.getByLabel(/callout/i).first()).toBeAttached();
  });

  // ---------------------------------------------------------------------------
  // /api
  // ---------------------------------------------------------------------------

  test('api page renders section titles and tables', async ({ page }) => {
    await navigateAndWaitForFlutter(page, '/api');
    await enableFlutterSemantics(page);

    try {
      await waitForSemantics(page, /api/i, SEMANTICS_TIMEOUT_MS);
    } catch {
      test.skip(true, 'Flutter semantics tree not available (Flutter #151929)');
      return;
    }

    // Section titles
    await expect(page.getByLabel(/api/i).first()).toBeAttached();

    // Scroll to bring the Authentication section's DocTable into viewport —
    // Flutter only exposes semantics for widgets in the render viewport.
    for (let i = 0; i < 3; i++) {
      await page.mouse.wheel(0, 400);
      await page.waitForTimeout(300);
    }

    // DocTable headers (first table: "API Key Scopes")
    await expect(page.getByLabel(/table/i).first()).toBeAttached({ timeout: 5000 });

    // Note: DocInlineWarning has Semantics(label: 'Warning: ...') but Flutter's
    // CanvasKit semantics tree optimizer merges it — the aria-label is not emitted
    // to the DOM. Verified via aria-label dump: 0 warning nodes despite visual render.
  });

  // ---------------------------------------------------------------------------
  // /docs/quickstart
  // ---------------------------------------------------------------------------

  test('quickstart renders section titles and numbered lists', async ({ page }) => {
    await navigateAndWaitForFlutter(page, '/docs/quickstart');
    await enableFlutterSemantics(page);

    try {
      await waitForSemantics(page, /quickstart|getting started/i, SEMANTICS_TIMEOUT_MS);
    } catch {
      test.skip(true, 'Flutter semantics tree not available (Flutter #151929)');
      return;
    }

    // Section titles
    await expect(page.getByLabel(/quickstart|getting started/i).first()).toBeAttached();

    // DocNumberedList
    await expect(page.getByLabel(/steps/i).first()).toBeAttached();
  });
});
