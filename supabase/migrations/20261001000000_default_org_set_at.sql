-- `users.default_organization_id` carries no history: on 2026-10-01 the first new
-- signup's default could only be inferred to have come from the CR50 trigger
-- (`memberships_default_org`), because nothing recorded when, or in which write,
-- it was set (BACKLOG.md CR50).
--
--   users  BEFORE INSERT / UPDATE OF default_organization_id, default_organization_set_at
--          -> now() when the default changes (on INSERT, when it is non-null);
--             otherwise the stored value, so a direct write is overwritten
--
-- now() is the transaction's start time, so a default the CR50 trigger sets
-- carries exactly the `created_at` of the membership row that set it. Clearing
-- the default is a change too, and is stamped. Existing rows stay null: when
-- their default was set is recorded nowhere, so null means "unchanged since this
-- migration".
--
-- Not SECURITY DEFINER: the function only rewrites NEW, so it needs no privilege
-- beyond the write that fired it. Empty search_path, like the UA04 and CR50 triggers.

alter table public.users
  add column if not exists default_organization_set_at timestamptz;

create or replace function public.users_stamp_default_org()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  if tg_op = 'INSERT' then
    new.default_organization_set_at :=
      case when new.default_organization_id is null then null else now() end;
  elsif new.default_organization_id is distinct from old.default_organization_id then
    new.default_organization_set_at := now();
  else
    new.default_organization_set_at := old.default_organization_set_at;
  end if;
  return new;
end;
$$;

drop trigger if exists users_stamp_default_org on public.users;
create trigger users_stamp_default_org
  before insert or update of default_organization_id, default_organization_set_at on public.users
  for each row execute function public.users_stamp_default_org();

comment on column public.users.default_organization_set_at is
  'When default_organization_id last changed (2026-10-01): now() of the changing transaction, so a default set by memberships_default_org equals that membership''s created_at. Maintained by trigger users_stamp_default_org; direct writes are overwritten. Null = no default, or unchanged since the column was added.';
