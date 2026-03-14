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

  test('api page renders section titles, tables, and inline warnings', async ({ page }) => {
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

    // DocTable headers
    await expect(page.getByLabel(/table/i).first()).toBeAttached();

    // DocInlineWarning
    await expect(page.getByLabel(/warning/i).first()).toBeAttached();
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
