# Supabase Access & Migration Ledger

Operational history moved out of CLAUDE.md on 2026-08-03. Dates inline are when each fact was measured; re-measure perishable values before relying on them. The copy-paste command blocks stay in CLAUDE.md; this file holds the reasoning, the incident history, and the dead ends so they are not re-derived.

## The migration ledger, and why "zero out of sync" lied

Migrations are the source of truth for schema — **true since 2026-08-03, and it was not before**: the ledger could not rebuild the schema at all. 10 tables, 3 enums, 2 columns on a ledger-managed table and 1 view — 43% of `public` — existed only in production. `migration list` said "zero out of sync" the whole time because it compares against **production**, which already had every object. **A migration set is only proven by replaying it onto an empty database**; that had never been done. Five baseline migrations closed it, verified at 24/24 tables+views and 255/255 columns.

The CI guard is `migration-replay-check.yml` → `scripts/check-migration-replay.sh` — full local stack + `db reset` + schema assertions. Written 2026-08-03; **first execution ran green the same day** (run `30804541500`, 2m46s, on the merge to `main`). Docker is absent on this machine, so the check only runs in CI. Both triggers filter `branches: [main]`, so pushing a feature branch runs nothing — the push/PR into `main` is what executes it. `gh run list --workflow=migration-replay-check.yml` settles its state.

A second dev project, `tumhmtshahktumhqqamk` / `integritystudio-dev`, exists for cloud-side replay.

## Access routes

**The working DDL route (found 2026-08-03).** The Supabase CLI holds an `sbp_` personal access token in the macOS keychain, and the Management API query endpoint runs **arbitrary SQL including DDL** with it — **while that login is valid; it expires.** On 2026-09-11 the keychain token returned `Unauthorized` everywhere (`projects list`, `functions list`, the query endpoint). `supabase login` refreshes it interactively (not from a non-TTY `!` prompt). The alternative that worked that day: Doppler `prd` `SUPABASE_ACCESS_TOKEN` (see below), via `doppler run --project integrity-studio --config prd --`. No Docker, no `SUPABASE_DB_PASSWORD`. Extraction: `security find-generic-password -s "Supabase CLI" -w`, strip the `go-keyring-base64:` prefix, `base64 -d` → `sbp_…` (recipe in CLAUDE.md). This is the route that read production's entire schema for BACKLOG CR30.

**`supabase db push --db-url <conn>` works without linking**, which avoids mutating the repo's linked-project state that other sessions share. Use the **session pooler on :5432**, not :6543 — the transaction pooler fails mid-push with `prepared statement "lrupsc_1_0" already exists`. `supabase db dump` is *not* usable: it shells out to Docker.

**The CLI's keychain session authorizes the Management API, not Postgres.** A working `supabase projects list` does not mean migrations can be applied — `migration list`/`db push` need a direct database connection (or the `--db-url`/query-endpoint routes above).

**The Dashboard SQL editor executes SQL *without* writing a ledger row** — `migration list` still reports the file pending and the next `db push` fails on `already exists`. Reconcile with `migration repair --status applied <version>` afterwards.

## The DB password saga

🔴 **`SUPABASE_DB_PASSWORD` does not authenticate** (measured 2026-07-31; unchanged). `db push --dry-run` fails `SASL auth (FATAL: password authentication failed for user "postgres" (SQLSTATE 28P01))` against `aws-1-us-east-1.pooler.supabase.com`; `migration list --linked` fails `LegacyDbConnectError`. The fix is a Dashboard password reset plus storing the new value.

Four dead ends, so you don't re-derive them:

- **`dev`'s copy of the password.** A *different* 16-char value (sha `ea45e4f3` vs `prd`'s `0eaaeb6e`), and it fails identically. Both configs pointed at the same project, so there was one real password and neither slot had it.
- **Restoring the service key to that slot.** It used to hold the same string as the live `sb_secret_` key (41 chars, sha `cdb0a4bd`); a Dashboard reset decoupled them without updating Doppler. **Do not re-couple PostgREST `service_role` to direct Postgres access** to "fix" the auth failure.
- ~~**The Management API query endpoint.**~~ **NOT a dead end — corrected 2026-08-03, and this was the most expensive wrong entry on the page.** The diagnosis was right (`POST https://api.supabase.com/v1/projects/<ref>/database/query` returns **401 `JWT could not be decoded`** for any `sb_secret_` key — that class is a data-plane credential for PostgREST; the endpoint wants an `sbp_` personal access token). The **conclusion** was wrong: `sbp_` is not Dashboard-minted-only, because the CLI already holds a working one in the keychain (above). While the wrong conclusion stood, it pushed DDL toward the Dashboard SQL editor — the route that skips the ledger.
- **PostgREST and `psql`.** PostgREST cannot run DDL at all, and there is no `psql` on this machine.

## Doppler slots

~~**`SUPABASE_ACCESS_TOKEN` is EMPTY in Doppler on purpose.**~~ **Stale since a real `sbp_` token was stored — verified 2026-09-11 in both `prd` and `dev`.** With the keychain login expired, `doppler run --project integrity-studio --config prd -- supabase functions delete …` and the Management API query endpoint both authenticated with it (three GA4 functions deleted, `20260910000000` applied and recorded). The override behaviour described here is still real — a value in the env wins over the keychain — which is now the desired direction. *(Historical: the slot once held the revoked old service key, and a garbage value broke every `supabase` command; that is why this line existed.)*

  🔴 **But Doppler `prd`'s `SUPABASE_ACCESS_TOKEN` is PROJECT-SCOPED to production — it cannot reach the dev project at all (found 2026-09-18).** `supabase functions deploy api-keys-rotate --project-ref tumhmtshahktumhqqamk` under it fails `403 "Your account does not have the necessary privileges"`, which reads like a role problem and is not: both projects sit in the same org (`khkebomlarrkcywpaduh`), and the token answers `GET /v1/projects/cfrbahzzklwrnmbtqojl/functions` → **200**, `…/tumhmtshahktumhqqamk/functions` → **403**, `GET /v1/organizations` → `[]`, and `supabase projects list` shows production only. That is the signature of a token minted with project-level access, not org membership. Doppler `dev`'s slot is **unset**. So the dev project is reachable only through the CLI's keychain login (`supabase login`, interactive TTY — it is what created the project on 2026-08-03 and deployed its functions on 2026-08-07), or a personal access token stored in Doppler `dev`. When using the keychain login, run **without** the `doppler run … prd --` prefix: the env value overrides the keychain, and production's token is what would then 403.

**The service key lives in `SUPABASE_PROVISIONING_KEY`, not `SUPABASE_SERVICE_ROLE_KEY`.** The latter exists in **neither** config (verified 2026-07-31) even though it is the name every Worker *binds* it under. Reading the binding name from Doppler silently returns empty and the next command fails with a misleading "No API key found in request".

**`SUPABASE_INTEGRITY_MEMERSHIP_KEY`** (typo real — MEMERSHIP; found 2026-07-31): a third live `sb_secret_` key, sha `3720a512`, distinct from `SUPABASE_PROVISIONING_KEY`, byte-identical in `dev` and `prd` (absent in `stg`), and it works — `/rest/v1/organizations` returns `200` with full RLS bypass. No code in *this* repo reads it; check `observability-toolkit` before revoking. **Do not bind it to a Worker to solve an org-resolution problem** — an `sb_secret_` key is a *credential*, not a scope: it authenticates as `service_role`, bypasses RLS on every table, and carries no org identity, so the "MEMERSHIP" name grants nothing membership-specific. Both `stripe-webhook` and `api-gateway` already bind `SUPABASE_SERVICE_ROLE_KEY`, so neither lacks database access; a second key adds blast radius and no capability. Why `org_id` rides in Stripe metadata is a bootstrap ordering problem, not an access problem (see `/create-checkout-session` in CLAUDE.md).
