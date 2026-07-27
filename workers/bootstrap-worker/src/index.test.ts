import { describe, it, expect, vi, afterEach } from 'vitest';
import { verifySupabaseJwt, parseJwtHeader } from './auth';
import worker from './index';
import type { Env } from './index';
import { loadOrgContext } from './bootstrap';

const makeEnv = (overrides: Partial<Env> = {}): Env => ({
  SUPABASE_URL: 'https://test.supabase.co',
  SUPABASE_SERVICE_ROLE_KEY: 'key',
  SUPABASE_JWT_SECRET: 'secret',
  ...overrides,
});

describe('bootstrap-worker routing', () => {
  it('returns 204 with CORS headers for OPTIONS preflight', async () => {
    const req = new Request('https://bootstrap.test/bootstrap', {
      method: 'OPTIONS',
      headers: { Origin: 'https://integritystudio.ai' },
    });
    const res = await worker.fetch(req, makeEnv());
    expect(res.status).toBe(204);
    expect(res.headers.get('Access-Control-Allow-Origin')).toBe('https://integritystudio.ai');
    expect(res.headers.get('Access-Control-Allow-Methods')).toContain('POST');
  });

  it('returns 404 (not 500) for unknown routes', async () => {
    const req = new Request('https://bootstrap.test/unknown', { method: 'GET' });
    const res = await worker.fetch(req, makeEnv());
    expect(res.status).toBe(404);
  });

  it('returns CORS header on 404 response', async () => {
    const req = new Request('https://bootstrap.test/unknown', {
      method: 'GET',
      headers: { Origin: 'https://integritystudio.ai' },
    });
    const res = await worker.fetch(req, makeEnv());
    expect(res.status).toBe(404);
    expect(res.headers.get('Access-Control-Allow-Origin')).toBeTruthy();
  });

  it('returns 200 for /health', async () => {
    const req = new Request('https://bootstrap.test/health', { method: 'GET' });
    const res = await worker.fetch(req, makeEnv());
    expect(res.status).toBe(200);
  });

  it('honors ALLOWED_ORIGINS_JSON for CORS', async () => {
    const req = new Request('https://bootstrap.test/bootstrap', {
      method: 'OPTIONS',
      headers: { Origin: 'http://localhost:3000' },
    });
    const res = await worker.fetch(req, makeEnv({
      ALLOWED_ORIGINS_JSON: JSON.stringify(['http://localhost:3000', 'https://integritystudio.ai']),
    }));
    expect(res.status).toBe(204);
    expect(res.headers.get('Access-Control-Allow-Origin')).toBe('http://localhost:3000');
  });
});

describe('auth', () => {
  describe('parseJwtHeader', () => {
    it('should parse valid jwt header', () => {
      const token =
        'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9' +
        '.eyJzdWIiOiJ1c2VyLWlkIiwiZW1haWwiOiJ0ZXN0QGV4YW1wbGUuY29tIiwiaWF0IjoxNzAzMDAwMDAwLCJleHAiOjk5OTk5OTk5OTl9' +
        '.signature';

      const result = parseJwtHeader(token);

      expect(result.ok).toBe(true);
      expect(result.ok && result.payload.sub).toBe('user-id');
      expect(result.ok && result.payload.email).toBe('test@example.com');
    });

    it('should reject invalid jwt format', () => {
      const result = parseJwtHeader('not-a-jwt');

      expect(result.ok).toBe(false);
      expect(!result.ok && result.error).toContain('invalid jwt format');
    });
  });

  describe('verifySupabaseJwt', () => {
    it('should reject expired jwt', async () => {
      // exp is in the past (1603000000)
      const token =
        'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9' +
        '.eyJzdWIiOiJ1c2VyLWlkIiwiZW1haWwiOiJ0ZXN0QGV4YW1wbGUuY29tIiwiaWF0IjoxNzAzMDAwMDAwLCJleHAiOjE2MDMwMDAwMDB9' +
        '.signature';

      const result = await verifySupabaseJwt(token, 'secret');

      expect(result.ok).toBe(false);
      expect(!result.ok && result.error).toBeDefined();
    });

    it('should reject invalid signature', async () => {
      // Valid structure but bad signature
      const token =
        'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9' +
        '.eyJzdWIiOiJ1c2VyLWlkIiwiZW1haWwiOiJ0ZXN0QGV4YW1wbGUuY29tIiwiaWF0IjoxNzAzMDAwMDAwLCJleXAiOjk5OTk5OTk5OTl9' +
        '.invalidsignature';

      const result = await verifySupabaseJwt(token, 'secret');

      expect(result.ok).toBe(false);
      expect(!result.ok && result.error).toBeDefined();
    });
  });
});

describe('loadOrgContext — org row mismatch', () => {
  afterEach(() => vi.restoreAllMocks());

  it('returns 404 when membership rows exist but no matching org rows found', async () => {
    // membership query returns a row for org-999, but org query returns no matching org
    vi.spyOn(globalThis, 'fetch').mockImplementation(async (input) => {
      const url = String(input);
      if (url.includes('organization_memberships')) {
        return new Response(
          JSON.stringify([{ organization_id: 'org-999', role: 'owner' }]),
          { status: 200, headers: { 'content-type': 'application/json' } },
        );
      }
      if (url.includes('organizations')) {
        // Returns an org with a DIFFERENT id — no match for org-999.
        return new Response(
          JSON.stringify([{ id: 'org-other', slug: 'other', name: 'Other', billing_status: 'active', current_plan: 'starter', quota_version: 1 }]),
          { status: 200, headers: { 'content-type': 'application/json' } },
        );
      }
      return new Response('', { status: 404 });
    });

    const result = await loadOrgContext(
      'user-1', null, 'https://test.supabase.co', 'service-key',
    );

    expect(result.ok).toBe(false);
    if (!result.ok) {
      expect(result.error.status).toBe(404);
    }
  });
});
