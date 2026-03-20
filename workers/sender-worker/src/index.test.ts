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
  ALLOWED_ORIGINS_JSON?: string;
}

import worker from './index';

// Mock environment
const mockEnv: Env = {
  SHARED_SECRET: 'test-shared-secret-key',
  RECEIVER_WORKER_URL: 'https://receiver.test',
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

describe('Sender Worker', () => {
  describe('POST /send — valid requests', () => {
    it('forwards valid JSON to receiver-worker with HMAC signature', async () => {
      const body = JSON.stringify({ userId: 'user123', action: 'signup' });

      // Mock fetch to intercept the forwarded request
      const fetchSpy = vi.spyOn(global, 'fetch').mockResolvedValueOnce(
        new Response(
          JSON.stringify({ ok: true, received: JSON.parse(body) }),
          { status: 200, headers: { 'content-type': 'application/json; charset=utf-8' } },
        ),
      );

      const request = new Request('https://worker.test/send', {
        method: 'POST',
        headers: { 'content-type': 'application/json' },
        body,
      });

      const response = await worker.fetch(request, mockEnv);

      expect(response.status).toBe(200);
      const data = await response.json() as SuccessResponse;
      expect(data.ok).toBe(true);
      expect(data.received).toEqual({ userId: 'user123', action: 'signup' });

      // Verify fetch was called with receiver URL
      expect(fetchSpy).toHaveBeenCalled();
      const callArgs = fetchSpy.mock.calls[0];
      expect(callArgs[0]).toBe(`${mockEnv.RECEIVER_WORKER_URL}/inbox`);

      // Verify request includes x-timestamp and x-signature headers
      const fetchRequest = callArgs[1] as RequestInit;
      expect(fetchRequest.headers).toHaveProperty('x-timestamp');
      expect(fetchRequest.headers).toHaveProperty('x-signature');
      expect(fetchRequest.body).toBe(body);

      fetchSpy.mockRestore();
    });

    it('computes signature using timestamp.body format', async () => {
      const body = JSON.stringify({ test: 'data' });
      let capturedRequest: { timestamp: string; signature: string; body: string } | null = null;

      const fetchSpy = vi.spyOn(global, 'fetch').mockImplementation(async (url, init) => {
        const headers = init?.headers as Record<string, string>;
        capturedRequest = {
          timestamp: headers['x-timestamp'],
          signature: headers['x-signature'],
          body: init?.body as string,
        };
        return new Response(
          JSON.stringify({ ok: true, received: JSON.parse(body) }),
          { status: 200, headers: { 'content-type': 'application/json; charset=utf-8' } },
        );
      });

      const request = new Request('https://worker.test/send', {
        method: 'POST',
        body,
      });

      await worker.fetch(request, mockEnv);

      expect(capturedRequest).not.toBeNull();
      const { timestamp, signature } = capturedRequest!;

      // Compute expected signature independently
      const expectedSignature = await computeSignature(body, mockEnv.SHARED_SECRET, timestamp);
      expect(signature).toBe(expectedSignature);

      fetchSpy.mockRestore();
    });

    it('returns receiver-worker response status and body', async () => {
      const body = JSON.stringify({ event: 'test' });

      const fetchSpy = vi.spyOn(global, 'fetch').mockResolvedValueOnce(
        new Response(
          JSON.stringify({ ok: true, received: { event: 'test' } }),
          { status: 200, headers: { 'content-type': 'application/json; charset=utf-8' } },
        ),
      );

      const request = new Request('https://worker.test/send', {
        method: 'POST',
        body,
      });

      const response = await worker.fetch(request, mockEnv);

      expect(response.status).toBe(200);
      expect(response.headers.get('content-type')).toBe('application/json; charset=utf-8');

      fetchSpy.mockRestore();
    });

    it('passes through receiver-worker errors unchanged', async () => {
      const body = JSON.stringify({ data: 'test' });

      const fetchSpy = vi.spyOn(global, 'fetch').mockResolvedValueOnce(
        new Response(
          JSON.stringify({ error: 'invalid signature' }),
          { status: 401, headers: { 'content-type': 'application/json; charset=utf-8' } },
        ),
      );

      const request = new Request('https://worker.test/send', {
        method: 'POST',
        body,
      });

      const response = await worker.fetch(request, mockEnv);

      expect(response.status).toBe(401);
      const data = await response.json() as ErrorResponse;
      expect(data.error).toBe('invalid signature');

      fetchSpy.mockRestore();
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
    it('returns 500 when RECEIVER_WORKER_URL is not configured', async () => {
      const body = JSON.stringify({ data: 'test' });
      const envMissingReceiver: Env = {
        SHARED_SECRET: 'secret',
        RECEIVER_WORKER_URL: '',
      };

      const request = new Request('https://worker.test/send', {
        method: 'POST',
        body,
      });

      const response = await worker.fetch(request, envMissingReceiver);

      expect(response.status).toBe(500);
      const data = await response.json() as ErrorResponse;
      expect(data.error).toContain('not configured');
    });

    it('returns 500 when SHARED_SECRET is not configured', async () => {
      const body = JSON.stringify({ data: 'test' });
      const envMissingSecret: Env = {
        SHARED_SECRET: '',
        RECEIVER_WORKER_URL: 'https://receiver.test',
      };

      const request = new Request('https://worker.test/send', {
        method: 'POST',
        body,
      });

      const response = await worker.fetch(request, envMissingSecret);

      expect(response.status).toBe(500);
      const data = await response.json() as ErrorResponse;
      expect(data.error).toContain('not configured');
    });
  });

  describe('POST /send — network errors', () => {
    it('returns 502 when receiver-worker is unreachable', async () => {
      const body = JSON.stringify({ data: 'test' });

      const fetchSpy = vi.spyOn(global, 'fetch').mockRejectedValueOnce(
        new TypeError('Failed to fetch'),
      );

      const request = new Request('https://worker.test/send', {
        method: 'POST',
        body,
      });

      const response = await worker.fetch(request, mockEnv);

      expect(response.status).toBe(502);
      const data = await response.json() as ErrorResponse;
      expect(data.error).toBe('receiver-worker unreachable');

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
      const body = JSON.stringify({ userId: 'user123' });

      const fetchSpy = vi.spyOn(global, 'fetch').mockResolvedValueOnce(
        new Response(
          JSON.stringify({ ok: true, received: JSON.parse(body) }),
          { status: 200, headers: { 'content-type': 'application/json; charset=utf-8' } },
        ),
      );

      const request = new Request('https://worker.test/send', {
        method: 'POST',
        headers: {
          'content-type': 'application/json',
          Origin: 'https://www.integritystudio.ai',
        },
        body,
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

  describe('CORS — Environment-based origin configuration', () => {
    it('allows development origin when ALLOWED_ORIGINS_JSON is configured', async () => {
      const body = JSON.stringify({ userId: 'user123' });
      const envWithDevOrigin: Env = {
        ...mockEnv,
        ALLOWED_ORIGINS_JSON: JSON.stringify(['http://localhost:8081', 'https://integritystudio.ai']),
      };

      const fetchSpy = vi.spyOn(global, 'fetch').mockResolvedValueOnce(
        new Response(
          JSON.stringify({ ok: true, received: JSON.parse(body) }),
          { status: 200, headers: { 'content-type': 'application/json; charset=utf-8' } },
        ),
      );

      const request = new Request('https://worker.test/send', {
        method: 'POST',
        headers: {
          'content-type': 'application/json',
          Origin: 'http://localhost:8081',
        },
        body,
      });

      const response = await worker.fetch(request, envWithDevOrigin);

      expect(response.status).toBe(200);
      expect(response.headers.get('Access-Control-Allow-Origin')).toBe('http://localhost:8081');

      fetchSpy.mockRestore();
    });

    it('allows staging origin when configured', async () => {
      const body = JSON.stringify({ userId: 'user456' });
      const envWithStaging: Env = {
        ...mockEnv,
        ALLOWED_ORIGINS_JSON: JSON.stringify(['https://staging.integritystudio.ai', 'https://www.integritystudio.ai']),
      };

      const fetchSpy = vi.spyOn(global, 'fetch').mockResolvedValueOnce(
        new Response(
          JSON.stringify({ ok: true, received: JSON.parse(body) }),
          { status: 200, headers: { 'content-type': 'application/json; charset=utf-8' } },
        ),
      );

      const request = new Request('https://worker.test/send', {
        method: 'POST',
        headers: {
          'content-type': 'application/json',
          Origin: 'https://staging.integritystudio.ai',
        },
        body,
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
        headers: {
          'content-type': 'application/json',
          Origin: 'https://evil.example.com',
        },
        body: JSON.stringify({ data: 'test' }),
      });

      const response = await worker.fetch(request, envWithDevOrigin);

      expect(response.status).toBe(403);
      const data = await response.json() as ErrorResponse;
      expect(data.error).toBe('forbidden');
    });

    it('uses ALLOWED_ORIGINS_JSON when provided, ignoring hardcoded defaults', async () => {
      const body = JSON.stringify({ userId: 'user789' });
      const customOrigin = 'https://custom.example.com';
      const envWithCustomOrigins: Env = {
        ...mockEnv,
        ALLOWED_ORIGINS_JSON: JSON.stringify([customOrigin]),
      };

      const fetchSpy = vi.spyOn(global, 'fetch').mockResolvedValueOnce(
        new Response(
          JSON.stringify({ ok: true, received: JSON.parse(body) }),
          { status: 200, headers: { 'content-type': 'application/json; charset=utf-8' } },
        ),
      );

      const request = new Request('https://worker.test/send', {
        method: 'POST',
        headers: {
          'content-type': 'application/json',
          Origin: customOrigin,
        },
        body,
      });

      const response = await worker.fetch(request, envWithCustomOrigins);

      expect(response.status).toBe(200);
      expect(response.headers.get('Access-Control-Allow-Origin')).toBe(customOrigin);

      fetchSpy.mockRestore();
    });

    it('falls back to hardcoded defaults when ALLOWED_ORIGINS_JSON is not set', async () => {
      const body = JSON.stringify({ userId: 'user000' });

      const fetchSpy = vi.spyOn(global, 'fetch').mockResolvedValueOnce(
        new Response(
          JSON.stringify({ ok: true, received: JSON.parse(body) }),
          { status: 200, headers: { 'content-type': 'application/json; charset=utf-8' } },
        ),
      );

      const request = new Request('https://worker.test/send', {
        method: 'POST',
        headers: {
          'content-type': 'application/json',
          Origin: 'https://integritystudio.ai',
        },
        body,
      });

      const response = await worker.fetch(request, mockEnv);

      expect(response.status).toBe(200);
      expect(response.headers.get('Access-Control-Allow-Origin')).toBe('https://integritystudio.ai');

      fetchSpy.mockRestore();
    });
  });
});
