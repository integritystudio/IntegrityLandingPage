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
                                  # ✅ 49/49 as of 2026-08-02 (once collected 0 tests; see CR11).
                                  #   Its bindings live in vitest.e2e.config.mts, NOT Doppler — a new required
                                  #   secret must be added there or every /send test 500s (CR29 step 2).
```

**Supabase** (migrations are the source of truth for schema — ✅ **true since 2026-08-03, and it was not before**: the ledger could not rebuild the schema at all. 10 tables, 3 enums, 2 columns on a ledger-managed table and 1 view — 43% of `public` — existed only in production. `migration list` said "zero out of sync" the whole time because it compares against **production**, which already had every object. **A migration set is only proven by replaying it onto an empty database**; that had never been done. Five baseline migrations now close it, verified at 24/24 tables+views and 255/255 columns. The CI guard is `migration-replay-check.yml` → `scripts/check-migration-replay.sh` — full local stack + `db reset` + schema assertions; written 2026-08-03, proven on its first CI run (Docker is absent on this machine, so it cannot run locally). A second dev project, `tumhmtshahktumhqqamk` / `integritystudio-dev`, exists for cloud-side replay.)
```bash
# ⚠️ SUPABASE_ACCESS_TOKEN is EMPTY in Doppler — the slot held the revoked old service
# key, and a garbage value OVERRIDES the CLI's keychain login, so exporting it breaks
# `supabase` commands that otherwise work. Leave it unset until a real `sbp_` token is
# minted in the Dashboard (BACKLOG.md CR01 step 3).
#
# The CLI's keychain session IS valid — `supabase projects list` returns the project. But
# that session authorizes the *Management API*, not Postgres, and every command below needs
# a direct database connection. Do not read a working `projects list` as "migrations can be
# applied" — see the DB-password warning under this block.
export SUPABASE_DB_PASSWORD=$(doppler secrets get SUPABASE_DB_PASSWORD --project integrity-studio --config prd --plain)
supabase migration list --linked   # local vs remote; any blank `remote` column is pending
supabase db push --dry-run         # preview; add --include-all if a file sorts before the last applied version
supabase db push                   # apply — ALL pending migrations, not just yours

# Apply ONE migration when others are pending (db push would sweep them in too):
supabase db query --linked -f supabase/migrations/<version>_<name>.sql
supabase migration repair --status applied <version>   # then record just that one
```
✅ **There IS a working route, found 2026-08-03 — use this before anything below.** The Supabase CLI holds a valid `sbp_` personal access token in the macOS keychain, and the Management API query endpoint runs **arbitrary SQL including DDL** with it. No Docker, no `SUPABASE_DB_PASSWORD`:
```bash
RAW=$(security find-generic-password -s "Supabase CLI" -w)   # go-keyring-base64:<b64>
TOK=$(printf '%s' "${RAW#*:}" | base64 -d)                    # -> sbp_...
curl -s -X POST "https://api.supabase.com/v1/projects/<ref>/database/query" \
  -H "Authorization: Bearer $TOK" -H "Content-Type: application/json" \
  -d '{"query":"select 1"}'
```
And **`supabase db push --db-url <conn>` works without linking**, which avoids mutating the repo's linked-project state that other sessions share. Use the **session pooler on :5432**, not :6543 — the transaction pooler fails mid-push with `prepared statement "lrupsc_1_0" already exists`. `supabase db dump` is *not* usable: it shells out to Docker, which is not installed here.

🔴 **The commands above still do not work — `SUPABASE_DB_PASSWORD` does not authenticate** (measured 2026-07-31; unchanged). `db push --dry-run` fails `SASL auth (FATAL: password authentication failed for user "postgres" (SQLSTATE 28P01))` against `aws-1-us-east-1.pooler.supabase.com`; `migration list --linked` fails `LegacyDbConnectError`. **Until a working password is stored, the only route for DDL is the Dashboard SQL editor** — which executes the SQL *without* writing a ledger row, so `migration list` still reports the file pending and the next `db push` fails on `already exists`. Reconcile with `migration repair --status applied <version>` once the password works.

Four dead ends, so you don't re-derive them:
- **`dev`'s copy of the password.** A *different* 16-char value (sha `ea45e4f3` vs `prd`'s `0eaaeb6e`), and it fails identically. Both configs point at the same project, so there is one real password and neither slot has it — the fix is a Dashboard reset plus storing the new value.
- **Restoring the service key to that slot.** It used to hold the same string as the live `sb_secret_` key (41 chars, sha `cdb0a4bd`); a Dashboard reset decoupled them without updating Doppler. **Do not re-couple PostgREST `service_role` to direct Postgres access** to "fix" the auth failure.
- ~~**The Management API query endpoint.**~~ **NOT a dead end — corrected 2026-08-03, and this was the most expensive wrong entry on the page.** The diagnosis was right (`POST https://api.supabase.com/v1/projects/<ref>/database/query` returns **401 `JWT could not be decoded`** for any `sb_secret_` key — that class is a data-plane credential for PostgREST; the endpoint wants an `sbp_` personal access token). The **conclusion** was wrong: `sbp_` is not Dashboard-minted-only, because **the Supabase CLI already holds a working one in the macOS keychain.** Extract it with `security find-generic-password -s "Supabase CLI" -w`, strip the `go-keyring-base64:` prefix, `base64 -d` → `sbp_…`. It runs **arbitrary SQL including DDL**, needs no Docker and no `SUPABASE_DB_PASSWORD`, and is the route that read production's entire schema for BACKLOG CR30. **So "the only route for DDL is the Dashboard SQL editor" (above) is false** — and that claim was doing real damage, since the Dashboard route is the one that executes SQL *without* writing a ledger row.
- **PostgREST and `psql`.** PostgREST cannot run DDL at all, and there is no `psql` on this machine.

⚠️ **The Doppler slot for the service key is `SUPABASE_PROVISIONING_KEY`, not `SUPABASE_SERVICE_ROLE_KEY`.** The latter exists in **neither** config (verified 2026-07-31) even though it is the name every Worker *binds* it under. Reading the binding name from Doppler silently returns empty and the next command fails with a misleading "No API key found in request".

🔴 **A third live `sb_secret_` key sits in Doppler** (found 2026-07-31): `SUPABASE_INTEGRITY_MEMERSHIP_KEY` (note the typo — MEMERSHIP), sha `3720a512`, distinct from `SUPABASE_PROVISIONING_KEY`, **byte-identical in `dev` and `prd`** (absent in `stg`), and it works — `/rest/v1/organizations` returns `200` with full RLS bypass. One more CR11 isolation row, and one `check:env-isolation` does not compare. No code in *this* repo reads it; check `observability-toolkit` before revoking. **Do not bind it to a Worker to solve an org-resolution problem** — an `sb_secret_` key is a *credential*, not a scope: it authenticates as `service_role`, bypasses RLS on every table, and carries no org identity, so the "MEMERSHIP" name grants nothing membership-specific. Both `stripe-webhook` and `api-gateway` already bind `SUPABASE_SERVICE_ROLE_KEY`, so neither lacks database access; a second key adds blast radius and no capability. Why `org_id` still has to ride in Stripe metadata is under `/create-checkout-session` below — a bootstrap ordering problem, not an access problem.

Two hard-won rules. **`create policy if not exists` is invalid PostgreSQL** — there is no `IF NOT EXISTS` for `CREATE POLICY`; use `drop policy if exists` then `create policy`. And **`migration repair --status applied` writes a ledger row without executing the SQL**, which is how two migrations came to be recorded as applied while their tables did not exist (CR17). Last resort only, never a way past a failing push.

**RLS is not optional for privacy.** PostgREST exposes every table in the `public` schema, so a table with RLS off is readable with the *publishable* anon key regardless of which key your workers use. Enabling RLS with **zero policies** denies anon and authenticated while `service_role` bypasses it — the correct posture for server-only tables. Verify with the catalog, not a status code: RLS denial returns `200 []`, not an error.
```bash
# any table here is publicly readable
select relname from pg_class c join pg_namespace n on n.oid=c.relnamespace
where n.nspname='public' and c.relkind='r' and c.relrowsecurity=false;
```

## Current Status

**Phase**: Codebase review remediation + worker deploy/settings audit + database/secret remediation + credential rotation — CR01–CR29, status table in [docs/BACKLOG.md](docs/BACKLOG.md)
**Last Updated**: 2026-08-03
**Test Status**: ✅ **1,212 worker tests** re-measured 2026-08-03 on the working tree (`lib` 515, contact-form 81, api-gateway 208, sender-worker 203, receiver-worker 33, stripe-webhook 172), and **3,017 Flutter** (2026-07-31). Counts in this file have gone stale by ~100 before — if you are reconciling one, run the suite rather than trusting the line. Coverage ~94%. `npm run lint:workers` **is** the worker linter (`tsc --noEmit` × the 6 packages; there is no ESLint under `workers/`, and plain `npm run lint` is `flutter analyze`) — zero errors as of 2026-08-03, and **that now includes every test file in all six packages**. `sender-worker` used to be the exception — its `tsconfig.json` excluded `src/**/*.test.ts`, `*.e2e.test.ts`, `*.live.test.ts` and `src/test-helpers/`, hiding **111 type errors** from the bare `tsc --noEmit` that `lint:workers` runs. Not cosmetic: making a field non-optional in `Env` silently invalidated every partial `Env` literal in those files with neither `tsc` nor `vitest` saying a word, which is how CR29 step 2 broke three fixtures. Fixed 2026-08-03 (111 → 0, tests still 203/203 + e2e 49/49); the `exclude` is gone and **must not come back**. Mutation-verified both ways: annotating one fixture `Record<string, unknown>` instead of `Env` now fails, and passes silently under the old exclude list. Two things the fix turned up, both measured rather than assumed: **explicit `import … from "node:fs"` does NOT resolve without `"node"` in the `types` array** — the `node:*` declarations live in `@types/node`, which only enters the program via that array — so `types` is now `["@cloudflare/workers-types", "node", "@cloudflare/vitest-pool-workers/types"]` (the last supplies `declare module "cloudflare:test"`). The cost is that `process`/`Buffer` are ambiently visible to the Worker source in `src/` too, where they do not exist at runtime without `nodejs_compat` — ambient globals are program-wide, so there is no way to scope them to tests within one `tsc` invocation. Don't use them in `src/`. And `vi.spyOn(global, …)` was 46 sites of a Node-only alias in a Workers package: `globalThis` is both the standard spelling and the one workerd actually has, and switching also let TS infer `fetch`'s real signature, clearing 38 implicit-any errors as a side effect. Opt-in suites: `sender-worker` `test:e2e` **49/49** (re-run 2026-08-03 on wrangler 4.118 — it boots workerd, so it is what actually exercises a wrangler bump rather than only type-checking against it), `test:live` 9 passed / 3 skipped and `stripe-webhook` `test:live` 5/5 (both 2026-07-29)
**Dependencies**: ✅ all six worker packages aligned 2026-08-03 — `wrangler ^4.118.0`, `@cloudflare/workers-types ^5.20260801.1`, `vitest` + `@vitest/coverage-v8 ^4.1.10`, `typescript ^5.9.3` — and `npm audit` is **0 in each** (was 8 in receiver-worker, 7 in contact-form, 2 each in lib and sender-worker). Audit and bump **per package**: these are not npm workspaces, so each carries its own lockfile and `node_modules`, and there is no root worker audit. Six things before editing a manifest:
- **`wrangler` ≥ 4.114 forces the `workers-types` v5 major.** It declares `peerOptional @cloudflare/workers-types@^5.20260730.1`, so pinning 4.x leaves a tree `npm update` tolerates but a clean `npm install` rejects with ERESOLVE. The wrangler bump is not optional either — the advisory range is **4.16.0–4.113.0**, and it transitively carries the esbuild dev-server file read, sharp/libvips, the seven-CVE undici cluster and both `ws` advisories.
- **Only the declared floors travel.** `.gitignore:53` is a bare `package-lock.json`, so it matches at every depth and no worker resolution is committed (line 54 re-includes `e2e/` only) — a fresh clone resolves from the ranges alone. Raising a floor after `npm update` **is** the fix, not bookkeeping — the old `^4.79.0` would have reinstalled a vulnerable wrangler.
- **`npm update` cannot reach a vendored nested copy.** `@cloudflare/vitest-pool-workers@0.14.x` ships its own `node_modules/wrangler` inside the advisory range, so `contact-form` still read 7 after the top-level bump; `^0.18.8` cleared it (the advisory range ends at 0.18.7).
- **All six declare `allowScripts`, deliberately UNPINNED.** npm 11 blocks dependency install scripts absent from that allowlist; no worker had the field, so every `npm install` warned (`esbuild`, `fsevents`, `workerd`). Added 2026-08-03 via `npm approve-scripts --all --no-allow-scripts-pin`; all six are quiet now. **Unpinned is the deliberate choice, and gitignored lockfiles are the reason** — npm's default writes `name@exact-version` keys, which `observability-toolkit` uses safely *because* it commits lockfiles, but here every clone re-resolves to whatever is newest, so pinned keys would go stale at once and warn in CI on every run. The tradeoff is real: an unpinned key approves all future versions of that package with no per-version review gate. Blocking was never breakage anyway — `workerd --version` and `esbuild --version` both ran in `sender-worker` while blocked, because those binaries come from platform-specific optional deps, not from `install.js`. Audit per package with `npm approve-scripts --allow-scripts-pending`.
  - It also exposed duplication worth knowing: `contact-form` and `sender-worker` — the two carrying `@cloudflare/vitest-pool-workers` — install **two** workerd copies each, `1.20260722.1` hoisted at `node_modules/workerd` and `1.20260730.1` nested at `node_modules/wrangler/node_modules/workerd`. The other three carry only `1.20260730.1`; `lib` has none. Same vendored-nesting hazard as the bullet above, and one more argument for unpinned — a single `workerd` key covers both copies where pinning needs two.
- **A widened range does not re-resolve, and a disjunction is how that hides.** Found in `observability-toolkit` 2026-08-03, recorded here because the mechanism is npm's, not that repo's: `@modelcontextprotocol/sdk` shipped its `@hono/node-server` fix by *adding* a disjunct (`^1.19.9` → `^1.19.9 || ^2.0.5`), so the already-installed 1.19.15 still satisfied the new range and stayed put — the bump cleared the SDK's own advisory while leaving the transitive one it was flagged through. `npm update` would not have reached it either; the top of the first branch, 1.19.17, is still inside the `<2.0.5` advisory. When upstream fixes by adding a disjunct, only an `overrides` entry (or a direct dep) moves you. **Here it is the mirror image of the floors rule above:** no worker lockfile is committed, so every install re-resolves to the maximum and this trap cannot bite — which is exactly why the declared floor is the only control there is. The disjunctions themselves are real in these trees (`vite: ^6 || ^7 || ^8` and `esbuild: ^0.27 || ^0.28` in all six).
- **`workers/lib` is on v5 deliberately even though it declares no wrangler.** All five workers import from it, so its source was already being compiled under v5 inside every consumer's program while its own `tsc` checked those same files under v4 — one set of files, two type environments.

**Database**: ✅ Supabase `cfrbahzzklwrnmbtqojl` is `ACTIVE_HEALTHY`; 10 migrations applied and `migration list` reports zero out of sync — the ledger previously claimed migrations that had never run, including the one creating `stripe-webhook`'s tables (CR17). RLS is enabled on every table in `public`
**Deployed**: ✅ all four production Workers redeployed from current source 2026-07-30, closing a four-month gap; all `200`/healthy afterwards, DO namespace intact, `preview_urls` still `false`, crons and service bindings intact, and — the one that mattered — **zone routes unchanged, `api.integritystudio.ai/*` still → `obtool-api`**, so CR13's trap did not fire. `api-gateway` returns `{"database":"healthy","durableObjects":"healthy"}` with three secrets bound — `SUPABASE_URL`, `SUPABASE_SERVICE_ROLE_KEY`, `STRIPE_SECRET_KEY`; `API_KEY_HMAC_SECRET` is still missing (CR12). **`SUPABASE_JWT_SECRET` is deliberately unbound, and its absence is correct rather than a regression:** `api-gateway` verifies **Auth0**-issued tokens against **Auth0** JWKS, so nothing read it. It is gone from the `Env` interface and the `wrangler.toml` secret list, and the shared `supabaseJwtKey`/`jwksUrlFor` helpers are `@deprecated`. **Do not re-bind it to "fix" a 401** — verifying an Auth0-issued token against *Supabase* JWKS is exactly what produced the original `401 Invalid JWT signature` (CR26). ~~The five `*-dev` workers are deliberately secret-less~~ **The dev workers hold DEV credentials since 2026-08-03** (CR11 step 4, after the isolation detector went green): `sender-worker-dev` 9, `api-gateway-dev` 4, `stripe-webhook-dev` 4 (incl. its sandbox Stripe pair) — all pointing at the dev Supabase project and dev Auth0 tenant, proven by a live dev signup that left production row counts untouched. `contact-form-dev` holds a fresh sending-scoped Resend key + CSRF secret since step 5 landed (dev recipients: developer inbox, `contact-dev@` sender), and `sender-worker-dev` deliberately lacks `SIGNING_KEYS`/`ACTIVE_KEY_ID`/`SHARED_SECRET` so `/send` fails closed while `RECEIVER` still binds the production receiver (CR02 item 5). No zone route points at any dev worker
**Stripe**: production account **`acct_1SN2e7AwEfePbhfk`**. Two endpoints, both pinned to `api_version=2025-09-30.clover` and subscribed to the five implemented events: test-mode `we_1Ty14zBWbFuvm1I6rvLOD5OW` → `stripe-webhook-dev`, live-mode `we_1Ty29dAwEfePbhfkky1OeqQu` → production `stripe-webhook` (signature verification proven with a wrong-secret control). `prd`'s `STRIPE_SECRET_KEY` holds an **`rk_live_` restricted key** (least privilege; the `sk_live_` is retained in Doppler history), bound to `api-gateway` and `sender-worker`. The live Customer Portal has a configuration (`bpc_1Ty2XDAwEfePbhfk9PndBNgW`), proven by creating a real session. **Stripe is the one credential family where `dev` really is isolated from `prd`** — `acct_1SN2eDBWbFuvm1I6` is a confirmed sandbox account, and `dev` holds only sandbox values. That is not true of Supabase or Auth0 (CR11). ⚠️ **Two different live `rk_live_` keys exist on the production account** (found 2026-07-29): `STRIPE_SECRET_KEY` ending `aHZC` and `STRIPE_API_KEY` ending `B6I8`, both returning 200 from `GET /v1/account`. Code reads **only** `STRIPE_SECRET_KEY`, so `…B6I8` is an unused live credential — revoke it in the Dashboard (Stripe exposes no key-management API), *then* clear the slot, not before, since the last-4 is how the Dashboard identifies it

**Deployment history: read it, don't infer it.** Binding a secret creates a deployment **without shipping code**, so timestamps alone lie — read them as "bindings changed" unless the version's source is `version_upload`. That is how `stripe-webhook` was caught running a 2026-03-31 build that could not write `webhook_events_log`. Version IDs recorded in docs go stale within a day; read the live value instead:
```bash
npx wrangler deployments list --name <worker>   # what shipped
npx wrangler secret list --name <worker>        # what is bound
```
**`wrangler secret list` cannot tell you *when* a binding changed — the versions API can.** Each version's detail carries `resources.bindings`, so diffing the **name** sets across versions reconstructs the whole bind/unbind history without ever reading a secret value (values are write-only; only names are returned). Two things this settled on 2026-07-31 that were otherwise guesswork: `SIGNING_KEYS`/`ACTIVE_KEY_ID` were provisioned at **2026-07-30T01:28Z**, not 2026-07-29 as `sender-worker/wrangler.toml` claimed (the stale date was local PDT — the API is UTC, so **record UTC**), which confirms CR01's 2026-07-29 `/send` verification really did exercise `SHARED_SECRET`; and CR15's four stale secrets really were deleted, at 2026-07-31T05:07Z. The two tools count different things — `secret list` returns secrets only, while `resources.bindings` also includes KV, service, and DO bindings, so one worker reads as 13 secrets or 15 bindings. Reconcile before concluding a count disagrees.
```bash
ACCT=$(doppler secrets get CLOUDFLARE_ACCOUNT_ID --project integrity-studio --config prd --plain)
TOKEN=$(doppler secrets get CLOUDFLARE_API_TOKEN --project integrity-studio --config prd --plain)
B=https://api.cloudflare.com/client/v4/accounts/$ACCT/workers/scripts/<worker>/versions
curl -s -H "Authorization: Bearer $TOKEN" "$B?per_page=100"   # ids + created_on + source
curl -s -H "Authorization: Bearer $TOKEN" "$B/<version-id>" \
  | python3 -c 'import json,sys; print(sorted(b["name"] for b in json.load(sys.stdin)["result"]["resources"]["bindings"]))'
```

⚠️ **`sender-worker` deploys via CI on merge to `main`, so anything unmerged is not live.** This branch is **9 commits ahead of `origin/main`**, three of which change worker behaviour: CR29 step 1 (`4bd0901`), `api-gateway`'s dead `[env.staging]` route claim (`25f02b7`), and `stripe-webhook`'s `active_subscription_id` write (`3d5906f`) — plus **CR29 step 2 uncommitted in the working tree** (`workers/sender-worker/`, `workers/receiver-worker/`). When the branch is far behind `origin/main`, the reverse hazard applies — pushing `main` deploys older code over what is live, a silent rollback.

**Not deployable.** `receiver-worker` is a local stub / test double, so `deploy:prd` would create a production Worker that nothing binds to and that returns mock responses. `bootstrap-worker` was deleted 2026-07-31 — `POST /bootstrap` is now a route on `api-gateway`, which closed CR26 without standing up a sixth Worker and needed no client release (verified live: **401**, not 404, so the route is mounted and auth-gated).

See [docs/changelog/1.3/CHANGELOG.md](docs/changelog/1.3/CHANGELOG.md) for recent changes, including what the 2026-07-30 deploys shipped.

### Known Issues
Status table in [docs/BACKLOG.md](docs/BACKLOG.md#code-review-2026-07-26--2026-07-27-cr01cr16), CR01–CR29. What remains open needs a credential decision, a spend decision, an answer about intent, or a production deploy.

**P1**
- **CR29**: 🔴 **the HMAC key rotation retires nothing — fixed in code 2026-08-02, and nothing is deployed, so every statement here is still true of production.** `SIGNING_KEYS`/`ACTIVE_KEY_ID=v2` is provisioned on both sides and works — but the live receiver resolves an **absent** `x-key-id` to the legacy `SHARED_SECRET`, a credential with no key id and therefore no rotation handle. Measured against production `POST /inbox` with controls: `v2` + key id → 200, `SHARED_SECRET` + **no** key id → **200**, garbage → 401. So removing a key from `SIGNING_KEYS` revokes nothing, CR01's HMAC rotation is incomplete, and anything holding `SHARED_SECRET` (incl. Doppler `dev`) can forge provisioning events by omitting one header.
  - **The order must not be reordered:** ~~caller audit~~ ✅ → ~~instrument the receiver~~ ✅ (`observability-toolkit` `8fcae0b`) → ~~sender fails closed~~ ✅ (`4bd0901`) → ~~receiver requires the header~~ ✅ (2026-08-02, both repos) → **deploy** → *then* unbind `SHARED_SECRET`. Unbinding early is an outage, not a fix. **Everything is committed and nothing is pushed, on purpose in both repos** — pushing the toolkit auto-deploys the receiver, merging this repo CI-deploys `sender-worker`, and neither has a staging gate. **Deploy the sender first:** the live receiver already accepts `v2`, so either order technically works, but the sender is the side that fails *loudly*, and receiver-first makes any unknown keyless caller start emitting 401s that look exactly like an attack. Confirm the receiver's `SIGNING_KEYS` holds every key id in use before it ships — after that deploy an unlisted key id is a 401 with nothing behind it.
  - **A green `/send` does not test this.** `resolveOutboundSigningKey` prefers `v2`, so the happy path never touches `SHARED_SECRET`. Sign `/inbox` directly, with `curl` and a positive control (Python `urllib` gets a blanket `403 1010` that mimics a signature failure — see CR14).
  - 🔴 **Step 3's gate metric changed, and the old one now reads as a false pass.** It was "`auth.verified_legacy_key` goes quiet in deployed traffic" — but step 2 **deleted the code path that emitted it**, so quiet is guaranteed by construction and proves nothing. The live gate is **`auth.key_unresolved` with `miss: "missing_key_id"` staying at zero**, the same question in the negative: not "did anything succeed keylessly" but "did anything get rejected for signing keylessly". Also emitted — `auth.verified` (info, with `keyId`) and `auth.invalid_signature` with `keySource`. Distinct event *names*, not a `source` field, because Sentry cannot search `extra` while the name becomes the `event_type` tag. Both 401s stay byte-identical, so neither key ids **nor whether a deployment has been migrated** can be probed by diffing responses.
  - **Sender fail-closed — three things before touching it.** All four misses now return 500 `SIGNING_KEY_UNRESOLVED` and forward nothing: `ACTIVE_KEY_ID` unset (step 2 — there is no longer a legacy path to fall back *to*), `SIGNING_KEYS` unset or malformed, or an unknown key id. Staging a new key now belongs on the **receiver**, which is the receiver-first order the runbook already requires. The load-bearing test assertion is **`expect(mockReceiverFetch).not.toHaveBeenCalled()`**, not the status code — a downgraded request is accepted by the *live* receiver as legacy-signed, so a regression returns 200/502 and a status-only test passes while testing nothing (mutation-verified twice: restoring the fallback fails 6 tests in step 1, 5 in step 2, one of them `expected 502 to be 500`, which is the proof the receiver really was reached). `handleSend`'s credential pre-flight is **deleted**, not rewritten: `forwardToReceiver` is the single authority, so there is one 500 whose code names the fault instead of two for one condition — and step 3's unbinding cannot become a `/send` outage, since nothing reads `SHARED_SECRET`. The `!env.RECEIVER` pre-flight stays.
  - **`SHARED_SECRET` is deliberately still bound in every fixture** (sender unit env, `vitest.e2e.config.mts`, the e2e receiver stub) and deliberately a *different* value from the active key, so "unreachable" is proven with the credential present rather than merely absent. Do not "tidy" it out before step 3.
  - **CI.** `observability-toolkit`'s e2e job was removed from `.github/workflows/publish.yml` (it signed production `/inbox` with `SHARED_SECRET` and no key id on every publish), making `sender-worker` the sole automated caller. **Do not provision `SIGNING_KEYS`/`ACTIVE_KEY_ID` into Doppler `dev` to restore it** — `dev` points at the *production* receiver, so that copies a production signing key into `dev`, re-creating CR11. `receiver-security.e2e.ts` is fixed rather than pending: it reads `ACTIVE_KEY_ID` + `resolveActiveSecret()`, no longer reads `SHARED_SECRET` at all, and has an `assertSignatureAccepted` positive control — without one, tests 2–3's `401 INVALID_SIGNATURE` is indistinguishable from a rejected key id and would pass while testing nothing. Seven unrelated specs still run nowhere, which is why the job should be restored rather than deleted. ⚠️ **The receiver auto-deploys** — `api-provisioning-receiver-test.yml` deploys production on every push to `main` touching `services/api-provisioning-receiver/**`.
  - **One toolkit path is type-checked by nothing** — `services/e2e/`, since the toolkit root's `include` is `['src/**/*']`. Its only checker is `eslint.config.cjs` (lines 181–190): `npx eslint --config eslint.config.cjs <file>`. That config runs **no type-aware rules**, so it passes on genuine type errors; a green eslint is not a type check. The receiver's two blind spots (`scripts/`, and its own `src/**/*.test.ts`) were **closed 2026-08-02** — its `tsconfig.json` is now `include: ["src/", "scripts/"]` with no `exclude`, the 68 hidden errors are fixed, and `npm run build` covers them. Do not re-add an `exclude` for tests.
  - **The test-helper trap this work turned on:** `function f(x = DEFAULT)` called as `f(undefined)` **uses DEFAULT**. Any helper meaning "omit this header" must take `null` as its sentinel, or it sends a *keyed* request while the test believes it sent a keyless one.
  - Confirmed out of scope: `obtool-ingest`'s evaluations endpoint is a separate HMAC scheme (`INJECT_HMAC_SECRET`, body-only, `sha256=` prefix).
- **CR11**: ✅ **credential isolation achieved 2026-08-03 — `npm run check:env-isolation` PASSES.** `--config dev` no longer reaches production: Supabase repointed to the dev project `tumhmtshahktumhqqamk` (dev key reads dev 200, refused by prod 401), Auth0 on the dev tenant `dev-njjmghdzm23uy0p7`, `SHARED_SECRET` re-rotated. ✅ **Runbook tail also done 2026-08-03:** dev secrets pushed to the `*-dev` workers (proven by a live `sender-worker-dev` signup — 201, dev DB 0/0→1/1, production untouched), dev DB seeded to reference parity, `contact-form-dev` armed (fresh sending-scoped Resend key; its old dev key was distinct-but-dead, 401), and the Playwright `contact-worker` spec repointed to dev (16/16). Only two things remain, neither isolation: scope the dev deploy token (owner/Dashboard) and restore the toolkit e2e suite (one hop behind CR02 item 5's dev receiver). ⚠️ **Historical, pre-2026-08-03:** Doppler `dev` shared the same Supabase **project** and Auth0 **tenant** as `prd`, so `--config dev` was not a safety boundary. Detector: `npm run check:env-isolation` — **5 of 13 failing, measured 2026-07-31** (10/10 → 3/13 on 2026-07-29, then regressed; it now covers 3 Stripe rows too). Longstanding: `SUPABASE_URL` + `SUPABASE_ANON_KEY` (one project) and `AUTH0_DOMAIN`. **Two newer rows, both traps.** `SHARED_SECRET` is byte-identical across the configs again, undone by something no doc records — diagnosed 2026-07-31 as `dev` being re-copied *from* `prd`, so re-rotating `dev` is safe, but it only un-shares the row and does not close the downgrade path (that is CR29). And `SUPABASE_SERVICE_ROLE_KEY` reads "UNSET in both" only because **the slot exists in neither config** — the detector is watching a name that is gone, masking the real finding: the live service key now lives in `SUPABASE_PROVISIONING_KEY`, is byte-identical in `dev` and `prd`, and **returns HTTP 200 against the production database**. So `--config dev` still grants full RLS bypass on production. Swapping the slot name in the detector's `SECRETS` is a prerequisite for trusting the count, though it will not lower it. ✅ **The Auth0 half is DONE (2026-08-03).** `dev-njjmghdzm23uy0p7` is now the dev tenant for real: M2M provisioned (all-scopes, dev `AUTH0_CLI_*`), resource server `https://api.integritystudio.dev` created (**it didn't exist** — every ROPC login would have 403'd "Service not found"), ROPC app + test user built, `default_directory` set so the plain `password` grant works with **no `AUTH0_REALM` code change** (proven by probe), and Doppler `dev`'s `AUTH0_DOMAIN`/`AUTH0_CLIENT_*`/`AUTH0_TEST_*` repointed. The production tenant's interim (`dev-users` connection, `integrity-dev-ropc`, `integrity-dev-m2m`) is **deleted, not disabled** — the two dev clients had been silently re-enabled on the production connection since 2026-07-29, and `integrity-dev-m2m` had acquired a `read:users delete:users` grant ("verified powerless" no longer true); deletion ends both. Production `/signin` verified after: 200 + JWT. The tenant **environment tag is not exposed via the Management API**, so Development/Production changes can only be confirmed in the Dashboard. **Two traps in the existing tenant:** creating any client auto-enables it on the production connection (`is_domain_connection: true` — re-check the client list after every creation), and `/signin`'s plain `password` grant resolves via the tenant-wide `default_directory`, so dev credentials authenticate nothing until the code passes a `realm`. 💰 **Unblocking CR11 costs $0 — re-audited against vendor terms 2026-08-02, and the "blocked on spend" framing was phantom.** The item had recorded itself as blocked on "whether to pay for a third Supabase project": the org holds **1** project of **2** free slots (Supabase counts free projects per *owner* across every org where you are Owner/Admin, and paused projects don't count) since `atx_movement` was deleted 2026-07-29, so the dev project is free — and `POST /v1/projects` already works with the `sbp_` token. The Auth0 half needs no tenant creation at all (above). **The pause problem is solved at $0** — `supabase-dev-keepalive.yml` pings the dev project's PostgREST Mon+Thu (publishable key hardcoded on purpose: anon-class keys are public by design and RLS is on everywhere; do not swap in a secret-class key). Inert until it reaches `main` — scheduled workflows run from the default branch only. Two isolation gaps CR11 never tracked became its steps 8–9, and **both were mis-stated; re-measured 2026-08-03.** Step 9 ("dev has no Stripe sandbox of its own") was already false when written — `dev` holds `sk_test_` keys on the confirmed sandbox account, which the detector scores `ok (test in dev, live in prd)`. Step 8 said `deploy` and `deploy:prd` "share one `CLOUDFLARE_WORKER_TOKEN`"; they do not share a token at all — see the deploy-split paragraph below for what was actually measured. The real step 8 is that dev's token is **distinct but account-wide in scope**, which is a blast-radius item, not an isolation one
- **CR01**: ⚠️ partial — `doppler.json` scrubbed from history and force-pushed 2026-07-29, Stripe / Auth0 / Supabase service keys / HMAC `SHARED_SECRET` all rotated and re-bound, and the Doppler configs swept of dead and duplicate slots (inventory in BACKLOG.md CR01 step 3). **A rotation is not a revocation** — the pre-rotation HMAC key is not retired by one, and neither is the current one by the next (CR29). **Remaining:** two Stripe Dashboard revocations (the old key and the unused `…B6I8`), a Dashboard-minted `sbp_` token for `SUPABASE_ACCESS_TOKEN` (CI's migration-drift job **skips** rather than fails as of 2026-07-31, so this enables real drift detection rather than clearing a red X), and revoking the `sbp_` token exposed in a session transcript. The on-disk `doppler.json` and `~/.doppler/fallback/` still hold pre-rotation material and should not be deleted yet
- **CR12**: ⚠️ partial — `api-gateway` and `stripe-webhook` both healthy, `STRIPE_SECRET_KEY` and `STRIPE_WEBHOOK_SECRET` bound. Still missing `API_KEY_HMAC_SECRET` (canonical value lives in `observability-toolkit`; API-key auth routes are broken until it is bound)
- **CR18**: ⚠️ mostly resolved — `prd`'s `STRIPE_SECRET_KEY` now holds a live `rk_live_` key and is bound, so server-side Stripe calls work. `dev` and `prd` are two different accounts *by design* (sandbox vs live), which is the isolation exception noted above. What remains is the Dashboard revocation of the unused `…B6I8` key
- **CR14**: ⚠️ partial — preview URLs publish every superseded version's bindings. **Every exposure this repo controls is closed** (2026-07-29): all four production Workers at `previews_enabled: false`, and the **71 superseded versions** that had been serving — 63 `sender-worker` back to 2026-03-29, 8 `contact-form` back to 2026-01-17 — now return `404`. **Still exposed:** cross-repo `api-provisioning-receiver` (**9** secrets, including both credentials CR01 rotated plus `SIGNING_KEYS`, so its retained versions publish the *current* values — 30 of 30 code versions reachable, oldest 2026-03-20) and `stripe-webhook-dev` (2 sandbox, closes on its next dev deploy). Four things worth keeping: **superseded versions do not age out** — a `404` means the version came from `wrangler secret put`, which gets no preview URL, so the earlier "past retention" reading was wrong; the mitigation POST **must include `"enabled":true`**, or it takes the Worker's `workers.dev` hostname down, which is the only way the shipped Flutter app reaches `sender-worker` and `integrity-studio-contact`; it propagates over seconds, so sample more than once (one sweep showed 42 of 63 closed, the next all 63); and two probe traps that both understate exposure — workers.dev returns a blanket `403` to `Python-urllib` where `curl` gets the true code, and reachability is "anything but `404`", since `403`/`405`/`500` all mean the Worker ran. Read the binding *list*, not the total: the earlier "10 secrets" figure came from counting `SIGNING_KEYS` as an addition without noticing `SUPABASE_SERVICE_ROLE_KEY` had been dropped

**P2**
- **CR20**: 🔴 `stripe-webhook`'s cron is now the **only** retry path — CR21 returns 2xx before processing via `ctx.waitUntil`, foreclosing the 5xx option — and it is unmonitored. W04 alerting is mandatory
- **CR13**: ⚠️ partial — step 1 done (the `routes` key is gone from `workers/api-gateway/wrangler.toml`) and **proven in practice 2026-07-30**: a real `deploy:prd` ran and the zone routes were unchanged afterwards, so `deploy:prd` will not capture `obtool-api`'s traffic. The four months of undeployed fixes have shipped. The hostname-topology decision — what URL customers should use — is still open (BACKLOG.md CR13 steps 3–5)
- **CR25**: ⚠️ partial — Auth0 tenant production-readiness, before flipping `dev-68gg87ow4mg4kzyo` from Development to Production. **Fixed:** the `google-oauth2` connection ran on Auth0's shared **development keys** while enabled on 6 apps (0 users used it) — now disabled for every app, connection kept so it is one PATCH to restore once real Google credentials exist. **Partial:** TOTP + recovery-code factors enabled, so MFA *can* be enrolled, but no enforcement policy — that would force all 96 users to enrol and needs a decision. **Blocked on spend:** breached-password detection returns `400 "upgrade your subscription"`, joining the custom domain as a paid feature. Also open: `implicit` grant on 4 apps incl. the dashboard SPA (same URL-fragment mechanism as CR04), ROPC on the Management M2M, unbranded Universal Login, no log streams, 24h API tokens
- **CR04**: JWT still passed to the dashboard in a URL fragment — cross-repo fix needed
- **CR02**: ✅ mostly closed — `npm run deploy` targets `--env dev`, verified live. Only the dev receiver remains, and CR29's resolution took it off that critical path

**P3**
- **CR22**: ⚠️ deployed 2026-07-30, still unexercised — the 403 path needs a *valid* API key that fails only the type check, and API-key auth is unreachable while `API_KEY_HMAC_SECRET` is unbound (CR12). An invalid key returns `401 Invalid JWT format`, which is CR23's design decision, not a regression
- **CR16**: 📋 by design, not a defect. `obtool-ingest` (→ R2+D1) is Integrity Studio's **internal** OTEL pipeline; `api-gateway`'s `/v1/ingest/otel` (→ Supabase) is the **customer-facing** one. **Do not de-duplicate these.** Folding obtool-ingest into api-gateway is an eventual goal, explicitly not current priority
- **Closed** (detail in BACKLOG.md): CR03 (KV rate-limit namespaces, live since 2026-07-30), CR15 (observability had been silently off in production for ~4 months; four stale `sender-worker` secrets deleted 2026-07-31T05:07Z, 16 → 12), CR17 (ledger repaired, `migration-drift-check` CI job added), CR19 (out-of-order events → dead-letter), CR21 (`ctx.waitUntil`, live 2026-07-30), CR24 (legacy Supabase `anon` + `service_role` JWT keys disabled, both verified 401 — reversible via the same endpoint, but **never re-enable**: those JWTs are disclosed material), CR26, CR27, CR28

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
test/                 # Unit + widget tests (~94% coverage; count in Current Status)
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
  - **Forwarded to receiver:** `/send` events (`provision_api_key`, `sign_in`) are HMAC-SHA256-signed and forwarded to the production receiver `api-provisioning-receiver` via the `[[services]]` binding. API-key minting happens on the receiver, not here. The signing key is resolved by `resolveOutboundSigningKey`, which **fails closed on all four misses** — `SIGNING_KEYS` + `ACTIVE_KEY_ID` are the only credential, `x-key-id` is sent unconditionally, and `SHARED_SECRET` is read by nothing. See CR29 above before changing any of that.
  - **`/create-checkout-session` derives the org server-side from the email — never accept an `orgId` from the caller.** `stripe-webhook` reads `session.metadata.org_id || session.client_reference_id` to run `linkStripeCustomer` (`workers/stripe-webhook/src/handlers/checkout.ts:24`); with neither set it warns and bails, which is why no subscription linked to an org before 2026-07-31. The org therefore has to reach Stripe somehow — but **adding `orgId` to `CreateCheckoutSessionSchema` would be a vulnerability**: this route is origin-gated and *unauthenticated*, so a client-supplied org id lets any caller attach a subscription to an org they do not own. The origin gate is not a boundary here either — `isOriginAllowed` is a browser-surface control only, and origin-less callers (Flutter native, curl) bypass it by design. `supabaseFindOrgIdByEmail` resolves it instead (prefer `default_organization_id`, else oldest active membership — mirroring `custom_access_token_hook`), needing no change from the landing page or Flutter client. Resolution is **best-effort by design**: an unknown email or a failed lookup logs and proceeds with an unattributed session, because failing checkout to protect a metadata field trades a linking bug for a revenue bug.

    ⚠️ **This route is only correct for single-org users, and that limit was not stated when it was written** (found 2026-07-31). `supabaseFindOrgIdByEmail` resolves an *identity* to an org, so for anyone holding several memberships it silently returns their default org rather than the one being paid for. A real case: `alyshia@inventoryai.io` owns three orgs and the `default_organization_id` already carried a paid subscription — so upgrading a *different* org through this route would have attached the new Stripe customer to the org that was already paying and left the intended one showing no billing account. **Use it only for the signup flow, where the user has exactly one org and no session yet.** Anywhere the caller is authenticated and the org is known, use **`POST /v1/orgs/:id/checkout-session`** on `api-gateway`, which takes the org from a membership-checked route parameter. That does not contradict the rule above — the org id still never comes from the request body; it comes from a path the caller has been authorized against.
  - **Gotcha — mock by URL, not by call order, in `index.test.ts`.** `handleCreateCheckoutSession` makes a Supabase lookup *before* the Stripe call, so `mockResolvedValueOnce`/`mockRejectedValueOnce` bind to the lookup and the Stripe branch under test never runs. Three existing tests broke this way, and two lived in a sibling `describe` that a `-t`-filtered run did not touch — they only surfaced on the full suite. Route on `url.includes('/rest/v1/')` instead.
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

The top-level block of each `wrangler.toml` **is** the production config; `[env.dev]` is the dev overlay. Three consequences worth knowing before editing one:
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

**✅ Doppler `dev` is now data-isolated from `prd` (2026-08-03) — `npm run check:env-isolation` PASSES.** `--config dev` reaches a separate Supabase project (`tumhmtshahktumhqqamk`) and a separate Auth0 tenant (`dev-njjmghdzm23uy0p7`); the dev provisioning key is refused by production (401). Stripe was already isolated (separate sandbox account). ✅ **And the dev workers are now armed with those dev credentials (2026-08-03), proven by a live signup**: `POST /signup` on `sender-worker-dev` → 201 with a dev-tenant JWT, dev DB 0/0 → 1/1, production row counts unchanged. Holdings: `sender-worker-dev` 9 secrets, `api-gateway-dev` 4, `stripe-webhook-dev` 4. **Deliberately withheld:** `SIGNING_KEYS`/`ACTIVE_KEY_ID`/`SHARED_SECRET` from `sender-worker-dev` — its `RECEIVER` still binds the **production** receiver, so dev `/send` must fail closed until a dev receiver exists (CR02 item 5); and `contact-form-dev` is armed since CR11 step 5 landed: dev-safe recipients (`alyshialedlie@gmail.com` ← `contact-dev@integritystudio.ai`), a freshly minted sending-scoped Resend key (dev's old one was distinct but **dead** — 401), fresh `CSRF_SECRET`; proven by a live 200 submission. The Playwright `contact-worker` spec defaults to this dev worker now. Worker-secret names differ from Doppler slots: `SUPABASE_SERVICE_ROLE_KEY` ← `SUPABASE_PROVISIONING_KEY`, `AUTH0_AUDIENCE` ← `AUTH0_CLIENT_AUDIENCE`. The dev DB has exactly the rows dev tests create — seeding beyond that is still open. Never push `prd` values into a `*-dev` worker. Tracked as BACKLOG.md CR11. *(Historical: before 2026-08-03 both configs shared one Supabase project and Auth0 tenant, so `--config dev` was not a safety boundary.)*

⚠️ **The dev/prod deploy split is a config-layer guarantee — but the credential claim that used to sit here was wrong three ways** (measured 2026-08-03). It read "`deploy` and `deploy:prd` both authenticate with the same `CLOUDFLARE_WORKER_TOKEN` from Doppler `prd`". Wrong slot, wrong config, wrong conclusion: `wrangler` authenticates with **`CLOUDFLARE_API_TOKEN`**, `npm run deploy` injects it from Doppler **`dev`** (`doppler run --config dev`) and `deploy:prd` from **`prd`**, and those two values are **distinct** — dev is an account-wide `cfat_` token, prd sha `25889310adec`. ⚠️ The dev token was rotated 2026-08-03 (was `abb57cc474cb`, now `15680a6f90a5`); fingerprint before acting. The byte-identical slot really is `CLOUDFLARE_WORKER_TOKEN` (sha `1243e82a0ae8` in both configs), but **no code in this repo reads it**; its only three readers are `observability-toolkit` workflows, all passing `--config prd`. Same class of error as `SUPABASE_SERVICE_ROLE_KEY` above — a doc watching a name that is not the one in play, which is why the fingerprint recipe exists.

**What is still open is scope, not sharing — and distinctness is not scope.** Dev's token is a distinct credential that is not dev-*scoped*: it lists **all 18 Worker scripts in the account**, production `api-gateway` / `sender-worker` / `stripe-webhook` / `obtool-api` / `api-provisioning-receiver` included. `Edit` was not probed, because the probe is a write — but Cloudflare scopes the Workers Scripts permission to the **account**, not to individual scripts, so an `Edit`-carrying token reaches any of them. It is narrower than a global key (`GET /user/tokens` → `Unauthorized`). So what stops `npm run deploy` hitting production is still `--env dev` in the script plus `workers/lib/deploy-environments.test.ts` asserting it. **Separate accounts with wrangler profiles pinned per directory remain the only structural fix**; a dev-scoped token narrows blast radius and yields an independently revocable credential, but it cannot make production unreachable. BACKLOG.md CR11 step 8 / CR02 step 8.

**Environment isolation is free on every vendor here — verified 2026-08-02, not assumed.** Supabase: 2 free projects per owner across all orgs, paused ones uncounted. Auth0: dev/staging tenants link to one subscription with usage aggregated, so a ~0-MAU dev tenant adds no charge (and one already exists here). Stripe: sandboxes are the recommended default and each environment should get its own — `stripe-webhook-dev` already does this and is the model. **`dev` must never receive a copy of a `*_live_` key, restricted or not** — the `rk_live_` in `prd` is correct least-privilege practice, which is exactly what makes copying it the tempting mistake.

**Also not isolated:** `sender-worker-dev` binds `RECEIVER` to the production `api-provisioning-receiver`, because no dev receiver is deployed (it lives in the `observability-toolkit` repo). Tracked as CR02 item 5.

#### Doppler Configuration
- **Project**: `integrity-studio`
- **Dev Config** (`--config dev`): ✅ **a separate environment as of 2026-08-03** — its own Supabase project (`tumhmtshahktumhqqamk`), its own Auth0 tenant (`dev-njjmghdzm23uy0p7`), its own HMAC secret and its own Stripe sandbox. `npm run check:env-isolation` **PASSES** (exit 0; 15 credentials distinct, 2 Stripe keys test-mode in dev / live in prd). Two caveats that are *not* credential isolation: `sender-worker-dev`'s `RECEIVER` still binds the **production** receiver (CR02 item 5), and the deploy token is distinct but account-wide in scope (CR11 step 8). Re-run the detector rather than trusting this line
- **Prd Config** (`--config prd`): Production deployments, secret rotation, sensitive operations
- **Stg Config**: exists but is **empty** — every credential is unset

Worker runtime secrets are **not** supplied by Doppler. `wrangler deploy` does not turn ambient env vars into Worker secrets; those are set per worker with `wrangler secret put`. Doppler's role at deploy time is to provide `CLOUDFLARE_API_TOKEN`. Check what a worker actually has bound with:
```bash
npx wrangler secret list --name <worker>          # or --env dev
```

**Read Doppler values with `doppler secrets get --plain`, not `doppler run`.** On 2026-07-27 a `doppler run --config prd` reported a value that `doppler secrets get --config prd --plain` contradicted, and the upstream API confirmed the latter — `~/.doppler/fallback/` caches credential snapshots, so a stale one can be served silently. Two traps compound it: `sh -c 'echo -n "$V"'` prints the literal `-n ` (POSIX `sh`, not bash) and corrupts any prefix check — use `printf '%s'` — and a prefix alone is weak evidence. Fingerprint instead, which never prints secret material:
```bash
v=$(doppler secrets get NAME --project integrity-studio --config prd --plain | tr -d '\n')
printf 'len=%s sha=%s\n' "${#v}" "$(printf '%s' "$v" | shasum | cut -c1-12)"
```
When binding a secret to a Worker, pipe that captured value into `wrangler secret put` rather than letting `doppler run` inject it.

**Sample twice before concluding a binding is bad — Cloudflare rolls a new version out over seconds, not instantly.** On 2026-07-31, immediately after `wrangler secret put STRIPE_PLAN_TO_PRICE_JSON` + `deploy:prd`, a probe with `tier=growth` returned `200` while the very next probe with `tier=starter` returned `no Stripe price configured` — from the *same* secret, whose Doppler value was byte-correct throughout (86 bytes, both keys, verified by dumping it to a file and `JSON.parse`-ing). Different edge nodes were simply on either side of the rollout; a minute later all tiers behaved. The obvious-but-wrong read is "the value was written wrong", which sends you re-`put`ting a secret that was already fine. Same caveat as CR14's `preview_urls` sweep — treat it as a general property of Cloudflare config propagation, not a quirk of one endpoint. Re-probe before diagnosing, and prefer a loop over a single shot.

#### Worker Deployment Overview

| Worker | Purpose | Production Worker | Dev Worker (`--env dev`) | CI/CD |
|--------|---------|-------------------|--------------------------|-------|
| **sender-worker** | Inline signup/signin (Auth0+Supabase); HMAC-signs `/send` events to receiver | `sender-worker` | `sender-worker-dev` | ✓ Yes (main) |
| **api-provisioning-receiver** | Verifies signed requests, persists to Supabase (production receiver) | `api-provisioning-receiver` | — (separate repo) | ✓ Yes (separate repo) |
| **stripe-webhook** | Handles Stripe subscription events | `stripe-webhook` | `stripe-webhook-dev` (no cron) | — |
| **contact-form** | Processes contact form (Resend, KV rate limit) | `integrity-studio-contact` | `integrity-studio-contact-dev` (no KV) | — |
| **api-gateway** | API gateway (aggregation, quota), plus `POST /bootstrap` | `api-gateway` | `api-gateway-dev` (own DO namespace) | — |
| **receiver-worker** | Local stub / test double — not deployed | — | — (`[env.dev]` names `receiver-worker-dev`, never deployed) | — |

`bootstrap-worker` was removed 2026-07-31 (CR26); a `bootstrap-worker-dev` Worker may still linger in the account with zero secrets bound.

**Note:** `sender-worker` reaches the receiver via a service binding — `service = "api-provisioning-receiver"` in `workers/sender-worker/wrangler.toml` (the source of truth). The production receiver lives in the separate `observability-toolkit` repo (`services/api-provisioning-receiver/`) and is deployed from there.

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
- ✅ **E2E tests use `--config dev`, and `dev` is isolated from prod as of 2026-08-03** — separate Supabase project, separate Auth0 tenant, separate Stripe sandbox. Verify with `npm run check:env-isolation` (**PASSES**, exit 0). What remains under CR11 is not credential isolation: seeding the dev DB, pointing the e2e suite at dev, `contact-form-dev` (its `[env.dev.vars]` still carry the real business inbox), and scoping the deploy token
- ✅ No hardcoded secrets in package.json or workflows
- ⚠️ `doppler.json` scrubbed from git history (2026-07-29), and most credentials rotated — but **rotated is not revoked**: the on-disk `doppler.json` and `~/.doppler/fallback/` still hold pre-rotation material, and the HMAC rotation retires nothing in *deployed* code (BACKLOG.md CR01, CR29 — the fix is written and unpushed)

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

**Prd secrets** are rotated on a schedule. Read values with `doppler secrets get --project integrity-studio --config prd --plain` and fingerprint them (recipe above), then bind with `wrangler secret put` — **not** with `doppler run`, which has served a stale cached value. `doppler run` remains the right way to *inject* `CLOUDFLARE_API_TOKEN` into a deploy; the prohibition is on reading a value back through it. And a rotation is not a revocation: the superseded credential stays live until it is explicitly deleted at the provider.

See `.github/workflows/ci.yml` for the current production deployment configuration and secret injection.
