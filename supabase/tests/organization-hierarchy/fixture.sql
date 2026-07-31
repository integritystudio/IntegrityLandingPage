-- Fixture for the organization-hierarchy migration test.
--
-- Replicates only the slice of the prd schema the migration touches, then seeds
-- the real prd ids so assertions read against recognisable orgs.
--
-- Deliberately NOT a full schema dump: the migration touches organizations,
-- organization_memberships, auth_user_links and the RLS policies over them.
-- Everything else (billing, usage, api_keys) is irrelevant to the ancestor walk.

create schema if not exists auth;

-- Supabase's auth.uid() reads the sub claim from the request JWT. Under a bare
-- Postgres cluster there is no JWT, so it is stubbed to read a GUC that each
-- test sets with `set local test.auth_uid`. Same signature and STABLE volatility
-- as the real one, so policy planning behaves the same way.
create or replace function auth.uid() returns uuid
language sql stable as $$
  select nullif(current_setting('test.auth_uid', true), '')::uuid;
$$;

create type public.organization_type as enum
  ('personal', 'team', 'organization', 'parent-organization');

create table public.organizations (
  id uuid primary key default gen_random_uuid(),
  slug text unique not null,
  name text not null,
  billing_status text not null default 'inactive',
  current_plan text not null default 'starter',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  domain text,
  type public.organization_type not null default 'personal'
);

create table public.users (
  id uuid primary key default gen_random_uuid(),
  email text unique not null,
  default_organization_id uuid references public.organizations(id)
);

create table public.organization_memberships (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  user_id uuid not null references public.users(id) on delete cascade,
  role text not null,
  status text not null default 'active',
  unique (organization_id, user_id)
);

create table public.auth_user_links (
  id uuid primary key default gen_random_uuid(),
  app_user_id uuid not null references public.users(id) on delete cascade,
  auth_user_id uuid not null
);

alter table public.organizations enable row level security;
alter table public.organization_memberships enable row level security;
alter table public.auth_user_links enable row level security;

-- The three pre-existing prd policies this migration interacts with, copied
-- from 20260320000000_phase1_consolidated.sql (orgs, memberships) and
-- 20260320005000_create_auth_user_links.sql (links).
--
-- All three are load-bearing for the test, not decoration. users_view_member_orgs
-- reads organization_memberships, which reads auth_user_links; if either inner
-- table has RLS enabled with NO policy, it returns zero rows and the outer
-- policy silently matches nothing. An earlier revision of this fixture omitted
-- the latter two and T3 failed with the child org invisible while the parent
-- was visible — because user_ancestor_org_ids() is `security definer` and
-- bypasses those inner tables, whereas the inline policy is not and does not.
-- Keeping all three here is what makes the additive-OR behaviour observable.
create policy "users_view_member_orgs"
  on public.organizations for select
  using (
    exists (
      select 1
      from public.organization_memberships m
      join public.auth_user_links ual on m.user_id = ual.app_user_id
      where m.organization_id = public.organizations.id
        and ual.auth_user_id = auth.uid()
        and m.status = 'active'
    )
  );

create policy "users_view_own_memberships"
  on public.organization_memberships for select
  using (
    user_id in (
      select app_user_id from public.auth_user_links
      where auth_user_id = auth.uid()
    )
  );

create policy "users_view_own_auth_link"
  on public.auth_user_links for select
  using (auth.uid() = auth_user_id);

-- `authenticated` is Supabase's role for a logged-in caller. It must be a
-- NON-OWNER of the tables: Postgres exempts a table's owner from RLS, so
-- running assertions as the owner silently bypasses every policy.
create role authenticated;
grant usage on schema public, auth to authenticated;
grant select on all tables in schema public to authenticated;

-- ---------------------------------------------------------------------------
-- Seed. Real prd ids so failures name orgs that exist.
-- ---------------------------------------------------------------------------
insert into public.organizations (id, slug, name, type, current_plan) values
  ('29edb193-ae7f-4863-9bb6-e245da74ec1f', 'integrity-studio-ai', 'Integrity Studio AI', 'organization', 'enterprise'),
  ('38567a26-c19c-4b34-9c42-d377761bb50c', 'team-integritystudio.ai', 'integritystudio.ai', 'team', 'starter'),
  ('7383d8d2-f218-4e50-b3b5-c53fd01bf755', 'team-gmail.com', 'gmail.com', 'team', 'starter'),
  ('f4286657-da73-4174-9e49-937f1bb6097f', 'home', 'Integrity Studio — Home', 'personal', 'enterprise');

insert into public.users (id, email) values
  ('11111111-1111-1111-1111-111111111111', 'chandra@integritystudio.ai'),
  ('22222222-2222-2222-2222-222222222222', 'outsider@example.com');

-- chandra: active member of the CHILD org only. Should gain the parent.
insert into public.organization_memberships (organization_id, user_id, role, status) values
  ('38567a26-c19c-4b34-9c42-d377761bb50c', '11111111-1111-1111-1111-111111111111', 'admin', 'active');

-- outsider: member of an unrelated, parentless team org. Should gain nothing.
insert into public.organization_memberships (organization_id, user_id, role, status) values
  ('7383d8d2-f218-4e50-b3b5-c53fd01bf755', '22222222-2222-2222-2222-222222222222', 'member', 'active');

-- prd has ZERO auth_user_links rows, which is why its organizations policies
-- currently match nothing for anyone. The fixture populates the table so the
-- policies are actually exercised — otherwise every test passes vacuously.
insert into public.auth_user_links (app_user_id, auth_user_id) values
  ('11111111-1111-1111-1111-111111111111', 'aaaaaaaa-0000-0000-0000-000000000001'),
  ('22222222-2222-2222-2222-222222222222', 'aaaaaaaa-0000-0000-0000-000000000002');
