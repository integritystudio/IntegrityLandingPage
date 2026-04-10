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
