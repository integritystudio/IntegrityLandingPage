-- CR30 part 3: RLS policies lifted out of 20260320000000_phase1_consolidated.sql.
--
-- All five read `public.auth_user_links`, which 20260320005000 creates AFTER
-- that migration: the ledger depended on its own future. Invisible until
-- 2026-08-03 because production already had every object and the ledger had
-- never been replayed onto an empty database.
--
-- Sorted last, not merely after 20260320005000, because these policies also
-- reference `entitlements` and `subscriptions`.
--
-- Guarded rather than drop-and-recreate, so this is a true no-op against
-- production, which already holds all five. (`create policy if not exists` is
-- not valid PostgreSQL -- hence the DO blocks.)

do $$ begin
  if not exists (select 1 from pg_policies where schemaname = 'public'
                 and tablename = 'organization_memberships' and policyname = 'users_view_own_memberships') then
    execute $stmt$create policy "users_view_own_memberships"
  on public.organization_memberships for select
  using (
    user_id in (
      select app_user_id from public.auth_user_links
      where auth_user_id = auth.uid()
    )
  )$stmt$;
  end if;
end $$;

do $$ begin
  if not exists (select 1 from pg_policies where schemaname = 'public'
                 and tablename = 'organizations' and policyname = 'users_view_member_orgs') then
    execute $stmt$create policy "users_view_member_orgs"
  on public.organizations for select
  using (
    exists (
      select 1
      from public.organization_memberships m
      join public.auth_user_links ual on m.user_id = ual.app_user_id
      where m.organization_id = public.organizations.id
        and ual.auth_user_id = auth.uid()
        and m.status = 'active'
    )
  )$stmt$;
  end if;
end $$;

do $$ begin
  if not exists (select 1 from pg_policies where schemaname = 'public'
                 and tablename = 'entitlements' and policyname = 'users_view_org_entitlements') then
    execute $stmt$create policy "users_view_org_entitlements"
  on public.entitlements for select
  using (
    exists (
      select 1
      from public.organization_memberships m
      join public.auth_user_links ual on m.user_id = ual.app_user_id
      where m.organization_id = public.entitlements.organization_id
        and ual.auth_user_id = auth.uid()
        and m.status = 'active'
    )
  )$stmt$;
  end if;
end $$;

do $$ begin
  if not exists (select 1 from pg_policies where schemaname = 'public'
                 and tablename = 'subscriptions' and policyname = 'users_view_org_subscriptions') then
    execute $stmt$create policy "users_view_org_subscriptions"
  on public.subscriptions for select
  using (
    exists (
      select 1
      from public.organization_memberships m
      join public.auth_user_links ual on m.user_id = ual.app_user_id
      where m.organization_id = public.subscriptions.organization_id
        and ual.auth_user_id = auth.uid()
        and m.status = 'active'
    )
  )$stmt$;
  end if;
end $$;

alter table public.auth_user_links enable row level security;

do $$ begin
  if not exists (select 1 from pg_policies where schemaname = 'public'
                 and tablename = 'auth_user_links' and policyname = 'users_view_own_auth_link') then
    execute $stmt$create policy "users_view_own_auth_link"
  on public.auth_user_links for select
  using (auth.uid() = auth_user_id)$stmt$;
  end if;
end $$;
