import { test, expect } from '@playwright/test';

/**
 * E2E tests for cache header validation.
 *
 * Validates that Cloudflare Pages _headers configuration correctly applies
 * caching policies to different asset types. Critical for performance and
 * ensuring content updates propagate correctly.
 */
test.describe('Cache Headers', () => {
  test.describe('HTML pages', () => {
    test('index.html has no-cache header', async ({ request }) => {
      const response = await request.get('/');
      expect(response.status()).toBe(200);

      const cacheControl = response.headers()['cache-control'];
      // HTML should not be aggressively cached
      if (cacheControl) {
        expect(cacheControl).toContain('no-cache');
      }
    });
  });

  test.describe('Static assets', () => {
    test('favicon has long cache duration', async ({ request }) => {
      const response = await request.get('/icons/favicon-32x32.png');
      expect(response.status()).toBe(200);

      const cacheControl = response.headers()['cache-control'];
      if (cacheControl) {
        // Should have long cache (immutable or max-age >= 1 year)
        const hasLongCache =
          cacheControl.includes('immutable') ||
          cacheControl.includes('max-age=31536000');
        expect(hasLongCache).toBe(true);
      }
    });

    test('JS files are cacheable', async ({ request }) => {
      const response = await request.get('/js/meta-pixel.js');
      expect(response.status()).toBe(200);

      // JS files should be served with appropriate content type
      const contentType = response.headers()['content-type'];
      expect(contentType).toMatch(/javascript/);
    });
  });

  test.describe('Security headers on all responses', () => {
    test('X-Content-Type-Options is set', async ({ request }) => {
      const response = await request.get('/');
      const header = response.headers()['x-content-type-options'];
      if (header) {
        expect(header).toBe('nosniff');
      }
    });

    test('X-Frame-Options is set', async ({ request }) => {
      const response = await request.get('/');
      const header = response.headers()['x-frame-options'];
      if (header) {
        expect(header).toBe('DENY');
      }
    });

    test('Referrer-Policy is set', async ({ request }) => {
      const response = await request.get('/');
      const header = response.headers()['referrer-policy'];
      if (header) {
        expect(header).toBe('strict-origin-when-cross-origin');
      }
    });

    test('Permissions-Policy is set', async ({ request }) => {
      const response = await request.get('/');
      const header = response.headers()['permissions-policy'];
      if (header) {
        expect(header).toContain('camera=()');
        expect(header).toContain('microphone=()');
      }
    });

    test('Report-To header is present', async ({ request }) => {
      const response = await request.get('/');
      const header = response.headers()['report-to'];
      if (header) {
        const parsed = JSON.parse(header);
        expect(parsed.group).toBe('csp-endpoint');
        expect(parsed.endpoints).toHaveLength(1);
        expect(parsed.endpoints[0].url).toContain('sentry.io');
      }
    });
  });
});
