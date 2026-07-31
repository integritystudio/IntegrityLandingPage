-- Organization hierarchy: link child orgs (team/personal) to an umbrella parent.
--
-- Motivation: `organizations.type` already carries a `parent-organization` enum
-- label, but no linkage column ever existed, so the value was unreachable. This
-- adds the missing edge and uses it to place `team-integritystudio.ai` under
-- `Integrity Studio AI`.
--
-- NOT YET APPLIED to prd. Per the convention in
-- 20260717000000_provisioned_dashboard_viewer_default_role.sql, prd is normally
-- the source of truth and migrations mirror it; this file inverts that and is
-- meant to DRIVE the change. Apply it, then confirm the verification block.

begin;

-- 1. Linkage column. `on delete set null` so removing a parent orphans children
--    rather than cascading a delete through the hierarchy.
alter table public.organizations
  add column if not exists parent_organization_id uuid
  references public.organizations(id) on delete set null;

create index if not exists idx_organizations_parent_organization_id
  on public.organizations(parent_organization_id);

-- 2. Reject self-parenting. This does NOT prevent longer cycles (a -> b -> a);
--    a depth guard would need a trigger, deferred until nesting is actually used.
alter table public.organizations
  drop constraint if exists chk_organizations_no_self_parent;
alter table public.organizations
  add constraint chk_organizations_no_self_parent
  check (parent_organization_id is null or parent_organization_id <> id);

-- 3. Promote the umbrella org. Safe against existing reads: `lookupTeamOrgByDomain`
--    filters `type=eq.team` and the e2e org sweep filters `type='personal'`, so
--    neither matches this row today (it is `type='organization'`), and neither
--    will match it afterwards.
update public.organizations
  set type = 'parent-organization', updated_at = now()
  where id = '29edb193-ae7f-4863-9bb6-e245da74ec1f'
    and type = 'organization';

-- 4. Attach the team org to it.
update public.organizations
  set parent_organization_id = '29edb193-ae7f-4863-9bb6-e245da74ec1f', updated_at = now()
  where id = '38567a26-c19c-4b34-9c42-d377761bb50c';

-- 5. Ancestor walk for RLS.
--
--    Why a function and not an inline policy: a policy ON public.organizations
--    that joins TO public.organizations re-enters its own policy and Postgres
--    aborts with "infinite recursion detected in policy for relation
--    organizations". A `security definer` function runs as the owner, for whom
--    RLS is not enforced, which breaks the cycle.
--
--    `union` (not `union all`) dedupes, so a parent cycle (a -> b -> a) is
--    absorbed rather than looping forever — no CYCLE clause needed.
--
--    `set search_path` is mandatory hardening for security definer: without it
--    a caller-controlled search_path can shadow `public.` objects.
create or replace function public.user_ancestor_org_ids()
returns setof uuid
language sql
stable
security definer
set search_path = public
as $$
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

revoke execute on function public.user_ancestor_org_ids() from public;
grant execute on function public.user_ancestor_org_ids() to authenticated;

-- 6. Additive SELECT policy. Permissive policies OR together, so this widens
--    visibility on top of users_view_member_orgs without modifying it: a member
--    of a child org may read its ancestors, but not siblings or descendants.
--
--    DORMANT ON APPLY. Every organizations policy resolves identity through
--    public.auth_user_links, which has 0 rows in prd, and all application access
--    uses the service role key (RLS bypassed). This policy is correct but has no
--    effect until auth_user_links is backfilled from Auth0 subs.
drop policy if exists "users_view_ancestor_orgs" on public.organizations;
create policy "users_view_ancestor_orgs"
  on public.organizations for select
  to authenticated
  using (id in (select public.user_ancestor_org_ids()));

commit;

-- Verification — expect exactly one row:
--   child = team-integritystudio.ai, parent = integrity-studio-ai,
--   parent_type = parent-organization
--
-- select c.slug as child, c.type as child_type,
--        p.slug as parent, p.type as parent_type
-- from public.organizations c
-- join public.organizations p on p.id = c.parent_organization_id;

-- Policy check — as an authenticated user who is an active member of a child
-- org, this should return the parent once auth_user_links is populated:
--
-- select public.user_ancestor_org_ids();
--
-- Rollback:
-- begin;
-- drop policy if exists "users_view_ancestor_orgs" on public.organizations;
-- drop function if exists public.user_ancestor_org_ids();
-- update public.organizations set parent_organization_id = null
--   where id = '38567a26-c19c-4b34-9c42-d377761bb50c';
-- update public.organizations set type = 'organization'
--   where id = '29edb193-ae7f-4863-9bb6-e245da74ec1f';
-- alter table public.organizations
--   drop constraint if exists chk_organizations_no_self_parent;
-- drop index if exists public.idx_organizations_parent_organization_id;
-- alter table public.organizations drop column if exists parent_organization_id;
-- commit;
