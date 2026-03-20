-- Phase 2: Setup Ledger Triggers and Helper Functions
-- Auto-updates usage_buckets_daily when usage_events are inserted
-- Helper functions for provisioning and quota management

-- Function: upsert_daily_usage_bucket
-- Increments daily usage totals when a usage_event is created
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

-- Trigger: Auto-update daily buckets on usage_events insert
create trigger trigger_upsert_daily_usage_bucket
  after insert on usage_events
  for each row
  execute function upsert_daily_usage_bucket();

-- Function: create_audit_log_entry
-- Generic function to log changes to any table
create or replace function create_audit_log_entry(
  org_id uuid,
  actor_id uuid,
  action text,
  target_type text,
  target_id text,
  old_vals jsonb default null,
  new_vals jsonb default null,
  meta jsonb default '{}'::jsonb
)
returns uuid as $$
declare
  audit_id bigint;
begin
  insert into audit_log (
    organization_id,
    actor_user_id,
    action,
    target_type,
    target_id,
    old_values,
    new_values,
    metadata
  )
  values (org_id, actor_id, action, target_type, target_id, old_vals, new_vals, meta)
  returning id into audit_id;

  return audit_id::uuid;
end;
$$ language plpgsql;

-- Function: enqueue_provisioning_job
-- Creates a provisioning job with idempotency key
create or replace function enqueue_provisioning_job(
  job_type text,
  source text,
  dedupe_key text,
  org_id uuid default null,
  user_id uuid default null,
  payload jsonb default '{}'::jsonb
)
returns uuid as $$
declare
  job_id uuid;
begin
  insert into provisioning_jobs (
    job_type,
    source,
    dedupe_key,
    organization_id,
    user_id,
    payload,
    status
  )
  values (job_type, source, dedupe_key, org_id, user_id, payload, 'pending')
  on conflict (dedupe_key)
  do update set
    updated_at = now(),
    status = case
      when provisioning_jobs.status = 'completed' then 'completed'
      when provisioning_jobs.status = 'failed' and provisioning_jobs.retry_count < provisioning_jobs.max_retries then 'pending'
      else provisioning_jobs.status
    end,
    retry_count = case
      when provisioning_jobs.status = 'failed' and provisioning_jobs.retry_count < provisioning_jobs.max_retries
        then provisioning_jobs.retry_count + 1
      else provisioning_jobs.retry_count
    end
  returning id into job_id;

  return job_id;
end;
$$ language plpgsql;

-- Function: get_org_daily_usage
-- Retrieves aggregated daily usage for an org/metric within a date range
create or replace function get_org_daily_usage(
  org_id uuid,
  metric text,
  start_date date,
  end_date date
)
returns table(
  bucket_date date,
  total_quantity bigint,
  request_count bigint,
  avg_latency_ms numeric
) as $$
begin
  return query
  select
    usage_buckets_daily.bucket_date,
    usage_buckets_daily.total_quantity,
    usage_buckets_daily.request_count,
    usage_buckets_daily.avg_latency_ms
  from usage_buckets_daily
  where usage_buckets_daily.organization_id = org_id
    and usage_buckets_daily.metric_key = metric
    and usage_buckets_daily.bucket_date between start_date and end_date
  order by usage_buckets_daily.bucket_date desc;
end;
$$ language plpgsql;

-- Function: get_org_month_usage
-- Retrieves total usage for an org for the current month
create or replace function get_org_month_usage(org_id uuid)
returns table(
  metric_key text,
  total_quantity bigint,
  request_count bigint
) as $$
begin
  return query
  select
    usage_buckets_daily.metric_key,
    sum(usage_buckets_daily.total_quantity)::bigint,
    sum(usage_buckets_daily.request_count)::bigint
  from usage_buckets_daily
  where usage_buckets_daily.organization_id = org_id
    and usage_buckets_daily.bucket_date >= date_trunc('month', now())::date
  group by usage_buckets_daily.metric_key
  order by sum(usage_buckets_daily.total_quantity) desc;
end;
$$ language plpgsql;

-- Function: check_org_quota
-- Determines if an org has quota remaining for a metric
create or replace function check_org_quota(
  org_id uuid,
  metric text,
  requested_units bigint
)
returns table(
  allowed boolean,
  remaining bigint,
  reason text
) as $$
declare
  org_plan_key text;
  plan_limit bigint;
  month_usage bigint;
begin
  -- Get org's current plan
  select current_plan into org_plan_key
  from organizations
  where id = org_id;

  -- Get plan's monthly limit for this metric
  select (features ->> metric)::bigint into plan_limit
  from plans
  where key = org_plan_key;

  -- Get this month's usage
  select coalesce(sum(total_quantity), 0) into month_usage
  from usage_buckets_daily
  where organization_id = org_id
    and metric_key = metric
    and bucket_date >= date_trunc('month', now())::date;

  return query select
    (month_usage + requested_units <= plan_limit)::boolean,
    (plan_limit - month_usage)::bigint,
    case
      when plan_limit is null then 'feature_not_in_plan'
      when month_usage + requested_units > plan_limit then 'monthly_quota_exceeded'
      else 'ok'
    end;
end;
$$ language plpgsql;

-- Comment on tables for clarity
comment on table usage_events is
  'Immutable append-only ledger of all metered events. Used for billing, analytics, and audit.';

comment on table usage_buckets_daily is
  'Materialized daily summary of usage_events. Updated by trigger after each insert.';

comment on table billing_event_log is
  'Immutable record of all Stripe webhook events processed. Source of truth for subscription state.';

comment on table provisioning_jobs is
  'Async provisioning queue with idempotency. Tracks user creation, membership changes, and entitlement syncs.';

comment on table audit_log is
  'Immutable record of all system changes: roles, subscriptions, entitlements, API keys, quotas.';
