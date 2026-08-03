-- CR30, part 2: everything that could not live in the baseline because it
-- depends on objects the LEDGER creates. Sorts after every existing
-- migration for that reason. See 20260319000000 for the full rationale.
--
--   * FKs into `organizations` (created by 20260320000000)
--   * triggers calling update_timestamp (20260320010002) and
--     assign_default_role (20260717000000)
--   * policy api_keys.users_view_own_api_keys, which reads auth_user_links
--     (20260320005000)

do $$ begin
  if not exists (select 1 from pg_constraint where conname = 'users_default_organization_id_fkey'
                 and conrelid = 'public.users'::regclass) then
    alter table public.users add constraint users_default_organization_id_fkey FOREIGN KEY (default_organization_id) REFERENCES organizations(id);
  end if;
end $$;
do $$ begin
  if not exists (select 1 from pg_constraint where conname = 'api_keys_organization_id_fkey'
                 and conrelid = 'public.api_keys'::regclass) then
    alter table public.api_keys add constraint api_keys_organization_id_fkey FOREIGN KEY (organization_id) REFERENCES organizations(id) ON DELETE CASCADE;
  end if;
end $$;

drop policy if exists "users_view_own_api_keys" on public.api_keys;
create policy "users_view_own_api_keys" on public.api_keys
  as permissive
  for select
  to public
  using ((user_id IN ( SELECT auth_user_links.app_user_id
   FROM auth_user_links
  WHERE (auth_user_links.auth_user_id = auth.uid()))));

drop trigger if exists "update_roles_updated_at" on public.roles;
CREATE TRIGGER update_roles_updated_at BEFORE UPDATE ON public.roles FOR EACH ROW EXECUTE FUNCTION update_timestamp();
drop trigger if exists "on_user_created" on public.users;
CREATE TRIGGER on_user_created AFTER INSERT ON public.users FOR EACH ROW EXECUTE FUNCTION assign_default_role();
drop trigger if exists "update_users_updated_at" on public.users;
CREATE TRIGGER update_users_updated_at BEFORE UPDATE ON public.users FOR EACH ROW EXECUTE FUNCTION update_timestamp();
drop trigger if exists "update_user_profiles_updated_at" on public.user_profiles;
CREATE TRIGGER update_user_profiles_updated_at BEFORE UPDATE ON public.user_profiles FOR EACH ROW EXECUTE FUNCTION update_timestamp();
drop trigger if exists "update_user_sessions_updated_at" on public.user_sessions;
CREATE TRIGGER update_user_sessions_updated_at BEFORE UPDATE ON public.user_sessions FOR EACH ROW EXECUTE FUNCTION update_timestamp();
drop trigger if exists "update_analytics_projects_updated_at" on public.analytics_projects;
CREATE TRIGGER update_analytics_projects_updated_at BEFORE UPDATE ON public.analytics_projects FOR EACH ROW EXECUTE FUNCTION update_timestamp();
drop trigger if exists "update_provider_oauth_tokens_updated_at" on public.provider_oauth_tokens;
CREATE TRIGGER update_provider_oauth_tokens_updated_at BEFORE UPDATE ON public.provider_oauth_tokens FOR EACH ROW EXECUTE FUNCTION update_timestamp();
drop trigger if exists "update_api_keys_updated_at" on public.api_keys;
CREATE TRIGGER update_api_keys_updated_at BEFORE UPDATE ON public.api_keys FOR EACH ROW EXECUTE FUNCTION update_timestamp();

