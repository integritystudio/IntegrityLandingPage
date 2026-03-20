import { describe, it, expect } from 'vitest';
import { corsHeaders, withCors, handleOptions } from './cors';

describe('corsHeaders()', () => {
  it('defaults origin to *', () => {
    const h = corsHeaders();
    expect(h.get('access-control-allow-origin')).toBe('*');
  });

  it('sets origin from options', () => {
    expect(corsHeaders({ origin: 'https://example.com' }).get('access-control-allow-origin'))
      .toBe('https://example.com');
  });

  it('includes default methods', () => {
    const methods = corsHeaders().get('access-control-allow-methods') ?? '';
    expect(methods).toContain('GET');
    expect(methods).toContain('POST');
    expect(methods).toContain('OPTIONS');
  });

  it('accepts custom methods', () => {
    const h = corsHeaders({ methods: ['POST', 'OPTIONS'] });
    expect(h.get('access-control-allow-methods')).toBe('POST, OPTIONS');
  });

  it('sets access-control-max-age', () => {
    expect(corsHeaders().get('access-control-max-age')).toBe('86400');
  });

  it('does not set credentials by default', () => {
    expect(corsHeaders().get('access-control-allow-credentials')).toBeNull();
  });

  it('sets credentials when enabled with a specific origin', () => {
    const h = corsHeaders({ origin: 'https://example.com', credentials: true });
    expect(h.get('access-control-allow-credentials')).toBe('true');
  });

  it('throws when credentials: true is combined with wildcard origin', () => {
    expect(() => corsHeaders({ credentials: true })).toThrow('credentials: true requires a specific origin');
  });
});

describe('withCors()', () => {
  it('adds CORS headers to an existing response', () => {
    const r = withCors(new Response('ok', { status: 200 }), { origin: 'https://a.com' });
    expect(r.headers.get('access-control-allow-origin')).toBe('https://a.com');
  });

  it('preserves the original status and body', async () => {
    const r = withCors(new Response('body', { status: 201 }));
    expect(r.status).toBe(201);
    expect(await r.text()).toBe('body');
  });

  it('preserves existing response headers', () => {
    const original = new Response(null, { headers: { 'x-custom': 'yes' } });
    const r = withCors(original);
    expect(r.headers.get('x-custom')).toBe('yes');
  });
});

describe('handleOptions()', () => {
  it('returns null for non-OPTIONS requests', () => {
    const r = new Request('http://t/', { method: 'POST' });
    expect(handleOptions(r)).toBeNull();
  });

  it('returns 204 for OPTIONS requests', () => {
    const r = new Request('http://t/', { method: 'OPTIONS' });
    expect(handleOptions(r)?.status).toBe(204);
  });

  it('includes CORS headers in OPTIONS response', () => {
    const r = new Request('http://t/', { method: 'OPTIONS' });
    const resp = handleOptions(r, { origin: 'https://b.com' });
    expect(resp?.headers.get('access-control-allow-origin')).toBe('https://b.com');
  });
});
