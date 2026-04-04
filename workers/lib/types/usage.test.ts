import { describe, it, expect } from 'vitest';
import {
  UsageEventSourceSchema,
  UsageEventSchema,
  UsageEventIngestionSchema,
  IngestEventRequestSchema,
  IngestEventResponseSchema,
  UsageBucketSchema,
  MonthlyUsageSummarySchema,
  UsageQueryResponseSchema,
  OtelSpanSchema,
  IngestOtelRequestSchema,
  IngestOtelMetadataSchema,
  IngestOtelResponseSchema,
  UsageFlushResultSchema,
} from './usage';

const ORG_UUID = '550e8400-e29b-41d4-a716-446655440001';
const USER_UUID = '550e8400-e29b-41d4-a716-446655440002';
const REQ_UUID = '550e8400-e29b-41d4-a716-446655440003';

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

describe('UsageEventSchema', () => {
  const valid = {
    id: 1,
    organization_id: ORG_UUID,
    user_id: USER_UUID,
    api_key_id: null,
    route: '/v1/ingest',
    metric_key: 'api_calls',
    quantity: 1,
    request_id: 'req-abc',
    source: 'api',
    status_code: 200,
    latency_ms: 45,
    metadata: {},
    created_at: '2024-01-01T00:00:00.000Z',
  };

  it('accepts a valid usage event', () => {
    expect(UsageEventSchema.safeParse(valid).success).toBe(true);
  });

  it('rejects id of 0 (must be positive)', () => {
    expect(UsageEventSchema.safeParse({ ...valid, id: 0 }).success).toBe(false);
  });

  it('rejects negative quantity', () => {
    expect(UsageEventSchema.safeParse({ ...valid, quantity: 0 }).success).toBe(false);
  });

  it('rejects status_code below 100', () => {
    expect(UsageEventSchema.safeParse({ ...valid, status_code: 99 }).success).toBe(false);
  });

  it('rejects status_code above 599', () => {
    expect(UsageEventSchema.safeParse({ ...valid, status_code: 600 }).success).toBe(false);
  });

  it('accepts null user_id and api_key_id', () => {
    expect(UsageEventSchema.safeParse({ ...valid, user_id: null, api_key_id: null }).success).toBe(true);
  });

  it('defaults metadata to {}', () => {
    const { metadata: _m, ...noMeta } = valid;
    const r = UsageEventSchema.safeParse(noMeta);
    expect(r.success).toBe(true);
    if (r.success) expect(r.data.metadata).toEqual({});
  });
});

describe('UsageEventIngestionSchema', () => {
  it('accepts minimal valid ingestion event', () => {
    expect(UsageEventIngestionSchema.safeParse({ metric_key: 'api_calls' }).success).toBe(true);
  });

  it('defaults quantity to 1', () => {
    const r = UsageEventIngestionSchema.safeParse({ metric_key: 'api_calls' });
    expect(r.success).toBe(true);
    if (r.success) expect(r.data.quantity).toBe(1);
  });

  it('rejects empty metric_key', () => {
    expect(UsageEventIngestionSchema.safeParse({ metric_key: '' }).success).toBe(false);
  });

  it('rejects metric_key longer than 128 chars', () => {
    expect(UsageEventIngestionSchema.safeParse({ metric_key: 'a'.repeat(129) }).success).toBe(false);
  });

  it('rejects latency_ms exceeding 300000', () => {
    expect(UsageEventIngestionSchema.safeParse({ metric_key: 'k', latency_ms: 300_001 }).success).toBe(false);
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

describe('IngestEventResponseSchema', () => {
  it('accepts valid response', () => {
    expect(IngestEventResponseSchema.safeParse({ ok: true, request_id: REQ_UUID }).success).toBe(true);
  });

  it('rejects non-uuid request_id', () => {
    expect(IngestEventResponseSchema.safeParse({ ok: true, request_id: 'req-123' }).success).toBe(false);
  });
});

describe('UsageBucketSchema (usage.ts)', () => {
  const valid = {
    organization_id: ORG_UUID,
    bucket_date: '2024-01-15',
    metric_key: 'api_calls',
    total_quantity: 500,
    request_count: 500,
    avg_latency_ms: 120.5,
    updated_at: '2024-01-15T23:59:59.000Z',
  };

  it('accepts a valid bucket', () => {
    expect(UsageBucketSchema.safeParse(valid).success).toBe(true);
  });

  it('rejects invalid date format', () => {
    expect(UsageBucketSchema.safeParse({ ...valid, bucket_date: '2024/01/15' }).success).toBe(false);
  });

  it('accepts null avg_latency_ms', () => {
    expect(UsageBucketSchema.safeParse({ ...valid, avg_latency_ms: null }).success).toBe(true);
  });

  it('rejects negative total_quantity', () => {
    expect(UsageBucketSchema.safeParse({ ...valid, total_quantity: -1 }).success).toBe(false);
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

describe('UsageQueryResponseSchema', () => {
  const valid = {
    organization_id: ORG_UUID,
    period_start: '2024-01-01T00:00:00.000Z',
    period_end: '2024-01-31T23:59:59.000Z',
    buckets: [],
    total_quantity: 0,
    total_requests: 0,
    avg_latency_ms: null,
  };

  it('accepts a valid query response', () => {
    expect(UsageQueryResponseSchema.safeParse(valid).success).toBe(true);
  });

  it('rejects invalid period_start', () => {
    expect(UsageQueryResponseSchema.safeParse({ ...valid, period_start: '2024-01-01' }).success).toBe(false);
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

describe('IngestOtelMetadataSchema', () => {
  const span = {
    trace_id: 'trace1',
    span_id: 'span1',
    name: 'test-span',
    start_time_ms: Date.now() - 1000,
    duration_ms: 10,
  };

  it('accepts valid metadata', () => {
    expect(IngestOtelMetadataSchema.safeParse({ span_count: 1, spans: [span] }).success).toBe(true);
  });

  it('rejects negative span_count', () => {
    expect(IngestOtelMetadataSchema.safeParse({ span_count: -1, spans: [] }).success).toBe(false);
  });
});

describe('IngestOtelResponseSchema', () => {
  it('accepts valid response', () => {
    expect(IngestOtelResponseSchema.safeParse({ ok: true, request_id: REQ_UUID, span_count: 5 }).success).toBe(true);
  });

  it('rejects ok: false', () => {
    expect(IngestOtelResponseSchema.safeParse({ ok: false, request_id: REQ_UUID, span_count: 5 }).success).toBe(false);
  });

  it('rejects span_count of 0', () => {
    expect(IngestOtelResponseSchema.safeParse({ ok: true, request_id: REQ_UUID, span_count: 0 }).success).toBe(false);
  });
});

describe('UsageFlushResultSchema', () => {
  const valid = {
    organization_id: ORG_UUID,
    events_processed: 100,
    buckets_updated: 5,
    period: {
      start_date: '2024-01-01T00:00:00.000Z',
      end_date: '2024-01-31T23:59:59.000Z',
    },
    flushed_at: '2024-01-31T23:59:59.000Z',
  };

  it('accepts a valid flush result', () => {
    expect(UsageFlushResultSchema.safeParse(valid).success).toBe(true);
  });

  it('rejects negative events_processed', () => {
    expect(UsageFlushResultSchema.safeParse({ ...valid, events_processed: -1 }).success).toBe(false);
  });

  it('rejects invalid flushed_at', () => {
    expect(UsageFlushResultSchema.safeParse({ ...valid, flushed_at: '2024-01-31' }).success).toBe(false);
  });
});
