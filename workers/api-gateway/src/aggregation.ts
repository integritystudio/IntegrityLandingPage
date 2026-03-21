import type { SupabaseClient } from '../../lib/supabase';
import type { UsageFlushResult } from '../../lib/types/usage';

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
export async function rollupDailyBucket(
  orgId: string,
  date: string, // YYYY-MM-DD
  sb: SupabaseClient,
): Promise<UsageFlushResult> {
  const periodStart = new Date(`${date}T00:00:00.000Z`);
  const periodEnd = new Date(periodStart.getTime() + 24 * 60 * 60 * 1000);

  const result = await sb.query<UsageEventRow>('usage_events', {
    select: 'organization_id, metric_key, quantity, latency_ms',
    filters: [
      { column: 'organization_id', operator: 'eq', value: orgId },
      { column: 'created_at', operator: 'gte', value: periodStart.toISOString() },
      { column: 'created_at', operator: 'lt', value: periodEnd.toISOString() },
    ],
  });

  const events: UsageEventRow[] =
    result.ok && Array.isArray(result.data) ? result.data : [];

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
    const upsertResult = await sb.upsert(
      'usage_buckets_daily',
      buckets,
      'organization_id,bucket_date,metric_key',
    );
    if (upsertResult.ok) {
      bucketsUpdated = buckets.length;
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
