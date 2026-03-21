import { describe, it, expect, vi } from 'vitest';
import worker from './index';
import type { Env } from './index';

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
      const mockDOStub = {
        fetch: vi.fn().mockResolvedValue(new Response(JSON.stringify({ status: 'uninitialized' }), { status: 200 })),
      };
      const mockDO = {
        idFromName: vi.fn().mockReturnValue('health-probe-id'),
        get: vi.fn().mockReturnValue(mockDOStub),
      } as unknown as DurableObjectNamespace;

      const res = await worker.fetch(makeRequest('GET', '/health'), makeEnv({ QUOTA_DO: mockDO }));
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
});
