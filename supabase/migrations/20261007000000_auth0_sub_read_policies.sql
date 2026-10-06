-- CR62 step 3: read policies that answer for an Auth0 subject.
--
-- Supabase Third-Party Auth (Auth0) is on for production. A token it accepts carries
-- `sub = auth0|…`, and auth.uid() casts the subject to uuid, so every policy that calls it
-- raises `22P02 invalid input syntax for type uuid` for such a token — measured in the local
-- harness 2026-10-05 (supabase/tests/auth0-read-policies, fixture pre-check). An error in any
-- permissive policy fails the whole statement, so the api_keys policies that already matched
-- auth.jwt() ->> 'sub' never got to answer either. 22 policies on 13 tables, plus
-- user_ancestor_org_ids(), called auth.uid().
--
-- One resolver replaces every identity predicate:
--
--   public.current_app_user_id()
--     sub is an Auth0 subject  -> users.auth0_id = sub
--     sub is a uuid            -> auth_user_links.auth_user_id = sub   (a Supabase Auth
--                                 account; the bridge custom_access_token_hook uses)
--   public.current_user_org_ids(allowed_roles)
--     the caller's active memberships, optionally narrowed to roles
--
-- Both are security definer so the lookup does not pass through users',
-- auth_user_links' or organization_memberships' own RLS (supabase/tests/README.md trap 3),
-- with search_path = '' so nothing in the caller's path is resolved, and executable only by
-- `authenticated` and `service_role`: anon never reaches a policy that calls them.
--
-- Per table, the duplicated pairs collapse to one policy `to authenticated` — the role a
-- third-party token maps to when its Action sets `role = authenticated`, and the role every
-- Supabase Auth token already has. anon keeps the plans/roles public reads. No write policy
-- is added or changed: CR61's invariant (scripts/check-migration-replay.sh) still holds.
--
-- What the collapse drops, and why nothing loses access:
--   * The baseline's `m.user_id = auth.uid()` family compared an app user id with an auth
--     user id. The two are different uuids for every user provisioned by /signup or the
--     Action, so it matched nothing it was meant to.
--   * users: `auth.uid() = id` and `auth.uid()::text = auth0_id` matched only a Supabase
--     Auth account that had created its own users row — CR61 closed that door, and 0 users
--     on production have a uuid-shaped auth0_id (2026-10-06).
--   * subscriptions "users can view subscriptions for their orgs" admitted an owner or
--     billing_admin whose membership was suspended; the surviving predicate is active
--     membership, any role, as 20260803010000 defined it.
--   * audit_log keeps its owner/admin narrowing and billing_event_log its
--     owner/billing_admin narrowing, on active memberships.
--
-- Verified by supabase/tests/auth0-read-policies (local harness; PG 17 in CI).

begin;

-- 1. Resolvers ---------------------------------------------------------------------------

-- plpgsql, not sql: a sql body is inlined, the planner pulls the claim subquery up and
-- evaluates `sub::uuid` as an init-plan before CASE picks an arm, so an Auth0 subject raised
-- 22P02 anyway (caught by the suite's first run). plpgsql evaluates the branches in order.
create or replace function public.current_app_user_id()
returns uuid
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  sub text := auth.jwt() ->> 'sub';
begin
  if sub is null then
    return null;
  elsif sub ~* '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$' then
    return (select l.app_user_id
              from public.auth_user_links l
             where l.auth_user_id = sub::uuid);
  else
    return (select u.id
              from public.users u
             where u.auth0_id = sub);
  end if;
end;
$$;

comment on function public.current_app_user_id() is
  'The public.users id of the caller: an Auth0 subject via users.auth0_id, a Supabase Auth '
  'uuid via auth_user_links. NULL for anon, a stranger, or an unbridged uuid. Never casts '
  'the subject to uuid, which is what made auth.uid() raise for Auth0 tokens (CR62).';

create or replace function public.current_user_org_ids(allowed_roles text[] default null)
returns setof uuid
language sql
stable
security definer
set search_path = ''
as $$
  select m.organization_id
    from public.organization_memberships m
   where m.user_id = public.current_app_user_id()
     and m.status = 'active'
     and (allowed_roles is null or m.role = any (allowed_roles));
$$;

comment on function public.current_user_org_ids(text[]) is
  'Organizations the caller is an active member of, narrowed to allowed_roles when given. '
  'Backs every org-scoped read policy (CR62).';

revoke all on function public.current_app_user_id() from public;
revoke all on function public.current_user_org_ids(text[]) from public;
grant execute on function public.current_app_user_id() to authenticated, service_role;
grant execute on function public.current_user_org_ids(text[]) to authenticated, service_role;

-- user_ancestor_org_ids() (20260731010000) resolved the caller through auth_user_links and
-- auth.uid(); same shape, same security definer, now through the resolver.
create or replace function public.user_ancestor_org_ids()
returns setof uuid
language sql
stable
security definer
set search_path = ''
as $$
  with recursive member_orgs as (
    select o.id, o.parent_organization_id
      from public.organizations o
     where o.id in (select public.current_user_org_ids())
  ),
  ancestors as (
    select mo.parent_organization_id as id
      from member_orgs mo
     where mo.parent_organization_id is not null
    union
    select o.parent_organization_id
      from ancestors a
      join public.organizations o on o.id = a.id
     where o.parent_organization_id is not null
  )
  select distinct id from ancestors;
$$;

-- 2. Own-row tables ----------------------------------------------------------------------

drop policy if exists "Users can read their own data" on public.users;
drop policy if exists "Users can view own data" on public.users;
drop policy if exists "users can view own profile" on public.users;
create policy users_read_own on public.users
  for select to authenticated
  using (id = public.current_app_user_id());

drop policy if exists users_read_own_keys on public.api_keys;
drop policy if exists users_view_own_api_keys on public.api_keys;
create policy api_keys_read_own on public.api_keys
  for select to authenticated
  using (user_id = public.current_app_user_id());

drop policy if exists users_view_own_auth_link on public.auth_user_links;
create policy auth_user_links_read_own on public.auth_user_links
  for select to authenticated
  using (app_user_id = public.current_app_user_id());

drop policy if exists "Users can view own roles" on public.user_roles;
create policy user_roles_read_own on public.user_roles
  for select to authenticated
  using (user_id = public.current_app_user_id());

drop policy if exists "Users can view own activity" on public.user_activity;
drop policy if exists "users can view own activity" on public.user_activity;
create policy user_activity_read_own on public.user_activity
  for select to authenticated
  using (user_id = public.current_app_user_id());

drop policy if exists "users can view their org memberships" on public.organization_memberships;
drop policy if exists users_view_own_memberships on public.organization_memberships;
create policy organization_memberships_read_own on public.organization_memberships
  for select to authenticated
  using (user_id = public.current_app_user_id());

-- 3. Org-scoped tables -------------------------------------------------------------------

drop policy if exists "users can view orgs they belong to" on public.organizations;
drop policy if exists users_view_member_orgs on public.organizations;
create policy organizations_read_member on public.organizations
  for select to authenticated
  using (id in (select public.current_user_org_ids()));
-- users_view_ancestor_orgs stays as 20260731010000 created it; its function changed above.

drop policy if exists "users can view subscriptions for their orgs" on public.subscriptions;
drop policy if exists users_view_org_subscriptions on public.subscriptions;
create policy subscriptions_read_member on public.subscriptions
  for select to authenticated
  using (organization_id in (select public.current_user_org_ids()));

drop policy if exists "users can view entitlements for their orgs" on public.entitlements;
drop policy if exists users_view_org_entitlements on public.entitlements;
create policy entitlements_read_member on public.entitlements
  for select to authenticated
  using (organization_id in (select public.current_user_org_ids()));

drop policy if exists "users can view usage for their orgs" on public.usage_events;
drop policy if exists users_view_org_usage_events on public.usage_events;
create policy usage_events_read_member on public.usage_events
  for select to authenticated
  using (organization_id in (select public.current_user_org_ids()));

drop policy if exists "users can view usage buckets for their orgs" on public.usage_buckets_daily;
drop policy if exists users_view_org_usage_buckets on public.usage_buckets_daily;
create policy usage_buckets_daily_read_member on public.usage_buckets_daily
  for select to authenticated
  using (organization_id in (select public.current_user_org_ids()));

drop policy if exists admins_view_org_audit_logs on public.audit_log;
create policy audit_log_read_admin on public.audit_log
  for select to authenticated
  using (organization_id in (select public.current_user_org_ids(array['owner', 'admin'])));

drop policy if exists billing_admins_view_org_billing_events on public.billing_event_log;
create policy billing_event_log_read_billing_admin on public.billing_event_log
  for select to authenticated
  using (organization_id in (select public.current_user_org_ids(array['owner', 'billing_admin'])));

commit;

-- Rollback (restores the auth.uid() form, which is dead for Auth0 tokens):
-- drop every policy created above, recreate the pairs from 20260319000000 and
-- 20260803010000, recreate user_ancestor_org_ids() from 20260731010000, then
-- drop function public.current_user_org_ids(text[]); drop function public.current_app_user_id();
