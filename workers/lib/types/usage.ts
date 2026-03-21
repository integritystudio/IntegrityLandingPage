import { z } from 'zod';

/**
 * Usage Event Tracking
 * API request metering and quota consumption
 */

export const UsageEventSourceSchema = z.enum(['api', 'ingest', 'job', 'internal', 'migration']);

export type UsageEventSource = z.infer<typeof UsageEventSourceSchema>;

export const UsageEventSchema = z.object({
  id: z.number().int().positive(),
  organization_id: z.string().uuid(),
  user_id: z.string().uuid().nullable(),
  api_key_id: z.string().uuid().nullable(),
  route: z.string().min(1),
  metric_key: z.string().min(1),
  quantity: z.number().int().positive(),
  request_id: z.string().min(1),
  source: UsageEventSourceSchema,
  status_code: z.number().int().min(100).max(599).nullable(),
  latency_ms: z.number().int().nonnegative().nullable(),
  metadata: z.record(z.unknown()).default({}),
  created_at: z.string().datetime(),
});

export type UsageEvent = z.infer<typeof UsageEventSchema>;

/**
 * Request to ingest a usage event
 * Minimal shape for edge worker ingestion (without org_id)
 */
export const UsageEventIngestionSchema = z.object({
  metric_key: z.string().min(1).max(128),
  quantity: z.number().int().positive().default(1),
  route: z.string().min(1).optional(),
  status_code: z.number().int().min(100).max(599).optional(),
  latency_ms: z.number().int().min(0).max(300_000).optional(),
  metadata: z.record(z.unknown()).optional(),
});

export type UsageEventIngestion = z.infer<typeof UsageEventIngestionSchema>;

/**
 * Ingest request payload with organization context
 * Used by POST /v1/ingest/events endpoint
 */
export const IngestEventRequestSchema = z.object({
  org_id: z.string().uuid(),
  metric_key: z.string().min(1).max(128),
  quantity: z.number().int().positive().default(1),
  source: UsageEventSourceSchema.default('api'),
  route: z.string().min(1).optional(),
  status_code: z.number().int().min(100).max(599).optional(),
  latency_ms: z.number().int().min(0).max(300_000).optional(),
  metadata: z.record(z.unknown()).optional(),
});

export type IngestEventRequest = z.infer<typeof IngestEventRequestSchema>;

/**
 * Ingest response (fire-and-forget)
 */
export const IngestEventResponseSchema = z.object({
  ok: z.boolean(),
  request_id: z.string().uuid(),
});

export type IngestEventResponse = z.infer<typeof IngestEventResponseSchema>;

/**
 * Daily usage bucket (aggregated metrics)
 * Pre-computed rollups for efficient querying
 */
export const UsageBucketSchema = z.object({
  organization_id: z.string().uuid(),
  bucket_date: z.string().regex(/^\d{4}-\d{2}-\d{2}$/, 'Date must be YYYY-MM-DD'),
  metric_key: z.string().min(1),
  total_quantity: z.number().int().nonnegative(),
  request_count: z.number().int().nonnegative(),
  avg_latency_ms: z.number().nonnegative().nullable(),
  updated_at: z.string().datetime(),
});

export type UsageBucket = z.infer<typeof UsageBucketSchema>;

/**
 * Monthly usage rollup summary
 * High-level view of org usage within a billing period
 */
export const MonthlyUsageSummarySchema = z.object({
  organization_id: z.string().uuid(),
  year_month: z.string().regex(/^\d{4}-(0[1-9]|1[0-2])$/, 'Date must be YYYY-MM (month 01–12)'),
  total_quantity: z.number().int().nonnegative(),
  total_requests: z.number().int().nonnegative(),
  avg_latency_ms: z.number().nonnegative().nullable(),
  metric_breakdown: z.record(
    z.object({
      quantity: z.number().int().nonnegative(),
      requests: z.number().int().nonnegative(),
      avg_latency_ms: z.number().nonnegative().nullable(),
    })
  ),
  created_at: z.string().datetime(),
  updated_at: z.string().datetime(),
});

export type MonthlyUsageSummary = z.infer<typeof MonthlyUsageSummarySchema>;

/**
 * Usage query response with pagination
 */
export const UsageQueryResponseSchema = z.object({
  organization_id: z.string().uuid(),
  period_start: z.string().datetime(),
  period_end: z.string().datetime(),
  buckets: z.array(UsageBucketSchema),
  total_quantity: z.number().int().nonnegative(),
  total_requests: z.number().int().nonnegative(),
  avg_latency_ms: z.number().nonnegative().nullable(),
});

export type UsageQueryResponse = z.infer<typeof UsageQueryResponseSchema>;

/**
 * OpenTelemetry span (simplified OTLP-compatible shape)
 * Used by POST /v1/ingest/otel for service telemetry ingestion
 */
export const OtelSpanSchema = z.object({
  trace_id: z.string().min(1).max(64),
  span_id: z.string().min(1).max(32),
  name: z.string().min(1).max(256),
  start_time_ms: z.number().int().nonnegative(),
  duration_ms: z.number().int().nonnegative(),
  status: z.enum(['ok', 'error', 'unset']).default('unset'),
  attributes: z.record(
    z.union([z.string().max(256), z.number(), z.boolean()])
  ).refine(
    r => Object.keys(r).length <= 64,
    { message: 'attributes must have at most 64 keys' },
  ).optional(),
});

export type OtelSpan = z.infer<typeof OtelSpanSchema>;

export const IngestOtelRequestSchema = z.object({
  spans: z.array(OtelSpanSchema).min(1).max(1_000),
});

export type IngestOtelRequest = z.infer<typeof IngestOtelRequestSchema>;

/**
 * Usage flush operation (periodic aggregation)
 * Moves event data from usage_events into usage_buckets_daily and monthly rollups
 */
export const UsageFlushResultSchema = z.object({
  organization_id: z.string().uuid(),
  events_processed: z.number().int().nonnegative(),
  buckets_updated: z.number().int().nonnegative(),
  period: z.object({
    start_date: z.string().datetime(),
    end_date: z.string().datetime(),
  }),
  flushed_at: z.string().datetime(),
});

export type UsageFlushResult = z.infer<typeof UsageFlushResultSchema>;
