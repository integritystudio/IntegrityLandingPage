import { describe, it, expect, vi } from 'vitest';
import { errorResponse, corsPreflightResponse, resolveOutboundSigningKey } from './utils';
import { HTTP_STATUS, CONTENT_TYPES } from './types';

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
    AUTH0_AUDIENCE: 'audience',
    SUPABASE_URL: 'https://supabase.example.com',
    SUPABASE_SERVICE_ROLE_KEY: 'service-role-key',
  };

  it('returns SHARED_SECRET when no rotation vars are set', () => {
    const { secret, keyId } = resolveOutboundSigningKey(BASE_ENV);
    expect(secret).toBe('base-secret');
    expect(keyId).toBeUndefined();
  });

  it('returns rotated secret and keyId when ACTIVE_KEY_ID is found in SIGNING_KEYS', () => {
    const env = { ...BASE_ENV, ACTIVE_KEY_ID: 'v2', SIGNING_KEYS: JSON.stringify({ v2: 'rotated-secret' }) };
    const { secret, keyId } = resolveOutboundSigningKey(env);
    expect(secret).toBe('rotated-secret');
    expect(keyId).toBe('v2');
  });

  it('falls back to SHARED_SECRET and logs a warning when ACTIVE_KEY_ID is not in SIGNING_KEYS', () => {
    const warn = vi.spyOn(console, 'warn').mockImplementation(() => {});
    const env = { ...BASE_ENV, ACTIVE_KEY_ID: 'v99', SIGNING_KEYS: JSON.stringify({ v2: 'other-secret' }) };
    const { secret, keyId } = resolveOutboundSigningKey(env);
    expect(secret).toBe('base-secret');
    expect(keyId).toBeUndefined();
    expect(warn).toHaveBeenCalledWith(expect.stringContaining('v99'));
    warn.mockRestore();
  });

  it('falls back to SHARED_SECRET and logs an error when SIGNING_KEYS is invalid JSON', () => {
    const error = vi.spyOn(console, 'error').mockImplementation(() => {});
    const env = { ...BASE_ENV, ACTIVE_KEY_ID: 'v2', SIGNING_KEYS: 'not-valid-json' };
    const { secret, keyId } = resolveOutboundSigningKey(env);
    expect(secret).toBe('base-secret');
    expect(keyId).toBeUndefined();
    expect(error).toHaveBeenCalledWith(expect.stringContaining('SIGNING_KEYS'));
    error.mockRestore();
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
    const env: Record<string, unknown> = {
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
      await checkAuthRateLimit('10.0.0.1', env as Pick<import('./types').Env, 'RATE_LIMIT_KV'>);
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
