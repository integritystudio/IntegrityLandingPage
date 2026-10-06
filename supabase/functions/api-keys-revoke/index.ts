/**
 * api-keys-revoke — mark an active API key as revoked in `api_keys` and delete
 * its AUTH KV record so telemetry workers stop accepting it immediately.
 *
 * Server-to-server only: every request must present a service-level key (same
 * capability check as api-keys-create and api-keys-rotate). The caller names
 * the key to revoke in the body: { "keyId": "<uuid>" }. The caller is
 * responsible for verifying org membership before calling here.
 *
 * Previously (before CR64) this function required a user JWT (`verify_jwt =
 * true`), was never called by any production code, and left the AUTH KV record
 * intact — so a key "revoked" through the api-gateway route kept authenticating
 * to obtool-ingest and obtool-api. The gateway's revoke route now calls this
 * function server-to-server (with the service key) after the DB update.
 */
import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { createClient } from "jsr:@supabase/supabase-js@2";
import { createApiKeysRevokeHandler } from "./handler.ts";

Deno.serve(createApiKeysRevokeHandler({
  env: (name) => Deno.env.get(name),
  fetch: (input, init) => fetch(input, init),
  createClient,
}));
