\set ON_ERROR_STOP on

-- Assertions for 20260927000000_derive_users_tier_from_default_org.sql (UA04).
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

create or replace function public.tier_of(user_email text) returns text
language sql as $$ select tier::text from public.users where email = user_email $$;

-- T1 backfill corrected existing drift
select assert_eq('T1a backfill: stale starter under growth org -> growth', tier_of('stale@test'), 'growth');
select assert_eq('T1b backfill: no default org keeps stored value', tier_of('noorg@test'), 'growth');
select assert_eq('T1c backfill: plan ''free'' maps to starter', tier_of('free@test'), 'starter');

-- T2 insert derives from the default org, ignoring the supplied tier
begin;
insert into public.users (id, email, tier, default_organization_id)
values ('00000000-0000-0000-0000-000000000009', 'new@test', 'starter', '00000000-0000-0000-0000-00000000000c');
select assert_eq('T2 insert: supplied tier overridden by org plan', tier_of('new@test'), 'enterprise');
rollback;

-- T3 a direct write to tier is overwritten
begin;
update public.users set tier = 'enterprise' where email = 'stale@test';
select assert_eq('T3 direct tier write overwritten', tier_of('stale@test'), 'growth');
rollback;

-- T4 changing default org recomputes tier
begin;
update public.users set default_organization_id = '00000000-0000-0000-0000-00000000000c' where email = 'stale@test';
select assert_eq('T4 default org change recomputes tier', tier_of('stale@test'), 'enterprise');
rollback;

-- T5 plan change propagates to every user of that org, and only them
begin;
update public.organizations set current_plan = 'enterprise' where slug = 'growth-org';
select assert_eq('T5a plan change reaches owner', tier_of('stale@test'), 'enterprise');
select assert_eq('T5b plan change reaches teammate', tier_of('teammate@test'), 'enterprise');
select assert_eq('T5c other org untouched', tier_of('free@test'), 'starter');
select assert_eq('T5d no-org user untouched', tier_of('noorg@test'), 'growth');
rollback;

-- T6 unknown plan resolves to starter; mapping is case-insensitive
begin;
update public.organizations set current_plan = 'legacy-pro' where slug = 'growth-org';
select assert_eq('T6a unknown plan -> starter', tier_of('stale@test'), 'starter');
update public.organizations set current_plan = 'GROWTH' where slug = 'growth-org';
select assert_eq('T6b case-insensitive mapping', tier_of('stale@test'), 'growth');
rollback;

-- T7 a writer with no privilege on users still propagates (security definer)
begin;
set local role org_writer;
select assert_eq('T7 harness: role switched', current_user::text, 'org_writer');
update public.organizations set current_plan = 'starter' where slug = 'growth-org';
reset role;
select assert_eq('T7 propagation independent of caller grants on users', tier_of('stale@test'), 'starter');
rollback;

-- T8 clearing the default org leaves the last derived value in place
begin;
update public.users set default_organization_id = null where email = 'stale@test';
select assert_eq('T8 cleared default org keeps value', tier_of('stale@test'), 'growth');
rollback;

-- T9 invariant: every user with a default org carries that org's derived tier
select assert_eq('T9 invariant holds for all users with a default org',
  (select count(*)::text
     from public.users u join public.organizations o on o.id = u.default_organization_id
    where u.tier <> public.plan_to_api_key_tier(o.current_plan)),
  '0');

\echo 'all users-tier-derivation assertions passed'
