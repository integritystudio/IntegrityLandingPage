-- Fixture for the drop-client-write-policies migration test.
--
-- The slice the migration touches: `users` and `api_keys` with every RLS policy production
-- holds on them, the tables those policies and the insert trigger read or write, and
-- Supabase's API roles with production's grants.

create schema auth;

-- Supabase's auth.jwt(), auth.uid() and auth.role(), with the hosted project's bodies
-- (pg_get_functiondef, 2026-10-05). They read the claims PostgREST puts in a GUC, so a
-- test sets them the same way, and auth.jwt() ->> 'sub' and auth.uid() agree as they do
-- there. A stub reading its own GUC would let the two drift apart.
create function auth.jwt() returns jsonb language sql stable as $$
  select
    coalesce(
        nullif(current_setting('request.jwt.claim', true), ''),
        nullif(current_setting('request.jwt.claims', true), '')
    )::jsonb
$$;

create function auth.uid() returns uuid language sql stable as $$
  select
  coalesce(
    nullif(current_setting('request.jwt.claim.sub', true), ''),
    (nullif(current_setting('request.jwt.claims', true), '')::jsonb ->> 'sub')
  )::uuid
$$;

create function auth.role() returns text language sql stable as $$
  select
  coalesce(
    nullif(current_setting('request.jwt.claim.role', true), ''),
    (nullif(current_setting('request.jwt.claims', true), '')::jsonb ->> 'role')
  )::text
$$;

create type public.api_key_status as enum ('active', 'revoked', 'expired', 'inactive');

create table public.organizations (
  id uuid primary key,
  slug text unique not null
);

create table public.users (
  id uuid primary key default gen_random_uuid(),
  auth0_id varchar(255) unique not null,
  email varchar(255) unique not null
);

create table public.roles (
  id uuid primary key default gen_random_uuid(),
  name varchar(100) unique not null
);

create table public.user_roles (
  user_id uuid not null references public.users(id) on delete cascade,
  role_id uuid not null references public.roles(id) on delete cascade,
  unique (user_id, role_id)
);

create table public.auth_user_links (
  auth_user_id uuid primary key,
  app_user_id uuid not null unique references public.users(id) on delete cascade
);

create table public.api_keys (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.users(id) on delete restrict,
  organization_id uuid not null references public.organizations(id) on delete restrict,
  hash text unique not null,
  status public.api_key_status not null default 'active'
);

-- Production's on_user_created trigger (20260717000000). SECURITY DEFINER is why a client
-- insert into `users` is not stopped by `user_roles` having no insert policy, so without
-- it the fixture would be stricter than production in exactly the place under test.
create function public.assign_default_role() returns trigger
language plpgsql security definer as $$
declare default_role_id uuid;
begin
  select id into default_role_id from public.roles where name = 'provisioned-dashboard-viewer' limit 1;
  if default_role_id is not null then
    insert into public.user_roles (user_id, role_id) values (NEW.id, default_role_id);
  end if;
  return NEW;
end;
$$;

create trigger on_user_created after insert on public.users
  for each row execute function public.assign_default_role();

alter table public.organizations enable row level security;
alter table public.users enable row level security;
alter table public.roles enable row level security;
alter table public.user_roles enable row level security;
alter table public.auth_user_links enable row level security;
alter table public.api_keys enable row level security;

-- Every policy production holds on `users` and `api_keys`, copied from the baseline
-- (20260319000000) and 20260803000000, plus the one on `auth_user_links` that
-- users_view_own_api_keys reads through. `organizations` carries none: its policies all
-- need a membership, which nobody here has.
create policy "Users can insert their own data" on public.users
  as permissive
  for insert
  to public
  with check ((auth.uid() = id));

create policy "Users can read their own data" on public.users
  as permissive
  for select
  to public
  using ((auth.uid() = id));

create policy "Users can update own data" on public.users
  as permissive
  for update
  to public
  using (((auth.uid())::text = (auth0_id)::text));

create policy "Users can view own data" on public.users
  as permissive
  for select
  to public
  using (((auth.uid())::text = (auth0_id)::text));

create policy "users can view own profile" on public.users
  as permissive
  for select
  to public
  using ((id = auth.uid()));

create policy "service_role_full_access" on public.api_keys
  as permissive
  for all
  to public
  using ((auth.role() = 'service_role'::text));

create policy "users_insert_own_keys" on public.api_keys
  as permissive
  for insert
  to public
  with check ((user_id IN ( SELECT users.id
   FROM users
  WHERE ((users.auth0_id)::text = (auth.jwt() ->> 'sub'::text)))));

create policy "users_read_own_keys" on public.api_keys
  as permissive
  for select
  to public
  using ((user_id IN ( SELECT users.id
   FROM users
  WHERE ((users.auth0_id)::text = (auth.jwt() ->> 'sub'::text)))));

create policy "users_update_own_keys" on public.api_keys
  as permissive
  for update
  to public
  using ((user_id IN ( SELECT users.id
   FROM users
  WHERE ((users.auth0_id)::text = (auth.jwt() ->> 'sub'::text)))));

create policy "users_view_own_api_keys" on public.api_keys
  as permissive
  for select
  to public
  using ((user_id IN ( SELECT auth_user_links.app_user_id
   FROM auth_user_links
  WHERE (auth_user_links.auth_user_id = auth.uid()))));

create policy "users_view_own_auth_link" on public.auth_user_links
  as permissive
  for select
  to public
  using ((auth.uid() = auth_user_id));

-- Supabase's API roles. `authenticated` is a non-owner holding production's table-wide
-- grants, so RLS is the only thing between it and a write. `service_role` bypasses RLS,
-- as it does on the hosted project (rolbypassrls).
create role authenticated;
create role service_role bypassrls;
grant usage on schema public, auth to authenticated, service_role;
grant all on all tables in schema public to authenticated, service_role;

insert into public.roles (name) values ('provisioned-dashboard-viewer');

insert into public.organizations (id, slug) values
  ('00000000-0000-0000-0000-00000000000a', 'org-a'),
  ('00000000-0000-0000-0000-00000000000b', 'org-b');

-- planted:  a Supabase Auth account that created its own row before the migration ran,
--           with auth0_id set to its own uuid so the api_keys policies match it.
-- customer: provisioned by /signup. auth0_id is an Auth0 sub; no JWT ever carries its id.
-- linked:   a customer bridged to Supabase Auth account ...c3 through auth_user_links.
insert into public.users (id, auth0_id, email) values
  ('00000000-0000-0000-0000-000000000001', '00000000-0000-0000-0000-000000000001', 'planted@test'),
  ('00000000-0000-0000-0000-000000000002', 'auth0|customer', 'customer@test'),
  ('00000000-0000-0000-0000-000000000003', 'auth0|linked', 'linked@test');

insert into public.auth_user_links (auth_user_id, app_user_id) values
  ('00000000-0000-0000-0000-0000000000c3', '00000000-0000-0000-0000-000000000003');

insert into public.api_keys (id, user_id, organization_id, hash) values
  ('00000000-0000-0000-0000-0000000000f1', '00000000-0000-0000-0000-000000000001', '00000000-0000-0000-0000-00000000000a', 'hash-planted'),
  ('00000000-0000-0000-0000-0000000000f2', '00000000-0000-0000-0000-000000000002', '00000000-0000-0000-0000-00000000000b', 'hash-customer'),
  ('00000000-0000-0000-0000-0000000000f3', '00000000-0000-0000-0000-000000000003', '00000000-0000-0000-0000-00000000000b', 'hash-linked');
