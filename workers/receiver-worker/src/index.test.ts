/**
 * Tests for Integrity Studio Receiver Worker
 *
 * Tests HMAC-signed inter-service request handling and health endpoint.
 * Run with: npm test
 */

import { describe, it, expect, vi, afterEach } from 'vitest';
import { REPLAY_WINDOW_MS } from '../../constants';
import { hmacSignHex } from '../../lib/crypto';
import worker, { resolveSigningKey } from './index';
import type { Env, HealthResponse, InboxSuccessResponse, ErrorResponse } from './index';

type ApiResponse = HealthResponse | InboxSuccessResponse | ErrorResponse;

// Mock environment
const testEnv: Env = {
  SHARED_SECRET: 'test-shared-secret-key',
};

// Helper to create a valid HMAC-SHA256 signature for a request body
async function signRequest(
  body: string,
  secret: string,
  timestamp?: number,
): Promise<{ timestamp: string; signature: string }> {
  const ts = (timestamp ?? Date.now()).toString();
  const signature = await hmacSignHex(secret, `${ts}.${body}`);
  return { timestamp: ts, signature };
}

describe('Receiver Worker', () => {
  describe('GET /health', () => {
    it('returns 200 with ok and service name', async () => {
      const request = new Request('https://worker.test/health', { method: 'GET' });
      const response = await worker.fetch(request, testEnv);

      expect(response.status).toBe(200);
      const data = await response.json() as HealthResponse;
      expect(data.ok).toBe(true);
      expect(data.service).toBe('receiver-worker');
    });

    it('sets content-type to application/json; charset=utf-8', async () => {
      const request = new Request('https://worker.test/health', { method: 'GET' });
      const response = await worker.fetch(request, testEnv);

      expect(response.headers.get('content-type')).toBe('application/json; charset=utf-8');
    });

    it('requires no authentication', async () => {
      // No auth headers — should still succeed
      const request = new Request('https://worker.test/health', { method: 'GET' });
      const response = await worker.fetch(request, testEnv);

      expect(response.status).toBe(200);
    });
  });

  describe('POST /inbox — valid requests', () => {
    it('returns 200 with ok and parsed body when signature is valid', async () => {
      const body = JSON.stringify({ event: 'test', value: 42 });
      const { timestamp, signature } = await signRequest(body, testEnv.SHARED_SECRET);

      const request = new Request('https://worker.test/inbox', {
        method: 'POST',
        headers: {
          'content-type': 'application/json',
          'x-timestamp': timestamp,
          'x-signature': signature,
        },
        body,
      });

      const response = await worker.fetch(request, testEnv);

      expect(response.status).toBe(200);
      const data = await response.json() as InboxSuccessResponse;
      expect(data.ok).toBe(true);
      expect(data.apiKey).toMatch(/^sk-[a-f0-9]{32}$/);
      expect(data.received).toEqual({ event: 'test', value: 42 });
    });

    it('sets content-type to application/json; charset=utf-8 on success', async () => {
      const body = JSON.stringify({ ping: true });
      const { timestamp, signature } = await signRequest(body, testEnv.SHARED_SECRET);

      const request = new Request('https://worker.test/inbox', {
        method: 'POST',
        headers: {
          'content-type': 'application/json',
          'x-timestamp': timestamp,
          'x-signature': signature,
        },
        body,
      });

      const response = await worker.fetch(request, testEnv);

      expect(response.headers.get('content-type')).toBe('application/json; charset=utf-8');
    });
  });

  describe('POST /inbox — missing auth headers', () => {
    it('returns 401 with missing auth headers error when x-timestamp is absent', async () => {
      const body = JSON.stringify({ event: 'test' });
      const { signature } = await signRequest(body, testEnv.SHARED_SECRET);

      const request = new Request('https://worker.test/inbox', {
        method: 'POST',
        headers: {
          'content-type': 'application/json',
          'x-signature': signature,
          // x-timestamp intentionally omitted
        },
        body,
      });

      const response = await worker.fetch(request, testEnv);

      expect(response.status).toBe(401);
      const data = await response.json() as ErrorResponse;
      expect(data.error).toBe('missing auth headers');
    });

    it('returns 401 with missing auth headers error when x-signature is absent', async () => {
      const body = JSON.stringify({ event: 'test' });
      const { timestamp } = await signRequest(body, testEnv.SHARED_SECRET);

      const request = new Request('https://worker.test/inbox', {
        method: 'POST',
        headers: {
          'content-type': 'application/json',
          'x-timestamp': timestamp,
          // x-signature intentionally omitted
        },
        body,
      });

      const response = await worker.fetch(request, testEnv);

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

      const response = await worker.fetch(request, testEnv);

      expect(response.status).toBe(401);
      expect(response.headers.get('content-type')).toBe('application/json; charset=utf-8');
    });
  });

  describe('POST /inbox — stale timestamp', () => {
    it('returns 401 with stale or invalid timestamp when timestamp is more than 5 minutes old', async () => {
      const staleTimestamp = Date.now() - 6 * 60 * 1000; // 6 minutes ago
      const body = JSON.stringify({ event: 'test' });
      const { timestamp, signature } = await signRequest(body, testEnv.SHARED_SECRET, staleTimestamp);

      const request = new Request('https://worker.test/inbox', {
        method: 'POST',
        headers: {
          'content-type': 'application/json',
          'x-timestamp': timestamp,
          'x-signature': signature,
        },
        body,
      });

      const response = await worker.fetch(request, testEnv);

      expect(response.status).toBe(401);
      const data = await response.json() as ErrorResponse;
      expect(data.error).toBe('stale or invalid timestamp');
    });

    it('returns 401 with stale or invalid timestamp when timestamp is more than 5 minutes in the future', async () => {
      const futureTimestamp = Date.now() + 6 * 60 * 1000; // 6 minutes ahead
      const body = JSON.stringify({ event: 'test' });
      const { timestamp, signature } = await signRequest(body, testEnv.SHARED_SECRET, futureTimestamp);

      const request = new Request('https://worker.test/inbox', {
        method: 'POST',
        headers: {
          'content-type': 'application/json',
          'x-timestamp': timestamp,
          'x-signature': signature,
        },
        body,
      });

      const response = await worker.fetch(request, testEnv);

      expect(response.status).toBe(401);
      const data = await response.json() as ErrorResponse;
      expect(data.error).toBe('stale or invalid timestamp');
    });

    it('returns 401 with stale or invalid timestamp when x-timestamp is non-numeric', async () => {
      const body = JSON.stringify({ event: 'test' });
      // Compute a signature using the non-numeric string as the timestamp
      const hex = await hmacSignHex(testEnv.SHARED_SECRET, `not-a-number.${body}`);

      const request = new Request('https://worker.test/inbox', {
        method: 'POST',
        headers: {
          'content-type': 'application/json',
          'x-timestamp': 'not-a-number',
          'x-signature': hex,
        },
        body,
      });

      const response = await worker.fetch(request, testEnv);

      expect(response.status).toBe(401);
      const data = await response.json() as ErrorResponse;
      expect(data.error).toBe('stale or invalid timestamp');
    });
  });

  describe('POST /inbox — replay-window boundary (fake timers)', () => {
    afterEach(() => {
      vi.useRealTimers();
    });

    it('accepts request 1ms inside replay window', async () => {
      const baseTime = 1_000_000_000;
      vi.useFakeTimers();
      vi.setSystemTime(baseTime);

      const requestTime = baseTime - (REPLAY_WINDOW_MS - 1);
      const body = JSON.stringify({ event: 'boundary-inside' });
      const { timestamp, signature } = await signRequest(body, testEnv.SHARED_SECRET, requestTime);

      const request = new Request('https://worker.test/inbox', {
        method: 'POST',
        headers: {
          'content-type': 'application/json',
          'x-timestamp': timestamp,
          'x-signature': signature,
        },
        body,
      });

      const response = await worker.fetch(request, testEnv);
      expect(response.status).toBe(200);
    });

    it('accepts request exactly at replay window boundary (REPLAY_WINDOW_MS, strict >)', async () => {
      // Production check: Math.abs(delta) > REPLAY_WINDOW_MS (strict greater-than)
      // so a request exactly REPLAY_WINDOW_MS old is still accepted.
      const baseTime = 1_000_000_000;
      vi.useFakeTimers();
      vi.setSystemTime(baseTime);

      const requestTime = baseTime - REPLAY_WINDOW_MS;
      const body = JSON.stringify({ event: 'boundary-at' });
      const { timestamp, signature } = await signRequest(body, testEnv.SHARED_SECRET, requestTime);

      const request = new Request('https://worker.test/inbox', {
        method: 'POST',
        headers: {
          'content-type': 'application/json',
          'x-timestamp': timestamp,
          'x-signature': signature,
        },
        body,
      });

      const response = await worker.fetch(request, testEnv);
      expect(response.status).toBe(200);
    });

    it('rejects request 1ms outside replay window', async () => {
      const baseTime = 1_000_000_000;
      vi.useFakeTimers();
      vi.setSystemTime(baseTime);

      const requestTime = baseTime - (REPLAY_WINDOW_MS + 1);
      const body = JSON.stringify({ event: 'boundary-outside' });
      const { timestamp, signature } = await signRequest(body, testEnv.SHARED_SECRET, requestTime);

      const request = new Request('https://worker.test/inbox', {
        method: 'POST',
        headers: {
          'content-type': 'application/json',
          'x-timestamp': timestamp,
          'x-signature': signature,
        },
        body,
      });

      const response = await worker.fetch(request, testEnv);
      expect(response.status).toBe(401);
      const data = await response.json() as ErrorResponse;
      expect(data.error).toBe('stale or invalid timestamp');
    });
  });

  describe('POST /inbox — invalid signature', () => {
    it('returns 401 with invalid signature error when signature does not match', async () => {
      const body = JSON.stringify({ event: 'test' });
      const { timestamp } = await signRequest(body, testEnv.SHARED_SECRET);

      const request = new Request('https://worker.test/inbox', {
        method: 'POST',
        headers: {
          'content-type': 'application/json',
          'x-timestamp': timestamp,
          'x-signature': 'a'.repeat(64), // wrong signature
        },
        body,
      });

      const response = await worker.fetch(request, testEnv);

      expect(response.status).toBe(401);
      const data = await response.json() as ErrorResponse;
      expect(data.error).toBe('invalid signature');
    });
  });

  describe('POST /inbox — invalid JSON body', () => {
    it('returns 400 with invalid json error when body is not valid JSON', async () => {
      const body = 'not valid json {';
      const { timestamp, signature } = await signRequest(body, testEnv.SHARED_SECRET);

      const request = new Request('https://worker.test/inbox', {
        method: 'POST',
        headers: {
          'content-type': 'application/json',
          'x-timestamp': timestamp,
          'x-signature': signature,
        },
        body,
      });

      const response = await worker.fetch(request, testEnv);

      expect(response.status).toBe(400);
      const data = await response.json() as ErrorResponse;
      expect(data.error).toBe('invalid json');
    });

    it('sets content-type to application/json; charset=utf-8 on 400 error', async () => {
      const body = 'not valid json {';
      const { timestamp, signature } = await signRequest(body, testEnv.SHARED_SECRET);

      const request = new Request('https://worker.test/inbox', {
        method: 'POST',
        headers: {
          'content-type': 'application/json',
          'x-timestamp': timestamp,
          'x-signature': signature,
        },
        body,
      });

      const response = await worker.fetch(request, testEnv);

      expect(response.headers.get('content-type')).toBe('application/json; charset=utf-8');
    });
  });

  describe('resolveSigningKey', () => {
    it('returns SHARED_SECRET when keyId is undefined', () => {
      expect(resolveSigningKey(testEnv, undefined)).toBe(testEnv.SHARED_SECRET);
    });

    it('returns SHARED_SECRET when keyId is empty string', () => {
      expect(resolveSigningKey(testEnv, '')).toBe(testEnv.SHARED_SECRET);
    });

    it('returns mapped secret when keyId matches SIGNING_KEYS', () => {
      const env: Env = { ...testEnv, SIGNING_KEYS: JSON.stringify({ v2: 'new-secret' }) };
      expect(resolveSigningKey(env, 'v2')).toBe('new-secret');
    });

    it('returns null when keyId not in SIGNING_KEYS', () => {
      const env: Env = { ...testEnv, SIGNING_KEYS: JSON.stringify({ v2: 'new-secret' }) };
      expect(resolveSigningKey(env, 'v99')).toBeNull();
    });

    it('returns null when SIGNING_KEYS absent but keyId provided', () => {
      expect(resolveSigningKey(testEnv, 'v1')).toBeNull();
    });

    it('returns null when SIGNING_KEYS is malformed JSON', () => {
      const env: Env = { ...testEnv, SIGNING_KEYS: 'not-json' };
      expect(resolveSigningKey(env, 'v1')).toBeNull();
    });

    it('returns null when SIGNING_KEYS is a JSON string (not object)', () => {
      const env: Env = { ...testEnv, SIGNING_KEYS: '"just-a-string"' };
      expect(resolveSigningKey(env, 'v1')).toBeNull();
    });
  });

  describe('POST /inbox — x-key-id rotation', () => {
    const TEST_KEY_ID = 'v2';
    const TEST_SECRET_V2 = 'rotated-secret-v2';

    it('accepts request signed with key from SIGNING_KEYS when x-key-id matches', async () => {
      const env: Env = { ...testEnv, SIGNING_KEYS: JSON.stringify({ [TEST_KEY_ID]: TEST_SECRET_V2 }) };
      const body = JSON.stringify({ event: 'test' });
      const { timestamp, signature } = await signRequest(body, TEST_SECRET_V2);

      const request = new Request('https://worker.test/inbox', {
        method: 'POST',
        headers: {
          'content-type': 'application/json',
          'x-timestamp': timestamp,
          'x-signature': signature,
          'x-key-id': TEST_KEY_ID,
        },
        body,
      });

      const response = await worker.fetch(request, env);
      expect(response.status).toBe(200);
    });

    it('rejects request with unknown x-key-id', async () => {
      const env: Env = { ...testEnv, SIGNING_KEYS: JSON.stringify({ [TEST_KEY_ID]: TEST_SECRET_V2 }) };
      const body = JSON.stringify({ event: 'test' });
      const { timestamp, signature } = await signRequest(body, TEST_SECRET_V2);

      const request = new Request('https://worker.test/inbox', {
        method: 'POST',
        headers: {
          'content-type': 'application/json',
          'x-timestamp': timestamp,
          'x-signature': signature,
          'x-key-id': 'unknown-key',
        },
        body,
      });

      const response = await worker.fetch(request, env);
      expect(response.status).toBe(401);
      const data = await response.json() as ErrorResponse;
      expect(data.error).toBe('invalid signature');
    });

    it('rejects x-key-id when SIGNING_KEYS is not configured', async () => {
      const body = JSON.stringify({ event: 'test' });
      const { timestamp, signature } = await signRequest(body, testEnv.SHARED_SECRET);

      const request = new Request('https://worker.test/inbox', {
        method: 'POST',
        headers: {
          'content-type': 'application/json',
          'x-timestamp': timestamp,
          'x-signature': signature,
          'x-key-id': 'v1',
        },
        body,
      });

      const response = await worker.fetch(request, testEnv);
      expect(response.status).toBe(401);
    });
  });

  describe('Unknown routes', () => {
    it('returns 404 with not found error for unknown GET route', async () => {
      const request = new Request('https://worker.test/unknown', { method: 'GET' });
      const response = await worker.fetch(request, testEnv);

      expect(response.status).toBe(404);
      const data = await response.json() as ErrorResponse;
      expect(data.error).toBe('not found');
    });

    it('sets content-type to application/json; charset=utf-8 on 404 error', async () => {
      const request = new Request('https://worker.test/unknown', { method: 'GET' });
      const response = await worker.fetch(request, testEnv);

      expect(response.headers.get('content-type')).toBe('application/json; charset=utf-8');
    });
  });
});
