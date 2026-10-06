\set ON_ERROR_STOP on

-- Assertions for 20261006000000_retire_user_profiles.sql.
-- Run via ./run.sh. Every caller test runs in begin/rollback as the non-owner
-- `authenticated` role with the JWT claims PostgREST would set: SET LOCAL needs the
-- transaction, and the table owner bypasses RLS. assert_role() raises if the switch did
-- not take, so a test cannot pass by running as the owner.

create or replace function public.assert_role(expected text) returns void
language plpgsql as $$
begin
  if current_user <> expected then
    raise exception 'HARNESS BROKEN: current_user=% expected=%', current_user, expected;
  end if;
end $$;

create or replace function public.assert_eq(label text, actual text, expected text) returns void
language plpgsql as $$
begin
  if actual is distinct from expected then
    raise exception 'FAIL %: got % expected %', label, coalesce(actual, 'NULL'), coalesce(expected, 'NULL');
  end if;
  raise notice 'PASS %', label;
end $$;

-- The claims of a signed-in caller. Transaction-local, like the role.
create or replace function public.act_as(sub text) returns void
language plpgsql as $$
begin
  perform set_config('request.jwt.claims',
    json_build_object('sub', sub, 'role', 'authenticated')::text, true);
end $$;

-- Runs `stmt` and passes only if RLS stopped it: an insert refused with 42501, or an
-- update that matched no row. A missing table grant is 42501 too, so the message is
-- checked — otherwise a fixture without grants would pass every write test.
create or replace function public.assert_blocked(label text, stmt text) returns void
language plpgsql as $$
declare
  affected bigint;
begin
  begin
    execute stmt;
    get diagnostics affected = row_count;
  exception when insufficient_privilege then
    if sqlerrm not like '%row-level security%' then
      raise exception 'HARNESS BROKEN %: refused, but not by RLS: %', label, sqlerrm;
    end if;
    raise notice 'PASS %', label;
    return;
  end;
  if affected > 0 then
    raise exception 'FAIL %: the write went through (% row)', label, affected;
  end if;
  raise notice 'PASS %', label;
end $$;

-- T1 the four legacy objects are gone: table, view, trigger function, trigger
select assert_eq('T1a user_profiles is gone', (to_regclass('public.user_profiles') is null)::text, 'true');
select assert_eq('T1b user_details is gone', (to_regclass('public.user_details') is null)::text, 'true');
select assert_eq('T1c handle_new_user is gone',
  (select count(*)::text from pg_proc where pronamespace = 'public'::regnamespace and proname = 'handle_new_user'), '0');
select assert_eq('T1d on_auth_user_created is gone',
  (select count(*)::text from pg_trigger where tgrelid = 'auth.users'::regclass and tgname = 'on_auth_user_created'), '0');

-- T2 a Supabase Auth account can still be created: the trigger that fed the table no
-- longer runs on auth.users, and nothing else does
begin;
insert into auth.users (id, email) values ('00000000-0000-0000-0000-0000000000d4', 'new@test');
select assert_eq('T2 an auth.users insert still succeeds with no trigger on it',
  (select count(*)::text from pg_trigger where tgrelid = 'auth.users'::regclass and not tgisinternal), '0');
rollback;

-- W1 the account that planted its own users row before 20261005000000 can no longer edit it
begin;
set local role authenticated;
select assert_role('authenticated');
select act_as('00000000-0000-0000-0000-000000000001');
select assert_blocked('W1a a planted account cannot update its own users row',
  $$update public.users set email = 'taken@test' where id = '00000000-0000-0000-0000-000000000001'$$);
reset role;
select assert_eq('W1b the row is as it was',
  (select email from public.users where id = '00000000-0000-0000-0000-000000000001'), 'planted@test');
rollback;

-- R1 reads are untouched: an account still sees its own users row and its own key, only
begin;
set local role authenticated;
select assert_role('authenticated');
select act_as('00000000-0000-0000-0000-000000000001');
select assert_eq('R1a an account still reads its own users row and no other',
  (select string_agg(email, ',' order by email) from public.users), 'planted@test');
select assert_eq('R1b and its own key and no other',
  (select string_agg(hash, ',' order by hash) from public.api_keys), 'hash-planted');
rollback;

-- R2 the auth_user_links read path still resolves
begin;
set local role authenticated;
select assert_role('authenticated');
select act_as('00000000-0000-0000-0000-0000000000c3');
select assert_eq('R2 a linked account still reads its key',
  (select string_agg(hash, ',' order by hash) from public.api_keys), 'hash-linked');
rollback;

-- S1 the service role still writes users and api_keys: /signup, key creation, set-status
begin;
set local role service_role;
select assert_role('service_role');
insert into public.users (id, auth0_id, email)
  values ('00000000-0000-0000-0000-000000000005', 'auth0|signup', 'signup@test');
insert into public.api_keys (user_id, organization_id, hash)
  values ('00000000-0000-0000-0000-000000000005', '00000000-0000-0000-0000-00000000000a', 'hash-minted');
update public.api_keys set status = 'inactive' where hash = 'hash-minted';
select assert_eq('S1 the service role still inserts a user and a key and updates it',
  (select u.email || ' ' || k.status from public.api_keys k join public.users u on u.id = k.user_id
    where k.hash = 'hash-minted'),
  'signup@test inactive');
rollback;

-- C1 the invariant this migration completes: no write policy in public is usable by a
-- non-service caller. The same query guards every replay in scripts/check-migration-replay.sh.
select assert_eq('C1 no write policy in public is usable by a non-service caller',
  (select coalesce(string_agg(tablename || '.' || policyname, ', ' order by tablename, policyname), '')
     from pg_policies
    where schemaname = 'public' and cmd <> 'SELECT'
      and coalesce(qual, '') not like '%service_role%'
      and coalesce(with_check, '') not like '%service_role%'
      and coalesce(qual, '') <> 'false'),
  '');

-- C2 what is left on users is exactly its three read policies
select assert_eq('C2 users keeps exactly its three read policies',
  (select string_agg(policyname || ':' || cmd, ', ' order by policyname)
     from pg_policies where schemaname = 'public' and tablename = 'users'),
  'Users can read their own data:SELECT, Users can view own data:SELECT, users can view own profile:SELECT');

-- Z1 at rest, after every block above: nothing was added or changed
select assert_eq('Z1 the seeded users and keys are all that exist',
  (select count(*)::text from public.users) || ' ' ||
  (select string_agg(hash, ',' order by hash) from public.api_keys),
  '3 hash-customer,hash-linked,hash-planted');
