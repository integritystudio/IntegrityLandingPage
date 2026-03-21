import { describe, it, expect, vi } from 'vitest';
import { handleListOrgs, handleOrgDashboard, handleOrgBillingStatus } from './orgs';
import type { Organization, OrgRole } from '../../../lib/types';

const JWT_SECRET = 'test-jwt-secret-at-least-32-chars!!';

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

const makeOrg = (overrides: Partial<Organization & { role: OrgRole }> = {}): Organization & { role: OrgRole } => ({
  id: 'org-id-1',
  slug: 'test-org',
  name: 'Test Org',
  billing_status: 'active',
  current_plan: 'growth',
  quota_version: 1,
  role: 'owner',
  ...overrides,
});

const makeMembership = (orgId = 'org-id-1', role: OrgRole = 'owner') => ({
  organization_id: orgId,
  user_id: 'user-id-1',
  role,
  status: 'active',
});

const makeOpts = (sbOverride: any) => ({
  jwtSecret: JWT_SECRET,
  supabaseUrl: 'https://test.supabase.co',
  serviceRoleKey: 'key',
  _sbOverride: sbOverride,
});

describe('GET /v1/orgs', () => {
  it('returns 401 when no bearer token', async () => {
    const req = new Request('https://api.test/v1/orgs', { method: 'GET' });
    const res = await handleListOrgs(req, makeOpts(null));
    expect(res.status).toBe(401);
  });

  it('returns list of orgs the user belongs to', async () => {
    const token = await makeJwt({ sub: 'user-id-1', email: 'u@test.com' }, JWT_SECRET);
    const org = makeOrg();

    const mockSb = {
      query: vi.fn()
        .mockResolvedValueOnce({ ok: true, data: [makeMembership()] })
        .mockResolvedValueOnce({ ok: true, data: [org] }),
      insert: vi.fn(), update: vi.fn(), rpc: vi.fn(),
    };

    const req = new Request('https://api.test/v1/orgs', {
      method: 'GET',
      headers: { authorization: `Bearer ${token}` },
    });

    const res = await handleListOrgs(req, makeOpts(mockSb));
    expect(res.status).toBe(200);
    const body = await res.json() as any;
    expect(body.organizations).toHaveLength(1);
    expect(body.organizations[0].id).toBe('org-id-1');
    expect(body.organizations[0].role).toBe('owner');
  });

  it('returns empty list when user has no memberships', async () => {
    const token = await makeJwt({ sub: 'user-id-1', email: 'u@test.com' }, JWT_SECRET);
    const mockSb = {
      query: vi.fn().mockResolvedValueOnce({ ok: true, data: [] }),
      insert: vi.fn(), update: vi.fn(), rpc: vi.fn(),
    };
    const req = new Request('https://api.test/v1/orgs', {
      method: 'GET',
      headers: { authorization: `Bearer ${token}` },
    });
    const res = await handleListOrgs(req, makeOpts(mockSb));
    expect(res.status).toBe(200);
    const body = await res.json() as any;
    expect(body.organizations).toEqual([]);
  });
});

describe('GET /v1/orgs/:orgId/dashboard', () => {
  it('returns 401 when no bearer token', async () => {
    const req = new Request('https://api.test/v1/orgs/org-id-1/dashboard', { method: 'GET' });
    const res = await handleOrgDashboard(req, 'org-id-1', makeOpts(null));
    expect(res.status).toBe(401);
  });

  it('returns 403 when user is not a member of the org', async () => {
    const token = await makeJwt({ sub: 'user-id-1', email: 'u@test.com' }, JWT_SECRET);
    const mockSb = {
      query: vi.fn().mockResolvedValueOnce({ ok: true, data: [] }),
      insert: vi.fn(), update: vi.fn(), rpc: vi.fn(),
    };
    const req = new Request('https://api.test/v1/orgs/org-id-1/dashboard', {
      method: 'GET',
      headers: { authorization: `Bearer ${token}` },
    });
    const res = await handleOrgDashboard(req, 'org-id-1', makeOpts(mockSb));
    expect(res.status).toBe(403);
  });

  it('returns dashboard summary when user is a member', async () => {
    const token = await makeJwt({ sub: 'user-id-1', email: 'u@test.com' }, JWT_SECRET);
    const org = makeOrg();
    const entitlements = [
      { organization_id: 'org-id-1', feature_key: 'api_keys_max', enabled: true, hard_limit: 10, soft_limit: null },
    ];

    const mockSb = {
      query: vi.fn()
        .mockResolvedValueOnce({ ok: true, data: [makeMembership()] })
        .mockResolvedValueOnce({ ok: true, data: [org] })
        .mockResolvedValueOnce({ ok: true, data: entitlements }),
      insert: vi.fn(), update: vi.fn(), rpc: vi.fn(),
    };

    const req = new Request('https://api.test/v1/orgs/org-id-1/dashboard', {
      method: 'GET',
      headers: { authorization: `Bearer ${token}` },
    });

    const res = await handleOrgDashboard(req, 'org-id-1', makeOpts(mockSb));
    expect(res.status).toBe(200);
    const body = await res.json() as any;
    expect(body.org.id).toBe('org-id-1');
    expect(body.role).toBe('owner');
    expect(body.entitlements).toBeDefined();
  });
});

describe('GET /v1/orgs/:orgId/billing-status', () => {
  it('returns 403 when user is not a member', async () => {
    const token = await makeJwt({ sub: 'user-id-1', email: 'u@test.com' }, JWT_SECRET);
    const mockSb = {
      query: vi.fn().mockResolvedValueOnce({ ok: true, data: [] }),
      insert: vi.fn(), update: vi.fn(), rpc: vi.fn(),
    };
    const req = new Request('https://api.test/v1/orgs/org-id-1/billing-status', {
      method: 'GET',
      headers: { authorization: `Bearer ${token}` },
    });
    const res = await handleOrgBillingStatus(req, 'org-id-1', makeOpts(mockSb));
    expect(res.status).toBe(403);
  });

  it('returns billing status for owner', async () => {
    const token = await makeJwt({ sub: 'user-id-1', email: 'u@test.com' }, JWT_SECRET);
    const org = makeOrg({ billing_status: 'active', current_plan: 'growth' });

    const mockSb = {
      query: vi.fn()
        .mockResolvedValueOnce({ ok: true, data: [makeMembership('org-id-1', 'owner')] })
        .mockResolvedValueOnce({ ok: true, data: [org] }),
      insert: vi.fn(), update: vi.fn(), rpc: vi.fn(),
    };

    const req = new Request('https://api.test/v1/orgs/org-id-1/billing-status', {
      method: 'GET',
      headers: { authorization: `Bearer ${token}` },
    });

    const res = await handleOrgBillingStatus(req, 'org-id-1', makeOpts(mockSb));
    expect(res.status).toBe(200);
    const body = await res.json() as any;
    expect(body.billing_status).toBe('active');
    expect(body.current_plan).toBe('growth');
  });
});
