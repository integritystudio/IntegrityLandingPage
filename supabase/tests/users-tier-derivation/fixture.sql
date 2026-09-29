-- Fixture for the users-tier-derivation migration test (UA04).
--
-- Only the slice the migration touches: the api_key_tier enum, organizations'
-- plan column, and users' tier + default_organization_id. Rows are seeded
-- BEFORE the migration runs so its backfill is exercised on pre-existing drift.

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
  -- No delete action, as in production (users_default_organization_id_fkey,
  -- 20260803000000_baseline_deferred_constraints.sql): deleting a default org is refused.
  default_organization_id uuid references public.organizations(id)
);

insert into public.organizations (id, slug, current_plan) values
  ('00000000-0000-0000-0000-00000000000a', 'growth-org',     'growth'),
  ('00000000-0000-0000-0000-00000000000b', 'free-org',       'free'),
  ('00000000-0000-0000-0000-00000000000c', 'enterprise-org', 'enterprise');

-- The UA04 shape: a growth org whose owner still reads starter.
insert into public.users (id, email, tier, default_organization_id) values
  ('00000000-0000-0000-0000-000000000001', 'stale@test',   'starter',    '00000000-0000-0000-0000-00000000000a'),
  ('00000000-0000-0000-0000-000000000002', 'noorg@test',   'growth',     null),
  ('00000000-0000-0000-0000-000000000003', 'free@test',    'enterprise', '00000000-0000-0000-0000-00000000000b'),
  ('00000000-0000-0000-0000-000000000004', 'teammate@test','starter',    '00000000-0000-0000-0000-00000000000a');

-- A writer that may update organizations but has no grant on users — proves the
-- propagation trigger does not depend on the caller's privileges on users.
create role org_writer nologin;
grant usage on schema public to org_writer;
grant select, update on public.organizations to org_writer;
