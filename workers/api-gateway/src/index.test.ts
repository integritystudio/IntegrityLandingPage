import { describe, it, expect, vi, beforeEach, beforeAll, afterEach } from 'vitest';
import worker from './index';
import type { Env } from './index';
import * as quotaLib from './lib/quota';
import { createAuth0JwtFixture, TEST_AUTH0_OPTS, TEST_AUTH0_DOMAIN, type Auth0JwtFixture } from '../../lib/test-helpers/auth0-jwt-stub';
import { createSupabaseFetchStub, createdRows, okRows } from '../../lib/test-helpers/supabase-fetch-stub';
import { MockStorage, stubDurableObjectState } from '../../lib/test-helpers/durable-object-state-stub';
import { QuotaDurableObject } from './durable-objects/quota';
import { ORG_RATE_LIMIT_MAX, ORG_RATE_LIMIT_WINDOW_SECONDS, resetIdentityRateLimit, resetOrgRateLimit } from './lib/rate-limit';
import { resetAdminViewAudit } from './lib/admin-view-audit';
import { ADMIN_ORG_ROUTES } from './lib/org-routes';


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

/** Quota DO that admits every request; `onReserve` sees each check-and-reserve body. */
function admittingQuotaDo(onReserve?: (body: { orgId: string; units: number }) => void): DurableObjectNamespace {
  return {
    idFromName: (name: string) => name,
    get: () => ({
      fetch: async (request: Request) => {
        onReserve?.((await request.json()) as { orgId: string; units: number });
        return new Response(JSON.stringify({ allowed: true, remainingMinute: 1000, remainingMonthly: null }), {
          status: 200,
          headers: { 'Content-Type': 'application/json' },
        });
      },
    }),
  } as unknown as DurableObjectNamespace;
}

/** KV namespace over a Map, honouring the `json` read type the rate limiter uses. */
function mapKv(store = new Map<string, string>()): KVNamespace {
  return {
    get: async (key: string, type?: string) => {
      const raw = store.get(key);
      if (raw === undefined) return null;
      return type === 'json' ? JSON.parse(raw) : raw;
    },
    put: async (key: string, value: string) => {
      store.set(key, value);
    },
  } as unknown as KVNamespace;
}

describe('api-gateway', () => {
  describe('GET /health', () => {
    // TS02: stub fetch so the DB check fails immediately rather than waiting up
    // to DB_CHECK_TIMEOUT_MS (5 s) for DNS on the test.supabase.co hostname.
    beforeEach(() => {
      vi.stubGlobal('fetch', async (input: RequestInfo) => {
        const url = typeof input === 'string' ? input : (input as Request).url;
        if (url.includes('supabase')) {
          return new Response('service unavailable', { status: 503 });
        }
        throw new TypeError(`[test stub] unmatched fetch to ${url}`);
      });
    });
    afterEach(() => {
      vi.unstubAllGlobals();
    });

    it('returns a health status response with all expected fields', async () => {
      const res = await worker.fetch(makeRequest('GET', '/health'), makeEnv());
      // Supabase is stubbed as unreachable, so status is 503.
      expect(res.status).toBe(503);
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

    // An empty allowlist denies every origin (CR46). It used to fall back to the production
    // origin, so `[]` still admitted integritystudio.ai; it must not emit "undefined" either.
    it('sends no Allow-Origin at all when the allowlist is empty', async () => {
      const res = await worker.fetch(
        makeRequest('OPTIONS', '/v1/orgs', { headers: { Origin: ALLOWED_ORIGIN } }),
        makeEnv({ ALLOWED_ORIGINS_JSON: '[]' }),
      );
      expect(res.headers.get('Access-Control-Allow-Origin')).toBeNull();
      expect(res.headers.get('Vary')).toBe('Origin');
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
      expect(quotaLib.enforceOrgQuota).toHaveBeenCalledWith('org-123', expect.any(Object), { chargeMonthly: true });
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

// UA01: every /v1/orgs/:id/* response the quota DO admitted is mirrored into usage_events.
describe('usage ledger on org routes', () => {
  interface Captured { organization_id: string; route: string; metric_key: string; quantity: number; source: string; status_code: number; latency_ms: number; request_id: string }
  let captured: Captured[];
  let pending: Promise<unknown>[];
  let errorSpy: ReturnType<typeof vi.spyOn>;

  const ctx = () => ({
    waitUntil: (p: Promise<unknown>) => { pending.push(p); },
    passThroughOnException: () => {},
  }) as unknown as ExecutionContext;

  beforeEach(() => {
    vi.restoreAllMocks();
    captured = [];
    pending = [];
    errorSpy = vi.spyOn(console, 'error').mockImplementation(() => {});
    // usage_events inserts succeed; everything else stands in for unreachable Supabase.
    vi.stubGlobal('fetch', jwt.wrap((async (input: RequestInfo | URL, init?: RequestInit) => {
      const url = typeof input === 'string' ? input : input instanceof URL ? input.href : input.url;
      if (url.includes('/rest/v1/usage_events') && init?.method === 'POST') {
        const parsed: unknown = JSON.parse(String(init.body));
        captured.push((Array.isArray(parsed) ? parsed[0] : parsed) as Captured);
        return new Response('[]', { status: 201 });
      }
      return new Response('unavailable', { status: 503 });
    }) as unknown as typeof fetch));
  });

  afterEach(() => {
    errorSpy.mockRestore();
    vi.unstubAllGlobals();
  });

  it('records one `requests` unit per admitted org request, matching what the DO reserved', async () => {
    const enforce = vi.spyOn(quotaLib, 'enforceOrgQuota').mockResolvedValue({ ok: true, rateLimitHeaders: {} });
    const token = await jwt.sign({ sub: 'auth0|user-123', email: 'user@example.com' });

    const res = await worker.fetch(
      makeRequest('GET', '/v1/orgs/org-123/entitlements', { headers: { Authorization: `Bearer ${token}` } }),
      makeEnv(),
      ctx(),
    );
    await Promise.all(pending);

    expect(enforce).toHaveBeenCalledWith('org-123', expect.anything(), { chargeMonthly: true });
    expect(captured).toHaveLength(1);
    const [row] = captured;
    expect(row.organization_id).toBe('org-123');
    expect(row.route).toBe('GET /v1/orgs/:id/entitlements');
    expect(row.metric_key).toBe('requests');
    expect(row.quantity).toBe(1);
    expect(row.source).toBe('api');
    // Supabase is unreachable in this stub, so the handler answered non-2xx — and the
    // row still records it: the DO reserved the unit whatever the handler then did.
    expect(res.status).toBeGreaterThanOrEqual(400);
    expect(row.status_code).toBe(res.status);
    expect(row.latency_ms).toBeGreaterThanOrEqual(0);
    expect(row.request_id).toMatch(/^[0-9a-f-]{36}$/);
  });

  // CR58: reading usage or quota must not spend it; the per-minute check still runs.
  it.each(['/usage/summary', '/quota/status'])('charges no monthly quota and records nothing for GET %s', async (subPath) => {
    const enforce = vi.spyOn(quotaLib, 'enforceOrgQuota').mockResolvedValue({ ok: true, rateLimitHeaders: {} });
    const token = await jwt.sign({ sub: 'auth0|user-123', email: 'user@example.com' });

    await worker.fetch(
      makeRequest('GET', `/v1/orgs/org-123${subPath}`, { headers: { Authorization: `Bearer ${token}` } }),
      makeEnv(),
      ctx(),
    );
    await Promise.all(pending);

    expect(enforce).toHaveBeenCalledWith('org-123', expect.anything(), { chargeMonthly: false });
    expect(captured).toHaveLength(0);
  });

  it('records nothing when the quota DO refused the request', async () => {
    vi.spyOn(quotaLib, 'enforceOrgQuota').mockResolvedValue({
      ok: false,
      response: new Response(JSON.stringify({ error: 'quota exceeded' }), { status: 429 }),
    });
    const token = await jwt.sign({ sub: 'auth0|user-123', email: 'user@example.com' });

    const res = await worker.fetch(
      makeRequest('GET', '/v1/orgs/org-123/dashboard', { headers: { Authorization: `Bearer ${token}` } }),
      makeEnv(),
      ctx(),
    );
    await Promise.all(pending);

    expect(res.status).toBe(429);
    expect(captured).toHaveLength(0);
  });

  // A ledger failure must never surface to the caller: it is logged and the response is unchanged.
  it('keeps the response when the ledger insert fails', async () => {
    vi.spyOn(quotaLib, 'enforceOrgQuota').mockResolvedValue({ ok: true, rateLimitHeaders: {} });
    vi.stubGlobal('fetch', jwt.wrap((async () => new Response('unavailable', { status: 503 })) as unknown as typeof fetch));
    const token = await jwt.sign({ sub: 'auth0|user-123', email: 'user@example.com' });

    const res = await worker.fetch(
      makeRequest('GET', '/v1/orgs/org-123/entitlements', { headers: { Authorization: `Bearer ${token}` } }),
      makeEnv(),
      ctx(),
    );
    await Promise.all(pending);

    expect(res.status).not.toBe(429);
    expect(errorSpy).toHaveBeenCalledWith(expect.stringContaining('[usage-ledger]'), 'GET /v1/orgs/:id/entitlements', 'for org', 'org-123', expect.anything());
  });
});

// TS32: CR58's promise end to end. The tests above check the call into enforceOrgQuota;
// these run the real quota DO class over in-memory storage, so only Supabase is stubbed.
describe('an org that has used up its month (real quota DO)', () => {
  const ORG = 'org-month-used';
  const USER_ID = 'user-month-used';
  /** Starter's monthly limit in the DO's DEFAULT_QUOTAS. */
  const STARTER_MONTHLY_LIMIT = 10000;

  async function exhaustedQuotaDo(): Promise<DurableObjectNamespace> {
    const storage = new MockStorage();
    await storage.put('quota', {
      orgId: ORG, planKey: 'starter', quotaVersion: 1,
      minuteLimit: 60, monthlyLimit: STARTER_MONTHLY_LIMIT,
      minuteUsedAt: Date.now(), minuteUsed: 0,
      monthlyUsed: STARTER_MONTHLY_LIMIT, lastMonthlyResetAt: Date.now(), seenRequestIds: {},
    });
    const quotaDo = new QuotaDurableObject(stubDurableObjectState(storage));
    return { idFromName: (name: string) => name, get: () => quotaDo } as unknown as DurableObjectNamespace;
  }

  let token: string;

  beforeAll(async () => {
    token = await jwt.sign({ sub: 'auth0|month-used', email: 'owner@example.com' });
  });

  beforeEach(() => {
    vi.restoreAllMocks();
    resetOrgRateLimit();
    const stub = createSupabaseFetchStub({
      'GET users': okRows([{ id: USER_ID, email: 'owner@example.com' }]),
      'GET organization_memberships': okRows([
        { user_id: USER_ID, organization_id: ORG, role: 'owner', status: 'active' },
      ]),
      'GET organizations': okRows([{ id: ORG, current_plan: 'starter', quota_version: 1, billing_status: 'active' }]),
      'GET usage_buckets_daily': okRows([]),
      'POST usage_events': createdRows([]),
    });
    vi.stubGlobal('fetch', jwt.wrap(stub.fetch as typeof fetch));
  });

  afterEach(() => {
    resetOrgRateLimit();
    vi.unstubAllGlobals();
  });

  const get = async (subPath: string) => worker.fetch(
    makeRequest('GET', `/v1/orgs/${ORG}${subPath}`, { headers: { Authorization: `Bearer ${token}` } }),
    makeEnv({ QUOTA_DO: await exhaustedQuotaDo(), RATE_LIMIT_KV: mapKv() }),
  );

  it('can still read its usage summary', async () => {
    const res = await get('/usage/summary');
    expect(res.status).toBe(200);
  });

  it('is refused a charged route for the month', async () => {
    const res = await get('/dashboard');
    expect(res.status).toBe(429);
    expect((await res.json() as { error: { reason: string } }).error.reason).toBe('monthly_limit');
  });
});

// UA08: a valid credential from a different org must be refused before quota is consumed.
describe('UA08: cross-org access refused before quota', () => {
  beforeEach(() => {
    vi.restoreAllMocks();
  });
  afterEach(() => {
    vi.unstubAllGlobals();
  });

  it('returns 403 without consuming quota when an API key belongs to a different org', async () => {
    vi.spyOn(quotaLib, 'enforceOrgQuota').mockResolvedValue({ ok: true, rateLimitHeaders: {} });

    // A validly-formatted obtk_ token — the stub returns the canned row for any api_keys query.
    const apiKey = `obtk_${'a'.repeat(64)}`;

    const stub = createSupabaseFetchStub({
      'GET api_keys': okRows([{
        id: 'key-id-1',
        organization_id: 'org-a',
        user_id: 'user-id-1',
        hash: 'abc123',
        prefix: 'aaaaaaaa',
        status: 'active',
        revoked_at: null,
        expires_at: null,
        name: 'test',
        created_at: '2026-01-01T00:00:00Z',
        updated_at: '2026-01-01T00:00:00Z',
      }]),
    });
    vi.stubGlobal('fetch', jwt.wrap(stub.fetch as typeof fetch));

    // The key belongs to org-a; the URL targets org-b.
    const res = await worker.fetch(
      makeRequest('GET', '/v1/orgs/org-b/entitlements', {
        headers: { Authorization: `Bearer ${apiKey}` },
      }),
      makeEnv(),
    );

    expect(res.status).toBe(403);
    expect(quotaLib.enforceOrgQuota).not.toHaveBeenCalled();
  });

  it('returns 403 without consuming quota when a JWT user has no membership in the org', async () => {
    vi.spyOn(quotaLib, 'enforceOrgQuota').mockResolvedValue({ ok: true, rateLimitHeaders: {} });

    const token = await jwt.sign({ sub: 'auth0|user-123', email: 'user@example.com' });

    // User resolves, but has no membership in org-123.
    const stub = createSupabaseFetchStub({
      'GET users': okRows([{ id: 'user-uuid-1', email: 'user@example.com' }]),
      'GET organization_memberships': okRows([]),
    });
    vi.stubGlobal('fetch', jwt.wrap(stub.fetch as typeof fetch));

    const res = await worker.fetch(
      makeRequest('GET', '/v1/orgs/org-123/entitlements', {
        headers: { Authorization: `Bearer ${token}` },
      }),
      makeEnv(),
    );

    expect(res.status).toBe(403);
    expect(quotaLib.enforceOrgQuota).not.toHaveBeenCalled();
  });
});


// CR36: the per-org edge limit is only a control if the router applies it — after the
// caller is verified (so nobody can spend an org's budget without that org's credential)
// and before the quota DO (so it still caps a loop while the fail-open DO is down).
// Everything here is real except the three I/O edges: a Map-backed KV, a quota DO fake
// that records what it reserved, and the Supabase transport stub.
describe('CR36: per-org edge rate limit on org routes', () => {
  const ORIGIN = 'https://integritystudio.ai';
  const ORG = 'org-rl-1';
  const OTHER_ORG = 'org-rl-2';
  const USER_ROW = { id: 'user-uuid-rl', email: 'member@example.com' };

  let reserved: Map<string, number>;
  let kvStore: Map<string, string>;
  let isMember: boolean;
  let token: string;

  const jsonRows = (rows: unknown[]) =>
    new Response(JSON.stringify(rows), { status: 200, headers: { 'Content-Type': 'application/json' } });

  /** An env whose quota DO admits everything and records the units each org reserved. */
  const env = () => makeEnv({
    RATE_LIMIT_KV: mapKv(kvStore),
    QUOTA_DO: admittingQuotaDo((body) => reserved.set(body.orgId, (reserved.get(body.orgId) ?? 0) + body.units)),
  });

  function send(orgId: string, authorization: string | null, sharedEnv: Env): Promise<Response> {
    const headers: Record<string, string> = { Origin: ORIGIN };
    if (authorization) headers.Authorization = authorization;
    return worker.fetch(makeRequest('GET', `/v1/orgs/${orgId}/entitlements`, { headers }), sharedEnv);
  }

  async function sendMany(count: number, orgId: string, authorization: string | null, sharedEnv: Env): Promise<number[]> {
    const statuses: number[] = [];
    for (let i = 0; i < count; i++) statuses.push((await send(orgId, authorization, sharedEnv)).status);
    return statuses;
  }

  beforeEach(async () => {
    vi.restoreAllMocks();
    resetOrgRateLimit();
    reserved = new Map();
    kvStore = new Map();
    isMember = true;
    token = await jwt.sign({ sub: 'auth0|member', email: USER_ROW.email });
    const stub = createSupabaseFetchStub({
      'GET users': okRows([USER_ROW]),
      'GET organization_memberships': () => jsonRows(isMember ? [{ user_id: USER_ROW.id, organization_id: ORG, role: 'owner' }] : []),
      'GET organizations': okRows([{ id: ORG, current_plan: 'growth', quota_version: 0, billing_status: 'active' }]),
      'POST usage_events': createdRows([]),
    });
    vi.stubGlobal('fetch', jwt.wrap(stub.fetch as typeof fetch));
    vi.spyOn(console, 'error').mockImplementation(() => {});
  });

  afterEach(() => {
    resetOrgRateLimit();
    vi.unstubAllGlobals();
    vi.restoreAllMocks();
  });

  it('admits the limit, then answers 429 with Retry-After, CORS and security headers, without reaching the quota DO', async () => {
    const sharedEnv = env();
    const admitted = await sendMany(ORG_RATE_LIMIT_MAX, ORG, `Bearer ${token}`, sharedEnv);

    const res = await send(ORG, `Bearer ${token}`, sharedEnv);

    expect(admitted).not.toContain(429);
    expect(res.status).toBe(429);
    const retryAfter = Number(res.headers.get('Retry-After'));
    expect(Number.isInteger(retryAfter)).toBe(true);
    expect(retryAfter).toBeGreaterThanOrEqual(1);
    expect(retryAfter).toBeLessThanOrEqual(ORG_RATE_LIMIT_WINDOW_SECONDS);
    expect(res.headers.get('Access-Control-Allow-Origin')).toBe(ORIGIN);
    expect(res.headers.get('X-Content-Type-Options')).toBe('nosniff');
    expect(await res.json()).toEqual({ error: { message: 'Too Many Requests' } });
    expect(reserved.get(ORG)).toBe(ORG_RATE_LIMIT_MAX);
  });

  it('does not let unauthenticated requests spend an org\'s budget', async () => {
    const sharedEnv = env();
    const anonymous = await sendMany(ORG_RATE_LIMIT_MAX + 1, ORG, null, sharedEnv);

    const res = await send(ORG, `Bearer ${token}`, sharedEnv);

    expect(new Set(anonymous)).toEqual(new Set([401]));
    expect(res.status).not.toBe(429);
    expect(reserved.get(ORG)).toBe(1);
  });

  it('does not let a verified non-member spend an org\'s budget', async () => {
    const sharedEnv = env();
    isMember = false;
    const refused = await sendMany(ORG_RATE_LIMIT_MAX + 1, ORG, `Bearer ${token}`, sharedEnv);
    isMember = true;

    const res = await send(ORG, `Bearer ${token}`, sharedEnv);

    expect(new Set(refused)).toEqual(new Set([403]));
    expect(res.status).not.toBe(429);
    expect(reserved.get(ORG)).toBe(1);
  });

  it('gives each org its own budget', async () => {
    const sharedEnv = env();
    await sendMany(ORG_RATE_LIMIT_MAX + 1, ORG, `Bearer ${token}`, sharedEnv);

    const res = await send(OTHER_ORG, `Bearer ${token}`, sharedEnv);

    expect(res.status).not.toBe(429);
    expect(reserved.get(OTHER_ORG)).toBe(1);
  });

  it('keeps refusing in a fresh isolate, because the count lives in the bound KV namespace', async () => {
    const sharedEnv = env();
    await sendMany(ORG_RATE_LIMIT_MAX, ORG, `Bearer ${token}`, sharedEnv);
    resetOrgRateLimit(); // a new isolate: its in-memory windows start empty; KV does not

    const res = await send(ORG, `Bearer ${token}`, sharedEnv);

    expect(res.status).toBe(429);
    expect(reserved.get(ORG)).toBe(ORG_RATE_LIMIT_MAX);
  });
});

// CR43: usage_buckets_daily has one writer, the ledger trigger on usage_events.
describe('CR43: ingest leaves usage_buckets_daily to the ledger trigger', () => {
  const ORG_ID = '00000000-0000-4000-8000-000000000001';
  const USER_ID = '00000000-0000-4000-8000-000000000002';
  const BUCKETS_TABLE = 'usage_buckets_daily';

  afterEach(() => {
    vi.unstubAllGlobals();
  });

  it('writes the event and nothing to the daily buckets, including deferred work', async () => {
    // usage_events answers reads with a row, so a rollup that recounted the day would
    // reach its bucket upsert here rather than stop at an unstubbed read.
    const stub = createSupabaseFetchStub({
      'GET users': okRows([{ id: USER_ID }]),
      'GET organization_memberships': okRows([
        { organization_id: ORG_ID, user_id: USER_ID, role: 'owner', status: 'active' },
      ]),
      'POST usage_events': createdRows([{ id: 'evt-1' }]),
      'GET usage_events': okRows([
        { organization_id: ORG_ID, metric_key: 'api_requests', quantity: 1, latency_ms: null },
      ]),
    });
    vi.stubGlobal('fetch', jwt.wrap(stub.fetch));
    const pending: Promise<unknown>[] = [];
    const ctx = {
      waitUntil: (p: Promise<unknown>) => { pending.push(p); },
      passThroughOnException: () => {},
    } as unknown as ExecutionContext;
    const token = await jwt.sign({ sub: 'auth0|user-123', email: 'user@example.com' });

    const res = await worker.fetch(
      makeRequest('POST', '/v1/ingest/events', {
        headers: { Authorization: `Bearer ${token}`, 'Content-Type': 'application/json' },
        body: JSON.stringify({ org_id: ORG_ID, metric_key: 'api_requests' }),
      }),
      makeEnv(),
      ctx,
    );
    await Promise.allSettled(pending);

    expect(res.status).toBe(202);
    expect(stub.findAll('POST', 'usage_events')).toHaveLength(1);
    expect(stub.requests.filter((r) => r.table === BUCKETS_TABLE).map((r) => r.method)).toEqual([]);
  });
});

describe('CR40: /v1/auth0-logs is dispatched with the stream token', () => {
  afterEach(() => {
    vi.unstubAllGlobals();
  });

  it('refuses a delivery without the token and accepts one with it', async () => {
    const STREAM_TOKEN = 'stream-token-0123456789abcdef';
    const stub = createSupabaseFetchStub({ 'POST auth0_logs': createdRows([]) });
    vi.stubGlobal('fetch', stub.fetch);
    const body = JSON.stringify([
      { log_id: 'log-1', data: { date: '2026-09-28T12:00:00.000Z', type: 's' } },
    ]);
    const deliver = (authorization?: string) => worker.fetch(
      makeRequest('POST', '/v1/auth0-logs', {
        headers: { 'Content-Type': 'application/json', ...(authorization ? { Authorization: authorization } : {}) },
        body,
      }),
      makeEnv({ AUTH0_LOG_STREAM_TOKEN: STREAM_TOKEN }),
    );

    expect((await deliver()).status).toBe(401);
    expect(stub.requests).toHaveLength(0);
    expect((await deliver(`Bearer ${STREAM_TOKEN}`)).status).toBe(200);
    expect(stub.findAll('POST', 'auth0_logs')).toHaveLength(1);
  });
});

describe('scheduled: the Auth0 log poller', () => {
  it('throws when the poller fails, so the cron invocation records an error', async () => {
    const ctx = { waitUntil: () => {}, passThroughOnException: () => {} } as unknown as ExecutionContext;

    await expect(
      worker.scheduled({} as ScheduledEvent, makeEnv(), ctx),
    ).rejects.toThrow('AUTH0_LOG_READER_CLIENT_ID/SECRET not bound');
  });
});

// TS23: router-level dispatch test. Each of these paths had zero hits under
// coverage — the handlers were unit-tested in isolation but the routing lines
// in index.ts were never exercised. A typo in a path string or method would
// silently ship green.
//
// Strategy: every request here is authenticated (JWT + user + membership for
// org routes; none for /v1/auth0-logs, which answers 503 here because makeEnv
// binds no AUTH0_LOG_STREAM_TOKEN — still not the fall-through). The quota DO is faked to admit
// everything. The assertion is that the response is not the router's
// fall-through 404 — that proves dispatch reached the handler without requiring
// each handler to return a predictable result against an unreachable Supabase /
// Stripe. The fall-through is matched on body `error.message`, and a positive
// control pins that shape.
describe('TS23: all registered routes are dispatched (not 404)', () => {
  const ORG = 'org-dispatch-test';

  let token: string;

  beforeAll(async () => {
    token = await jwt.sign({ sub: 'auth0|dispatch-user', email: 'member@example.com' });
  });

  beforeEach(() => {
    vi.restoreAllMocks();
    resetOrgRateLimit();
    const stub = createSupabaseFetchStub({
      'GET users': okRows([{ id: 'user-dispatch', email: 'member@example.com' }]),
      'GET organization_memberships': okRows([
        { user_id: 'user-dispatch', organization_id: ORG, role: 'owner', status: 'active' },
      ]),
    });
    vi.stubGlobal('fetch', jwt.wrap(stub.fetch as typeof fetch));
    vi.spyOn(console, 'error').mockImplementation(() => {});
    vi.spyOn(console, 'warn').mockImplementation(() => {});
  });

  afterEach(() => {
    resetOrgRateLimit();
    vi.unstubAllGlobals();
    vi.restoreAllMocks();
  });

  const authHeader = () => ({ Authorization: `Bearer ${token}` });
  const env = () => makeEnv({ QUOTA_DO: admittingQuotaDo(), RATE_LIMIT_KV: mapKv() });

  /** The router's fall-through answer (`index.ts`); every handler 404 carries its own message. */
  const ROUTER_NOT_FOUND_MESSAGE = 'Not found';

  async function isRouterFallThrough(res: Response): Promise<boolean> {
    const body = await res.clone().json().catch(() => ({})) as { error?: { message?: unknown } };
    return res.status === 404 && body.error?.message === ROUTER_NOT_FOUND_MESSAGE;
  }

  // Positive control: without it, a change to the fall-through's shape or message
  // would make every assertion below pass without testing anything.
  it.each([
    ['GET',  `/v1/orgs/${ORG}/not-a-route`],
    ['POST', '/not-a-route'],
  ] as const)('control: unregistered %s %s gets the router fall-through', async (method, path) => {
    const res = await worker.fetch(makeRequest(method, path, { headers: authHeader() }), env());
    expect(await isRouterFallThrough(res)).toBe(true);
  });

  // TS31: a sub-path no route serves is answered before the quota DO, so it spends nothing
  // and the DO charges nothing the ledger will not record.
  it.each([
    ['GET',  `/v1/orgs/${ORG}/not-a-route`],
    ['GET',  `/v1/orgs/${ORG}/usage/summary/`],
    ['GET',  `/v1/orgs/${ORG}`],
    ['POST', `/v1/orgs/${ORG}/usage/summary`],
    ['GET',  `/v1/orgs/${ORG}/api-keys/key-abc123/revoke`],
  ] as const)('%s %s gets the fall-through without reaching the quota DO', async (method, path) => {
    const reserved: unknown[] = [];
    const res = await worker.fetch(
      makeRequest(method, path, { headers: authHeader() }),
      makeEnv({ QUOTA_DO: admittingQuotaDo((body) => reserved.push(body)), RATE_LIMIT_KV: mapKv() }),
    );

    expect(await isRouterFallThrough(res)).toBe(true);
    expect(reserved).toHaveLength(0);
  });

  // Control for the rows above: the revoke pattern is routed outside ORG_ROUTES, and a
  // routed request does reach the DO.
  it('POST .../api-keys/:id/revoke still reaches the quota DO', async () => {
    const reserved: unknown[] = [];
    await worker.fetch(
      makeRequest('POST', `/v1/orgs/${ORG}/api-keys/key-abc123/revoke`, { headers: authHeader() }),
      makeEnv({ QUOTA_DO: admittingQuotaDo((body) => reserved.push(body)), RATE_LIMIT_KV: mapKv() }),
    );

    expect(reserved).toHaveLength(1);
  });

  it('refuses an unauthenticated request to an unrouted sub-path with 401, not 404', async () => {
    const res = await worker.fetch(makeRequest('GET', `/v1/orgs/${ORG}/not-a-route`), env());
    expect(res.status).toBe(401);
  });

  // Every fixed route in ORG_ROUTES (org-routes.ts) has a row, plus the revoke pattern.
  it.each([
    ['GET',  `/v1/orgs/${ORG}/dashboard`],
    ['GET',  `/v1/orgs/${ORG}/billing-status`],
    ['GET',  `/v1/orgs/${ORG}/usage/summary`],
    ['GET',  `/v1/orgs/${ORG}/entitlements`],
    ['GET',  `/v1/orgs/${ORG}/quota/status`],
    ['POST', `/v1/orgs/${ORG}/billing-portal`],
    ['POST', `/v1/orgs/${ORG}/checkout-session`],
    ['POST', `/v1/orgs/${ORG}/api-keys`],
    ['POST', `/v1/orgs/${ORG}/api-keys/key-abc123/revoke`],
  ] as const)('%s %s reaches a handler, not the terminal 404', async (method, path) => {
    const res = await worker.fetch(
      makeRequest(method, path, { headers: authHeader() }),
      env(),
    );
    // A handler 404 ("API key not found", etc.) is a successful dispatch.
    expect(await isRouterFallThrough(res)).toBe(false);
  });

  it('POST /bootstrap reaches its handler, not the terminal 404', async () => {
    const res = await worker.fetch(
      makeRequest('POST', '/bootstrap', {
        headers: { ...authHeader(), 'Content-Type': 'application/json' },
        body: JSON.stringify({ email: 'new@example.com' }),
      }),
      env(),
    );
    expect(await isRouterFallThrough(res)).toBe(false);
  });

  it('POST /v1/auth0-logs reaches its handler, not the terminal 404', async () => {
    const res = await worker.fetch(
      makeRequest('POST', '/v1/auth0-logs', {
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify([]),
      }),
      env(),
    );
    expect(await isRouterFallThrough(res)).toBe(false);
  });

  // ADMIN-CV-GATEWAY-READ: the staff directory and the four staff twins are dispatched.
  it.each([
    ['GET', '/v1/admin/orgs'],
    ...Object.values(ADMIN_ORG_ROUTES).map((r) => [r.method, `/v1/admin/orgs/${ORG}${r.subPath}`] as const),
  ] as const)('%s %s reaches a handler, not the terminal 404', async (method, path) => {
    const res = await worker.fetch(makeRequest(method, path, { headers: authHeader() }), env());
    expect(await isRouterFallThrough(res)).toBe(false);
  });

  it.each([
    ['GET', `/v1/admin/orgs/${ORG}/not-a-route`],
    ['GET', `/v1/admin/orgs/${ORG}`],
    ['POST', `/v1/admin/orgs/${ORG}/usage/summary`],
    ['POST', '/v1/admin/orgs'],
  ] as const)('%s %s gets the router fall-through', async (method, path) => {
    const res = await worker.fetch(makeRequest(method, path, { headers: authHeader() }), env());
    expect(await isRouterFallThrough(res)).toBe(true);
  });
});

/**
 * ADMIN-CV-GATEWAY-READ's hard requirements, at the router: a staff read of an org reserves
 * no quota, takes no per-org rate limit, writes no `usage_events` row, and a non-staff
 * caller — an org owner included — gets 403 with none of that touched either.
 */
describe('ADMIN-CV-GATEWAY-READ: staff reads are unmetered', () => {
  const ORG = 'org-admin-read';
  const STAFF_SUB = 'auth0|staff-user';
  const STAFF_USER_ID = 'user-staff';
  const OWNER_SUB = 'auth0|owner-user';
  const OWNER_USER_ID = 'user-owner';

  let staffToken: string;
  let ownerToken: string;
  let reserved: unknown[];
  let ledgerRows: unknown[];
  let auditRows: Array<{ action: string; target_id: string }>;
  let pending: Promise<unknown>[];

  const ctx = () => ({
    waitUntil: (p: Promise<unknown>) => { pending.push(p); },
    passThroughOnException: () => {},
  }) as unknown as ExecutionContext;

  const env = () => makeEnv({
    STAFF_USER_IDS: JSON.stringify([STAFF_USER_ID]),
    QUOTA_DO: admittingQuotaDo((body) => reserved.push(body)),
    RATE_LIMIT_KV: mapKv(),
  });

  beforeAll(async () => {
    staffToken = await jwt.sign({ sub: STAFF_SUB, email: 'staff@example.com' });
    ownerToken = await jwt.sign({ sub: OWNER_SUB, email: 'owner@example.com' });
  });

  beforeEach(() => {
    vi.restoreAllMocks();
    resetOrgRateLimit();
    resetIdentityRateLimit();
    resetAdminViewAudit();
    reserved = [];
    ledgerRows = [];
    auditRows = [];
    pending = [];
    const stub = createSupabaseFetchStub({
      'GET users': (req) => {
        const sub = req.url.searchParams.get('auth0_id');
        const row = sub === `eq.${STAFF_SUB}` ? { id: STAFF_USER_ID } : sub === `eq.${OWNER_SUB}` ? { id: OWNER_USER_ID } : null;
        return new Response(JSON.stringify(row ? [row] : []), { status: 200, headers: { 'content-type': 'application/json' } });
      },
      'GET organization_memberships': okRows([{ user_id: OWNER_USER_ID, organization_id: ORG, role: 'owner', status: 'active' }]),
      'GET organizations': okRows([{ id: ORG, name: 'Admin Read Org', slug: 'admin-read', billing_status: 'active', current_plan: 'growth', quota_version: 1, stripe_customer_id: null }]),
      'GET usage_buckets_daily': okRows([]),
      'GET entitlements': okRows([]),
      'GET plans': okRows([]),
      'POST usage_events': (req) => { ledgerRows.push(req.body); return new Response('[]', { status: 201 }); },
      'POST audit_log': (req) => { auditRows.push(...(req.body as typeof auditRows)); return new Response('[]', { status: 201 }); },
    });
    vi.stubGlobal('fetch', jwt.wrap(stub.fetch as typeof fetch));
    vi.spyOn(console, 'error').mockImplementation(() => {});
    vi.spyOn(console, 'warn').mockImplementation(() => {});
  });

  afterEach(() => {
    resetOrgRateLimit();
    resetIdentityRateLimit();
    resetAdminViewAudit();
    vi.unstubAllGlobals();
    vi.restoreAllMocks();
  });

  const read = (path: string, token: string) =>
    worker.fetch(makeRequest('GET', path, { headers: { Authorization: `Bearer ${token}` } }), env(), ctx());

  it.each(Object.values(ADMIN_ORG_ROUTES).map((r) => r.subPath))(
    'a staff read of %s is 200 with no quota reservation, no org rate limit entry and no ledger row',
    async (subPath) => {
      const enforce = vi.spyOn(quotaLib, 'enforceOrgQuota');
      const sharedEnv = env();
      const kvStore = (sharedEnv.RATE_LIMIT_KV as unknown as { get: (k: string) => Promise<unknown> });

      const res = await worker.fetch(
        makeRequest('GET', `/v1/admin/orgs/${ORG}${subPath}`, { headers: { Authorization: `Bearer ${staffToken}` } }),
        sharedEnv,
        ctx(),
      );
      await Promise.all(pending);

      expect(res.status).toBe(200);
      expect(enforce).not.toHaveBeenCalled();
      expect(reserved).toHaveLength(0);
      expect(ledgerRows).toHaveLength(0);
      expect(await kvStore.get(`gw_org_rl:${ORG}`)).toBeNull();
      expect(res.headers.get('X-RateLimit-Remaining-Minute')).toBeNull();
    },
  );

  it('ten staff reads of one org reserve nothing and write no ledger row', async () => {
    for (let i = 0; i < 10; i++) {
      expect((await read(`/v1/admin/orgs/${ORG}/usage/summary`, staffToken)).status).toBe(200);
    }
    await Promise.all(pending);
    expect(reserved).toHaveLength(0);
    expect(ledgerRows).toHaveLength(0);
  });

  it('ten staff reads of one org write one audit row', async () => {
    for (let i = 0; i < 10; i++) await read(`/v1/admin/orgs/${ORG}/usage/summary`, staffToken);
    await Promise.all(pending);
    expect(auditRows.filter((r) => r.action === 'admin.org_viewed').map((r) => r.target_id)).toEqual([ORG]);
  });

  it('refuses the org owner with 403 and touches neither quota nor ledger', async () => {
    const res = await read(`/v1/admin/orgs/${ORG}/billing-status`, ownerToken);
    await Promise.all(pending);
    expect(res.status).toBe(403);
    expect(reserved).toHaveLength(0);
    expect(ledgerRows).toHaveLength(0);
    expect(auditRows).toHaveLength(0);
  });

  it('refuses everyone when STAFF_USER_IDS is unset', async () => {
    const res = await worker.fetch(
      makeRequest('GET', `/v1/admin/orgs/${ORG}/billing-status`, { headers: { Authorization: `Bearer ${staffToken}` } }),
      makeEnv({ QUOTA_DO: admittingQuotaDo(), RATE_LIMIT_KV: mapKv() }),
    );
    expect(res.status).toBe(403);
  });

  // The dashboard calls these cross-origin with an Authorization header, so the preflight
  // and the error responses must carry CORS like every other route (ADMIN-CV-CORS-AUDIENCE).
  it('answers a preflight and carries CORS on a refusal', async () => {
    const origin = 'https://integritystudio.dev';
    const preflight = await worker.fetch(
      makeRequest('OPTIONS', `/v1/admin/orgs/${ORG}/billing-status`, {
        headers: { Origin: origin, 'Access-Control-Request-Method': 'GET', 'Access-Control-Request-Headers': 'authorization' },
      }),
      env(),
    );
    expect(preflight.status).toBe(204);
    expect(preflight.headers.get('Access-Control-Allow-Origin')).toBe(origin);

    const refused = await worker.fetch(
      makeRequest('GET', `/v1/admin/orgs/${ORG}/billing-status`, { headers: { Origin: origin, Authorization: `Bearer ${ownerToken}` } }),
      env(),
    );
    expect(refused.status).toBe(403);
    expect(refused.headers.get('Access-Control-Allow-Origin')).toBe(origin);
    expect(refused.headers.get('Cache-Control')).toBe('no-store');
  });
});
