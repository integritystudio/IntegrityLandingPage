import { test, expect } from '@playwright/test';
import { CONTACT_WORKER_URL, SITE_URL } from './constants';

/**
 * E2E tests for the Cloudflare Worker contact form API.
 *
 * Tests the HTTP layer of the contact form submission pipeline without
 * relying on Flutter canvas rendering. Validates:
 * - CORS preflight handling
 * - CSRF token endpoint reachability
 * - Request validation (missing fields, bad email)
 * - Method gating (405 on non-POST/GET)
 * - Origin gating (403 or CF edge block on unauthorized origin)
 *
 * NOTE: Full end-to-end form submission (fill → submit → redirect) is
 * blocked by Flutter canvas rendering (#111 limitation). These tests
 * exercise the HTTP API layer directly.
 *
 * NOTE: x-request-id response header is not forwarded by Cloudflare
 * edge; only the worker-set headers that CF passes through are tested.
 *
 * Worker URL: https://integrity-studio-contact.alyshia-b38.workers.dev
 * Configured via CONTACT_API_URL dart-define in contact_service.dart.
 */

const WORKER_URL = CONTACT_WORKER_URL;
const ALLOWED_ORIGIN = SITE_URL;

test.describe('Contact Form Worker API (#109)', () => {
  // -------------------------------------------------------------------------
  // CORS preflight
  // -------------------------------------------------------------------------

  test.describe('CORS preflight', () => {
    test('OPTIONS returns 200 for allowed origin', async ({ request }) => {
      const response = await request.fetch(WORKER_URL, {
        method: 'OPTIONS',
        headers: {
          'Origin': ALLOWED_ORIGIN,
          'Access-Control-Request-Method': 'POST',
          'Access-Control-Request-Headers': 'Content-Type',
        },
      });
      expect(response.status()).toBe(200);
    });

    test('OPTIONS response includes Access-Control-Allow-Origin', async ({ request }) => {
      const response = await request.fetch(WORKER_URL, {
        method: 'OPTIONS',
        headers: { 'Origin': ALLOWED_ORIGIN },
      });
      const headers = response.headers();
      expect(headers['access-control-allow-origin']).toBe(ALLOWED_ORIGIN);
    });

    test('OPTIONS response includes allowed methods', async ({ request }) => {
      const response = await request.fetch(WORKER_URL, {
        method: 'OPTIONS',
        headers: { 'Origin': ALLOWED_ORIGIN },
      });
      const allowMethods = response.headers()['access-control-allow-methods'] ?? '';
      expect(allowMethods).toContain('POST');
    });
  });

  // -------------------------------------------------------------------------
  // Origin gating
  // -------------------------------------------------------------------------

  test.describe('origin gating', () => {
    test('POST from unauthorized origin is rejected (403 or 429)', async ({ request }) => {
      const response = await request.post(WORKER_URL, {
        headers: {
          'Content-Type': 'application/json',
          'Origin': 'https://malicious.example.com',
        },
        data: { name: 'Test', email: '[email protected]' },
      });
      // Worker returns 403 for bad origin; CF edge may return 429 if rate-limited
      expect([403, 429]).toContain(response.status());
    });

    test('GET from unauthorized origin is rejected (403 or 429)', async ({ request }) => {
      const response = await request.get(WORKER_URL, {
        headers: { 'Origin': 'https://malicious.example.com' },
      });
      // Worker enforces origin on GET (CSRF token endpoint); CF edge may return 429 if rate-limited
      expect([403, 429]).toContain(response.status());
    });
  });

  // -------------------------------------------------------------------------
  // Method gating
  // -------------------------------------------------------------------------

  test.describe('method gating', () => {
    test('PUT returns 405', async ({ request }) => {
      const response = await request.fetch(WORKER_URL, {
        method: 'PUT',
        headers: {
          'Content-Type': 'application/json',
          'Origin': ALLOWED_ORIGIN,
        },
        data: '{}',
      });
      expect(response.status()).toBe(405);
      const body = await response.json();
      expect(body.error).toBe('Method not allowed');
    });

    test('DELETE returns 405', async ({ request }) => {
      const response = await request.fetch(WORKER_URL, {
        method: 'DELETE',
        headers: { 'Origin': ALLOWED_ORIGIN },
      });
      expect(response.status()).toBe(405);
    });
  });

  // -------------------------------------------------------------------------
  // CSRF token (GET)
  // -------------------------------------------------------------------------

  test.describe('CSRF token endpoint', () => {
    test('GET with valid origin returns JSON', async ({ request }) => {
      const response = await request.get(WORKER_URL, {
        headers: { 'Origin': ALLOWED_ORIGIN },
      });
      // 200 if CSRF_SECRET configured, 503 if not
      expect([200, 503]).toContain(response.status());
      expect(response.headers()['content-type']).toContain('application/json');
    });

    test('GET with valid origin returns CSRF token format on 200', async ({ request }) => {
      const response = await request.get(WORKER_URL, {
        headers: { 'Origin': ALLOWED_ORIGIN },
      });
      // Skip (not silently pass) when CSRF_SECRET is not configured and worker returns 503
      test.skip(response.status() !== 200, `Worker returned ${response.status()} — CSRF_SECRET not configured`);
      const body = await response.json();
      expect(body.csrfToken).toBeDefined();
      expect(typeof body.csrfToken).toBe('string');
      // Token format: {timestamp}.{base64url-signature}
      expect(body.csrfToken).toMatch(/^\d+\.[A-Za-z0-9_-]+$/);
    });
  });

  // -------------------------------------------------------------------------
  // Form validation (POST)
  // -------------------------------------------------------------------------

  test.describe('form validation', () => {
    test('POST with missing name returns client error', async ({ request }) => {
      const response = await request.post(WORKER_URL, {
        headers: {
          'Content-Type': 'application/json',
          'Origin': ALLOWED_ORIGIN,
        },
        data: { email: '[email protected]' }, // missing name
      });
      // Skip (not silently pass) when CF edge rate-limits before validation runs
      test.skip(response.status() === 429, 'Rate-limited by CF edge — validation not exercised');
      // 400 validation / 403 CSRF / 422
      expect([400, 403, 422]).toContain(response.status());
    });

    test('POST with invalid email returns client error', async ({ request }) => {
      const response = await request.post(WORKER_URL, {
        headers: {
          'Content-Type': 'application/json',
          'Origin': ALLOWED_ORIGIN,
        },
        data: { name: 'Test User', email: 'not-an-email' },
      });
      test.skip(response.status() === 429, 'Rate-limited by CF edge — validation not exercised');
      expect([400, 403, 422]).toContain(response.status());
    });

    test('POST with empty body returns client error', async ({ request }) => {
      const response = await request.post(WORKER_URL, {
        headers: {
          'Content-Type': 'application/json',
          'Origin': ALLOWED_ORIGIN,
        },
        data: {},
      });
      test.skip(response.status() === 429, 'Rate-limited by CF edge — validation not exercised');
      expect([400, 403, 422]).toContain(response.status());
    });

    test('POST response is JSON', async ({ request }) => {
      const response = await request.post(WORKER_URL, {
        headers: {
          'Content-Type': 'application/json',
          'Origin': ALLOWED_ORIGIN,
        },
        data: {},
      });
      const ct = response.headers()['content-type'] ?? '';
      expect(ct).toContain('application/json');
    });
  });

  // -------------------------------------------------------------------------
  // Submission flow — valid fields, CSRF guard (#109)
  // Tests the full submission path without triggering real email delivery.
  // CSRF validation runs before Resend API call, so a missing/invalid token
  // causes a 403 (or 429 on rate limit) without sending any email.
  // -------------------------------------------------------------------------

  test.describe('submission flow', () => {
    const VALID_SUBMISSION = {
      name: 'E2E Test User',
      email: '[email protected]',
      message: 'Automated test submission — no action required.',
    };

    test('POST with valid fields but no CSRF token is rejected', async ({ request }) => {
      const response = await request.post(WORKER_URL, {
        headers: {
          'Content-Type': 'application/json',
          'Origin': ALLOWED_ORIGIN,
          // No X-CSRF-Token header
        },
        data: VALID_SUBMISSION,
      });
      // Skip (not silently pass) when CSRF_SECRET is not configured and worker returns 200
      test.skip(response.status() === 200, 'CSRF_SECRET not configured — skipping CSRF guard assertion');
      expect([403, 429]).toContain(response.status());
      const body = await response.json();
      expect(body.error).toBeDefined();
    });

    test('POST with valid fields and invalid CSRF token returns 403', async ({ request }) => {
      const response = await request.post(WORKER_URL, {
        headers: {
          'Content-Type': 'application/json',
          'Origin': ALLOWED_ORIGIN,
          'X-CSRF-Token': 'invalid.token',
        },
        data: VALID_SUBMISSION,
      });
      // Skip (not silently pass) when CSRF_SECRET is not configured and worker returns 200
      test.skip(response.status() === 200, 'CSRF_SECRET not configured — skipping CSRF guard assertion');
      expect([403, 429]).toContain(response.status());
    });

    test('POST with valid complete fields returns JSON error response', async ({ request }) => {
      const response = await request.post(WORKER_URL, {
        headers: {
          'Content-Type': 'application/json',
          'Origin': ALLOWED_ORIGIN,
        },
        data: VALID_SUBMISSION,
      });
      // Valid fields bypass field-validation errors; response is still an error (CSRF/rate-limit)
      // unless CSRF_SECRET is not configured (200 success path)
      expect([200, 403, 429]).toContain(response.status());
      const ct = response.headers()['content-type'] ?? '';
      expect(ct).toContain('application/json');
    });
  });
});
