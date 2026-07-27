import { describe, it, expect, vi, afterEach } from 'vitest';
import { handleUsageSummary, handleOrgEntitlements, handleQuotaStatus } from './usage';
import { hashApiKeySecret } from '../../../lib/api-keys';
import {
  createSupabaseFetchStub,
  httpError,
  okRows,
  TEST_SERVICE_ROLE_KEY,
  TEST_SUPABASE_URL,
  type RouteResponder,
  type SupabaseFetchStub,
} from '../../../lib/test-helpers/supabase-fetch-stub';

const JWT_SECRET = 'test-jwt-secret-at-least-32-chars!!';
const HMAC_SECRET = 'test-hmac-secret-at-least-32-chars!';

const ORG_ID = 'org-id-1';
const USER_ID = 'user-id-1';
const API_KEY_PREFIX = 'abc12345';
const API_KEY_SECRET = 'testsecret32charsminimumvalue000';
const API_KEY_TOKEN = `int_live_${API_KEY_PREFIX}_${API_KEY_SECRET}`;

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

const opts = {
  jwtSecret: JWT_SECRET,
  hmacSecret: HMAC_SECRET,
  supabaseUrl: TEST_SUPABASE_URL,
  serviceRoleKey: TEST_SERVICE_ROLE_KEY,
};

const makeMembership = (orgId = ORG_ID, role = 'owner') => ({
  organization_id: orgId,
  user_id: USER_ID,
  role,
  status: 'active',
});

const makeApiKeyRow = async (orgId = ORG_ID, prefix = API_KEY_PREFIX, secret = API_KEY_SECRET) => ({
  id: 'key-id-1',
  user_id: USER_ID,
  organization_id: orgId,
  prefix,
  hash: await hashApiKeySecret(secret, HMAC_SECRET),
  name: 'Default',
  tier: 'starter',
  status: 'active',
  expires_at: null,
  last_used_at: null,
  created_at: '2026-01-01T00:00:00Z',
  revoked_at: null,
});

/** Installs the stub as global fetch and returns it for assertions. */
function stubSupabase(routes: Record<string, RouteResponder>): SupabaseFetchStub {
  const stub = createSupabaseFetchStub(routes);
  vi.stubGlobal('fetch', stub.fetch);
  return stub;
}

const membershipRoute = (memberships = [makeMembership()]): Record<string, RouteResponder> => ({
  'GET organization_memberships': okRows(memberships),
});

const apiKeyRoute = async (row?: Record<string, unknown>): Promise<Record<string, RouteResponder>> => ({
  'GET api_keys': okRows([row ?? await makeApiKeyRow()]),
});

const makeJwtRequest = async (path: string) => {
  const token = await makeJwt({ sub: USER_ID, email: 'u@test.com' }, JWT_SECRET);
  return new Request(`https://api.test${path}`, {
    method: 'GET',
    headers: { authorization: `Bearer ${token}` },
  });
};

const makeApiKeyRequest = (path: string) =>
  new Request(`https://api.test${path}`, {
    method: 'GET',
    headers: { authorization: `Bearer ${API_KEY_TOKEN}` },
  });

afterEach(() => {
  vi.unstubAllGlobals();
});

describe('GET /v1/orgs/:orgId/usage/summary', () => {
  const PATH = `/v1/orgs/${ORG_ID}/usage/summary`;

  it('returns 401 when no auth', async () => {
    const stub = stubSupabase({});
    const req = new Request(`https://api.test${PATH}`, { method: 'GET' });
    const res = await handleUsageSummary(req, ORG_ID, opts);
    expect(res.status).toBe(401);
    expect(stub.requests).toHaveLength(0);
  });

  it('returns 403 when JWT user is not a member', async () => {
    const stub = stubSupabase(membershipRoute([]));
    const res = await handleUsageSummary(await makeJwtRequest(PATH), ORG_ID, opts);
    expect(res.status).toBe(403);
    expect(stub.findAll('GET', 'usage_buckets_daily')).toHaveLength(0);
  });

  it('returns usage summary for JWT-authenticated member', async () => {
    const usageBuckets = [
      { organization_id: ORG_ID, bucket_date: '2026-03-01', metric_key: 'requests', total_quantity: 1234, request_count: 100, avg_latency_ms: 45 },
    ];
    const stub = stubSupabase({
      ...membershipRoute(),
      'GET usage_buckets_daily': okRows(usageBuckets),
    });

    const res = await handleUsageSummary(await makeJwtRequest(PATH), ORG_ID, opts);
    expect(res.status).toBe(200);
    const body = await res.json() as { org_id: string; period_start: string; buckets: { total_quantity: number }[] };
    expect(body.org_id).toBe(ORG_ID);
    expect(body.buckets).toHaveLength(1);
    expect(body.buckets[0].total_quantity).toBe(1234);

    const memberParams = stub.find('GET', 'organization_memberships')!.url.searchParams;
    expect(memberParams.get('user_id')).toBe(`eq.${USER_ID}`);
    expect(memberParams.get('organization_id')).toBe(`eq.${ORG_ID}`);
    expect(memberParams.get('status')).toBe('eq.active');
    expect(memberParams.get('limit')).toBe('1');

    const bucketParams = stub.find('GET', 'usage_buckets_daily')!.url.searchParams;
    expect(bucketParams.get('organization_id')).toBe(`eq.${ORG_ID}`);
    expect(bucketParams.get('bucket_date')).toBe(`gte.${body.period_start}`);
    expect(bucketParams.get('order')).toBe('bucket_date.desc');
    expect(bucketParams.get('select')).toContain('total_quantity');
  });

  it('returns usage summary for valid API key', async () => {
    const usageBuckets = [
      { organization_id: ORG_ID, bucket_date: '2026-03-01', metric_key: 'requests', total_quantity: 999, request_count: 50, avg_latency_ms: 30 },
    ];
    const stub = stubSupabase({
      ...(await apiKeyRoute()),
      'GET usage_buckets_daily': okRows(usageBuckets),
    });

    const res = await handleUsageSummary(makeApiKeyRequest(PATH), ORG_ID, opts);
    expect(res.status).toBe(200);

    const keyParams = stub.find('GET', 'api_keys')!.url.searchParams;
    expect(keyParams.get('prefix')).toBe(`eq.${API_KEY_PREFIX}`);
    expect(keyParams.get('limit')).toBe('1');
    // API keys carry their own org, so no membership lookup is needed.
    expect(stub.findAll('GET', 'organization_memberships')).toHaveLength(0);
  });

  it('returns 403 when API key belongs to different org', async () => {
    const stub = stubSupabase(await apiKeyRoute(await makeApiKeyRow('other-org-id')));
    const res = await handleUsageSummary(makeApiKeyRequest(PATH), ORG_ID, opts);
    expect(res.status).toBe(403);
    expect(stub.findAll('GET', 'usage_buckets_daily')).toHaveLength(0);
  });

  it('returns 200 with empty buckets when the usage query fails', async () => {
    stubSupabase({
      ...membershipRoute(),
      'GET usage_buckets_daily': httpError(500, 'DB error'),
    });
    const res = await handleUsageSummary(await makeJwtRequest(PATH), ORG_ID, opts);
    expect(res.status).toBe(200);
    const body = await res.json() as { buckets: unknown[] };
    expect(body.buckets).toEqual([]);
  });
});

describe('GET /v1/orgs/:orgId/entitlements', () => {
  const PATH = `/v1/orgs/${ORG_ID}/entitlements`;

  it('returns 401 when no auth', async () => {
    const stub = stubSupabase({});
    const req = new Request(`https://api.test${PATH}`, { method: 'GET' });
    const res = await handleOrgEntitlements(req, ORG_ID, opts);
    expect(res.status).toBe(401);
    expect(stub.requests).toHaveLength(0);
  });

  it('returns entitlements map for JWT-authenticated member', async () => {
    const entitlements = [
      { organization_id: ORG_ID, feature_key: 'usage_dashboard', enabled: true, hard_limit: null, soft_limit: null },
      { organization_id: ORG_ID, feature_key: 'monthly_units', enabled: true, hard_limit: 500000, soft_limit: null },
      { organization_id: ORG_ID, feature_key: 'alerts', enabled: false, hard_limit: null, soft_limit: null },
    ];
    const stub = stubSupabase({
      ...membershipRoute(),
      'GET entitlements': okRows(entitlements),
    });

    const res = await handleOrgEntitlements(await makeJwtRequest(PATH), ORG_ID, opts);
    expect(res.status).toBe(200);
    const body = await res.json() as { entitlements: Record<string, boolean | number | null> };
    expect(body.entitlements.usage_dashboard).toBe(true);
    expect(body.entitlements.monthly_units).toBe(500000);
    expect(body.entitlements.alerts).toBe(false);

    const entParams = stub.find('GET', 'entitlements')!.url.searchParams;
    expect(entParams.get('organization_id')).toBe(`eq.${ORG_ID}`);
  });

  it('returns 403 when JWT user is not a member', async () => {
    const stub = stubSupabase(membershipRoute([]));
    const res = await handleOrgEntitlements(await makeJwtRequest(PATH), ORG_ID, opts);
    expect(res.status).toBe(403);
    expect(stub.findAll('GET', 'entitlements')).toHaveLength(0);
  });

  it('returns 403 when API key belongs to different org', async () => {
    const stub = stubSupabase(await apiKeyRoute(await makeApiKeyRow('other-org-id')));
    const res = await handleOrgEntitlements(makeApiKeyRequest(PATH), ORG_ID, opts);
    expect(res.status).toBe(403);
    expect(stub.findAll('GET', 'entitlements')).toHaveLength(0);
  });

  it('returns an empty entitlements map when the entitlements query fails', async () => {
    stubSupabase({
      ...membershipRoute(),
      'GET entitlements': httpError(500, 'DB error'),
    });
    const res = await handleOrgEntitlements(await makeJwtRequest(PATH), ORG_ID, opts);
    expect(res.status).toBe(200);
    const body = await res.json() as { entitlements: Record<string, unknown> };
    expect(body.entitlements).toEqual({});
  });
});

describe('GET /v1/orgs/:orgId/quota/status', () => {
  const PATH = `/v1/orgs/${ORG_ID}/quota/status`;

  const makeQuotaOpts = (doOverride?: DurableObjectNamespace) => ({
    ...opts,
    doNamespace: doOverride ?? {} as DurableObjectNamespace,
  });

  const makeDoNamespace = (statusPayload: unknown) => ({
    idFromName: vi.fn().mockReturnValue('stub-id'),
    get: vi.fn().mockReturnValue({
      fetch: vi.fn().mockResolvedValue(
        new Response(JSON.stringify(statusPayload), { status: 200 }),
      ),
    }),
  } as unknown as DurableObjectNamespace);

  it('returns 401 when no auth', async () => {
    const stub = stubSupabase({});
    const req = new Request(`https://api.test${PATH}`, { method: 'GET' });
    const res = await handleQuotaStatus(req, ORG_ID, makeQuotaOpts());
    expect(res.status).toBe(401);
    expect(stub.requests).toHaveLength(0);
  });

  it('returns 403 when JWT user is not a member', async () => {
    stubSupabase(membershipRoute([]));
    const res = await handleQuotaStatus(await makeJwtRequest(PATH), ORG_ID, makeQuotaOpts());
    expect(res.status).toBe(403);
  });

  it('returns quota status for JWT-authenticated member', async () => {
    const stub = stubSupabase(membershipRoute());
    const quotaPayload = {
      orgId: ORG_ID,
      planKey: 'growth',
      quotaVersion: 2,
      minuteLimit: 60,
      monthlyLimit: 500000,
      minuteUsed: 5,
      monthlyUsed: 12345,
      minuteWindowExpiresIn: 45000,
    };
    const res = await handleQuotaStatus(
      await makeJwtRequest(PATH), ORG_ID, makeQuotaOpts(makeDoNamespace(quotaPayload)),
    );
    expect(res.status).toBe(200);
    const body = await res.json() as {
      org_id: string;
      minuteLimit: number;
      minuteUsed: number;
      monthlyLimit: number | null;
      monthlyUsed: number;
      minuteWindowExpiresIn: number;
    };
    expect(body.org_id).toBe(ORG_ID);
    expect(body.minuteLimit).toBe(60);
    expect(body.minuteUsed).toBe(5);
    expect(body.monthlyLimit).toBe(500000);
    expect(body.monthlyUsed).toBe(12345);
    expect(body.minuteWindowExpiresIn).toBe(45000);
    // Quota lives in the DO: membership is the only database round-trip.
    expect(stub.requests).toHaveLength(1);
  });

  it('returns uninitialized status when DO is unavailable', async () => {
    stubSupabase(membershipRoute());
    const throwingDo = {
      idFromName: vi.fn().mockReturnValue('stub-id'),
      get: vi.fn().mockReturnValue({
        fetch: vi.fn().mockRejectedValue(new Error('DO unavailable')),
      }),
    } as unknown as DurableObjectNamespace;
    const res = await handleQuotaStatus(
      await makeJwtRequest(PATH), ORG_ID, makeQuotaOpts(throwingDo),
    );
    expect(res.status).toBe(200);
    const body = await res.json() as { status: string };
    expect(body.status).toBe('uninitialized');
  });

  it('returns quota status with null monthlyLimit for unlimited plan', async () => {
    stubSupabase(membershipRoute());
    const quotaPayload = {
      orgId: ORG_ID,
      planKey: 'enterprise',
      quotaVersion: 1,
      minuteLimit: 120,
      monthlyLimit: null,
      minuteUsed: 0,
      monthlyUsed: 0,
      minuteWindowExpiresIn: 60000,
    };
    const res = await handleQuotaStatus(
      await makeJwtRequest(PATH), ORG_ID, makeQuotaOpts(makeDoNamespace(quotaPayload)),
    );
    expect(res.status).toBe(200);
    const body = await res.json() as { monthlyLimit: number | null; minuteLimit: number };
    expect(body.monthlyLimit).toBeNull();
    expect(body.minuteLimit).toBe(120);
  });
});
