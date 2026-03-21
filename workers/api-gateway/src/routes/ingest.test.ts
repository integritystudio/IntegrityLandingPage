import { describe, it, expect, vi } from 'vitest';
import { handleIngestEvent, handleIngestOtel } from './ingest';
import { hashApiKeySecret } from '../../../lib/api-keys';
import type { SupabaseClient } from '../../../lib/supabase';

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

const makeOpts = (sbOverride: SupabaseClient | undefined = undefined) => ({
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
    const res = await handleIngestEvent(req, makeOpts());
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
    const apiKeyRow = await makeApiKeyRow('00000000-0000-0000-0000-000000000099');
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

const validSpan = () => ({
  trace_id: 'abc123def456',
  span_id: 'span001',
  name: 'test-span',
  start_time_ms: 1700000000000,
  duration_ms: 42,
});

const makeOtelRequest = (body: unknown, token: string) =>
  new Request('https://api.test/v1/ingest/otel', {
    method: 'POST',
    headers: {
      authorization: `Bearer ${token}`,
      'content-type': 'application/json',
    },
    body: JSON.stringify(body),
  });

describe('POST /v1/ingest/otel', () => {
  it('returns 401 when no auth header', async () => {
    const req = new Request('https://api.test/v1/ingest/otel', { method: 'POST' });
    const res = await handleIngestOtel(req, makeOpts());
    expect(res.status).toBe(401);
  });

  it('returns 401 when JWT is used instead of API key', async () => {
    const token = await makeJwt({ sub: USER_ID });
    const mockSb = makeMockSb();
    const req = makeOtelRequest({ spans: [validSpan()] }, token);
    const res = await handleIngestOtel(req, makeOpts(mockSb));
    expect(res.status).toBe(401);
  });

  it('returns 422 when spans array is missing', async () => {
    const secret = 'testsecret32charsminimumvalue000';
    const apiKeyRow = await makeApiKeyRow();
    const mockSb = makeMockSb({ query: vi.fn().mockResolvedValue({ ok: true, data: [apiKeyRow] }) });
    const req = makeOtelRequest({}, `int_live_abc12345_${secret}`);
    const res = await handleIngestOtel(req, makeOpts(mockSb));
    expect(res.status).toBe(422);
  });

  it('returns 422 when spans array is empty', async () => {
    const secret = 'testsecret32charsminimumvalue000';
    const apiKeyRow = await makeApiKeyRow();
    const mockSb = makeMockSb({ query: vi.fn().mockResolvedValue({ ok: true, data: [apiKeyRow] }) });
    const req = makeOtelRequest({ spans: [] }, `int_live_abc12345_${secret}`);
    const res = await handleIngestOtel(req, makeOpts(mockSb));
    expect(res.status).toBe(422);
  });

  it('returns 202 with request_id and span_count for valid API key', async () => {
    const secret = 'testsecret32charsminimumvalue000';
    const apiKeyRow = await makeApiKeyRow();
    const mockSb = makeMockSb({ query: vi.fn().mockResolvedValue({ ok: true, data: [apiKeyRow] }) });
    const req = makeOtelRequest({ spans: [validSpan()] }, `int_live_abc12345_${secret}`);
    const res = await handleIngestOtel(req, makeOpts(mockSb));
    expect(res.status).toBe(202);
    const body = await res.json() as any;
    expect(body.ok).toBe(true);
    expect(typeof body.request_id).toBe('string');
    expect(body.span_count).toBe(1);
  });

  it('inserts usage event with correct fields', async () => {
    const secret = 'testsecret32charsminimumvalue000';
    const apiKeyRow = await makeApiKeyRow();
    const mockSb = makeMockSb({ query: vi.fn().mockResolvedValue({ ok: true, data: [apiKeyRow] }) });
    const spans = [validSpan(), { ...validSpan(), span_id: 'span002' }];
    const req = makeOtelRequest({ spans }, `int_live_abc12345_${secret}`);
    await handleIngestOtel(req, makeOpts(mockSb));

    expect(mockSb.insert).toHaveBeenCalledWith(
      'usage_events',
      expect.objectContaining({
        organization_id: ORG_ID,
        metric_key: 'otel_events',
        quantity: 2,
        source: 'ingest',
        route: '/v1/ingest/otel',
        api_key_id: 'key-id-1',
      }),
    );
  });

  it('returns 500 when insert fails', async () => {
    const secret = 'testsecret32charsminimumvalue000';
    const apiKeyRow = await makeApiKeyRow();
    const mockSb = makeMockSb({
      query: vi.fn().mockResolvedValue({ ok: true, data: [apiKeyRow] }),
      insert: vi.fn().mockResolvedValue({ ok: false, error: 'DB error' }),
    });
    const req = makeOtelRequest({ spans: [validSpan()] }, `int_live_abc12345_${secret}`);
    const res = await handleIngestOtel(req, makeOpts(mockSb));
    expect(res.status).toBe(500);
  });

  it('calls waitUntil with rollup promise when provided', async () => {
    const secret = 'testsecret32charsminimumvalue000';
    const apiKeyRow = await makeApiKeyRow();
    const mockSb = makeMockSb({ query: vi.fn().mockResolvedValue({ ok: true, data: [apiKeyRow] }) });
    const waitUntil = vi.fn();
    const req = makeOtelRequest({ spans: [validSpan()] }, `int_live_abc12345_${secret}`);
    await handleIngestOtel(req, makeOpts(mockSb), waitUntil);
    expect(waitUntil).toHaveBeenCalledWith(expect.any(Promise));
  });

  it('returns 422 when spans exceed the 1000-span limit', async () => {
    const secret = 'testsecret32charsminimumvalue000';
    const apiKeyRow = await makeApiKeyRow();
    const mockSb = makeMockSb({ query: vi.fn().mockResolvedValue({ ok: true, data: [apiKeyRow] }) });
    const tooManySpans = Array.from({ length: 1001 }, (_, i) => ({ ...validSpan(), span_id: `span${i}` }));
    const req = makeOtelRequest({ spans: tooManySpans }, `int_live_abc12345_${secret}`);
    const res = await handleIngestOtel(req, makeOpts(mockSb));
    expect(res.status).toBe(422);
  });

  it('accepts optional span attributes and status', async () => {
    const secret = 'testsecret32charsminimumvalue000';
    const apiKeyRow = await makeApiKeyRow();
    const mockSb = makeMockSb({ query: vi.fn().mockResolvedValue({ ok: true, data: [apiKeyRow] }) });
    const spanWithAttrs = {
      ...validSpan(),
      status: 'error' as const,
      attributes: { 'http.method': 'GET', 'http.status_code': 500, 'error': true },
    };
    const req = makeOtelRequest({ spans: [spanWithAttrs] }, `int_live_abc12345_${secret}`);
    const res = await handleIngestOtel(req, makeOpts(mockSb));
    expect(res.status).toBe(202);
  });

  it('returns 422 when start_time_ms is more than 1 day in the future', async () => {
    const secret = 'testsecret32charsminimumvalue000';
    const apiKeyRow = await makeApiKeyRow();
    const mockSb = makeMockSb({ query: vi.fn().mockResolvedValue({ ok: true, data: [apiKeyRow] }) });
    const futureSpan = { ...validSpan(), start_time_ms: Date.now() + 7 * 86_400_000 };
    const req = makeOtelRequest({ spans: [futureSpan] }, `int_live_abc12345_${secret}`);
    const res = await handleIngestOtel(req, makeOpts(mockSb));
    expect(res.status).toBe(422);
  });

  it('forwards rate-limit headers when doNamespace quota check passes', async () => {
    const secret = 'testsecret32charsminimumvalue000';
    const apiKeyRow = await makeApiKeyRow();
    const mockSb = makeMockSb({ query: vi.fn().mockResolvedValue({ ok: true, data: [apiKeyRow] }) });
    const mockDO = {
      idFromName: vi.fn().mockReturnValue('do-id'),
      get: vi.fn().mockReturnValue({
        fetch: vi.fn().mockResolvedValue(
          new Response(
            JSON.stringify({ allowed: true, remainingMinute: 42, remainingMonthly: 999 }),
            { status: 200, headers: { 'Content-Type': 'application/json' } },
          ),
        ),
      }),
    } as unknown as DurableObjectNamespace;
    const req = makeOtelRequest({ spans: [validSpan()] }, `int_live_abc12345_${secret}`);
    const res = await handleIngestOtel(req, { ...makeOpts(mockSb), doNamespace: mockDO });
    expect(res.status).toBe(202);
    expect(res.headers.get('X-RateLimit-Remaining-Minute')).toBe('42');
    expect(res.headers.get('X-RateLimit-Remaining-Monthly')).toBe('999');
  });
});
