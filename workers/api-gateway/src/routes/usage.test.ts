import { describe, it, expect, vi } from 'vitest';
import { handleUsageSummary, handleOrgEntitlements, handleQuotaStatus } from './usage';
import { hashApiKeySecret } from '../../../lib/api-keys';

const JWT_SECRET = 'test-jwt-secret-at-least-32-chars!!';
const HMAC_SECRET = 'test-hmac-secret-at-least-32-chars!';

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

const makeOpts = (sbOverride: any) => ({
  jwtSecret: JWT_SECRET,
  hmacSecret: HMAC_SECRET,
  supabaseUrl: 'https://test.supabase.co',
  serviceRoleKey: 'key',
  _sbOverride: sbOverride,
});

const makeMembership = (orgId = 'org-id-1', role = 'owner') => ({
  organization_id: orgId,
  user_id: 'user-id-1',
  role,
  status: 'active',
});

const makeApiKeyRow = async (orgId = 'org-id-1', prefix = 'abc12345', secret = 'testsecret32charsminimumvalue000') => ({
  id: 'key-id-1',
  user_id: 'user-id-1',
  organization_id: orgId,
  prefix,
  hash: await hashApiKeySecret(secret, HMAC_SECRET),
  name: 'Default',
  tier: 'free',
  status: 'active',
  expires_at: null,
  last_used_at: null,
  created_at: '2026-01-01T00:00:00Z',
  revoked_at: null,
});

describe('GET /v1/orgs/:orgId/usage/summary', () => {
  it('returns 401 when no auth', async () => {
    const req = new Request('https://api.test/v1/orgs/org-id-1/usage/summary', { method: 'GET' });
    const res = await handleUsageSummary(req, 'org-id-1', makeOpts(null));
    expect(res.status).toBe(401);
  });

  it('returns 403 when JWT user is not a member', async () => {
    const token = await makeJwt({ sub: 'user-id-1', email: 'u@test.com' }, JWT_SECRET);
    const mockSb = {
      query: vi.fn().mockResolvedValueOnce({ ok: true, data: [] }),
      insert: vi.fn(), update: vi.fn(), rpc: vi.fn(),
    };
    const req = new Request('https://api.test/v1/orgs/org-id-1/usage/summary', {
      method: 'GET',
      headers: { authorization: `Bearer ${token}` },
    });
    const res = await handleUsageSummary(req, 'org-id-1', makeOpts(mockSb));
    expect(res.status).toBe(403);
  });

  it('returns usage summary for JWT-authenticated member', async () => {
    const token = await makeJwt({ sub: 'user-id-1', email: 'u@test.com' }, JWT_SECRET);
    const usageBuckets = [
      { organization_id: 'org-id-1', bucket_date: '2026-03-01', metric_key: 'requests', total_quantity: 1234, request_count: 100, avg_latency_ms: 45 },
    ];

    const mockSb = {
      query: vi.fn()
        .mockResolvedValueOnce({ ok: true, data: [makeMembership()] })
        .mockResolvedValueOnce({ ok: true, data: usageBuckets }),
      insert: vi.fn(), update: vi.fn(), rpc: vi.fn(),
    };
    const req = new Request('https://api.test/v1/orgs/org-id-1/usage/summary', {
      method: 'GET',
      headers: { authorization: `Bearer ${token}` },
    });
    const res = await handleUsageSummary(req, 'org-id-1', makeOpts(mockSb));
    expect(res.status).toBe(200);
    const body = await res.json() as any;
    expect(body.org_id).toBe('org-id-1');
    expect(body.buckets).toHaveLength(1);
    expect(body.buckets[0].total_quantity).toBe(1234);
  });

  it('returns usage summary for valid API key', async () => {
    const secret = 'testsecret32charsminimumvalue000';
    const apiKeyRow = await makeApiKeyRow();
    const usageBuckets = [
      { organization_id: 'org-id-1', bucket_date: '2026-03-01', metric_key: 'requests', total_quantity: 999, request_count: 50, avg_latency_ms: 30 },
    ];

    const mockSb = {
      query: vi.fn()
        .mockResolvedValueOnce({ ok: true, data: [apiKeyRow] })
        .mockResolvedValueOnce({ ok: true, data: usageBuckets }),
      insert: vi.fn(), update: vi.fn(), rpc: vi.fn(),
    };
    const req = new Request('https://api.test/v1/orgs/org-id-1/usage/summary', {
      method: 'GET',
      headers: { authorization: `Bearer int_live_abc12345_${secret}` },
    });
    const res = await handleUsageSummary(req, 'org-id-1', makeOpts(mockSb));
    expect(res.status).toBe(200);
  });

  it('returns 403 when API key belongs to different org', async () => {
    const secret = 'testsecret32charsminimumvalue000';
    const apiKeyRow = await makeApiKeyRow('other-org-id');

    const mockSb = {
      query: vi.fn().mockResolvedValueOnce({ ok: true, data: [apiKeyRow] }),
      insert: vi.fn(), update: vi.fn(), rpc: vi.fn(),
    };
    const req = new Request('https://api.test/v1/orgs/org-id-1/usage/summary', {
      method: 'GET',
      headers: { authorization: `Bearer int_live_abc12345_${secret}` },
    });
    const res = await handleUsageSummary(req, 'org-id-1', makeOpts(mockSb));
    expect(res.status).toBe(403);
  });
});

describe('GET /v1/orgs/:orgId/entitlements', () => {
  it('returns 401 when no auth', async () => {
    const req = new Request('https://api.test/v1/orgs/org-id-1/entitlements', { method: 'GET' });
    const res = await handleOrgEntitlements(req, 'org-id-1', makeOpts(null));
    expect(res.status).toBe(401);
  });

  it('returns entitlements map for JWT-authenticated member', async () => {
    const token = await makeJwt({ sub: 'user-id-1', email: 'u@test.com' }, JWT_SECRET);
    const entitlements = [
      { organization_id: 'org-id-1', feature_key: 'usage_dashboard', enabled: true, hard_limit: null, soft_limit: null },
      { organization_id: 'org-id-1', feature_key: 'monthly_units', enabled: true, hard_limit: 500000, soft_limit: null },
      { organization_id: 'org-id-1', feature_key: 'alerts', enabled: false, hard_limit: null, soft_limit: null },
    ];

    const mockSb = {
      query: vi.fn()
        .mockResolvedValueOnce({ ok: true, data: [makeMembership()] })
        .mockResolvedValueOnce({ ok: true, data: entitlements }),
      insert: vi.fn(), update: vi.fn(), rpc: vi.fn(),
    };
    const req = new Request('https://api.test/v1/orgs/org-id-1/entitlements', {
      method: 'GET',
      headers: { authorization: `Bearer ${token}` },
    });
    const res = await handleOrgEntitlements(req, 'org-id-1', makeOpts(mockSb));
    expect(res.status).toBe(200);
    const body = await res.json() as any;
    expect(body.entitlements.usage_dashboard).toBe(true);
    expect(body.entitlements.monthly_units).toBe(500000);
    expect(body.entitlements.alerts).toBe(false);
  });

  it('returns 403 when JWT user is not a member', async () => {
    const token = await makeJwt({ sub: 'user-id-1', email: 'u@test.com' }, JWT_SECRET);
    const mockSb = {
      query: vi.fn().mockResolvedValueOnce({ ok: true, data: [] }),
      insert: vi.fn(), update: vi.fn(), rpc: vi.fn(),
    };
    const req = new Request('https://api.test/v1/orgs/org-id-1/entitlements', {
      method: 'GET',
      headers: { authorization: `Bearer ${token}` },
    });
    const res = await handleOrgEntitlements(req, 'org-id-1', makeOpts(mockSb));
    expect(res.status).toBe(403);
  });

  it('returns 403 when API key belongs to different org', async () => {
    const secret = 'testsecret32charsminimumvalue000';
    const apiKeyRow = await makeApiKeyRow('other-org-id');
    const mockSb = {
      query: vi.fn().mockResolvedValueOnce({ ok: true, data: [apiKeyRow] }),
      insert: vi.fn(), update: vi.fn(), rpc: vi.fn(),
    };
    const req = new Request('https://api.test/v1/orgs/org-id-1/entitlements', {
      method: 'GET',
      headers: { authorization: `Bearer int_live_abc12345_${secret}` },
    });
    const res = await handleOrgEntitlements(req, 'org-id-1', makeOpts(mockSb));
    expect(res.status).toBe(403);
  });
});

describe('GET /v1/orgs/:orgId/quota/status', () => {
  const makeQuotaOpts = (sbOverride: any, doOverride?: any) => ({
    ...makeOpts(sbOverride),
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
    const req = new Request('https://api.test/v1/orgs/org-id-1/quota/status', { method: 'GET' });
    const res = await handleQuotaStatus(req, 'org-id-1', makeQuotaOpts(null));
    expect(res.status).toBe(401);
  });

  it('returns 403 when JWT user is not a member', async () => {
    const token = await makeJwt({ sub: 'user-id-1', email: 'u@test.com' }, JWT_SECRET);
    const mockSb = {
      query: vi.fn().mockResolvedValueOnce({ ok: true, data: [] }),
      insert: vi.fn(), update: vi.fn(), rpc: vi.fn(),
    };
    const req = new Request('https://api.test/v1/orgs/org-id-1/quota/status', {
      method: 'GET',
      headers: { authorization: `Bearer ${token}` },
    });
    const res = await handleQuotaStatus(req, 'org-id-1', makeQuotaOpts(mockSb));
    expect(res.status).toBe(403);
  });

  it('returns quota status for JWT-authenticated member', async () => {
    const token = await makeJwt({ sub: 'user-id-1', email: 'u@test.com' }, JWT_SECRET);
    const mockSb = {
      query: vi.fn().mockResolvedValueOnce({ ok: true, data: [makeMembership()] }),
      insert: vi.fn(), update: vi.fn(), rpc: vi.fn(),
    };
    const quotaPayload = {
      orgId: 'org-id-1',
      planKey: 'growth',
      quotaVersion: 2,
      minuteLimit: 60,
      monthlyLimit: 500000,
      minuteUsed: 5,
      monthlyUsed: 12345,
      minuteWindowExpiresIn: 45000,
    };
    const mockDo = makeDoNamespace(quotaPayload);
    const req = new Request('https://api.test/v1/orgs/org-id-1/quota/status', {
      method: 'GET',
      headers: { authorization: `Bearer ${token}` },
    });
    const res = await handleQuotaStatus(req, 'org-id-1', makeQuotaOpts(mockSb, mockDo));
    expect(res.status).toBe(200);
    const body = await res.json() as any;
    expect(body.org_id).toBe('org-id-1');
    expect(body.minuteLimit).toBe(60);
    expect(body.minuteUsed).toBe(5);
    expect(body.monthlyLimit).toBe(500000);
    expect(body.monthlyUsed).toBe(12345);
    expect(body.minuteWindowExpiresIn).toBe(45000);
  });

  it('returns quota status with null monthlyLimit for unlimited plan', async () => {
    const token = await makeJwt({ sub: 'user-id-1', email: 'u@test.com' }, JWT_SECRET);
    const mockSb = {
      query: vi.fn().mockResolvedValueOnce({ ok: true, data: [makeMembership()] }),
      insert: vi.fn(), update: vi.fn(), rpc: vi.fn(),
    };
    const quotaPayload = {
      orgId: 'org-id-1',
      planKey: 'enterprise',
      quotaVersion: 1,
      minuteLimit: 120,
      monthlyLimit: null,
      minuteUsed: 0,
      monthlyUsed: 0,
      minuteWindowExpiresIn: 60000,
    };
    const mockDo = makeDoNamespace(quotaPayload);
    const req = new Request('https://api.test/v1/orgs/org-id-1/quota/status', {
      method: 'GET',
      headers: { authorization: `Bearer ${token}` },
    });
    const res = await handleQuotaStatus(req, 'org-id-1', makeQuotaOpts(mockSb, mockDo));
    expect(res.status).toBe(200);
    const body = await res.json() as any;
    expect(body.monthlyLimit).toBeNull();
    expect(body.minuteLimit).toBe(120);
  });
});
