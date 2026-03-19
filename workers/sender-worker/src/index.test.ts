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
});
