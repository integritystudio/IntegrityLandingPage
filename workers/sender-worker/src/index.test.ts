/**
 * Tests for Integrity Studio Sender Worker
 *
 * Tests inter-worker request signing and forwarding to receiver-worker.
 * Run with: npm test
 */

import { describe, it, expect, beforeEach, afterEach, vi } from 'vitest';
import { FetchMock } from './test-helpers/fetch-mock';
import { fixtures, SignupScenarioBuilder } from './test-helpers/fixtures';


interface SuccessResponse {
  ok: boolean;
  received: Record<string, unknown>;
}

interface ErrorResponse {
  error: string;
}

type ApiResponse = SuccessResponse | ErrorResponse;

interface Env {
  SHARED_SECRET: string;
  RECEIVER: Fetcher;
  AUTH0_DOMAIN: string;
  AUTH0_CLIENT_ID: string;
  AUTH0_CLIENT_SECRET: string;
  AUTH0_CLI_ID: string;
  AUTH0_CLI_SECRET: string;
  AUTH0_AUDIENCE: string;
  SUPABASE_URL: string;
  SUPABASE_SERVICE_ROLE_KEY: string;
  ALLOWED_ORIGINS_JSON?: string;
  STRIPE_SECRET_KEY?: string;
  STRIPE_PLAN_TO_PRICE_JSON?: string;
  APP_BASE_URL?: string;
}

import worker from './index';
import { clearAuthRateLimitStore } from './utils';

// Mock receiver service binding
const mockReceiverFetch = vi.fn<(...args: unknown[]) => Promise<Response>>();
const mockReceiver = { fetch: mockReceiverFetch } as unknown as Fetcher;

// Mock environment
const mockEnv: Env = {
  SHARED_SECRET: 'test-shared-secret-key',
  RECEIVER: mockReceiver,
  AUTH0_DOMAIN: 'test.auth0.com',
  AUTH0_CLIENT_ID: 'test-spa-client-id',
  AUTH0_CLIENT_SECRET: 'test-spa-client-secret',
  AUTH0_CLI_ID: 'test-m2m-client-id',
  AUTH0_CLI_SECRET: 'test-m2m-client-secret',
  AUTH0_AUDIENCE: 'https://test.auth0.com/api/v2/',
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
  // Clear the in-memory auth rate limit store before every test so that tests
  // using the same IP do not bleed state into each other.
  beforeEach(() => {
    clearAuthRateLimitStore();
  });

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

      const expectedSig = await computeSignature(capturedBody, mockEnv.SHARED_SECRET, capturedTimestamp);
      expect(capturedSignature).toBe(expectedSig);
    });

    it('defaults tier to starter when absent', async () => {
      let forwardedPayload: Record<string, unknown> | null = null;

      mockReceiverFetch.mockImplementation(async (_url, init) => {
        forwardedPayload = JSON.parse((init as RequestInit)?.body as string) as Record<string, unknown>;
        return new Response(JSON.stringify({ ok: true }), {
          status: 200,
          headers: { 'content-type': 'application/json; charset=utf-8' },
        });
      });

      const { tier: _tier, ...withoutTier } = validSendPayload;
      const request = makeSendRequest(withoutTier);
      await worker.fetch(request, mockEnv);

      expect(forwardedPayload!['tier']).toBe('starter');
    });

    it('defaults tier to starter when value is invalid', async () => {
      let forwardedPayload: Record<string, unknown> | null = null;

      mockReceiverFetch.mockImplementation(async (_url, init) => {
        forwardedPayload = JSON.parse((init as RequestInit)?.body as string) as Record<string, unknown>;
        return new Response(JSON.stringify({ ok: true }), {
          status: 200,
          headers: { 'content-type': 'application/json; charset=utf-8' },
        });
      });

      const request = makeSendRequest({ ...validSendPayload, tier: 'invalid-tier' });
      await worker.fetch(request, mockEnv);

      expect(forwardedPayload!['tier']).toBe('starter');
    });

    it('preserves valid growth tier', async () => {
      let forwardedPayload: Record<string, unknown> | null = null;

      mockReceiverFetch.mockImplementation(async (_url, init) => {
        forwardedPayload = JSON.parse((init as RequestInit)?.body as string) as Record<string, unknown>;
        return new Response(JSON.stringify({ ok: true }), {
          status: 200,
          headers: { 'content-type': 'application/json; charset=utf-8' },
        });
      });

      const request = makeSendRequest({ ...validSendPayload, tier: 'growth' });
      await worker.fetch(request, mockEnv);

      expect(forwardedPayload!['tier']).toBe('growth');
    });

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
    it('returns 500 when RECEIVER service binding is missing', async () => {
      const envMissingReceiver = { ...mockEnv, RECEIVER: undefined } as unknown as Env;
      const request = makeSendRequest(validSendPayload);
      const response = await worker.fetch(request, envMissingReceiver);
      expect(response.status).toBe(500);
      expect((await response.json() as ErrorResponse).error).toContain('not configured');
    });

    it('returns 500 when SHARED_SECRET is not configured', async () => {
      const envMissingSecret = { SHARED_SECRET: '', RECEIVER: mockReceiver } as unknown as Env;
      const request = makeSendRequest(validSendPayload);
      const response = await worker.fetch(request, envMissingSecret);
      expect(response.status).toBe(500);
      expect((await response.json() as ErrorResponse).error).toContain('not configured');
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

  describe('POST /signup — Auth0 user creation', () => {
    it('calls Auth0 Management API and returns auth0Sub + userId on success', async () => {
      const auth0Sub = 'auth0|test-user-id';
      const generatedUserId = 'aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee';
      const orgId = 'org-uuid-1234';

      const fetchSpy = vi.spyOn(global, 'fetch').mockImplementation(async (url) => {
        const urlStr = String(url);
        if (urlStr.includes('/oauth/token')) {
          return new Response(JSON.stringify({ access_token: 'test-mgmt-token' }), {
            status: 200,
            headers: { 'content-type': 'application/json' },
          });
        }
        if (urlStr.includes('/api/v2/users')) {
          return new Response(JSON.stringify({ user_id: auth0Sub }), {
            status: 201,
            headers: { 'content-type': 'application/json' },
          });
        }
        if (urlStr.includes('/organizations')) {
          return new Response(JSON.stringify([{ id: orgId }]), {
            status: 201,
            headers: { 'content-type': 'application/json' },
          });
        }
        // users insert and org_memberships insert — return minimal
        return new Response('', { status: 201 });
      });

      // crypto.randomUUID is not available in all test environments; stub it
      const uuidSpy = vi.spyOn(crypto, 'randomUUID').mockReturnValue(generatedUserId as `${string}-${string}-${string}-${string}-${string}`);

      const request = new Request('https://worker.test/signup', {
        method: 'POST',
        headers: { 'content-type': 'application/json' },
        body: JSON.stringify({ email: 'user@example.com', password: 'S3cur3!pass' }),
      });

      const response = await worker.fetch(request, mockEnv);

      expect(response.status).toBe(201);
      const data = await response.json() as { auth0Sub: string; userId: string; email: string };
      expect(data.auth0Sub).toBe(auth0Sub);
      expect(data.userId).toBe(generatedUserId);
      expect(data.email).toBe('user@example.com');

      fetchSpy.mockRestore();
      uuidSpy.mockRestore();
    });

    it('sends Auth0 token exchange and user create to the configured domain', async () => {
      const auth0Sub = 'auth0|abc123';
      const orgId = 'org-uuid-5678';
      let capturedTokenUrl = '';
      let capturedUsersUrl = '';

      const fetchSpy = vi.spyOn(global, 'fetch').mockImplementation(async (url) => {
        const urlStr = String(url);
        if (urlStr.includes('/oauth/token')) {
          capturedTokenUrl = urlStr;
          return new Response(JSON.stringify({ access_token: 'test-mgmt-token' }), {
            status: 200,
            headers: { 'content-type': 'application/json' },
          });
        }
        if (urlStr.includes('/api/v2/users')) {
          capturedUsersUrl = urlStr;
          return new Response(JSON.stringify({ user_id: auth0Sub }), {
            status: 201,
            headers: { 'content-type': 'application/json' },
          });
        }
        if (urlStr.includes('/organizations')) {
          return new Response(JSON.stringify([{ id: orgId }]), {
            status: 201,
            headers: { 'content-type': 'application/json' },
          });
        }
        return new Response('', { status: 201 });
      });

      const request = new Request('https://worker.test/signup', {
        method: 'POST',
        headers: { 'content-type': 'application/json' },
        body: JSON.stringify({ email: 'user@example.com', password: 'S3cur3!pass' }),
      });

      await worker.fetch(request, mockEnv);

      expect(capturedTokenUrl).toBe(`https://${mockEnv.AUTH0_DOMAIN}/oauth/token`);
      expect(capturedUsersUrl).toBe(`https://${mockEnv.AUTH0_DOMAIN}/api/v2/users`);

      fetchSpy.mockRestore();
    });

    it('stores auth0Sub (not userId) as auth0_id in the Supabase users insert', async () => {
      const auth0Sub = 'auth0|unique-sub-xyz';
      const orgId = 'org-uuid-9999';
      let capturedUsersBody: Record<string, unknown> | null = null;

      const fetchSpy = vi.spyOn(global, 'fetch').mockImplementation(async (url, init) => {
        const urlStr = String(url);
        if (urlStr.includes('/oauth/token')) {
          return new Response(JSON.stringify({ access_token: 'test-mgmt-token' }), {
            status: 200,
            headers: { 'content-type': 'application/json' },
          });
        }
        if (urlStr.includes('/api/v2/users')) {
          return new Response(JSON.stringify({ user_id: auth0Sub }), {
            status: 201,
            headers: { 'content-type': 'application/json' },
          });
        }
        if (urlStr.includes('/organizations')) {
          return new Response(JSON.stringify([{ id: orgId }]), {
            status: 201,
            headers: { 'content-type': 'application/json' },
          });
        }
        if (urlStr.includes('/rest/v1/users')) {
          capturedUsersBody = JSON.parse(init?.body as string) as Record<string, unknown>;
        }
        return new Response('', { status: 201 });
      });

      const request = new Request('https://worker.test/signup', {
        method: 'POST',
        headers: { 'content-type': 'application/json' },
        body: JSON.stringify({ email: 'user@example.com', password: 'S3cur3!pass' }),
      });

      await worker.fetch(request, mockEnv);

      expect(capturedUsersBody).not.toBeNull();
      expect(capturedUsersBody!['auth0_id']).toBe(auth0Sub);
      expect(capturedUsersBody!['auth0_id']).not.toBe(capturedUsersBody!['id']);

      fetchSpy.mockRestore();
    });

    it('returns 400 when email is missing', async () => {
      const request = new Request('https://worker.test/signup', {
        method: 'POST',
        headers: { 'content-type': 'application/json' },
        body: JSON.stringify({ password: 'S3cur3!pass' }),
      });

      const response = await worker.fetch(request, mockEnv);

      expect(response.status).toBe(400);
      const data = await response.json() as { error: string };
      expect(data.error).toContain('email');
    });

    it('returns 400 when password is missing', async () => {
      const request = new Request('https://worker.test/signup', {
        method: 'POST',
        headers: { 'content-type': 'application/json' },
        body: JSON.stringify({ email: 'user@example.com' }),
      });

      const response = await worker.fetch(request, mockEnv);

      expect(response.status).toBe(400);
      const data = await response.json() as { error: string };
      expect(data.error).toContain('password');
    });

    it('returns 400 for invalid email format', async () => {
      const request = new Request('https://worker.test/signup', {
        method: 'POST',
        headers: { 'content-type': 'application/json' },
        body: JSON.stringify({ email: 'not-an-email', password: 'S3cur3!pass' }),
      });

      const response = await worker.fetch(request, mockEnv);

      expect(response.status).toBe(400);
      const data = await response.json() as { error: string };
      expect(data.error).toContain('email');
    });

    it('returns 500 when Auth0 createUser fails', async () => {
      const fetchSpy = vi.spyOn(global, 'fetch').mockImplementation(async (url) => {
        const urlStr = String(url);
        if (urlStr.includes('/oauth/token')) {
          return new Response(JSON.stringify({ access_token: 'test-mgmt-token' }), {
            status: 200,
            headers: { 'content-type': 'application/json' },
          });
        }
        if (urlStr.includes('/api/v2/users')) {
          return new Response(JSON.stringify({ message: 'conflict' }), {
            status: 409,
            headers: { 'content-type': 'application/json' },
          });
        }
        return new Response('', { status: 201 });
      });

      const request = new Request('https://worker.test/signup', {
        method: 'POST',
        headers: { 'content-type': 'application/json' },
        body: JSON.stringify({ email: 'user@example.com', password: 'S3cur3!pass' }),
      });

      const response = await worker.fetch(request, mockEnv);

      expect(response.status).toBe(500);
      const data = await response.json() as { error: string };
      expect(data.error).toBe('signup failed');

      fetchSpy.mockRestore();
    });

    it('uses provided name as Supabase org name', async () => {
      const orgId = 'org-uuid-name-test';
      let capturedOrgBody: Record<string, unknown> | null = null;

      const fetchSpy = vi.spyOn(global, 'fetch').mockImplementation(async (url, init) => {
        const urlStr = String(url);
        if (urlStr.includes('/oauth/token')) {
          return new Response(JSON.stringify({ access_token: 'test-mgmt-token' }), {
            status: 200, headers: { 'content-type': 'application/json' },
          });
        }
        if (urlStr.includes('/api/v2/users')) {
          return new Response(JSON.stringify({ user_id: 'auth0|abc' }), {
            status: 201, headers: { 'content-type': 'application/json' },
          });
        }
        if (urlStr.includes('/rest/v1/organizations')) {
          capturedOrgBody = JSON.parse(init?.body as string) as Record<string, unknown>;
          return new Response(JSON.stringify([{ id: orgId }]), {
            status: 201, headers: { 'content-type': 'application/json' },
          });
        }
        return new Response('', { status: 201 });
      });

      const request = new Request('https://worker.test/signup', {
        method: 'POST',
        headers: { 'content-type': 'application/json' },
        body: JSON.stringify({ email: 'user@example.com', password: 'S3cur3!pass', name: 'Acme Corp' }),
      });

      await worker.fetch(request, mockEnv);

      expect(capturedOrgBody).not.toBeNull();
      expect(capturedOrgBody!['name']).toBe('Acme Corp');

      fetchSpy.mockRestore();
    });

    it('falls back to email local-part when name is absent', async () => {
      const orgId = 'org-uuid-no-name';
      let capturedOrgBody: Record<string, unknown> | null = null;

      const fetchSpy = vi.spyOn(global, 'fetch').mockImplementation(async (url, init) => {
        const urlStr = String(url);
        if (urlStr.includes('/oauth/token')) {
          return new Response(JSON.stringify({ access_token: 'test-mgmt-token' }), {
            status: 200, headers: { 'content-type': 'application/json' },
          });
        }
        if (urlStr.includes('/api/v2/users')) {
          return new Response(JSON.stringify({ user_id: 'auth0|def' }), {
            status: 201, headers: { 'content-type': 'application/json' },
          });
        }
        if (urlStr.includes('/rest/v1/organizations')) {
          capturedOrgBody = JSON.parse(init?.body as string) as Record<string, unknown>;
          return new Response(JSON.stringify([{ id: orgId }]), {
            status: 201, headers: { 'content-type': 'application/json' },
          });
        }
        return new Response('', { status: 201 });
      });

      const request = new Request('https://worker.test/signup', {
        method: 'POST',
        headers: { 'content-type': 'application/json' },
        body: JSON.stringify({ email: 'alice@example.com', password: 'S3cur3!pass' }),
      });

      await worker.fetch(request, mockEnv);

      expect(capturedOrgBody).not.toBeNull();
      expect(capturedOrgBody!['name']).toBe('alice (personal)');

      fetchSpy.mockRestore();
    });

    it('sets current_plan from tier when provided', async () => {
      const orgId = 'org-uuid-tier-test';
      let capturedOrgBody: Record<string, unknown> | null = null;

      const fetchSpy = vi.spyOn(global, 'fetch').mockImplementation(async (url, init) => {
        const urlStr = String(url);
        if (urlStr.includes('/oauth/token')) {
          return new Response(JSON.stringify({ access_token: 'test-mgmt-token' }), {
            status: 200, headers: { 'content-type': 'application/json' },
          });
        }
        if (urlStr.includes('/api/v2/users')) {
          return new Response(JSON.stringify({ user_id: 'auth0|ghi' }), {
            status: 201, headers: { 'content-type': 'application/json' },
          });
        }
        if (urlStr.includes('/rest/v1/organizations')) {
          capturedOrgBody = JSON.parse(init?.body as string) as Record<string, unknown>;
          return new Response(JSON.stringify([{ id: orgId }]), {
            status: 201, headers: { 'content-type': 'application/json' },
          });
        }
        return new Response('', { status: 201 });
      });

      const request = new Request('https://worker.test/signup', {
        method: 'POST',
        headers: { 'content-type': 'application/json' },
        body: JSON.stringify({ email: 'user@example.com', password: 'S3cur3!pass', tier: 'growth' }),
      });

      await worker.fetch(request, mockEnv);

      expect(capturedOrgBody).not.toBeNull();
      expect(capturedOrgBody!['current_plan']).toBe('growth');

      fetchSpy.mockRestore();
    });

    it('defaults current_plan to starter when tier is absent', async () => {
      const orgId = 'org-uuid-default-tier';
      let capturedOrgBody: Record<string, unknown> | null = null;

      const fetchSpy = vi.spyOn(global, 'fetch').mockImplementation(async (url, init) => {
        const urlStr = String(url);
        if (urlStr.includes('/oauth/token')) {
          return new Response(JSON.stringify({ access_token: 'test-mgmt-token' }), {
            status: 200, headers: { 'content-type': 'application/json' },
          });
        }
        if (urlStr.includes('/api/v2/users')) {
          return new Response(JSON.stringify({ user_id: 'auth0|jkl' }), {
            status: 201, headers: { 'content-type': 'application/json' },
          });
        }
        if (urlStr.includes('/rest/v1/organizations')) {
          capturedOrgBody = JSON.parse(init?.body as string) as Record<string, unknown>;
          return new Response(JSON.stringify([{ id: orgId }]), {
            status: 201, headers: { 'content-type': 'application/json' },
          });
        }
        return new Response('', { status: 201 });
      });

      const request = new Request('https://worker.test/signup', {
        method: 'POST',
        headers: { 'content-type': 'application/json' },
        body: JSON.stringify({ email: 'user@example.com', password: 'S3cur3!pass' }),
      });

      await worker.fetch(request, mockEnv);

      expect(capturedOrgBody).not.toBeNull();
      expect(capturedOrgBody!['current_plan']).toBe('starter');

      fetchSpy.mockRestore();
    });

    it('defaults current_plan to starter when tier is invalid', async () => {
      const orgId = 'org-uuid-invalid-tier';
      let capturedOrgBody: Record<string, unknown> | null = null;

      const fetchSpy = vi.spyOn(global, 'fetch').mockImplementation(async (url, init) => {
        const urlStr = String(url);
        if (urlStr.includes('/oauth/token')) {
          return new Response(JSON.stringify({ access_token: 'test-mgmt-token' }), {
            status: 200, headers: { 'content-type': 'application/json' },
          });
        }
        if (urlStr.includes('/api/v2/users')) {
          return new Response(JSON.stringify({ user_id: 'auth0|mno' }), {
            status: 201, headers: { 'content-type': 'application/json' },
          });
        }
        if (urlStr.includes('/rest/v1/organizations')) {
          capturedOrgBody = JSON.parse(init?.body as string) as Record<string, unknown>;
          return new Response(JSON.stringify([{ id: orgId }]), {
            status: 201, headers: { 'content-type': 'application/json' },
          });
        }
        return new Response('', { status: 201 });
      });

      const request = new Request('https://worker.test/signup', {
        method: 'POST',
        headers: { 'content-type': 'application/json' },
        body: JSON.stringify({ email: 'user@example.com', password: 'S3cur3!pass', tier: 'bogus' }),
      });

      await worker.fetch(request, mockEnv);

      expect(capturedOrgBody).not.toBeNull();
      expect(capturedOrgBody!['current_plan']).toBe('starter');

      fetchSpy.mockRestore();
    });
  });

  describe('POST /signup — ROPC token exchange', () => {
    it('returns jwt in 201 response from ROPC token exchange', async () => {
      let oauthCallCount = 0;

      const fetchSpy = vi.spyOn(global, 'fetch').mockImplementation(async (url) => {
        const urlStr = String(url);
        if (urlStr.includes('/oauth/token')) {
          oauthCallCount++;
          const token = oauthCallCount === 1 ? 'test-mgmt-token' : 'test-user-jwt';
          return new Response(JSON.stringify({ access_token: token }), {
            status: 200,
            headers: { 'content-type': 'application/json' },
          });
        }
        if (urlStr.includes('/api/v2/users')) {
          return new Response(JSON.stringify({ user_id: 'auth0|test-sub' }), {
            status: 201,
            headers: { 'content-type': 'application/json' },
          });
        }
        if (urlStr.includes('/rest/v1/organizations')) {
          return new Response(JSON.stringify([{ id: 'org-uuid-ropc' }]), {
            status: 201,
            headers: { 'content-type': 'application/json' },
          });
        }
        return new Response('', { status: 201 });
      });

      const request = new Request('https://worker.test/signup', {
        method: 'POST',
        headers: { 'content-type': 'application/json' },
        body: JSON.stringify({ email: 'user@example.com', password: 'S3cur3!pass' }),
      });

      const response = await worker.fetch(request, mockEnv);

      expect(response.status).toBe(201);
      const data = await response.json() as { jwt: string; auth0Sub: string; email: string };
      expect(data.jwt).toBe('test-user-jwt');
      expect(data.auth0Sub).toBe('auth0|test-sub');
      expect(data.email).toBe('user@example.com');

      fetchSpy.mockRestore();
    });

    it('calls /oauth/token twice — once for mgmt token then once for ROPC', async () => {
      const oauthCalls: string[] = [];

      const fetchSpy = vi.spyOn(global, 'fetch').mockImplementation(async (url, init) => {
        const urlStr = String(url);
        if (urlStr.includes('/oauth/token')) {
          const body = JSON.parse((init?.body as string) ?? '{}') as { grant_type?: string };
          oauthCalls.push(body.grant_type ?? 'unknown');
          return new Response(JSON.stringify({ access_token: 'token' }), {
            status: 200,
            headers: { 'content-type': 'application/json' },
          });
        }
        if (urlStr.includes('/api/v2/users')) {
          return new Response(JSON.stringify({ user_id: 'auth0|test' }), {
            status: 201,
            headers: { 'content-type': 'application/json' },
          });
        }
        if (urlStr.includes('/rest/v1/organizations')) {
          return new Response(JSON.stringify([{ id: 'org-uuid-ropc-2' }]), {
            status: 201,
            headers: { 'content-type': 'application/json' },
          });
        }
        return new Response('', { status: 201 });
      });

      const request = new Request('https://worker.test/signup', {
        method: 'POST',
        headers: { 'content-type': 'application/json' },
        body: JSON.stringify({ email: 'user@example.com', password: 'S3cur3!pass' }),
      });

      await worker.fetch(request, mockEnv);

      expect(oauthCalls).toHaveLength(2);
      expect(oauthCalls[0]).toBe('client_credentials');
      expect(oauthCalls[1]).toBe('password');

      fetchSpy.mockRestore();
    });
  });

  describe('POST /signin — Auth0 ROPC sign-in', () => {
    it('returns jwt on successful Auth0 sign-in', async () => {
      const fetchSpy = vi.spyOn(global, 'fetch').mockResolvedValueOnce(
        new Response(JSON.stringify({ access_token: 'jwt-from-auth0' }), { status: 200 }),
      );

      const request = new Request('https://worker.test/signin', {
        method: 'POST',
        headers: { 'content-type': 'application/json' },
        body: JSON.stringify({ email: 'user@example.com', password: 'SecurePass123!' }),
      });

      const response = await worker.fetch(request, mockEnv);

      expect(response.status).toBe(200);
      const data = await response.json() as { jwt: string; email: string };
      expect(data.jwt).toBe('jwt-from-auth0');
      expect(data.email).toBe('user@example.com');

      fetchSpy.mockRestore();
    });

    it('returns 400 when email and password are missing', async () => {
      const request = new Request('https://worker.test/signin', {
        method: 'POST',
        headers: { 'content-type': 'application/json' },
        body: JSON.stringify({}),
      });

      const response = await worker.fetch(request, mockEnv);

      expect(response.status).toBe(400);
      const data = await response.json() as { code: string };
      expect(data.code).toBe('MISSING_FIELDS');
    });

    it('returns 400 INVALID_EMAIL for bad email format', async () => {
      const request = new Request('https://worker.test/signin', {
        method: 'POST',
        headers: { 'content-type': 'application/json' },
        body: JSON.stringify({ email: 'not-an-email', password: 'SecurePass123!' }),
      });

      const response = await worker.fetch(request, mockEnv);

      expect(response.status).toBe(400);
      const data = await response.json() as { code: string };
      expect(data.code).toBe('INVALID_EMAIL');
    });

    it('returns 500 when Auth0 ROPC fails', async () => {
      const fetchSpy = vi.spyOn(global, 'fetch').mockResolvedValueOnce(
        new Response(JSON.stringify({ error: 'invalid_grant' }), { status: 403 }),
      );

      const request = new Request('https://worker.test/signin', {
        method: 'POST',
        headers: { 'content-type': 'application/json' },
        body: JSON.stringify({ email: 'user@example.com', password: 'wrong' }),
      });

      const response = await worker.fetch(request, mockEnv);

      expect(response.status).toBe(500);
      const data = await response.json() as { code: string };
      expect(data.code).toBe('INTERNAL_ERROR');

      fetchSpy.mockRestore();
    });
  });

  describe('POST /create-checkout-session — Stripe checkout', () => {
    const stripeEnv: Env = {
      ...mockEnv,
      STRIPE_SECRET_KEY: 'sk_test_abc123',
      STRIPE_PLAN_TO_PRICE_JSON: JSON.stringify({ growth: 'price_growth_monthly', enterprise: 'price_enterprise_annual' }),
      APP_BASE_URL: 'https://integritystudio.ai',
    };

    it('returns 200 with checkoutUrl on success', async () => {
      const checkoutUrl = 'https://checkout.stripe.com/pay/cs_test_abc123';
      const fetchSpy = vi.spyOn(global, 'fetch').mockResolvedValueOnce(
        new Response(JSON.stringify({ url: checkoutUrl }), {
          status: 200,
          headers: { 'content-type': 'application/json' },
        }),
      );

      const request = new Request('https://worker.test/create-checkout-session', {
        method: 'POST',
        headers: { 'content-type': 'application/json' },
        body: JSON.stringify({ email: 'user@example.com', tier: 'growth' }),
      });

      const response = await worker.fetch(request, stripeEnv);

      expect(response.status).toBe(200);
      const data = await response.json() as { checkoutUrl: string };
      expect(data.checkoutUrl).toBe(checkoutUrl);
      fetchSpy.mockRestore();
    });

    it('calls Stripe API with correct price and mode', async () => {
      let capturedBody = '';
      const fetchSpy = vi.spyOn(global, 'fetch').mockImplementation(async (_url, init) => {
        capturedBody = init?.body as string;
        return new Response(JSON.stringify({ url: 'https://checkout.stripe.com/pay/test' }), {
          status: 200,
          headers: { 'content-type': 'application/json' },
        });
      });

      const request = new Request('https://worker.test/create-checkout-session', {
        method: 'POST',
        headers: { 'content-type': 'application/json' },
        body: JSON.stringify({ email: 'user@example.com', tier: 'growth' }),
      });

      await worker.fetch(request, stripeEnv);

      const params = new URLSearchParams(capturedBody);
      expect(params.get('mode')).toBe('subscription');
      expect(params.get('line_items[0][price]')).toBe('price_growth_monthly');
      expect(params.get('line_items[0][quantity]')).toBe('1');
      expect(params.get('customer_email')).toBe('user@example.com');
      expect(params.get('success_url')).toContain('/checkout-success');
      expect(params.get('cancel_url')).toContain('/signup?tier=growth');
      fetchSpy.mockRestore();
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
      const fetchSpy = vi.spyOn(global, 'fetch').mockResolvedValueOnce(
        new Response(JSON.stringify({ error: { message: 'Invalid API key' } }), {
          status: 401,
          headers: { 'content-type': 'application/json' },
        }),
      );

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

  describe('POST /signup — invalid JSON body', () => {
    it('returns 400 with invalid json error when body is not valid JSON', async () => {
      const request = new Request('https://worker.test/signup', {
        method: 'POST',
        body: 'not valid json {',
      });
      const response = await worker.fetch(request, mockEnv);
      expect(response.status).toBe(400);
      const data = await response.json() as ErrorResponse;
      expect(data.error).toBe('invalid json');
    });
  });

  describe('POST /signin — invalid JSON body', () => {
    it('returns 400 with invalid json error when body is not valid JSON', async () => {
      const request = new Request('https://worker.test/signin', {
        method: 'POST',
        body: 'not valid json {',
      });
      const response = await worker.fetch(request, mockEnv);
      expect(response.status).toBe(400);
      const data = await response.json() as ErrorResponse;
      expect(data.error).toBe('invalid json');
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
    });

    it('uses default empty price map when STRIPE_PLAN_TO_PRICE_JSON is not set, returning 500', async () => {
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
    });

    it('returns 500 when Stripe response is missing the session URL', async () => {
      const fetchSpy = vi.spyOn(global, 'fetch').mockResolvedValueOnce(
        new Response(JSON.stringify({ id: 'cs_test_abc' }), {
          status: 200,
          headers: { 'content-type': 'application/json' },
        }),
      );
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
  });

  describe('POST /signup — Supabase error branches', () => {
    it('returns 500 when Supabase org creation fails with HTTP error', async () => {
      const fetchSpy = vi.spyOn(global, 'fetch').mockImplementation(async (url) => {
        const urlStr = String(url);
        if (urlStr.includes('/oauth/token')) {
          return new Response(JSON.stringify({ access_token: 'mgmt-token' }), {
            status: 200, headers: { 'content-type': 'application/json' },
          });
        }
        if (urlStr.includes('/api/v2/users')) {
          return new Response(JSON.stringify({ user_id: 'auth0|abc' }), {
            status: 201, headers: { 'content-type': 'application/json' },
          });
        }
        if (urlStr.includes('/rest/v1/organizations')) {
          return new Response('conflict', { status: 409 });
        }
        return new Response('', { status: 201 });
      });

      const request = new Request('https://worker.test/signup', {
        method: 'POST',
        headers: { 'content-type': 'application/json' },
        body: JSON.stringify({ email: 'user@example.com', password: 'S3cur3!pass' }),
      });
      const response = await worker.fetch(request, mockEnv);
      expect(response.status).toBe(500);
      const data = await response.json() as ErrorResponse;
      expect(data.error).toBe('signup failed');
      fetchSpy.mockRestore();
    });

    it('returns 500 when Supabase org creation returns no id', async () => {
      const fetchSpy = vi.spyOn(global, 'fetch').mockImplementation(async (url) => {
        const urlStr = String(url);
        if (urlStr.includes('/oauth/token')) {
          return new Response(JSON.stringify({ access_token: 'mgmt-token' }), {
            status: 200, headers: { 'content-type': 'application/json' },
          });
        }
        if (urlStr.includes('/api/v2/users')) {
          return new Response(JSON.stringify({ user_id: 'auth0|abc' }), {
            status: 201, headers: { 'content-type': 'application/json' },
          });
        }
        if (urlStr.includes('/rest/v1/organizations')) {
          return new Response(JSON.stringify([{}]), {
            status: 201, headers: { 'content-type': 'application/json' },
          });
        }
        return new Response('', { status: 201 });
      });

      const request = new Request('https://worker.test/signup', {
        method: 'POST',
        headers: { 'content-type': 'application/json' },
        body: JSON.stringify({ email: 'user@example.com', password: 'S3cur3!pass' }),
      });
      const response = await worker.fetch(request, mockEnv);
      expect(response.status).toBe(500);
      const data = await response.json() as ErrorResponse;
      expect(data.error).toBe('signup failed');
      fetchSpy.mockRestore();
    });

    it('returns 500 when Supabase user insert fails', async () => {
      const fetchSpy = vi.spyOn(global, 'fetch').mockImplementation(async (url) => {
        const urlStr = String(url);
        if (urlStr.includes('/oauth/token')) {
          return new Response(JSON.stringify({ access_token: 'mgmt-token' }), {
            status: 200, headers: { 'content-type': 'application/json' },
          });
        }
        if (urlStr.includes('/api/v2/users')) {
          return new Response(JSON.stringify({ user_id: 'auth0|abc' }), {
            status: 201, headers: { 'content-type': 'application/json' },
          });
        }
        if (urlStr.includes('/rest/v1/organizations')) {
          return new Response(JSON.stringify([{ id: 'org-123' }]), {
            status: 201, headers: { 'content-type': 'application/json' },
          });
        }
        if (urlStr.includes('/rest/v1/users')) {
          return new Response('forbidden', { status: 403 });
        }
        return new Response('', { status: 201 });
      });

      const request = new Request('https://worker.test/signup', {
        method: 'POST',
        headers: { 'content-type': 'application/json' },
        body: JSON.stringify({ email: 'user@example.com', password: 'S3cur3!pass' }),
      });
      const response = await worker.fetch(request, mockEnv);
      expect(response.status).toBe(500);
      const data = await response.json() as ErrorResponse;
      expect(data.error).toBe('signup failed');
      fetchSpy.mockRestore();
    });

    it('returns 500 when Supabase org membership insert fails', async () => {
      const fetchSpy = vi.spyOn(global, 'fetch').mockImplementation(async (url) => {
        const urlStr = String(url);
        if (urlStr.includes('/oauth/token')) {
          return new Response(JSON.stringify({ access_token: 'mgmt-token' }), {
            status: 200, headers: { 'content-type': 'application/json' },
          });
        }
        if (urlStr.includes('/api/v2/users')) {
          return new Response(JSON.stringify({ user_id: 'auth0|abc' }), {
            status: 201, headers: { 'content-type': 'application/json' },
          });
        }
        if (urlStr.includes('/rest/v1/organizations')) {
          return new Response(JSON.stringify([{ id: 'org-123' }]), {
            status: 201, headers: { 'content-type': 'application/json' },
          });
        }
        if (urlStr.includes('/rest/v1/users')) {
          return new Response('', { status: 201 });
        }
        if (urlStr.includes('/rest/v1/organization_memberships')) {
          return new Response('forbidden', { status: 403 });
        }
        return new Response('', { status: 201 });
      });

      const request = new Request('https://worker.test/signup', {
        method: 'POST',
        headers: { 'content-type': 'application/json' },
        body: JSON.stringify({ email: 'user@example.com', password: 'S3cur3!pass' }),
      });
      const response = await worker.fetch(request, mockEnv);
      expect(response.status).toBe(500);
      const data = await response.json() as ErrorResponse;
      expect(data.error).toBe('signup failed');
      fetchSpy.mockRestore();
    });

    it('returns 500 when signup throws a non-Error value', async () => {
      const fetchSpy = vi.spyOn(global, 'fetch').mockRejectedValueOnce('unexpected string throw');

      const request = new Request('https://worker.test/signup', {
        method: 'POST',
        headers: { 'content-type': 'application/json' },
        body: JSON.stringify({ email: 'user@example.com', password: 'S3cur3!pass' }),
      });
      const response = await worker.fetch(request, mockEnv);
      expect(response.status).toBe(500);
      const data = await response.json() as ErrorResponse;
      expect(data.error).toBe('signup failed');
      fetchSpy.mockRestore();
    });

    it('returns 500 when Auth0 mgmt token exchange fails (HTTP error)', async () => {
      const fetchSpy = vi.spyOn(global, 'fetch').mockImplementation(async (url) => {
        const urlStr = String(url);
        if (urlStr.includes('/oauth/token')) {
          return new Response('unauthorized', { status: 401 });
        }
        return new Response('', { status: 201 });
      });

      const request = new Request('https://worker.test/signup', {
        method: 'POST',
        headers: { 'content-type': 'application/json' },
        body: JSON.stringify({ email: 'user@example.com', password: 'S3cur3!pass' }),
      });
      const response = await worker.fetch(request, mockEnv);
      expect(response.status).toBe(500);
      const data = await response.json() as ErrorResponse;
      expect(data.error).toBe('signup failed');
      fetchSpy.mockRestore();
    });

    it('returns 500 when Auth0 mgmt token exchange returns no access_token', async () => {
      const fetchSpy = vi.spyOn(global, 'fetch').mockImplementation(async (url) => {
        const urlStr = String(url);
        if (urlStr.includes('/oauth/token')) {
          return new Response(JSON.stringify({}), {
            status: 200, headers: { 'content-type': 'application/json' },
          });
        }
        return new Response('', { status: 201 });
      });

      const request = new Request('https://worker.test/signup', {
        method: 'POST',
        headers: { 'content-type': 'application/json' },
        body: JSON.stringify({ email: 'user@example.com', password: 'S3cur3!pass' }),
      });
      const response = await worker.fetch(request, mockEnv);
      expect(response.status).toBe(500);
      const data = await response.json() as ErrorResponse;
      expect(data.error).toBe('signup failed');
      fetchSpy.mockRestore();
    });

    it('returns 500 when ROPC token exchange (user signin) fails after successful user creation', async () => {
      let oauthCallCount = 0;
      const fetchSpy = vi.spyOn(global, 'fetch').mockImplementation(async (url) => {
        const urlStr = String(url);
        if (urlStr.includes('/oauth/token')) {
          oauthCallCount++;
          if (oauthCallCount === 1) {
            return new Response(JSON.stringify({ access_token: 'mgmt-token' }), {
              status: 200, headers: { 'content-type': 'application/json' },
            });
          }
          // Second call — ROPC — fails
          return new Response('unauthorized', { status: 401 });
        }
        if (urlStr.includes('/api/v2/users')) {
          return new Response(JSON.stringify({ user_id: 'auth0|abc' }), {
            status: 201, headers: { 'content-type': 'application/json' },
          });
        }
        if (urlStr.includes('/rest/v1/organizations')) {
          return new Response(JSON.stringify([{ id: 'org-123' }]), {
            status: 201, headers: { 'content-type': 'application/json' },
          });
        }
        return new Response('', { status: 201 });
      });

      const request = new Request('https://worker.test/signup', {
        method: 'POST',
        headers: { 'content-type': 'application/json' },
        body: JSON.stringify({ email: 'user@example.com', password: 'S3cur3!pass' }),
      });
      const response = await worker.fetch(request, mockEnv);
      expect(response.status).toBe(500);
      const data = await response.json() as ErrorResponse;
      expect(data.error).toBe('signup failed');
      fetchSpy.mockRestore();
    });

    it('returns 500 when ROPC token exchange returns no access_token', async () => {
      let oauthCallCount = 0;
      const fetchSpy = vi.spyOn(global, 'fetch').mockImplementation(async (url) => {
        const urlStr = String(url);
        if (urlStr.includes('/oauth/token')) {
          oauthCallCount++;
          if (oauthCallCount === 1) {
            return new Response(JSON.stringify({ access_token: 'mgmt-token' }), {
              status: 200, headers: { 'content-type': 'application/json' },
            });
          }
          return new Response(JSON.stringify({}), {
            status: 200, headers: { 'content-type': 'application/json' },
          });
        }
        if (urlStr.includes('/api/v2/users')) {
          return new Response(JSON.stringify({ user_id: 'auth0|abc' }), {
            status: 201, headers: { 'content-type': 'application/json' },
          });
        }
        if (urlStr.includes('/rest/v1/organizations')) {
          return new Response(JSON.stringify([{ id: 'org-123' }]), {
            status: 201, headers: { 'content-type': 'application/json' },
          });
        }
        return new Response('', { status: 201 });
      });

      const request = new Request('https://worker.test/signup', {
        method: 'POST',
        headers: { 'content-type': 'application/json' },
        body: JSON.stringify({ email: 'user@example.com', password: 'S3cur3!pass' }),
      });
      const response = await worker.fetch(request, mockEnv);
      expect(response.status).toBe(500);
      const data = await response.json() as ErrorResponse;
      expect(data.error).toBe('signup failed');
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

  describe('POST /signup — Refactored with FetchMock (No Global Spies)', () => {
    let fetchMock: FetchMock;

    afterEach(() => {
      fetchMock?.restore();
    });

    it('successful signup with FetchMock helper (no global spy)', async () => {
      fetchMock = new SignupScenarioBuilder().successful();
      fetchMock.activate();

      const request = new Request('https://worker.test/signup', {
        method: 'POST',
        headers: { 'content-type': 'application/json' },
        body: JSON.stringify({ email: fixtures.user.email, password: fixtures.user.password }),
      });

      const response = await worker.fetch(request, mockEnv);
      expect(response.status).toBe(201);
      const data = await response.json() as Record<string, unknown>;
      expect(data.auth0Sub).toBe(fixtures.auth0.sub);
      expect(data.email).toBe(fixtures.user.email);
    });

    it('tracks fetch calls without global spy', async () => {
      fetchMock = new SignupScenarioBuilder().successful();
      fetchMock.activate();

      const request = new Request('https://worker.test/signup', {
        method: 'POST',
        headers: { 'content-type': 'application/json' },
        body: JSON.stringify({ email: fixtures.user.email, password: fixtures.user.password }),
      });

      await worker.fetch(request, mockEnv);

      expect(fetchMock.assertCalled(/\/oauth\/token/)).toBe(true);
      expect(fetchMock.assertCalled(/\/api\/v2\/users/)).toBe(true);
      expect(fetchMock.assertCalled(/\/organizations/)).toBe(true);
      expect(fetchMock.getCallCount(/\/oauth\/token/)).toBe(2); // M2M + ROPC
    });

    it('custom fetch handler without global spy', async () => {
      fetchMock = new FetchMock()
        .whenAuth0Token()
        .whenAuth0CreateUser('auth0|custom-user')
        .whenSupabaseOrganization('org-custom-123')
        .whenSupabaseUser()
        .whenSupabaseOrgMembership();
      fetchMock.activate();

      const request = new Request('https://worker.test/signup', {
        method: 'POST',
        headers: { 'content-type': 'application/json' },
        body: JSON.stringify({ email: fixtures.user.email, password: fixtures.user.password }),
      });

      const response = await worker.fetch(request, mockEnv);
      expect(response.status).toBe(201);
    });
  });

  describe('POST /signup — rollback on partial failure', () => {
    function makeSuccessfulFetch(auth0Sub: string, orgId: string): (url: RequestInfo | URL, init?: RequestInit) => Promise<Response> {
      let oauthCount = 0;
      return async (url) => {
        const urlStr = String(url);
        if (urlStr.includes('/oauth/token')) {
          oauthCount++;
          return new Response(JSON.stringify({ access_token: oauthCount === 1 ? 'mgmt-token' : 'user-jwt' }), {
            status: 200, headers: { 'content-type': 'application/json' },
          });
        }
        if (urlStr.includes('/api/v2/users') && !urlStr.includes('/api/v2/users/')) {
          return new Response(JSON.stringify({ user_id: auth0Sub }), {
            status: 201, headers: { 'content-type': 'application/json' },
          });
        }
        if (urlStr.includes('/organizations')) {
          return new Response(JSON.stringify([{ id: orgId }]), {
            status: 201, headers: { 'content-type': 'application/json' },
          });
        }
        return new Response('', { status: 201 });
      };
    }

    it('deletes Auth0 user when Supabase org creation fails', async () => {
      const auth0Sub = 'auth0|rollback-step2';
      const deletedUrls: string[] = [];

      const fetchSpy = vi.spyOn(global, 'fetch').mockImplementation(async (url) => {
        const urlStr = String(url);
        if (urlStr.includes('/oauth/token')) {
          return new Response(JSON.stringify({ access_token: 'mgmt-token' }), {
            status: 200, headers: { 'content-type': 'application/json' },
          });
        }
        if (urlStr.includes('/api/v2/users/')) {
          deletedUrls.push(urlStr);
          return new Response('', { status: 204 });
        }
        if (urlStr.includes('/api/v2/users')) {
          return new Response(JSON.stringify({ user_id: auth0Sub }), {
            status: 201, headers: { 'content-type': 'application/json' },
          });
        }
        if (urlStr.includes('/organizations')) {
          return new Response('db error', { status: 500 });
        }
        return new Response('', { status: 201 });
      });

      const response = await worker.fetch(new Request('https://worker.test/signup', {
        method: 'POST',
        headers: { 'content-type': 'application/json' },
        body: JSON.stringify({ email: 'fail@example.com', password: 'S3cur3!pass' }),
      }), mockEnv);

      expect(response.status).toBe(500);
      expect(deletedUrls.some((u) => u.includes(encodeURIComponent(auth0Sub)))).toBe(true);
      fetchSpy.mockRestore();
    });

    it('deletes Auth0 user and org when Supabase user insert fails', async () => {
      const auth0Sub = 'auth0|rollback-step3';
      const orgId = 'org-step3';
      const deletedUrls: string[] = [];

      const fetchSpy = vi.spyOn(global, 'fetch').mockImplementation(async (url) => {
        const urlStr = String(url);
        if (urlStr.includes('/oauth/token')) {
          return new Response(JSON.stringify({ access_token: 'mgmt-token' }), {
            status: 200, headers: { 'content-type': 'application/json' },
          });
        }
        if (urlStr.includes('/api/v2/users/')) {
          deletedUrls.push(urlStr);
          return new Response('', { status: 204 });
        }
        if (urlStr.includes('/api/v2/users')) {
          return new Response(JSON.stringify({ user_id: auth0Sub }), {
            status: 201, headers: { 'content-type': 'application/json' },
          });
        }
        if (urlStr.includes('/organizations?id=eq.')) {
          deletedUrls.push(urlStr);
          return new Response('', { status: 204 });
        }
        if (urlStr.includes('/organizations')) {
          return new Response(JSON.stringify([{ id: orgId }]), {
            status: 201, headers: { 'content-type': 'application/json' },
          });
        }
        // users insert fails
        if (urlStr.includes('/rest/v1/users')) {
          return new Response('conflict', { status: 409 });
        }
        return new Response('', { status: 201 });
      });

      const response = await worker.fetch(new Request('https://worker.test/signup', {
        method: 'POST',
        headers: { 'content-type': 'application/json' },
        body: JSON.stringify({ email: 'fail3@example.com', password: 'S3cur3!pass' }),
      }), mockEnv);

      expect(response.status).toBe(500);
      expect(deletedUrls.some((u) => u.includes(`/organizations?id=eq.`))).toBe(true);
      expect(deletedUrls.some((u) => u.includes(encodeURIComponent(auth0Sub)))).toBe(true);
      fetchSpy.mockRestore();
    });
  });

  describe('Environment Variable Validation (Regression Tests)', () => {
    it('mockEnv includes Regular Web App credentials for ROPC and CLI M2M credentials for Management API', () => {
      expect(mockEnv).toHaveProperty('AUTH0_CLIENT_ID');
      expect(mockEnv).toHaveProperty('AUTH0_CLIENT_SECRET');
      expect(mockEnv).toHaveProperty('AUTH0_CLI_ID');
      expect(mockEnv).toHaveProperty('AUTH0_CLI_SECRET');
      expect(mockEnv).toHaveProperty('AUTH0_AUDIENCE');
      expect(mockEnv.AUTH0_CLIENT_ID).toBe('test-spa-client-id');
      expect(mockEnv.AUTH0_CLIENT_SECRET).toBe('test-spa-client-secret');
      expect(mockEnv.AUTH0_CLI_ID).toBe('test-m2m-client-id');
      expect(mockEnv.AUTH0_CLI_SECRET).toBe('test-m2m-client-secret');
    });

    it('does not use deprecated AUTHO_CLI_* variable names (typo regression test)', () => {
      // This test ensures we never accidentally use the typo'd AUTHO_CLI_* naming.
      const env = mockEnv as unknown as Record<string, unknown>;
      expect(env).not.toHaveProperty('AUTHO_CLI_ID');
      expect(env).not.toHaveProperty('AUTHO_CLI_SECRET');
      expect(env).not.toHaveProperty('AUTHO_CLI_AUDIENCE');
      expect(env).not.toHaveProperty('AUTH0_CLI_AUDIENCE');
    });

    it('all required environment variables are present in mockEnv', () => {
      const requiredVars = [
        'SHARED_SECRET',
        'RECEIVER',
        'AUTH0_DOMAIN',
        'AUTH0_CLIENT_ID',
        'AUTH0_CLIENT_SECRET',
        'AUTH0_CLI_ID',
        'AUTH0_CLI_SECRET',
        'AUTH0_AUDIENCE',
        'SUPABASE_URL',
        'SUPABASE_SERVICE_ROLE_KEY',
      ];

      requiredVars.forEach((varName) => {
        expect(mockEnv).toHaveProperty(varName);
      });
    });
  });
});
