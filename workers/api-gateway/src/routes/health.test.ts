import { describe, it, expect, vi, beforeEach } from 'vitest';
import { handleHealthCheck } from './health';

// Mock supabase to control database status in tests.
vi.mock('../../../lib/supabase', () => ({
  createSupabaseClient: () => ({
    query: vi.fn().mockResolvedValue({ ok: true }),
  }),
}));

const makeQuotaDO = (present = true): DurableObjectNamespace =>
  (present ? {} : null) as unknown as DurableObjectNamespace;

describe('handleHealthCheck — PagerDuty alerting', () => {
  beforeEach(() => {
    vi.stubGlobal('fetch', vi.fn().mockResolvedValue(new Response('ok', { status: 202 })));
  });

  it('does not fire PagerDuty when healthy', async () => {
    const waitUntil = vi.fn();
    const res = await handleHealthCheck(
      'https://test.supabase.co',
      'service-key',
      makeQuotaDO(true),
      { pdKey: 'pd-key-abc', waitUntil },
    );
    expect(res.status).toBe(200);
    expect(waitUntil).not.toHaveBeenCalled();
  });

  it('fires PagerDuty when DO is absent (unhealthy)', async () => {
    const waitUntil = vi.fn();
    const res = await handleHealthCheck(
      'https://test.supabase.co',
      'service-key',
      makeQuotaDO(false),
      { pdKey: 'pd-key-abc', waitUntil },
    );
    expect(res.status).toBe(503);
    expect(waitUntil).toHaveBeenCalledOnce();
    // waitUntil receives a Promise; resolve it to trigger the fetch call.
    await waitUntil.mock.calls[0][0];
    expect(vi.mocked(fetch)).toHaveBeenCalledOnce();
    const [url, init] = vi.mocked(fetch).mock.calls[0] as [string, RequestInit];
    expect(url).toBe('https://events.pagerduty.com/v2/enqueue');
    const body = JSON.parse(init.body as string);
    expect(body.routing_key).toBe('pd-key-abc');
    expect(body.event_action).toBe('trigger');
    expect(body.dedup_key).toBe('api-gateway-health');
    expect(body.payload.severity).toBe('critical');
  });

  it('does not fire PagerDuty when pdKey is absent', async () => {
    const waitUntil = vi.fn();
    const res = await handleHealthCheck(
      'https://test.supabase.co',
      'service-key',
      makeQuotaDO(false),
      { waitUntil },
    );
    expect(res.status).toBe(503);
    expect(waitUntil).not.toHaveBeenCalled();
  });

  it('does not fire PagerDuty when waitUntil is absent', async () => {
    const res = await handleHealthCheck(
      'https://test.supabase.co',
      'service-key',
      makeQuotaDO(false),
      { pdKey: 'pd-key-abc' },
    );
    expect(res.status).toBe(503);
    expect(vi.mocked(fetch)).not.toHaveBeenCalled();
  });

  it('health response succeeds even when PagerDuty fetch throws', async () => {
    vi.stubGlobal('fetch', vi.fn().mockRejectedValue(new Error('network error')));
    const waitUntil = vi.fn();
    const res = await handleHealthCheck(
      'https://test.supabase.co',
      'service-key',
      makeQuotaDO(false),
      { pdKey: 'pd-key-abc', waitUntil },
    );
    expect(res.status).toBe(503);
    // Resolve the waitUntil promise — must not throw.
    await expect(waitUntil.mock.calls[0][0]).resolves.toBeUndefined();
  });
});
