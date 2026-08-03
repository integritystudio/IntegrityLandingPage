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

const TEST_KEY_ID = 'v2';
const TEST_SECRET_V2 = 'rotated-secret-v2';

// SIGNING_KEYS deliberately maps to a *different* secret than SHARED_SECRET: the two
// verification paths cannot then be confused, and a test that signs with the wrong one
// fails instead of passing by coincidence. SHARED_SECRET stays set because production
// keeps it bound until CR29 step 3 — "unreachable" has to be proven with it present.
const testEnv: Env = {
  SHARED_SECRET: 'test-shared-secret-key',
  SIGNING_KEYS: JSON.stringify({ [TEST_KEY_ID]: TEST_SECRET_V2 }),
};

/** An env with the SIGNING_KEYS secret unbound — how it reads at runtime, whatever Env says. */
const ENV_NO_SIGNING_KEYS = { ...testEnv, SIGNING_KEYS: undefined } as unknown as Env;

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

/**
 * POST /inbox with the given auth headers. `keyId` defaults to the valid one; pass `null`
 * to omit the header, which is now rejected (CR29 step 2). Two reasons for the shape:
 * defaulting means a test that simply forgot x-key-id cannot silently pass on the 401 that
 * key resolution returns instead of whatever it was written to check — and the sentinel is
 * `null` rather than `undefined` because JS resolves an explicit `undefined` argument to the
 * default, so `undefined` would send the header while reading as if it omitted it.
 */
function inboxRequest(
  body: string,
  timestamp: string,
  signature: string,
  keyId: string | null = TEST_KEY_ID,
): Request {
  const headers: Record<string, string> = {
    'content-type': 'application/json',
    'x-timestamp': timestamp,
    'x-signature': signature,
  };
  if (keyId !== null) headers['x-key-id'] = keyId;
  return new Request('https://worker.test/inbox', { method: 'POST', headers, body });
}

/** POST /inbox correctly signed with the active key. */
async function signedInboxRequest(body: string, timestamp?: number): Promise<Request> {
  const signed = await signRequest(body, TEST_SECRET_V2, timestamp);
  return inboxRequest(body, signed.timestamp, signed.signature);
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
      const response = await worker.fetch(await signedInboxRequest(body), testEnv);

      expect(response.status).toBe(200);
      const data = await response.json() as InboxSuccessResponse;
      expect(data.ok).toBe(true);
      expect(data.apiKey).toMatch(/^sk-[a-f0-9]{32}$/);
      expect(data.received).toEqual({ action: 'provision_api_key', event: 'test', value: 42 });
    });

    it('returns unique apiKey on each call', async () => {
      async function callInbox(): Promise<string> {
        const body = JSON.stringify({ action: 'provision_api_key', event: 'uniqueness-check' });
        const response = await worker.fetch(await signedInboxRequest(body), testEnv);
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
      const { signature } = await signRequest(body, TEST_SECRET_V2);

      const request = new Request('https://worker.test/inbox', {
        method: 'POST',
        headers: {
          'content-type': 'application/json',
          'x-signature': signature,
          'x-key-id': TEST_KEY_ID,
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
      const { timestamp } = await signRequest(body, TEST_SECRET_V2);

      const request = new Request('https://worker.test/inbox', {
        method: 'POST',
        headers: {
          'content-type': 'application/json',
          'x-timestamp': timestamp,
          'x-key-id': TEST_KEY_ID,
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
      const response = await worker.fetch(await signedInboxRequest(body, staleTimestamp), testEnv);

      expect(response.status).toBe(401);
      const data = await response.json() as ErrorResponse;
      expect(data.error).toBe('stale or invalid timestamp');
    });

    it('returns 401 with stale or invalid timestamp when timestamp is more than 5 minutes in the future', async () => {
      const futureTimestamp = Date.now() + 6 * 60 * 1000; // 6 minutes ahead
      const body = JSON.stringify({ action: 'provision_api_key', event: 'test' });
      const response = await worker.fetch(await signedInboxRequest(body, futureTimestamp), testEnv);

      expect(response.status).toBe(401);
      const data = await response.json() as ErrorResponse;
      expect(data.error).toBe('stale or invalid timestamp');
    });

    it('returns 401 with stale or invalid timestamp when x-timestamp is non-numeric', async () => {
      const body = JSON.stringify({ action: 'provision_api_key', event: 'test' });
      // Compute a signature using the non-numeric string as the timestamp
      const hex = await hmacSignHex(TEST_SECRET_V2, `not-a-number.${body}`);

      const response = await worker.fetch(inboxRequest(body, 'not-a-number', hex), testEnv);

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
      const response = await worker.fetch(await signedInboxRequest(body, requestTime), testEnv);
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
      const response = await worker.fetch(await signedInboxRequest(body, requestTime), testEnv);
      expect(response.status).toBe(200);
    });

    it('rejects request 1ms outside replay window', async () => {
      const baseTime = 1_000_000_000;
      vi.useFakeTimers();
      vi.setSystemTime(baseTime);

      const requestTime = baseTime - (REPLAY_WINDOW_MS + 1);
      const body = JSON.stringify({ action: 'provision_api_key', event: 'boundary-outside' });
      const response = await worker.fetch(await signedInboxRequest(body, requestTime), testEnv);
      expect(response.status).toBe(401);
      const data = await response.json() as ErrorResponse;
      expect(data.error).toBe('stale or invalid timestamp');
    });
  });

  describe('POST /inbox — invalid signature', () => {
    it('returns 401 with invalid signature error when signature does not match', async () => {
      const body = JSON.stringify({ action: 'provision_api_key', event: 'test' });
      const { timestamp } = await signRequest(body, TEST_SECRET_V2);

      // A valid x-key-id, so the 401 proves signature verification failed rather than key
      // resolution — the two are deliberately indistinguishable from the response alone.
      const response = await worker.fetch(inboxRequest(body, timestamp, 'a'.repeat(64)), testEnv);

      expect(response.status).toBe(401);
      const data = await response.json() as ErrorResponse;
      expect(data.error).toBe('invalid signature');
    });
  });

  describe('POST /inbox — invalid JSON body', () => {
    it('returns 400 with invalid json error when body is not valid JSON', async () => {
      const body = 'not valid json {';
      const response = await worker.fetch(await signedInboxRequest(body), testEnv);

      expect(response.status).toBe(400);
      const data = await response.json() as ErrorResponse;
      expect(data.error).toBe('invalid json');
    });

  });

  describe('POST /inbox — action dispatch', () => {
    it('returns 400 unknown action when action is missing', async () => {
      const body = JSON.stringify({ event: 'no-action' });
      const response = await worker.fetch(await signedInboxRequest(body), testEnv);
      expect(response.status).toBe(400);
      expect((await response.json() as ErrorResponse).error).toBe('unknown action');
    });

    it('returns 400 unknown action when action is not in allowlist', async () => {
      const body = JSON.stringify({ action: 'delete_everything' });
      const response = await worker.fetch(await signedInboxRequest(body), testEnv);
      expect(response.status).toBe(400);
      expect((await response.json() as ErrorResponse).error).toBe('unknown action');
    });

    it('returns stub sign_in response with empty orgs and apiKeys', async () => {
      const body = JSON.stringify({ action: 'sign_in', email: 'user@acme.com' });
      const response = await worker.fetch(await signedInboxRequest(body), testEnv);
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
    it('returns null when keyId is undefined (CR29 step 2)', () => {
      expect(resolveSigningKey(testEnv, undefined)).toBeNull();
    });

    it('does not resolve to SHARED_SECRET even though it is still bound', () => {
      // The load-bearing assertion, and the one that fails if the fallback is restored.
      expect(testEnv.SHARED_SECRET).toBe('test-shared-secret-key');
      expect(resolveSigningKey(testEnv, undefined)).not.toBe(testEnv.SHARED_SECRET);
    });

    it('returns null when keyId is empty string (prevents rotation bypass)', () => {
      expect(resolveSigningKey(testEnv, '')).toBeNull();
      expect(resolveSigningKey(testEnv, '   ')).toBeNull();
    });

    it('returns mapped secret when keyId matches SIGNING_KEYS', () => {
      expect(resolveSigningKey(testEnv, TEST_KEY_ID)).toBe(TEST_SECRET_V2);
    });

    it('returns null when keyId not in SIGNING_KEYS', () => {
      expect(resolveSigningKey(testEnv, 'v99')).toBeNull();
    });

    it('returns null when SIGNING_KEYS absent but keyId provided', () => {
      expect(resolveSigningKey(ENV_NO_SIGNING_KEYS, 'v1')).toBeNull();
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
    it('accepts request signed with key from SIGNING_KEYS when x-key-id matches', async () => {
      const body = JSON.stringify({ action: 'provision_api_key', event: 'test' });
      const response = await worker.fetch(await signedInboxRequest(body), testEnv);
      expect(response.status).toBe(200);
    });

    it('rejects request with unknown x-key-id', async () => {
      const body = JSON.stringify({ action: 'provision_api_key', event: 'test' });
      const { timestamp, signature } = await signRequest(body, TEST_SECRET_V2);

      const response = await worker.fetch(
        inboxRequest(body, timestamp, signature, 'unknown-key'),
        testEnv,
      );
      expect(response.status).toBe(401);
      const data = await response.json() as ErrorResponse;
      expect(data.error).toBe('invalid signature');
    });

    it('rejects x-key-id when SIGNING_KEYS is not configured', async () => {
      const body = JSON.stringify({ action: 'provision_api_key', event: 'test' });
      const { timestamp, signature } = await signRequest(body, TEST_SECRET_V2);

      const response = await worker.fetch(
        inboxRequest(body, timestamp, signature),
        ENV_NO_SIGNING_KEYS,
      );
      expect(response.status).toBe(401);
    });
  });

  describe('POST /inbox — keyless requests (CR29 step 2)', () => {
    // The hole this closed: production answered 200 to a request signed with the keyless
    // SHARED_SECRET, so removing a key from SIGNING_KEYS revoked nothing. Both tests omit
    // only the header — the signature itself is valid — so a 200 means the stub resolves
    // keyless traffic to some credential, not that the secret is wrong.
    it('rejects a correctly signed request that omits x-key-id', async () => {
      const body = JSON.stringify({ action: 'provision_api_key', event: 'test' });
      const { timestamp, signature } = await signRequest(body, TEST_SECRET_V2);

      // Positive control: the same request WITH the key id is accepted, so the 401 below
      // is the missing header and not a broken fixture.
      const control = await worker.fetch(inboxRequest(body, timestamp, signature), testEnv);
      expect(control.status).toBe(200);

      const response = await worker.fetch(
        inboxRequest(body, timestamp, signature, null),
        testEnv,
      );
      expect(response.status).toBe(401);
      const data = await response.json() as ErrorResponse;
      expect(data.error).toBe('invalid signature');
    });

    it('rejects a keyless request signed with SHARED_SECRET, the exact case production accepted', async () => {
      const body = JSON.stringify({ action: 'provision_api_key', event: 'test' });
      const { timestamp, signature } = await signRequest(body, testEnv.SHARED_SECRET);

      const response = await worker.fetch(
        inboxRequest(body, timestamp, signature, null),
        testEnv,
      );
      expect(response.status).toBe(401);
      const data = await response.json() as ErrorResponse;
      expect(data.error).toBe('invalid signature');
    });

    it('rejects a keyless request even with SIGNING_KEYS unbound', async () => {
      // Nothing to fall back TO is not what makes it fail: the header is required first.
      const body = JSON.stringify({ action: 'provision_api_key', event: 'test' });
      const { timestamp, signature } = await signRequest(body, testEnv.SHARED_SECRET);

      const response = await worker.fetch(
        inboxRequest(body, timestamp, signature, null),
        ENV_NO_SIGNING_KEYS,
      );
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
