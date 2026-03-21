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
    it('returns 200 with service name', async () => {
      const res = await worker.fetch(makeRequest('GET', '/health'), makeEnv());
      expect(res.status).toBe(200);
      const body = (await res.json()) as Record<string, unknown>;
      expect(body.ok).toBe(true);
      expect(body.service).toBe('api-gateway');
    });
  });

  describe('unknown routes', () => {
    it('returns 404 for unknown path', async () => {
      const res = await worker.fetch(makeRequest('GET', '/unknown'), makeEnv());
      expect(res.status).toBe(404);
    });
  });
});
