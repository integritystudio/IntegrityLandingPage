\set ON_ERROR_STOP on

-- Assertions for 20260927020000_usage_buckets_single_writer.sql (CR43).
-- Run via ./run.sh. Each mutating test runs in begin/rollback so tests are
-- independent and all start from the post-backfill state.
--
-- bucket_of() renders a bucket as quantity/requests/avg/latency-samples, so one
-- assertion pins the whole row and a failure prints every field.

create or replace function public.assert_eq(label text, actual text, expected text) returns void
language plpgsql as $$
begin
  if actual is distinct from expected then
    raise exception 'FAIL %: got % expected %', label, coalesce(actual, 'NULL'), coalesce(expected, 'NULL');
  end if;
  raise notice 'PASS %', label;
end $$;

create or replace function public.bucket_of(metric text, day date) returns text
language sql as $$
  select format('%s/%s/%s/%s', total_quantity, request_count,
                coalesce(round(avg_latency_ms, 2)::text, 'NULL'), latency_sample_count)
    from public.usage_buckets_daily
   where metric_key = metric and bucket_date = day
$$;

create or replace function public.add_event(metric text, qty bigint, latency integer, at timestamptz) returns void
language sql as $$
  insert into public.usage_events (organization_id, metric_key, quantity, latency_ms, created_at)
  values ('00000000-0000-0000-0000-00000000000a', metric, qty, latency, at)
$$;

-- T1 backfill recomputes what the ledger vouches for, and nothing else
select assert_eq('T1a drifted bucket restored from the ledger', bucket_of('api_requests', '2026-09-20'), '15/3/200.00/3');
select assert_eq('T1b NULL-poisoned average restored', bucket_of('otel_spans', '2026-09-21'), '5/2/50.00/1');
select assert_eq('T1c bucket with no events left alone', bucket_of('legacy', '2026-09-01'), '7/7/12.00/0');

-- T2 first event of a new bucket
begin;
select add_event('fresh', 3, 40, '2026-09-22 09:00Z');
select assert_eq('T2 first event creates the bucket', bucket_of('fresh', '2026-09-22'), '3/1/40.00/1');
rollback;

-- T3 a NULL latency counts as a request but leaves the average alone
begin;
select add_event('api_requests', 2, null, '2026-09-20 13:00Z');
select assert_eq('T3 NULL latency: +request, same average', bucket_of('api_requests', '2026-09-20'), '17/4/200.00/3');
rollback;

-- T4 a NULL first sample does not make the average NULL
begin;
select add_event('fresh', 1, null, '2026-09-22 09:00Z');
select add_event('fresh', 1, 80,   '2026-09-22 10:00Z');
select assert_eq('T4 NULL first, then 80 -> average 80', bucket_of('fresh', '2026-09-22'), '2/2/80.00/1');
rollback;

-- T5 the average is weighted by latency samples, not by requests
begin;
select add_event('fresh', 1, 100,  '2026-09-22 09:00Z');
select add_event('fresh', 1, null, '2026-09-22 10:00Z');
select add_event('fresh', 1, 300,  '2026-09-22 11:00Z');
select assert_eq('T5 latencies 100, NULL, 300 -> average 200', bucket_of('fresh', '2026-09-22'), '3/3/200.00/2');
rollback;

-- T6 the bucket is the UTC day, whatever the session timezone
begin;
set local timezone = 'America/Chicago';
select add_event('late', 1, 10, '2026-09-27 23:30:00-05');
select assert_eq('T6a 23:30 Chicago lands on the next UTC day', bucket_of('late', '2026-09-28'), '1/1/10.00/1');
select assert_eq('T6b and not on the local day', bucket_of('late', '2026-09-27'), null);
rollback;

-- T7 increments accumulate across many inserts
begin;
insert into public.usage_events (organization_id, metric_key, quantity, latency_ms, created_at)
select '00000000-0000-0000-0000-00000000000a', 'bulk', 2, 10, '2026-09-23 00:00Z' from generate_series(1, 50);
select assert_eq('T7 fifty events accumulate', bucket_of('bulk', '2026-09-23'), '100/50/10.00/50');
rollback;

\echo 'ALL PASS'
