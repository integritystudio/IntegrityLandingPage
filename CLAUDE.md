[README.md](README.md)

## Commands

**Flutter**
```bash
flutter test --coverage           # Run all tests
flutter build web --release       # Production web build
flutter run -d chrome             # Dev server (localhost)

# Override worker URLs for local/staging:
flutter run -d chrome \
  --dart-define=SENDER_WORKER_URL=http://localhost:8787 \
  --dart-define=CONTACT_API_URL=http://localhost:8786
```

**Workers** (run from the individual worker directory)
```bash
npm test                          # Unit tests (vitest)
npm run deploy                    # → <worker>-dev (wrangler --env dev); cannot touch production
npm run deploy:prd                # → the live worker (top-level config + Doppler prd)
wrangler dev --port 8787          # Local dev server

# Opt-in suites (excluded from `npm test`)
npm run test:live                 # stripe-webhook: real Stripe-signed requests to the deployed dev Worker (5/5)
                                  # sender-worker: real Auth0 Management API calls against the PRODUCTION tenant
                                  #   (--config prd since 2026-07-29; dev creds cannot mint a management token).
                                  #   vitest.live.config.ts overrides AUTH0_TEST_EMAIL to a disposable identity —
                                  #   the suite DELETES the user at that address, and prd's value is the real
                                  #   test@integritystudio.ai account. Do not remove that override.
npm run test:e2e                  # sender-worker: workerd runtime, all outbound calls mocked — needs no credentials
                                  # ✅ 44/44 as of 2026-07-29 (previously collected 0 tests; see CR11)
```

**Supabase** (migrations are the source of truth for schema)
```bash
# ⚠️ SUPABASE_ACCESS_TOKEN is EMPTY in Doppler as of 2026-07-29 — the slot held the
# revoked old service key, and a garbage value OVERRIDES the CLI's keychain login,
# so exporting it breaks `supabase` commands that otherwise work. Leave it unset
# until a real `sbp_` token is minted in the Dashboard (BACKLOG.md CR01 step 3).
#
# The CLI's keychain session IS valid — `supabase projects list` returns the project.
# But that session authorizes the *Management API*, not Postgres, and every command
# below needs a direct database connection. Do not read a working `projects list` as
# "migrations can be applied" — see the DB-password warning under this block.
export SUPABASE_DB_PASSWORD=$(doppler secrets get SUPABASE_DB_PASSWORD --project integrity-studio --config prd --plain)
supabase migration list --linked   # local vs remote; any blank `remote` column is pending
supabase db push --dry-run         # preview; add --include-all if a file sorts before the last applied version
supabase db push                   # apply — ALL pending migrations, not just yours

# Apply ONE migration when others are pending (db push would sweep them in too):
supabase db query --linked -f supabase/migrations/<version>_<name>.sql
supabase migration repair --status applied <version>   # then record just that one
```
🔴 **None of the commands above work as of 2026-07-31 — `SUPABASE_DB_PASSWORD` does not authenticate.** `db push --dry-run` fails `SASL auth (FATAL: password authentication failed for user "postgres" (SQLSTATE 28P01))` against `aws-1-us-east-1.pooler.supabase.com`, and `migration list --linked` fails `LegacyDbConnectError`. **Until a working password is stored, the only route for DDL is the Dashboard SQL editor**, which executes the SQL *without* writing a ledger row — so `migration list` will still report the file pending and the next `db push` will fail on `already exists`. Reconcile with `migration repair --status applied <version>` once the password works. Minting an `sbp_` token would also unlock `POST /v1/projects/<ref>/database/query` as an alternative.
**Two routes that look right and do not work — don't re-derive them.** The Management API REST endpoint (`POST https://api.supabase.com/v1/projects/<ref>/database/query`) returns **401 `JWT could not be decoded`** for any `sb_secret_` key: that class is a data-plane credential for PostgREST, and the endpoint wants an `sbp_` personal access token. PostgREST cannot run DDL at all, and there is no `psql` on this machine.

**`SUPABASE_DB_PASSWORD` — the long-standing tension in this file is resolved, and the answer flipped (2026-07-31).** Two contradictory claims used to sit here: that the slot held the same string as the live `sb_secret_` service key and authenticated to Postgres, and that it failed auth against the pooler. Both are now obsolete. The slot holds a **16-character random password that is *not* an `sb_secret_` key** (sha `0eaaeb6e`; the live service key is 41 chars, sha `cdb0a4bd`), so the credential coupling that note warned about **has been decoupled** — apparently by the Dashboard password reset it recommended. But the value stored here is **wrong or stale: it fails `28P01`**, so the decoupling was done without updating Doppler. Fixing it means resetting the password again in the Dashboard and storing the new value. **Don't reach for `dev`'s copy as a fallback** — `dev` holds a *different* 16-char value (sha `ea45e4f3`) and it fails identically, so both slots are stale; since both configs point at the same Supabase project there is only one real password, and neither slot has it. **Do not restore the service key to this slot to "fix" the auth failure** — that would undo the decoupling and re-couple PostgREST `service_role` to direct Postgres access.

⚠️ **The Doppler slot for the service key is `SUPABASE_PROVISIONING_KEY`, not `SUPABASE_SERVICE_ROLE_KEY`.** The latter exists in **neither** config (verified 2026-07-31) even though it is the name every Worker *binds* it under, and other docs describe it as a Doppler slot. Reading the binding name from Doppler silently returns empty and the next command fails with a misleading "No API key found in request".

🔴 **A third live `sb_secret_` key is sitting in Doppler (found 2026-07-31), in *both* configs.** `SUPABASE_INTEGRITY_MEMERSHIP_KEY` (note the typo — MEMERSHIP) holds an `sb_secret_` key (sha `3720a512`) distinct from `SUPABASE_PROVISIONING_KEY` (sha `cdb0a4bd`), and it **works**: a `/rest/v1/organizations` query returns `200` with full RLS bypass. `dev` and `prd` hold the **byte-identical value** (absent in `stg`), so it is one more CR11 isolation row — and one `check:env-isolation` does not compare. No code in this repo reads that name (grep only covers *this* repo — check `observability-toolkit` before revoking). Same class as the stray `sb_secret_bgU_b` key CR01 revoked.

**Do not bind it to a Worker to solve an org-resolution problem.** An `sb_secret_` key is a *credential*, not a scope — it authenticates as `service_role` and bypasses RLS on every table, carrying no org identity, and the "MEMERSHIP" name grants nothing membership-specific. Both `stripe-webhook` and `api-gateway` already bind `SUPABASE_SERVICE_ROLE_KEY` (verified live 2026-07-31), so neither lacks database access; a second key would add blast radius and one more secret to CR14's preview-URL exposure surface, and no capability. Why `org_id` still has to ride in Stripe metadata is explained under `/create-checkout-session` below — it is a bootstrap ordering problem, not an access problem.

Two hard-won rules. **`create policy if not exists` is invalid PostgreSQL** — there is no `IF NOT EXISTS` for `CREATE POLICY`; use `drop policy if exists` then `create policy`. And **`migration repair --status applied` writes a ledger row without executing the SQL**, which is how two migrations came to be recorded as applied while their tables did not exist (BACKLOG.md CR17). Treat it as a last resort, never as a way past a failing push.

**RLS is not optional for privacy.** PostgREST exposes every table in the `public` schema, so a table with RLS off is readable with the *publishable* anon key regardless of which key your workers use. Enabling RLS with **zero policies** denies anon and authenticated while `service_role` bypasses it — that is the correct posture for server-only tables. Verify with the catalog, not a status code: RLS denial returns `200 []`, not an error.
```bash
# any table here is publicly readable
select relname from pg_class c join pg_namespace n on n.oid=c.relnamespace
where n.nspname='public' and c.relkind='r' and c.relrowsecurity=false;
```

## Current Status

**Phase**: Codebase review remediation + worker deploy/settings audit + database/secret remediation + credential rotation — CR01–CR29 tracked, see the status table in [docs/BACKLOG.md](docs/BACKLOG.md)
**Last Updated**: 2026-07-31
**Build Status**: ✅ Web build successful, running on localhost:8080
**Test Status**: ✅ **3,017 Flutter and 1,179 worker tests passing**, measured 2026-07-31 on the working tree (`lib` 510, contact-form 81, api-gateway 208, sender-worker 188, receiver-worker 29, stripe-webhook 163). The previous figure of 1,063 worker tests was stale by roughly a hundred; if you are reconciling a count, run the suite rather than trusting this line. Coverage ~94%; zero TypeScript errors via `npm run lint:workers` — note that **is** the worker "linter" (`tsc --noEmit` × 7 packages; there is no ESLint under `workers/`, and plain `npm run lint` is `flutter analyze`). All three opt-in suites are green as of 2026-07-29: `sender-worker` `test:e2e` **44/44** (was non-functional — see BACKLOG.md CR11), `sender-worker` `test:live` 9 passed / 3 skipped (now `--config prd`), `stripe-webhook` `test:live` 5/5
**Database**: ✅ Supabase `cfrbahzzklwrnmbtqojl` is `ACTIVE_HEALTHY`; 10 migrations applied and `supabase migration list` reports zero out of sync. The ledger previously claimed migrations that had never run (CR17) — including the one creating `stripe-webhook`'s tables. RLS is now enabled on every table in `public`.
**Deployed**: ✅ **all four production Workers redeployed from current source 2026-07-30** and healthy — see the deploy table below for versions. `api-gateway` returns `200 {"database":"healthy","durableObjects":"healthy"}` with **three** secrets bound as of 2026-07-31 00:02 UTC — `SUPABASE_URL`, `SUPABASE_SERVICE_ROLE_KEY`, `STRIPE_SECRET_KEY` (CR12 partial — `API_KEY_HMAC_SECRET` still missing). **`SUPABASE_JWT_SECRET` was deliberately unbound on 2026-07-30 and its absence is correct, not a regression:** `api-gateway` verifies **Auth0**-issued tokens against **Auth0** JWKS, so nothing read it — it was a credential with no reader. It is also gone from the `Env` interface and the `wrangler.toml` secret list, and the shared `supabaseJwtKey`/`jwksUrlFor` helpers are now `@deprecated`. **Do not re-bind it to "fix" a 401**: verifying an Auth0-issued token against *Supabase* JWKS is exactly what produced the original `401 Invalid JWT signature` — see BACKLOG.md CR26. **`stripe-webhook` is fully wired as of 2026-07-28** — Supabase pair plus `STRIPE_WEBHOOK_SECRET`, and redeployed from current source. Its production code had been stuck at 2026-03-31 and could not write `webhook_events_log`; a signed probe now returns `{"ok":true,"processed":true}` and a replay returns `already_processed`. Five `*-dev` workers are deliberately secret-less (CR11) except `stripe-webhook-dev`, which holds a sandbox `STRIPE_API_KEY` + `STRIPE_WEBHOOK_SECRET` for live signature testing. No zone route points at any dev worker.
**Stripe**: production account is **`acct_1SN2e7AwEfePbhfk`**. Two endpoints, both pinned to `api_version=2025-09-30.clover` and subscribed to the five implemented events: test-mode `we_1Ty14zBWbFuvm1I6rvLOD5OW` → `stripe-webhook-dev`, and **live-mode `we_1Ty29dAwEfePbhfkky1OeqQu` → production `stripe-webhook`** (registered 2026-07-28, signature verification proven with a wrong-secret control). `prd`'s `STRIPE_SECRET_KEY` holds an **`rk_live_` restricted key** (least privilege; the `sk_live_` is retained in Doppler history) — bound to `api-gateway` and `sender-worker` on 2026-07-28 (`sender-worker` verified reading it — checkout now reaches validation instead of `"Stripe not configured"`). `api-gateway`'s billing portal is unblocked as of 2026-07-28 — the live Customer Portal now has a configuration (`bpc_1Ty2XDAwEfePbhfk9PndBNgW`), and a real session was created against it to prove the call works. The route itself is still unexercised because it needs a JWT. Doppler `dev` now holds only sandbox Stripe values — `STRIPE_SECRET_KEY` was a `pk_live_` publishable key on the *production* account until 2026-07-28 and is now the sandbox `sk_test_`. **Stripe is the one credential family where `dev` really is isolated from `prd`**: `acct_1SN2eDBWbFuvm1I6` is confirmed as "Integrity Studio sandbox". That is not true of Supabase or Auth0 — see CR11. See CR18. ⚠️ **Two different live `rk_live_` keys exist on the production account** (found 2026-07-29): `STRIPE_SECRET_KEY` ending `aHZC` and `STRIPE_API_KEY` ending `B6I8`, both returning 200 from `GET /v1/account`. Worker code reads **only** `STRIPE_SECRET_KEY`, so `…B6I8` is an unused live credential — revoke it in the Dashboard (Stripe exposes no key-management API), then clear the slot, not before, since the last-4 is how the Dashboard identifies it.
✅ **The deploy backlog is cleared as of 2026-07-30.** All four production Workers this repo owns were deployed from `fix/review-supabase-writes-and-signup-tiers` with `npm run deploy:prd`, closing a four-month gap:

| Worker | Last **code** deploy | Version | How it updates |
|---|---|---|---|
| `api-gateway` | **2026-07-30** (was 2026-03-31) | `9f483435` | manual — CR13 step 1 unblocked it |
| `sender-worker` | **2026-07-30** (was 2026-07-26) | `ac1d4825` | CI on merge to `main` |
| `integrity-studio-contact` | **2026-07-30** (was 2026-03-31) | `55c13446` | manual |
| `stripe-webhook` | **2026-07-30** (was 2026-07-28) | `1e3f2cce` | manual |

⚠️ **These version IDs are a snapshot, and two have already moved once.** `api-gateway` took six further code deploys on 2026-07-30 (last at 20:19 UTC) from work outside this session, and `sender-worker` was redeployed by CI as `ac1d4825` when this branch merged to `main`. Treat the column as "what shipped that day", not as current state, and read the live value rather than this table:
```bash
npx wrangler deployments list --name <worker>   # or the API: GET /accounts/{id}/workers/scripts/{name}/deployments
npx wrangler secret list --name <worker>        # what is actually bound
```

What went live: the **JWKS/ES256 JWT verifier**, CR03's `RATE_LIMIT_KV` binding, observability on all four (CR15 item 1 + W04 step 1 — `api-gateway` and `contact-form` had *never* emitted logs or traces), CR21's `ctx.waitUntil`, CR22's billing-portal fix, CR05/CR06's 5xx-on-DB-error, the quota DO alarm flush, contact-form's fail-closed CSRF + CRLF-sanitised Subject, and the security fix that verifies the bearer token **before** quota enforcement. Verified after each deploy: all four `200`/healthy, `api-gateway` reports `{"database":"healthy","durableObjects":"healthy"}` so its DO namespace survived, `preview_urls` stayed `false`, `stripe-webhook`'s `*/15` cron and `sender-worker`'s `RECEIVER` service binding intact, and — the one that mattered — **the zone routes are unchanged, `api.integritystudio.ai/*` still → `obtool-api`**, so CR13's trap did not fire.

~~**Two Workers were deliberately NOT deployed.** `bootstrap-worker` has no production deployment…~~ **Resolved 2026-07-31 — `bootstrap-worker` no longer exists.** CR26 was closed by mounting `POST /bootstrap` **inside `api-gateway`** rather than standing up a sixth Worker, so the shipped Flutter app's existing call now resolves with no client release. The handler was ported over, `workers/bootstrap-worker/` was deleted, and the name is gone from `WORKERS`/`SECRET_BEARING` in `deploy-environments.test.ts` and from the root `package.json` scripts. **Verified live:** `POST /bootstrap` on the production gateway returns **401**, not 404 — the route is mounted and auth-gated. Only `receiver-worker` remains in the "do not deploy" category: it is a local stub / test double (`name = "receiver-worker"`), so its `deploy:prd` would likewise create a production Worker that nothing binds to and that returns mock responses. Neither should be run without a decision to stand that service up.

⚠️ **Two things about deployment history that remain true.** Binding a secret creates a deployment **without shipping code**, so timestamps alone lie — read them as "bindings changed" unless the source is `version_upload`. That is how `stripe-webhook` was caught running a 2026-03-31 build that could not write `webhook_events_log`.

**You can recover *which* bindings changed, and when — `wrangler secret list` cannot tell you that, but the versions API can.** Each version's detail carries `resources.bindings`, so diffing the **name** sets across versions reconstructs the whole bind/unbind history without ever reading a secret value (values are write-only; only names are returned). Two things this settled on 2026-07-31 that were otherwise guesswork: `SIGNING_KEYS`/`ACTIVE_KEY_ID` were provisioned at **2026-07-30T01:28Z**, not 2026-07-29 as `sender-worker/wrangler.toml` claimed (the stale date was local PDT — the API is UTC, so **record UTC**), which in turn confirms CR01's 2026-07-29 `/send` verification really did exercise `SHARED_SECRET`; and CR15's four stale secrets really were deleted, at 2026-07-31T05:07Z. Note the two tools count different things — `wrangler secret list` returns secrets only, while `resources.bindings` also includes KV, service, and DO bindings, so the same worker reads as 13 secrets or 15 bindings. Reconcile before concluding a count disagrees.
```bash
ACCT=$(doppler secrets get CLOUDFLARE_ACCOUNT_ID --project integrity-studio --config prd --plain)
TOKEN=$(doppler secrets get CLOUDFLARE_API_TOKEN --project integrity-studio --config prd --plain)
B=https://api.cloudflare.com/client/v4/accounts/$ACCT/workers/scripts/<worker>/versions
curl -s -H "Authorization: Bearer $TOKEN" "$B?per_page=100"   # ids + created_on + source
curl -s -H "Authorization: Bearer $TOKEN" "$B/<version-id>" \
  | python3 -c 'import json,sys; print(sorted(b["name"] for b in json.load(sys.stdin)["result"]["resources"]["bindings"]))'
``` And **`sender-worker` is CI-deployed on merge to `main`, while `HEAD` is 131 commits ahead of `origin/main`** — so a push to `main` today would deploy *older* code over what is now live, a silent rollback. Merge the branch before relying on the current deployment.

See [docs/changelog/1.3/CHANGELOG.md](docs/changelog/1.3/CHANGELOG.md) for recent changes.

### Known Issues
Tracked with a status table in [docs/BACKLOG.md](docs/BACKLOG.md#code-review-2026-07-26--2026-07-27-cr01cr16), now CR01–CR29. **CR17, CR19, CR21, CR23, CR24, CR26, CR27, CR28 closed**; CR18 and CR12 went from blocking to mostly-resolved once a live Stripe key was minted. **CR11 went from 10/13 isolation failures to 3/13 on 2026-07-29, then back to 5/13 by 2026-07-31** (see CR11 below — one is a real regression, one is the detector watching a deleted slot), and CR25 was filed the same day from an Auth0 production-readiness audit. **CR29 was filed 2026-07-31 out of CR11's diagnosis** and is the newest P1: the HMAC key rotation retires nothing. What remains needs a credential decision, a spend decision, an answer about intent, or a production deploy.

**CR13 step 1 is done (2026-07-29)** — the `routes` key has been removed from `workers/api-gateway/wrangler.toml`. `deploy:prd` is now safe to run and will not capture `obtool-api`'s traffic — **confirmed by an actual deploy on 2026-07-30, after which the zone routes were unchanged.** Those four months of undeployed fixes (the bearer-token auth check, CR22's billing-portal 403) **have now shipped**. The hostname-topology decision (what URL customers should use) is still open — see BACKLOG.md CR13 steps 3–5.

**P1**
- **CR18**: **two different Stripe accounts** — `prd` holds a `pk_live_` *publishable* key, `dev` an `sk_test_` secret key. `STRIPE_SECRET_KEY` (what the code reads) is empty everywhere, so **no worker can make a server-side Stripe call**. Stripe has no API to create secret keys; this needs one Dashboard action plus a decision about which account is production
- **CR01**: ⚠️ partial — history scrubbed + force-pushed 2026-07-29. Stripe rotated + re-bound (old key still needs Dashboard revocation). Supabase: **legacy `anon` + `service_role` JWT keys disabled and verified dead** (CR24 closed); workers' bound `sb_secret_` keys unaffected and healthy. **Doppler slot cleanup done 2026-07-29** — all six anon slots now hold the live `sb_publishable_` key; `SUPABASE_JWT_SECRET`'s real value was found in Doppler `dev` (it HMAC-verifies the project's own legacy JWTs), copied to `prd` and cleared from `dev`, and `api-gateway`'s existing binding was proven already correct via `/v1/me` (real-secret token → 404 user lookup, UUID-signed → 401); the stray `sb_secret_bgU_b` "default" key was revoked; the duplicate `SUPABASE_SERVICE_KEY` slot was deleted; and `SUPABASE_ACCESS_TOKEN` was emptied because a garbage value *overrides* the CLI keychain (a real `sbp_` token can only be minted in the Dashboard — the Management API 404s). Auth0: both `AUTH0_CLI_SECRET` and `AUTH0_CLIENT_SECRET` rotated, validated, and re-bound (ROPC fixed via Management API `rotate-secret`; live `/signin` verified 200 + JWT). HMAC `SHARED_SECRET` rotated on both sender and receiver, verified by a live `/send` round-trip — accurate as stated, but note it claims a *rotation*, not a revocation: **the pre-rotation key is not retired by this, and neither is the current one by the next rotation** (CR29). The `/send` verification was also valid only because `SIGNING_KEYS` was not yet bound on 2026-07-29 — **now measured, not assumed**: the last version of that day (`693d865d`, 21:20Z) binds `SHARED_SECRET` and no `SIGNING_KEYS`. The same check today exercises `v2` and would prove nothing about `SHARED_SECRET`. `sb_secret_` service keys swapped to the new `integrity_provisioning_key` on all four workers and the old key revoked + verified dead. Also swept the wider Doppler config: cleared two `AUTHO_*` slots (typo — letter O) holding Auth0 management bearer tokens **expired 241 and 125 days**, one from a different tenant, plus two dead pre-rotation M2M secret copies (`prd AUTH0_SECRET`, `dev AUTH0_CLI_SECRET`). `check:env-isolation` went from 10/10 failures to **7 of 13**. Two live-credential findings came out of it: ~~**`SUPABASE_DB_PASSWORD` is the same string as the live `sb_secret_` key**~~ — **superseded 2026-07-31: it no longer is, and it no longer authenticates.** The recommended Dashboard reset appears to have happened, decoupling the two, but Doppler was never updated, so the slot now holds a 16-char password that fails `28P01`. See the Supabase section above — and **two different live `rk_live_` Stripe keys** exist on the production account, of which code reads only `STRIPE_SECRET_KEY`. Remaining: Stripe Dashboard revocations (old key + the unused `…B6I8`), a Dashboard-minted `sbp_` token for `SUPABASE_ACCESS_TOKEN` (CI's migration-drift job now **skips** rather than failing as of 2026-07-31, so this enables real drift detection rather than clearing a red X), and revoking the `sbp_` token exposed in a session transcript. Full state: BACKLOG.md CR01 step 3
- **CR11**: Doppler `dev` still shares the same Supabase **project** and Auth0 **tenant** as `prd`, so `--config dev` is not a safety boundary. Detector: `npm run check:env-isolation` — **5 of 13 failing, measured 2026-07-31** (10/10 → 3/13 on 2026-07-29, then **regressed**; it now covers 3 Stripe rows too). Longstanding: `SUPABASE_URL` + `SUPABASE_ANON_KEY` (one project) and `AUTH0_DOMAIN`. **Two new, and both are traps.** `SHARED_SECRET` is byte-identical across the configs again — the 2026-07-29 rotation has been undone by something no doc records. **Diagnosed 2026-07-31: `prd` was NOT overwritten** (`dev` was re-copied from it), so re-rotating `dev` is safe — but it only un-shares this row, it does **not** close the downgrade path that diagnosis uncovered; that is **CR29** below, and the mechanism lives there. And `SUPABASE_SERVICE_ROLE_KEY` reads "UNSET in both" only because **the slot exists in neither config** — the detector is watching a name that is gone, which masks the real finding: the live service key now lives in `SUPABASE_PROVISIONING_KEY`, is **byte-identical in `dev` and `prd`**, and **returns HTTP 200 against the production database**. So `--config dev` still grants full RLS bypass on production, and BACKLOG.md CR01's claim to the contrary is false. Fixing the detector (swap the slot name in `SECRETS`) is a prerequisite for trusting the count, though it will not lower it — the new row is genuinely shared. **A second tenant already exists** — `dev-njjmghdzm23uy0p7.us.auth0.com` is live (OIDC + JWKS 200) but referenced by nothing here; both configs point at `dev-68gg87ow4mg4kzyo` ("Integrity Studio", 95 users, all live apps). So `AUTH0_DOMAIN` needs an **M2M credential** for that tenant, not a tenant creation — after which provisioning is scriptable and `default_directory` can point at the dev connection there, removing the `realm` code change entirely. Note the tenant **environment tag is not exposed via the Management API**, so Development/Production changes can only be confirmed in the Dashboard. Auth0 now has a `dev-users` connection plus dev-only ROPC/M2M clients, proven by probe to authenticate no production user. **Two traps recorded there:** creating any client in this tenant auto-enables it on the production connection (`is_domain_connection: true` — re-check the client list after every creation), and `/signin`'s plain `password` grant resolves via the tenant-wide `default_directory`, so dev credentials authenticate nothing until the code passes a `realm`. See BACKLOG.md CR11
- **CR29**: 🔴 **the HMAC key rotation retires nothing** (filed 2026-07-31 out of CR11's diagnosis). `SIGNING_KEYS`/`ACTIVE_KEY_ID=v2` is provisioned on both sides and works — but the receiver resolves an **absent** `x-key-id` to the legacy `SHARED_SECRET`, a credential with no key id and therefore no rotation handle. Measured against production `POST /inbox` with controls: `v2` + key id → 200, `SHARED_SECRET` + **no** key id → **200**, garbage → 401. Consequences: removing a key from `SIGNING_KEYS` revokes nothing, CR01's HMAC rotation is incomplete, and anything holding `SHARED_SECRET` (incl. Doppler `dev`) can forge provisioning events with one header omitted. **Two traps.** A green `/send` does **not** test this — `resolveOutboundSigningKey` prefers `v2`, so the happy path never touches `SHARED_SECRET`; sign `/inbox` directly, with `curl` and a positive control (Python `urllib` gets a blanket `403 1010` that mimics a signature failure — see CR14). And the sender has the mirror hazard: it falls back to `SHARED_SECRET` with no key id on four conditions including a typo'd `ACTIVE_KEY_ID`, marked only by a `console.warn`, so a rotation can silently downgrade and keep working. **Step 0's caller audit is done (2026-07-31) and it found a blocker, so the order changed.** `observability-toolkit`'s CI e2e job (`.github/workflows/publish.yml:87`, `--config dev`) runs `services/e2e/receiver-security.e2e.ts`, which signs `/inbox` with `SHARED_SECRET` and **no `x-key-id`** against the **production** receiver on every publish — its gate is satisfied because Doppler `dev` has both `PROVISIONING_RECEIVER_WORKER_URL` and `SHARED_SECRET`. Requiring the header breaks its test 4 outright and silently degrades tests 2–3 (they assert `401 INVALID_SIGNATURE`, which is also what a missing header returns — green while testing nothing). **It could not just add the header:** `SIGNING_KEYS`/`ACTIVE_KEY_ID` are UNSET in `dev`, and since `dev` points at the *production* receiver, provisioning them there would copy a production signing key into `dev` — re-creating CR11. ✅ **Resolved the same day by removing the `e2e` job** from that workflow, so `sender-worker` (signs `v2`) is the sole automated caller and steps 1–3 are unblocked; the **dev receiver (CR02 item 5) is off this critical path** and is now only what is needed to *restore* the job. Two things that removal did not fix and one it revealed. The tests-2-and-3 degradation is real and survives, so it is recorded in a comment atop `receiver-security.e2e.ts` — restoring the job without adding a positive control brings back two assertions that pass while testing nothing. Seven unrelated specs in that package now run nowhere (`provision-key`, `sender-receiver`, `api-key-auth`, `ingest-evaluations`, `dashboard-auth{,-errors,-logout}`), which is the reason to restore rather than delete; restore conditions are in the workflow comment. And ⚠️ **the receiver auto-deploys** — `api-provisioning-receiver-test.yml` deploys production on every push to `main` touching `services/api-provisioning-receiver/**`, so the step-2 change ships on merge with no staging gate; land the sender fix first. Also measured: the receiver **did not log the resolved key id** (never recorded; no success-path auth event; `auth.invalid_signature` covered both "no secret resolved" and "signature mismatch" with no discriminator), so the "watch a full traffic cycle" evidence was unobtainable. ✅ **Instrumented 2026-08-01** (`observability-toolkit` `8fcae0b`) — `resolveSigningKey` returns which credential answered, and `/inbox` now emits `auth.verified` (info, with `keyId`), **`auth.verified_legacy_key`** (warning — the keyless path, and the metric that gates unbinding: when it stops appearing, the fallback has no callers), `auth.key_unresolved` (a rejected key id, split out of `auth.invalid_signature`), and `auth.invalid_signature` with `keySource`. Distinct event *names*, not a `source` field, because Sentry cannot search `extra` while the name becomes the `event_type` tag. HTTP behaviour is unchanged and both 401s stay byte-identical, so key ids cannot be enumerated by diffing responses. **Committed unpushed on purpose — pushing deploys the receiver** (see the auto-deploy note above), and the telemetry is only useful once live. Revised order: ~~instrument~~ ✅ → **sender fail-closed** (next) → receiver requires the header → *then* unbind `SHARED_SECRET`. Unbinding early is an outage, not a fix, and step 3 additionally waits on `auth.verified_legacy_key` going quiet in *deployed* traffic. Confirmed out of scope: `obtool-ingest`'s evaluations endpoint is a separate HMAC scheme (`INJECT_HMAC_SECRET`, body-only, `sha256=` prefix). See BACKLOG.md CR29
- **CR12**: ⚠️ partial — `api-gateway` and `stripe-webhook` both healthy; `STRIPE_SECRET_KEY` and `STRIPE_WEBHOOK_SECRET` bound 2026-07-28. Still missing `API_KEY_HMAC_SECRET` (canonical value lives in `observability-toolkit`; API-key auth routes are broken until it is bound). The standing caveat that `api-gateway`'s *deployed* behaviour might not match this repo is **resolved as of 2026-07-30** — it was redeployed from current source
- **CR14**: ⚠️ partial — **every exposure this repo controls is closed live as of 2026-07-29 evening.** `sender-worker` (14 secrets then, **16** since the 2026-07-30 key-rotation provisioning) and `integrity-studio-contact` (2) joined `api-gateway` + `stripe-webhook` at `previews_enabled: false`, and the **71 superseded versions** that had been serving — 63 `sender-worker` back to 2026-03-29, 8 `contact-form` back to 2026-01-17 — now all return `404`. **Still exposed:** cross-repo `api-provisioning-receiver` (**9** secrets — re-counted live 2026-07-31; the "10" was an error, `SIGNING_KEYS` was counted as an addition without noticing `SUPABASE_SERVICE_ROLE_KEY` had been dropped, so read the list not the total — and it binds both credentials CR01 rotated plus the new `SIGNING_KEYS`, so its retained versions publish the *current* values — measured: **30 of 30 code versions reachable, oldest 2026-03-20, all superseded**) and `stripe-webhook-dev` (2 sandbox, closes on its next dev deploy). Four things worth keeping: **superseded versions do not age out** — the earlier "past retention" reading was wrong, a `404` means the version came from `wrangler secret put`, which gets no preview URL; the mitigation POST **must include `"enabled":true`**, or it takes the Worker's `workers.dev` hostname down, which is the only way the shipped Flutter app reaches `sender-worker` and `integrity-studio-contact`; it propagates over **seconds**, so sample more than once (the first sweep showed 42 of 63 closed, the next showed all 63); and two probe traps that both understate exposure — workers.dev returns a blanket `403` to `Python-urllib` where `curl` gets the true code, and reachability is "anything but `404`", since `403`/`405`/`500` all mean the Worker ran

**P2**
- **CR20**: 🔴 `stripe-webhook` cron is now the **only** retry path (CR21 returns 2xx before processing via `ctx.waitUntil`, foreclosing the 5xx option). The cron is unmonitored — W04 alerting is mandatory
- **CR17**: ✅ done — migration ledger repaired; `scripts/check-migration-drift.sh` + `migration-drift-check` CI job added
- **CR13**: ⚠️ partial — step 1 done 2026-07-29 (routes key removed) and **proven in practice 2026-07-30**: a real `api-gateway` `deploy:prd` ran and the zone routes were unchanged afterwards, `api.integritystudio.ai/*` still → `obtool-api`. Topology decision (how to give the gateway a real hostname) still open
- **CR19**: ✅ done — out-of-order events now route to dead-letter (commits eaaa199, 9741594)
- **CR04**: JWT still passed to the dashboard in a URL fragment — cross-repo fix needed
- **CR02**: ✅ mostly closed — `npm run deploy` targets `--env dev`, verified live. Only the dev receiver remains
- **CR03**: ✅ done — KV namespaces created and bound; **live in production since the 2026-07-30 `sender-worker` deploy** (`RATE_LIMIT_KV` → `766332ec…`, confirmed in the deploy's binding list)
- **CR25**: ⚠️ partial (filed 2026-07-29) — Auth0 tenant production-readiness, before flipping `dev-68gg87ow4mg4kzyo` from Development to Production. **Fixed:** the `google-oauth2` connection ran on Auth0's shared **development keys** while enabled on 6 apps (0 users used it) — now disabled for every app, connection kept so it is one PATCH to restore once real Google credentials exist. **Partial:** TOTP + recovery-code factors enabled, so MFA can be enrolled at all, but no enforcement policy — that would force all 96 users to enrol and needs a decision. **Blocked on spend:** breached-password detection returns `400 "upgrade your subscription"`, joining the custom domain as a paid feature. Also open: `implicit` grant on 4 apps incl. the dashboard SPA (same URL-fragment mechanism as CR04), ROPC on the Management M2M, unbranded Universal Login, no log streams, 24h API tokens

**P3**
- **CR15**: ✅ **done** — item 1 deployed 2026-07-30 (observability was silently off in production for ~4 months and now reports `enabled=True logs=True invocation=True traces=True` on `sender-worker` plus all three other Workers), and **item 2 closed 2026-07-31**: the four stale secrets — `RECEIVER_WORKER_URL`, `PROVISIONING_RECEIVER_WORKER_URL`, `AUTH0_CLI_AUDIENCE`, `SUPABASE_ANON_KEY` — were deleted at 2026-07-31T05:07Z, taking production `sender-worker` from 16 to 12 bound secrets. Independently corroborated 2026-07-31 by diffing binding-name sets across Worker versions (see the deployment-history note above): version `ac1d4825` binds all four, `91bac38e` binds none of them, and the four `api`-source Secret Change versions in between are the deletions. `/signin` still 401s correctly and the `RECEIVER` + `RATE_LIMIT_KV` bindings survived
- **CR21**: ✅ done **and now actually live** — merged 2026-07-29 but not deployed until 2026-07-30; the deployed bundle now contains `waitUntil`/`queued`/`Manual replay required`, and the stale `Failed to log processed event` string from the 2026-03-31 build is gone
- **CR22**: ⚠️ **deployed 2026-07-30, still unexercised.** The code is live (`billing_portal` present in the deployed bundle), but the 403 path needs a *valid* API key that fails only the type check, and API-key auth is unreachable while `API_KEY_HMAC_SECRET` is unbound (CR12). An invalid key correctly returns `401 Invalid JWT format` — that is CR23's design decision, not a regression
- **CR24**: ✅ done 2026-07-29 — legacy Supabase `anon` + `service_role` JWT keys disabled, verified by probe (both now 401). Reversible via the same endpoint, but never re-enable: the JWTs are disclosed material
- **CR16**: 📋 by design, not a defect. `obtool-ingest` (→ R2+D1) is Integrity Studio's **internal** OTEL pipeline; `api-gateway`'s `/v1/ingest/otel` (→ Supabase) is the **customer-facing** one. **Do not de-duplicate these.** Folding obtool-ingest into api-gateway is an eventual goal, explicitly not current priority

---

## Project Structure

```
lib/
├── config/content/   # Static content definitions (content.yaml models)
├── controllers/      # Business logic controllers
├── models/           # Data models
├── pages/            # Page widgets (40 pages)
├── routing/          # GoRouter configuration (43 routes)
├── services/         # External integrations (analytics, consent, contact, dashboard, provisioning)
├── theme/            # Design system (colors, decorations, spacing, typography)
├── utils/            # Utility functions
├── widgets/          # Reusable components
│   ├── common/       # Shared widgets
│   ├── consent/      # Cookie consent UI
│   ├── decorative/   # Visual elements
│   ├── docs/         # Documentation components
│   ├── modals/       # Dialog components
│   ├── navigation/   # Navigation components
│   └── sections/     # Page sections
├── app.dart          # Main App widget
└── main.dart         # Entry point

workers/
├── lib/              # Shared constants, HTTP utilities, validation, schemas
│   ├── constants.ts  # Time constants (MS_PER_DAY)
│   ├── http/         # CORS, request parsing, responses, error handling
│   ├── types/        # Zod schemas (usage, OTEL, audit, provisioning, Supabase)
│   └── validation/   # Validation helpers, error formatting
├── contact-form/     # Contact form worker (Resend email, KV rate limiting, CSRF)
├── api-gateway/      # API Gateway worker (ingest, usage aggregation, auth, quota)
├── sender-worker/    # Provisioning sender: inline /signup + /signin (Auth0+Supabase); HMAC-signs /send events to receiver
├── receiver-worker/  # Local stub / test double only (not deployed; production is api-provisioning-receiver in observability-toolkit)
└── stripe-webhook/   # Stripe event handler (subscription lifecycle, checkout, dead-letter, Supabase sync)

scripts/              # Build/dev tooling, repomix generation
docs/                 # Architecture, routes, changelog, backlog
test/                 # Unit + widget tests (2,982 passing, ~94% coverage)
```

## Workers

**Shared Library**
- [workers/lib/](workers/lib/) — Shared HTTP, validation, and constants (shared test suite)
  - `constants.ts` — Shared time constants (MS_PER_DAY)
  - `http/` — CORS, request parsing (JSON, bearer token, query params, method assertion), response factories, error handling
  - `types/` — Zod schemas (usage events, OTEL spans, audit logs, provisioning, Supabase)
  - `validation/` — Typed validation helpers, formatted error responses

**Workers**
- [workers/contact-form/](workers/contact-form/) — Cloudflare Worker handling contact form submissions (Resend email, KV rate limiting, CSRF, idempotency)
- [workers/sender-worker/](workers/sender-worker/) — Cloudflare Worker (`api-provisioning-sender`) exposing `POST /signup`, `POST /signin`, `POST /send`, `POST /create-checkout-session`, `GET /health` (Zod v4 validation). Two distinct paths:
  - **Inline (no receiver):** `/signup` creates the Auth0 user (M2M `AUTH0_CLI_*` → Management API) + Supabase org/user/owner-membership, then signs in via Auth0 ROPC (`AUTH0_CLIENT_*`) and returns `{jwt, auth0Sub, userId, email}`. `/signin` is direct Auth0 ROPC (`{email,password}` → `{jwt,email}`).
  - **Forwarded to receiver:** `/send` events (`provision_api_key`, `sign_in`) are HMAC-SHA256-signed and forwarded to the production receiver `api-provisioning-receiver` via the `[[services]]` binding. API-key minting happens on the receiver, not here.
  - **`/create-checkout-session` derives the org server-side from the email — never accept an `orgId` from the caller.** `stripe-webhook` reads `session.metadata.org_id || session.client_reference_id` to run `linkStripeCustomer` (`workers/stripe-webhook/src/handlers/checkout.ts:24`); with neither set it warns and bails, which is why no subscription linked to an org before 2026-07-31 ([[BACKLOG CHK01]]). The org therefore has to reach Stripe somehow — but **adding `orgId` to `CreateCheckoutSessionSchema` would be a vulnerability**: this route is origin-gated and *unauthenticated*, so a client-supplied org id lets any caller attach a subscription to an org they do not own. And the origin gate is not a boundary here — `isOriginAllowed` is a browser-surface control only, and origin-less callers (Flutter native, curl) bypass it by design. `supabaseFindOrgIdByEmail` resolves it instead (prefer `default_organization_id`, else oldest active membership — mirroring `custom_access_token_hook`), which also needs no change from the landing page or Flutter client. Resolution is **best-effort by design**: an unknown email or a failed lookup logs and proceeds with an unattributed session, because failing checkout to protect a metadata field trades a linking bug for a revenue bug.

    ⚠️ **This route is only correct for single-org users, and that limit was not stated when it was written (found 2026-07-31).** `supabaseFindOrgIdByEmail` resolves an *identity* to an org, so for anyone holding several memberships it silently returns their default org rather than the one being paid for. A real case: `alyshia@inventoryai.io` owns three orgs, and the `default_organization_id` already carried a paid subscription — so upgrading a *different* org through this route would have attached the new Stripe customer to the org that was already paying and left the intended one still showing no billing account. **Use it only for the signup flow, where the user has exactly one org and no session yet.** Anywhere the caller is authenticated and the org is known, use **`POST /v1/orgs/:id/checkout-session`** on `api-gateway` instead, which takes the org from a membership-checked route parameter. That does not contradict the rule above — the org id still never comes from the request body; it comes from a path the caller has been authorized against.
  - **Gotcha — mock by URL, not by call order, in `index.test.ts`.** `handleCreateCheckoutSession` now makes a Supabase lookup *before* the Stripe call, so `mockResolvedValueOnce`/`mockRejectedValueOnce` bind to the lookup and the Stripe branch under test never runs. Three existing tests broke this way, and two of them lived in a sibling `describe` that a `-t`-filtered run did not touch — they only surfaced on the full suite. Route on `url.includes('/rest/v1/')` instead.
- [workers/receiver-worker/](workers/receiver-worker/) — **Local stub / test double only** (signature verification + replay protection, returns mock responses). The production receiver is `api-provisioning-receiver`, which lives in the separate `observability-toolkit` repo and persists to Supabase. Nothing binds to this stub in production.
- [workers/stripe-webhook/](workers/stripe-webhook/) — Cloudflare Worker handling Stripe events (subscription lifecycle, checkout sessions, dead-letter queue, Supabase sync)

## Testing Strategy

**Hybrid Testing for ProvisioningService** — Three layers without duplicating test maintenance:
1. **Unit Tests** (48 tests) — Mock HTTP via `MockProvisioningDio`, test retry logic and error handling
2. **Contract Tests** (25 tests) — Verify Dart shapes match TypeScript Zod schemas, no live calls, runs in standard CI
3. **Live Integration Tests** (10 tests) — Real HTTP calls to staging, guarded by `LIVE_TESTS` dart-define, optional CI job

**Key Pattern**: Extract mock to `test/helpers/mock_provisioning_dio.dart` for reuse across unit + contract tests. Type preservation: always create `Response<dynamic>` before casting to `Response<T>` to preserve runtime type info (fixes CI environment issues).

**Mock Dependency Injection**: Use `setDioForTesting()` seam to inject test Dio instance (see provisioning_service.dart:~230).

## Flutter Canvas Limitations (E2E Testing)

Flutter Web renders to `<canvas>` via CanvasKit — DOM selectors cannot reach widget content. Workaround: wrap widgets with `Semantics(label: '...', button: true)` to expose ARIA labels, then use `page.getByLabel()` in Playwright. `SemanticsBinding.instance.ensureSemantics()` in `main.dart` enables the tree at startup. E2e tests must call `enableFlutterSemantics()` and gracefully skip on Flutter [#151929](https://github.com/flutter/flutter/issues/151929) when the tree fails to materialise. See `e2e/tests/docs-content.spec.ts` for the reference pattern.

**Applied in:** #111 (doc components), #114 (404 recovery), #117 (mobile hamburger menu)

## Repomix Context (docs/repomix/)

Choose the appropriate file based on the task:

- [token-tree.txt](docs/repomix/token-tree.txt) — file tree with token counts; use for navigation, finding files, estimating scope
- [docs-compressed.xml](docs/repomix/docs-compressed.xml) — compressed docs, CLAUDE.md, README (~11K tokens); use for broad docs understanding and search
- [repomix.xml](docs/repomix/repomix.xml) — full lossless source; use only when exact code detail is needed (e.g. line-level edits, debugging)
- [tests-compressed.xml](docs/repomix/tests-compressed.xml) — compressed test suite (Flutter + Workers); use when writing or reviewing tests

## Deployment Strategy

### Worker Deployment

All Cloudflare Workers use **Doppler for secret management**. Each worker has two deployment scripts, and they publish to **two different Workers**:

**Development (Local)**
```bash
npm run deploy      # wrangler deploy --env dev → <worker>-dev, reachable at its workers.dev URL
```

**Production (CI/CD)**
```bash
npm run deploy:prd  # wrangler deploy (top-level config) → the live worker; requires a Doppler prd token
```

Deploy targets are set by the **wrangler environment**, not by Doppler. Doppler chooses which secrets get injected; `--env dev` chooses which Worker gets written. Both matter, and conflating them is what CR02 was about — before 2026-07-27 both scripts ran a plain `wrangler deploy` against a single-name config, so a local `npm run deploy` published straight over production.

The top-level block of each `wrangler.toml` **is** the production config; `[env.dev]` is the dev overlay. Two consequences worth knowing before editing one:
- `deploy:prd` must never pass `--env`. A named environment renames the Worker (`sender-worker` → `sender-worker-production`), which orphans its Durable Object namespaces, routes, and crons.
- Wrangler does not inherit `durable_objects`, `services`, `vars`, `kv_namespaces`, `r2_buckets`, `d1_databases`, or `queues` into a named environment. Add one at the top level and you must repeat it under `[env.dev]` or the dev Worker silently loses the binding.
- **`routes` and `triggers` are the opposite — they ARE inherited, and omitting them is dangerous.** A named environment with no `routes` key inherits the top-level production routes and binds them to the dev Worker. On 2026-07-27 that handed `api.integritystudio.ai/v1/*` to the secret-less `api-gateway-dev`. Only an explicit `routes = []` (and `crons = []`) detaches a dev environment. The two rules pull in opposite directions: **repeat bindings, empty routes and triggers.**

Both rules are enforced by `workers/lib/deploy-environments.test.ts`.

**Pointing the Flutter app at the dev workers**
```bash
flutter run -d chrome \
  --dart-define=SENDER_WORKER_URL=https://sender-worker-dev.alyshia-b38.workers.dev \
  --dart-define=API_GATEWAY_URL=https://api-gateway-dev.alyshia-b38.workers.dev \
  --dart-define=CONTACT_API_URL=https://integrity-studio-contact-dev.alyshia-b38.workers.dev
```
Without these the app uses the compile-time defaults in `lib/services/`, which point at the **production** workers — including in `ci.yml`, which builds with no `--dart-define`.

All five dev workers were deployed and verified on 2026-07-27; production was confirmed untouched by the same run.

**⚠️ Dev workers are NOT data-isolated.** Doppler's `dev` and `prd` configs share the same Supabase **project** and Auth0 **tenant** (`npm run check:env-isolation` reports which — **5 of 13 rows as of 2026-07-31**; the Supabase JWT and Auth0 client credentials are distinct, but the HMAC `SHARED_SECRET` is **shared again** and the live Supabase service key is shared under a slot the detector does not check — and in any case a shared project and tenant mean distinctness alone isolates nothing). Selecting `--config dev` therefore changes nothing about which database or Auth0 tenant is used. Stripe is *not* affected, but not for the reason previously stated here (corrected 2026-07-27): `prd`'s `STRIPE_API_KEY` is a **`pk_live_` publishable key** and `dev`'s is an `sk_test_` secret key, belonging to **two different Stripe accounts**. A publishable key is public by design, so there is no exposure — but `STRIPE_SECRET_KEY`, the name the code actually reads, is empty in all three configs, so no worker can make a server-side Stripe call at all. `check:env-isolation` compares no Stripe credential. See BACKLOG.md CR18. The dev workers were deliberately deployed **without secrets** so they cannot reach production data; that is why they return errors on any route needing one. Do not push the `dev` Doppler secrets into them — that would create a second production-capable worker rather than a dev environment. Tracked as BACKLOG.md CR11.

**Also not isolated:** `sender-worker-dev` binds `RECEIVER` to the production `api-provisioning-receiver`, because no dev receiver is deployed (it lives in the `observability-toolkit` repo). Tracked as CR02 item 5.

#### Doppler Configuration
- **Project**: `integrity-studio`
- **Dev Config** (`--config dev`): ⚠️ **not a separate environment.** Holds the same Supabase project, Auth0 tenant, and HMAC secret as `prd` — see CR11 and run `npm run check:env-isolation`
- **Prd Config** (`--config prd`): Production deployments, secret rotation, sensitive operations
- **Stg Config**: exists but is **empty** — every credential is unset

Worker runtime secrets are **not** supplied by Doppler. `wrangler deploy` does not turn ambient env vars into Worker secrets; those are set per worker with `wrangler secret put`. Doppler's role at deploy time is to provide `CLOUDFLARE_API_TOKEN`. Check what a worker actually has bound with:
```bash
npx wrangler secret list --name <worker>          # or --env dev
```

**Read Doppler values with `doppler secrets get --plain`, not `doppler run`.** On 2026-07-27 a `doppler run --config prd` reported a value that `doppler secrets get --config prd --plain` contradicted, and the upstream API confirmed the latter. `~/.doppler/fallback/` caches credential snapshots, so a stale one can be served silently. Two traps compound it: `sh -c 'echo -n "$V"'` prints the literal `-n ` (POSIX `sh`, not bash) and corrupts any prefix check — use `printf '%s'` — and a prefix alone is weak evidence. Fingerprint instead, which never prints secret material:
```bash
v=$(doppler secrets get NAME --project integrity-studio --config prd --plain | tr -d '\n')
printf 'len=%s sha=%s\n' "${#v}" "$(printf '%s' "$v" | shasum | cut -c1-12)"
```
When binding a secret to a Worker, pipe that captured value into `wrangler secret put` rather than letting `doppler run` inject it.

**Sample twice before concluding a binding is bad — Cloudflare rolls a new version out over seconds, not instantly.** On 2026-07-31, immediately after `wrangler secret put STRIPE_PLAN_TO_PRICE_JSON` + `deploy:prd`, a probe with `tier=growth` returned `200` while the very next probe with `tier=starter` returned `no Stripe price configured` — from the *same* secret, whose Doppler value was byte-correct throughout (86 bytes, both keys, verified by dumping it to a file and `JSON.parse`-ing). Different edge nodes were simply on either side of the rollout. A minute later all tiers behaved. The obvious-but-wrong read is "the value was written wrong", which sends you re-`put`ting a secret that was already fine. This is the **same caveat CR14 records for the `preview_urls` sweep** — the first pass showed 42 of 63 versions closed, the next showed all 63 — so treat it as a general property of Cloudflare config propagation, not a quirk of one endpoint. Re-probe before diagnosing, and prefer a loop over a single shot.

#### Worker Deployment Overview

| Worker | Purpose | Production Worker | Dev Worker (`--env dev`) | CI/CD |
|--------|---------|-------------------|--------------------------|-------|
| **sender-worker** | Inline signup/signin (Auth0+Supabase); HMAC-signs `/send` events to receiver | `sender-worker` | `sender-worker-dev` | ✓ Yes (main) |
| **api-provisioning-receiver** | Verifies signed requests, persists to Supabase (production receiver) | `api-provisioning-receiver` | — (separate repo) | ✓ Yes (separate repo) |
| **stripe-webhook** | Handles Stripe subscription events | `stripe-webhook` | `stripe-webhook-dev` (no cron) | — |
| **contact-form** | Processes contact form (Resend, KV rate limit) | `integrity-studio-contact` | `integrity-studio-contact-dev` (no KV) | — |
| **api-gateway** | API gateway (aggregation, quota) | `api-gateway` | `api-gateway-dev` (own DO namespace) | — |
| ~~**bootstrap-worker**~~ | **Removed 2026-07-31** — `POST /bootstrap` is now a route on **api-gateway** (BACKLOG.md CR26). The directory is deleted; a `bootstrap-worker-dev` Worker may still linger in the account with zero secrets bound | — | — | — |
| **receiver-worker** | Local stub / test double — not deployed | — | — (`[env.dev]` names `receiver-worker-dev`, but it has never been deployed) | — |

**Note:** `sender-worker` reaches the receiver via a service binding — `service = "api-provisioning-receiver"` in `workers/sender-worker/wrangler.toml` (the source of truth). The production receiver `api-provisioning-receiver` lives in the separate `observability-toolkit` repo (`services/api-provisioning-receiver/`) and is deployed from there. `workers/receiver-worker/` in this repo is a **local stub / test double** — it is not deployed and nothing binds to it.

### GitHub Actions CI/CD

**Main branch deployments** (`.github/workflows/ci.yml`):
- Runs on `push` to `refs/heads/main`
- Requires all tests to pass
- Deploys **sender-worker only** (other workers deploy manually with `npm run deploy:prd`)
- Environment: `production`
- Secrets: `DOPPLER_TOKEN`, `CLOUDFLARE_API_TOKEN`, `CLOUDFLARE_ACCOUNT_ID`

**Deployment Safety**:
- ✅ Production secrets managed via GitHub Secrets + Doppler
- ✅ `deploy:prd` uses `--config prd` (never `dev`)
- ✅ `npm run deploy` targets `--env dev`, so a local deploy cannot overwrite a production worker (enforced by `workers/lib/deploy-environments.test.ts`)
- ✅ All workers have `deploy:prd` for emergency hotfixes
- ❌ **E2E tests use `--config dev`, which is NOT isolated from prod** — the same Supabase project and Auth0 tenant back both configs. Verify with `npm run check:env-isolation` (5 of 13 failing as of 2026-07-31). BACKLOG.md CR11
- ✅ No hardcoded secrets in package.json or workflows
- ⚠️ `doppler.json` scrubbed from git history (2026-07-29); secrets only **partially rotated** (Stripe done; Supabase mis-slotted; Auth0/HMAC pending) — the on-disk `doppler.json` and `~/.doppler/fallback/` still hold pre-rotation material (BACKLOG.md CR01)

### Deployment Checklist

**Before `npm run deploy:prd`**:
1. Verify branch: `git status` (should be on a feature branch or main)
2. Run tests: `npm test` or targeted test suite
3. Set Doppler token: export `DOPPLER_TOKEN=$(doppler --project integrity-studio --config prd token)`

**After deploy**:
1. Verify in Cloudflare Workers dashboard
2. Run E2E tests: `cd workers/sender-worker && npm run test:e2e`
3. Check worker logs: `npm run tail` (if available)

### Secret Rotation

**Dev secrets** expire as per Doppler project policy.  
**Prd secrets** are rotated on a schedule; always use `doppler run --project integrity-studio --config prd`.

See `.github/workflows/ci.yml` for the current production deployment configuration and secret injection.
