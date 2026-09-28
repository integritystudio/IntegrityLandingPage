-- UA04: `users.tier` predates organizations and billing never wrote it, so it
-- drifted from the plan actually paid for — the owner of `team-inventoryai-io`
-- read `starter` from 2026-07-31 (growth checkout) until it was hand-set on
-- 2026-09-18. `api-keys-create` and `/v1/me` both fall back to it whenever the
-- org lookup misses, so a stale value becomes the answer.
--
-- The column is now derived: for any user with a default organization, `tier`
-- is that org's `current_plan`, kept in step by two triggers. Users with no
-- default organization keep their stored value (there is no plan to derive from).
--
--   users          BEFORE INSERT / UPDATE OF default_organization_id, tier
--                  -> recompute tier; a direct write to tier is overwritten
--   organizations  AFTER UPDATE OF current_plan
--                  -> push the new tier to every user whose default org it is
--
-- `current_plan` is free text and `tier` is the api_key_tier enum. The mapping
-- matches api-keys-create and the quota DO: 'free' is the phase-1 seed's name
-- for 'starter', and anything unrecognised resolves to 'starter'.
--
-- Both functions are SECURITY DEFINER with an empty search_path: the webhook
-- writes `organizations.current_plan` and must be able to update `users` in the
-- same statement whatever role it runs as.

create or replace function public.plan_to_api_key_tier(plan text)
returns public.api_key_tier
language sql immutable
set search_path = ''
as $$
  select case lower(plan)
    when 'growth'     then 'growth'::public.api_key_tier
    when 'enterprise' then 'enterprise'::public.api_key_tier
    else 'starter'::public.api_key_tier
  end;
$$;

create or replace function public.users_derive_tier()
returns trigger
language plpgsql security definer
set search_path = ''
as $$
declare
  org_plan text;
begin
  if new.default_organization_id is null then
    return new;
  end if;

  select o.current_plan into org_plan
    from public.organizations o
   where o.id = new.default_organization_id;

  if found then
    new.tier := public.plan_to_api_key_tier(org_plan);
  end if;
  return new;
end;
$$;

create or replace function public.organizations_propagate_tier()
returns trigger
language plpgsql security definer
set search_path = ''
as $$
begin
  update public.users u
     set tier = public.plan_to_api_key_tier(new.current_plan)
   where u.default_organization_id = new.id
     and u.tier is distinct from public.plan_to_api_key_tier(new.current_plan);
  return null;
end;
$$;

drop trigger if exists users_derive_tier on public.users;
create trigger users_derive_tier
  before insert or update of default_organization_id, tier on public.users
  for each row execute function public.users_derive_tier();

drop trigger if exists organizations_propagate_tier on public.organizations;
create trigger organizations_propagate_tier
  after update of current_plan on public.organizations
  for each row
  when (old.current_plan is distinct from new.current_plan)
  execute function public.organizations_propagate_tier();

-- Backfill existing rows.
update public.users u
   set tier = public.plan_to_api_key_tier(o.current_plan)
  from public.organizations o
 where o.id = u.default_organization_id
   and u.tier is distinct from public.plan_to_api_key_tier(o.current_plan);

comment on column public.users.tier is
  'Derived (UA04, 2026-09-27): equals plan_to_api_key_tier(current_plan) of the default organization, maintained by triggers users_derive_tier and organizations_propagate_tier. Writes are overwritten. Only users with no default organization hold a stored value.';
