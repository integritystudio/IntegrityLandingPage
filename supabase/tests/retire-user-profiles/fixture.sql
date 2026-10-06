-- Fixture for the retire-user-profiles migration test.
--
-- Starts from client-write-policies' fixture (users, api_keys, every policy on them, the
-- API roles) with that suite's migration applied, which is the state production was in
-- when this migration was written. Then adds what this migration removes, as production
-- holds it: `user_profiles` with its four policies and FK, the `handle_new_user` trigger on
-- `auth.users` that fed it, and the `user_details` view that joins it.

\ir ../client-write-policies/fixture.sql
\ir ../../migrations/20261005000000_drop_client_write_policies.sql

-- Only the columns the trigger function writes; production's has 30-odd more.
create table auth.users (
  id uuid primary key,
  email text,
  raw_user_meta_data jsonb
);

create table public.user_profiles (
  id uuid primary key default gen_random_uuid(),
  user_id uuid unique references public.users(id) on delete cascade,
  email text,
  full_name text,
  created_at timestamptz default now(),
  updated_at timestamptz default now()
);

alter table public.user_profiles enable row level security;

create policy "Users can insert own profile" on public.user_profiles
  as permissive for insert to public
  with check ((auth.uid() = id));

create policy "Users can view own profile" on public.user_profiles
  as permissive for select to public
  using ((user_id IN ( SELECT users.id FROM users WHERE ((users.auth0_id)::text = (auth.uid())::text))));

create policy "users can view own user_profile" on public.user_profiles
  as permissive for select to public
  using ((user_id = auth.uid()));

create policy "Users can update own profile" on public.user_profiles
  as permissive for update to public
  using ((user_id IN ( SELECT users.id FROM users WHERE ((users.auth0_id)::text = (auth.uid())::text))));

-- Production's trigger function, verbatim (pg_get_functiondef 2026-10-06). It is in no
-- migration: the legacy app created it from the dashboard.
create function public.handle_new_user() returns trigger
language plpgsql security definer set search_path to 'public' as $$
  BEGIN
    INSERT INTO public.user_profiles (id, email, full_name, created_at, updated_at)
    VALUES (
      NEW.id,
      NEW.email,
      COALESCE(NEW.raw_user_meta_data->>'full_name', NULL),
      NOW(),
      NOW()
    );
    RETURN NEW;
  EXCEPTION
    WHEN unique_violation THEN
      RETURN NEW;
    WHEN OTHERS THEN
      RAISE WARNING 'Failed to create profile for user %: %', NEW.id, SQLERRM;
      RETURN NEW;
  END;
$$;

create trigger on_auth_user_created after insert on auth.users
  for each row execute function public.handle_new_user();

-- The view as 20260803020000 defines it, minus the roles aggregate, which needs columns
-- this fixture's `roles` lacks and which the migration does not touch.
create view public.user_details as
  select u.id, u.auth0_id, u.email, p.full_name
  from public.users u
  left join public.user_profiles p on u.id = p.user_id;

grant all on public.user_profiles, auth.users to authenticated, service_role;
grant select on public.user_details to authenticated;

-- The customer's profile row (user_id set), and the legacy shape: a row keyed by a
-- Supabase Auth uuid with no user_id, as all 193 production rows were.
insert into public.user_profiles (id, user_id, email, full_name) values
  ('00000000-0000-0000-0000-0000000000a2', '00000000-0000-0000-0000-000000000002', 'customer@test', 'Customer'),
  ('00000000-0000-0000-0000-0000000000c3', null, 'linked@test', null);
