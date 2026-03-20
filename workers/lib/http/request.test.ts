import { describe, it, expect } from 'vitest';
import {
  isJsonRequest,
  safeParseJson,
  requireJson,
  getBearerToken,
  requireBearerToken,
  getQueryParam,
  getRequiredQueryParam,
  getPathname,
  assertMethod,
} from './request';

function makeRequest(
  url: string,
  opts: { method?: string; headers?: Record<string, string>; body?: string } = {},
): Request {
  return new Request(url, opts);
}

describe('isJsonRequest()', () => {
  it('returns true for application/json', () => {
    const r = makeRequest('http://t/', { headers: { 'content-type': 'application/json' } });
    expect(isJsonRequest(r)).toBe(true);
  });

  it('returns true for application/json; charset=utf-8', () => {
    const r = makeRequest('http://t/', { headers: { 'content-type': 'application/json; charset=utf-8' } });
    expect(isJsonRequest(r)).toBe(true);
  });

  it('returns false when no content-type', () => {
    expect(isJsonRequest(makeRequest('http://t/'))).toBe(false);
  });

  it('returns false for text/plain', () => {
    const r = makeRequest('http://t/', { headers: { 'content-type': 'text/plain' } });
    expect(isJsonRequest(r)).toBe(false);
  });
});

describe('safeParseJson()', () => {
  it('returns ok: true for valid JSON', async () => {
    const r = makeRequest('http://t/', { method: 'POST', body: '{"x":1}' });
    const result = await safeParseJson<{ x: number }>(r);
    expect(result).toEqual({ ok: true, data: { x: 1 } });
  });

  it('returns ok: false + 400 for invalid JSON', async () => {
    const r = makeRequest('http://t/', { method: 'POST', body: 'not json' });
    const result = await safeParseJson(r);
    expect(result.ok).toBe(false);
    if (!result.ok) expect(result.error.status).toBe(400);
  });
});

describe('requireJson()', () => {
  it('returns ok: false + 400 when content-type is not json', async () => {
    const r = makeRequest('http://t/', { method: 'POST', headers: { 'content-type': 'text/plain' }, body: '{}' });
    const result = await requireJson(r);
    expect(result.ok).toBe(false);
    if (!result.ok) expect(result.error.status).toBe(400);
  });

  it('returns ok: true for valid JSON with correct content-type', async () => {
    const r = makeRequest('http://t/', {
      method: 'POST',
      headers: { 'content-type': 'application/json' },
      body: '{"y":2}',
    });
    const result = await requireJson<{ y: number }>(r);
    expect(result).toEqual({ ok: true, data: { y: 2 } });
  });
});

describe('getBearerToken()', () => {
  it('extracts token from Authorization header', () => {
    const r = makeRequest('http://t/', { headers: { authorization: 'Bearer abc123' } });
    expect(getBearerToken(r)).toBe('abc123');
  });

  it('returns null when no authorization header', () => {
    expect(getBearerToken(makeRequest('http://t/'))).toBeNull();
  });

  it('returns null for non-Bearer schemes', () => {
    const r = makeRequest('http://t/', { headers: { authorization: 'Basic abc' } });
    expect(getBearerToken(r)).toBeNull();
  });
});

describe('requireBearerToken()', () => {
  it('returns ok: true with token when present', () => {
    const r = makeRequest('http://t/', { headers: { authorization: 'Bearer tok' } });
    const result = requireBearerToken(r);
    expect(result).toEqual({ ok: true, token: 'tok' });
  });

  it('returns ok: false + 401 when absent', () => {
    const result = requireBearerToken(makeRequest('http://t/'));
    expect(result.ok).toBe(false);
    if (!result.ok) expect(result.error.status).toBe(401);
  });
});

describe('getQueryParam()', () => {
  it('returns the query param value', () => {
    expect(getQueryParam(makeRequest('http://t/?foo=bar'), 'foo')).toBe('bar');
  });

  it('returns null for missing param', () => {
    expect(getQueryParam(makeRequest('http://t/'), 'foo')).toBeNull();
  });
});

describe('getRequiredQueryParam()', () => {
  it('returns ok: true for present param', () => {
    const r = makeRequest('http://t/?id=42');
    expect(getRequiredQueryParam(r, 'id')).toEqual({ ok: true, value: '42' });
  });

  it('returns ok: true for empty-string param (present but empty)', () => {
    const r = makeRequest('http://t/?id=');
    const result = getRequiredQueryParam(r, 'id');
    expect(result).toEqual({ ok: true, value: '' });
  });

  it('returns ok: false + 400 for missing param', () => {
    const result = getRequiredQueryParam(makeRequest('http://t/'), 'id');
    expect(result.ok).toBe(false);
    if (!result.ok) expect(result.error.status).toBe(400);
  });
});

describe('getPathname()', () => {
  it('returns the pathname', () => {
    expect(getPathname(makeRequest('http://t/foo/bar'))).toBe('/foo/bar');
  });
});

describe('assertMethod()', () => {
  it('returns null for allowed method', () => {
    const r = makeRequest('http://t/', { method: 'POST' });
    expect(assertMethod(r, ['GET', 'POST'])).toBeNull();
  });

  it('returns 405 for disallowed method', () => {
    const r = makeRequest('http://t/', { method: 'DELETE' });
    const result = assertMethod(r, ['GET', 'POST']);
    expect(result?.status).toBe(405);
  });

  it('is case-insensitive', () => {
    const r = makeRequest('http://t/', { method: 'post' });
    expect(assertMethod(r, ['POST'])).toBeNull();
  });
});
