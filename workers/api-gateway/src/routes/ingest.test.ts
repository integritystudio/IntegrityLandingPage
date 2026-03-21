import { describe, it, expect, vi } from 'vitest';
import { handleIngestEvent } from './ingest';
import { hashApiKeySecret } from '../../../lib/api-keys';

const JWT_SECRET = 'test-jwt-secret-at-least-32-chars!!';
const HMAC_SECRET = 'test-hmac-secret-at-least-32-chars!';

async function makeJwt(payload: Record<string, unknown>): Promise<string> {
  const header = btoa(JSON.stringify({ alg: 'HS256', typ: 'JWT' }))
    .replace(/\+/g, '-').replace(/\//g, '_').replace(/=+$/, '');
  const body = btoa(JSON.stringify({ exp: 9999999999, ...payload }))
    .replace(/\+/g, '-').replace(/\//g, '_').replace(/=+$/, '');
  const msg = `${header}.${body}`;
  const key = await crypto.subtle.importKey(
    'raw', new TextEncoder().encode(JWT_SECRET),
    { name: 'HMAC', hash: 'SHA-256' }, false, ['sign'],
  );
  const sig = await crypto.subtle.sign('HMAC', key, new TextEncoder().encode(msg));
  const sigB64 = btoa(String.fromCharCode(...new Uint8Array(sig)))
    .replace(/\+/g, '-').replace(/\//g, '_').replace(/=+$/, '');
  return `${msg}.${sigB64}`;
}

const ORG_ID = '00000000-0000-0000-0000-000000000001';
const USER_ID = '00000000-0000-0000-0000-000000000002';

const makeOpts = (sbOverride: any) => ({
  jwtSecret: JWT_SECRET,
  hmacSecret: HMAC_SECRET,
  supabaseUrl: 'https://test.supabase.co',
  serviceRoleKey: 'key',
  _sbOverride: sbOverride,
});

const makeMembership = () => ({
  organization_id: ORG_ID,
  user_id: USER_ID,
  role: 'owner',
  status: 'active',
});

const makeApiKeyRow = async (orgId = ORG_ID, prefix = 'abc12345', secret = 'testsecret32charsminimumvalue000') => ({
  id: 'key-id-1',
  user_id: USER_ID,
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

const validBody = () => ({
  org_id: ORG_ID,
  metric_key: 'api_requests',
  quantity: 1,
});

const makeRequest = (body: unknown, token: string) =>
  new Request('https://api.test/v1/ingest/events', {
    method: 'POST',
    headers: {
      authorization: `Bearer ${token}`,
      'content-type': 'application/json',
    },
    body: JSON.stringify(body),
  });

const makeMockSb = (overrides: Partial<{
  query: ReturnType<typeof vi.fn>;
  insert: ReturnType<typeof vi.fn>;
  upsert: ReturnType<typeof vi.fn>;
}> = {}) => ({
  query: overrides.query ?? vi.fn().mockResolvedValue({ ok: true, data: [makeMembership()] }),
  insert: overrides.insert ?? vi.fn().mockResolvedValue({ ok: true, data: null }),
  update: vi.fn(),
  upsert: overrides.upsert ?? vi.fn().mockResolvedValue({ ok: true, data: null }),
  rpc: vi.fn(),
});

describe('POST /v1/ingest/events', () => {
  it('returns 401 when no auth header', async () => {
    const req = new Request('https://api.test/v1/ingest/events', { method: 'POST' });
    const res = await handleIngestEvent(req, makeOpts(null));
    expect(res.status).toBe(401);
  });

  it('returns 422 when body is missing required fields', async () => {
    const token = await makeJwt({ sub: USER_ID, email: 'u@test.com' });
    const mockSb = makeMockSb();
    const req = makeRequest({ org_id: ORG_ID }, token); // missing metric_key
    const res = await handleIngestEvent(req, makeOpts(mockSb));
    expect(res.status).toBe(422);
  });

  it('returns 403 when JWT user is not a member', async () => {
    const token = await makeJwt({ sub: USER_ID, email: 'u@test.com' });
    const mockSb = makeMockSb({ query: vi.fn().mockResolvedValue({ ok: true, data: [] }) });
    const req = makeRequest(validBody(), token);
    const res = await handleIngestEvent(req, makeOpts(mockSb));
    expect(res.status).toBe(403);
  });

  it('returns 202 and request_id for valid JWT ingest', async () => {
    const token = await makeJwt({ sub: USER_ID, email: 'u@test.com' });
    const mockSb = makeMockSb();
    const req = makeRequest(validBody(), token);
    const res = await handleIngestEvent(req, makeOpts(mockSb));
    expect(res.status).toBe(202);
    const body = await res.json() as any;
    expect(body.ok).toBe(true);
    expect(typeof body.request_id).toBe('string');
  });

  it('inserts event with correct fields', async () => {
    const token = await makeJwt({ sub: USER_ID, email: 'u@test.com' });
    const mockSb = makeMockSb();
    const payload = { ...validBody(), latency_ms: 120, status_code: 200 };
    const req = makeRequest(payload, token);
    await handleIngestEvent(req, makeOpts(mockSb));

    expect(mockSb.insert).toHaveBeenCalledWith(
      'usage_events',
      expect.objectContaining({
        organization_id: ORG_ID,
        metric_key: 'api_requests',
        quantity: 1,
        source: 'api',
        latency_ms: 120,
        status_code: 200,
      }),
    );
  });

  it('returns 202 for valid API key ingest', async () => {
    const secret = 'testsecret32charsminimumvalue000';
    const apiKeyRow = await makeApiKeyRow();
    const mockSb = makeMockSb({ query: vi.fn().mockResolvedValue({ ok: true, data: [apiKeyRow] }) });
    const req = makeRequest(validBody(), `int_live_abc12345_${secret}`);
    const res = await handleIngestEvent(req, makeOpts(mockSb));
    expect(res.status).toBe(202);
  });

  it('returns 403 when API key belongs to different org', async () => {
    const secret = 'testsecret32charsminimumvalue000';
    const apiKeyRow = await makeApiKeyRow('different-org-id-0000000000000');
    const mockSb = makeMockSb({ query: vi.fn().mockResolvedValue({ ok: true, data: [apiKeyRow] }) });
    const req = makeRequest(validBody(), `int_live_abc12345_${secret}`);
    const res = await handleIngestEvent(req, makeOpts(mockSb));
    expect(res.status).toBe(403);
  });

  it('returns 500 when insert fails', async () => {
    const token = await makeJwt({ sub: USER_ID, email: 'u@test.com' });
    const mockSb = makeMockSb({ insert: vi.fn().mockResolvedValue({ ok: false, error: 'DB error' }) });
    const req = makeRequest(validBody(), token);
    const res = await handleIngestEvent(req, makeOpts(mockSb));
    expect(res.status).toBe(500);
  });

  it('calls waitUntil with rollup promise when provided', async () => {
    const token = await makeJwt({ sub: USER_ID, email: 'u@test.com' });
    const mockSb = makeMockSb();
    const waitUntil = vi.fn();
    const req = makeRequest(validBody(), token);
    await handleIngestEvent(req, makeOpts(mockSb), waitUntil);
    expect(waitUntil).toHaveBeenCalledWith(expect.any(Promise));
  });
});
