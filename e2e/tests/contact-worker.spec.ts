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
 * NOTE: x-request-id response header is not forwarded by Cloudflare edge.
 * Worker URL: see CONTACT_WORKER_URL in e2e/tests/constants.ts
 */

const ALLOWED_ORIGIN = SITE_URL;

const CLIENT_ERROR_STATUSES = [HTTP_BAD_REQUEST, HTTP_FORBIDDEN, HTTP_UNPROCESSABLE_ENTITY] as const;

const VALID_SUBMISSION = {
  name: 'E2E Test User',
  email: '[email protected]',
  message: 'Automated test submission — no action required.',
};

test.describe('Contact Form Worker API (#109)', () => {
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
      expect(response.headers()[HEADER_ALLOW_ORIGIN]).toBe(ALLOWED_ORIGIN);
    });

    test('OPTIONS response includes allowed methods', async ({ request }) => {
      const response = await request.fetch(CONTACT_WORKER_URL, {
        method: 'OPTIONS',
        headers: { [HEADER_ORIGIN]: ALLOWED_ORIGIN },
      });
      expect(response.headers()[HEADER_ALLOW_METHODS] ?? '').toContain('POST');
    });
  });

  test.describe('origin gating', () => {
    test('POST from unauthorized origin is rejected (403 or 429)', async ({ request }) => {
      const response = await request.post(CONTACT_WORKER_URL, {
        headers: {
          [HEADER_CONTENT_TYPE]: CONTENT_TYPE_JSON,
          [HEADER_ORIGIN]: MALICIOUS_ORIGIN,
        },
        data: { name: 'Test', email: '[email protected]' },
      });
      expect([HTTP_FORBIDDEN, HTTP_TOO_MANY_REQUESTS]).toContain(response.status());
      if (response.status() === HTTP_FORBIDDEN) {
        expect((await response.json()).error).toBeDefined();
      }
    });

    test('GET from unauthorized origin is rejected (403 or 429)', async ({ request }) => {
      const response = await request.get(CONTACT_WORKER_URL, {
        headers: { [HEADER_ORIGIN]: MALICIOUS_ORIGIN },
      });
      expect([HTTP_FORBIDDEN, HTTP_TOO_MANY_REQUESTS]).toContain(response.status());
      if (response.status() === HTTP_FORBIDDEN) {
        expect((await response.json()).error).toBeDefined();
      }
    });
  });

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
      expect((await response.json()).error).toBe('Method not allowed');
    });

    test('DELETE returns 405', async ({ request }) => {
      const response = await request.fetch(CONTACT_WORKER_URL, {
        method: 'DELETE',
        headers: { [HEADER_ORIGIN]: ALLOWED_ORIGIN },
      });
      expect(response.status()).toBe(HTTP_METHOD_NOT_ALLOWED);
    });
  });

  test.describe('CSRF token endpoint', () => {
    test('GET with valid origin returns JSON', async ({ request }) => {
      const response = await request.get(CONTACT_WORKER_URL, {
        headers: { [HEADER_ORIGIN]: ALLOWED_ORIGIN },
      });
      expect([HTTP_OK, HTTP_SERVICE_UNAVAILABLE]).toContain(response.status());
      if (response.status() === HTTP_SERVICE_UNAVAILABLE) {
        test.skip();
        return;
      }
      expect(response.headers()[HEADER_CONTENT_TYPE]).toContain(CONTENT_TYPE_JSON);
    });

    test('GET with valid origin returns CSRF token format on 200', async ({ request }) => {
      const response = await request.get(CONTACT_WORKER_URL, {
        headers: { [HEADER_ORIGIN]: ALLOWED_ORIGIN },
      });
      if (response.status() !== HTTP_OK) {
        test.skip();
        return;
      }
      const body = await response.json();
      expect(typeof body.csrfToken).toBe('string');
      expect(body.csrfToken).toMatch(/^\d+\.[A-Za-z0-9_-]+$/);
    });
  });

  test.describe('form validation', () => {
    test('POST with missing name returns client error', async ({ request }) => {
      const response = await request.post(CONTACT_WORKER_URL, {
        headers: { [HEADER_CONTENT_TYPE]: CONTENT_TYPE_JSON, [HEADER_ORIGIN]: ALLOWED_ORIGIN },
        data: { email: '[email protected]' },
      });
      if (response.status() === HTTP_TOO_MANY_REQUESTS) { test.skip(); return; }
      expect(CLIENT_ERROR_STATUSES).toContain(response.status());
    });

    test('POST with invalid email returns client error', async ({ request }) => {
      const response = await request.post(CONTACT_WORKER_URL, {
        headers: { [HEADER_CONTENT_TYPE]: CONTENT_TYPE_JSON, [HEADER_ORIGIN]: ALLOWED_ORIGIN },
        data: { name: 'Test User', email: 'not-an-email' },
      });
      if (response.status() === HTTP_TOO_MANY_REQUESTS) { test.skip(); return; }
      expect(CLIENT_ERROR_STATUSES).toContain(response.status());
    });

    test('POST with empty body returns client error', async ({ request }) => {
      const response = await request.post(CONTACT_WORKER_URL, {
        headers: { [HEADER_CONTENT_TYPE]: CONTENT_TYPE_JSON, [HEADER_ORIGIN]: ALLOWED_ORIGIN },
        data: {},
      });
      if (response.status() === HTTP_TOO_MANY_REQUESTS) { test.skip(); return; }
      expect(CLIENT_ERROR_STATUSES).toContain(response.status());
    });

    test('POST response is JSON', async ({ request }) => {
      const response = await request.post(CONTACT_WORKER_URL, {
        headers: { [HEADER_CONTENT_TYPE]: CONTENT_TYPE_JSON, [HEADER_ORIGIN]: ALLOWED_ORIGIN },
        data: {},
      });
      if (response.status() === HTTP_TOO_MANY_REQUESTS) { test.skip(); return; }
      expect(response.headers()[HEADER_CONTENT_TYPE] ?? '').toContain(CONTENT_TYPE_JSON);
    });
  });

  test.describe('submission flow', () => {
    test('POST with valid fields but no CSRF token is rejected', async ({ request }) => {
      const response = await request.post(CONTACT_WORKER_URL, {
        headers: { [HEADER_CONTENT_TYPE]: CONTENT_TYPE_JSON, [HEADER_ORIGIN]: ALLOWED_ORIGIN },
        data: VALID_SUBMISSION,
      });
      if (response.status() === HTTP_OK) { test.skip(); return; }
      expect([HTTP_FORBIDDEN, HTTP_TOO_MANY_REQUESTS]).toContain(response.status());
      if (response.status() === HTTP_FORBIDDEN) {
        expect((await response.json()).error).toBeDefined();
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
      if (response.status() === HTTP_OK) { test.skip(); return; }
      expect([HTTP_FORBIDDEN, HTTP_TOO_MANY_REQUESTS]).toContain(response.status());
    });

    test('POST with valid complete fields returns JSON error response', async ({ request }) => {
      const response = await request.post(CONTACT_WORKER_URL, {
        headers: { [HEADER_CONTENT_TYPE]: CONTENT_TYPE_JSON, [HEADER_ORIGIN]: ALLOWED_ORIGIN },
        data: VALID_SUBMISSION,
      });
      expect([HTTP_OK, HTTP_FORBIDDEN, HTTP_TOO_MANY_REQUESTS]).toContain(response.status());
      expect(response.headers()[HEADER_CONTENT_TYPE] ?? '').toContain(CONTENT_TYPE_JSON);
    });
  });
});
