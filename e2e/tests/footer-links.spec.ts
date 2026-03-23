import { test, expect } from '@playwright/test';
import { waitForFlutter, assertFlutterRendering, navigateAndWaitForFlutter } from './helpers';
import { FLUTTER_BOOTSTRAP_SCRIPT } from './constants';

/**
 * E2E tests for footer link destinations and navigation.
 *
 * Regression coverage for:
 * - #53: Footer links migrated from hardcoded strings to Routes constants
 *   - '/features' → Routes.features (#features, anchor → navigates to home)
 *   - '/support' → Routes.support (/contact)
 * - #62: _FooterLink replaced with shared HoverTextLink widget
 *
 * Validates all footer link destination routes load the Flutter SPA correctly.
 */
test.describe('Footer Link Destinations', () => {
  test.beforeEach(async ({ browserName }) => {
    test.skip(browserName !== 'chromium', 'Flutter CanvasKit requires Chromium');
  });

  // All routes referenced by footer _linkSections (via Routes constants)
  const footerRoutes = [
    // Product section
    { path: '/pricing', name: 'Pricing' },
    { path: '/docs', name: 'Documentation' },
    { path: '/api', name: 'API Reference' },
    // Company section
    { path: '/about', name: 'About' },
    { path: '/blog', name: 'Blog' },
    { path: '/sources', name: 'Sources' },
    { path: '/careers', name: 'Careers' },
    { path: '/contact', name: 'Contact' },
    // Resources section
    // Routes.support resolves to /contact (#53 regression)
    { path: '/contact', name: 'Help Center (Routes.support)' },
    { path: '/status', name: 'Status' },
    { path: '/security', name: 'Security' },
  ];

  for (const route of footerRoutes) {
    test(`${route.name} (${route.path}) loads Flutter app`, async ({ page }) => {
      const response = await page.goto(route.path, { waitUntil: 'domcontentloaded' });
      expect(response?.status()).toBe(200);
      expect(await page.content()).toContain(FLUTTER_BOOTSTRAP_SCRIPT);
      await waitForFlutter(page);
      await assertFlutterRendering(page);
    });
  }

  const legalRoutes = [
    { path: '/privacy', name: 'Privacy Policy' },
    { path: '/terms', name: 'Terms of Service' },
    { path: '/cookies', name: 'Cookie Policy' },
    { path: '/accessibility', name: 'Accessibility' },
  ];

  for (const route of legalRoutes) {
    test(`${route.name} (${route.path}) loads Flutter app`, async ({ page }) => {
      const response = await page.goto(route.path, { waitUntil: 'domcontentloaded' });
      expect(response?.status()).toBe(200);
      await waitForFlutter(page);
      await assertFlutterRendering(page);
    });
  }

  test('anchor route #features navigates to home page', async ({ page }) => {
    // #53 regression: Features link changed from /features to #features
    await navigateAndWaitForFlutter(page, '/');
    await assertFlutterRendering(page);

    const response = await page.goto('/#features', { waitUntil: 'domcontentloaded' });
    if (response) {
      expect(response.status()).toBe(200);
    }
    await waitForFlutter(page);
    await assertFlutterRendering(page);
  });
});
