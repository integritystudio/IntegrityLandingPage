\set ON_ERROR_STOP on

-- Assertions for 20260731010000_add_organization_hierarchy.sql.
-- Run via ./run.sh — it builds a throwaway cluster, loads fixture.sql, applies
-- the migration, then runs this file. Any FAIL aborts with a non-zero exit.
--
-- TWO HARNESS TRAPS, both of which cause silent false-passes:
--
--  1. `SET LOCAL` outside a transaction is a no-op that only emits a WARNING.
--     The role never switches, queries run as the table owner, and every
--     visibility assertion passes vacuously. Every role-switching test below is
--     therefore wrapped in an explicit begin/…/rollback.
--  2. A table's OWNER bypasses RLS even when it is enabled. Switching to the
--     non-owner `authenticated` role is what makes the policies apply at all.
--
-- assert_role() guards both: it runs inside each transaction and raises if the
-- switch did not take. An earlier revision of this file lacked it and reported
-- four green visibility tests that were all bypassing RLS.

create or replace function public.assert_role(expected text) returns void
language plpgsql as $$
begin
  if current_user <> expected then
    raise exception 'HARNESS BROKEN: current_user=% expected=%', current_user, expected;
  end if;
end $$;

-- Compares the caller's RLS-visible org slugs against an expected CSV set.
-- Order-insensitive; reports both directions of the diff on failure.
create or replace function public.assert_visible(label text, expected text) returns void
language plpgsql as $$
declare
  actual_set text[];
  expected_set text[];
begin
  select coalesce(array_agg(slug order by slug), '{}') into actual_set
  from public.organizations;

  select coalesce(array_agg(trim(s) order by trim(s)), '{}') into expected_set
  from unnest(string_to_array(expected, ',')) s
  where trim(s) <> '';

  if actual_set = expected_set then
    raise notice 'PASS  %  -> %', label,
      case when cardinality(actual_set) = 0 then '(no rows)'
           else array_to_string(actual_set, ', ') end;
  else
    raise exception E'FAIL  %\n  expected: %\n  actual:   %\n  missing:  %\n  extra:    %',
      label,
      array_to_string(expected_set, ', '),
      array_to_string(actual_set, ', '),
      array_to_string(array(select unnest(expected_set) except select unnest(actual_set)), ', '),
      array_to_string(array(select unnest(actual_set) except select unnest(expected_set)), ', ');
  end if;
end $$;

\echo ''
\echo '################ organization-hierarchy migration ################'
\echo ''

\echo '--- T0  harness: role switch actually takes effect'
begin;
  set local role authenticated;
  select public.assert_role('authenticated');
rollback;
\echo 'PASS  T0  role switch verified (assert_role would have raised)'

\echo ''
\echo '--- T1  parent linkage recorded'
do $$
declare r record;
begin
  select c.slug as child, p.slug as parent, p.type::text as parent_type into r
  from public.organizations c
  join public.organizations p on p.id = c.parent_organization_id;

  if r.child = 'team-integritystudio.ai'
     and r.parent = 'integrity-studio-ai'
     and r.parent_type = 'parent-organization' then
    raise notice 'PASS  T1  % -> % (%)', r.child, r.parent, r.parent_type;
  else
    raise exception 'FAIL  T1  unexpected linkage: %', r;
  end if;
end $$;

\echo ''
\echo '--- T2  self-parent rejected by CHECK constraint'
do $$
begin
  update public.organizations
    set parent_organization_id = id
    where id = '38567a26-c19c-4b34-9c42-d377761bb50c';
  raise exception 'FAIL  T2  self-parent was allowed';
exception when check_violation then
  raise notice 'PASS  T2  self-parent rejected';
end $$;

\echo ''
\echo '--- T3  member of child org sees child AND parent, nothing else'
begin;
  set local role authenticated;
  set local test.auth_uid = 'aaaaaaaa-0000-0000-0000-000000000001';
  select public.assert_role('authenticated');
  select public.assert_visible('T3  chandra (member of team-integritystudio.ai)',
    'integrity-studio-ai, team-integritystudio.ai');
rollback;

\echo ''
\echo '--- T4  unrelated user sees only their own org (no parent leak)'
begin;
  set local role authenticated;
  set local test.auth_uid = 'aaaaaaaa-0000-0000-0000-000000000002';
  select public.assert_role('authenticated');
  select public.assert_visible('T4  outsider (member of parentless team-gmail.com)',
    'team-gmail.com');
rollback;

\echo ''
\echo '--- T5  no JWT -> zero rows'
begin;
  set local role authenticated;
  set local test.auth_uid = '';
  select public.assert_role('authenticated');
  select public.assert_visible('T5  anonymous', '');
rollback;

\echo ''
\echo '--- T6  inactive membership confers nothing'
begin;
  insert into public.users (id, email) values
    ('33333333-3333-3333-3333-333333333333', 'inactive@integritystudio.ai');
  insert into public.auth_user_links (app_user_id, auth_user_id) values
    ('33333333-3333-3333-3333-333333333333', 'aaaaaaaa-0000-0000-0000-000000000003');
  insert into public.organization_memberships (organization_id, user_id, role, status) values
    ('38567a26-c19c-4b34-9c42-d377761bb50c', '33333333-3333-3333-3333-333333333333', 'admin', 'invited');

  set local role authenticated;
  set local test.auth_uid = 'aaaaaaaa-0000-0000-0000-000000000003';
  select public.assert_role('authenticated');
  select public.assert_visible('T6  invited-but-not-active member', '');
rollback;

\echo ''
\echo '--- T7  walk is UPWARD only: parent member gains no children'
begin;
  insert into public.users (id, email) values
    ('44444444-4444-4444-4444-444444444444', 'umbrella@integritystudio.ai');
  insert into public.auth_user_links (app_user_id, auth_user_id) values
    ('44444444-4444-4444-4444-444444444444', 'aaaaaaaa-0000-0000-0000-000000000004');
  insert into public.organization_memberships (organization_id, user_id, role, status) values
    ('29edb193-ae7f-4863-9bb6-e245da74ec1f', '44444444-4444-4444-4444-444444444444', 'owner', 'active');

  set local role authenticated;
  set local test.auth_uid = 'aaaaaaaa-0000-0000-0000-000000000004';
  select public.assert_role('authenticated');
  select public.assert_visible('T7  owner of the umbrella org', 'integrity-studio-ai');
rollback;

\echo ''
\echo '--- T8  cycle (a -> b -> a) terminates instead of hanging'
begin;
  insert into public.organizations (id, slug, name, type) values
    ('aaaa1111-0000-0000-0000-00000000000a', 'cycle-a', 'Cycle A', 'team'),
    ('bbbb2222-0000-0000-0000-00000000000b', 'cycle-b', 'Cycle B', 'team');
  update public.organizations set parent_organization_id = 'bbbb2222-0000-0000-0000-00000000000b'
    where id = 'aaaa1111-0000-0000-0000-00000000000a';
  update public.organizations set parent_organization_id = 'aaaa1111-0000-0000-0000-00000000000a'
    where id = 'bbbb2222-0000-0000-0000-00000000000b';
  insert into public.organization_memberships (organization_id, user_id, role, status) values
    ('aaaa1111-0000-0000-0000-00000000000a', '11111111-1111-1111-1111-111111111111', 'member', 'active');

  -- If UNION dedup failed to absorb the cycle this raises 57014 instead of hanging.
  set local statement_timeout = '5s';
  set local role authenticated;
  set local test.auth_uid = 'aaaaaaaa-0000-0000-0000-000000000001';
  select public.assert_role('authenticated');
  select public.assert_visible('T8  member of cycle-a (also still in team-integritystudio.ai)',
    'cycle-a, cycle-b, integrity-studio-ai, team-integritystudio.ai');
rollback;

\echo ''
\echo '--- T9  multi-level walk reaches the grandparent'
begin;
  -- home -> team-integritystudio.ai -> integrity-studio-ai, member on home.
  update public.organizations set parent_organization_id = '38567a26-c19c-4b34-9c42-d377761bb50c'
    where id = 'f4286657-da73-4174-9e49-937f1bb6097f';
  insert into public.organization_memberships (organization_id, user_id, role, status) values
    ('f4286657-da73-4174-9e49-937f1bb6097f', '22222222-2222-2222-2222-222222222222', 'admin', 'active');

  set local role authenticated;
  set local test.auth_uid = 'aaaaaaaa-0000-0000-0000-000000000002';
  select public.assert_role('authenticated');
  select public.assert_visible('T9  member of home, two levels below the umbrella',
    'home, integrity-studio-ai, team-gmail.com, team-integritystudio.ai');
rollback;

\echo ''
\echo '--- T10  a naive inline policy WOULD recurse (documents why the function exists)'
do $$
begin
  execute $ddl$
    create policy "naive_parent_probe" on public.organizations for select
      using (exists (
        select 1 from public.organization_memberships m
        join public.auth_user_links ual on m.user_id = ual.app_user_id
        join public.organizations child on child.id = m.organization_id
        where child.parent_organization_id = public.organizations.id
          and ual.auth_user_id = auth.uid() and m.status = 'active'))
  $ddl$;

  begin
    set local role authenticated;
    set local test.auth_uid = 'aaaaaaaa-0000-0000-0000-000000000001';
    perform 1 from public.organizations;
    reset role;
    execute 'drop policy "naive_parent_probe" on public.organizations';
    raise exception 'FAIL  T10  naive inline policy did NOT recurse — the security definer indirection may no longer be needed, re-evaluate';
  exception when others then
    reset role;
    if sqlerrm like '%infinite recursion%' then
      execute 'drop policy "naive_parent_probe" on public.organizations';
      raise notice 'PASS  T10  naive policy recurses as expected (%)', sqlerrm;
    else
      execute 'drop policy "naive_parent_probe" on public.organizations';
      raise;
    end if;
  end;
end $$;

\echo ''
\echo '################ all assertions passed ################'
\echo ''
