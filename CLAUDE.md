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

# Opt-in suites (excluded from `npm test`; skip cleanly without credentials)
npm run test:live                 # stripe-webhook: real Stripe-signed requests to the deployed dev Worker
                                  # sender-worker: real Auth0 Management API calls
npm run test:e2e                  # sender-worker: workerd runtime with mocked outbound calls
```

**Supabase** (migrations are the source of truth for schema)
```bash
export SUPABASE_ACCESS_TOKEN=$(doppler secrets get SUPABASE_ACCESS_TOKEN --project integrity-studio --config prd --plain)
export SUPABASE_DB_PASSWORD=$(doppler secrets get SUPABASE_DB_PASSWORD --project integrity-studio --config prd --plain)
supabase migration list --linked   # local vs remote; any blank `remote` column is pending
supabase db push --dry-run         # preview; add --include-all if a file sorts before the last applied version
supabase db push                   # apply
```
Two hard-won rules. **`create policy if not exists` is invalid PostgreSQL** — there is no `IF NOT EXISTS` for `CREATE POLICY`; use `drop policy if exists` then `create policy`. And **`migration repair --status applied` writes a ledger row without executing the SQL**, which is how two migrations came to be recorded as applied while their tables did not exist (BACKLOG.md CR17). Treat it as a last resort, never as a way past a failing push.

**RLS is not optional for privacy.** PostgREST exposes every table in the `public` schema, so a table with RLS off is readable with the *publishable* anon key regardless of which key your workers use. Enabling RLS with **zero policies** denies anon and authenticated while `service_role` bypasses it — that is the correct posture for server-only tables. Verify with the catalog, not a status code: RLS denial returns `200 []`, not an error.
```bash
# any table here is publicly readable
select relname from pg_class c join pg_namespace n on n.oid=c.relnamespace
where n.nspname='public' and c.relkind='r' and c.relrowsecurity=false;
```

## Current Status

**Phase**: Codebase review remediation + worker deploy/settings audit + database/secret remediation — CR01–CR24 tracked, see the status table in [docs/BACKLOG.md](docs/BACKLOG.md)
**Last Updated**: 2026-07-29
**Build Status**: ✅ Web build successful, running on localhost:8080
**Test Status**: ✅ 3,001 Flutter tests passing (~94% coverage); 1,039 worker tests passing (6 workers + shared lib); zero TypeScript errors; `flutter analyze` clean. Plus 5 opt-in live signature tests — `cd workers/stripe-webhook && npm run test:live` (excluded from `npm test`; skips cleanly without credentials)
**Database**: ✅ Supabase `cfrbahzzklwrnmbtqojl` is `ACTIVE_HEALTHY`; 10 migrations applied and `supabase migration list` reports zero out of sync. The ledger previously claimed migrations that had never run (CR17) — including the one creating `stripe-webhook`'s tables. RLS is now enabled on every table in `public`.
**Deployed**: production `sender-worker` + `integrity-studio-contact` healthy. **`api-gateway` is healthy** — `200 {"database":"healthy"}` since 2026-07-27, with `SUPABASE_URL` / `SUPABASE_SERVICE_ROLE_KEY` / `SUPABASE_JWT_SECRET` bound (CR12 partial). **`stripe-webhook` is fully wired as of 2026-07-28** — Supabase pair plus `STRIPE_WEBHOOK_SECRET`, and redeployed from current source. Its production code had been stuck at 2026-03-31 and could not write `webhook_events_log`; a signed probe now returns `{"ok":true,"processed":true}` and a replay returns `already_processed`. Five `*-dev` workers are deliberately secret-less (CR11) except `stripe-webhook-dev`, which holds a sandbox `STRIPE_API_KEY` + `STRIPE_WEBHOOK_SECRET` for live signature testing. No zone route points at any dev worker.
**Stripe**: production account is **`acct_1SN2e7AwEfePbhfk`**. Two endpoints, both pinned to `api_version=2025-09-30.clover` and subscribed to the five implemented events: test-mode `we_1Ty14zBWbFuvm1I6rvLOD5OW` → `stripe-webhook-dev`, and **live-mode `we_1Ty29dAwEfePbhfkky1OeqQu` → production `stripe-webhook`** (registered 2026-07-28, signature verification proven with a wrong-secret control). `prd`'s `STRIPE_SECRET_KEY` holds an **`rk_live_` restricted key** (least privilege; the `sk_live_` is retained in Doppler history) — bound to `api-gateway` and `sender-worker` on 2026-07-28 (`sender-worker` verified reading it — checkout now reaches validation instead of `"Stripe not configured"`). `api-gateway`'s billing portal is unblocked as of 2026-07-28 — the live Customer Portal now has a configuration (`bpc_1Ty2XDAwEfePbhfk9PndBNgW`), and a real session was created against it to prove the call works. The route itself is still unexercised because it needs a JWT. Doppler `dev` now holds only sandbox Stripe values — `STRIPE_SECRET_KEY` was a `pk_live_` publishable key on the *production* account until 2026-07-28 and is now the sandbox `sk_test_`. **Stripe is the one credential family where `dev` really is isolated from `prd`**: `acct_1SN2eDBWbFuvm1I6` is confirmed as "Integrity Studio sandbox". That is not true of Supabase or Auth0 — see CR11. See CR18.
**Pending a `deploy:prd`** — committed but not live: CR03's `RATE_LIMIT_KV` binding and observability (CR15 + W04 step 1) on the five workers other than `stripe-webhook`, which was deployed 2026-07-28. CR14's `preview_urls` is already live on `api-gateway` and `stripe-webhook` via the API. CI deploys `sender-worker` on merge to `main`; other workers are manual.

⚠️ **Deployed code is not this repo's code, and the gap is measured in months.** Check before assuming a Worker behaves like `main`:

| Worker | Last **code** deploy | How it updates |
|---|---|---|
| `stripe-webhook` | **2026-07-28** ✅ current | manual |
| `sender-worker` | 2026-07-26 04:08 | CI on merge to `main` |
| `api-gateway` | **2026-03-31** | manual — **blocked by CR13** |

Deployment history is misleading here: `api-gateway` shows three 2026-07-28 02:36 entries and one at 04:18, but those are `wrangler secret put` calls. Binding a secret creates a deployment **without shipping code**. Read the timestamps as "bindings changed", not "code shipped". `stripe-webhook` was found this way — its 2026-03-31 build could not write `webhook_events_log`, which only became visible once a signed request could reach the handler.

None of the ~20 unpushed commits on `fix/review-supabase-writes-and-signup-tiers` are deployed anywhere, including `d9ba71a` (verify bearer token before quota enforcement) and CR22's billing-portal fix — both `api-gateway`, both blocked behind CR13 step 1.

See [docs/changelog/1.3/CHANGELOG.md](docs/changelog/1.3/CHANGELOG.md) for recent changes.

### Known Issues
Tracked with a status table in [docs/BACKLOG.md](docs/BACKLOG.md#code-review-2026-07-26--2026-07-27-cr01cr16), now CR01–CR24. **CR17 and CR19 closed 2026-07-28**; CR18 and CR12 went from blocking to mostly-resolved once a live Stripe key was minted. What remains needs a credential decision, an answer about intent, or a production deploy.

**CR13 step 1 is done (2026-07-29)** — the `routes` key has been removed from `workers/api-gateway/wrangler.toml`. `deploy:prd` is now safe to run and will not capture `obtool-api`'s traffic. Four months of undeployed fixes (`d9ba71a` bearer-token auth check, CR22 billing-portal 403) can now ship. The hostname-topology decision (what URL customers should use) is still open — see BACKLOG.md CR13 steps 3–5.

**P1**
- **CR18**: **two different Stripe accounts** — `prd` holds a `pk_live_` *publishable* key, `dev` an `sk_test_` secret key. `STRIPE_SECRET_KEY` (what the code reads) is empty everywhere, so **no worker can make a server-side Stripe call**. Stripe has no API to create secret keys; this needs one Dashboard action plus a decision about which account is production
- **CR01**: ⚠️ partial — history scrubbed + force-pushed 2026-07-29. Stripe rotated + re-bound (old key still needs Dashboard revocation). Supabase: **legacy `anon` + `service_role` JWT keys disabled and verified dead** (CR24 closed); workers' bound `sb_secret_` keys unaffected and healthy. **Doppler slot cleanup done 2026-07-29** — all six anon slots now hold the live `sb_publishable_` key; `SUPABASE_JWT_SECRET`'s real value was found in Doppler `dev` (it HMAC-verifies the project's own legacy JWTs), copied to `prd` and cleared from `dev`, and `api-gateway`'s existing binding was proven already correct via `/v1/me` (real-secret token → 404 user lookup, UUID-signed → 401); the stray `sb_secret_bgU_b` "default" key was revoked; the duplicate `SUPABASE_SERVICE_KEY` slot was deleted; and `SUPABASE_ACCESS_TOKEN` was emptied because a garbage value *overrides* the CLI keychain (a real `sbp_` token can only be minted in the Dashboard — the Management API 404s). Auth0: both `AUTH0_CLI_SECRET` and `AUTH0_CLIENT_SECRET` rotated, validated, and re-bound (ROPC fixed via Management API `rotate-secret`; live `/signin` verified 200 + JWT). HMAC `SHARED_SECRET` rotated on both sender and receiver, verified by a live `/send` round-trip. `sb_secret_` service keys swapped to the new `integrity_provisioning_key` on all four workers and the old key revoked + verified dead. Also swept the wider Doppler config: cleared two `AUTHO_*` slots (typo — letter O) holding Auth0 management bearer tokens **expired 241 and 125 days**, one from a different tenant, plus two dead pre-rotation M2M secret copies (`prd AUTH0_SECRET`, `dev AUTH0_CLI_SECRET`). `check:env-isolation` went from 10/10 failures to **7 of 13**. Two live-credential findings came out of it: **`SUPABASE_DB_PASSWORD` is the same string as the live `sb_secret_` key** — it really does authenticate to Postgres, so do *not* "clean up" that slot; reset the password in the Dashboard to decouple — and **two different live `rk_live_` Stripe keys** exist on the production account, of which code reads only `STRIPE_SECRET_KEY`. Remaining: Stripe Dashboard revocations (old key + the unused `…B6I8`), a Dashboard-minted `sbp_` token for `SUPABASE_ACCESS_TOKEN` (CI's migration-drift job is broken until then), and revoking the `sbp_` token exposed in a session transcript. Full state: BACKLOG.md CR01 step 3
- **CR11**: Doppler `dev` still shares the same Supabase **project** and Auth0 **tenant** as `prd`, so `--config dev` is not a safety boundary. Detector: `npm run check:env-isolation` — **3 of 13 failing** as of 2026-07-29 (was 10/10; it now covers 3 Stripe rows too). Remaining: `SUPABASE_URL` + `SUPABASE_ANON_KEY` (one project) and `AUTH0_DOMAIN` (one tenant, **Dashboard-only** — tenant creation has no API endpoint and the M2M token lacks `create:tenants`, so 2 of 3 is the API floor). Auth0 now has a `dev-users` connection plus dev-only ROPC/M2M clients, proven by probe to authenticate no production user. **Two traps recorded there:** creating any client in this tenant auto-enables it on the production connection (`is_domain_connection: true` — re-check the client list after every creation), and `/signin`'s plain `password` grant resolves via the tenant-wide `default_directory`, so dev credentials authenticate nothing until the code passes a `realm`. See BACKLOG.md CR11
- **CR12**: ⚠️ partial — `api-gateway` and `stripe-webhook` both healthy; `STRIPE_SECRET_KEY` and `STRIPE_WEBHOOK_SECRET` bound 2026-07-28. Still missing `API_KEY_HMAC_SECRET` (canonical value lives in `observability-toolkit`; API-key auth routes are broken until it is bound)
- **CR14**: ⚠️ partial — closed on `api-gateway` + `stripe-webhook`. **Still exposed:** `sender-worker` (13 secrets), `integrity-studio-contact`, and cross-repo `api-provisioning-receiver` (7)

**P2**
- **CR20**: 🔴 `stripe-webhook` cron is now the **only** retry path (CR21 returns 2xx before processing via `ctx.waitUntil`, foreclosing the 5xx option). The cron is unmonitored — W04 alerting is mandatory
- **CR17**: ✅ done — migration ledger repaired; `scripts/check-migration-drift.sh` + `migration-drift-check` CI job added
- **CR13**: ⚠️ partial — step 1 done 2026-07-29 (routes key removed, `deploy:prd` now safe). Topology decision (how to give gateway a real hostname) still open
- **CR19**: ✅ done — out-of-order events now route to dead-letter (commits eaaa199, 9741594)
- **CR04**: JWT still passed to the dashboard in a URL fragment — cross-repo fix needed
- **CR02**: ✅ mostly closed — `npm run deploy` targets `--env dev`, verified live. Only the dev receiver remains
- **CR03**: ✅ done — KV namespaces created and bound; live in production on the next `deploy:prd`

**P3**
- **CR15**: observability fixed in config (was silently off in production for ~4 months) but **not deployed**; **four** stale secrets still bound to production `sender-worker` — `RECEIVER_WORKER_URL`, `PROVISIONING_RECEIVER_WORKER_URL`, `AUTH0_CLI_AUDIENCE`, `SUPABASE_ANON_KEY`
- **CR21**: ✅ done — `stripe-webhook` now returns 2xx immediately via `ctx.waitUntil` (commit 8de2122)
- **CR22**: 🔴 billing-portal API-key 403 merged + tested; `api-gateway` deploy now unblocked (CR13 step 1 done) — needs `deploy:prd`
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

**⚠️ Dev workers are NOT data-isolated.** Doppler's `dev` and `prd` configs share the same Supabase **project** and Auth0 **tenant** (`npm run check:env-isolation` reports which — 6 of 13 rows as of 2026-07-29, down from 10/10; the HMAC `SHARED_SECRET` and the Supabase service/JWT credentials are now distinct, but a shared project and tenant mean distinctness alone isolates nothing). Selecting `--config dev` therefore changes nothing about which database or Auth0 tenant is used. Stripe is *not* affected, but not for the reason previously stated here (corrected 2026-07-27): `prd`'s `STRIPE_API_KEY` is a **`pk_live_` publishable key** and `dev`'s is an `sk_test_` secret key, belonging to **two different Stripe accounts**. A publishable key is public by design, so there is no exposure — but `STRIPE_SECRET_KEY`, the name the code actually reads, is empty in all three configs, so no worker can make a server-side Stripe call at all. `check:env-isolation` compares no Stripe credential. See BACKLOG.md CR18. The dev workers were deliberately deployed **without secrets** so they cannot reach production data; that is why they return errors on any route needing one. Do not push the `dev` Doppler secrets into them — that would create a second production-capable worker rather than a dev environment. Tracked as BACKLOG.md CR11.

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

#### Worker Deployment Overview

| Worker | Purpose | Production Worker | Dev Worker (`--env dev`) | CI/CD |
|--------|---------|-------------------|--------------------------|-------|
| **sender-worker** | Inline signup/signin (Auth0+Supabase); HMAC-signs `/send` events to receiver | `sender-worker` | `sender-worker-dev` | ✓ Yes (main) |
| **api-provisioning-receiver** | Verifies signed requests, persists to Supabase (production receiver) | `api-provisioning-receiver` | — (separate repo) | ✓ Yes (separate repo) |
| **stripe-webhook** | Handles Stripe subscription events | `stripe-webhook` | `stripe-webhook-dev` (no cron) | — |
| **contact-form** | Processes contact form (Resend, KV rate limit) | `integrity-studio-contact` | `integrity-studio-contact-dev` (no KV) | — |
| **api-gateway** | API gateway (aggregation, quota) | `api-gateway` | `api-gateway-dev` (own DO namespace) | — |
| **bootstrap-worker** | Bootstrap operations | `bootstrap-worker` | `bootstrap-worker-dev` | — |
| **receiver-worker** | Local stub / test double — not deployed | — | `receiver-worker-dev` | — |

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
- ❌ **E2E tests use `--config dev`, which is NOT isolated from prod** — the same Supabase project and Auth0 tenant back both configs. Verify with `npm run check:env-isolation` (6 of 13 failing as of 2026-07-29, down from 10/10). BACKLOG.md CR11
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
