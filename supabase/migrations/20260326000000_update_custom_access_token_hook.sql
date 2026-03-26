-- M18-V01: Remove mutable billing claims from Custom Access Token Hook
-- Removes default_org_plan and default_org_billing_status from JWT.
-- Both are mutable state queried server-side at runtime; embedding them in
-- the token creates stale-read access control vulnerabilities (up to 3600s
-- drift) violating SOC 2 CC6.1.
--
-- JWT now contains only stable identity references:
--   org_ids, default_org_id, default_org_role
--
-- App code already handles tokens with or without the old claims via
-- JWTPayloadSchema .passthrough() (commit 312070b).

create or replace function public.custom_access_token_hook(event jsonb)
returns jsonb
language plpgsql stable
security definer
set search_path = public
as $$
declare
  claims           jsonb;
  v_auth_user_id   uuid;
  v_app_user_id    uuid;
  v_org_ids        uuid[];
  v_default_org_id uuid;
  v_default_role   text;
begin
  v_auth_user_id := (event->>'user_id')::uuid;
  claims := event->'claims';

  -- Resolve app user via auth_user_links bridge
  select app_user_id into v_app_user_id
  from public.auth_user_links
  where auth_user_id = v_auth_user_id;

  -- No bridge row yet (new signup before provisioning) — return unmodified
  if v_app_user_id is null then
    return event;
  end if;

  -- Collect all active org memberships
  select array_agg(organization_id order by created_at)
  into v_org_ids
  from public.organization_memberships
  where user_id = v_app_user_id
    and status = 'active';

  -- Prefer user's designated default org; fall back to first membership
  select default_organization_id into v_default_org_id
  from public.users
  where id = v_app_user_id;

  if v_default_org_id is null
     and v_org_ids is not null
     and array_length(v_org_ids, 1) > 0
  then
    v_default_org_id := v_org_ids[1];
  end if;

  -- Role in the default org (stable; changes require a new session)
  if v_default_org_id is not null then
    select role into v_default_role
    from public.organization_memberships
    where user_id = v_app_user_id
      and organization_id = v_default_org_id
      and status = 'active';
  end if;

  -- Embed stable identity claims only — no plan, no billing_status
  claims := jsonb_set(
    claims,
    '{org_ids}',
    to_jsonb(coalesce(v_org_ids, '{}'::uuid[]))
  );

  if v_default_org_id is not null then
    claims := jsonb_set(claims, '{default_org_id}', to_jsonb(v_default_org_id));
  end if;

  if v_default_role is not null then
    claims := jsonb_set(claims, '{default_org_role}', to_jsonb(v_default_role));
  end if;

  return jsonb_set(event, '{claims}', claims);
end;
$$;

-- Allow Supabase Auth to call this function
grant execute on function public.custom_access_token_hook(jsonb)
  to supabase_auth_admin;

-- Prevent direct execution by authenticated users
revoke execute on function public.custom_access_token_hook(jsonb)
  from authenticated, anon, public;
