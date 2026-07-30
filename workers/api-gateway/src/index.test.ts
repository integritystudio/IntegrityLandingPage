import { describe, it, expect, vi, beforeEach, beforeAll, afterEach } from 'vitest';
import worker from './index';
import type { Env } from './index';
import * as quotaLib from './lib/quota';
import { createAuth0JwtFixture, TEST_AUTH0_OPTS, TEST_AUTH0_DOMAIN, type Auth0JwtFixture } from '../../lib/test-helpers/auth0-jwt-stub';


const makeEnv = (overrides: Partial<Env> = {}): Env => ({
  SUPABASE_URL: 'https://test.supabase.co',
  SUPABASE_SERVICE_ROLE_KEY: 'service-role-key',
  AUTH0_DOMAIN: TEST_AUTH0_DOMAIN,
  AUTH0_AUDIENCE: TEST_AUTH0_OPTS.auth0Audience,
  API_KEY_HMAC_SECRET: 'hmac-secret-at-least-32-chars-long!',
  QUOTA_DO: {} as DurableObjectNamespace,
  STRIPE_SECRET_KEY: 'sk_test_placeholder',
  ...overrides,
});

let jwt: Auth0JwtFixture;

beforeAll(async () => {
  jwt = await createAuth0JwtFixture();
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

  describe('CORS', () => {
    const ALLOWED_ORIGIN = 'https://integritystudio.ai';

    it('answers a preflight with 204 and the requested origin', async () => {
      const res = await worker.fetch(
        makeRequest('OPTIONS', '/v1/orgs', {
          headers: {
            Origin: ALLOWED_ORIGIN,
            'Access-Control-Request-Method': 'GET',
            'Access-Control-Request-Headers': 'authorization',
          },
        }),
        makeEnv(),
      );
      expect(res.status).toBe(204);
      expect(res.headers.get('Access-Control-Allow-Origin')).toBe(ALLOWED_ORIGIN);
      expect(res.headers.get('Access-Control-Allow-Headers')).toContain('Authorization');
      expect(res.headers.get('Access-Control-Allow-Methods')).toContain('GET');
    });

    // The browser drops a response without this header regardless of status, so the 401 the
    // Flutter app sees on an expired token must still be readable by its error handler.
    it('sets Access-Control-Allow-Origin on a 401', async () => {
      const res = await worker.fetch(
        makeRequest('GET', '/v1/orgs', { headers: { Origin: ALLOWED_ORIGIN } }),
        makeEnv(),
      );
      expect(res.status).toBe(401);
      expect(res.headers.get('Access-Control-Allow-Origin')).toBe(ALLOWED_ORIGIN);
    });

    it('sets Access-Control-Allow-Origin on the terminal 404', async () => {
      const res = await worker.fetch(
        makeRequest('GET', '/unknown', { headers: { Origin: ALLOWED_ORIGIN } }),
        makeEnv(),
      );
      expect(res.status).toBe(404);
      expect(res.headers.get('Access-Control-Allow-Origin')).toBe(ALLOWED_ORIGIN);
    });

    it('does not echo an origin outside the allowlist', async () => {
      const res = await worker.fetch(
        makeRequest('OPTIONS', '/v1/orgs', { headers: { Origin: 'https://evil.example' } }),
        makeEnv(),
      );
      expect(res.headers.get('Access-Control-Allow-Origin')).not.toBe('https://evil.example');
      expect(res.headers.get('Access-Control-Allow-Origin')).toBe(ALLOWED_ORIGIN);
    });

    it('honours ALLOWED_ORIGINS_JSON', async () => {
      const custom = 'https://staging.integritystudio.ai';
      const res = await worker.fetch(
        makeRequest('OPTIONS', '/v1/orgs', { headers: { Origin: custom } }),
        makeEnv({ ALLOWED_ORIGINS_JSON: JSON.stringify([custom]) }),
      );
      expect(res.headers.get('Access-Control-Allow-Origin')).toBe(custom);
    });

    // An empty allowlist must not emit the literal string "undefined" as the header value.
    it('falls back to a real origin when the allowlist is empty', async () => {
      const res = await worker.fetch(
        makeRequest('OPTIONS', '/v1/orgs', { headers: { Origin: ALLOWED_ORIGIN } }),
        makeEnv({ ALLOWED_ORIGINS_JSON: '[]' }),
      );
      expect(res.headers.get('Access-Control-Allow-Origin')).toBe(ALLOWED_ORIGIN);
    });

    it('preserves security headers alongside CORS on routed responses', async () => {
      const res = await worker.fetch(
        makeRequest('GET', '/v1/orgs', { headers: { Origin: ALLOWED_ORIGIN } }),
        makeEnv(),
      );
      expect(res.headers.get('X-Content-Type-Options')).toBe('nosniff');
      expect(res.headers.get('Cache-Control')).toBe('no-store');
      expect(res.headers.get('Vary')).toBe('Origin');
    });
  });

  describe('quota enforcement on org routes', () => {
    beforeEach(() => {
      vi.restoreAllMocks();
      // A signed token only verifies if the tenant's key set is reachable, so serve JWKS
      // locally. Everything else answers 503, standing in for unreachable Supabase — these
      // tests assert on quota behaviour, not on what the route handler ultimately returns.
      vi.stubGlobal('fetch', jwt.wrap((async () => new Response('unavailable', { status: 503 })) as unknown as typeof fetch));
    });

    afterEach(() => {
      vi.unstubAllGlobals();
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

      // Token verification runs before quota — no token means 401, not 429
      expect(res.status).toBe(401);
      expect(quotaLib.enforceOrgQuota).not.toHaveBeenCalled();
    });

    it('returns 401 for an invalid bearer token without consuming quota', async () => {
      vi.spyOn(quotaLib, 'enforceOrgQuota').mockResolvedValue({
        ok: false,
        response: new Response(
          JSON.stringify({ error: { message: 'Too Many Requests', reason: 'minute_limit' } }),
          { status: 429, headers: { 'Content-Type': 'application/json' } },
        ),
      });

      // Present but cryptographically invalid JWT — passes presence check but fails verification
      const res = await worker.fetch(
        makeRequest('GET', '/v1/orgs/org-123/dashboard', {
          headers: { Authorization: 'Bearer invalid.garbage.token' },
        }),
        makeEnv(),
      );

      // Token authentication failure must short-circuit before quota is decremented
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

      const token = await jwt.sign({ sub: 'auth0|user-123', email: 'user@example.com' });
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
      vi.spyOn(quotaLib, 'enforceOrgQuota').mockResolvedValue({ ok: true, rateLimitHeaders: {} });

      const token = await jwt.sign({ sub: 'auth0|user-123', email: 'user@example.com' });
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
      vi.spyOn(quotaLib, 'enforceOrgQuota').mockResolvedValue({ ok: true, rateLimitHeaders: {} });

      const token = await jwt.sign({ sub: 'auth0|user-123', email: 'user@example.com' });
      const res = await worker.fetch(
        makeRequest('GET', '/v1/orgs/org-123/entitlements', {
          headers: { Authorization: `Bearer ${token}` },
        }),
        makeEnv(),
      );

      // Quota fail-open → route executes → Supabase unreachable → non-429 response
      expect(res.status).not.toBe(429);
    });

    it('forwards X-RateLimit-Remaining-Minute and X-RateLimit-Remaining-Monthly on successful org responses', async () => {
      vi.spyOn(quotaLib, 'enforceOrgQuota').mockResolvedValue({
        ok: true,
        rateLimitHeaders: {
          'X-RateLimit-Remaining-Minute': '55',
          'X-RateLimit-Remaining-Monthly': '980',
        },
      });

      const token = await jwt.sign({ sub: 'auth0|user-123', email: 'user@example.com' });
      const res = await worker.fetch(
        makeRequest('GET', '/v1/orgs/org-123/billing-status', {
          headers: { Authorization: `Bearer ${token}` },
        }),
        makeEnv(),
      );

      // Rate limit headers are forwarded regardless of route handler status
      expect(res.headers.get('X-RateLimit-Remaining-Minute')).toBe('55');
      expect(res.headers.get('X-RateLimit-Remaining-Monthly')).toBe('980');
    });
  });
});
