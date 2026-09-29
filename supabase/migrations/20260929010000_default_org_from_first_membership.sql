-- CR50: new users get no `users.default_organization_id`. The paths that once set
-- it no longer run, and neither sender `/signup` nor the toolkit receiver writes
-- it, so `users_derive_tier` (UA04) has no org to derive from and the user's
-- `tier` never follows their org's plan. One production row on 2026-09-29.
--
-- Every reader already resolves a null default the same way:
-- `custom_access_token_hook`, `/v1/me` and sender checkout all take the user's
-- oldest active membership, of any role. This trigger stores that answer when it
-- first exists, so readers resolve the org they did before and the tier trigger
-- now fires.
--
--   organization_memberships  AFTER INSERT / UPDATE OF status, when active
--                             -> a user with no default takes this org
--
-- It only fills a null: a chosen default is never overwritten, and a user who
-- later joins a second org keeps the first. SECURITY DEFINER with an empty
-- search_path, like the UA04 triggers, so the membership writer needs no grant
-- on `users`.

create or replace function public.memberships_default_org()
returns trigger
language plpgsql security definer
set search_path = ''
as $$
begin
  update public.users u
     set default_organization_id = new.organization_id
   where u.id = new.user_id
     and u.default_organization_id is null;
  return null;
end;
$$;

drop trigger if exists memberships_default_org on public.organization_memberships;
create trigger memberships_default_org
  after insert or update of status on public.organization_memberships
  for each row
  when (new.status = 'active')
  execute function public.memberships_default_org();

-- Backfill: each user with no default takes their oldest active membership, the
-- org every reader already resolves for them.
update public.users u
   set default_organization_id = m.organization_id
  from (
    select distinct on (user_id) user_id, organization_id
      from public.organization_memberships
     where status = 'active'
     order by user_id, created_at, id
  ) m
 where m.user_id = u.id
   and u.default_organization_id is null;
