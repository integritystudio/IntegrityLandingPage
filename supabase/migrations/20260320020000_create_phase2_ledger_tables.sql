-- Phase 2: Usage Ledger & Audit Schema
-- Creates: usage_events, usage_buckets_daily, billing_event_log, provisioning_jobs, audit_log

-- Usage events table (append-only ledger)
-- Records every API call, ingest event, job execution, etc.
create table usage_events (
  id bigint generated always as identity primary key,
  organization_id uuid not null references public.organizations(id) on delete cascade,
  user_id uuid references public.users(id) on delete set null,
  api_key_id uuid references public.api_keys(id) on delete set null,
  route text not null,
  metric_key text not null,
  quantity bigint not null default 1,
  request_id text not null,
  source text not null check (source in ('api', 'ingest', 'job', 'internal', 'migration')),
  status_code integer,
  latency_ms integer,
  metadata jsonb not null default '{}',
  created_at timestamptz not null default now()
);

create index idx_usage_events_organization_id on usage_events(organization_id);
create index idx_usage_events_user_id on usage_events(user_id);
create index idx_usage_events_api_key_id on usage_events(api_key_id);
create index idx_usage_events_metric_key on usage_events(metric_key);
create index idx_usage_events_request_id on usage_events(request_id);
create index idx_usage_events_source on usage_events(source);
create index idx_usage_events_created_at on usage_events(created_at);
create index idx_usage_events_org_date on usage_events(organization_id, created_at desc);

-- Daily usage rollups (materialized summary for dashboard)
-- Updated by trigger or scheduled job
create table usage_buckets_daily (
  organization_id uuid not null references public.organizations(id) on delete cascade,
  bucket_date date not null,
  metric_key text not null,
  total_quantity bigint not null default 0,
  request_count bigint not null default 0,
  avg_latency_ms numeric,
  updated_at timestamptz not null default now(),
  primary key (organization_id, bucket_date, metric_key)
);

create index idx_usage_buckets_daily_org_date on usage_buckets_daily(organization_id, bucket_date desc);
create index idx_usage_buckets_daily_metric on usage_buckets_daily(metric_key, bucket_date desc);

-- Billing event log (audit trail for Stripe webhooks)
-- Immutable record of billing state changes
create table billing_event_log (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid references public.organizations(id) on delete cascade,
  stripe_event_id text unique not null,
  event_type text not null check (event_type in (
    'checkout.session.completed',
    'invoice.paid',
    'invoice.payment_failed',
    'customer.subscription.updated',
    'customer.subscription.deleted',
    'charge.refunded',
    'other'
  )),
  payload jsonb not null,
  processed_at timestamptz,
  error_message text,
  created_at timestamptz not null default now()
);

create index idx_billing_event_log_organization_id on billing_event_log(organization_id);
create index idx_billing_event_log_stripe_event_id on billing_event_log(stripe_event_id);
create index idx_billing_event_log_event_type on billing_event_log(event_type);
create index idx_billing_event_log_processed_at on billing_event_log(processed_at);

-- Provisioning jobs (async provisioning with idempotency)
-- Tracks user creation, membership changes, subscription updates, etc.
create table provisioning_jobs (
  id uuid primary key default gen_random_uuid(),
  job_type text not null check (job_type in (
    'user_created',
    'user_updated',
    'membership_changed',
    'subscription_changed',
    'entitlements_recomputed',
    'quota_version_bumped'
  )),
  source text not null check (source in ('supabase_webhook', 'stripe_webhook', 'manual', 'migration')),
  dedupe_key text unique not null,
  organization_id uuid references public.organizations(id) on delete cascade,
  user_id uuid references public.users(id) on delete set null,
  payload jsonb not null,
  status text not null default 'pending' check (status in ('pending', 'processing', 'completed', 'failed', 'retried')),
  result jsonb,
  error_message text,
  retry_count integer not null default 0,
  max_retries integer not null default 3,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  completed_at timestamptz
);

create index idx_provisioning_jobs_dedupe_key on provisioning_jobs(dedupe_key);
create index idx_provisioning_jobs_organization_id on provisioning_jobs(organization_id);
create index idx_provisioning_jobs_user_id on provisioning_jobs(user_id);
create index idx_provisioning_jobs_status on provisioning_jobs(status);
create index idx_provisioning_jobs_job_type on provisioning_jobs(job_type);
create index idx_provisioning_jobs_created_at on provisioning_jobs(created_at);

-- Audit log (system-wide change history)
-- Every significant change: user role, entitlement, subscription, API key, etc.
create table audit_log (
  id bigint generated always as identity primary key,
  organization_id uuid references public.organizations(id) on delete cascade,
  actor_user_id uuid references public.users(id) on delete set null,
  actor_api_key_id uuid references public.api_keys(id) on delete set null,
  action text not null,
  target_type text not null,
  target_id text not null,
  old_values jsonb,
  new_values jsonb,
  metadata jsonb not null default '{}',
  created_at timestamptz not null default now()
);

create index idx_audit_log_organization_id on audit_log(organization_id);
create index idx_audit_log_actor_user_id on audit_log(actor_user_id);
create index idx_audit_log_target_type on audit_log(target_type);
create index idx_audit_log_target_id on audit_log(target_id);
create index idx_audit_log_action on audit_log(action);
create index idx_audit_log_created_at on audit_log(created_at);
create index idx_audit_log_org_date on audit_log(organization_id, created_at desc);

-- Enable RLS on all Phase 2 tables
alter table usage_events enable row level security;
alter table usage_buckets_daily enable row level security;
alter table billing_event_log enable row level security;
alter table provisioning_jobs enable row level security;
alter table audit_log enable row level security;

-- RLS Policy: Users can view usage for their orgs
create policy "users_view_org_usage_events"
  on usage_events for select
  using (
    exists (
      select 1
      from organization_memberships m
      join public.auth_user_links ual on m.user_id = ual.app_user_id
      where m.organization_id = usage_events.organization_id
        and ual.auth_user_id = auth.uid()
        and m.status = 'active'
    )
  );

-- RLS Policy: Users can view daily rollups for their orgs
create policy "users_view_org_usage_buckets"
  on usage_buckets_daily for select
  using (
    exists (
      select 1
      from organization_memberships m
      join public.auth_user_links ual on m.user_id = ual.app_user_id
      where m.organization_id = usage_buckets_daily.organization_id
        and ual.auth_user_id = auth.uid()
        and m.status = 'active'
    )
  );

-- RLS Policy: Users can view billing events for their orgs (billing admins only)
create policy "billing_admins_view_org_billing_events"
  on billing_event_log for select
  using (
    exists (
      select 1
      from organization_memberships m
      join public.auth_user_links ual on m.user_id = ual.app_user_id
      where m.organization_id = billing_event_log.organization_id
        and ual.auth_user_id = auth.uid()
        and m.status = 'active'
        and m.role in ('owner', 'billing_admin')
    )
  );

-- RLS Policy: Users can view audit logs for their orgs (admins only)
create policy "admins_view_org_audit_logs"
  on audit_log for select
  using (
    exists (
      select 1
      from organization_memberships m
      join public.auth_user_links ual on m.user_id = ual.app_user_id
      where m.organization_id = audit_log.organization_id
        and ual.auth_user_id = auth.uid()
        and m.status = 'active'
        and m.role in ('owner', 'admin')
    )
  );

-- Service role write policies (no RLS restrictions)
-- Used by Workers and backend services for:
-- - Writing usage events
-- - Updating daily rollups
-- - Logging billing events
-- - Managing provisioning jobs
-- - Creating audit entries
