-- Phase 1 Consolidated: Organizations & Subscriptions Schema
-- Consolidated single migration to avoid tracking issues
-- Integrates with existing public.users, auth_user_links, roles, and api_keys tables

-- Drop Phase 1 tables if they exist (from failed migrations)
drop table if exists public.entitlements cascade;
drop table if exists public.subscriptions cascade;
drop table if exists public.organization_memberships cascade;
drop table if exists public.organizations cascade;
drop table if exists public.plans cascade;

-- Organizations table
create table public.organizations (
  id uuid primary key default gen_random_uuid(),
  slug text unique not null,
  name text not null,
  stripe_customer_id text unique,
  active_subscription_id uuid,
  billing_status text not null default 'inactive',
  current_plan text not null default 'free',
  quota_version bigint not null default 1,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index idx_organizations_stripe_customer_id on public.organizations(stripe_customer_id);
create index idx_organizations_active_subscription_id on public.organizations(active_subscription_id);
create index idx_organizations_billing_status on public.organizations(billing_status);
create index idx_organizations_current_plan on public.organizations(current_plan);

-- Plans table (reference data for tier definitions)
create table public.plans (
  key text primary key,
  display_name text not null,
  monthly_units bigint,
  requests_per_minute integer,
  concurrent_jobs integer,
  features jsonb not null default '{}',
  created_at timestamptz not null default now()
);

-- Pre-populate with tier definitions (idempotent)
insert into public.plans (key, display_name, monthly_units, requests_per_minute, concurrent_jobs, features)
values
  (
    'free',
    'Free',
    10000,
    60,
    1,
    '{"usage_dashboard": true, "alerts": true, "api_keys_max": 1}'::jsonb
  ),
  (
    'growth',
    'Growth',
    500000,
    600,
    5,
    '{"usage_dashboard": true, "alerts": true, "compliance_summary": true, "api_keys_max": 10}'::jsonb
  ),
  (
    'enterprise',
    'Enterprise',
    null,
    null,
    null,
    '{"usage_dashboard": true, "alerts": true, "compliance_summary": true, "api_keys_max": null, "premium_support": true}'::jsonb
  )
on conflict (key) do nothing;

-- Subscriptions table (mirrors Stripe subscription state)
create table public.subscriptions (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  stripe_subscription_id text unique not null,
  stripe_price_id text,
  status text not null,
  current_period_start timestamptz,
  current_period_end timestamptz,
  cancel_at_period_end boolean not null default false,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index idx_subscriptions_organization_id on public.subscriptions(organization_id);
create index idx_subscriptions_stripe_subscription_id on public.subscriptions(stripe_subscription_id);
create index idx_subscriptions_status on public.subscriptions(status);
create index idx_subscriptions_current_period_end on public.subscriptions(current_period_end);

-- Add foreign key constraint from organizations to subscriptions
alter table public.organizations
  add constraint fk_organizations_active_subscription_id
  foreign key (active_subscription_id) references public.subscriptions(id) on delete set null;

-- Organization memberships table
-- Links public.users to organizations with role-based access
create table public.organization_memberships (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  user_id uuid not null references public.users(id) on delete cascade,
  role text not null check (role in ('owner','admin','member','billing_admin','viewer')),
  status text not null default 'active' check (status in ('active','invited','suspended')),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (organization_id, user_id)
);

create index idx_organization_memberships_organization_id on public.organization_memberships(organization_id);
create index idx_organization_memberships_user_id on public.organization_memberships(user_id);
create index idx_organization_memberships_role on public.organization_memberships(role);
create index idx_organization_memberships_status on public.organization_memberships(status);

-- Entitlements table (org-scoped feature flags + limits)
create table public.entitlements (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  feature_key text not null,
  enabled boolean not null default false,
  hard_limit bigint,
  soft_limit bigint,
  config jsonb not null default '{}',
  updated_at timestamptz not null default now(),
  unique (organization_id, feature_key)
);

create index idx_entitlements_organization_id on public.entitlements(organization_id);
create index idx_entitlements_feature_key on public.entitlements(feature_key);

-- Add default_organization_id to public.users if it doesn't exist
alter table public.users
  add column if not exists default_organization_id uuid references public.organizations(id);

create index if not exists idx_users_default_organization_id on public.users(default_organization_id);

-- Enable RLS on all Phase 1 tables
alter table public.organizations enable row level security;
alter table public.organization_memberships enable row level security;
alter table public.plans enable row level security;
alter table public.subscriptions enable row level security;
alter table public.entitlements enable row level security;





-- RLS Policy: Plans are publicly readable (reference data)
create policy "plans_public_read"
  on public.plans for select
  using (true);

-- Integration: Update public.roles for executive permissions (idempotent)
update public.roles
  set permissions = permissions || '["dashboard.read","dashboard.executive"]'::jsonb
  where name = 'executive'
    and not (permissions @> '["dashboard.read"]'::jsonb);



-- NOTE (CR30, 2026-08-03): five RLS policies and the `enable row level
-- security` on public.auth_user_links were moved OUT of this file to
-- 20260803010000_phase1_policies_requiring_auth_user_links.sql. Every one of
-- them reads public.auth_user_links, which 20260320005000 creates AFTER this
-- migration -- so replaying the ledger onto an empty database died here. They
-- sort last now because they also touch entitlements and subscriptions.
-- Production is unaffected: this migration is already applied and never re-runs.
