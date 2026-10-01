\set ON_ERROR_STOP on

-- Assertions for 20261001000000_default_org_set_at.sql. Run via ./run.sh. Each
-- mutating test runs in begin/rollback, so tests are independent and all start
-- from the post-migration state. Inside one transaction now() is constant, which
-- is what lets a test compare a stamp with now() or with a membership's created_at.

create or replace function public.assert_eq(label text, actual text, expected text) returns void
language plpgsql as $$
begin
  if actual is distinct from expected then
    raise exception 'FAIL %: got % expected %', label, coalesce(actual, 'NULL'), coalesce(expected, 'NULL');
  end if;
  raise notice 'PASS %', label;
end $$;

create or replace function public.stamp_of(user_email text) returns text
language sql as $$
  select default_organization_set_at::text from public.users where email = user_email
$$;

create or replace function public.default_org_of(user_email text) returns text
language sql as $$
  select o.slug from public.users u left join public.organizations o on o.id = u.default_organization_id
   where u.email = user_email
$$;

-- S1 existing rows are not given a history they do not have
select assert_eq('S1 existing rows stay null',
  (select count(*)::text from public.users where default_organization_set_at is not null), '0');

-- S2 a default set by the CR50 trigger carries the membership's created_at
begin;
insert into public.users (id, email) values ('00000000-0000-0000-0000-000000000009', 'new@test');
select assert_eq('S2a a new user with no default has no stamp', stamp_of('new@test'), null);
insert into public.organization_memberships (organization_id, user_id, role)
values ('00000000-0000-0000-0000-00000000000c', '00000000-0000-0000-0000-000000000009', 'owner');
select assert_eq('S2b harness: the CR50 trigger set the default', default_org_of('new@test'), 'enterprise-org');
select assert_eq('S2c stamp equals the membership created_at', stamp_of('new@test'),
  (select created_at::text from public.organization_memberships
    where user_id = '00000000-0000-0000-0000-000000000009'));
rollback;

-- S3 changing the default stamps it, and the UA04 tier trigger still runs
begin;
update public.users set default_organization_id = '00000000-0000-0000-0000-00000000000a'
 where email = 'chosen@test';
select assert_eq('S3a a changed default is stamped', stamp_of('chosen@test'), now()::text);
select assert_eq('S3b tier still follows the default', (select tier::text from public.users where email = 'chosen@test'), 'growth');
rollback;

-- S4 an unchanged default keeps its stamp, and a direct write is overwritten
begin;
update public.users set default_organization_id = '00000000-0000-0000-0000-00000000000c'
 where email = 'chosen@test';
select assert_eq('S4a re-writing the same default is not a change', stamp_of('chosen@test'), null);
update public.users set default_organization_set_at = '2000-01-01' where email = 'chosen@test';
select assert_eq('S4b a direct write to a null stamp is overwritten', stamp_of('chosen@test'), null);
update public.users set default_organization_id = '00000000-0000-0000-0000-00000000000a'
 where email = 'chosen@test';
update public.users set default_organization_set_at = '2000-01-01' where email = 'chosen@test';
select assert_eq('S4c a direct write to a set stamp is overwritten', stamp_of('chosen@test'), now()::text);
rollback;

-- S5 clearing the default is a change, and is stamped
begin;
update public.users set default_organization_id = null where email = 'nodefault@test';
select assert_eq('S5 clearing the default is stamped', stamp_of('nodefault@test'), now()::text);
rollback;

-- S6 on INSERT the stamp follows the default, whatever the writer supplies
begin;
insert into public.users (id, email, default_organization_id, default_organization_set_at) values
  ('00000000-0000-0000-0000-000000000010', 'insert-default@test', '00000000-0000-0000-0000-00000000000a', '2000-01-01'),
  ('00000000-0000-0000-0000-000000000011', 'insert-none@test',    null,                                    '2000-01-01');
select assert_eq('S6a an insert with a default is stamped now', stamp_of('insert-default@test'), now()::text);
select assert_eq('S6b an insert with no default has no stamp', stamp_of('insert-none@test'), null);
rollback;

-- S7 a membership writer with no grant on users still gets the stamp
begin;
set local role membership_writer;
select assert_eq('S7 harness: role switched', current_user::text, 'membership_writer');
insert into public.organization_memberships (organization_id, user_id, role)
values ('00000000-0000-0000-0000-00000000000b', '00000000-0000-0000-0000-000000000004', 'owner');
reset role;
select assert_eq('S7 stamp set independent of caller grants on users', stamp_of('orphan@test'),
  (select created_at::text from public.organization_memberships
    where user_id = '00000000-0000-0000-0000-000000000004'));
rollback;
