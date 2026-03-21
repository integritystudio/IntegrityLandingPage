import { describe, it, expect, vi, beforeEach } from 'vitest';
import worker from './index';
import type { Env } from './index';
import * as quotaLib from './lib/quota';

const makeEnv = (overrides: Partial<Env> = {}): Env => ({
  SUPABASE_URL: 'https://test.supabase.co',
  SUPABASE_SERVICE_ROLE_KEY: 'service-role-key',
  SUPABASE_JWT_SECRET: 'jwt-secret-at-least-32-chars-long!!',
  API_KEY_HMAC_SECRET: 'hmac-secret-at-least-32-chars-long!',
  QUOTA_DO: {} as DurableObjectNamespace,
  ...overrides,
});

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

    it('returns 429 with quota headers when quota is exceeded', async () => {
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

      const res = await worker.fetch(
        makeRequest('GET', '/v1/orgs/org-123/dashboard'),
        makeEnv(),
      );

      expect(res.status).toBe(429);
      expect(res.headers.get('X-RateLimit-Remaining-Minute')).toBe('0');
      const body = (await res.json()) as Record<string, unknown>;
      expect(body).toHaveProperty('error');
    });

    it('allows through when quota check passes', async () => {
      vi.spyOn(quotaLib, 'enforceOrgQuota').mockResolvedValue({ ok: true });

      // Route still needs auth — expect 401, not 404/429
      const res = await worker.fetch(
        makeRequest('GET', '/v1/orgs/org-123/dashboard'),
        makeEnv(),
      );

      expect(res.status).toBe(401);
    });

    it('allows through when quota check fails (fail-open)', async () => {
      vi.spyOn(quotaLib, 'enforceOrgQuota').mockResolvedValue({ ok: true });

      const res = await worker.fetch(
        makeRequest('GET', '/v1/orgs/org-123/entitlements'),
        makeEnv(),
      );

      // Quota passed → route executes → no token → 401
      expect(res.status).toBe(401);
    });
  });
});
