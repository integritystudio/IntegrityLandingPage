\set ON_ERROR_STOP on

-- Assertions for 20260929010000_default_org_from_first_membership.sql (CR50).
-- Run via ./run.sh. Each mutating test runs in begin/rollback so tests are
-- independent and all start from the post-backfill state.

create or replace function public.assert_eq(label text, actual text, expected text) returns void
language plpgsql as $$
begin
  if actual is distinct from expected then
    raise exception 'FAIL %: got % expected %', label, coalesce(actual, 'NULL'), coalesce(expected, 'NULL');
  end if;
  raise notice 'PASS %', label;
end $$;

create or replace function public.default_org_of(user_email text) returns text
language sql as $$
  select o.slug from public.users u left join public.organizations o on o.id = u.default_organization_id
   where u.email = user_email
$$;

create or replace function public.tier_of(user_email text) returns text
language sql as $$ select tier::text from public.users where email = user_email $$;

-- T1 backfill: oldest active membership, the org every reader already resolves
select assert_eq('T1a backfill: oldest active membership wins over a newer owner one', default_org_of('nodefault@test'), 'growth-org');
select assert_eq('T1b backfill: tier follows the backfilled org', tier_of('nodefault@test'), 'growth');
select assert_eq('T1c backfill: a chosen default is untouched', default_org_of('chosen@test'), 'enterprise-org');
select assert_eq('T1d backfill: an invited-only user stays null', default_org_of('invited@test'), null);
select assert_eq('T1e backfill: a user with no membership stays null', default_org_of('orphan@test'), null);

-- T2 a new user's first active membership sets the default, and tier follows it
begin;
insert into public.users (id, email) values ('00000000-0000-0000-0000-000000000009', 'new@test');
select assert_eq('T2a harness: new user starts with no default', default_org_of('new@test'), null);
insert into public.organization_memberships (organization_id, user_id, role)
values ('00000000-0000-0000-0000-00000000000c', '00000000-0000-0000-0000-000000000009', 'owner');
select assert_eq('T2b first membership sets the default', default_org_of('new@test'), 'enterprise-org');
select assert_eq('T2c tier derives from it', tier_of('new@test'), 'enterprise');

-- T3 a second membership does not move it
insert into public.organization_memberships (organization_id, user_id, role)
values ('00000000-0000-0000-0000-00000000000a', '00000000-0000-0000-0000-000000000009', 'owner');
select assert_eq('T3 second membership keeps the first default', default_org_of('new@test'), 'enterprise-org');

-- T4 the org's later plan change reaches the new user (CR50 acceptance)
update public.organizations set current_plan = 'growth' where slug = 'enterprise-org';
select assert_eq('T4 plan change reaches the new user', tier_of('new@test'), 'growth');
rollback;

-- T5 an invited membership sets nothing until it becomes active
begin;
insert into public.organization_memberships (organization_id, user_id, role, status)
values ('00000000-0000-0000-0000-00000000000c', '00000000-0000-0000-0000-000000000004', 'member', 'invited');
select assert_eq('T5a invited insert sets nothing', default_org_of('orphan@test'), null);
update public.organization_memberships set status = 'suspended'
 where user_id = '00000000-0000-0000-0000-000000000004';
select assert_eq('T5b suspended update sets nothing', default_org_of('orphan@test'), null);
update public.organization_memberships set status = 'active'
 where user_id = '00000000-0000-0000-0000-000000000004';
select assert_eq('T5c activation sets the default', default_org_of('orphan@test'), 'enterprise-org');
rollback;

-- T6 a chosen default survives a new active membership
begin;
insert into public.organization_memberships (organization_id, user_id, role)
values ('00000000-0000-0000-0000-00000000000b', '00000000-0000-0000-0000-000000000002', 'owner');
select assert_eq('T6 chosen default not overwritten', default_org_of('chosen@test'), 'enterprise-org');
rollback;

-- T7 a writer with no privilege on users still sets it (security definer)
begin;
set local role membership_writer;
select assert_eq('T7 harness: role switched', current_user::text, 'membership_writer');
insert into public.organization_memberships (organization_id, user_id, role)
values ('00000000-0000-0000-0000-00000000000b', '00000000-0000-0000-0000-000000000004', 'owner');
reset role;
select assert_eq('T7 default set independent of caller grants on users', default_org_of('orphan@test'), 'free-org');
rollback;

-- T8 invariant: nobody with an active membership is left without a default
select assert_eq('T8 invariant: every user with an active membership has a default',
  (select count(*)::text from public.users u
    where u.default_organization_id is null
      and exists (select 1 from public.organization_memberships m
                   where m.user_id = u.id and m.status = 'active')),
  '0');
