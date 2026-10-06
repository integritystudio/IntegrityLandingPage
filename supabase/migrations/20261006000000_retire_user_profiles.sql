-- `user_profiles` is retired, and the last client write policy on `users` goes with it.
--
-- The table was the legacy app's profile store. On 2026-10-06 it held 193 rows written
-- 2025-10-28 → 2026-07-30, `user_id` null on every one, each carrying an email, and nothing
-- in this repo, the toolkit or the dashboard reads or writes it. Its one writer was
-- `handle_new_user`, a trigger on `auth.users` that no migration created: every Supabase
-- Auth sign-up inserted a row keyed by the auth uuid, which is how a table nothing uses
-- kept filling with addresses. Its one dependent is the `user_details` view (20260803020000),
-- which nothing reads either and cannot survive the join's table going; it is
-- `security_invoker`, so it exposed nothing beyond the caller's own RLS view and goes only
-- because it is dead.
--
-- The table's two write policies let a signed-in Supabase Auth account insert a profile
-- row with any free `user_id` (measured in supabase/tests/retire-user-profiles), and
-- `users` "Users can update own data" matched only rows whose `auth0_id` is a Supabase
-- Auth uuid — none exist, and since 20261005000000 only service-role writers create rows,
-- always with an Auth0 sub. With these gone, no write policy in `public` is usable by a
-- non-service caller; scripts/check-migration-replay.sh asserts that after every replay.
--
-- Order matters: the trigger before its function, the view before the table it joins.
-- `drop table` takes the table's four policies, its updated_at trigger and its FK with it.
drop trigger if exists on_auth_user_created on auth.users;
drop function if exists public.handle_new_user();
drop view if exists public.user_details;
drop table if exists public.user_profiles;
drop policy if exists "Users can update own data" on public.users;
