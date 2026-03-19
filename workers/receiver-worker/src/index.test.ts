/**
 * Tests for Integrity Studio Receiver Worker
 *
 * Tests HMAC-signed inter-service request handling and health endpoint.
 * Run with: npm test
 */

import { describe, it, expect } from 'vitest';

// API response types
interface HealthResponse {
  ok: boolean;
  service: string;
}

interface InboxSuccessResponse {
  ok: boolean;
  received: Record<string, unknown>;
}

interface ErrorResponse {
  error: string;
}

type ApiResponse = HealthResponse | InboxSuccessResponse | ErrorResponse;

interface Env {
  SHARED_SECRET: string;
}

import worker from './index';

// Mock environment
const mockEnv: Env = {
  SHARED_SECRET: 'test-shared-secret-key',
};

// Helper to create a valid HMAC-SHA256 signature for a request body
async function signRequest(
  body: string,
  secret: string,
  timestamp?: number,
): Promise<{ timestamp: string; signature: string }> {
  const ts = (timestamp ?? Date.now()).toString();
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
    encoder.encode(`${ts}.${body}`),
  );
  const hex = [...new Uint8Array(sig)].map(b => b.toString(16).padStart(2, '0')).join('');
  return { timestamp: ts, signature: hex };
}

describe('Receiver Worker', () => {
  describe('GET /health', () => {
    it('returns 200 with ok and service name', async () => {
      const request = new Request('https://worker.test/health', { method: 'GET' });
      const response = await worker.fetch(request, mockEnv);

      expect(response.status).toBe(200);
      const data = await response.json() as HealthResponse;
      expect(data.ok).toBe(true);
      expect(data.service).toBe('receiver-worker');
    });

    it('sets content-type to application/json; charset=utf-8', async () => {
      const request = new Request('https://worker.test/health', { method: 'GET' });
      const response = await worker.fetch(request, mockEnv);

      expect(response.headers.get('content-type')).toBe('application/json; charset=utf-8');
    });

    it('requires no authentication', async () => {
      // No auth headers — should still succeed
      const request = new Request('https://worker.test/health', { method: 'GET' });
      const response = await worker.fetch(request, mockEnv);

      expect(response.status).toBe(200);
    });
  });

  describe('POST /inbox — valid requests', () => {
    it('returns 200 with ok and parsed body when signature is valid', async () => {
      const body = JSON.stringify({ event: 'test', value: 42 });
      const { timestamp, signature } = await signRequest(body, mockEnv.SHARED_SECRET);

      const request = new Request('https://worker.test/inbox', {
        method: 'POST',
        headers: {
          'content-type': 'application/json',
          'x-timestamp': timestamp,
          'x-signature': signature,
        },
        body,
      });

      const response = await worker.fetch(request, mockEnv);

      expect(response.status).toBe(200);
      const data = await response.json() as InboxSuccessResponse;
      expect(data.ok).toBe(true);
      expect(data.received).toEqual({ event: 'test', value: 42 });
    });

    it('sets content-type to application/json; charset=utf-8 on success', async () => {
      const body = JSON.stringify({ ping: true });
      const { timestamp, signature } = await signRequest(body, mockEnv.SHARED_SECRET);

      const request = new Request('https://worker.test/inbox', {
        method: 'POST',
        headers: {
          'content-type': 'application/json',
          'x-timestamp': timestamp,
          'x-signature': signature,
        },
        body,
      });

      const response = await worker.fetch(request, mockEnv);

      expect(response.headers.get('content-type')).toBe('application/json; charset=utf-8');
    });
  });

  describe('POST /inbox — missing auth headers', () => {
    it('returns 401 with missing auth headers error when x-timestamp is absent', async () => {
      const body = JSON.stringify({ event: 'test' });
      const { signature } = await signRequest(body, mockEnv.SHARED_SECRET);

      const request = new Request('https://worker.test/inbox', {
        method: 'POST',
        headers: {
          'content-type': 'application/json',
          'x-signature': signature,
          // x-timestamp intentionally omitted
        },
        body,
      });

      const response = await worker.fetch(request, mockEnv);

      expect(response.status).toBe(401);
      const data = await response.json() as ErrorResponse;
      expect(data.error).toBe('missing auth headers');
    });

    it('returns 401 with missing auth headers error when x-signature is absent', async () => {
      const body = JSON.stringify({ event: 'test' });
      const { timestamp } = await signRequest(body, mockEnv.SHARED_SECRET);

      const request = new Request('https://worker.test/inbox', {
        method: 'POST',
        headers: {
          'content-type': 'application/json',
          'x-timestamp': timestamp,
          // x-signature intentionally omitted
        },
        body,
      });

      const response = await worker.fetch(request, mockEnv);

      expect(response.status).toBe(401);
      const data = await response.json() as ErrorResponse;
      expect(data.error).toBe('missing auth headers');
    });

    it('sets content-type to application/json; charset=utf-8 on 401 error', async () => {
      const request = new Request('https://worker.test/inbox', {
        method: 'POST',
        headers: { 'content-type': 'application/json' },
        body: JSON.stringify({ event: 'test' }),
      });

      const response = await worker.fetch(request, mockEnv);

      expect(response.status).toBe(401);
      expect(response.headers.get('content-type')).toBe('application/json; charset=utf-8');
    });
  });

  describe('POST /inbox — stale timestamp', () => {
    it('returns 401 with stale or invalid timestamp when timestamp is more than 5 minutes old', async () => {
      const staleTimestamp = Date.now() - 6 * 60 * 1000; // 6 minutes ago
      const body = JSON.stringify({ event: 'test' });
      const { timestamp, signature } = await signRequest(body, mockEnv.SHARED_SECRET, staleTimestamp);

      const request = new Request('https://worker.test/inbox', {
        method: 'POST',
        headers: {
          'content-type': 'application/json',
          'x-timestamp': timestamp,
          'x-signature': signature,
        },
        body,
      });

      const response = await worker.fetch(request, mockEnv);

      expect(response.status).toBe(401);
      const data = await response.json() as ErrorResponse;
      expect(data.error).toBe('stale or invalid timestamp');
    });

    it('returns 401 with stale or invalid timestamp when timestamp is more than 5 minutes in the future', async () => {
      const futureTimestamp = Date.now() + 6 * 60 * 1000; // 6 minutes ahead
      const body = JSON.stringify({ event: 'test' });
      const { timestamp, signature } = await signRequest(body, mockEnv.SHARED_SECRET, futureTimestamp);

      const request = new Request('https://worker.test/inbox', {
        method: 'POST',
        headers: {
          'content-type': 'application/json',
          'x-timestamp': timestamp,
          'x-signature': signature,
        },
        body,
      });

      const response = await worker.fetch(request, mockEnv);

      expect(response.status).toBe(401);
      const data = await response.json() as ErrorResponse;
      expect(data.error).toBe('stale or invalid timestamp');
    });

    it('returns 401 with stale or invalid timestamp when x-timestamp is non-numeric', async () => {
      const body = JSON.stringify({ event: 'test' });
      // Compute a signature using the non-numeric string as the timestamp
      const encoder = new TextEncoder();
      const key = await crypto.subtle.importKey(
        'raw',
        encoder.encode(mockEnv.SHARED_SECRET),
        { name: 'HMAC', hash: 'SHA-256' },
        false,
        ['sign'],
      );
      const sig = await crypto.subtle.sign('HMAC', key, encoder.encode(`not-a-number.${body}`));
      const hex = [...new Uint8Array(sig)].map(b => b.toString(16).padStart(2, '0')).join('');

      const request = new Request('https://worker.test/inbox', {
        method: 'POST',
        headers: {
          'content-type': 'application/json',
          'x-timestamp': 'not-a-number',
          'x-signature': hex,
        },
        body,
      });

      const response = await worker.fetch(request, mockEnv);

      expect(response.status).toBe(401);
      const data = await response.json() as ErrorResponse;
      expect(data.error).toBe('stale or invalid timestamp');
    });
  });

  describe('POST /inbox — invalid signature', () => {
    it('returns 401 with invalid signature error when signature does not match', async () => {
      const body = JSON.stringify({ event: 'test' });
      const { timestamp } = await signRequest(body, mockEnv.SHARED_SECRET);

      const request = new Request('https://worker.test/inbox', {
        method: 'POST',
        headers: {
          'content-type': 'application/json',
          'x-timestamp': timestamp,
          'x-signature': 'a'.repeat(64), // wrong signature
        },
        body,
      });

      const response = await worker.fetch(request, mockEnv);

      expect(response.status).toBe(401);
      const data = await response.json() as ErrorResponse;
      expect(data.error).toBe('invalid signature');
    });
  });

  describe('POST /inbox — invalid JSON body', () => {
    it('returns 400 with invalid json error when body is not valid JSON', async () => {
      const body = 'not valid json {';
      const { timestamp, signature } = await signRequest(body, mockEnv.SHARED_SECRET);

      const request = new Request('https://worker.test/inbox', {
        method: 'POST',
        headers: {
          'content-type': 'application/json',
          'x-timestamp': timestamp,
          'x-signature': signature,
        },
        body,
      });

      const response = await worker.fetch(request, mockEnv);

      expect(response.status).toBe(400);
      const data = await response.json() as ErrorResponse;
      expect(data.error).toBe('invalid json');
    });

    it('sets content-type to application/json; charset=utf-8 on 400 error', async () => {
      const body = 'not valid json {';
      const { timestamp, signature } = await signRequest(body, mockEnv.SHARED_SECRET);

      const request = new Request('https://worker.test/inbox', {
        method: 'POST',
        headers: {
          'content-type': 'application/json',
          'x-timestamp': timestamp,
          'x-signature': signature,
        },
        body,
      });

      const response = await worker.fetch(request, mockEnv);

      expect(response.headers.get('content-type')).toBe('application/json; charset=utf-8');
    });
  });

  describe('Unknown routes', () => {
    it('returns 404 with not found error for unknown GET route', async () => {
      const request = new Request('https://worker.test/unknown', { method: 'GET' });
      const response = await worker.fetch(request, mockEnv);

      expect(response.status).toBe(404);
      const data = await response.json() as ErrorResponse;
      expect(data.error).toBe('not found');
    });

    it('sets content-type to application/json; charset=utf-8 on 404 error', async () => {
      const request = new Request('https://worker.test/unknown', { method: 'GET' });
      const response = await worker.fetch(request, mockEnv);

      expect(response.headers.get('content-type')).toBe('application/json; charset=utf-8');
    });
  });
});
