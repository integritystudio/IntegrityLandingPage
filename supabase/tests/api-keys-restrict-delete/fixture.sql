-- Fixture for the api-keys-restrict-delete migration test (UA13).
--
-- The slice the migration touches, with production's delete actions: api_keys and its two
-- CASCADE foreign keys (as the baseline and 20260803000000 created them), the
-- auth.users -> public.users CASCADE that a Supabase admin deleteUser fires, and a
-- membership table so a key-less user's delete still cascades normally.

create schema auth;
create table auth.users (id uuid primary key);

create type public.api_key_status as enum ('active', 'revoked', 'expired', 'inactive');

create table public.organizations (
  id uuid primary key,
  slug text unique not null
);

create table public.users (
  id uuid primary key references auth.users(id) on delete cascade,
  email text unique not null
);

create table public.organization_memberships (
  organization_id uuid not null references public.organizations(id) on delete cascade,
  user_id uuid not null references public.users(id) on delete cascade,
  primary key (organization_id, user_id)
);

create table public.api_keys (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null,
  organization_id uuid not null,
  status public.api_key_status not null default 'active',
  revoked_at timestamptz,
  constraint api_keys_user_id_fkey foreign key (user_id)
    references public.users(id) on delete cascade,
  constraint api_keys_organization_id_fkey foreign key (organization_id)
    references public.organizations(id) on delete cascade
);

insert into auth.users (id) values
  ('00000000-0000-0000-0000-000000000001'),  -- holds an active key
  ('00000000-0000-0000-0000-000000000002'),  -- holds only a revoked key
  ('00000000-0000-0000-0000-000000000003');  -- holds no key

insert into public.organizations (id, slug) values
  ('00000000-0000-0000-0000-00000000000a', 'keyed-org'),
  ('00000000-0000-0000-0000-00000000000b', 'keyless-org');

insert into public.users (id, email) values
  ('00000000-0000-0000-0000-000000000001', 'keyholder@test'),
  ('00000000-0000-0000-0000-000000000002', 'revoked@test'),
  ('00000000-0000-0000-0000-000000000003', 'keyless@test');

insert into public.organization_memberships (organization_id, user_id) values
  ('00000000-0000-0000-0000-00000000000a', '00000000-0000-0000-0000-000000000001'),
  ('00000000-0000-0000-0000-00000000000a', '00000000-0000-0000-0000-000000000002'),
  ('00000000-0000-0000-0000-00000000000b', '00000000-0000-0000-0000-000000000003');

insert into public.api_keys (user_id, organization_id, status, revoked_at) values
  ('00000000-0000-0000-0000-000000000001', '00000000-0000-0000-0000-00000000000a', 'active',  null),
  ('00000000-0000-0000-0000-000000000002', '00000000-0000-0000-0000-00000000000a', 'revoked', now());
