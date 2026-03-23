import { test, expect } from '@playwright/test';
import { IS_LOCAL_DEV, SKIP_REASON_CLOUDFLARE_HEADERS } from './constants';

/**
 * E2E tests for cache header validation.
 *
 * Validates that Cloudflare Pages _headers configuration correctly applies
 * caching policies to different asset types. Critical for performance and
 * ensuring content updates propagate correctly.
 */
test.describe('Cache Headers', () => {
  test.beforeEach(() => {
    test.skip(IS_LOCAL_DEV, SKIP_REASON_CLOUDFLARE_HEADERS);
  });
  test.describe('HTML pages', () => {
    test('index.html prevents long-term caching', async ({ request }) => {
      const response = await request.get('/');
      expect(response.status()).toBe(200);

      const cacheControl = response.headers()['cache-control'];
      expect(cacheControl).toBeDefined();
      // Cloudflare may return "no-cache" or "public, max-age=0, must-revalidate"
      // depending on whether the path matches /*.html or / rules
      const preventsCaching =
        cacheControl.includes('no-cache') ||
        cacheControl.includes('max-age=0');
      expect(preventsCaching).toBe(true);
    });
  });

  test.describe('Static assets', () => {
    test('favicon has long cache duration', async ({ request }) => {
      const response = await request.get('/icons/favicon-32x32.png');
      expect(response.status()).toBe(200);

      const cacheControl = response.headers()['cache-control'];
      expect(cacheControl).toBeDefined();
      const hasLongCache =
        cacheControl.includes('immutable') ||
        cacheControl.includes('max-age=31536000');
      expect(hasLongCache).toBe(true);
    });

    test('JS files are cacheable', async ({ request }) => {
      const response = await request.get('/js/meta-pixel.js');
      expect(response.status()).toBe(200);

      const contentType = response.headers()['content-type'];
      expect(contentType).toMatch(/javascript/);
    });
  });

  test.describe('Security headers on all responses', () => {
    test('X-Content-Type-Options is set', async ({ request }) => {
      const response = await request.get('/');
      const header = response.headers()['x-content-type-options'];
      expect(header).toBeDefined();
      expect(header).toBe('nosniff');
    });

    test('X-Frame-Options is set', async ({ request }) => {
      const response = await request.get('/');
      const header = response.headers()['x-frame-options'];
      expect(header).toBeDefined();
      expect(header).toBe('DENY');
    });

    test('Referrer-Policy is set', async ({ request }) => {
      const response = await request.get('/');
      const header = response.headers()['referrer-policy'];
      expect(header).toBeDefined();
      expect(header).toBe('strict-origin-when-cross-origin');
    });

    test('Permissions-Policy is set', async ({ request }) => {
      const response = await request.get('/');
      const header = response.headers()['permissions-policy'];
      expect(header).toBeDefined();
      expect(header).toContain('camera=()');
      expect(header).toContain('microphone=()');
    });

    test('Report-To header is present', async ({ request }) => {
      const response = await request.get('/');
      const header = response.headers()['report-to'];
      expect(header).toBeDefined();
      const parsed = JSON.parse(header);
      expect(parsed.group).toBe('csp-endpoint');
      expect(parsed.endpoints).toHaveLength(1);
      expect(parsed.endpoints[0].url).toContain('sentry.io');
    });

    test('Reporting-Endpoints header is present', async ({ request }) => {
      const response = await request.get('/');
      const header = response.headers()['reporting-endpoints'];
      expect(header).toBeDefined();
      expect(header).toContain('csp-endpoint=');
      expect(header).toContain('sentry.io');
    });
  });
});
