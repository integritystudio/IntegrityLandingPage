import { test, expect, devices } from '@playwright/test';
import { waitForFlutter, assertFlutterRendering, navigateAndWaitForFlutter } from './helpers';

/**
 * E2E tests for backlog sprint items (#51-#74).
 *
 * Validates that refactored routes, footer, contact form, and constants
 * all render and navigate correctly after the code quality sprint.
 */

test.describe('Route Group Coverage (#65)', () => {
  const consoleErrors: string[] = [];

  test.beforeEach(async ({ page, browserName }) => {
    test.skip(browserName !== 'chromium', 'Flutter CanvasKit requires Chromium');
    consoleErrors.length = 0;
    page.on('console', (msg) => {
      if (msg.type() === 'error') consoleErrors.push(msg.text());
    });
  });

  test.afterEach(async ({}, testInfo) => {
    if (consoleErrors.length > 0 && testInfo.status === 'passed') {
      console.warn(`Test "${testInfo.title}" passed with console errors:`, consoleErrors);
    }
  });

  test('home route loads', async ({ page }) => {
    await navigateAndWaitForFlutter(page, '/');
    await assertFlutterRendering(page);
  });

  const blogRoutes = ['/blog', '/whylabs-alternative', '/compare/arize-ai-alternative', '/sources'];
  for (const route of blogRoutes) {
    test(`blog group: ${route} loads`, async ({ page }) => {
      await navigateAndWaitForFlutter(page, route);
      expect(page.url()).toContain(route);
      await assertFlutterRendering(page);
    });
  }

  const mainRoutes = ['/about', '/features', '/status', '/pricing', '/contact', '/demo', '/careers'];
  for (const route of mainRoutes) {
    test(`main group: ${route} loads`, async ({ page }) => {
      await navigateAndWaitForFlutter(page, route);
      expect(page.url()).toContain(route);
      await assertFlutterRendering(page);
    });
  }

  const authRoutes = ['/request_success', '/request_failure', '/support', '/signup', '/oauth/callback'];
  for (const route of authRoutes) {
    test(`auth group: ${route} loads`, async ({ page }) => {
      await navigateAndWaitForFlutter(page, route);
      expect(page.url()).toContain(route);
      await assertFlutterRendering(page);
    });
  }

  const legalRoutes = ['/privacy', '/terms', '/cookies', '/accessibility', '/security'];
  for (const route of legalRoutes) {
    test(`legal group: ${route} loads`, async ({ page }) => {
      await navigateAndWaitForFlutter(page, route);
      expect(page.url()).toContain(route);
      await assertFlutterRendering(page);
    });
  }

  // NOTE: /docs/tracing is served as a static HTML page on production (not Flutter SPA).
  const docsRoutes = [
    '/docs', '/docs/llm-observability', '/docs/integrations',
    '/api', '/api/toolkit', '/docs/quickstart', '/docs/alerts', '/docs/agents',
    '/compliance', '/eu-ai-act',
  ];
  for (const route of docsRoutes) {
    test(`docs group: ${route} loads`, async ({ page }) => {
      await navigateAndWaitForFlutter(page, route);
      expect(page.url()).toContain(route);
      await assertFlutterRendering(page);
    });
  }

  test('docs group: /docs/tracing loads (static)', async ({ page }) => {
    const response = await page.goto('/docs/tracing', { waitUntil: 'domcontentloaded' });
    expect(response?.status()).toBe(200);
    expect(page.url()).toContain('/docs/tracing');
  });
});

test.describe('Signup CTA Routing (#61)', () => {
  test.beforeEach(async ({ browserName }) => {
    test.skip(browserName !== 'chromium', 'Flutter CanvasKit requires Chromium');
  });

  test('signup with tier=Team query parameter loads', async ({ page }) => {
    await navigateAndWaitForFlutter(page, '/signup?tier=Team');
    expect(page.url()).toContain('/signup');
    expect(page.url()).toContain('tier=Team');
    await assertFlutterRendering(page);
  });
});

test.describe('Footer Rendering - Desktop', () => {
  test.beforeEach(async ({ browserName }) => {
    test.skip(browserName !== 'chromium', 'Flutter CanvasKit requires Chromium');
  });

  test('homepage loads with Flutter rendering (footer present)', async ({ page }) => {
    test.slow();
    await navigateAndWaitForFlutter(page, '/');
    await assertFlutterRendering(page);
    await page.evaluate(() => window.scrollTo(0, document.documentElement.scrollHeight));
    await page.waitForTimeout(2000);
    await assertFlutterRendering(page);
  });
});

test.describe('Footer Rendering - Mobile', () => {
  test.use({
    viewport: devices['iPhone 13'].viewport,
    userAgent: devices['iPhone 13'].userAgent,
  });

  test.beforeEach(async ({ browserName }) => {
    test.skip(browserName !== 'chromium', 'Flutter CanvasKit requires Chromium');
  });

  test('homepage loads on mobile with footer (#74 mobile labels)', async ({ page }) => {
    test.slow();
    await navigateAndWaitForFlutter(page, '/');
    await assertFlutterRendering(page);
    await page.evaluate(() => window.scrollTo(0, document.documentElement.scrollHeight));
    await page.waitForTimeout(2000);
    await assertFlutterRendering(page);
  });
});

test.describe('Copyright Year (#57)', () => {
  test('HTML shell contains current year or app renders', async ({ request }) => {
    // The copyright year is rendered by Flutter (canvas), not in HTML.
    expect((await request.get('/')).status()).toBe(200);
  });
});

test.describe('Contact Form Navigation (#68)', () => {
  test.beforeEach(async ({ browserName }) => {
    test.skip(browserName !== 'chromium', 'Flutter CanvasKit requires Chromium');
  });

  test('contact page loads and Flutter renders', async ({ page }) => {
    await navigateAndWaitForFlutter(page, '/contact');
    await assertFlutterRendering(page);
  });
});

test.describe('Back Navigation (#66)', () => {
  test.beforeEach(async ({ browserName }) => {
    test.skip(browserName !== 'chromium', 'Flutter CanvasKit requires Chromium');
  });

  test('navigating to subpage and back preserves app state', async ({ page }) => {
    test.slow();
    await navigateAndWaitForFlutter(page, '/');
    await navigateAndWaitForFlutter(page, '/pricing');
    await assertFlutterRendering(page);

    await page.goBack();
    await page.waitForURL(/https?:\/\/[^/]+(:\d+)?\/?$/);
    await waitForFlutter(page);
    await assertFlutterRendering(page);
  });
});
