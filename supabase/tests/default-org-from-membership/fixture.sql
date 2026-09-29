-- Fixture for the default-org-from-membership migration test (CR50).
--
-- The slice the migration touches: users' default_organization_id, memberships,
-- and the UA04 tier triggers it hands off to (applied from the real migration, so
-- the suite proves `tier` follows once a default exists). Rows are seeded BEFORE
-- the CR50 migration runs so its backfill is exercised.

create type public.api_key_tier as enum ('starter', 'growth', 'enterprise');

create table public.organizations (
  id uuid primary key,
  slug text unique not null,
  current_plan text not null default 'starter'
);

create table public.users (
  id uuid primary key,
  email text unique not null,
  tier public.api_key_tier not null default 'starter',
  default_organization_id uuid references public.organizations(id) on delete set null
);

create table public.organization_memberships (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  user_id uuid not null references public.users(id) on delete cascade,
  role text not null check (role in ('owner','admin','member','billing_admin','viewer')),
  status text not null default 'active' check (status in ('active','invited','suspended')),
  created_at timestamptz not null default now(),
  unique (organization_id, user_id)
);

\ir ../../migrations/20260927000000_derive_users_tier_from_default_org.sql

insert into public.organizations (id, slug, current_plan) values
  ('00000000-0000-0000-0000-00000000000a', 'growth-org',     'growth'),
  ('00000000-0000-0000-0000-00000000000b', 'free-org',       'free'),
  ('00000000-0000-0000-0000-00000000000c', 'enterprise-org', 'enterprise');

insert into public.users (id, email, default_organization_id) values
  -- The CR50 shape: memberships, no default. The OLDER membership is a plain
  -- member of growth-org, so the backfill must take age over role.
  ('00000000-0000-0000-0000-000000000001', 'nodefault@test', null),
  ('00000000-0000-0000-0000-000000000002', 'chosen@test',    '00000000-0000-0000-0000-00000000000c'),
  ('00000000-0000-0000-0000-000000000003', 'invited@test',   null),
  ('00000000-0000-0000-0000-000000000004', 'orphan@test',    null);

insert into public.organization_memberships (organization_id, user_id, role, status, created_at) values
  ('00000000-0000-0000-0000-00000000000a', '00000000-0000-0000-0000-000000000001', 'member', 'active',  '2026-09-01'),
  ('00000000-0000-0000-0000-00000000000b', '00000000-0000-0000-0000-000000000001', 'owner',  'active',  '2026-09-02'),
  ('00000000-0000-0000-0000-00000000000a', '00000000-0000-0000-0000-000000000002', 'owner',  'active',  '2026-09-01'),
  ('00000000-0000-0000-0000-00000000000a', '00000000-0000-0000-0000-000000000003', 'member', 'invited', '2026-09-01');

-- A writer that may write memberships but has no grant on users, like a
-- provisioning path — proves the trigger does not depend on the caller's
-- privileges on users.
create role membership_writer nologin;
grant usage on schema public to membership_writer;
grant select, insert, update on public.organization_memberships to membership_writer;
