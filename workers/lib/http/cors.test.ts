import { describe, it, expect, vi, afterEach } from 'vitest';
import { buildCors, isOriginAllowed, parseAllowedOrigins, DEFAULT_ALLOWED_ORIGINS, type CorsPolicy } from './cors';

const PROD = 'https://integritystudio.ai';
const EVIL = 'https://evil.example';
const PREVIEW_SUFFIX = '.integritystudio-ai-c1a.pages.dev';
const PREVIEW = `https://bc710702${PREVIEW_SUFFIX}`;

const policy = (overrides: Partial<CorsPolicy> = {}): CorsPolicy => ({
  allowMethods: 'GET, POST, OPTIONS',
  allowHeaders: 'Content-Type',
  ...overrides,
});

afterEach(() => {
  vi.restoreAllMocks();
});

describe('parseAllowedOrigins', () => {
  it('uses the production defaults when unset', () => {
    expect(parseAllowedOrigins(undefined)).toEqual([...DEFAULT_ALLOWED_ORIGINS]);
  });

  it('honours a configured list, and an explicit empty one', () => {
    expect(parseAllowedOrigins('["http://localhost:8080"]')).toEqual(['http://localhost:8080']);
    expect(parseAllowedOrigins('[]')).toEqual([]);
  });

  it.each([
    ['invalid JSON', 'not json'],
    ['a non-array', '{"a":1}'],
    ['a non-string member', '["https://ok.example", 42]'],
  ])('falls back to the defaults for %s', (_label, json) => {
    vi.spyOn(console, 'error').mockImplementation(() => {});
    expect(parseAllowedOrigins(json)).toEqual([...DEFAULT_ALLOWED_ORIGINS]);
  });
});

describe('isOriginAllowed', () => {
  it('allows an allowlisted origin and refuses others, including no origin', () => {
    expect(isOriginAllowed(PROD, {})).toBe(true);
    expect(isOriginAllowed(EVIL, {})).toBe(false);
    expect(isOriginAllowed(null, {})).toBe(false);
  });

  it('allows a preview host only over https and on a dot-anchored suffix', () => {
    const rule = { previewHostSuffix: PREVIEW_SUFFIX };
    expect(isOriginAllowed(PREVIEW, rule)).toBe(true);
    expect(isOriginAllowed(`http://bc710702${PREVIEW_SUFFIX}`, rule)).toBe(false);
    expect(isOriginAllowed(`${PREVIEW}.attacker.com`, rule)).toBe(false);
    expect(isOriginAllowed(`https://integritystudio-ai-c1a.pages.dev`, rule)).toBe(false);
    expect(isOriginAllowed(PREVIEW, {})).toBe(false);
  });

  it('matches nothing through a suffix that lacks its leading dot', () => {
    expect(isOriginAllowed('https://evilintegritystudio-ai-c1a.pages.dev', { previewHostSuffix: 'integritystudio-ai-c1a.pages.dev' }))
      .toBe(false);
  });
});

describe('buildCors', () => {
  it('reflects an allowed origin and always varies on Origin', () => {
    const { allowed, headers } = buildCors(PROD, policy());
    expect(allowed).toBe(true);
    expect(headers['Access-Control-Allow-Origin']).toBe(PROD);
    expect(headers.Vary).toBe('Origin');
    expect(headers['Access-Control-Allow-Methods']).toBe('GET, POST, OPTIONS');
  });

  it('never reflects a disallowed origin', () => {
    const omit = buildCors(EVIL, policy());
    const first = buildCors(EVIL, policy({ disallowedOriginHeader: 'first-allowed' }));
    expect(omit.allowed).toBe(false);
    expect(omit.headers['Access-Control-Allow-Origin']).toBeUndefined();
    expect(first.headers['Access-Control-Allow-Origin']).toBe(DEFAULT_ALLOWED_ORIGINS[0]);
  });

  it('sends no Allow-Origin for any caller when the allowlist is explicitly empty', () => {
    const { headers } = buildCors(PROD, policy({ allowedOriginsJson: '[]', disallowedOriginHeader: 'first-allowed' }));
    expect(headers['Access-Control-Allow-Origin']).toBeUndefined();
  });

  it('grants credentials only to an allowed origin, and only when asked', () => {
    expect(buildCors(PROD, policy({ allowCredentials: true })).headers['Access-Control-Allow-Credentials']).toBe('true');
    expect(buildCors(EVIL, policy({ allowCredentials: true, disallowedOriginHeader: 'first-allowed' }))
      .headers['Access-Control-Allow-Credentials']).toBeUndefined();
    expect(buildCors(PROD, policy()).headers['Access-Control-Allow-Credentials']).toBeUndefined();
  });

  it('drops a configured "*", so no caller is ever answered with a wildcard', () => {
    vi.spyOn(console, 'error').mockImplementation(() => {});
    const json = '["*", "https://ok.example"]';
    expect(parseAllowedOrigins(json)).toEqual(['https://ok.example']);
    const literal = buildCors('*', policy({ allowedOriginsJson: json, disallowedOriginHeader: 'first-allowed' }));
    expect(literal.allowed).toBe(false);
    expect(literal.headers['Access-Control-Allow-Origin']).toBe('https://ok.example');
    expect(buildCors(EVIL, policy({ allowedOriginsJson: json })).headers['Access-Control-Allow-Origin']).toBeUndefined();
  });
});
