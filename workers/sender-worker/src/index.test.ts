/**
 * Tests for Integrity Studio Sender Worker
 *
 * Tests inter-worker request signing and forwarding to receiver-worker.
 * Run with: npm test
 */

import { describe, it, expect, beforeEach, vi } from 'vitest';


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
  RECEIVER_WORKER_URL: string;
  SUPABASE_URL: string;
  SUPABASE_SERVICE_ROLE_KEY: string;
  AUTH0_DOMAIN: string;
  AUTH0_CLIENT_ID: string;
  AUTH0_CLIENT_SECRET: string;
  AUTH0_AUDIENCE: string;
  ALLOWED_ORIGINS_JSON?: string;
}

import worker from './index';

// Mock environment
const mockEnv: Env = {
  SHARED_SECRET: 'test-shared-secret-key',
  RECEIVER_WORKER_URL: 'https://receiver.test',
  SUPABASE_URL: 'https://supabase.test',
  SUPABASE_SERVICE_ROLE_KEY: 'test-service-role-key',
  AUTH0_DOMAIN: 'test.auth0.com',
  AUTH0_CLIENT_ID: 'test-client-id',
  AUTH0_CLIENT_SECRET: 'test-client-secret',
  AUTH0_AUDIENCE: 'https://api.test',
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

describe('Sender Worker', () => {
  describe('POST /send — valid provision_api_key requests', () => {
    it('forwards provision_api_key payload to receiver-worker with HMAC signature', async () => {
      const fetchSpy = vi.spyOn(global, 'fetch').mockResolvedValueOnce(
        new Response(
          JSON.stringify({ ok: true, received: validSendPayload }),
          { status: 200, headers: { 'content-type': 'application/json; charset=utf-8' } },
        ),
      );

      const request = new Request('https://worker.test/send', {
        method: 'POST',
        headers: { 'content-type': 'application/json' },
        body: JSON.stringify(validSendPayload),
      });

      const response = await worker.fetch(request, mockEnv);

      expect(response.status).toBe(200);
      expect(fetchSpy).toHaveBeenCalled();
      const callArgs = fetchSpy.mock.calls[0];
      expect(callArgs[0]).toBe(`${mockEnv.RECEIVER_WORKER_URL}/inbox`);
      const fetchRequest = callArgs[1] as RequestInit;
      expect(fetchRequest.headers).toHaveProperty('x-timestamp');
      expect(fetchRequest.headers).toHaveProperty('x-signature');

      fetchSpy.mockRestore();
    });

    it('computes signature over the normalized payload using timestamp.body format', async () => {
      let capturedTimestamp = '';
      let capturedSignature = '';
      let capturedBody = '';

      const fetchSpy = vi.spyOn(global, 'fetch').mockImplementation(async (_url, init) => {
        const headers = init?.headers as Record<string, string>;
        capturedTimestamp = headers['x-timestamp'];
        capturedSignature = headers['x-signature'];
        capturedBody = init?.body as string;
        return new Response(JSON.stringify({ ok: true }), {
          status: 200,
          headers: { 'content-type': 'application/json; charset=utf-8' },
        });
      });

      const request = new Request('https://worker.test/send', {
        method: 'POST',
        headers: { 'content-type': 'application/json' },
        body: JSON.stringify(validSendPayload),
      });

      await worker.fetch(request, mockEnv);

      const expectedSig = await computeSignature(capturedBody, mockEnv.SHARED_SECRET, capturedTimestamp);
      expect(capturedSignature).toBe(expectedSig);

      fetchSpy.mockRestore();
    });

    it('defaults tier to starter when absent', async () => {
      let forwardedPayload: Record<string, unknown> | null = null;

      const fetchSpy = vi.spyOn(global, 'fetch').mockImplementation(async (_url, init) => {
        forwardedPayload = JSON.parse(init?.body as string) as Record<string, unknown>;
        return new Response(JSON.stringify({ ok: true }), {
          status: 200,
          headers: { 'content-type': 'application/json; charset=utf-8' },
        });
      });

      const { tier: _tier, ...withoutTier } = validSendPayload;
      const request = new Request('https://worker.test/send', {
        method: 'POST',
        headers: { 'content-type': 'application/json' },
        body: JSON.stringify(withoutTier),
      });

      await worker.fetch(request, mockEnv);

      expect(forwardedPayload!['tier']).toBe('starter');
      fetchSpy.mockRestore();
    });

    it('defaults tier to starter when value is invalid', async () => {
      let forwardedPayload: Record<string, unknown> | null = null;

      const fetchSpy = vi.spyOn(global, 'fetch').mockImplementation(async (_url, init) => {
        forwardedPayload = JSON.parse(init?.body as string) as Record<string, unknown>;
        return new Response(JSON.stringify({ ok: true }), {
          status: 200,
          headers: { 'content-type': 'application/json; charset=utf-8' },
        });
      });

      const request = new Request('https://worker.test/send', {
        method: 'POST',
        headers: { 'content-type': 'application/json' },
        body: JSON.stringify({ ...validSendPayload, tier: 'invalid-tier' }),
      });

      await worker.fetch(request, mockEnv);

      expect(forwardedPayload!['tier']).toBe('starter');
      fetchSpy.mockRestore();
    });

    it('preserves valid growth tier', async () => {
      let forwardedPayload: Record<string, unknown> | null = null;

      const fetchSpy = vi.spyOn(global, 'fetch').mockImplementation(async (_url, init) => {
        forwardedPayload = JSON.parse(init?.body as string) as Record<string, unknown>;
        return new Response(JSON.stringify({ ok: true }), {
          status: 200,
          headers: { 'content-type': 'application/json; charset=utf-8' },
        });
      });

      const request = new Request('https://worker.test/send', {
        method: 'POST',
        headers: { 'content-type': 'application/json' },
        body: JSON.stringify({ ...validSendPayload, tier: 'growth' }),
      });

      await worker.fetch(request, mockEnv);

      expect(forwardedPayload!['tier']).toBe('growth');
      fetchSpy.mockRestore();
    });

    it('includes org_name in forwarded payload when provided', async () => {
      let forwardedPayload: Record<string, unknown> | null = null;

      const fetchSpy = vi.spyOn(global, 'fetch').mockImplementation(async (_url, init) => {
        forwardedPayload = JSON.parse(init?.body as string) as Record<string, unknown>;
        return new Response(JSON.stringify({ ok: true }), {
          status: 200,
          headers: { 'content-type': 'application/json; charset=utf-8' },
        });
      });

      const request = new Request('https://worker.test/send', {
        method: 'POST',
        headers: { 'content-type': 'application/json' },
        body: JSON.stringify({ ...validSendPayload, org_name: 'Acme Corp' }),
      });

      await worker.fetch(request, mockEnv);

      expect(forwardedPayload!['org_name']).toBe('Acme Corp');
      fetchSpy.mockRestore();
    });

    it('defaults org_name to email domain when not provided', async () => {
      let forwardedPayload: Record<string, unknown> | null = null;

      const fetchSpy = vi.spyOn(global, 'fetch').mockImplementation(async (_url, init) => {
        forwardedPayload = JSON.parse(init?.body as string) as Record<string, unknown>;
        return new Response(JSON.stringify({ ok: true }), {
          status: 200,
          headers: { 'content-type': 'application/json; charset=utf-8' },
        });
      });

      const request = new Request('https://worker.test/send', {
        method: 'POST',
        headers: { 'content-type': 'application/json' },
        body: JSON.stringify(validSendPayload),
      });

      await worker.fetch(request, mockEnv);

      expect(forwardedPayload!['org_name']).toBe('example.com');
      fetchSpy.mockRestore();
    });

    it('passes through receiver-worker error responses unchanged', async () => {
      const fetchSpy = vi.spyOn(global, 'fetch').mockResolvedValueOnce(
        new Response(
          JSON.stringify({ error: 'invalid signature' }),
          { status: 401, headers: { 'content-type': 'application/json; charset=utf-8' } },
        ),
      );

      const request = new Request('https://worker.test/send', {
        method: 'POST',
        headers: { 'content-type': 'application/json' },
        body: JSON.stringify(validSendPayload),
      });

      const response = await worker.fetch(request, mockEnv);

      expect(response.status).toBe(401);
      const data = await response.json() as ErrorResponse;
      expect(data.error).toBe('invalid signature');
      fetchSpy.mockRestore();
    });
  });

  describe('POST /send — payload validation', () => {
    it('returns 400 when action is missing (treated as unknown action)', async () => {
      const { action: _a, ...noAction } = validSendPayload;
      const request = new Request('https://worker.test/send', {
        method: 'POST',
        headers: { 'content-type': 'application/json' },
        body: JSON.stringify(noAction),
      });
      const response = await worker.fetch(request, mockEnv);
      expect(response.status).toBe(400);
      expect((await response.json() as ErrorResponse).error).toContain('unknown action');
    });

    it('returns 400 for unknown action', async () => {
      const request = new Request('https://worker.test/send', {
        method: 'POST',
        headers: { 'content-type': 'application/json' },
        body: JSON.stringify({ ...validSendPayload, action: 'unknown_action' }),
      });
      const response = await worker.fetch(request, mockEnv);
      expect(response.status).toBe(400);
      expect((await response.json() as ErrorResponse).error).toContain('unknown action');
    });

    it('returns 401 when jwt is missing', async () => {
      const { jwt: _j, ...noJwt } = validSendPayload;
      const request = new Request('https://worker.test/send', {
        method: 'POST',
        headers: { 'content-type': 'application/json' },
        body: JSON.stringify(noJwt),
      });
      const response = await worker.fetch(request, mockEnv);
      expect(response.status).toBe(401);
      expect((await response.json() as ErrorResponse).error).toContain('jwt');
    });

    it('returns 400 when name is missing', async () => {
      const { name: _n, ...noName } = validSendPayload;
      const request = new Request('https://worker.test/send', {
        method: 'POST',
        headers: { 'content-type': 'application/json' },
        body: JSON.stringify(noName),
      });
      const response = await worker.fetch(request, mockEnv);
      expect(response.status).toBe(400);
      expect((await response.json() as ErrorResponse).error).toContain('name');
    });

    it('returns 400 when email is missing', async () => {
      const { email: _e, ...noEmail } = validSendPayload;
      const request = new Request('https://worker.test/send', {
        method: 'POST',
        headers: { 'content-type': 'application/json' },
        body: JSON.stringify(noEmail),
      });
      const response = await worker.fetch(request, mockEnv);
      expect(response.status).toBe(400);
      expect((await response.json() as ErrorResponse).error).toContain('email');
    });

    it('returns 400 for invalid email format', async () => {
      const request = new Request('https://worker.test/send', {
        method: 'POST',
        headers: { 'content-type': 'application/json' },
        body: JSON.stringify({ ...validSendPayload, email: 'not-an-email' }),
      });
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
    it.each([
      ['empty string', ''],
      ['invalid URL', 'not-a-url'],
    ])('returns 500 when RECEIVER_WORKER_URL is %s', async (_label, url) => {
      const envMissingReceiver: Env = { ...mockEnv, RECEIVER_WORKER_URL: url };
      const request = new Request('https://worker.test/send', {
        method: 'POST',
        headers: { 'content-type': 'application/json' },
        body: JSON.stringify(validSendPayload),
      });
      const response = await worker.fetch(request, envMissingReceiver);
      expect(response.status).toBe(500);
      expect((await response.json() as ErrorResponse).error).toContain('not configured');
    });

    it('returns 500 when SHARED_SECRET is not configured', async () => {
      const envMissingSecret: Env = { SHARED_SECRET: '', RECEIVER_WORKER_URL: 'https://receiver.test' };
      const request = new Request('https://worker.test/send', {
        method: 'POST',
        headers: { 'content-type': 'application/json' },
        body: JSON.stringify(validSendPayload),
      });
      const response = await worker.fetch(request, envMissingSecret);
      expect(response.status).toBe(500);
      expect((await response.json() as ErrorResponse).error).toContain('not configured');
    });
  });

  describe('POST /send — network errors', () => {
    it('returns 502 when receiver-worker is unreachable', async () => {
      const fetchSpy = vi.spyOn(global, 'fetch').mockRejectedValueOnce(new TypeError('Failed to fetch'));
      const request = new Request('https://worker.test/send', {
        method: 'POST',
        headers: { 'content-type': 'application/json' },
        body: JSON.stringify(validSendPayload),
      });
      const response = await worker.fetch(request, mockEnv);
      expect(response.status).toBe(502);
      expect((await response.json() as ErrorResponse).error).toBe('receiver-worker unreachable');
      fetchSpy.mockRestore();
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
    it('includes CORS headers on POST response from allowed origin', async () => {
      const fetchSpy = vi.spyOn(global, 'fetch').mockResolvedValueOnce(
        new Response(
          JSON.stringify({ ok: true }),
          { status: 200, headers: { 'content-type': 'application/json; charset=utf-8' } },
        ),
      );

      const request = new Request('https://worker.test/send', {
        method: 'POST',
        headers: {
          'content-type': 'application/json',
          Origin: 'https://www.integritystudio.ai',
        },
        body: JSON.stringify(validSendPayload),
      });

      const response = await worker.fetch(request, mockEnv);

      expect(response.status).toBe(200);
      expect(response.headers.get('Access-Control-Allow-Origin')).toBe('https://www.integritystudio.ai');

      fetchSpy.mockRestore();
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
  });

  describe('POST /signin — not implemented (Auth0 handles auth)', () => {
    it('returns 404 for /signin route', async () => {
      const request = new Request('https://worker.test/signin', {
        method: 'POST',
        headers: { 'content-type': 'application/json' },
        body: JSON.stringify({ email: 'user@example.com', password: 'pass' }),
      });

      const response = await worker.fetch(request, mockEnv);

      expect(response.status).toBe(404);
      const data = await response.json() as { error: string };
      expect(data.error).toContain('Auth0');
    });
  });

  describe('CORS — Environment-based origin configuration', () => {
    it('allows development origin when ALLOWED_ORIGINS_JSON is configured', async () => {
      const envWithDevOrigin: Env = {
        ...mockEnv,
        ALLOWED_ORIGINS_JSON: JSON.stringify(['http://localhost:8081', 'https://integritystudio.ai']),
      };
      const fetchSpy = vi.spyOn(global, 'fetch').mockResolvedValueOnce(
        new Response(JSON.stringify({ ok: true }), { status: 200, headers: { 'content-type': 'application/json; charset=utf-8' } }),
      );
      const request = new Request('https://worker.test/send', {
        method: 'POST',
        headers: { 'content-type': 'application/json', Origin: 'http://localhost:8081' },
        body: JSON.stringify(validSendPayload),
      });
      const response = await worker.fetch(request, envWithDevOrigin);
      expect(response.status).toBe(200);
      expect(response.headers.get('Access-Control-Allow-Origin')).toBe('http://localhost:8081');
      fetchSpy.mockRestore();
    });

    it('allows staging origin when configured', async () => {
      const envWithStaging: Env = {
        ...mockEnv,
        ALLOWED_ORIGINS_JSON: JSON.stringify(['https://staging.integritystudio.ai', 'https://www.integritystudio.ai']),
      };
      const fetchSpy = vi.spyOn(global, 'fetch').mockResolvedValueOnce(
        new Response(JSON.stringify({ ok: true }), { status: 200, headers: { 'content-type': 'application/json; charset=utf-8' } }),
      );
      const request = new Request('https://worker.test/send', {
        method: 'POST',
        headers: { 'content-type': 'application/json', Origin: 'https://staging.integritystudio.ai' },
        body: JSON.stringify(validSendPayload),
      });
      const response = await worker.fetch(request, envWithStaging);
      expect(response.status).toBe(200);
      expect(response.headers.get('Access-Control-Allow-Origin')).toBe('https://staging.integritystudio.ai');
      fetchSpy.mockRestore();
    });

    it('rejects unregistered origins even with ALLOWED_ORIGINS_JSON configured', async () => {
      const envWithDevOrigin: Env = {
        ...mockEnv,
        ALLOWED_ORIGINS_JSON: JSON.stringify(['http://localhost:8081']),
      };
      const request = new Request('https://worker.test/send', {
        method: 'POST',
        headers: { 'content-type': 'application/json', Origin: 'https://evil.example.com' },
        body: JSON.stringify(validSendPayload),
      });
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
      const fetchSpy = vi.spyOn(global, 'fetch').mockResolvedValueOnce(
        new Response(JSON.stringify({ ok: true }), { status: 200, headers: { 'content-type': 'application/json; charset=utf-8' } }),
      );
      const request = new Request('https://worker.test/send', {
        method: 'POST',
        headers: { 'content-type': 'application/json', Origin: customOrigin },
        body: JSON.stringify(validSendPayload),
      });
      const response = await worker.fetch(request, envWithCustomOrigins);
      expect(response.status).toBe(200);
      expect(response.headers.get('Access-Control-Allow-Origin')).toBe(customOrigin);
      fetchSpy.mockRestore();
    });

    it('falls back to hardcoded defaults when ALLOWED_ORIGINS_JSON is not set', async () => {
      const fetchSpy = vi.spyOn(global, 'fetch').mockResolvedValueOnce(
        new Response(JSON.stringify({ ok: true }), { status: 200, headers: { 'content-type': 'application/json; charset=utf-8' } }),
      );
      const request = new Request('https://worker.test/send', {
        method: 'POST',
        headers: { 'content-type': 'application/json', Origin: 'https://integritystudio.ai' },
        body: JSON.stringify(validSendPayload),
      });
      const response = await worker.fetch(request, mockEnv);
      expect(response.status).toBe(200);
      expect(response.headers.get('Access-Control-Allow-Origin')).toBe('https://integritystudio.ai');
      fetchSpy.mockRestore();
    });
  });
});
