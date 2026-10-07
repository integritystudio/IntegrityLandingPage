/**
 * Tests for Integrity Studio Sender Worker
 *
 * Tests inter-worker request signing and forwarding to receiver-worker.
 * Run with: npm test
 */

import { describe, it, expect, beforeEach, afterEach, vi } from 'vitest';
import { ERROR_CODE } from './types';


interface SuccessResponse {
  ok: boolean;
  received: Record<string, unknown>;
}

interface ErrorResponse {
  error: string;
  code: string;
}

type ApiResponse = SuccessResponse | ErrorResponse;

interface Env {
  /** Optional, mirroring the real Env: nothing reads it, and CR29 step 3 unbinds it. */
  SHARED_SECRET?: string;
  SIGNING_KEYS?: string;
  ACTIVE_KEY_ID?: string;
  RECEIVER: Fetcher;
  SUPABASE_URL: string;
  SUPABASE_SERVICE_ROLE_KEY: string;
  ALLOWED_ORIGINS_JSON?: string;
  STRIPE_SECRET_KEY?: string;
  STRIPE_PLAN_TO_PRICE_JSON?: string;
  APP_BASE_URL?: string;
}

import worker from './index';

// Mock receiver service binding
const mockReceiverFetch = vi.fn<(...args: unknown[]) => Promise<Response>>();
const mockReceiver = { fetch: mockReceiverFetch } as unknown as Fetcher;

/** The active key id and its secret, mirroring production's `v2`. */
const TEST_KEY_ID = 'v2';
const TEST_SECRET_V2 = 'rotated-secret-v2';

// Mock environment. ACTIVE_KEY_ID + SIGNING_KEYS are part of the baseline because they are the
// only credential /send can sign with (CR29 step 2) — a fixture without them describes a worker
// that forwards nothing, which is what the "missing configuration" block below asserts.
// TEST_SECRET_V2 is deliberately different from SHARED_SECRET: if a fallback to the legacy
// credential were ever restored, an identical value would let every signature assertion still
// pass. SHARED_SECRET stays bound because nothing reading it must be proven with it present.
const mockEnv: Env = {
  SHARED_SECRET: 'test-shared-secret-key',
  ACTIVE_KEY_ID: TEST_KEY_ID,
  SIGNING_KEYS: JSON.stringify({ [TEST_KEY_ID]: TEST_SECRET_V2 }),
  RECEIVER: mockReceiver,
  SUPABASE_URL: 'https://supabase.test',
  SUPABASE_SERVICE_ROLE_KEY: 'test-service-role-key',
};

// Helper to compute HMAC-SHA256 signature (matches receiver verification)
async function computeSignature(
  body: string,
  secret: string,
  timestamp: string,
): Promise<string> {
  const encoder = new TextEncoder();
  const key = await crypto.subtle.importKey(
    'raw',
    encoder.encode(secret),
    { name: 'HMAC', hash: 'SHA-256' },
    false,
    ['sign'],
  );
  const sig = await crypto.subtle.sign(
    'HMAC',
    key,
    encoder.encode(`${timestamp}.${body}`),
  );
  return [...new Uint8Array(sig)].map(b => b.toString(16).padStart(2, '0')).join('');
}

const validSendPayload = {
  action: 'provision_api_key',
  jwt: 'eyJhbGciOiJSUzI1NiIsInR5cCI6IkpXVCJ9.eyJzdWIiOiJ1c2VyMTIzIn0.signature',
  name: 'My API Key',
  email: 'user@example.com',
  tier: 'starter',
};

// Shape returned by receiver-worker after full provisioning (steps 8-9 in wire doc)
const validApiKeyResponse = {
  ok: true,
  token: `obtk_${'a'.repeat(64)}`,
  keyId: 'key-uuid-1234',
  prefix: 'obtk_',
  tier: 'starter',
};

// --- DRY helpers for /send tests ---

/**
 * Sets up mockReceiverFetch to return a one-shot JSON response.
 * Only for use in POST /send tests — those call env.RECEIVER.fetch(), not global.fetch().
 */
function mockReceiverResponse(body: unknown, status = 200): void {
  mockReceiverFetch.mockResolvedValueOnce(
    new Response(JSON.stringify(body), {
      status,
      headers: { 'content-type': 'application/json; charset=utf-8' },
    }),
  );
}

/**
 * Builds a POST /send request with a JSON body.
 */
function makeSendRequest(body: unknown, extraHeaders: Record<string, string> = {}): Request {
  return new Request('https://worker.test/send', {
    method: 'POST',
    headers: { 'content-type': 'application/json', ...extraHeaders },
    body: JSON.stringify(body),
  });
}

describe('Sender Worker', () => {
  describe('POST /send — valid provision_api_key requests', () => {
    afterEach(() => {
      mockReceiverFetch.mockReset();
    });

    it('forwards provision_api_key payload to receiver via service binding with HMAC signature', async () => {
      mockReceiverResponse(validApiKeyResponse, 201);

      const request = makeSendRequest(validSendPayload);
      const response = await worker.fetch(request, mockEnv);

      expect(response.status).toBe(201);
      expect(mockReceiverFetch).toHaveBeenCalled();
      const callArgs = mockReceiverFetch.mock.calls[0];
      expect(callArgs[0]).toBe('https://receiver/inbox');
      const fetchRequest = callArgs[1] as RequestInit;
      expect(fetchRequest.headers).toHaveProperty('x-timestamp');
      expect(fetchRequest.headers).toHaveProperty('x-signature');
      // x-key-id is mandatory since CR29 step 2 — the receiver 401s a request without it.
      expect((fetchRequest.headers as Record<string, string>)['x-key-id']).toBe(TEST_KEY_ID);
    });

    it('forwards the client IP to the receiver as X-Forwarded-For', async () => {
      mockReceiverResponse(validApiKeyResponse, 201);

      const request = makeSendRequest(validSendPayload, { 'CF-Connecting-IP': '203.0.113.9' });
      await worker.fetch(request, mockEnv);

      const headers = (mockReceiverFetch.mock.calls[0][1] as RequestInit).headers as Record<string, string>;
      expect(headers['X-Forwarded-For']).toBe('203.0.113.9');
    });

    it('omits X-Forwarded-For when the inbound request has no client IP', async () => {
      mockReceiverResponse(validApiKeyResponse, 201);

      const request = makeSendRequest(validSendPayload);
      await worker.fetch(request, mockEnv);

      const headers = (mockReceiverFetch.mock.calls[0][1] as RequestInit).headers as Record<string, string>;
      expect(headers['X-Forwarded-For']).toBeUndefined();
    });

    it('proxies API key response body (token, keyId, prefix, tier) with 201 status unchanged', async () => {
      mockReceiverResponse(validApiKeyResponse, 201);

      const request = makeSendRequest(validSendPayload);
      const response = await worker.fetch(request, mockEnv);

      expect(response.status).toBe(201);
      const data = await response.json() as typeof validApiKeyResponse;
      expect(data.ok).toBe(true);
      expect(data.token).toBe(validApiKeyResponse.token);
      expect(data.keyId).toBe(validApiKeyResponse.keyId);
      expect(data.prefix).toBe(validApiKeyResponse.prefix);
      expect(data.tier).toBe(validApiKeyResponse.tier);
    });

    it('computes signature over the normalized payload using timestamp.body format', async () => {
      let capturedTimestamp = '';
      let capturedSignature = '';
      let capturedBody = '';

      mockReceiverFetch.mockImplementation(async (_url, init) => {
        const headers = (init as RequestInit)?.headers as Record<string, string>;
        capturedTimestamp = headers['x-timestamp'];
        capturedSignature = headers['x-signature'];
        capturedBody = (init as RequestInit)?.body as string;
        return new Response(JSON.stringify({ ok: true }), {
          status: 200,
          headers: { 'content-type': 'application/json; charset=utf-8' },
        });
      });

      const request = makeSendRequest(validSendPayload);
      await worker.fetch(request, mockEnv);

      // Signed with the key ACTIVE_KEY_ID names, not SHARED_SECRET. The two fixtures hold
      // different values on purpose, so this assertion fails if the legacy fallback returns.
      const expectedSig = await computeSignature(capturedBody, TEST_SECRET_V2, capturedTimestamp);
      expect(capturedSignature).toBe(expectedSig);
      expect(capturedSignature).not.toBe(
        await computeSignature(capturedBody, mockEnv.SHARED_SECRET!, capturedTimestamp),
      );
    });

    it.each(['enterprise', 'growth', 'invalid-tier'])(
      'accepts a caller-supplied tier of %s but never forwards it (CR37)',
      async (tier) => {
        let forwardedPayload: Record<string, unknown> | null = null;

        mockReceiverFetch.mockImplementation(async (_url, init) => {
          forwardedPayload = JSON.parse((init as RequestInit)?.body as string) as Record<string, unknown>;
          return new Response(JSON.stringify({ ok: true }), {
            status: 200,
            headers: { 'content-type': 'application/json; charset=utf-8' },
          });
        });

        const res = await worker.fetch(makeSendRequest({ ...validSendPayload, tier }), mockEnv);

        expect(res.status).toBe(200);
        expect(forwardedPayload).not.toBeNull();
        expect(forwardedPayload).not.toHaveProperty('tier');
      },
    );

    it('includes org_name in forwarded payload when provided', async () => {
      let forwardedPayload: Record<string, unknown> | null = null;

      mockReceiverFetch.mockImplementation(async (_url, init) => {
        forwardedPayload = JSON.parse((init as RequestInit)?.body as string) as Record<string, unknown>;
        return new Response(JSON.stringify({ ok: true }), {
          status: 200,
          headers: { 'content-type': 'application/json; charset=utf-8' },
        });
      });

      const request = makeSendRequest({ ...validSendPayload, org_name: 'Acme Corp' });
      await worker.fetch(request, mockEnv);

      expect(forwardedPayload!['org_name']).toBe('Acme Corp');
    });

    it('omits org_name from forwarded payload when not provided (receiver derives from registrable domain)', async () => {
      let forwardedPayload: Record<string, unknown> | null = null;

      mockReceiverFetch.mockImplementation(async (_url, init) => {
        forwardedPayload = JSON.parse((init as RequestInit)?.body as string) as Record<string, unknown>;
        return new Response(JSON.stringify({ ok: true }), {
          status: 200,
          headers: { 'content-type': 'application/json; charset=utf-8' },
        });
      });

      const request = makeSendRequest(validSendPayload);
      await worker.fetch(request, mockEnv);

      // org_name must be absent so the receiver's tldts-based domain normalization runs,
      // ensuring subdomain emails (e.g. user@mail.co.uk) get the correct registrable domain.
      expect(forwardedPayload!['org_name']).toBeUndefined();
    });

    it('passes through receiver-worker error responses unchanged', async () => {
      mockReceiverResponse({ error: 'invalid signature' }, 401);

      const request = makeSendRequest(validSendPayload);
      const response = await worker.fetch(request, mockEnv);

      expect(response.status).toBe(401);
      const data = await response.json() as ErrorResponse;
      expect(data.error).toBe('invalid signature');
    });
  });

  describe('POST /send — payload validation', () => {
    it('returns 400 when action is missing (treated as unknown action)', async () => {
      const { action: _a, ...noAction } = validSendPayload;
      const request = makeSendRequest(noAction);
      const response = await worker.fetch(request, mockEnv);
      expect(response.status).toBe(400);
      expect((await response.json() as ErrorResponse).error).toContain('unknown action');
    });

    it('returns 400 for unknown action', async () => {
      const request = makeSendRequest({ ...validSendPayload, action: 'unknown_action' });
      const response = await worker.fetch(request, mockEnv);
      expect(response.status).toBe(400);
      expect((await response.json() as ErrorResponse).error).toContain('unknown action');
    });

    it('forwards sign_in action with only jwt + email (no name/tier/org_name)', async () => {
      mockReceiverResponse(
        { ok: true, user: { userId: 'u1', email: 'user@example.com' }, organizations: [], apiKeys: [] },
        200,
      );
      const payload = {
        action: 'sign_in',
        jwt: 'eyJhbGciOiJSUzI1NiIsInR5cCI6IkpXVCJ9.eyJzdWIiOiJ1c2VyMTIzIn0.signature',
        email: 'user@example.com',
      };
      const request = makeSendRequest(payload);
      const response = await worker.fetch(request, mockEnv);
      expect(response.status).toBe(200);

      const forwarded = mockReceiverFetch.mock.calls[0][1] as RequestInit;
      const forwardedBody = JSON.parse(forwarded.body as string);
      expect(forwardedBody).toEqual({ action: 'sign_in', jwt: payload.jwt, email: payload.email });
      expect(forwardedBody).not.toHaveProperty('name');
      expect(forwardedBody).not.toHaveProperty('tier');
    });

    it('returns 401 when sign_in jwt is missing', async () => {
      const request = makeSendRequest({ action: 'sign_in', email: 'user@example.com' });
      const response = await worker.fetch(request, mockEnv);
      expect(response.status).toBe(401);
      expect((await response.json() as ErrorResponse).error).toContain('jwt');
    });

    it('returns 401 when jwt is missing', async () => {
      const { jwt: _j, ...noJwt } = validSendPayload;
      const request = makeSendRequest(noJwt);
      const response = await worker.fetch(request, mockEnv);
      expect(response.status).toBe(401);
      expect((await response.json() as ErrorResponse).error).toContain('jwt');
    });

    it('returns 400 when name is missing', async () => {
      const { name: _n, ...noName } = validSendPayload;
      const request = makeSendRequest(noName);
      const response = await worker.fetch(request, mockEnv);
      expect(response.status).toBe(400);
      expect((await response.json() as ErrorResponse).error).toContain('name');
    });

    it('returns 400 when email is missing', async () => {
      const { email: _e, ...noEmail } = validSendPayload;
      const request = makeSendRequest(noEmail);
      const response = await worker.fetch(request, mockEnv);
      expect(response.status).toBe(400);
      expect((await response.json() as ErrorResponse).error).toContain('email');
    });

    it('returns 400 for invalid email format', async () => {
      const request = makeSendRequest({ ...validSendPayload, email: 'not-an-email' });
      const response = await worker.fetch(request, mockEnv);
      expect(response.status).toBe(400);
      expect((await response.json() as ErrorResponse).error).toContain('email');
    });
  });

  describe('POST /send — invalid JSON body', () => {
    it('returns 400 with invalid json error when body is not valid JSON', async () => {
      const body = 'not valid json {';

      const request = new Request('https://worker.test/send', {
        method: 'POST',
        body,
      });

      const response = await worker.fetch(request, mockEnv);

      expect(response.status).toBe(400);
      const data = await response.json() as ErrorResponse;
      expect(data.error).toBe('invalid json');
    });

    it('sets content-type to application/json; charset=utf-8 on 400 error', async () => {
      const request = new Request('https://worker.test/send', {
        method: 'POST',
        body: 'not valid json {',
      });

      const response = await worker.fetch(request, mockEnv);

      expect(response.status).toBe(400);
      expect(response.headers.get('content-type')).toBe('application/json; charset=utf-8');
    });
  });

  describe('POST /send — missing configuration', () => {
    // The fail-closed tests below assert the receiver was never called, so the mock has to start
    // clean regardless of which describe block ran before this one.
    beforeEach(() => {
      mockReceiverFetch.mockReset();
    });

    afterEach(() => {
      mockReceiverFetch.mockReset();
    });

    it('returns 500 when RECEIVER service binding is missing', async () => {
      const envMissingReceiver = { ...mockEnv, RECEIVER: undefined } as unknown as Env;
      const request = makeSendRequest(validSendPayload);
      const response = await worker.fetch(request, envMissingReceiver);
      expect(response.status).toBe(500);
      expect((await response.json() as ErrorResponse).error).toContain('not configured');
    });

    // CR29 step 2. Previously this asserted a 500 "SHARED_SECRET not configured" — a worker with
    // no signing credential at all. The credential that matters is now ACTIVE_KEY_ID +
    // SIGNING_KEYS, so the same env is still a 500, but for the right reason and with a code that
    // names it. `not.toHaveBeenCalled()` is the load-bearing assertion, not the status: a
    // downgraded keyless request used to be *accepted* by the receiver, so a restored fallback
    // returns 200 here and a status-only test would pass while testing nothing.
    it('returns 500 and forwards nothing when no signing credential is configured', async () => {
      const error = vi.spyOn(console, 'error').mockImplementation(() => {});
      const envMissingSecret = { RECEIVER: mockReceiver } as unknown as Env;
      const request = makeSendRequest(validSendPayload);
      const response = await worker.fetch(request, envMissingSecret);
      expect(response.status).toBe(500);
      expect((await response.json() as ErrorResponse).code).toBe('SIGNING_KEY_UNRESOLVED');
      expect(mockReceiverFetch).not.toHaveBeenCalled();
      error.mockRestore();
    });

    // The legacy path itself: SHARED_SECRET bound, ACTIVE_KEY_ID unset. This used to be a valid
    // configuration that signed keylessly, and the receiver accepted it — which is precisely why
    // no key could ever be retired. Nothing may reach the receiver now.
    it('returns 500 and forwards nothing when ACTIVE_KEY_ID is unset but SHARED_SECRET is bound', async () => {
      const error = vi.spyOn(console, 'error').mockImplementation(() => {});
      const env = {
        ...mockEnv,
        ACTIVE_KEY_ID: undefined,
        SIGNING_KEYS: undefined,
      } as unknown as Env;
      const response = await worker.fetch(makeSendRequest(validSendPayload), env);

      expect(response.status).toBe(500);
      expect((await response.json() as ErrorResponse).code).toBe('SIGNING_KEY_UNRESOLVED');
      expect(mockReceiverFetch).not.toHaveBeenCalled();
      error.mockRestore();
    });

    // CR29 step 3 unbinds SHARED_SECRET once the legacy path is proven dead. A guard that
    // required it unconditionally would turn that step into a /send outage.
    it('signs with the rotated key when ACTIVE_KEY_ID is set and SHARED_SECRET is absent', async () => {
      let capturedKeyId: string | undefined;
      mockReceiverFetch.mockImplementation(async (_url, init) => {
        capturedKeyId = ((init as RequestInit)?.headers as Record<string, string>)['x-key-id'];
        return new Response(JSON.stringify({ ok: true }), {
          status: 200,
          headers: { 'content-type': 'application/json; charset=utf-8' },
        });
      });

      const env = {
        ...mockEnv,
        SHARED_SECRET: '',
        ACTIVE_KEY_ID: 'v2',
        SIGNING_KEYS: JSON.stringify({ v2: 'rotated-secret' }),
      } as unknown as Env;
      const response = await worker.fetch(makeSendRequest(validSendPayload), env);

      expect(response.status).toBe(200);
      expect(capturedKeyId).toBe('v2');
    });

    // The point of failing closed is that nothing reaches the receiver. A request signed with
    // SHARED_SECRET and no x-key-id is accepted by the receiver as legacy-signed, so a fallback
    // here would return 200 and leave the broken ACTIVE_KEY_ID invisible — hence the assertion
    // on the receiver never being called, not just on the status code.
    it('returns 500 and forwards nothing when ACTIVE_KEY_ID is not in SIGNING_KEYS', async () => {
      const error = vi.spyOn(console, 'error').mockImplementation(() => {});
      const env = {
        ...mockEnv,
        ACTIVE_KEY_ID: 'v99',
        SIGNING_KEYS: JSON.stringify({ v2: 'rotated-secret' }),
      } as unknown as Env;
      const response = await worker.fetch(makeSendRequest(validSendPayload), env);

      expect(response.status).toBe(500);
      const body = await response.json() as ErrorResponse;
      expect(body.code).toBe('SIGNING_KEY_UNRESOLVED');
      // No key id, and no hint of which one was expected.
      expect(body.error).not.toContain('v99');
      expect(mockReceiverFetch).not.toHaveBeenCalled();
      error.mockRestore();
    });

    it('returns 500 and forwards nothing when SIGNING_KEYS is malformed', async () => {
      const error = vi.spyOn(console, 'error').mockImplementation(() => {});
      const env = { ...mockEnv, ACTIVE_KEY_ID: 'v2', SIGNING_KEYS: '{oops' } as unknown as Env;
      const response = await worker.fetch(makeSendRequest(validSendPayload), env);

      expect(response.status).toBe(500);
      expect((await response.json() as ErrorResponse).code).toBe('SIGNING_KEY_UNRESOLVED');
      expect(mockReceiverFetch).not.toHaveBeenCalled();
      error.mockRestore();
    });
  });

  describe('POST /send — network errors', () => {
    afterEach(() => {
      mockReceiverFetch.mockReset();
    });

    it('returns 502 when receiver-worker is unreachable', async () => {
      mockReceiverFetch.mockRejectedValueOnce(new TypeError('Failed to fetch'));
      const request = makeSendRequest(validSendPayload);
      const response = await worker.fetch(request, mockEnv);
      expect(response.status).toBe(502);
      expect((await response.json() as ErrorResponse).error).toBe('receiver-worker unreachable');
    });
  });

  describe('Unknown routes', () => {
    // CR49: the inline auth routes were removed (sign-in is Auth0 Universal Login). They must
    // fall through to the router's 404 rather than reach any handler or upstream call.
    it.each(['/signup', '/signin', '/forgot-password'])('returns 404 NOT_FOUND for removed route POST %s', async (path) => {
      const fetchSpy = vi.spyOn(globalThis, 'fetch').mockRejectedValue(new Error('unexpected outbound fetch'));
      const request = new Request(`https://worker.test${path}`, {
        method: 'POST',
        headers: { 'content-type': 'application/json' },
        body: JSON.stringify({ email: 'user@example.com', password: 'Passw0rd!' }),
      });

      const response = await worker.fetch(request, mockEnv);

      expect(response.status).toBe(404);
      expect((await response.json() as ErrorResponse).code).toBe(ERROR_CODE.NOT_FOUND);
      expect(fetchSpy).not.toHaveBeenCalled();
      fetchSpy.mockRestore();
    });

    it('returns 404 for unknown POST routes', async () => {
      const request = new Request('https://worker.test/unknown', {
        method: 'POST',
        body: JSON.stringify({ data: 'test' }),
      });

      const response = await worker.fetch(request, mockEnv);

      expect(response.status).toBe(404);
      const data = await response.json() as ErrorResponse;
      expect(data.error).toBe('not found');
    });

    it('returns 404 for GET requests', async () => {
      const request = new Request('https://worker.test/send', { method: 'GET' });

      const response = await worker.fetch(request, mockEnv);

      expect(response.status).toBe(404);
      const data = await response.json() as ErrorResponse;
      expect(data.error).toBe('not found');
    });

    it('sets content-type to application/json; charset=utf-8 on 404 error', async () => {
      const request = new Request('https://worker.test/send', { method: 'GET' });

      const response = await worker.fetch(request, mockEnv);

      expect(response.status).toBe(404);
      expect(response.headers.get('content-type')).toBe('application/json; charset=utf-8');
    });
  });

  describe('CORS — OPTIONS preflight', () => {
    it('returns 204 with CORS headers for allowed origin', async () => {
      const request = new Request('https://worker.test/send', {
        method: 'OPTIONS',
        headers: { Origin: 'https://integritystudio.ai' },
      });

      const response = await worker.fetch(request, mockEnv);

      expect(response.status).toBe(204);
      expect(response.headers.get('Access-Control-Allow-Origin')).toBe('https://integritystudio.ai');
      expect(response.headers.get('Access-Control-Allow-Methods')).toContain('POST');
      expect(response.headers.get('Access-Control-Allow-Methods')).toContain('OPTIONS');
    });

    it('returns 204 with no CORS headers for disallowed origin', async () => {
      const request = new Request('https://worker.test/send', {
        method: 'OPTIONS',
        headers: { Origin: 'https://evil.example.com' },
      });

      const response = await worker.fetch(request, mockEnv);

      expect(response.status).toBe(204);
      expect(response.headers.get('Access-Control-Allow-Origin')).toBeNull();
    });
  });

  describe('CORS — POST requests', () => {
    afterEach(() => {
      mockReceiverFetch.mockReset();
    });

    it('includes CORS headers on POST response from allowed origin', async () => {
      mockReceiverResponse({ ok: true }, 200);

      const request = makeSendRequest(validSendPayload, { Origin: 'https://www.integritystudio.ai' });
      const response = await worker.fetch(request, mockEnv);

      expect(response.status).toBe(200);
      expect(response.headers.get('Access-Control-Allow-Origin')).toBe('https://www.integritystudio.ai');
    });

    it('returns 403 for POST from disallowed origin', async () => {
      const request = new Request('https://worker.test/send', {
        method: 'POST',
        headers: {
          'content-type': 'application/json',
          Origin: 'https://evil.example.com',
        },
        body: JSON.stringify({ data: 'test' }),
      });

      const response = await worker.fetch(request, mockEnv);

      expect(response.status).toBe(403);
      const data = await response.json() as ErrorResponse;
      expect(data.error).toBe('forbidden');
    });
  });

  describe('CORS — Cloudflare Pages preview origins', () => {
    afterEach(() => {
      mockReceiverFetch.mockReset();
    });

    const previewOrigin = 'https://bc710702.integritystudio-ai-c1a.pages.dev';

    it('returns 204 with CORS headers for a Pages preview-deploy origin (OPTIONS)', async () => {
      const request = new Request('https://worker.test/send', {
        method: 'OPTIONS',
        headers: { Origin: previewOrigin },
      });
      const response = await worker.fetch(request, mockEnv);
      expect(response.status).toBe(204);
      expect(response.headers.get('Access-Control-Allow-Origin')).toBe(previewOrigin);
    });

    it('includes CORS headers on POST response from a Pages preview origin', async () => {
      mockReceiverResponse({ ok: true }, 200);
      const request = makeSendRequest(validSendPayload, { Origin: previewOrigin });
      const response = await worker.fetch(request, mockEnv);
      expect(response.status).toBe(200);
      expect(response.headers.get('Access-Control-Allow-Origin')).toBe(previewOrigin);
    });

    it('allows preview origins even when ALLOWED_ORIGINS_JSON omits them', async () => {
      const envWithCustom: Env = {
        ...mockEnv,
        ALLOWED_ORIGINS_JSON: JSON.stringify(['https://integritystudio.ai']),
      };
      mockReceiverResponse({ ok: true }, 200);
      const request = makeSendRequest(validSendPayload, { Origin: previewOrigin });
      const response = await worker.fetch(request, envWithCustom);
      expect(response.status).toBe(200);
      expect(response.headers.get('Access-Control-Allow-Origin')).toBe(previewOrigin);
    });

    it('rejects a non-https preview-looking origin', async () => {
      const request = makeSendRequest(validSendPayload, {
        Origin: 'http://bc710702.integritystudio-ai-c1a.pages.dev',
      });
      const response = await worker.fetch(request, mockEnv);
      expect(response.status).toBe(403);
      expect((await response.json() as ErrorResponse).error).toBe('forbidden');
    });

    it('rejects a lookalike host that only contains the suffix as a prefix', async () => {
      const request = makeSendRequest(validSendPayload, {
        Origin: 'https://bc710702.integritystudio-ai-c1a.pages.dev.attacker.com',
      });
      const response = await worker.fetch(request, mockEnv);
      expect(response.status).toBe(403);
      expect((await response.json() as ErrorResponse).error).toBe('forbidden');
    });

    it('rejects the bare project alias (no subdomain boundary)', async () => {
      const request = makeSendRequest(validSendPayload, {
        Origin: 'https://integritystudio-ai-c1a.pages.dev',
      });
      const response = await worker.fetch(request, mockEnv);
      expect(response.status).toBe(403);
      expect((await response.json() as ErrorResponse).error).toBe('forbidden');
    });
  });

  describe('POST /create-checkout-session — Stripe checkout', () => {
    const stripeEnv: Env = {
      ...mockEnv,
      STRIPE_SECRET_KEY: 'sk_test_abc123',
      STRIPE_PLAN_TO_PRICE_JSON: JSON.stringify({ growth: 'price_growth_monthly', enterprise: 'price_enterprise_annual' }),
      APP_BASE_URL: 'https://integritystudio.ai',
    };

    const TEST_ORG_ID = '1649a1c1-6377-4c4b-9fc2-4d7534372915';

    /**
     * The handler now makes a Supabase org lookup BEFORE the Stripe call, so
     * sequential mocks (mockResolvedValueOnce) bind to the wrong request. Route
     * by URL instead, and return `stripeBody` so assertions can read the exact
     * form-encoded payload sent to Stripe.
     */
    function mockCheckoutFetch(opts: {
      /** Rows returned by the users lookup; [] simulates an unknown email. */
      users?: Array<{ id: string; default_organization_id: string | null }>;
      /** Rows returned by the membership fallback lookup. */
      memberships?: Array<{ organization_id: string }>;
      /** Force a non-2xx from the users lookup. */
      userLookupStatus?: number;
      checkoutUrl?: string;
    }) {
      const state = { stripeBody: '' };
      const json = (body: unknown, status = 200) =>
        new Response(JSON.stringify(body), { status, headers: { 'content-type': 'application/json' } });

      const spy = vi.spyOn(globalThis, 'fetch').mockImplementation(async (input, init) => {
        const url = typeof input === 'string' ? input : (input as Request).url;
        if (url.includes('/rest/v1/users')) {
          if (opts.userLookupStatus) return json({ message: 'boom' }, opts.userLookupStatus);
          return json(opts.users ?? []);
        }
        if (url.includes('/rest/v1/organization_memberships')) {
          return json(opts.memberships ?? []);
        }
        state.stripeBody = init?.body as string;
        return json({ url: opts.checkoutUrl ?? 'https://checkout.stripe.com/pay/test' });
      });
      return { spy, state };
    }

    it('returns 200 with checkoutUrl on success', async () => {
      const checkoutUrl = 'https://checkout.stripe.com/pay/cs_test_abc123';
      const { spy } = mockCheckoutFetch({
        users: [{ id: 'user-1', default_organization_id: TEST_ORG_ID }],
        checkoutUrl,
      });

      const request = new Request('https://worker.test/create-checkout-session', {
        method: 'POST',
        headers: { 'content-type': 'application/json' },
        body: JSON.stringify({ email: 'user@example.com', tier: 'growth' }),
      });

      const response = await worker.fetch(request, stripeEnv);

      expect(response.status).toBe(200);
      const data = await response.json() as { checkoutUrl: string };
      expect(data.checkoutUrl).toBe(checkoutUrl);
      spy.mockRestore();
    });

    it('calls Stripe API with correct price and mode', async () => {
      const { spy, state } = mockCheckoutFetch({
        users: [{ id: 'user-1', default_organization_id: TEST_ORG_ID }],
      });

      const request = new Request('https://worker.test/create-checkout-session', {
        method: 'POST',
        headers: { 'content-type': 'application/json' },
        body: JSON.stringify({ email: 'user@example.com', tier: 'growth' }),
      });

      await worker.fetch(request, stripeEnv);

      const params = new URLSearchParams(state.stripeBody);
      expect(params.get('mode')).toBe('subscription');
      expect(params.get('line_items[0][price]')).toBe('price_growth_monthly');
      expect(params.get('line_items[0][quantity]')).toBe('1');
      expect(params.has('line_items[0][adjustable_quantity][enabled]')).toBe(false);
      expect(params.get('customer_email')).toBe('user@example.com');
      expect(params.get('success_url')).toContain('/checkout-success');
      expect(params.get('cancel_url')).toContain('/signup?tier=growth');
      spy.mockRestore();
    });

    it('opens an enterprise checkout at its 6-seat minimum and lets the buyer add seats', async () => {
      const { spy, state } = mockCheckoutFetch({
        users: [{ id: 'user-1', default_organization_id: TEST_ORG_ID }],
      });

      const request = new Request('https://worker.test/create-checkout-session', {
        method: 'POST',
        headers: { 'content-type': 'application/json' },
        body: JSON.stringify({ email: 'user@example.com', tier: 'enterprise' }),
      });

      await worker.fetch(request, stripeEnv);

      const params = new URLSearchParams(state.stripeBody);
      expect(params.get('line_items[0][price]')).toBe('price_enterprise_annual');
      expect(params.get('line_items[0][quantity]')).toBe('6');
      expect(params.get('line_items[0][adjustable_quantity][enabled]')).toBe('true');
      expect(params.get('line_items[0][adjustable_quantity][minimum]')).toBe('6');
      spy.mockRestore();
    });

    // stripe-webhook's checkout.session.completed handler reads
    // `session.metadata.org_id || session.client_reference_id` to link the Stripe
    // customer to an org. Without it, linkStripeCustomer never runs.
    it('sets metadata[org_id] from the buyer default organization', async () => {
      const { spy, state } = mockCheckoutFetch({
        users: [{ id: 'user-1', default_organization_id: TEST_ORG_ID }],
      });

      const request = new Request('https://worker.test/create-checkout-session', {
        method: 'POST',
        headers: { 'content-type': 'application/json' },
        body: JSON.stringify({ email: 'user@example.com', tier: 'growth' }),
      });

      const response = await worker.fetch(request, stripeEnv);

      expect(response.status).toBe(200);
      const params = new URLSearchParams(state.stripeBody);
      expect(params.get('metadata[org_id]')).toBe(TEST_ORG_ID);
      expect(params.get('subscription_data[metadata][org_id]')).toBe(TEST_ORG_ID);
      spy.mockRestore();
    });

    it('falls back to the oldest active membership when no default org is set', async () => {
      const { spy, state } = mockCheckoutFetch({
        users: [{ id: 'user-1', default_organization_id: null }],
        memberships: [{ organization_id: TEST_ORG_ID }],
      });

      const request = new Request('https://worker.test/create-checkout-session', {
        method: 'POST',
        headers: { 'content-type': 'application/json' },
        body: JSON.stringify({ email: 'user@example.com', tier: 'growth' }),
      });

      await worker.fetch(request, stripeEnv);

      expect(new URLSearchParams(state.stripeBody).get('metadata[org_id]')).toBe(TEST_ORG_ID);
      spy.mockRestore();
    });

    // A checkout that cannot be attributed is still a sale — never block payment.
    it('still returns 200 without metadata when the email has no org', async () => {
      const { spy, state } = mockCheckoutFetch({ users: [] });

      const request = new Request('https://worker.test/create-checkout-session', {
        method: 'POST',
        headers: { 'content-type': 'application/json' },
        body: JSON.stringify({ email: 'nobody@example.com', tier: 'growth' }),
      });

      const response = await worker.fetch(request, stripeEnv);

      expect(response.status).toBe(200);
      const params = new URLSearchParams(state.stripeBody);
      expect(params.get('metadata[org_id]')).toBeNull();
      expect(params.get('subscription_data[metadata][org_id]')).toBeNull();
      spy.mockRestore();
    });

    it('still returns 200 when the org lookup itself fails', async () => {
      const { spy, state } = mockCheckoutFetch({ userLookupStatus: 500 });

      const request = new Request('https://worker.test/create-checkout-session', {
        method: 'POST',
        headers: { 'content-type': 'application/json' },
        body: JSON.stringify({ email: 'user@example.com', tier: 'growth' }),
      });

      const response = await worker.fetch(request, stripeEnv);

      expect(response.status).toBe(200);
      expect(new URLSearchParams(state.stripeBody).get('metadata[org_id]')).toBeNull();
      spy.mockRestore();
    });

    it('returns 500 when STRIPE_SECRET_KEY is not configured', async () => {
      const noStripeEnv: Env = { ...mockEnv };
      const request = new Request('https://worker.test/create-checkout-session', {
        method: 'POST',
        headers: { 'content-type': 'application/json' },
        body: JSON.stringify({ email: 'user@example.com', tier: 'growth' }),
      });

      const response = await worker.fetch(request, noStripeEnv);

      expect(response.status).toBe(500);
      const data = await response.json() as ErrorResponse;
      expect(data.error).toContain('Stripe not configured');
    });

    it('returns 500 when tier has no configured price', async () => {
      // TS02: stub fetch so the Supabase org lookup does not hit supabase.test.
      // The price check fails before any Stripe call, so only Supabase is stubbed.
      const fetchSpy = vi.spyOn(globalThis, 'fetch').mockImplementation(async (input) => {
        const url = typeof input === 'string' ? input : (input as Request).url;
        if (url.includes('/rest/v1/')) {
          return new Response('[]', { status: 200, headers: { 'content-type': 'application/json' } });
        }
        throw new TypeError(`[test stub] unmatched fetch to ${url}`);
      });
      const noPriceEnv: Env = {
        ...mockEnv,
        STRIPE_SECRET_KEY: 'sk_test_abc123',
        STRIPE_PLAN_TO_PRICE_JSON: JSON.stringify({}),
      };
      const request = new Request('https://worker.test/create-checkout-session', {
        method: 'POST',
        headers: { 'content-type': 'application/json' },
        body: JSON.stringify({ email: 'user@example.com', tier: 'growth' }),
      });

      const response = await worker.fetch(request, noPriceEnv);

      expect(response.status).toBe(500);
      const data = await response.json() as ErrorResponse;
      expect(data.error).toContain('growth');
      fetchSpy.mockRestore();
    });

    it('returns 400 when email is missing', async () => {
      const request = new Request('https://worker.test/create-checkout-session', {
        method: 'POST',
        headers: { 'content-type': 'application/json' },
        body: JSON.stringify({ tier: 'growth' }),
      });

      const response = await worker.fetch(request, stripeEnv);

      expect(response.status).toBe(400);
    });

    it('returns 400 when tier is missing', async () => {
      const request = new Request('https://worker.test/create-checkout-session', {
        method: 'POST',
        headers: { 'content-type': 'application/json' },
        body: JSON.stringify({ email: 'user@example.com' }),
      });

      const response = await worker.fetch(request, stripeEnv);

      expect(response.status).toBe(400);
    });

    it('returns 500 when Stripe API fails', async () => {
      // TS02: route by URL — mockResolvedValueOnce binds to the Supabase org lookup
      // (the first fetch in the handler), not the Stripe call; using a single-shot mock
      // lets the Stripe call through to api.stripe.com. Route instead so both are
      // intercepted correctly.
      const fetchSpy = vi.spyOn(globalThis, 'fetch').mockImplementation(async (input) => {
        const url = typeof input === 'string' ? input : (input as Request).url;
        if (url.includes('/rest/v1/')) {
          return new Response('[]', { status: 200, headers: { 'content-type': 'application/json' } });
        }
        return new Response(JSON.stringify({ error: { message: 'Invalid API key' } }), {
          status: 401,
          headers: { 'content-type': 'application/json' },
        });
      });

      const request = new Request('https://worker.test/create-checkout-session', {
        method: 'POST',
        headers: { 'content-type': 'application/json' },
        body: JSON.stringify({ email: 'user@example.com', tier: 'growth' }),
      });

      const response = await worker.fetch(request, stripeEnv);

      expect(response.status).toBe(500);
      fetchSpy.mockRestore();
    });
  });

  describe('CORS — Environment-based origin configuration', () => {
    afterEach(() => {
      mockReceiverFetch.mockReset();
    });

    it('allows development origin when ALLOWED_ORIGINS_JSON is configured', async () => {
      const envWithDevOrigin: Env = {
        ...mockEnv,
        ALLOWED_ORIGINS_JSON: JSON.stringify(['http://localhost:8081', 'https://integritystudio.ai']),
      };
      mockReceiverResponse({ ok: true }, 200);
      const request = makeSendRequest(validSendPayload, { Origin: 'http://localhost:8081' });
      const response = await worker.fetch(request, envWithDevOrigin);
      expect(response.status).toBe(200);
      expect(response.headers.get('Access-Control-Allow-Origin')).toBe('http://localhost:8081');
    });

    it('allows staging origin when configured', async () => {
      const envWithStaging: Env = {
        ...mockEnv,
        ALLOWED_ORIGINS_JSON: JSON.stringify(['https://staging.integritystudio.ai', 'https://www.integritystudio.ai']),
      };
      mockReceiverResponse({ ok: true }, 200);
      const request = makeSendRequest(validSendPayload, { Origin: 'https://staging.integritystudio.ai' });
      const response = await worker.fetch(request, envWithStaging);
      expect(response.status).toBe(200);
      expect(response.headers.get('Access-Control-Allow-Origin')).toBe('https://staging.integritystudio.ai');
    });

    it('rejects unregistered origins even with ALLOWED_ORIGINS_JSON configured', async () => {
      const envWithDevOrigin: Env = {
        ...mockEnv,
        ALLOWED_ORIGINS_JSON: JSON.stringify(['http://localhost:8081']),
      };
      const request = makeSendRequest(validSendPayload, { Origin: 'https://evil.example.com' });
      const response = await worker.fetch(request, envWithDevOrigin);
      expect(response.status).toBe(403);
      expect((await response.json() as ErrorResponse).error).toBe('forbidden');
    });

    it('uses ALLOWED_ORIGINS_JSON when provided, ignoring hardcoded defaults', async () => {
      const customOrigin = 'https://custom.example.com';
      const envWithCustomOrigins: Env = {
        ...mockEnv,
        ALLOWED_ORIGINS_JSON: JSON.stringify([customOrigin]),
      };
      mockReceiverResponse({ ok: true }, 200);
      const request = makeSendRequest(validSendPayload, { Origin: customOrigin });
      const response = await worker.fetch(request, envWithCustomOrigins);
      expect(response.status).toBe(200);
      expect(response.headers.get('Access-Control-Allow-Origin')).toBe(customOrigin);
    });

    it('falls back to hardcoded defaults when ALLOWED_ORIGINS_JSON is not set', async () => {
      mockReceiverResponse({ ok: true }, 200);
      const request = makeSendRequest(validSendPayload, { Origin: 'https://integritystudio.ai' });
      const response = await worker.fetch(request, mockEnv);
      expect(response.status).toBe(200);
      expect(response.headers.get('Access-Control-Allow-Origin')).toBe('https://integritystudio.ai');
    });

    it('falls back to hardcoded defaults when ALLOWED_ORIGINS_JSON is invalid JSON', async () => {
      const envWithBadJson: Env = {
        ...mockEnv,
        ALLOWED_ORIGINS_JSON: 'not-valid-json',
      };
      const request = new Request('https://worker.test/send', {
        method: 'OPTIONS',
        headers: { Origin: 'https://integritystudio.ai' },
      });
      const response = await worker.fetch(request, envWithBadJson);
      expect(response.status).toBe(204);
      expect(response.headers.get('Access-Control-Allow-Origin')).toBe('https://integritystudio.ai');
    });

    it('falls back to hardcoded defaults when ALLOWED_ORIGINS_JSON is a JSON string, not an array', async () => {
      // A JSON string like `"https://attacker.com"` would previously pass as string[] and allow
      // substring matching — e.g. any origin containing that value would match .includes().
      const envWithStringJson: Env = {
        ...mockEnv,
        ALLOWED_ORIGINS_JSON: JSON.stringify('https://integritystudio.ai'),
      };
      const request = new Request('https://worker.test/send', {
        method: 'OPTIONS',
        headers: { Origin: 'https://integritystudio.ai' },
      });
      const response = await worker.fetch(request, envWithStringJson);
      // Falls back to hardcoded defaults, which include integritystudio.ai — still 204
      expect(response.status).toBe(204);
      expect(response.headers.get('Access-Control-Allow-Origin')).toBe('https://integritystudio.ai');
    });

    it('falls back to hardcoded defaults when ALLOWED_ORIGINS_JSON is a JSON object, not an array', async () => {
      // A JSON object would previously crash every request with TypeError (no .includes method).
      const envWithObjectJson: Env = {
        ...mockEnv,
        ALLOWED_ORIGINS_JSON: JSON.stringify({ origin: 'https://integritystudio.ai' }),
      };
      const request = new Request('https://worker.test/send', {
        method: 'OPTIONS',
        headers: { Origin: 'https://integritystudio.ai' },
      });
      const response = await worker.fetch(request, envWithObjectJson);
      expect(response.status).toBe(204);
      expect(response.headers.get('Access-Control-Allow-Origin')).toBe('https://integritystudio.ai');
    });
  });

  describe('POST /create-checkout-session — invalid JSON body', () => {
    it('returns 400 with invalid json error when body is not valid JSON', async () => {
      const stripeEnv: Env = {
        ...mockEnv,
        STRIPE_SECRET_KEY: 'sk_test_abc123',
      };
      const request = new Request('https://worker.test/create-checkout-session', {
        method: 'POST',
        body: 'not valid json {',
      });
      const response = await worker.fetch(request, stripeEnv);
      expect(response.status).toBe(400);
      const data = await response.json() as ErrorResponse;
      expect(data.error).toBe('invalid json');
      expect(data.code).toBe(ERROR_CODE.JSON_PARSE_ERROR);
    });
  });

  describe('POST /send — JWT extraction fallbacks', () => {
    afterEach(() => {
      mockReceiverFetch.mockReset();
    });

    it('extracts JWT from Authorization Bearer header when jwt absent in body', async () => {
      let capturedPayload: Record<string, unknown> | null = null;
      mockReceiverFetch.mockImplementation(async (_url, init) => {
        capturedPayload = JSON.parse((init as RequestInit)?.body as string) as Record<string, unknown>;
        return new Response(JSON.stringify({ ok: true }), {
          status: 200,
          headers: { 'content-type': 'application/json' },
        });
      });

      const { jwt, ...noJwt } = validSendPayload;
      const request = new Request('https://worker.test/send', {
        method: 'POST',
        headers: {
          'content-type': 'application/json',
          authorization: `Bearer ${jwt}`,
        },
        body: JSON.stringify(noJwt),
      });
      await worker.fetch(request, mockEnv);
      expect(capturedPayload!['jwt']).toBe(jwt);
    });

    it('extracts JWT from x-session-data header (base64-encoded)', async () => {
      let capturedPayload: Record<string, unknown> | null = null;
      mockReceiverFetch.mockImplementation(async (_url, init) => {
        capturedPayload = JSON.parse((init as RequestInit)?.body as string) as Record<string, unknown>;
        return new Response(JSON.stringify({ ok: true }), {
          status: 200,
          headers: { 'content-type': 'application/json' },
        });
      });

      const { jwt, ...noJwt } = validSendPayload;
      const encoded = btoa(jwt);
      const request = new Request('https://worker.test/send', {
        method: 'POST',
        headers: {
          'content-type': 'application/json',
          'x-session-data': encoded,
        },
        body: JSON.stringify(noJwt),
      });
      await worker.fetch(request, mockEnv);
      expect(capturedPayload!['jwt']).toBe(jwt);
    });

    it('uses x-session-data value as-is when base64 decode fails', async () => {
      let capturedPayload: Record<string, unknown> | null = null;
      mockReceiverFetch.mockImplementation(async (_url, init) => {
        capturedPayload = JSON.parse((init as RequestInit)?.body as string) as Record<string, unknown>;
        return new Response(JSON.stringify({ ok: true }), {
          status: 200,
          headers: { 'content-type': 'application/json' },
        });
      });

      const rawJwt = validSendPayload.jwt;
      const { jwt: _j, ...noJwt } = validSendPayload;
      // Pass the raw JWT directly — atob will fail on the '.' characters in a JWT
      // but the fallback assigns sessionData directly
      const request = new Request('https://worker.test/send', {
        method: 'POST',
        headers: {
          'content-type': 'application/json',
          'x-session-data': rawJwt,
        },
        body: JSON.stringify(noJwt),
      });
      await worker.fetch(request, mockEnv);
      // Either decoded or raw value is set; key point is jwt is populated
      expect(capturedPayload!['jwt']).toBeTruthy();
    });
  });

  describe('POST /create-checkout-session — Stripe edge cases', () => {
    const stripeEnv: Env = {
      ...mockEnv,
      STRIPE_SECRET_KEY: 'sk_test_abc123',
      STRIPE_PLAN_TO_PRICE_JSON: JSON.stringify({ growth: 'price_growth_monthly' }),
      APP_BASE_URL: 'https://integritystudio.ai',
    };

    it('returns 500 when STRIPE_PLAN_TO_PRICE_JSON is invalid JSON', async () => {
      // TS02: stub fetch so Supabase org lookup does not hit supabase.test.
      // JSON parse fails before any Stripe call, so only Supabase needs stubbing.
      const fetchSpy = vi.spyOn(globalThis, 'fetch').mockImplementation(async (input) => {
        const url = typeof input === 'string' ? input : (input as Request).url;
        if (url.includes('/rest/v1/')) {
          return new Response('[]', { status: 200, headers: { 'content-type': 'application/json' } });
        }
        throw new TypeError(`[test stub] unmatched fetch to ${url}`);
      });
      const badJsonEnv: Env = {
        ...mockEnv,
        STRIPE_SECRET_KEY: 'sk_test_abc123',
        STRIPE_PLAN_TO_PRICE_JSON: 'not-valid-json',
      };
      const request = new Request('https://worker.test/create-checkout-session', {
        method: 'POST',
        headers: { 'content-type': 'application/json' },
        body: JSON.stringify({ email: 'user@example.com', tier: 'growth' }),
      });
      const response = await worker.fetch(request, badJsonEnv);
      expect(response.status).toBe(500);
      const data = await response.json() as ErrorResponse;
      expect(data.error).toContain('configuration');
      fetchSpy.mockRestore();
    });

    it('uses default empty price map when STRIPE_PLAN_TO_PRICE_JSON is not set, returning 500', async () => {
      // TS02: stub fetch so Supabase org lookup does not hit supabase.test.
      const fetchSpy = vi.spyOn(globalThis, 'fetch').mockImplementation(async (input) => {
        const url = typeof input === 'string' ? input : (input as Request).url;
        if (url.includes('/rest/v1/')) {
          return new Response('[]', { status: 200, headers: { 'content-type': 'application/json' } });
        }
        throw new TypeError(`[test stub] unmatched fetch to ${url}`);
      });
      const noJsonEnv: Env = {
        ...mockEnv,
        STRIPE_SECRET_KEY: 'sk_test_abc123',
        // STRIPE_PLAN_TO_PRICE_JSON intentionally absent
      };
      const request = new Request('https://worker.test/create-checkout-session', {
        method: 'POST',
        headers: { 'content-type': 'application/json' },
        body: JSON.stringify({ email: 'user@example.com', tier: 'growth' }),
      });
      const response = await worker.fetch(request, noJsonEnv);
      expect(response.status).toBe(500);
      const data = await response.json() as ErrorResponse;
      expect(data.error).toContain('growth');
      fetchSpy.mockRestore();
    });

    // These two route by URL rather than using mockResolvedValueOnce: the handler
    // makes a Supabase org lookup before the Stripe call, so a single-shot mock
    // binds to the lookup and the Stripe branch under test never runs. The lookup
    // returns [] (no org) so only the Stripe behaviour is exercised.
    it('returns 500 when Stripe response is missing the session URL', async () => {
      const fetchSpy = vi.spyOn(globalThis, 'fetch').mockImplementation(async (input) => {
        const url = typeof input === 'string' ? input : (input as Request).url;
        if (url.includes('/rest/v1/')) {
          return new Response('[]', { status: 200, headers: { 'content-type': 'application/json' } });
        }
        return new Response(JSON.stringify({ id: 'cs_test_abc' }), {
          status: 200,
          headers: { 'content-type': 'application/json' },
        });
      });
      const request = new Request('https://worker.test/create-checkout-session', {
        method: 'POST',
        headers: { 'content-type': 'application/json' },
        body: JSON.stringify({ email: 'user@example.com', tier: 'growth' }),
      });
      const response = await worker.fetch(request, stripeEnv);
      expect(response.status).toBe(500);
      const data = await response.json() as ErrorResponse;
      expect(data.error).toContain('URL');
      fetchSpy.mockRestore();
    });

    it('returns 500 when Stripe fetch throws a network error', async () => {
      const fetchSpy = vi.spyOn(globalThis, 'fetch').mockImplementation(async (input) => {
        const url = typeof input === 'string' ? input : (input as Request).url;
        if (url.includes('/rest/v1/')) {
          return new Response('[]', { status: 200, headers: { 'content-type': 'application/json' } });
        }
        throw new TypeError('Failed to fetch');
      });
      const request = new Request('https://worker.test/create-checkout-session', {
        method: 'POST',
        headers: { 'content-type': 'application/json' },
        body: JSON.stringify({ email: 'user@example.com', tier: 'growth' }),
      });
      const response = await worker.fetch(request, stripeEnv);
      expect(response.status).toBe(500);
      const data = await response.json() as ErrorResponse;
      expect(data.error).toContain('unavailable');
      fetchSpy.mockRestore();
    });
  });

  describe('POST /send — non-TypeError exception from receiver', () => {
    afterEach(() => {
      mockReceiverFetch.mockReset();
    });

    it('returns 500 when receiver throws a non-TypeError error', async () => {
      mockReceiverFetch.mockRejectedValueOnce(new Error('internal error'));
      const request = makeSendRequest(validSendPayload);
      const response = await worker.fetch(request, mockEnv);
      expect(response.status).toBe(500);
      const data = await response.json() as ErrorResponse;
      expect(data.error).toBe('send failed');
    });

    it('returns 500 when receiver throws a non-Error value', async () => {
      mockReceiverFetch.mockRejectedValueOnce('string error');
      const request = makeSendRequest(validSendPayload);
      const response = await worker.fetch(request, mockEnv);
      expect(response.status).toBe(500);
      const data = await response.json() as ErrorResponse;
      expect(data.error).toBe('send failed');
    });

    it('proxies receiver response and sets a content-type when receiver omits content-type header', async () => {
      // Build a response where the content-type header is explicitly null
      const receiverRes = new Response(JSON.stringify({ ok: true }), { status: 200 });
      // Remove content-type by constructing with no headers
      const noCtRes = new Response(receiverRes.body, { status: 200, headers: {} });
      mockReceiverFetch.mockResolvedValueOnce(noCtRes);
      const request = makeSendRequest(validSendPayload);
      const response = await worker.fetch(request, mockEnv);
      expect(response.status).toBe(200);
      // The worker falls back to CONTENT_TYPES.JSON when content-type is null
      expect(response.headers.get('content-type')).toBeTruthy();
    });
  });

  describe('POST /send — enrichReceiverErrorBody', () => {
    // enrichReceiverErrorBody is not exported; it is exercised through the /send endpoint
    // when the receiver returns a non-2xx JSON body with a known error code.

    beforeEach(() => {
      mockReceiverFetch.mockReset();
    });

    it('attaches a description for a known receiver error code', async () => {
      // Simulate a receiver returning a known code with no description yet.
      const receiverBody = { error: 'key not found', code: 'MISSING_FIELDS' };
      mockReceiverFetch.mockResolvedValueOnce(
        new Response(JSON.stringify(receiverBody), {
          status: 400,
          headers: { 'content-type': 'application/json' },
        }),
      );
      const request = makeSendRequest(validSendPayload);
      const response = await worker.fetch(request, mockEnv);
      expect(response.status).toBe(400);
      const data = await response.json() as Record<string, unknown>;
      expect(typeof data['description']).toBe('string');
      expect((data['description'] as string).length).toBeGreaterThan(0);
    });

    it('leaves the body unchanged when a description is already present', async () => {
      const receiverBody = { error: 'bad input', code: 'MISSING_FIELDS', description: 'already set' };
      mockReceiverFetch.mockResolvedValueOnce(
        new Response(JSON.stringify(receiverBody), {
          status: 400,
          headers: { 'content-type': 'application/json' },
        }),
      );
      const request = makeSendRequest(validSendPayload);
      const response = await worker.fetch(request, mockEnv);
      const data = await response.json() as Record<string, unknown>;
      expect(data['description']).toBe('already set');
    });

    it('leaves the body unchanged for an unknown error code', async () => {
      const receiverBody = { error: 'something obscure', code: 'TOTALLY_UNKNOWN_CODE_XYZ' };
      mockReceiverFetch.mockResolvedValueOnce(
        new Response(JSON.stringify(receiverBody), {
          status: 500,
          headers: { 'content-type': 'application/json' },
        }),
      );
      const request = makeSendRequest(validSendPayload);
      const response = await worker.fetch(request, mockEnv);
      const data = await response.json() as Record<string, unknown>;
      expect(data['description']).toBeUndefined();
    });

    it('leaves the body unchanged when the receiver returns 2xx', async () => {
      // enrichReceiverErrorBody skips bodies whose status < 400
      mockReceiverResponse({ ok: true, received: {} }, 200);
      const request = makeSendRequest(validSendPayload);
      const response = await worker.fetch(request, mockEnv);
      expect(response.status).toBe(200);
      const data = await response.json() as Record<string, unknown>;
      expect(data['description']).toBeUndefined();
    });

    it('leaves a non-JSON error body unchanged', async () => {
      mockReceiverFetch.mockResolvedValueOnce(
        new Response('gateway error', {
          status: 502,
          headers: { 'content-type': 'text/plain' },
        }),
      );
      const request = makeSendRequest(validSendPayload);
      const response = await worker.fetch(request, mockEnv);
      expect(response.status).toBe(502);
      const text = await response.text();
      expect(text).toBe('gateway error');
    });

    it('leaves an invalid-JSON error body unchanged', async () => {
      mockReceiverFetch.mockResolvedValueOnce(
        new Response('not json {', {
          status: 400,
          headers: { 'content-type': 'application/json' },
        }),
      );
      const request = makeSendRequest(validSendPayload);
      const response = await worker.fetch(request, mockEnv);
      const text = await response.text();
      expect(text).toBe('not json {');
    });
  });

  describe('GET /health', () => {
    it('returns 200 with service info', async () => {
      const request = new Request('https://worker.test/health', { method: 'GET' });
      const response = await worker.fetch(request, mockEnv);
      expect(response.status).toBe(200);
      const data = await response.json() as { ok: boolean; service: string; version: string; timestamp: string };
      expect(data.ok).toBe(true);
      expect(typeof data.service).toBe('string');
      expect(typeof data.version).toBe('string');
      expect(typeof data.timestamp).toBe('string');
    });
  });

  describe('Environment Variable Validation (Regression Tests)', () => {
    // SHARED_SECRET is deliberately absent from the required list. It is still in mockEnv (the
    // signature tests need it present to prove it is not what /send signs with), but nothing
    // reads it since CR29 step 2 — listing it as required would make its removal fail a test.
    it('the outbound signing credential is present in mockEnv and SHARED_SECRET is not it', () => {
      expect(mockEnv.ACTIVE_KEY_ID).toBe(TEST_KEY_ID);
      expect(JSON.parse(mockEnv.SIGNING_KEYS!) as Record<string, string>).toHaveProperty(TEST_KEY_ID);
      expect(mockEnv).toHaveProperty('SHARED_SECRET');
      expect(mockEnv.SHARED_SECRET).not.toBe(TEST_SECRET_V2);
    });

    it('all required environment variables are present in mockEnv', () => {
      const requiredVars = ['RECEIVER', 'SUPABASE_URL', 'SUPABASE_SERVICE_ROLE_KEY'];

      requiredVars.forEach((varName) => {
        expect(mockEnv).toHaveProperty(varName);
      });
    });
  });
});
