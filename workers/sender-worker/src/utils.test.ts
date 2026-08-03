import { describe, it, expect, vi, beforeEach } from 'vitest';
import { errorResponse, corsPreflightResponse, resolveOutboundSigningKey } from './utils';
import { HTTP_STATUS, CONTENT_TYPES, type Env } from './types';

describe('errorResponse()', () => {
  it('returns a JSON response with error and code fields', async () => {
    const res = errorResponse('something broke', 'INTERNAL_ERROR', HTTP_STATUS.INTERNAL_SERVER_ERROR);
    expect(res.status).toBe(HTTP_STATUS.INTERNAL_SERVER_ERROR);
    const body = await res.json() as { error: string; code: string };
    expect(body.error).toBe('something broke');
    expect(body.code).toBe('INTERNAL_ERROR');
  });

  it('sets content-type to application/json', () => {
    const res = errorResponse('not found', 'NOT_FOUND', HTTP_STATUS.NOT_FOUND);
    expect(res.headers.get('content-type')).toBe(CONTENT_TYPES.JSON);
  });
});

describe('resolveOutboundSigningKey()', () => {
  const BASE_ENV = {
    SHARED_SECRET: 'base-secret',
    RECEIVER: {} as Fetcher,
    AUTH0_DOMAIN: 'example.auth0.com',
    AUTH0_CLIENT_ID: 'client-id',
    AUTH0_CLIENT_SECRET: 'client-secret',
    AUTH0_CLI_ID: 'cli-id',
    AUTH0_CLI_SECRET: 'cli-secret',
    AUTH0_AUDIENCE: 'audience',
    SUPABASE_URL: 'https://supabase.example.com',
    SUPABASE_SERVICE_ROLE_KEY: 'service-role-key',
  };

  it('returns rotated secret and keyId when ACTIVE_KEY_ID is found in SIGNING_KEYS', () => {
    const env = { ...BASE_ENV, ACTIVE_KEY_ID: 'v2', SIGNING_KEYS: JSON.stringify({ v2: 'rotated-secret' }) };
    const { secret, keyId } = resolveOutboundSigningKey(env);
    expect(secret).toBe('rotated-secret');
    expect(keyId).toBe('v2');
  });

  // CR29 step 2. Both cases below were the legacy path: no ACTIVE_KEY_ID meant sign with
  // SHARED_SECRET and send no x-key-id, which the receiver accepted. It no longer does, so a
  // sender still taking that path would emit requests guaranteed to 401 — and the receiver's
  // rejection is byte-identical to a forged signature, so the config error would present as an
  // attack. Failing closed here makes it a 500 at the sender with a log line naming the cause.
  //
  // Each asserts `secret === null` rather than `keyId === undefined`: the fallback returned an
  // undefined keyId too, so keyId alone cannot distinguish "refused to sign" from "signed with
  // the un-rotatable legacy credential".
  describe('fails closed when ACTIVE_KEY_ID is not set', () => {
    it('returns miss "active_key_id_unset" when no rotation vars are set', () => {
      const error = vi.spyOn(console, 'error').mockImplementation(() => {});
      const result = resolveOutboundSigningKey(BASE_ENV);
      expect(result.secret).toBeNull();
      expect(result.keyId).toBeUndefined();
      expect(result.miss).toBe('active_key_id_unset');
      expect(error).toHaveBeenCalledTimes(1);
      error.mockRestore();
    });

    // SHARED_SECRET is deliberately still bound in BASE_ENV — production's state until step 3
    // unbinds it. "Unreachable" has to be proven with the credential present, or the test only
    // shows that an absent secret cannot be used.
    it('does not fall back to SHARED_SECRET even though it is still bound', () => {
      const error = vi.spyOn(console, 'error').mockImplementation(() => {});
      expect(BASE_ENV.SHARED_SECRET).toBe('base-secret');
      expect(resolveOutboundSigningKey(BASE_ENV).secret).not.toBe('base-secret');
      error.mockRestore();
    });

    // Staging SIGNING_KEYS on the sender and activating it later used to be the documented
    // rotation runbook. It is now a broken config, not a staged one: staging belongs on the
    // receiver, whose SIGNING_KEYS must carry the new key before this worker starts sending it.
    it('returns a miss when SIGNING_KEYS is staged but ACTIVE_KEY_ID is not set', () => {
      const error = vi.spyOn(console, 'error').mockImplementation(() => {});
      const env = { ...BASE_ENV, SIGNING_KEYS: JSON.stringify({ v2: 'rotated-secret' }) };
      const result = resolveOutboundSigningKey(env);
      expect(result.secret).toBeNull();
      expect(result.miss).toBe('active_key_id_unset');
      error.mockRestore();
    });
  });

  // CR29 step 1: an unusable ACTIVE_KEY_ID must NOT downgrade to SHARED_SECRET either. Same
  // reasoning as above — a typo in the key id had been signing every request with the legacy
  // credential, and the request still succeeded on the wire.
  describe('fails closed when ACTIVE_KEY_ID cannot be resolved', () => {
    const cases: Array<[string, Record<string, unknown>, string]> = [
      ['SIGNING_KEYS is not bound', {}, 'signing_keys_unset'],
      ['SIGNING_KEYS is invalid JSON', { SIGNING_KEYS: 'not-valid-json' }, 'signing_keys_malformed'],
      ['SIGNING_KEYS is a JSON array', { SIGNING_KEYS: '["v2"]' }, 'signing_keys_malformed'],
      ['SIGNING_KEYS is JSON null', { SIGNING_KEYS: 'null' }, 'signing_keys_malformed'],
      ['SIGNING_KEYS is a JSON string', { SIGNING_KEYS: '"v2"' }, 'signing_keys_malformed'],
      ['the key id is absent from the map', { SIGNING_KEYS: JSON.stringify({ v1: 'other-secret' }) }, 'unknown_active_key_id'],
      // A truthiness check would have returned these as `secret`, typed string.
      ['the entry is a number', { SIGNING_KEYS: JSON.stringify({ v2: 123 }) }, 'signing_keys_malformed'],
      ['the entry is null', { SIGNING_KEYS: JSON.stringify({ v2: null }) }, 'signing_keys_malformed'],
      ['the entry is an empty string', { SIGNING_KEYS: JSON.stringify({ v2: '' }) }, 'signing_keys_malformed'],
    ];

    for (const [label, overrides, miss] of cases) {
      it(`returns miss "${miss}" when ${label}`, () => {
        const error = vi.spyOn(console, 'error').mockImplementation(() => {});
        const result = resolveOutboundSigningKey({ ...BASE_ENV, ACTIVE_KEY_ID: 'v2', ...overrides });
        expect(result.secret).toBeNull();
        expect(result.keyId).toBeUndefined();
        expect(result.miss).toBe(miss);
        expect(error).toHaveBeenCalledTimes(1);
        error.mockRestore();
      });
    }

    it('does not leak the secret material of a non-active key', () => {
      const error = vi.spyOn(console, 'error').mockImplementation(() => {});
      const env = { ...BASE_ENV, ACTIVE_KEY_ID: 'v99', SIGNING_KEYS: JSON.stringify({ v2: 'other-secret' }) };
      expect(resolveOutboundSigningKey(env).secret).toBeNull();
      expect(error).toHaveBeenCalledWith(expect.stringContaining('v99'));
      expect(error).not.toHaveBeenCalledWith(expect.stringContaining('other-secret'));
      error.mockRestore();
    });
  });
});

describe('corsPreflightResponse()', () => {
  it('returns 204 No Content', () => {
    const res = corsPreflightResponse();
    expect(res.status).toBe(HTTP_STATUS.NO_CONTENT);
  });

  it('body is null (empty)', async () => {
    const res = corsPreflightResponse();
    const text = await res.text();
    expect(text).toBe('');
  });

  it('includes CORS allow-methods header', () => {
    const res = corsPreflightResponse();
    expect(res.headers.get('access-control-allow-methods')).toContain('POST');
  });

  it('includes CORS allow-headers header', () => {
    const res = corsPreflightResponse();
    const allowedHeaders = res.headers.get('access-control-allow-headers');
    expect(allowedHeaders).toContain('content-type');
  });
});

import { checkAuthRateLimit, clearAuthRateLimitStore } from './utils';
import { AUTH_RATE_LIMIT_MAX } from './types';

describe('checkAuthRateLimit()', () => {
  const noKvEnv = {} as Pick<import('./types').Env, 'RATE_LIMIT_KV'>;

  beforeEach(() => { clearAuthRateLimitStore(); });

  it('allows requests up to AUTH_RATE_LIMIT_MAX', async () => {
    for (let i = 0; i < AUTH_RATE_LIMIT_MAX; i++) {
      const result = await checkAuthRateLimit('192.0.2.1', noKvEnv);
      expect(result.allowed).toBe(true);
    }
  });

  it('denies the request after AUTH_RATE_LIMIT_MAX is reached', async () => {
    for (let i = 0; i < AUTH_RATE_LIMIT_MAX; i++) {
      await checkAuthRateLimit('192.0.2.2', noKvEnv);
    }
    const result = await checkAuthRateLimit('192.0.2.2', noKvEnv);
    expect(result.allowed).toBe(false);
    if (!result.allowed) {
      expect(result.retryAfterSeconds).toBeGreaterThan(0);
    }
  });

  it('tracks IPs independently', async () => {
    for (let i = 0; i < AUTH_RATE_LIMIT_MAX; i++) {
      await checkAuthRateLimit('192.0.2.3', noKvEnv);
    }
    // Different IP should still be allowed
    const result = await checkAuthRateLimit('192.0.2.4', noKvEnv);
    expect(result.allowed).toBe(true);
  });

  it('enforces the limit with no KV binding — an unbound namespace degrades accuracy, it does not disable limiting', async () => {
    // Pins the semantics of the `if (!env.RATE_LIMIT_KV) return { allowed: true }`
    // early return, which reads like a fail-open but is not one: the in-memory
    // tier has already counted the request by that point. Guards against the
    // check being "simplified" into an actual fail-open.
    for (let i = 0; i < AUTH_RATE_LIMIT_MAX; i++) {
      expect((await checkAuthRateLimit('198.51.100.1', noKvEnv)).allowed).toBe(true);
    }
    expect((await checkAuthRateLimit('198.51.100.1', noKvEnv)).allowed).toBe(false);
  });

  it('warns once per isolate when RATE_LIMIT_KV is unbound, so a misconfigured deploy is visible', async () => {
    const warn = vi.spyOn(console, 'warn').mockImplementation(() => {});
    try {
      await checkAuthRateLimit('198.51.100.2', noKvEnv);
      await checkAuthRateLimit('198.51.100.3', noKvEnv);
      expect(warn).toHaveBeenCalledTimes(1);
      expect(warn.mock.calls[0][0]).toContain('RATE_LIMIT_KV is not bound');
    } finally {
      warn.mockRestore();
    }
  });

  it('KV read failure degrades to the in-memory count rather than failing open', async () => {
    const failingKv = {
      get: vi.fn().mockRejectedValue(new Error('KV unavailable')),
      put: vi.fn().mockRejectedValue(new Error('KV unavailable')),
    } as unknown as KVNamespace;
    const env = { RATE_LIMIT_KV: failingKv } as Pick<import('./types').Env, 'RATE_LIMIT_KV'>;
    const error = vi.spyOn(console, 'error').mockImplementation(() => {});
    try {
      for (let i = 0; i < AUTH_RATE_LIMIT_MAX; i++) {
        await checkAuthRateLimit('198.51.100.4', env);
      }
      expect((await checkAuthRateLimit('198.51.100.4', env)).allowed).toBe(false);
    } finally {
      error.mockRestore();
    }
  });

  it('returns 429 and Retry-After header for rate-limited signup requests', async () => {
    // Annotated `Env`, not `Record<string, unknown>`: the latter is not assignable to the
    // parameter of `worker.fetch` below, and widening it hid the fact that this literal
    // really does satisfy every required field. RATE_LIMIT_KV is deliberately absent so
    // checkAuthRateLimit falls back to its in-memory counter.
    const env: Env = {
      SHARED_SECRET: 'test-shared-secret-key',
      RECEIVER: { fetch: vi.fn() } as unknown as Fetcher,
      AUTH0_DOMAIN: 'test.auth0.com',
      AUTH0_CLIENT_ID: 'spa-client',
      AUTH0_CLIENT_SECRET: 'spa-secret',
      AUTH0_CLI_ID: 'cli-id',
      AUTH0_CLI_SECRET: 'cli-secret',
      AUTH0_AUDIENCE: 'https://test.auth0.com/api/v2/',
      SUPABASE_URL: 'https://supabase.test',
      SUPABASE_SERVICE_ROLE_KEY: 'service-role-key',
    };

    // Exhaust the limit
    for (let i = 0; i < AUTH_RATE_LIMIT_MAX; i++) {
      await checkAuthRateLimit('10.0.0.1', env);
    }

    // Import worker via dynamic import to avoid circular reference at module load time
    const { default: worker } = await import('./index');
    const request = new Request('https://worker.test/signup', {
      method: 'POST',
      headers: { 'content-type': 'application/json', 'CF-Connecting-IP': '10.0.0.1' },
      body: JSON.stringify({ email: 'rl@example.com', password: 'Pass1234!' }),
    });

    const response = await worker.fetch(request, env);
    expect(response.status).toBe(429);
    expect(response.headers.get('Retry-After')).not.toBeNull();
  });
});
