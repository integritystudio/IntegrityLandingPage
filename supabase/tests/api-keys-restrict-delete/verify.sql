\set ON_ERROR_STOP on

-- Assertions for 20260930000000_api_keys_restrict_delete.sql (UA13).
-- Run via ./run.sh. Each mutating test runs in begin/rollback so tests are
-- independent and all start from the fixture state.

create or replace function public.assert_eq(label text, actual text, expected text) returns void
language plpgsql as $$
begin
  if actual is distinct from expected then
    raise exception 'FAIL %: got % expected %', label, coalesce(actual, 'NULL'), coalesce(expected, 'NULL');
  end if;
  raise notice 'PASS %', label;
end $$;

-- Runs `stmt` and passes only if it fails with a foreign-key violation (23503).
create or replace function public.assert_refused(label text, stmt text) returns void
language plpgsql as $$
begin
  begin
    execute stmt;
  exception when foreign_key_violation then
    raise notice 'PASS %', label;
    return;
  end;
  raise exception 'FAIL %: the delete succeeded', label;
end $$;

create or replace function public.key_count() returns text
language sql as $$ select count(*)::text from public.api_keys $$;

-- T1 both constraints now refuse rather than cascade ('r' = RESTRICT in pg_constraint)
select assert_eq('T1a api_keys_user_id_fkey is ON DELETE RESTRICT',
  (select confdeltype::text from pg_constraint where conname = 'api_keys_user_id_fkey'), 'r');
select assert_eq('T1b api_keys_organization_id_fkey is ON DELETE RESTRICT',
  (select confdeltype::text from pg_constraint where conname = 'api_keys_organization_id_fkey'), 'r');

-- T2 deleting a user who holds a key is refused, and the key row survives
select assert_refused('T2a delete of a key-holding user is refused',
  $$delete from public.users where email = 'keyholder@test'$$);
select assert_eq('T2b no key row was removed', key_count(), '2');

-- T3 the Supabase admin path (auth.users -> public.users CASCADE) is refused the same way
select assert_refused('T3 delete of a key holder''s auth.users entry is refused',
  $$delete from auth.users where id = '00000000-0000-0000-0000-000000000001'$$);

-- T4 deleting an org that holds keys is refused
select assert_refused('T4 delete of an org holding keys is refused',
  $$delete from public.organizations where slug = 'keyed-org'$$);

-- T5 a revoked row blocks too: revocation keeps the row, so it must be deleted first
select assert_refused('T5 delete of a user holding only a revoked key is refused',
  $$delete from public.users where email = 'revoked@test'$$);

-- T6 the supported order works: delete the user's key rows, then the user
begin;
delete from public.api_keys where user_id = '00000000-0000-0000-0000-000000000001';
delete from auth.users where id = '00000000-0000-0000-0000-000000000001';
select assert_eq('T6a user deleted once their keys are gone',
  (select count(*)::text from public.users where email = 'keyholder@test'), '0');
select assert_eq('T6b their memberships still cascade',
  (select count(*)::text from public.organization_memberships
    where user_id = '00000000-0000-0000-0000-000000000001'), '0');
rollback;

-- T7 a user and an org with no keys delete as before (the signup rollback path)
begin;
delete from public.users where email = 'keyless@test';
delete from public.organizations where slug = 'keyless-org';
select assert_eq('T7a key-less user deleted', (select count(*)::text from public.users where email = 'keyless@test'), '0');
select assert_eq('T7b key-less org deleted', (select count(*)::text from public.organizations where slug = 'keyless-org'), '0');
rollback;

-- T8 at rest, after every block above: nothing was lost
select assert_eq('T8 every key row is still present', key_count(), '2');
