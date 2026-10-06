-- Fixture for the auth0-sub-read-policies migration test.
--
-- Starts from the users/api_keys slice as CR61 left it (both earlier fixtures and both
-- migrations), then adds every other table whose read policy names the caller, each with
-- the policies production holds (pg_policies, 2026-10-06), and user_ancestor_org_ids() as
-- 20260731010000 wrote it. The whole read chain is here on purpose: a policy that reads a
-- table with RLS on and no policy silently matches nothing (README trap 3).

\ir ../retire-user-profiles/fixture.sql
\ir ../../migrations/20261006000000_retire_user_profiles.sql

alter table public.organizations
  add column parent_organization_id uuid references public.organizations(id);

create table public.organization_memberships (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id),
  user_id uuid not null references public.users(id),
  role text not null,
  status text not null default 'active',
  created_at timestamptz not null default now()
);

create table public.subscriptions (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id),
  stripe_subscription_id text unique not null,
  status text not null default 'active'
);

create table public.entitlements (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id),
  feature_key text not null
);

create table public.usage_events (
  id bigint primary key,
  organization_id uuid not null references public.organizations(id),
  user_id uuid,
  metric_key text not null
);

create table public.usage_buckets_daily (
  organization_id uuid not null references public.organizations(id),
  bucket_date date not null,
  metric_key text not null,
  primary key (organization_id, bucket_date, metric_key)
);

create table public.user_activity (
  id uuid primary key default gen_random_uuid(),
  user_id uuid references public.users(id),
  activity_type text not null
);

create table public.audit_log (
  id bigint primary key,
  organization_id uuid references public.organizations(id),
  action text not null
);

create table public.billing_event_log (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid references public.organizations(id),
  stripe_event_id text unique not null,
  event_type text not null
);

create table public.plans (
  key text primary key,
  display_name text not null
);

alter table public.organization_memberships enable row level security;
alter table public.subscriptions enable row level security;
alter table public.entitlements enable row level security;
alter table public.usage_events enable row level security;
alter table public.usage_buckets_daily enable row level security;
alter table public.user_activity enable row level security;
alter table public.audit_log enable row level security;
alter table public.billing_event_log enable row level security;
alter table public.plans enable row level security;

-- 20260731010000, verbatim: the ancestor walk resolved the caller with auth.uid().
create function public.user_ancestor_org_ids() returns setof uuid
language sql stable security definer set search_path to 'public' as $$
  with recursive member_orgs as (
    select o.id, o.parent_organization_id
    from public.organization_memberships m
    join public.auth_user_links ual on m.user_id = ual.app_user_id
    join public.organizations o on o.id = m.organization_id
    where ual.auth_user_id = auth.uid()
      and m.status = 'active'
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

-- Production's policies on the tables above, both members of each pair.
create policy "users can view their org memberships" on public.organization_memberships
  as permissive for select to public
  using ((user_id = auth.uid()));
create policy "users_view_own_memberships" on public.organization_memberships
  as permissive for select to public
  using ((user_id IN ( SELECT auth_user_links.app_user_id
   FROM auth_user_links
  WHERE (auth_user_links.auth_user_id = auth.uid()))));

create policy "users can view orgs they belong to" on public.organizations
  as permissive for select to public
  using ((EXISTS ( SELECT 1
   FROM organization_memberships m
  WHERE ((m.organization_id = organizations.id) AND (m.user_id = auth.uid()) AND (m.status = 'active'::text)))));
create policy "users_view_ancestor_orgs" on public.organizations
  as permissive for select to authenticated
  using ((id IN ( SELECT user_ancestor_org_ids() AS user_ancestor_org_ids)));
create policy "users_view_member_orgs" on public.organizations
  as permissive for select to public
  using ((EXISTS ( SELECT 1
   FROM (organization_memberships m
     JOIN auth_user_links ual ON ((m.user_id = ual.app_user_id)))
  WHERE ((m.organization_id = organizations.id) AND (ual.auth_user_id = auth.uid()) AND (m.status = 'active'::text)))));

create policy "users can view subscriptions for their orgs" on public.subscriptions
  as permissive for select to public
  using ((EXISTS ( SELECT 1
   FROM organization_memberships m
  WHERE ((m.organization_id = subscriptions.organization_id) AND (m.user_id = auth.uid()) AND ((m.role = 'owner'::text) OR (m.role = 'billing_admin'::text))))));
create policy "users_view_org_subscriptions" on public.subscriptions
  as permissive for select to public
  using ((EXISTS ( SELECT 1
   FROM (organization_memberships m
     JOIN auth_user_links ual ON ((m.user_id = ual.app_user_id)))
  WHERE ((m.organization_id = subscriptions.organization_id) AND (ual.auth_user_id = auth.uid()) AND (m.status = 'active'::text)))));

create policy "users can view entitlements for their orgs" on public.entitlements
  as permissive for select to public
  using ((EXISTS ( SELECT 1
   FROM organization_memberships m
  WHERE ((m.organization_id = entitlements.organization_id) AND (m.user_id = auth.uid()) AND (m.status = 'active'::text)))));
create policy "users_view_org_entitlements" on public.entitlements
  as permissive for select to public
  using ((EXISTS ( SELECT 1
   FROM (organization_memberships m
     JOIN auth_user_links ual ON ((m.user_id = ual.app_user_id)))
  WHERE ((m.organization_id = entitlements.organization_id) AND (ual.auth_user_id = auth.uid()) AND (m.status = 'active'::text)))));

create policy "users can view usage for their orgs" on public.usage_events
  as permissive for select to public
  using ((EXISTS ( SELECT 1
   FROM organization_memberships m
  WHERE ((m.organization_id = usage_events.organization_id) AND (m.user_id = auth.uid()) AND (m.status = 'active'::text)))));
create policy "users_view_org_usage_events" on public.usage_events
  as permissive for select to public
  using ((EXISTS ( SELECT 1
   FROM (organization_memberships m
     JOIN auth_user_links ual ON ((m.user_id = ual.app_user_id)))
  WHERE ((m.organization_id = usage_events.organization_id) AND (ual.auth_user_id = auth.uid()) AND (m.status = 'active'::text)))));

create policy "users can view usage buckets for their orgs" on public.usage_buckets_daily
  as permissive for select to public
  using ((EXISTS ( SELECT 1
   FROM organization_memberships m
  WHERE ((m.organization_id = usage_buckets_daily.organization_id) AND (m.user_id = auth.uid()) AND (m.status = 'active'::text)))));
create policy "users_view_org_usage_buckets" on public.usage_buckets_daily
  as permissive for select to public
  using ((EXISTS ( SELECT 1
   FROM (organization_memberships m
     JOIN auth_user_links ual ON ((m.user_id = ual.app_user_id)))
  WHERE ((m.organization_id = usage_buckets_daily.organization_id) AND (ual.auth_user_id = auth.uid()) AND (m.status = 'active'::text)))));

create policy "Users can view own activity" on public.user_activity
  as permissive for select to public
  using ((user_id IN ( SELECT users.id
   FROM users
  WHERE ((users.auth0_id)::text = (auth.uid())::text))));
create policy "users can view own activity" on public.user_activity
  as permissive for select to public
  using ((user_id = auth.uid()));

create policy "Users can view own roles" on public.user_roles
  as permissive for select to public
  using ((user_id IN ( SELECT users.id
   FROM users
  WHERE ((users.auth0_id)::text = (auth.uid())::text))));

create policy "admins_view_org_audit_logs" on public.audit_log
  as permissive for select to public
  using ((EXISTS ( SELECT 1
   FROM (organization_memberships m
     JOIN auth_user_links ual ON ((m.user_id = ual.app_user_id)))
  WHERE ((m.organization_id = audit_log.organization_id) AND (ual.auth_user_id = auth.uid()) AND (m.status = 'active'::text) AND (m.role = ANY (ARRAY['owner'::text, 'admin'::text]))))));

create policy "billing_admins_view_org_billing_events" on public.billing_event_log
  as permissive for select to public
  using ((EXISTS ( SELECT 1
   FROM (organization_memberships m
     JOIN auth_user_links ual ON ((m.user_id = ual.app_user_id)))
  WHERE ((m.organization_id = billing_event_log.organization_id) AND (ual.auth_user_id = auth.uid()) AND (m.status = 'active'::text) AND (m.role = ANY (ARRAY['owner'::text, 'billing_admin'::text]))))));

create policy "plans_public_read" on public.plans
  as permissive for select to public
  using (true);

-- The base fixture enables RLS on roles without its policy (nothing there read it).
create policy "Anyone can view roles" on public.roles
  as permissive for select to public
  using (true);

-- anon, the third API role: it holds the same table grants as authenticated on the hosted
-- project and must end up with nothing but the public reads.
create role anon;
grant usage on schema public, auth to anon;
grant all on all tables in schema public to authenticated, service_role, anon;

-- Seed. The base fixture holds planted ...01 (auth0_id = its own uuid), customer ...02
-- (auth0|customer), linked ...03 (auth0|linked, bridged to Supabase Auth ...c3), keys
-- f1-f3 and orgs org-a / org-b. Added here:
--   other     auth0|other, admin of org-b
--   org-parent  parent of org-a, reachable only through the ancestor walk
--   customer  owner of org-a, suspended member of org-b (must grant nothing on org-b)
--   linked    plain member of org-b
insert into public.users (id, auth0_id, email) values
  ('00000000-0000-0000-0000-000000000004', 'auth0|other', 'other@test');

insert into public.organizations (id, slug) values
  ('00000000-0000-0000-0000-0000000000aa', 'org-parent');
update public.organizations
   set parent_organization_id = '00000000-0000-0000-0000-0000000000aa'
 where slug = 'org-a';

insert into public.organization_memberships (organization_id, user_id, role, status) values
  ('00000000-0000-0000-0000-00000000000a', '00000000-0000-0000-0000-000000000002', 'owner',  'active'),
  ('00000000-0000-0000-0000-00000000000b', '00000000-0000-0000-0000-000000000002', 'member', 'suspended'),
  ('00000000-0000-0000-0000-00000000000b', '00000000-0000-0000-0000-000000000003', 'member', 'active'),
  ('00000000-0000-0000-0000-00000000000b', '00000000-0000-0000-0000-000000000004', 'admin',  'active');

insert into public.api_keys (id, user_id, organization_id, hash) values
  ('00000000-0000-0000-0000-0000000000f4', '00000000-0000-0000-0000-000000000004', '00000000-0000-0000-0000-00000000000b', 'hash-other');

insert into public.subscriptions (organization_id, stripe_subscription_id) values
  ('00000000-0000-0000-0000-00000000000a', 'sub_a'),
  ('00000000-0000-0000-0000-00000000000b', 'sub_b');

insert into public.entitlements (organization_id, feature_key) values
  ('00000000-0000-0000-0000-00000000000a', 'feat-a'),
  ('00000000-0000-0000-0000-00000000000b', 'feat-b');

insert into public.usage_events (id, organization_id, metric_key) values
  (1, '00000000-0000-0000-0000-00000000000a', 'ue-a'),
  (2, '00000000-0000-0000-0000-00000000000b', 'ue-b');

insert into public.usage_buckets_daily (organization_id, bucket_date, metric_key) values
  ('00000000-0000-0000-0000-00000000000a', '2026-10-01', 'ub-a'),
  ('00000000-0000-0000-0000-00000000000b', '2026-10-01', 'ub-b');

insert into public.user_activity (user_id, activity_type) values
  ('00000000-0000-0000-0000-000000000002', 'act-customer'),
  ('00000000-0000-0000-0000-000000000004', 'act-other');

insert into public.audit_log (id, organization_id, action) values
  (1, '00000000-0000-0000-0000-00000000000a', 'al-a'),
  (2, '00000000-0000-0000-0000-00000000000b', 'al-b');

insert into public.billing_event_log (organization_id, stripe_event_id, event_type) values
  ('00000000-0000-0000-0000-00000000000a', 'evt_a', 'bl-a'),
  ('00000000-0000-0000-0000-00000000000b', 'evt_b', 'bl-b');

insert into public.plans (key, display_name) values ('starter', 'Starter');

-- Pre-check: the fixture reproduces the defect. Under an Auth0 subject the users read
-- raises 22P02 before the migration; if it does not, the fixture is not production's shape
-- and the suite would prove nothing.
begin;
set local role authenticated;
select set_config('request.jwt.claims', '{"sub":"auth0|customer","role":"authenticated"}', true);
do $$
begin
  perform count(*) from public.users;
  raise exception 'FIXTURE BROKEN: a users read under an Auth0 subject did not raise before the migration';
exception when invalid_text_representation then
  raise notice 'pre-check: a users read under an Auth0 subject raises 22P02 before the migration';
end $$;
do $$
begin
  perform count(*) from public.organizations;
  raise exception 'FIXTURE BROKEN: an organizations read under an Auth0 subject did not raise before the migration';
exception when invalid_text_representation then
  raise notice 'pre-check: an organizations read under an Auth0 subject raises 22P02 before the migration';
end $$;
rollback;
