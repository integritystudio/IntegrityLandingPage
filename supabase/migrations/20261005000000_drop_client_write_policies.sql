-- `users` and `api_keys` are written only by service-role callers: sender-worker's
-- /signup, api-gateway and the api-keys-* Edge Functions. Three baseline policies also
-- let a signed-in caller write them straight through PostgREST, and nothing uses that:
--
--   users     "Users can insert their own data"   with check (auth.uid() = id)
--   api_keys  users_insert_own_keys               with check (user_id is a users row
--   api_keys  users_update_own_keys               using       whose auth0_id = the JWT sub)
--
-- Supabase Auth sign-up is a separate door from Auth0, and a signed-in Supabase Auth
-- account passes all three. The first lets it create its own `users` row with an
-- `auth0_id` and `email` of its choosing. `email` is unique and /signup does a plain
-- insert, so a planted row blocks that address from ever signing up. An `auth0_id` equal
-- to the account's own uuid then matches the two `api_keys` policies, which take any
-- `organization_id` the caller can name and let every column of their own rows be
-- rewritten. Keys authenticate from the AUTH KV namespace, so such a row never becomes a
-- working key, but it sits in the table revocation and org attribution are read from.
--
-- The read policies stay, and service_role bypasses RLS, so no worker or Edge Function
-- changes behaviour. "Users can update own data" on `users` stays too: it reaches only a
-- row whose `auth0_id` is the caller's own Supabase Auth uuid, and with the insert policy
-- gone no client can create one. Rows planted before this ran are still theirs to edit:
--   select id, email from public.users where auth0_id ~* '^[0-9a-f]{8}-[0-9a-f]{4}-';
drop policy if exists "Users can insert their own data" on public.users;
drop policy if exists "users_insert_own_keys" on public.api_keys;
drop policy if exists "users_update_own_keys" on public.api_keys;
