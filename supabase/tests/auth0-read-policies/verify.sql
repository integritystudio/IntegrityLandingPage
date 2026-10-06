\set ON_ERROR_STOP on

-- Assertions for 20261007000000_auth0_sub_read_policies.sql.
-- Run via ./run.sh. Every caller test runs in begin/rollback as a non-owner API role with
-- the JWT claims PostgREST would set: SET LOCAL needs the transaction, and the table owner
-- bypasses RLS. assert_role() raises if the switch did not take, so a test cannot pass by
-- running as the owner.

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

-- The claims of a signed-in caller. Transaction-local, like the role. A third-party token
-- carries exactly these two once the Action sets role = authenticated (CR62 step 2).
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

-- Runs `stmt` and passes only if it is refused with 42501 for lack of EXECUTE.
create or replace function public.assert_no_execute(label text, stmt text) returns void
language plpgsql as $$
begin
  execute stmt;
  raise exception 'FAIL %: the call was allowed', label;
exception when insufficient_privilege then
  if sqlerrm not like '%permission denied for function%' then
    raise exception 'HARNESS BROKEN %: refused, but not for EXECUTE: %', label, sqlerrm;
  end if;
  raise notice 'PASS %', label;
end $$;

-- A1 an Auth0 subject reads its own rows on every own-row table, and no other
begin;
set local role authenticated;
select assert_role('authenticated');
select act_as('auth0|customer');
select assert_eq('A1a users: own row only',
  (select string_agg(email, ',' order by email) from public.users), 'customer@test');
select assert_eq('A1b api_keys: own key only',
  (select string_agg(hash, ',' order by hash) from public.api_keys), 'hash-customer');
select assert_eq('A1c user_roles: own row only',
  (select string_agg(user_id::text, ',') from public.user_roles), '00000000-0000-0000-0000-000000000002');
select assert_eq('A1d user_activity: own row only',
  (select string_agg(activity_type, ',' order by activity_type) from public.user_activity), 'act-customer');
select assert_eq('A1e organization_memberships: own rows, suspended one included',
  (select string_agg(role || ':' || status, ',' order by role) from public.organization_memberships),
  'member:suspended,owner:active');
select assert_eq('A1f auth_user_links: nothing, this subject has no bridge row',
  (select count(*)::text from public.auth_user_links), '0');
rollback;

-- A2 org-scoped tables answer for the active membership only; the suspended one grants
--    nothing on org-b, and the ancestor walk reaches org-parent
begin;
set local role authenticated;
select assert_role('authenticated');
select act_as('auth0|customer');
select assert_eq('A2a organizations: member org and its ancestor, not the suspended org',
  (select string_agg(slug, ',' order by slug) from public.organizations), 'org-a,org-parent');
select assert_eq('A2b subscriptions',
  (select string_agg(stripe_subscription_id, ',') from public.subscriptions), 'sub_a');
select assert_eq('A2c entitlements',
  (select string_agg(feature_key, ',') from public.entitlements), 'feat-a');
select assert_eq('A2d usage_events',
  (select string_agg(metric_key, ',') from public.usage_events), 'ue-a');
select assert_eq('A2e usage_buckets_daily',
  (select string_agg(metric_key, ',') from public.usage_buckets_daily), 'ub-a');
select assert_eq('A2f audit_log: an owner reads it',
  (select string_agg(action, ',') from public.audit_log), 'al-a');
select assert_eq('A2g billing_event_log: an owner reads it',
  (select string_agg(event_type, ',') from public.billing_event_log), 'bl-a');
rollback;

-- A3 role narrowing: an admin reads audit_log but not billing_event_log; a member neither
begin;
set local role authenticated;
select assert_role('authenticated');
select act_as('auth0|other');
select assert_eq('A3a an admin reads its org audit_log',
  (select string_agg(action, ',') from public.audit_log), 'al-b');
select assert_eq('A3b an admin does not read billing_event_log',
  (select count(*)::text from public.billing_event_log), '0');
select assert_eq('A3c an admin reads its org subscriptions',
  (select string_agg(stripe_subscription_id, ',') from public.subscriptions), 'sub_b');
select act_as('auth0|linked');
select assert_eq('A3d a member reads neither log',
  (select count(*) from public.audit_log)::text || ' ' || (select count(*) from public.billing_event_log)::text, '0 0');
select assert_eq('A3e but reads its org subscriptions and organizations',
  (select string_agg(stripe_subscription_id, ',') from public.subscriptions) || ' ' ||
  (select string_agg(slug, ',') from public.organizations), 'sub_b org-b');
rollback;

-- A4 a Supabase Auth account still resolves through auth_user_links
begin;
set local role authenticated;
select assert_role('authenticated');
select act_as('00000000-0000-0000-0000-0000000000c3');
select assert_eq('A4a users via the bridge',
  (select string_agg(email, ',') from public.users), 'linked@test');
select assert_eq('A4b api_keys via the bridge',
  (select string_agg(hash, ',') from public.api_keys), 'hash-linked');
select assert_eq('A4c organizations via the bridge',
  (select string_agg(slug, ',') from public.organizations), 'org-b');
select assert_eq('A4d its own auth_user_links row',
  (select string_agg(auth_user_id::text, ',') from public.auth_user_links), '00000000-0000-0000-0000-0000000000c3');
rollback;

-- A5 a uuid subject with no bridge row resolves to nobody, even though a users row carries
--    that uuid as its auth0_id and id (the shape CR61's planted account had)
begin;
set local role authenticated;
select assert_role('authenticated');
select act_as('00000000-0000-0000-0000-000000000001');
select assert_eq('A5 an unbridged uuid subject reads no users row and no key',
  (select count(*) from public.users)::text || ' ' || (select count(*) from public.api_keys)::text, '0 0');
rollback;

-- A6 a stranger's Auth0 token reads nothing but the public tables, and raises nothing
begin;
set local role authenticated;
select assert_role('authenticated');
select act_as('auth0|stranger');
select assert_eq('A6a a stranger reads no private row on any table',
  (select count(*) from public.users)::text || (select count(*) from public.api_keys)::text ||
  (select count(*) from public.organizations)::text || (select count(*) from public.organization_memberships)::text ||
  (select count(*) from public.subscriptions)::text || (select count(*) from public.entitlements)::text ||
  (select count(*) from public.usage_events)::text || (select count(*) from public.usage_buckets_daily)::text ||
  (select count(*) from public.user_activity)::text || (select count(*) from public.user_roles)::text ||
  (select count(*) from public.audit_log)::text || (select count(*) from public.billing_event_log)::text ||
  (select count(*) from public.auth_user_links)::text, '0000000000000');
select assert_eq('A6b and still the public plans and roles',
  (select string_agg(key, ',') from public.plans) || ' ' || (select string_agg(name, ',') from public.roles),
  'starter provisioned-dashboard-viewer');
rollback;

-- A7 anon: no claims, the public reads only, and the resolvers are not callable
begin;
set local role anon;
select assert_role('anon');
select assert_eq('A7a anon reads no users row',
  (select count(*)::text from public.users), '0');
select assert_eq('A7b anon reads no organizations row',
  (select count(*)::text from public.organizations), '0');
select assert_eq('A7c anon reads plans',
  (select string_agg(key, ',') from public.plans), 'starter');
select assert_no_execute('A7d anon cannot call current_app_user_id()',
  'select public.current_app_user_id()');
select assert_no_execute('A7e anon cannot call current_user_org_ids()',
  'select public.current_user_org_ids()');
rollback;

-- A8 the write side is as CR61 left it: an Auth0 subject with the authenticated role
--    still cannot write its own rows
begin;
set local role authenticated;
select assert_role('authenticated');
select act_as('auth0|customer');
select assert_blocked('A8a an Auth0 subject cannot update its users row',
  $$update public.users set email = 'taken@test' where id = '00000000-0000-0000-0000-000000000002'$$);
select assert_blocked('A8b nor insert a key row',
  $$insert into public.api_keys (user_id, organization_id, hash)
    values ('00000000-0000-0000-0000-000000000002', '00000000-0000-0000-0000-00000000000a', 'hash-forged')$$);
select assert_blocked('A8c nor promote its suspended membership',
  $$update public.organization_memberships set status = 'active', role = 'owner'
    where user_id = '00000000-0000-0000-0000-000000000002' and organization_id = '00000000-0000-0000-0000-00000000000b'$$);
rollback;

-- S1 the service role bypasses every policy, as the Workers rely on
begin;
set local role service_role;
select assert_role('service_role');
select assert_eq('S1 the service role reads every users row',
  (select count(*)::text from public.users), '4');
rollback;

-- C1 the catalog: nothing in public calls auth.uid() any more
select assert_eq('C1a no policy in public calls auth.uid()',
  (select count(*)::text from pg_policies
    where schemaname = 'public'
      and (coalesce(qual, '') like '%auth.uid()%' or coalesce(with_check, '') like '%auth.uid()%')), '0');
select assert_eq('C1b no function in public calls auth.uid()',
  (select count(*)::text from pg_proc
    where pronamespace = 'public'::regnamespace and prosrc like '%auth.uid()%'), '0');

-- C2 every private read policy is to authenticated; the public reads stay public
select assert_eq('C2 select policies not restricted to authenticated are exactly the public reads',
  (select string_agg(tablename || '.' || policyname, ', ' order by tablename, policyname)
     from pg_policies
    where schemaname = 'public' and cmd = 'SELECT' and roles <> '{authenticated}'),
  'plans.plans_public_read, roles.Anyone can view roles');

-- C3 the CR61 invariant: no write policy usable by a non-service caller
select assert_eq('C3 no write policy usable by a non-service caller',
  (select coalesce(string_agg(tablename || '.' || policyname, ', ' order by tablename, policyname), '<none>')
     from pg_policies
    where schemaname = 'public' and cmd <> 'SELECT'
      and coalesce(qual, '') not like '%service_role%'
      and coalesce(with_check, '') not like '%service_role%'
      and coalesce(qual, '') <> 'false'), '<none>');

-- C4 the resolvers are security definer with an empty search_path, executable by the API
--    roles that reach a policy and by nobody else
select assert_eq('C4 resolver definitions',
  (select string_agg(proname || ':' || prosecdef::text || ':' || array_to_string(proconfig, ';') || ':' ||
            coalesce((select string_agg(grantee, '+' order by grantee)
                        from information_schema.routine_privileges rp
                       where rp.specific_schema = 'public' and rp.routine_name = p.proname
                         and rp.privilege_type = 'EXECUTE' and rp.grantee <> current_user), '-'),
          ', ' order by proname)
     from pg_proc p
    where pronamespace = 'public'::regnamespace
      and proname in ('current_app_user_id', 'current_user_org_ids', 'user_ancestor_org_ids')),
  'current_app_user_id:true:search_path="":authenticated+service_role, ' ||
  'current_user_org_ids:true:search_path="":authenticated+service_role, ' ||
  'user_ancestor_org_ids:true:search_path="":PUBLIC');

-- Z1 at rest, after every block above: nothing was added or changed
select assert_eq('Z1 the seeded rows are all that exist',
  (select count(*) from public.users)::text || ' ' ||
  (select string_agg(hash, ',' order by hash) from public.api_keys) || ' ' ||
  (select count(*) from public.organization_memberships)::text,
  '4 hash-customer,hash-linked,hash-other,hash-planted 4');
