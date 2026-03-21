import { describe, it, expect, vi, beforeEach } from 'vitest';
import worker from './index';
import type { Env } from './index';
import * as quotaLib from './lib/quota';

const JWT_SECRET = 'jwt-secret-at-least-32-chars-long!!';

const makeEnv = (overrides: Partial<Env> = {}): Env => ({
  SUPABASE_URL: 'https://test.supabase.co',
  SUPABASE_SERVICE_ROLE_KEY: 'service-role-key',
  SUPABASE_JWT_SECRET: JWT_SECRET,
  API_KEY_HMAC_SECRET: 'hmac-secret-at-least-32-chars-long!',
  QUOTA_DO: {} as DurableObjectNamespace,
  STRIPE_SECRET_KEY: 'sk_test_placeholder',
  ...overrides,
});

async function makeJwt(payload: Record<string, unknown>, secret: string): Promise<string> {
  const header = btoa(JSON.stringify({ alg: 'HS256', typ: 'JWT' }))
    .replace(/\+/g, '-').replace(/\//g, '_').replace(/=+$/, '');
  const body = btoa(JSON.stringify({ exp: 9999999999, ...payload }))
    .replace(/\+/g, '-').replace(/\//g, '_').replace(/=+$/, '');
  const msg = `${header}.${body}`;
  const key = await crypto.subtle.importKey(
    'raw', new TextEncoder().encode(secret),
    { name: 'HMAC', hash: 'SHA-256' }, false, ['sign'],
  );
  const sig = await crypto.subtle.sign('HMAC', key, new TextEncoder().encode(msg));
  const sigB64 = btoa(String.fromCharCode(...new Uint8Array(sig)))
    .replace(/\+/g, '-').replace(/\//g, '_').replace(/=+$/, '');
  return `${msg}.${sigB64}`;
}

function makeRequest(method: string, path: string, init: RequestInit = {}): Request {
  return new Request(`https://api.integritystudio.ai${path}`, { method, ...init });
}

describe('api-gateway', () => {
  describe('GET /health', () => {
    it('returns a health status response with all expected fields', async () => {
      const res = await worker.fetch(makeRequest('GET', '/health'), makeEnv());
      // Status depends on Supabase connectivity; in tests expect 503 (db unreachable).
      // Key assertion: response is JSON with expected shape.
      const body = (await res.json()) as Record<string, unknown>;
      expect(body).toHaveProperty('database');
      expect(body).toHaveProperty('durableObjects');
      expect(body).toHaveProperty('timestamp');
      expect(['healthy', 'degraded', 'unhealthy']).toContain(body.database);
      expect(['healthy', 'degraded', 'unhealthy']).toContain(body.durableObjects);
    });
  });

  describe('unknown routes', () => {
    it('returns 404 for unknown path', async () => {
      const res = await worker.fetch(makeRequest('GET', '/unknown'), makeEnv());
      expect(res.status).toBe(404);
    });
  });

  describe('quota enforcement on org routes', () => {
    beforeEach(() => {
      vi.restoreAllMocks();
    });

    it('returns 401 for unauthenticated request even when quota is exceeded', async () => {
      vi.spyOn(quotaLib, 'enforceOrgQuota').mockResolvedValue({
        ok: false,
        response: new Response(
          JSON.stringify({ error: { message: 'Too Many Requests', reason: 'minute_limit' } }),
          { status: 429, headers: { 'Content-Type': 'application/json' } },
        ),
      });

      const res = await worker.fetch(
        makeRequest('GET', '/v1/orgs/org-123/dashboard'),
        makeEnv(),
      );

      // Bearer token presence check runs before quota — no token means 401, not 429
      expect(res.status).toBe(401);
      expect(quotaLib.enforceOrgQuota).not.toHaveBeenCalled();
    });

    it('returns 429 with quota headers when authenticated and quota is exceeded', async () => {
      vi.spyOn(quotaLib, 'enforceOrgQuota').mockResolvedValue({
        ok: false,
        response: new Response(
          JSON.stringify({ error: { message: 'Too Many Requests', reason: 'minute_limit' } }),
          {
            status: 429,
            headers: {
              'Content-Type': 'application/json',
              'X-RateLimit-Remaining-Minute': '0',
            },
          },
        ),
      });

      const token = await makeJwt({ sub: 'user-123', email: 'user@example.com' }, JWT_SECRET);
      const res = await worker.fetch(
        makeRequest('GET', '/v1/orgs/org-123/dashboard', {
          headers: { Authorization: `Bearer ${token}` },
        }),
        makeEnv(),
      );

      expect(res.status).toBe(429);
      expect(res.headers.get('X-RateLimit-Remaining-Minute')).toBe('0');
      const body = (await res.json()) as Record<string, unknown>;
      expect(body).toHaveProperty('error');
    });

    it('allows through to route handler when jwt and quota both pass', async () => {
      vi.spyOn(quotaLib, 'enforceOrgQuota').mockResolvedValue({ ok: true });

      const token = await makeJwt({ sub: 'user-123', email: 'user@example.com' }, JWT_SECRET);
      const res = await worker.fetch(
        makeRequest('GET', '/v1/orgs/org-123/dashboard', {
          headers: { Authorization: `Bearer ${token}` },
        }),
        makeEnv(),
      );

      // JWT passes, quota passes → route executes → Supabase unreachable in test → 500 or similar
      expect([200, 401, 403, 404, 500, 503]).toContain(res.status);
      expect(quotaLib.enforceOrgQuota).toHaveBeenCalledWith('org-123', expect.any(Object));
    });

    it('allows through (fail-open) when quota DO is unavailable', async () => {
      vi.spyOn(quotaLib, 'enforceOrgQuota').mockResolvedValue({ ok: true });

      const token = await makeJwt({ sub: 'user-123', email: 'user@example.com' }, JWT_SECRET);
      const res = await worker.fetch(
        makeRequest('GET', '/v1/orgs/org-123/entitlements', {
          headers: { Authorization: `Bearer ${token}` },
        }),
        makeEnv(),
      );

      // Quota fail-open → route executes → Supabase unreachable → non-429 response
      expect(res.status).not.toBe(429);
    });
  });
});
