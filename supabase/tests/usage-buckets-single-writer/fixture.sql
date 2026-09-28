-- Fixture for the usage-buckets single-writer migration test (CR43).
--
-- Only the slice the migration touches: usage_events, usage_buckets_daily in
-- its pre-CR43 shape, and the ORIGINAL trigger (verbatim from
-- 20260320020001_phase2_setup_ledger_triggers.sql), so the migration is tested
-- replacing it. Rows are seeded through that old trigger and then drifted the
-- way the Worker rollup drifted them, so the backfill is exercised on real damage.

create table public.organizations (id uuid primary key);

create table public.usage_events (
  id bigint generated always as identity primary key,
  organization_id uuid not null references public.organizations(id) on delete cascade,
  metric_key text not null,
  quantity bigint not null default 1,
  latency_ms integer,
  created_at timestamptz not null default now()
);

create table public.usage_buckets_daily (
  organization_id uuid not null references public.organizations(id) on delete cascade,
  bucket_date date not null,
  metric_key text not null,
  total_quantity bigint not null default 0,
  request_count bigint not null default 0,
  avg_latency_ms numeric,
  updated_at timestamptz not null default now(),
  primary key (organization_id, bucket_date, metric_key)
);

create or replace function upsert_daily_usage_bucket()
returns trigger as $$
begin
  insert into usage_buckets_daily (organization_id, bucket_date, metric_key, total_quantity, request_count, avg_latency_ms)
  values (
    new.organization_id,
    new.created_at::date,
    new.metric_key,
    new.quantity,
    1,
    new.latency_ms::numeric
  )
  on conflict (organization_id, bucket_date, metric_key)
  do update set
    total_quantity = usage_buckets_daily.total_quantity + new.quantity,
    request_count = usage_buckets_daily.request_count + 1,
    avg_latency_ms = (
      (usage_buckets_daily.avg_latency_ms * usage_buckets_daily.request_count + new.latency_ms) /
      (usage_buckets_daily.request_count + 1)
    ),
    updated_at = now();
  return new;
end;
$$ language plpgsql;

create trigger trigger_upsert_daily_usage_bucket
  after insert on public.usage_events
  for each row
  execute function upsert_daily_usage_bucket();

set timezone = 'UTC';

insert into public.organizations (id) values ('00000000-0000-0000-0000-00000000000a');

-- 'drifted': three events, 15 units, latencies 100/200/300. The old trigger gets
-- this right; the UPDATE below is the rollup's capped recount overwriting it.
insert into public.usage_events (organization_id, metric_key, quantity, latency_ms, created_at) values
  ('00000000-0000-0000-0000-00000000000a', 'api_requests', 5, 100, '2026-09-20 10:00Z'),
  ('00000000-0000-0000-0000-00000000000a', 'api_requests', 5, 200, '2026-09-20 11:00Z'),
  ('00000000-0000-0000-0000-00000000000a', 'api_requests', 5, 300, '2026-09-20 12:00Z');
update public.usage_buckets_daily set total_quantity = 10, request_count = 2
 where metric_key = 'api_requests' and bucket_date = '2026-09-20';

-- 'poisoned': a NULL latency first (as /v1/ingest/otel always sends), then 50.
-- The old average goes NULL on the first row and stays NULL.
insert into public.usage_events (organization_id, metric_key, quantity, latency_ms, created_at) values
  ('00000000-0000-0000-0000-00000000000a', 'otel_spans', 4, null, '2026-09-21 10:00Z'),
  ('00000000-0000-0000-0000-00000000000a', 'otel_spans', 1, 50,   '2026-09-21 11:00Z');

-- 'orphan': a bucket with no ledger events behind it.
insert into public.usage_buckets_daily (organization_id, bucket_date, metric_key, total_quantity, request_count, avg_latency_ms)
values ('00000000-0000-0000-0000-00000000000a', '2026-09-01', 'legacy', 7, 7, 12);
