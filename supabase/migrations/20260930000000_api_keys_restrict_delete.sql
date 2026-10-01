-- Deleting a user or an organization no longer deletes their API keys out from under the
-- AUTH KV namespace (UA13). Both foreign keys were ON DELETE CASCADE, so removing a user
-- (or the auth.users entry that cascades to public.users) silently dropped every
-- `api_keys` row while the key's `apikey:<hash>` KV record stayed behind and kept
-- authenticating, with no row left to revoke it from. The 92 orphans found 2026-09-29, and
-- three more from the test users deleted 2026-09-30, all came this way.
--
-- RESTRICT turns that into an error (23503). To delete a user or an org that holds keys,
-- remove each key's KV record first (api-keys-revoke deletes it), then the `api_keys`
-- rows, then the user or org. A revoked row blocks too: revocation keeps the row.
alter table public.api_keys
  drop constraint api_keys_user_id_fkey,
  add constraint api_keys_user_id_fkey
    foreign key (user_id) references public.users(id) on delete restrict,
  drop constraint api_keys_organization_id_fkey,
  add constraint api_keys_organization_id_fkey
    foreign key (organization_id) references public.organizations(id) on delete restrict;
