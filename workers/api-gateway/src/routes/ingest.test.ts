import { describe, it, expect, vi, afterEach } from 'vitest';
import { handleIngestEvent, handleIngestOtel } from './ingest';
import { hashApiKeySecret } from '../../../lib/api-keys';
import { MS_PER_DAY } from '../../../lib/constants';
import {
  createSupabaseFetchStub,
  createdRows,
  httpError,
  okRows,
  TEST_SERVICE_ROLE_KEY,
  TEST_SUPABASE_URL,
  type RouteResponder,
  type SupabaseFetchStub,
} from '../../../lib/test-helpers/supabase-fetch-stub';

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

const ORG_ID = '00000000-0000-4000-8000-000000000001';
const USER_ID = '00000000-0000-4000-8000-000000000002';
const API_KEY_SECRET = 'testsecret32charsminimumvalue000';
const API_KEY_TOKEN = `int_live_abc12345_${API_KEY_SECRET}`;

const opts = {
  jwtSecret: JWT_SECRET,
  hmacSecret: HMAC_SECRET,
  supabaseUrl: TEST_SUPABASE_URL,
  serviceRoleKey: TEST_SERVICE_ROLE_KEY,
};

const makeMembership = () => ({
  organization_id: ORG_ID,
  user_id: USER_ID,
  role: 'owner',
  status: 'active',
});

const makeApiKeyRow = async (orgId = ORG_ID, prefix = 'abc12345', secret = API_KEY_SECRET) => ({
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

/** Routes shared by every happy path: the event insert and the rollup it triggers. */
const writeRoutes = (): Record<string, RouteResponder> => ({
  'POST usage_events': createdRows([{ id: 'evt-1' }]),
  'GET usage_events': okRows([]),
  'POST usage_buckets_daily': createdRows([]),
});

/** Installs the stub as global fetch and returns it for assertions. */
function stubSupabase(routes: Record<string, RouteResponder>): SupabaseFetchStub {
  const stub = createSupabaseFetchStub(routes);
  vi.stubGlobal('fetch', stub.fetch);
  return stub;
}

const jwtRoutes = (memberships = [makeMembership()]) => ({
  'GET organization_memberships': okRows(memberships),
  ...writeRoutes(),
});

const apiKeyRoutes = async (row?: Record<string, unknown>) => ({
  'GET api_keys': okRows([row ?? await makeApiKeyRow()]),
  ...writeRoutes(),
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

afterEach(() => {
  vi.unstubAllGlobals();
});

describe('POST /v1/ingest/events', () => {
  it('returns 401 when no auth header', async () => {
    stubSupabase({});
    const req = new Request('https://api.test/v1/ingest/events', { method: 'POST' });
    const res = await handleIngestEvent(req, opts);
    expect(res.status).toBe(401);
  });

  it('returns 422 when body is missing required fields', async () => {
    const token = await makeJwt({ sub: USER_ID, email: 'u@test.com' });
    stubSupabase(jwtRoutes());
    const req = makeRequest({ org_id: ORG_ID }, token); // missing metric_key
    const res = await handleIngestEvent(req, opts);
    expect(res.status).toBe(422);
  });

  it('returns 403 when JWT user is not a member', async () => {
    const token = await makeJwt({ sub: USER_ID, email: 'u@test.com' });
    stubSupabase(jwtRoutes([]));
    const req = makeRequest(validBody(), token);
    const res = await handleIngestEvent(req, opts);
    expect(res.status).toBe(403);
  });

  it('returns 202 and request_id for valid JWT ingest', async () => {
    const token = await makeJwt({ sub: USER_ID, email: 'u@test.com' });
    stubSupabase(jwtRoutes());
    const req = makeRequest(validBody(), token);
    const res = await handleIngestEvent(req, opts);
    expect(res.status).toBe(202);
    const body = await res.json() as { ok: boolean; request_id: string };
    expect(body.ok).toBe(true);
    expect(typeof body.request_id).toBe('string');
  });

  it('scopes the membership lookup to the user, org, and active status', async () => {
    const token = await makeJwt({ sub: USER_ID, email: 'u@test.com' });
    const stub = stubSupabase(jwtRoutes());
    await handleIngestEvent(makeRequest(validBody(), token), opts);

    const params = stub.find('GET', 'organization_memberships')!.url.searchParams;
    expect(params.get('user_id')).toBe(`eq.${USER_ID}`);
    expect(params.get('organization_id')).toBe(`eq.${ORG_ID}`);
    expect(params.get('status')).toBe('eq.active');
  });

  it('inserts event with correct fields', async () => {
    const token = await makeJwt({ sub: USER_ID, email: 'u@test.com' });
    const stub = stubSupabase(jwtRoutes());
    const payload = { ...validBody(), latency_ms: 120, status_code: 200 };
    await handleIngestEvent(makeRequest(payload, token), opts);

    const insert = stub.find('POST', 'usage_events')!;
    expect(insert.headers['prefer']).toBe('return=representation');
    expect(insert.body).toEqual([
      expect.objectContaining({
        organization_id: ORG_ID,
        metric_key: 'api_requests',
        quantity: 1,
        source: 'api',
        latency_ms: 120,
        status_code: 200,
      }),
    ]);
  });

  it('returns 202 for valid API key ingest', async () => {
    stubSupabase(await apiKeyRoutes());
    const res = await handleIngestEvent(makeRequest(validBody(), API_KEY_TOKEN), opts);
    expect(res.status).toBe(202);
  });

  it('returns 403 when API key belongs to different org', async () => {
    const otherOrgKey = await makeApiKeyRow('00000000-0000-4000-8000-000000000099');
    stubSupabase(await apiKeyRoutes(otherOrgKey));
    const res = await handleIngestEvent(makeRequest(validBody(), API_KEY_TOKEN), opts);
    expect(res.status).toBe(403);
  });

  it('returns 500 when insert fails', async () => {
    const token = await makeJwt({ sub: USER_ID, email: 'u@test.com' });
    stubSupabase({ ...jwtRoutes(), 'POST usage_events': httpError(500, 'DB error') });
    const res = await handleIngestEvent(makeRequest(validBody(), token), opts);
    expect(res.status).toBe(500);
  });

  it('calls waitUntil with rollup promise when provided', async () => {
    const token = await makeJwt({ sub: USER_ID, email: 'u@test.com' });
    stubSupabase(jwtRoutes());
    const waitUntil = vi.fn();
    await handleIngestEvent(makeRequest(validBody(), token), opts, waitUntil);
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
    stubSupabase({});
    const req = new Request('https://api.test/v1/ingest/otel', { method: 'POST' });
    const res = await handleIngestOtel(req, opts);
    expect(res.status).toBe(401);
  });

  it('returns 401 when JWT is used instead of API key', async () => {
    const token = await makeJwt({ sub: USER_ID });
    stubSupabase(jwtRoutes());
    const res = await handleIngestOtel(makeOtelRequest({ spans: [validSpan()] }, token), opts);
    expect(res.status).toBe(401);
  });

  it('returns 422 when spans array is missing', async () => {
    stubSupabase(await apiKeyRoutes());
    const res = await handleIngestOtel(makeOtelRequest({}, API_KEY_TOKEN), opts);
    expect(res.status).toBe(422);
  });

  it('returns 422 when spans array is empty', async () => {
    stubSupabase(await apiKeyRoutes());
    const res = await handleIngestOtel(makeOtelRequest({ spans: [] }, API_KEY_TOKEN), opts);
    expect(res.status).toBe(422);
  });

  it('returns 202 with request_id and span_count for valid API key', async () => {
    stubSupabase(await apiKeyRoutes());
    const res = await handleIngestOtel(
      makeOtelRequest({ spans: [validSpan()] }, API_KEY_TOKEN), opts,
    );
    expect(res.status).toBe(202);
    const body = await res.json() as { ok: boolean; request_id: string; span_count: number };
    expect(body.ok).toBe(true);
    expect(typeof body.request_id).toBe('string');
    expect(body.span_count).toBe(1);
  });

  it('inserts usage event with correct fields', async () => {
    const stub = stubSupabase(await apiKeyRoutes());
    const spans = [validSpan(), { ...validSpan(), span_id: 'span002' }];
    await handleIngestOtel(makeOtelRequest({ spans }, API_KEY_TOKEN), opts);

    expect(stub.find('POST', 'usage_events')!.body).toEqual([
      expect.objectContaining({
        organization_id: ORG_ID,
        metric_key: 'otel_events',
        quantity: 2,
        source: 'ingest',
        route: '/v1/ingest/otel',
        api_key_id: 'key-id-1',
      }),
    ]);
  });

  it('returns 500 when insert fails', async () => {
    stubSupabase({
      ...(await apiKeyRoutes()),
      'POST usage_events': httpError(500, 'DB error'),
    });
    const res = await handleIngestOtel(
      makeOtelRequest({ spans: [validSpan()] }, API_KEY_TOKEN), opts,
    );
    expect(res.status).toBe(500);
  });

  it('calls waitUntil with rollup promise when provided', async () => {
    stubSupabase(await apiKeyRoutes());
    const waitUntil = vi.fn();
    await handleIngestOtel(
      makeOtelRequest({ spans: [validSpan()] }, API_KEY_TOKEN), opts, waitUntil,
    );
    expect(waitUntil).toHaveBeenCalledWith(expect.any(Promise));
  });

  it('returns 422 when spans exceed the 1000-span limit', async () => {
    stubSupabase(await apiKeyRoutes());
    const tooManySpans = Array.from({ length: 1001 }, (_, i) => ({ ...validSpan(), span_id: `span${i}` }));
    const res = await handleIngestOtel(
      makeOtelRequest({ spans: tooManySpans }, API_KEY_TOKEN), opts,
    );
    expect(res.status).toBe(422);
  });

  it('accepts optional span attributes and status', async () => {
    stubSupabase(await apiKeyRoutes());
    const spanWithAttrs = {
      ...validSpan(),
      status: 'error' as const,
      attributes: { 'http.method': 'GET', 'http.status_code': 500, 'error': true },
    };
    const res = await handleIngestOtel(
      makeOtelRequest({ spans: [spanWithAttrs] }, API_KEY_TOKEN), opts,
    );
    expect(res.status).toBe(202);
  });

  it('returns 422 when start_time_ms is more than 1 day in the future', async () => {
    stubSupabase(await apiKeyRoutes());
    const futureSpan = { ...validSpan(), start_time_ms: Date.now() + 7 * MS_PER_DAY };
    const res = await handleIngestOtel(
      makeOtelRequest({ spans: [futureSpan] }, API_KEY_TOKEN), opts,
    );
    expect(res.status).toBe(422);
  });

  it('forwards rate-limit headers when doNamespace quota check passes', async () => {
    stubSupabase(await apiKeyRoutes());
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
    const res = await handleIngestOtel(
      makeOtelRequest({ spans: [validSpan()] }, API_KEY_TOKEN),
      { ...opts, doNamespace: mockDO },
    );
    expect(res.status).toBe(202);
    expect(res.headers.get('X-RateLimit-Remaining-Minute')).toBe('42');
    expect(res.headers.get('X-RateLimit-Remaining-Monthly')).toBe('999');
  });
});
