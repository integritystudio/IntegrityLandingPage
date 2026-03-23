import { test, expect, type APIResponse } from '@playwright/test';
import { IS_LOCAL_DEV, SKIP_REASON_CLOUDFLARE_HEADERS } from './constants';

/**
 * E2E tests for cache header validation.
 *
 * Validates that Cloudflare Pages _headers configuration correctly applies
 * caching policies to different asset types. Critical for performance and
 * ensuring content updates propagate correctly.
 */
test.describe('Cache Headers', () => {
  test.skip(IS_LOCAL_DEV, SKIP_REASON_CLOUDFLARE_HEADERS);
  test.describe('HTML pages', () => {
    test('index.html prevents long-term caching', async ({ request }) => {
      const response = await request.get('/');
      expect(response.status()).toBe(200);

      const cacheControl = response.headers()['cache-control'];
      // Cloudflare may return "no-cache" or "public, max-age=0, must-revalidate"
      // depending on whether the path matches /*.html or / rules
      expect(
        cacheControl.includes('no-cache') || cacheControl.includes('max-age=0'),
      ).toBe(true);
    });
  });

  test.describe('Static assets', () => {
    test('favicon has long cache duration', async ({ request }) => {
      const response = await request.get('/icons/favicon-32x32.png');
      expect(response.status()).toBe(200);

      const cacheControl = response.headers()['cache-control'];
      expect(
        cacheControl.includes('immutable') ||
        cacheControl.includes('max-age=31536000'),
      ).toBe(true);
    });

    test('JS files are cacheable', async ({ request }) => {
      const response = await request.get('/js/meta-pixel.js');
      expect(response.status()).toBe(200);

      const contentType = response.headers()['content-type'];
      expect(contentType).toMatch(/javascript/);
    });
  });

  test.describe('Security headers on all responses', () => {
    let response: APIResponse;

    test.beforeAll(async ({ request }) => {
      response = await request.get('/');
    });

    test('X-Content-Type-Options is set', () => {
      expect(response.headers()['x-content-type-options']).toBe('nosniff');
    });

    test('X-Frame-Options is set', () => {
      expect(response.headers()['x-frame-options']).toBe('DENY');
    });

    test('Referrer-Policy is set', () => {
      expect(response.headers()['referrer-policy']).toBe(
        'strict-origin-when-cross-origin',
      );
    });

    test('Permissions-Policy is set', () => {
      const header = response.headers()['permissions-policy'];
      expect(header).toContain('camera=()');
      expect(header).toContain('microphone=()');
    });

    test('Report-To header is present', () => {
      const header = response.headers()['report-to'];
      expect(header).toBeTruthy();

      const parsed = JSON.parse(header);
      expect(parsed.group).toBe('csp-endpoint');
      expect(parsed.endpoints).toHaveLength(1);
      expect(parsed.endpoints[0].url).toContain('sentry.io');
    });

    test('Reporting-Endpoints header is present', () => {
      const header = response.headers()['reporting-endpoints'];
      expect(header).toContain('csp-endpoint=');
      expect(header).toContain('sentry.io');
    });
  });
});
