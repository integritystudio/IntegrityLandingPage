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

**Phase**: Codebase review remediation + worker deploy/settings audit + database/secret remediation — 48 findings fixed, 13 open as CR01–CR21
**Last Updated**: 2026-07-27 (evening)
**Build Status**: ✅ Web build successful, running on localhost:8080
**Test Status**: ✅ 3,001 Flutter tests passing (~94% coverage); 1,039 worker tests passing (6 workers + shared lib); zero TypeScript errors; `flutter analyze` clean. Plus 5 opt-in live signature tests — `cd workers/stripe-webhook && npm run test:live` (excluded from `npm test`; skips cleanly without credentials)
**Database**: ✅ Supabase `cfrbahzzklwrnmbtqojl` is `ACTIVE_HEALTHY`; 10 migrations applied and `supabase migration list` reports zero out of sync. The ledger previously claimed migrations that had never run (CR17) — including the one creating `stripe-webhook`'s tables. RLS is now enabled on every table in `public`.
**Deployed**: production `sender-worker` + `integrity-studio-contact` healthy. **`api-gateway` is healthy** — `200 {"database":"healthy"}` since 2026-07-27, with `SUPABASE_URL` / `SUPABASE_SERVICE_ROLE_KEY` / `SUPABASE_JWT_SECRET` bound (CR12 partial). **`stripe-webhook` is fully wired as of 2026-07-28** — Supabase pair plus `STRIPE_WEBHOOK_SECRET`, and redeployed from current source. Its production code had been stuck at 2026-03-31 and could not write `webhook_events_log`; a signed probe now returns `{"ok":true,"processed":true}` and a replay returns `already_processed`. Five `*-dev` workers are deliberately secret-less (CR11) except `stripe-webhook-dev`, which holds a sandbox `STRIPE_API_KEY` + `STRIPE_WEBHOOK_SECRET` for live signature testing. No zone route points at any dev worker.
**Stripe**: production account is **`acct_1SN2e7AwEfePbhfk`**. Two endpoints, both pinned to `api_version=2025-09-30.clover` and subscribed to the five implemented events: test-mode `we_1Ty14zBWbFuvm1I6rvLOD5OW` → `stripe-webhook-dev`, and **live-mode `we_1Ty29dAwEfePbhfkky1OeqQu` → production `stripe-webhook`** (registered 2026-07-28, signature verification proven with a wrong-secret control). `prd`'s `STRIPE_SECRET_KEY` holds an **`rk_live_` restricted key** (least privilege; the `sk_live_` is retained in Doppler history) — bound to `api-gateway` and `sender-worker` on 2026-07-28 (`sender-worker` verified reading it — checkout now reaches validation instead of `"Stripe not configured"`). `api-gateway`'s billing portal is still down for a different reason: the live Customer Portal has **no configuration**, so `billing_portal.sessions.create` fails regardless of the key. Doppler `dev` is now actively wrong: its `STRIPE_SECRET_KEY` is a **`pk_live_` publishable key on the production account**. See CR18.
**Pending a `deploy:prd`** — committed but not live: CR03's `RATE_LIMIT_KV` binding and observability on all six workers (CR15 + W04 step 1). CR14's `preview_urls` is already live on `api-gateway` and `stripe-webhook` via the API. CI deploys `sender-worker` on merge to `main`; other workers are manual.

See [docs/changelog/1.3/CHANGELOG.md](docs/changelog/1.3/CHANGELOG.md) for recent changes.

### Known Issues
Thirteen items open, tracked with a status table in [docs/BACKLOG.md](docs/BACKLOG.md#code-review-2026-07-26--2026-07-27-cr01cr16). **Three are now blocked on code** (CR19–CR21, all defects in `workers/stripe-webhook/src/`); the rest need a credential decision, an answer about intent, or a production deploy.

⚠️ **Armed trap — do not run `deploy:prd` in `workers/api-gateway`.** Its `wrangler.toml` declares `api.integritystudio.ai/v1/*` at the top level, which is what `deploy:prd` publishes. That path is served by `obtool-api` via a `/*` wildcard, and Cloudflare resolves overlapping routes by longest match — so a deploy captures **all** `/v1` traffic, including `obtool-api`'s `/v1/traces`, `/v1/sessions`, and `/v1/metrics`, which `api-gateway` does not implement. The risk went **up** on 2026-07-27: that file was edited (for CR14), giving someone a reason to deploy it. CR13 step 1 (delete the `routes` key) has no live effect and defuses it.

**P1**
- **CR18**: **two different Stripe accounts** — `prd` holds a `pk_live_` *publishable* key, `dev` an `sk_test_` secret key. `STRIPE_SECRET_KEY` (what the code reads) is empty everywhere, so **no worker can make a server-side Stripe call**. Stripe has no API to create secret keys; this needs one Dashboard action plus a decision about which account is production
- **CR01**: `doppler.json` history scrub + full secret rotation still required. **Nothing has been rotated.** The Supabase half is cheaper than assumed — `sb_secret_` keys are individually revocable without rotating the project JWT secret
- **CR11**: Doppler `dev` holds the same Supabase project and Auth0 tenant as `prd`. `--config dev` is not a safety boundary. Detector: `npm run check:env-isolation` (fails 10/10) — note it **covers no Stripe credential**
- **CR12**: ⚠️ partial — `api-gateway` restored to healthy. Still missing `API_KEY_HMAC_SECRET` (canonical value lives on the receiver in `observability-toolkit`), `STRIPE_SECRET_KEY`, and `STRIPE_WEBHOOK_SECRET`
- **CR14**: ⚠️ partial — closed on `api-gateway` + `stripe-webhook`. **Still exposed:** `sender-worker` (13 secrets), `integrity-studio-contact`, and cross-repo `api-provisioning-receiver` (7)

**P2**
- **CR19**: 🔴 **code bug** — `stripe-webhook` marks out-of-order events as processed and returns 200, so an event arriving before its org link exists is lost with no dead-letter row and no retry
- **CR20**: 🔴 `stripe-webhook` returns 200 on handler failure, discarding Stripe's 3-day retry in favour of the `*/15` cron. Defensible only if the cron is monitored — it isn't yet
- **CR17**: ⚠️ partial — migration ledger had recorded migrations that never ran; repaired, but **no drift detection exists** to stop it recurring
- **CR13**: hostname topology — see the armed-trap note above
- **CR04**: JWT still passed to the dashboard in a URL fragment — cross-repo fix needed
- **CR02**: ✅ mostly closed — `npm run deploy` targets `--env dev`, verified live. Only the dev receiver remains
- **CR03**: ✅ done — KV namespaces created and bound; live in production on the next `deploy:prd`

**P3**
- **CR15**: observability fixed in config (was silently off in production for ~4 months) but **not deployed**, which now blocks confirming several things this session changed; **four** stale secrets still bound to production `sender-worker` — `RECEIVER_WORKER_URL`, `PROVISIONING_RECEIVER_WORKER_URL`, `AUTH0_CLI_AUDIENCE`, `SUPABASE_ANON_KEY`
- **CR21**: `stripe-webhook` processes synchronously rather than returning 2xx first; use `ctx.waitUntil()`
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

**⚠️ Dev workers are NOT data-isolated.** Doppler's `dev` and `prd` configs hold **identical** values for all 10 Supabase, Auth0, and HMAC credentials (`npm run check:env-isolation` reports which). Selecting `--config dev` therefore changes nothing about which database or Auth0 tenant is used. Stripe is *not* affected, but not for the reason previously stated here (corrected 2026-07-27): `prd`'s `STRIPE_API_KEY` is a **`pk_live_` publishable key** and `dev`'s is an `sk_test_` secret key, belonging to **two different Stripe accounts**. A publishable key is public by design, so there is no exposure — but `STRIPE_SECRET_KEY`, the name the code actually reads, is empty in all three configs, so no worker can make a server-side Stripe call at all. `check:env-isolation` compares no Stripe credential. See BACKLOG.md CR18. The dev workers were deliberately deployed **without secrets** so they cannot reach production data; that is why they return errors on any route needing one. Do not push the `dev` Doppler secrets into them — that would create a second production-capable worker rather than a dev environment. Tracked as BACKLOG.md CR11.

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
- ❌ **E2E tests use `--config dev`, which is NOT isolated from prod** — all 10 Supabase/Auth0/HMAC credentials are shared between the two configs. Verify with `npm run check:env-isolation` (currently fails 10/10). BACKLOG.md CR11
- ✅ No hardcoded secrets in package.json or workflows
- ⚠️ `doppler.json` remains in git history with its secrets unrotated (BACKLOG.md CR01)

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
