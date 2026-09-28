-- CR43: the ledger trigger becomes the only writer of usage_buckets_daily.
--
-- Until now two writers owned the same row: trigger_upsert_daily_usage_bucket
-- incremented it on every usage_events insert, and api-gateway's
-- rollupDailyBucket then overwrote it with a recount capped at 10 000 events.
-- Past the cap the busiest days were reported short, and within one request the
-- two raced. The Worker-side rollup is deleted in the same change; this
-- migration makes the trigger correct enough to stand alone:
--
--   1. avg_latency_ms is averaged over latency samples, not requests. The old
--      formula, (avg * request_count + new.latency_ms) / (request_count + 1),
--      went NULL on the first event without a latency and stayed NULL. The
--      rollup's overwrite hid that; /v1/ingest/otel always inserts a NULL
--      latency. latency_sample_count carries the weight the average needs.
--   2. The bucket date is the UTC day, matching what the rollup wrote and what
--      /v1/orgs/:id/usage queries, whatever the session timezone.
--   3. Every bucket the ledger can vouch for is recomputed from it, so drift
--      left by the old overwrite is corrected. A bucket with no events is left
--      alone: the ledger has nothing to say about it.
--
-- Apply BEFORE deploying the api-gateway that drops the rollup. The reverse
-- order runs the old NULL-prone average with nothing overwriting it.

alter table public.usage_buckets_daily
  add column if not exists latency_sample_count bigint not null default 0;

comment on column public.usage_buckets_daily.latency_sample_count is
  'CR43: events in this bucket with a non-null latency_ms; the weight of avg_latency_ms. Maintained by upsert_daily_usage_bucket.';

create or replace function public.upsert_daily_usage_bucket()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  insert into public.usage_buckets_daily as b
    (organization_id, bucket_date, metric_key, total_quantity, request_count, avg_latency_ms, latency_sample_count)
  values (
    new.organization_id,
    (new.created_at at time zone 'UTC')::date,
    new.metric_key,
    new.quantity,
    1,
    new.latency_ms::numeric,
    case when new.latency_ms is null then 0 else 1 end
  )
  on conflict (organization_id, bucket_date, metric_key)
  do update set
    total_quantity = b.total_quantity + excluded.total_quantity,
    request_count = b.request_count + 1,
    avg_latency_ms = case
      when excluded.avg_latency_ms is null then b.avg_latency_ms
      else (coalesce(b.avg_latency_ms, 0) * b.latency_sample_count + excluded.avg_latency_ms)
           / (b.latency_sample_count + 1)
    end,
    latency_sample_count = b.latency_sample_count + excluded.latency_sample_count,
    updated_at = now();
  return new;
end;
$$;

insert into public.usage_buckets_daily as b
  (organization_id, bucket_date, metric_key, total_quantity, request_count, avg_latency_ms, latency_sample_count)
select organization_id,
       (created_at at time zone 'UTC')::date,
       metric_key,
       sum(quantity),
       count(*),
       avg(latency_ms),
       count(latency_ms)
  from public.usage_events
 group by 1, 2, 3
on conflict (organization_id, bucket_date, metric_key)
do update set
  total_quantity = excluded.total_quantity,
  request_count = excluded.request_count,
  avg_latency_ms = excluded.avg_latency_ms,
  latency_sample_count = excluded.latency_sample_count,
  updated_at = now()
where (b.total_quantity, b.request_count, b.avg_latency_ms, b.latency_sample_count)
      is distinct from
      (excluded.total_quantity, excluded.request_count, excluded.avg_latency_ms, excluded.latency_sample_count);
