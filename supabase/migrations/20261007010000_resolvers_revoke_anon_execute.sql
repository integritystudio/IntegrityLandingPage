-- CR62 follow-up: take anon's EXECUTE off the two resolvers.
--
-- Hosted Supabase grants EXECUTE on every new function in public to anon, authenticated and
-- service_role through default privileges (`alter default privileges for role postgres`), on
-- top of PostgreSQL's own grant to PUBLIC. 20261007000000 revoked from PUBLIC and granted to
-- authenticated and service_role, which left anon's explicit grant in place — measured after
-- the push 2026-10-06: routine_privileges listed anon+authenticated+service_role on both,
-- while the local suite, whose cluster has no such default privileges, asserted
-- authenticated+service_role. Nothing was exposed: anon carries no claims, so
-- current_app_user_id() answers NULL and current_user_org_ids() nothing, and every policy
-- that calls them is `to authenticated`. This makes the grants say what the comment says,
-- and the fixture of supabase/tests/auth0-read-policies now sets the hosted default
-- privileges so the suite reproduces the gap.

revoke execute on function public.current_app_user_id() from anon;
revoke execute on function public.current_user_org_ids(text[]) from anon;
