import { describe, it, expect, vi } from 'vitest';
import { rollupDailyBucket, rollupMonthlyBucket } from './aggregation';
import { MonthlyUsageSummarySchema } from '../../lib/types/usage';

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

const makeMockSupabaseClient = (
  queryData: unknown,
  mocks?: Record<string, any>
) => ({
  query: vi.fn().mockResolvedValue({ ok: true, data: queryData }),
  insert: vi.fn(),
  update: vi.fn(),
  upsert: vi.fn().mockResolvedValue({ ok: true, data: null }),
  rpc: vi.fn(),
  ...mocks,
});

const makeSb = (events: ReturnType<typeof makeEvents>) =>
  makeMockSupabaseClient(events);

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

  it('throws when usage_events query fails', async () => {
    const sb = {
      query: vi.fn().mockResolvedValue({ ok: false, error: 'DB connection error' }),
      insert: vi.fn(),
      update: vi.fn(),
      upsert: vi.fn(),
      rpc: vi.fn(),
    };
    await expect(rollupDailyBucket('org-1', '2026-03-20', sb as any)).rejects.toThrow(
      'usage_events query failed',
    );
  });
});

const makeDailyBuckets = (overrides: Partial<{
  organization_id: string;
  metric_key: string;
  total_quantity: number;
  request_count: number;
  avg_latency_ms: number | null;
}>[] = []) =>
  overrides.map(o => ({
    organization_id: '00000000-0000-4000-8000-000000000001',
    metric_key: 'api_requests',
    total_quantity: 1,
    request_count: 1,
    avg_latency_ms: null,
    ...o,
  }));

const makeMonthSb = (buckets: ReturnType<typeof makeDailyBuckets>) =>
  makeMockSupabaseClient(buckets, { upsert: vi.fn() });

const ORG_UUID = '00000000-0000-4000-8000-000000000001';

describe('rollupMonthlyBucket', () => {
  it('queries usage_buckets_daily for correct org and month range', async () => {
    const sb = makeMonthSb([]);
    await rollupMonthlyBucket(ORG_UUID, '2026-03', sb as any);

    expect(sb.query).toHaveBeenCalledWith('usage_buckets_daily', expect.objectContaining({
      filters: expect.arrayContaining([
        { column: 'organization_id', operator: 'eq', value: ORG_UUID },
        { column: 'bucket_date', operator: 'gte', value: '2026-03-01' },
        { column: 'bucket_date', operator: 'lt', value: '2026-04-01' },
      ]),
    }));
  });

  it('handles December month rollover correctly', async () => {
    const sb = makeMonthSb([]);
    await rollupMonthlyBucket(ORG_UUID, '2026-12', sb as any);

    expect(sb.query).toHaveBeenCalledWith('usage_buckets_daily', expect.objectContaining({
      filters: expect.arrayContaining([
        { column: 'bucket_date', operator: 'gte', value: '2026-12-01' },
        { column: 'bucket_date', operator: 'lt', value: '2027-01-01' },
      ]),
    }));
  });

  it('returns zero totals and empty breakdown when no daily buckets', async () => {
    const sb = makeMonthSb([]);
    const result = await rollupMonthlyBucket(ORG_UUID, '2026-03', sb as any);

    expect(result.organization_id).toBe(ORG_UUID);
    expect(result.year_month).toBe('2026-03');
    expect(result.total_quantity).toBe(0);
    expect(result.total_requests).toBe(0);
    expect(result.avg_latency_ms).toBeNull();
    expect(result.metric_breakdown).toEqual({});
  });

  it('aggregates single metric across multiple days', async () => {
    const buckets = makeDailyBuckets([
      { total_quantity: 5, request_count: 5, avg_latency_ms: 100 },
      { total_quantity: 10, request_count: 10, avg_latency_ms: 200 },
      { total_quantity: 3, request_count: 3, avg_latency_ms: null },
    ]);
    const sb = makeMonthSb(buckets);
    const result = await rollupMonthlyBucket(ORG_UUID, '2026-03', sb as any);

    expect(result.total_quantity).toBe(18);
    expect(result.total_requests).toBe(18);
    expect(result.metric_breakdown['api_requests'].quantity).toBe(18);
    expect(result.metric_breakdown['api_requests'].requests).toBe(18);
    // weighted avg: (100*5 + 200*10) / (5+10) = (500 + 2000) / 15 = 166.67
    expect(result.metric_breakdown['api_requests'].avg_latency_ms).toBeCloseTo(166.67, 1);
  });

  it('aggregates multiple metrics into separate breakdown entries', async () => {
    const buckets = makeDailyBuckets([
      { metric_key: 'api_requests', total_quantity: 20, request_count: 20, avg_latency_ms: 50 },
      { metric_key: 'data_retention_days', total_quantity: 30, request_count: 1, avg_latency_ms: null },
      { metric_key: 'api_requests', total_quantity: 10, request_count: 10, avg_latency_ms: 100 },
    ]);
    const sb = makeMonthSb(buckets);
    const result = await rollupMonthlyBucket(ORG_UUID, '2026-03', sb as any);

    expect(result.total_quantity).toBe(60);
    expect(result.total_requests).toBe(31);

    const reqBreakdown = result.metric_breakdown['api_requests'];
    expect(reqBreakdown.quantity).toBe(30);
    expect(reqBreakdown.requests).toBe(30);
    // weighted avg: (50*20 + 100*10) / (20+10) = (1000 + 1000) / 30 ≈ 66.67
    expect(reqBreakdown.avg_latency_ms).toBeCloseTo(66.67, 1);

    const retBreakdown = result.metric_breakdown['data_retention_days'];
    expect(retBreakdown.quantity).toBe(30);
    expect(retBreakdown.requests).toBe(1);
    expect(retBreakdown.avg_latency_ms).toBeNull();
  });

  it('returns null avg_latency_ms when all daily buckets have null latency', async () => {
    const buckets = makeDailyBuckets([
      { total_quantity: 1, request_count: 1, avg_latency_ms: null },
      { total_quantity: 2, request_count: 2, avg_latency_ms: null },
    ]);
    const sb = makeMonthSb(buckets);
    const result = await rollupMonthlyBucket(ORG_UUID, '2026-03', sb as any);

    expect(result.avg_latency_ms).toBeNull();
    expect(result.metric_breakdown['api_requests'].avg_latency_ms).toBeNull();
  });

  it('throws for invalid yearMonth format', async () => {
    const sb = makeMonthSb([]);
    await expect(rollupMonthlyBucket(ORG_UUID, '2026-3', sb as any)).rejects.toThrow('invalid yearMonth format');
    await expect(rollupMonthlyBucket(ORG_UUID, '2026-03-01', sb as any)).rejects.toThrow('invalid yearMonth format');
    await expect(rollupMonthlyBucket(ORG_UUID, 'bad', sb as any)).rejects.toThrow('invalid yearMonth format');
    await expect(rollupMonthlyBucket(ORG_UUID, '2026-00', sb as any)).rejects.toThrow('invalid yearMonth format');
    await expect(rollupMonthlyBucket(ORG_UUID, '2026-13', sb as any)).rejects.toThrow('invalid yearMonth format');
  });

  it('throws when usage_buckets_daily query fails', async () => {
    const sb = {
      query: vi.fn().mockResolvedValue({ ok: false, error: 'DB error' }),
      insert: vi.fn(),
      update: vi.fn(),
      upsert: vi.fn(),
      rpc: vi.fn(),
    };
    await expect(rollupMonthlyBucket(ORG_UUID, '2026-03', sb as any)).rejects.toThrow(
      'usage_buckets_daily query failed',
    );
  });

  it('returns a Zod-validated MonthlyUsageSummary shape', async () => {
    const buckets = makeDailyBuckets([{ total_quantity: 5, request_count: 5, avg_latency_ms: 100 }]);
    const sb = makeMonthSb(buckets);
    const result = await rollupMonthlyBucket(ORG_UUID, '2026-03', sb as any);

    // Zod validation would throw on parse — reaching here confirms shape is valid
    expect(result.organization_id).toBe(ORG_UUID);
    expect(result.year_month).toBe('2026-03');
    expect(typeof result.created_at).toBe('string');
    expect(typeof result.updated_at).toBe('string');
  });

  it('MonthlyUsageSummarySchema rejects non-UUID organization_id and negative quantities', () => {
    const base = {
      organization_id: ORG_UUID,
      year_month: '2026-03',
      total_quantity: 0,
      total_requests: 0,
      avg_latency_ms: null,
      metric_breakdown: {},
      created_at: new Date().toISOString(),
      updated_at: new Date().toISOString(),
    };

    expect(MonthlyUsageSummarySchema.safeParse({ ...base, organization_id: 'not-a-uuid' }).success).toBe(false);
    expect(MonthlyUsageSummarySchema.safeParse({ ...base, total_quantity: -1 }).success).toBe(false);
    expect(MonthlyUsageSummarySchema.safeParse({ ...base, total_requests: -1 }).success).toBe(false);
  });

  it('truncates float total_quantity and request_count from DB rows to integers', async () => {
    const buckets = makeDailyBuckets([
      { total_quantity: 5.7, request_count: 3.9, avg_latency_ms: null },
      { total_quantity: 2.2, request_count: 1.1, avg_latency_ms: null },
    ]);
    const sb = makeMonthSb(buckets);
    const result = await rollupMonthlyBucket(ORG_UUID, '2026-03', sb as any);

    // Math.trunc(5.7) + Math.trunc(2.2) = 5 + 2 = 7
    expect(result.total_quantity).toBe(7);
    // Math.trunc(3.9) + Math.trunc(1.1) = 3 + 1 = 4
    expect(result.total_requests).toBe(4);
    // Zod int() check passes — no throw
    expect(Number.isInteger(result.total_quantity)).toBe(true);
    expect(Number.isInteger(result.total_requests)).toBe(true);
  });

  it('uses truncated request_count as latency weight to keep weighted average consistent', async () => {
    const buckets = makeDailyBuckets([
      // float request_count should be truncated before weighting: trunc(9.9) = 9
      { total_quantity: 10, request_count: 9.9, avg_latency_ms: 100 },
    ]);
    const sb = makeMonthSb(buckets);
    const result = await rollupMonthlyBucket(ORG_UUID, '2026-03', sb as any);

    // weighted sum = 100 * trunc(9.9) = 100 * 9 = 900; count = 9; avg = 100
    expect(result.avg_latency_ms).toBeCloseTo(100, 5);
    expect(result.total_requests).toBe(9);
  });
});
