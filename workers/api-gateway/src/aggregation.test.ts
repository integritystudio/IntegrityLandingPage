import { describe, it, expect, vi } from 'vitest';
import { rollupDailyBucket } from './aggregation';

const makeEvents = (overrides: Partial<{
  organization_id: string;
  metric_key: string;
  quantity: number;
  latency_ms: number | null;
}>[] = []) =>
  overrides.map(o => ({
    organization_id: 'org-1',
    metric_key: 'api_requests',
    quantity: 1,
    latency_ms: null,
    ...o,
  }));

const makeSb = (events: ReturnType<typeof makeEvents>) => ({
  query: vi.fn().mockResolvedValue({ ok: true, data: events }),
  insert: vi.fn(),
  update: vi.fn(),
  upsert: vi.fn().mockResolvedValue({ ok: true, data: null }),
  rpc: vi.fn(),
});

describe('rollupDailyBucket', () => {
  it('queries usage_events for the correct org and date range', async () => {
    const sb = makeSb([]);
    await rollupDailyBucket('org-1', '2026-03-20', sb as any);

    expect(sb.query).toHaveBeenCalledWith('usage_events', expect.objectContaining({
      filters: expect.arrayContaining([
        { column: 'organization_id', operator: 'eq', value: 'org-1' },
        { column: 'created_at', operator: 'gte', value: '2026-03-20T00:00:00.000Z' },
        { column: 'created_at', operator: 'lt', value: '2026-03-21T00:00:00.000Z' },
      ]),
    }));
  });

  it('returns zero counts when no events', async () => {
    const sb = makeSb([]);
    const result = await rollupDailyBucket('org-1', '2026-03-20', sb as any);

    expect(result.events_processed).toBe(0);
    expect(result.buckets_updated).toBe(0);
    expect(sb.upsert).not.toHaveBeenCalled();
  });

  it('aggregates single metric correctly', async () => {
    const events = makeEvents([
      { quantity: 5, latency_ms: 100 },
      { quantity: 3, latency_ms: 200 },
      { quantity: 2, latency_ms: null },
    ]);
    const sb = makeSb(events);
    const result = await rollupDailyBucket('org-1', '2026-03-20', sb as any);

    expect(result.events_processed).toBe(3);
    expect(result.buckets_updated).toBe(1);
    expect(sb.upsert).toHaveBeenCalledWith(
      'usage_buckets_daily',
      [expect.objectContaining({
        organization_id: 'org-1',
        bucket_date: '2026-03-20',
        metric_key: 'api_requests',
        total_quantity: 10,
        request_count: 3,
        avg_latency_ms: 150, // (100 + 200) / 2, null excluded
      })],
      'organization_id,bucket_date,metric_key',
    );
  });

  it('aggregates multiple metrics into separate buckets', async () => {
    const events = makeEvents([
      { metric_key: 'api_requests', quantity: 2, latency_ms: 50 },
      { metric_key: 'data_retention_days', quantity: 30, latency_ms: null },
      { metric_key: 'api_requests', quantity: 1, latency_ms: 100 },
    ]);
    const sb = makeSb(events);
    const result = await rollupDailyBucket('org-1', '2026-03-20', sb as any);

    expect(result.events_processed).toBe(3);
    expect(result.buckets_updated).toBe(2);

    const buckets: any[] = sb.upsert.mock.calls[0][1];
    const reqBucket = buckets.find((b: any) => b.metric_key === 'api_requests');
    const retBucket = buckets.find((b: any) => b.metric_key === 'data_retention_days');

    expect(reqBucket.total_quantity).toBe(3);
    expect(reqBucket.request_count).toBe(2);
    expect(reqBucket.avg_latency_ms).toBe(75); // (50 + 100) / 2

    expect(retBucket.total_quantity).toBe(30);
    expect(retBucket.request_count).toBe(1);
    expect(retBucket.avg_latency_ms).toBeNull();
  });

  it('returns avg_latency_ms null when all events have null latency', async () => {
    const events = makeEvents([
      { quantity: 1, latency_ms: null },
      { quantity: 1, latency_ms: null },
    ]);
    const sb = makeSb(events);
    await rollupDailyBucket('org-1', '2026-03-20', sb as any);

    const buckets: any[] = sb.upsert.mock.calls[0][1];
    expect(buckets[0].avg_latency_ms).toBeNull();
  });

  it('upserts with correct conflict columns', async () => {
    const sb = makeSb(makeEvents([{ quantity: 1 }]));
    await rollupDailyBucket('org-1', '2026-03-20', sb as any);

    expect(sb.upsert).toHaveBeenCalledWith(
      'usage_buckets_daily',
      expect.any(Array),
      'organization_id,bucket_date,metric_key',
    );
  });

  it('still returns result when upsert fails', async () => {
    const events = makeEvents([{ quantity: 1 }]);
    const sb = {
      query: vi.fn().mockResolvedValue({ ok: true, data: events }),
      insert: vi.fn(),
      update: vi.fn(),
      upsert: vi.fn().mockResolvedValue({ ok: false, error: 'DB error' }),
      rpc: vi.fn(),
    };
    const result = await rollupDailyBucket('org-1', '2026-03-20', sb as any);

    expect(result.events_processed).toBe(1);
    expect(result.buckets_updated).toBe(0);
  });
});
