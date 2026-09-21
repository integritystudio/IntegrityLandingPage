import { describe, it, expect, vi, afterEach } from 'vitest';
import { meteredRoute, recordMeteredRequest, USAGE_METRIC_REQUESTS } from './usage-ledger';
import { createSupabaseClient } from '../../../lib/supabase';
import {
  createSupabaseFetchStub,
  createdRows,
  httpError,
  TEST_SERVICE_ROLE_KEY,
  TEST_SUPABASE_URL,
  type RouteResponder,
} from '../../../lib/test-helpers/supabase-fetch-stub';

const sb = () => createSupabaseClient(TEST_SUPABASE_URL, TEST_SERVICE_ROLE_KEY);
const stub = (routes: Record<string, RouteResponder>) => {
  const s = createSupabaseFetchStub(routes);
  vi.stubGlobal('fetch', s.fetch);
  return s;
};
const RECORD = { orgId: 'org-1', route: 'GET /v1/orgs/:id/dashboard', requestId: 'req-1', statusCode: 200, latencyMs: 12 };

afterEach(() => vi.unstubAllGlobals());

describe('meteredRoute', () => {
  it('elides the org id so rows group by route', () => {
    expect(meteredRoute('GET', '/dashboard')).toBe('GET /v1/orgs/:id/dashboard');
    expect(meteredRoute('POST', '/api-keys/abc/revoke')).toBe('POST /v1/orgs/:id/api-keys/abc/revoke');
    expect(meteredRoute('GET', '')).toBe('GET /v1/orgs/:id');
  });
});

describe('recordMeteredRequest', () => {
  it('inserts one usage_events row shaped like the DO reservation', async () => {
    const s = stub({ 'POST usage_events': createdRows([{ id: 1 }]) });

    await recordMeteredRequest(sb(), RECORD);

    const post = s.find('POST', 'usage_events')!;
    // The stub hands back the parsed body; a raw string is parsed for symmetry.
    const body: unknown = typeof post.body === 'string' ? JSON.parse(post.body) : post.body;
    const row = (Array.isArray(body) ? body[0] : body) as Record<string, unknown>;
    expect(row).toEqual({
      organization_id: 'org-1',
      route: 'GET /v1/orgs/:id/dashboard',
      metric_key: USAGE_METRIC_REQUESTS,
      quantity: 1,
      request_id: 'req-1',
      source: 'api',
      status_code: 200,
      latency_ms: 12,
    });
  });

  it('logs and does not throw when the insert fails', async () => {
    const error = vi.spyOn(console, 'error').mockImplementation(() => {});
    stub({ 'POST usage_events': httpError(500, 'DB error') });

    await expect(recordMeteredRequest(sb(), RECORD)).resolves.toBeUndefined();

    expect(error).toHaveBeenCalledWith(expect.stringContaining('[usage-ledger]'), RECORD.route, 'for org', 'org-1', expect.any(String));
    error.mockRestore();
  });
});
