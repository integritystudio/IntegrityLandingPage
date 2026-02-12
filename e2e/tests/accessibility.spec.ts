import { test, expect } from '@playwright/test';
import { waitForFlutter } from './helpers';

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
    test('page is keyboard navigable', async ({ page }) => {
      await page.goto('/', { waitUntil: 'domcontentloaded' });
      await waitForFlutter(page);

      // Tab should work without errors - use waitForLoadState instead of arbitrary timeouts
      await page.keyboard.press('Tab');
      await page.waitForLoadState('domcontentloaded');
      await page.keyboard.press('Tab');
      await page.waitForLoadState('domcontentloaded');

      // Page should still be functional after keyboard interaction
      const hasFlutter = await page.evaluate(() => {
        return !!(
          document.querySelector('flt-glass-pane') ||
          document.querySelector('flutter-view') ||
          document.querySelector('canvas')
        );
      });
      expect(hasFlutter).toBe(true);
    });
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
