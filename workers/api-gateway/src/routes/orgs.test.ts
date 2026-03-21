import { describe, it, expect, vi } from 'vitest';
import { handleListOrgs, handleOrgDashboard, handleOrgBillingStatus, handleBillingPortal } from './orgs';
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

  it('passes org IDs as in-filter to DB query (H3)', async () => {
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

    await handleListOrgs(req, makeOpts(mockSb));

    const secondCall = mockSb.query.mock.calls[1];
    expect(secondCall[1]).toMatchObject({
      filters: expect.arrayContaining([
        expect.objectContaining({ column: 'id', operator: 'in' }),
      ]),
    });
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

const makePortalOpts = (sbOverride: any, stripeOverride?: any) => ({
  jwtSecret: JWT_SECRET,
  supabaseUrl: 'https://test.supabase.co',
  serviceRoleKey: 'key',
  stripeSecretKey: 'sk_test_xxx',
  returnUrl: 'https://app.integritystudio.ai/#/billing',
  _sbOverride: sbOverride,
  _stripeOverride: stripeOverride,
});

describe('POST /v1/orgs/:id/billing-portal', () => {
  it('returns 401 when no bearer token', async () => {
    const req = new Request('https://api.test/v1/orgs/org-id-1/billing-portal', { method: 'POST' });
    const res = await handleBillingPortal(req, 'org-id-1', makePortalOpts(null));
    expect(res.status).toBe(401);
  });

  it('returns 403 when user is not a member', async () => {
    const token = await makeJwt({ sub: 'user-id-1', email: 'u@test.com' }, JWT_SECRET);
    const mockSb = {
      query: vi.fn().mockResolvedValueOnce({ ok: true, data: [] }),
      insert: vi.fn(), update: vi.fn(), rpc: vi.fn(),
    };
    const req = new Request('https://api.test/v1/orgs/org-id-1/billing-portal', {
      method: 'POST',
      headers: { authorization: `Bearer ${token}` },
    });
    const res = await handleBillingPortal(req, 'org-id-1', makePortalOpts(mockSb));
    expect(res.status).toBe(403);
  });

  it('returns 403 when user role is not owner or billing_admin', async () => {
    const token = await makeJwt({ sub: 'user-id-1', email: 'u@test.com' }, JWT_SECRET);
    const mockSb = {
      query: vi.fn().mockResolvedValueOnce({ ok: true, data: [makeMembership('org-id-1', 'member')] }),
      insert: vi.fn(), update: vi.fn(), rpc: vi.fn(),
    };
    const req = new Request('https://api.test/v1/orgs/org-id-1/billing-portal', {
      method: 'POST',
      headers: { authorization: `Bearer ${token}` },
    });
    const res = await handleBillingPortal(req, 'org-id-1', makePortalOpts(mockSb));
    expect(res.status).toBe(403);
  });

  it('returns 404 when org has no stripe_customer_id', async () => {
    const token = await makeJwt({ sub: 'user-id-1', email: 'u@test.com' }, JWT_SECRET);
    const mockSb = {
      query: vi.fn()
        .mockResolvedValueOnce({ ok: true, data: [makeMembership('org-id-1', 'owner')] })
        .mockResolvedValueOnce({ ok: true, data: [{ id: 'org-id-1', stripe_customer_id: null }] }),
      insert: vi.fn(), update: vi.fn(), rpc: vi.fn(),
    };
    const req = new Request('https://api.test/v1/orgs/org-id-1/billing-portal', {
      method: 'POST',
      headers: { authorization: `Bearer ${token}` },
    });
    const res = await handleBillingPortal(req, 'org-id-1', makePortalOpts(mockSb));
    expect(res.status).toBe(404);
  });

  it('returns 500 when stripe_customer_id has invalid format (H4)', async () => {
    const token = await makeJwt({ sub: 'user-id-1', email: 'u@test.com' }, JWT_SECRET);
    const mockSb = {
      query: vi.fn()
        .mockResolvedValueOnce({ ok: true, data: [makeMembership('org-id-1', 'owner')] })
        .mockResolvedValueOnce({ ok: true, data: [{ id: 'org-id-1', stripe_customer_id: 'invalid-id' }] }),
      insert: vi.fn(), update: vi.fn(), rpc: vi.fn(),
    };
    const req = new Request('https://api.test/v1/orgs/org-id-1/billing-portal', {
      method: 'POST',
      headers: { authorization: `Bearer ${token}` },
    });
    const res = await handleBillingPortal(req, 'org-id-1', makePortalOpts(mockSb));
    expect(res.status).toBe(500);
  });

  it('returns portal URL for owner with stripe customer', async () => {
    const token = await makeJwt({ sub: 'user-id-1', email: 'u@test.com' }, JWT_SECRET);
    const mockSb = {
      query: vi.fn()
        .mockResolvedValueOnce({ ok: true, data: [makeMembership('org-id-1', 'owner')] })
        .mockResolvedValueOnce({ ok: true, data: [{ id: 'org-id-1', stripe_customer_id: 'cus_123' }] }),
      insert: vi.fn().mockResolvedValue({ ok: true, data: [] }),
      update: vi.fn(), rpc: vi.fn(),
    };
    const mockStripe = {
      billingPortal: {
        sessions: {
          create: vi.fn().mockResolvedValue({ url: 'https://billing.stripe.com/session/xxx' }),
        },
      },
    };
    const req = new Request('https://api.test/v1/orgs/org-id-1/billing-portal', {
      method: 'POST',
      headers: { authorization: `Bearer ${token}` },
    });
    const res = await handleBillingPortal(req, 'org-id-1', makePortalOpts(mockSb, mockStripe));
    expect(res.status).toBe(200);
    const body = await res.json() as any;
    expect(body.url).toBe('https://billing.stripe.com/session/xxx');
    expect(mockStripe.billingPortal.sessions.create).toHaveBeenCalledWith({
      customer: 'cus_123',
      return_url: 'https://app.integritystudio.ai/#/billing',
    });
    // Audit log written after successful portal session creation
    expect(mockSb.insert).toHaveBeenCalledWith(
      'audit_log',
      expect.objectContaining({ action: 'billing_portal.accessed', target_type: 'org', target_id: 'org-id-1' }),
    );
  });

  it('returns portal URL for billing_admin role', async () => {
    const token = await makeJwt({ sub: 'user-id-1', email: 'u@test.com' }, JWT_SECRET);
    const mockSb = {
      query: vi.fn()
        .mockResolvedValueOnce({ ok: true, data: [makeMembership('org-id-1', 'billing_admin')] })
        .mockResolvedValueOnce({ ok: true, data: [{ id: 'org-id-1', stripe_customer_id: 'cus_456' }] }),
      insert: vi.fn().mockResolvedValue({ ok: true, data: [] }),
      update: vi.fn(), rpc: vi.fn(),
    };
    const mockStripe = {
      billingPortal: {
        sessions: { create: vi.fn().mockResolvedValue({ url: 'https://billing.stripe.com/session/yyy' }) },
      },
    };
    const req = new Request('https://api.test/v1/orgs/org-id-1/billing-portal', {
      method: 'POST',
      headers: { authorization: `Bearer ${token}` },
    });
    const res = await handleBillingPortal(req, 'org-id-1', makePortalOpts(mockSb, mockStripe));
    expect(res.status).toBe(200);
    const body = await res.json() as any;
    expect(body.url).toBe('https://billing.stripe.com/session/yyy');
  });

  it('returns 500 when Stripe throws', async () => {
    const token = await makeJwt({ sub: 'user-id-1', email: 'u@test.com' }, JWT_SECRET);
    const mockSb = {
      query: vi.fn()
        .mockResolvedValueOnce({ ok: true, data: [makeMembership('org-id-1', 'owner')] })
        .mockResolvedValueOnce({ ok: true, data: [{ id: 'org-id-1', stripe_customer_id: 'cus_123' }] }),
      insert: vi.fn(), update: vi.fn(), rpc: vi.fn(),
    };
    const mockStripe = {
      billingPortal: {
        sessions: { create: vi.fn().mockRejectedValue(new Error('Stripe API error')) },
      },
    };
    const req = new Request('https://api.test/v1/orgs/org-id-1/billing-portal', {
      method: 'POST',
      headers: { authorization: `Bearer ${token}` },
    });
    const res = await handleBillingPortal(req, 'org-id-1', makePortalOpts(mockSb, mockStripe));
    expect(res.status).toBe(500);
  });
});
