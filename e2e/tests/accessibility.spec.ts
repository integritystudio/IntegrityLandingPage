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
  let html: string;

  test.beforeAll(async ({ request }) => {
    html = await (await request.get('/')).text();
  });

  test.describe('HTML structure', () => {
    test('page has lang attribute', async () => {
      expect(html).toMatch(/<html[^>]*lang="en"/);
    });

    test('page has title', async () => {
      expect(html).toMatch(/<title>[^<]+<\/title>/);
    });

    test('page has meta description', async () => {
      expect(html).toContain('name="description"');
    });

    test('loading spinner has aria attributes', async () => {
      expect(html).toContain('aria-label="Loading application"');
      expect(html).toContain('role="progressbar"');
    });
  });

  test.describe('noscript fallback', () => {
    test('noscript content has semantic HTML', async () => {
      expect(html).toContain('<noscript>');
      expect(html).toMatch(/<main[^>]*>/);
      expect(html).toMatch(/<header[^>]*>/);
      expect(html).toMatch(/<article[^>]*>/);
      expect(html).toMatch(/<footer[^>]*>/);
    });

    test('noscript content has heading hierarchy', async () => {
      expect(html).toContain('<h1');
      expect(html).toContain('<h2');
    });
  });

  test.describe('keyboard navigation', () => {
    test('page is keyboard navigable', async ({ page, browserName }) => {
      test.skip(browserName !== 'chromium', 'Flutter CanvasKit requires Chromium');
      await page.goto('/', { waitUntil: 'domcontentloaded' });
      await waitForFlutter(page);

      await page.keyboard.press('Tab');
      await page.waitForTimeout(KEY_SETTLE_MS);
      await page.keyboard.press('Tab');
      await page.waitForTimeout(KEY_SETTLE_MS);

      await assertFlutterRendering(page);
    });

    // #113: Keyboard Navigation Audit Per Page
    const keyboardRoutes = ['/docs', '/contact', '/signup', '/pricing'];

    for (const route of keyboardRoutes) {
      test(`${route} remains functional after keyboard Tab navigation`, async ({ page, browserName }) => {
        test.skip(browserName !== 'chromium', 'Flutter CanvasKit requires Chromium');
        await page.goto(route, { waitUntil: 'domcontentloaded' });
        await waitForFlutter(page);

        for (let i = 0; i < 3; i++) {
          await page.keyboard.press('Tab');
        }
        await page.waitForTimeout(KEY_SETTLE_MS);

        await assertFlutterRendering(page);
      });
    }
  });

  test.describe('color and contrast', () => {
    test('theme color meta tag is present', async () => {
      expect(html).toContain('name="theme-color"');
    });
  });

  test.describe('images and media', () => {
    test('og:image has alt text', async () => {
      expect(html).toContain('og:image:alt');
    });

    // This asserted the OPPOSITE until 2026-08-08, and had been wrong since
    // f439651 (2026-07-26) — "fix(gdpr): gate Meta Pixel on marketing consent".
    // The <noscript> block used to carry the Facebook Pixel's tracking <img>
    // with display:none; that commit removed it, because a noscript pixel
    // fires for every visitor and there is no way to gate it on consent —
    // which is the entire point of the fix. The old assertion therefore
    // required the privacy fix to be absent. Asserting the ABSENCE instead
    // turns it into a regression test that stops the pixel being reintroduced.
    test('noscript block contains no tracking pixel img', async () => {
      const noscript = html.match(/<noscript>[\s\S]*?<\/noscript>/i)?.[0] ?? '';
      // Positive control: without this, a regex that stopped matching would
      // leave an empty string and the <img> assertion below would pass
      // vacuously — the failure mode this test exists to catch.
      expect(noscript).not.toBe('');
      expect(noscript).not.toMatch(/<img/i);
    });
  });
});
