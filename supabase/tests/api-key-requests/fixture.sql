-- Fixture for the api-key-requests migration test.
--
-- The api_keys slice the migration writes through, with production's types and the
-- constraints a create can trip (hash unique, organization+prefix unique, revoked rows
-- carry a timestamp), plus the three hosted API roles. service_role bypasses RLS as it
-- does on the hosted project. The hosted default privileges are reproduced so the
-- migration's revokes are tested against the grants they must remove, not against a
-- cluster that never granted anything (20261007010000).

create type public.api_key_tier as enum ('starter', 'growth', 'enterprise');
create type public.api_key_status as enum ('active', 'revoked', 'expired', 'inactive');

create table public.organizations (
  id uuid primary key,
  slug text unique not null
);

create table public.users (
  id uuid primary key,
  email text unique not null
);

create table public.api_keys (
  id uuid default gen_random_uuid() not null,
  user_id uuid not null,
  prefix character(8) not null,
  hash text not null,
  name text default 'Default'::text not null,
  tier public.api_key_tier default 'starter'::public.api_key_tier not null,
  status public.api_key_status default 'active'::public.api_key_status not null,
  created_at timestamptz default now() not null,
  revoked_at timestamptz,
  organization_id uuid not null,
  constraint api_keys_pkey primary key (id),
  constraint api_keys_hash_key unique (hash),
  constraint api_keys_organization_id_prefix_key unique (organization_id, prefix),
  constraint api_keys_user_id_fkey foreign key (user_id) references public.users(id) on delete restrict,
  constraint api_keys_organization_id_fkey foreign key (organization_id) references public.organizations(id) on delete restrict,
  constraint revoked_has_timestamp check ((status <> 'revoked'::public.api_key_status) or (revoked_at is not null))
);

create role anon;
create role authenticated;
create role service_role bypassrls;
grant usage on schema public to anon, authenticated, service_role;
grant all on all tables in schema public to anon, authenticated, service_role;

alter default privileges for role pgtest in schema public
  grant all on tables to anon, authenticated, service_role;
alter default privileges for role pgtest in schema public
  grant execute on functions to anon, authenticated, service_role;

insert into public.organizations (id, slug) values
  ('00000000-0000-0000-0000-00000000000a', 'org-a');

insert into public.users (id, email) values
  ('00000000-0000-0000-0000-000000000001', 'owner@test');
