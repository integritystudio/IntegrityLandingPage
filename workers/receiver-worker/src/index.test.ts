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
      const body = JSON.stringify({ action: 'provision_api_key', event: 'test', value: 42 });
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
      expect(data.received).toEqual({ action: 'provision_api_key', event: 'test', value: 42 });
    });

    it('returns unique apiKey on each call', async () => {
      async function callInbox(): Promise<string> {
        const body = JSON.stringify({ action: 'provision_api_key', event: 'uniqueness-check' });
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
        const data = await response.json() as InboxSuccessResponse;
        return data.apiKey;
      }

      const [key1, key2] = await Promise.all([callInbox(), callInbox()]);
      expect(key1).toMatch(/^sk-[a-f0-9]{32}$/);
      expect(key2).toMatch(/^sk-[a-f0-9]{32}$/);
      expect(key1).not.toBe(key2);
    });

  });

  describe('POST /inbox — missing auth headers', () => {
    it('returns 401 with missing auth headers error when x-timestamp is absent', async () => {
      const body = JSON.stringify({ action: 'provision_api_key', event: 'test' });
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
      const body = JSON.stringify({ action: 'provision_api_key', event: 'test' });
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

  });

  describe('POST /inbox — stale timestamp', () => {
    it('returns 401 with stale or invalid timestamp when timestamp is more than 5 minutes old', async () => {
      const staleTimestamp = Date.now() - 6 * 60 * 1000; // 6 minutes ago
      const body = JSON.stringify({ action: 'provision_api_key', event: 'test' });
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
      const body = JSON.stringify({ action: 'provision_api_key', event: 'test' });
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
      const body = JSON.stringify({ action: 'provision_api_key', event: 'test' });
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
      const body = JSON.stringify({ action: 'provision_api_key', event: 'boundary-inside' });
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
      const body = JSON.stringify({ action: 'provision_api_key', event: 'boundary-at' });
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
      const body = JSON.stringify({ action: 'provision_api_key', event: 'boundary-outside' });
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
      const body = JSON.stringify({ action: 'provision_api_key', event: 'test' });
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

  });

  describe('POST /inbox — action dispatch', () => {
    it('returns 400 unknown action when action is missing', async () => {
      const body = JSON.stringify({ event: 'no-action' });
      const { timestamp, signature } = await signRequest(body, testEnv.SHARED_SECRET);
      const request = new Request('https://worker.test/inbox', {
        method: 'POST',
        headers: { 'content-type': 'application/json', 'x-timestamp': timestamp, 'x-signature': signature },
        body,
      });
      const response = await worker.fetch(request, testEnv);
      expect(response.status).toBe(400);
      expect((await response.json() as ErrorResponse).error).toBe('unknown action');
    });

    it('returns 400 unknown action when action is not in allowlist', async () => {
      const body = JSON.stringify({ action: 'delete_everything' });
      const { timestamp, signature } = await signRequest(body, testEnv.SHARED_SECRET);
      const request = new Request('https://worker.test/inbox', {
        method: 'POST',
        headers: { 'content-type': 'application/json', 'x-timestamp': timestamp, 'x-signature': signature },
        body,
      });
      const response = await worker.fetch(request, testEnv);
      expect(response.status).toBe(400);
      expect((await response.json() as ErrorResponse).error).toBe('unknown action');
    });

    it('returns stub sign_in response with empty orgs and apiKeys', async () => {
      const body = JSON.stringify({ action: 'sign_in', email: 'user@acme.com' });
      const { timestamp, signature } = await signRequest(body, testEnv.SHARED_SECRET);
      const request = new Request('https://worker.test/inbox', {
        method: 'POST',
        headers: { 'content-type': 'application/json', 'x-timestamp': timestamp, 'x-signature': signature },
        body,
      });
      const response = await worker.fetch(request, testEnv);
      expect(response.status).toBe(200);
      const data = await response.json() as { ok: boolean; user: { userId: string; email: string }; organizations: unknown[]; apiKeys: unknown[] };
      expect(data.ok).toBe(true);
      expect(data.user.email).toBe('user@acme.com');
      expect(data.user.userId).toMatch(/^[0-9a-f-]{36}$/);
      expect(data.organizations).toEqual([]);
      expect(data.apiKeys).toEqual([]);
    });
  });

  describe('resolveSigningKey', () => {
    it('returns SHARED_SECRET when keyId is undefined', () => {
      expect(resolveSigningKey(testEnv, undefined)).toBe(testEnv.SHARED_SECRET);
    });

    it('returns null when keyId is empty string (prevents rotation bypass)', () => {
      expect(resolveSigningKey(testEnv, '')).toBeNull();
      expect(resolveSigningKey(testEnv, '   ')).toBeNull();
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
      const body = JSON.stringify({ action: 'provision_api_key', event: 'test' });
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
      const body = JSON.stringify({ action: 'provision_api_key', event: 'test' });
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
      const body = JSON.stringify({ action: 'provision_api_key', event: 'test' });
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

  });
});
