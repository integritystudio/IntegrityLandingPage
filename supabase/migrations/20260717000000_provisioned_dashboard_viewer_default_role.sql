-- PROV-RBAC: consolidate provisioned/default dashboard access onto a single role.
--
-- Context: newly provisioned API-key users previously received the `read` role
-- (permissions ["dashboard.read"]) via the on_user_created trigger. That grants
-- only dashboard.read with no view-specific permissions, so those users had no
-- usable dashboard views. This migration replaces `read` with a new
-- `provisioned-dashboard-viewer` role that grants read access to every dashboard
-- view (non-admin), migrates existing holders, drops `read`, and repoints the
-- default-role trigger at the new role.
--
-- Mirrors the application-side grant in the api-provisioning-receiver worker
-- (grantDashboardAccess), which assigns the same role at API-key provisioning
-- time via insert-or-ignore. The two paths are intentionally redundant and
-- converge on the same (user_id, role_id) row.
--
-- Idempotent: safe to run on an environment that still has `read`, or one that
-- has already been migrated.

-- 1. Create the viewer role (all dashboard views, no dashboard.admin).
insert into public.roles (name, description, permissions)
select
  'provisioned-dashboard-viewer',
  'Default role for provisioned users: read access to all dashboard views (non-admin)',
  '["dashboard.read","dashboard.executive","dashboard.operator","dashboard.auditor","dashboard.traces.read","dashboard.sessions.read","dashboard.agents.read","dashboard.pipeline.read","dashboard.compliance.read"]'::jsonb
where not exists (select 1 from public.roles where name = 'provisioned-dashboard-viewer');

-- 2. Reassign existing `read` holders to the viewer role, in place, unless the
--    user already holds the viewer role (avoids the (user_id, role_id) unique conflict).
update public.user_roles ur
set role_id = (select id from public.roles where name = 'provisioned-dashboard-viewer' limit 1)
where ur.role_id = (select id from public.roles where name = 'read' limit 1)
  and not exists (
    select 1 from public.user_roles dup
    where dup.user_id = ur.user_id
      and dup.role_id = (select id from public.roles where name = 'provisioned-dashboard-viewer' limit 1)
  );

-- 3. Remove any residual `read` assignments (users who already had the viewer
--    role in step 2) and drop the now-unused `read` role.
delete from public.user_roles where role_id = (select id from public.roles where name = 'read' limit 1);
delete from public.roles where name = 'read';

-- 4. Repoint the default-role trigger function at the viewer role. The null-guard
--    means a missing role is a safe no-op (never a failed insert / broken signup).
create or replace function public.assign_default_role()
returns trigger
language plpgsql
security definer
as $function$
declare default_role_id uuid;
begin
  select id into default_role_id from public.roles where name = 'provisioned-dashboard-viewer' limit 1;
  if default_role_id is not null then
    insert into public.user_roles (user_id, role_id) values (NEW.id, default_role_id);
  end if;
  return NEW;
end;
$function$;
