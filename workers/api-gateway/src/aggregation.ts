import type { SupabaseClient } from '../../lib/supabase';
import type { UsageFlushResult } from '../../lib/types/usage';
import { MonthlyUsageSummarySchema, type MonthlyUsageSummary } from '../../lib/types/usage';
import { MS_PER_DAY } from '../../lib/constants';
// Capped to avoid unbounded memory usage; high-volume orgs should use a DB-side RPC rollup.
const MAX_EVENTS_PER_ROLLUP = 10_000;
// 31 days × 100 metric keys — bounded because metric_key cardinality is low by design
// (predefined keys like 'api_requests', 'data_retention_days'). Adjust if dynamic keys are added.
const MAX_DAILY_BUCKETS_PER_MONTH = 31 * 100;

interface UsageEventRow extends Record<string, unknown> {
  organization_id: string;
  metric_key: string;
  quantity: number;
  latency_ms: number | null;
}

interface BucketAggregate {
  total_quantity: number;
  request_count: number;
  total_latency_ms: number;
  latency_count: number;
}

/**
 * Reads usage_events for the given org and date, aggregates by metric_key,
 * and upserts results into usage_buckets_daily.
 *
 * Safe to call multiple times for the same org/date — upsert on
 * (organization_id, bucket_date, metric_key) keeps the latest rollup.
 */
const DATE_RE = /^\d{4}-\d{2}-\d{2}$/;
const YEAR_MONTH_RE = /^\d{4}-(0[1-9]|1[0-2])$/;

export async function rollupDailyBucket(
  orgId: string,
  date: string, // YYYY-MM-DD UTC
  sb: SupabaseClient,
): Promise<UsageFlushResult> {
  if (!DATE_RE.test(date)) throw new Error(`[aggregation] invalid date format: ${date}`);
  const periodStart = new Date(`${date}T00:00:00.000Z`);
  const periodEnd = new Date(periodStart.getTime() + MS_PER_DAY);

  const result = await sb.query<UsageEventRow>('usage_events', {
    select: 'organization_id, metric_key, quantity, latency_ms',
    filters: [
      { column: 'organization_id', operator: 'eq', value: orgId },
      { column: 'created_at', operator: 'gte', value: periodStart.toISOString() },
      { column: 'created_at', operator: 'lt', value: periodEnd.toISOString() },
    ],
    limit: MAX_EVENTS_PER_ROLLUP,
  });

  if (!result.ok) {
    throw new Error(`[aggregation] usage_events query failed: ${String(result.error)}`);
  }

  const events: UsageEventRow[] = result.data;
  if (events.length >= MAX_EVENTS_PER_ROLLUP) {
    console.warn(`[aggregation] rollupDailyBucket: event query hit limit (${MAX_EVENTS_PER_ROLLUP}) for org=${orgId} date=${date}; aggregation may be incomplete`);
  }

  const aggregates = new Map<string, BucketAggregate>();
  for (const event of events) {
    const existing = aggregates.get(event.metric_key) ?? {
      total_quantity: 0,
      request_count: 0,
      total_latency_ms: 0,
      latency_count: 0,
    };
    aggregates.set(event.metric_key, {
      total_quantity: existing.total_quantity + event.quantity,
      request_count: existing.request_count + 1,
      total_latency_ms: existing.total_latency_ms + (event.latency_ms ?? 0),
      latency_count: existing.latency_count + (event.latency_ms !== null ? 1 : 0),
    });
  }

  const now = new Date().toISOString();
  const buckets = Array.from(aggregates.entries()).map(([metric_key, agg]) => ({
    organization_id: orgId,
    bucket_date: date,
    metric_key,
    total_quantity: agg.total_quantity,
    request_count: agg.request_count,
    avg_latency_ms: agg.latency_count > 0 ? agg.total_latency_ms / agg.latency_count : null,
    updated_at: now,
  }));

  let bucketsUpdated = 0;
  if (buckets.length > 0) {
    const upsertResult = await sb.upsert('usage_buckets_daily', buckets, 'organization_id,bucket_date,metric_key');
    if (upsertResult.ok) {
      bucketsUpdated = buckets.length;
    } else {
      console.error('[aggregation] usage_buckets_daily upsert failed', upsertResult.error);
    }
  }

  return {
    organization_id: orgId,
    events_processed: events.length,
    buckets_updated: bucketsUpdated,
    period: {
      start_date: periodStart.toISOString(),
      end_date: periodEnd.toISOString(),
    },
    flushed_at: now,
  };
}

interface DailyBucketRow extends Record<string, unknown> {
  organization_id: string;
  metric_key: string;
  total_quantity: number;
  request_count: number;
  avg_latency_ms: number | null;
}

interface MonthlyMetricAgg {
  total_quantity: number;
  request_count: number;
  weighted_latency_sum: number;
  weighted_latency_count: number;
}

/**
 * Reads usage_buckets_daily for the given org and year-month, aggregates by
 * metric_key across all days in the period, and returns a MonthlyUsageSummary.
 *
 * avg_latency_ms is weighted by request_count per daily bucket.
 * This is an approximation because daily buckets store avg rather than sum,
 * but it is consistent and avoids querying raw events for large date ranges.
 */
export async function rollupMonthlyBucket(
  orgId: string,
  yearMonth: string, // YYYY-MM UTC
  sb: SupabaseClient,
): Promise<MonthlyUsageSummary> {
  if (!YEAR_MONTH_RE.test(yearMonth)) {
    throw new Error(`[aggregation] invalid yearMonth format: ${yearMonth}`);
  }

  const periodStart = `${yearMonth}-01`;
  const [year, month] = yearMonth.split('-').map(Number);
  const nextYear = month === 12 ? year + 1 : year;
  const nextMonth = month === 12 ? 1 : month + 1;
  const periodEnd = `${nextYear}-${String(nextMonth).padStart(2, '0')}-01`;

  const result = await sb.query<DailyBucketRow>('usage_buckets_daily', {
    select: 'organization_id, metric_key, total_quantity, request_count, avg_latency_ms',
    filters: [
      { column: 'organization_id', operator: 'eq', value: orgId },
      { column: 'bucket_date', operator: 'gte', value: periodStart },
      { column: 'bucket_date', operator: 'lt', value: periodEnd },
    ],
    limit: MAX_DAILY_BUCKETS_PER_MONTH,
  });

  if (!result.ok) {
    throw new Error(`[aggregation] usage_buckets_daily query failed: ${String(result.error)}`);
  }

  const buckets: DailyBucketRow[] = result.data;
  if (buckets.length >= MAX_DAILY_BUCKETS_PER_MONTH) {
    console.warn(`[aggregation] rollupMonthlyBucket: bucket query hit limit (${MAX_DAILY_BUCKETS_PER_MONTH}) for org=${orgId} yearMonth=${yearMonth}; aggregation may be incomplete`);
  }

  // Math.trunc guards against float values from faulty DB migrations; MonthlyUsageSummarySchema requires int().
  // The truncated request_count is used as the latency weight to keep all arithmetic consistent.
  const aggregates = new Map<string, MonthlyMetricAgg>();
  for (const bucket of buckets) {
    const existing = aggregates.get(bucket.metric_key) ?? {
      total_quantity: 0,
      request_count: 0,
      weighted_latency_sum: 0,
      weighted_latency_count: 0,
    };
    const reqCount = Math.trunc(bucket.request_count);
    aggregates.set(bucket.metric_key, {
      total_quantity: existing.total_quantity + Math.trunc(bucket.total_quantity),
      request_count: existing.request_count + reqCount,
      weighted_latency_sum: existing.weighted_latency_sum +
        (bucket.avg_latency_ms !== null ? bucket.avg_latency_ms * reqCount : 0),
      weighted_latency_count: existing.weighted_latency_count +
        (bucket.avg_latency_ms !== null ? reqCount : 0),
    });
  }

  const now = new Date().toISOString();
  let total_quantity = 0;
  let total_requests = 0;
  let weightedLatencySum = 0;
  let weightedLatencyCount = 0;
  const metric_breakdown: Record<string, { quantity: number; requests: number; avg_latency_ms: number | null }> = {};

  for (const [metric_key, agg] of aggregates.entries()) {
    total_quantity += agg.total_quantity;
    total_requests += agg.request_count;
    weightedLatencySum += agg.weighted_latency_sum;
    weightedLatencyCount += agg.weighted_latency_count;
    metric_breakdown[metric_key] = {
      quantity: agg.total_quantity,
      requests: agg.request_count,
      avg_latency_ms: agg.weighted_latency_count > 0
        ? agg.weighted_latency_sum / agg.weighted_latency_count
        : null,
    };
  }

  return MonthlyUsageSummarySchema.parse({
    organization_id: orgId,
    year_month: yearMonth,
    total_quantity,
    total_requests,
    // Cross-metric weighted mean — meaningful only for homogeneous metric sets.
    // Prefer metric_breakdown[key].avg_latency_ms for per-metric analysis.
    avg_latency_ms: weightedLatencyCount > 0 ? weightedLatencySum / weightedLatencyCount : null,
    metric_breakdown,
    created_at: now,
    updated_at: now,
  });
}
