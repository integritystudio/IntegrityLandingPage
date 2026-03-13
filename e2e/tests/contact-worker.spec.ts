import { test, expect } from '@playwright/test';
import {
  CONTACT_WORKER_URL,
  SITE_URL,
  HTTP_OK,
  HTTP_BAD_REQUEST,
  HTTP_FORBIDDEN,
  HTTP_METHOD_NOT_ALLOWED,
  HTTP_UNPROCESSABLE_ENTITY,
  HTTP_TOO_MANY_REQUESTS,
  HTTP_SERVICE_UNAVAILABLE,
  CONTENT_TYPE_JSON,
  HEADER_CONTENT_TYPE,
  HEADER_ORIGIN,
  HEADER_ALLOW_ORIGIN,
  HEADER_ALLOW_METHODS,
  HEADER_REQUEST_METHOD,
  HEADER_REQUEST_HEADERS,
  HEADER_CSRF_TOKEN,
  MALICIOUS_ORIGIN,
} from './constants';

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
 * Worker URL: see CONTACT_WORKER_URL in e2e/tests/constants.ts
 * Configured via CONTACT_API_URL dart-define in contact_service.dart.
 */

const ALLOWED_ORIGIN = SITE_URL;

test.describe('Contact Form Worker API (#109)', () => {
  // -------------------------------------------------------------------------
  // CORS preflight
  // -------------------------------------------------------------------------

  test.describe('CORS preflight', () => {
    test('OPTIONS returns 200 for allowed origin', async ({ request }) => {
      const response = await request.fetch(CONTACT_WORKER_URL, {
        method: 'OPTIONS',
        headers: {
          [HEADER_ORIGIN]: ALLOWED_ORIGIN,
          [HEADER_REQUEST_METHOD]: 'POST',
          [HEADER_REQUEST_HEADERS]: HEADER_CONTENT_TYPE,
        },
      });
      expect(response.status()).toBe(HTTP_OK);
    });

    test('OPTIONS response includes Access-Control-Allow-Origin', async ({ request }) => {
      const response = await request.fetch(CONTACT_WORKER_URL, {
        method: 'OPTIONS',
        headers: { [HEADER_ORIGIN]: ALLOWED_ORIGIN },
      });
      const headers = response.headers();
      expect(headers[HEADER_ALLOW_ORIGIN]).toBe(ALLOWED_ORIGIN);
    });

    test('OPTIONS response includes allowed methods', async ({ request }) => {
      const response = await request.fetch(CONTACT_WORKER_URL, {
        method: 'OPTIONS',
        headers: { [HEADER_ORIGIN]: ALLOWED_ORIGIN },
      });
      const allowMethods = response.headers()[HEADER_ALLOW_METHODS] ?? '';
      expect(allowMethods).toContain('POST');
    });
  });

  // -------------------------------------------------------------------------
  // Origin gating
  // -------------------------------------------------------------------------

  test.describe('origin gating', () => {
    test('POST from unauthorized origin is rejected (403 or 429)', async ({ request }) => {
      const response = await request.post(CONTACT_WORKER_URL, {
        headers: {
          [HEADER_CONTENT_TYPE]: CONTENT_TYPE_JSON,
          [HEADER_ORIGIN]: MALICIOUS_ORIGIN,
        },
        data: { name: 'Test', email: '[email protected]' },
      });
      // Worker returns 403 for bad origin; CF edge may return 429 if rate-limited
      expect([HTTP_FORBIDDEN, HTTP_TOO_MANY_REQUESTS]).toContain(response.status());
      if (response.status() === HTTP_FORBIDDEN) {
        const body = await response.json();
        expect(body.error).toBeDefined();
      }
    });

    test('GET from unauthorized origin is rejected (403 or 429)', async ({ request }) => {
      const response = await request.get(CONTACT_WORKER_URL, {
        headers: { [HEADER_ORIGIN]: MALICIOUS_ORIGIN },
      });
      // Worker enforces origin on GET (CSRF token endpoint); CF edge may return 429 if rate-limited
      expect([HTTP_FORBIDDEN, HTTP_TOO_MANY_REQUESTS]).toContain(response.status());
      if (response.status() === HTTP_FORBIDDEN) {
        const body = await response.json();
        expect(body.error).toBeDefined();
      }
    });
  });

  // -------------------------------------------------------------------------
  // Method gating
  // -------------------------------------------------------------------------

  test.describe('method gating', () => {
    test('PUT returns 405', async ({ request }) => {
      const response = await request.fetch(CONTACT_WORKER_URL, {
        method: 'PUT',
        headers: {
          [HEADER_CONTENT_TYPE]: CONTENT_TYPE_JSON,
          [HEADER_ORIGIN]: ALLOWED_ORIGIN,
        },
        data: '{}',
      });
      expect(response.status()).toBe(HTTP_METHOD_NOT_ALLOWED);
      const body = await response.json();
      expect(body.error).toBe('Method not allowed');
    });

    test('DELETE returns 405', async ({ request }) => {
      const response = await request.fetch(CONTACT_WORKER_URL, {
        method: 'DELETE',
        headers: { [HEADER_ORIGIN]: ALLOWED_ORIGIN },
      });
      expect(response.status()).toBe(HTTP_METHOD_NOT_ALLOWED);
    });
  });

  // -------------------------------------------------------------------------
  // CSRF token (GET)
  // -------------------------------------------------------------------------

  test.describe('CSRF token endpoint', () => {
    test('GET with valid origin returns JSON', async ({ request }) => {
      const response = await request.get(CONTACT_WORKER_URL, {
        headers: { [HEADER_ORIGIN]: ALLOWED_ORIGIN },
      });
      // 200 if CSRF_SECRET configured, 503 if not
      expect([HTTP_OK, HTTP_SERVICE_UNAVAILABLE]).toContain(response.status());
      // Guard content-type assertion: CF may return an HTML error page on 503,
      // making the application/json assertion misleading rather than meaningful
      if (response.status() === HTTP_SERVICE_UNAVAILABLE) {
        test.skip(); // halts execution; no content-type assertion on 503
        return;
      }
      expect(response.headers()[HEADER_CONTENT_TYPE]).toContain(CONTENT_TYPE_JSON);
    });

    test('GET with valid origin returns CSRF token format on 200', async ({ request }) => {
      const response = await request.get(CONTACT_WORKER_URL, {
        headers: { [HEADER_ORIGIN]: ALLOWED_ORIGIN },
      });
      // Skip (not silently pass) when CSRF_SECRET is not configured and worker returns 503
      if (response.status() !== HTTP_OK) {
        test.skip();
        return;
      }
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
      const response = await request.post(CONTACT_WORKER_URL, {
        headers: {
          [HEADER_CONTENT_TYPE]: CONTENT_TYPE_JSON,
          [HEADER_ORIGIN]: ALLOWED_ORIGIN,
        },
        data: { email: '[email protected]' }, // missing name
      });
      // Skip (not silently pass) when CF edge rate-limits before validation runs
      if (response.status() === HTTP_TOO_MANY_REQUESTS) {
        test.skip();
        return;
      }
      // 400 validation / 403 CSRF / 422
      expect([HTTP_BAD_REQUEST, HTTP_FORBIDDEN, HTTP_UNPROCESSABLE_ENTITY]).toContain(response.status());
    });

    test('POST with invalid email returns client error', async ({ request }) => {
      const response = await request.post(CONTACT_WORKER_URL, {
        headers: {
          [HEADER_CONTENT_TYPE]: CONTENT_TYPE_JSON,
          [HEADER_ORIGIN]: ALLOWED_ORIGIN,
        },
        data: { name: 'Test User', email: 'not-an-email' },
      });
      if (response.status() === HTTP_TOO_MANY_REQUESTS) {
        test.skip();
        return;
      }
      expect([HTTP_BAD_REQUEST, HTTP_FORBIDDEN, HTTP_UNPROCESSABLE_ENTITY]).toContain(response.status());
    });

    test('POST with empty body returns client error', async ({ request }) => {
      const response = await request.post(CONTACT_WORKER_URL, {
        headers: {
          [HEADER_CONTENT_TYPE]: CONTENT_TYPE_JSON,
          [HEADER_ORIGIN]: ALLOWED_ORIGIN,
        },
        data: {},
      });
      if (response.status() === HTTP_TOO_MANY_REQUESTS) {
        test.skip();
        return;
      }
      expect([HTTP_BAD_REQUEST, HTTP_FORBIDDEN, HTTP_UNPROCESSABLE_ENTITY]).toContain(response.status());
    });

    test('POST response is JSON', async ({ request }) => {
      const response = await request.post(CONTACT_WORKER_URL, {
        headers: {
          [HEADER_CONTENT_TYPE]: CONTENT_TYPE_JSON,
          [HEADER_ORIGIN]: ALLOWED_ORIGIN,
        },
        data: {},
      });
      // Skip when CF edge rate-limits before validation runs (HTML body, not JSON)
      if (response.status() === HTTP_TOO_MANY_REQUESTS) {
        test.skip();
        return;
      }
      const ct = response.headers()[HEADER_CONTENT_TYPE] ?? '';
      expect(ct).toContain(CONTENT_TYPE_JSON);
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
      const response = await request.post(CONTACT_WORKER_URL, {
        headers: {
          [HEADER_CONTENT_TYPE]: CONTENT_TYPE_JSON,
          [HEADER_ORIGIN]: ALLOWED_ORIGIN,
          // No X-CSRF-Token header
        },
        data: VALID_SUBMISSION,
      });
      // Skip (not silently pass) when CSRF_SECRET is not configured and worker returns 200
      if (response.status() === HTTP_OK) {
        test.skip();
        return;
      }
      expect([HTTP_FORBIDDEN, HTTP_TOO_MANY_REQUESTS]).toContain(response.status());
      // Guard json() on 403 only — 429 may return HTML body from CF edge
      if (response.status() === HTTP_FORBIDDEN) {
        const body = await response.json();
        expect(body.error).toBeDefined();
      }
    });

    test('POST with valid fields and invalid CSRF token returns 403', async ({ request }) => {
      const response = await request.post(CONTACT_WORKER_URL, {
        headers: {
          [HEADER_CONTENT_TYPE]: CONTENT_TYPE_JSON,
          [HEADER_ORIGIN]: ALLOWED_ORIGIN,
          [HEADER_CSRF_TOKEN]: 'invalid.token',
        },
        data: VALID_SUBMISSION,
      });
      // Skip (not silently pass) when CSRF_SECRET is not configured and worker returns 200
      if (response.status() === HTTP_OK) {
        test.skip();
        return;
      }
      expect([HTTP_FORBIDDEN, HTTP_TOO_MANY_REQUESTS]).toContain(response.status());
    });

    test('POST with valid complete fields returns JSON error response', async ({ request }) => {
      const response = await request.post(CONTACT_WORKER_URL, {
        headers: {
          [HEADER_CONTENT_TYPE]: CONTENT_TYPE_JSON,
          [HEADER_ORIGIN]: ALLOWED_ORIGIN,
        },
        data: VALID_SUBMISSION,
      });
      // Valid fields bypass field-validation errors; response is still an error (CSRF/rate-limit)
      // unless CSRF_SECRET is not configured (200 success path)
      expect([HTTP_OK, HTTP_FORBIDDEN, HTTP_TOO_MANY_REQUESTS]).toContain(response.status());
      const ct = response.headers()[HEADER_CONTENT_TYPE] ?? '';
      expect(ct).toContain(CONTENT_TYPE_JSON);
    });
  });
});
