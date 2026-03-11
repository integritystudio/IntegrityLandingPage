import { test, expect } from '@playwright/test';
import { waitForFlutter, assertFlutterRendering } from './helpers';
import { KEY_SETTLE_MS } from './constants';

/**
 * E2E accessibility (a11y) tests.
 *
 * Validates basic accessibility requirements for the Flutter web app.
 * Flutter renders to canvas which limits DOM-based a11y testing,
 * but we can validate the HTML shell, meta tags, semantic structure,
 * and Flutter's accessibility tree when enabled.
 */
test.describe('Accessibility', () => {
  test.describe('HTML structure', () => {
    test('page has lang attribute', async ({ request }) => {
      const response = await request.get('/');
      const html = await response.text();
      expect(html).toMatch(/<html[^>]*lang="en"/);
    });

    test('page has title', async ({ request }) => {
      const response = await request.get('/');
      const html = await response.text();
      expect(html).toMatch(/<title>[^<]+<\/title>/);
    });

    test('page has meta description', async ({ request }) => {
      const response = await request.get('/');
      const html = await response.text();
      expect(html).toContain('name="description"');
    });

    test('loading spinner has aria attributes', async ({ request }) => {
      const response = await request.get('/');
      const html = await response.text();

      // Loading container should have aria-label
      expect(html).toContain('aria-label="Loading application"');

      // Spinner should have progressbar role
      expect(html).toContain('role="progressbar"');
    });
  });

  test.describe('noscript fallback', () => {
    test('noscript content has semantic HTML', async ({ request }) => {
      const response = await request.get('/');
      const html = await response.text();

      // Noscript block should use semantic elements
      expect(html).toContain('<noscript>');
      expect(html).toMatch(/<main[^>]*>/);
      expect(html).toMatch(/<header[^>]*>/);
      expect(html).toMatch(/<article[^>]*>/);
      expect(html).toMatch(/<footer[^>]*>/);
    });

    test('noscript content has heading hierarchy', async ({ request }) => {
      const response = await request.get('/');
      const html = await response.text();

      // Should have h1 and h2 in noscript content
      expect(html).toContain('<h1');
      expect(html).toContain('<h2');
    });
  });

  test.describe('keyboard navigation', () => {
    test('page is keyboard navigable', async ({ page, browserName }) => {
      test.skip(browserName !== 'chromium', 'Flutter CanvasKit requires Chromium');
      await page.goto('/', { waitUntil: 'domcontentloaded' });
      await waitForFlutter(page);

      // Tab should work without errors — let Flutter settle between presses
      await page.keyboard.press('Tab');
      await page.waitForTimeout(KEY_SETTLE_MS);
      await page.keyboard.press('Tab');
      await page.waitForTimeout(KEY_SETTLE_MS);

      // Page should still be functional after keyboard interaction
      await assertFlutterRendering(page);
    });

    // #113: Keyboard Navigation Audit Per Page
    const keyboardRoutes = ['/docs', '/contact', '/signup', '/pricing'];

    for (const route of keyboardRoutes) {
      test(`${route} remains functional after keyboard Tab navigation`, async ({ page, browserName }) => {
        test.skip(browserName !== 'chromium', 'Flutter CanvasKit requires Chromium');
        await page.goto(route, { waitUntil: 'domcontentloaded' });
        await waitForFlutter(page);

        // Press Tab 3 times — Flutter intercepts, page must not crash
        for (let i = 0; i < 3; i++) {
          await page.keyboard.press('Tab');
        }
        await page.waitForTimeout(KEY_SETTLE_MS);

        await assertFlutterRendering(page);
      });
    }
  });

  test.describe('color and contrast', () => {
    test('theme color meta tag is present', async ({ request }) => {
      const response = await request.get('/');
      const html = await response.text();
      expect(html).toContain('name="theme-color"');
    });
  });

  test.describe('images and media', () => {
    test('og:image has alt text', async ({ request }) => {
      const response = await request.get('/');
      const html = await response.text();
      expect(html).toContain('og:image:alt');
    });

    test('noscript img has display:none style', async ({ request }) => {
      const response = await request.get('/');
      const html = await response.text();

      // Meta pixel noscript image should be hidden
      expect(html).toMatch(/<img[^>]*style="display:none"/);
    });
  });
});
