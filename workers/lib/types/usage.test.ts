import { describe, it, expect } from 'vitest';
import {
  UsageEventSourceSchema,
  IngestEventRequestSchema,
  MonthlyUsageSummarySchema,
  OtelSpanSchema,
  IngestOtelRequestSchema,
} from './usage';

const ORG_UUID = '550e8400-e29b-41d4-a716-446655440001';

describe('UsageEventSourceSchema', () => {
  it('accepts all valid sources', () => {
    for (const s of ['api', 'ingest', 'job', 'internal', 'migration']) {
      expect(UsageEventSourceSchema.safeParse(s).success).toBe(true);
    }
  });

  it('rejects unknown source', () => {
    expect(UsageEventSourceSchema.safeParse('webhook').success).toBe(false);
  });
});

describe('IngestEventRequestSchema', () => {
  const valid = {
    org_id: ORG_UUID,
    metric_key: 'api_calls',
  };

  it('accepts valid ingest request', () => {
    expect(IngestEventRequestSchema.safeParse(valid).success).toBe(true);
  });

  it('defaults quantity to 1', () => {
    const r = IngestEventRequestSchema.safeParse(valid);
    expect(r.success).toBe(true);
    if (r.success) expect(r.data.quantity).toBe(1);
  });

  it('defaults source to "api"', () => {
    const r = IngestEventRequestSchema.safeParse(valid);
    expect(r.success).toBe(true);
    if (r.success) expect(r.data.source).toBe('api');
  });

  it('rejects non-uuid org_id', () => {
    expect(IngestEventRequestSchema.safeParse({ ...valid, org_id: 'not-a-uuid' }).success).toBe(false);
  });

  it('rejects invalid source', () => {
    expect(IngestEventRequestSchema.safeParse({ ...valid, source: 'external' }).success).toBe(false);
  });
});

describe('MonthlyUsageSummarySchema', () => {
  const valid = {
    organization_id: ORG_UUID,
    year_month: '2024-01',
    total_quantity: 1000,
    total_requests: 1000,
    avg_latency_ms: null,
    metric_breakdown: {
      api_calls: { quantity: 1000, requests: 1000, avg_latency_ms: null },
    },
    created_at: '2024-01-01T00:00:00.000Z',
    updated_at: '2024-01-31T00:00:00.000Z',
  };

  it('accepts a valid monthly summary', () => {
    expect(MonthlyUsageSummarySchema.safeParse(valid).success).toBe(true);
  });

  it('rejects invalid year_month format', () => {
    expect(MonthlyUsageSummarySchema.safeParse({ ...valid, year_month: '2024-13' }).success).toBe(false);
  });

  it('accepts month 12', () => {
    expect(MonthlyUsageSummarySchema.safeParse({ ...valid, year_month: '2024-12' }).success).toBe(true);
  });

  it('rejects month 00', () => {
    expect(MonthlyUsageSummarySchema.safeParse({ ...valid, year_month: '2024-00' }).success).toBe(false);
  });
});

describe('OtelSpanSchema', () => {
  const valid = {
    trace_id: 'abcd1234',
    span_id: 'efgh5678',
    name: 'my-span',
    start_time_ms: Date.now() - 1000,
    duration_ms: 50,
  };

  it('accepts a valid span', () => {
    expect(OtelSpanSchema.safeParse(valid).success).toBe(true);
  });

  it('defaults status to "unset"', () => {
    const r = OtelSpanSchema.safeParse(valid);
    expect(r.success).toBe(true);
    if (r.success) expect(r.data.status).toBe('unset');
  });

  it('accepts valid status values', () => {
    for (const s of ['ok', 'error', 'unset']) {
      expect(OtelSpanSchema.safeParse({ ...valid, status: s }).success).toBe(true);
    }
  });

  it('rejects invalid status', () => {
    expect(OtelSpanSchema.safeParse({ ...valid, status: 'warning' }).success).toBe(false);
  });

  it('rejects start_time_ms more than 1 day in the future', () => {
    const tooFar = Date.now() + 25 * 60 * 60 * 1000;
    expect(OtelSpanSchema.safeParse({ ...valid, start_time_ms: tooFar }).success).toBe(false);
  });

  it('rejects attributes with more than 64 keys', () => {
    const attrs: Record<string, string> = {};
    for (let i = 0; i < 65; i++) attrs[`key_${i}`] = 'val';
    expect(OtelSpanSchema.safeParse({ ...valid, attributes: attrs }).success).toBe(false);
  });

  it('accepts attributes with up to 64 keys', () => {
    const attrs: Record<string, string> = {};
    for (let i = 0; i < 64; i++) attrs[`key_${i}`] = 'val';
    expect(OtelSpanSchema.safeParse({ ...valid, attributes: attrs }).success).toBe(true);
  });

  it('rejects attribute string values over 256 chars', () => {
    expect(OtelSpanSchema.safeParse({ ...valid, attributes: { key: 'a'.repeat(257) } }).success).toBe(false);
  });

  it('accepts attribute boolean and number values', () => {
    expect(OtelSpanSchema.safeParse({ ...valid, attributes: { flag: true, count: 42 } }).success).toBe(true);
  });
});

describe('IngestOtelRequestSchema', () => {
  const span = {
    trace_id: 'trace1',
    span_id: 'span1',
    name: 'test-span',
    start_time_ms: Date.now() - 1000,
    duration_ms: 10,
  };

  it('accepts 1 span', () => {
    expect(IngestOtelRequestSchema.safeParse({ spans: [span] }).success).toBe(true);
  });

  it('rejects empty spans array', () => {
    expect(IngestOtelRequestSchema.safeParse({ spans: [] }).success).toBe(false);
  });

  it('rejects more than 1000 spans', () => {
    const spans = Array.from({ length: 1001 }, () => span);
    expect(IngestOtelRequestSchema.safeParse({ spans }).success).toBe(false);
  });
});
