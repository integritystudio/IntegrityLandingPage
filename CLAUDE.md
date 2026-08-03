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
npm run test:live                 # stripe-webhook: real Stripe-signed requests to the deployed dev Worker
                                  # sender-worker: real Auth0 Management API calls against the PRODUCTION tenant
                                  #   (--config prd; dev creds cannot mint a management token).
                                  #   vitest.live.config.ts overrides AUTH0_TEST_EMAIL to a disposable identity —
                                  #   the suite DELETES the user at that address, and prd's value is the real
                                  #   test@integritystudio.ai account. Do not remove that override.
npm run test:e2e                  # sender-worker: workerd runtime, all outbound calls mocked — needs no credentials.
                                  #   Its bindings live in vitest.e2e.config.mts, NOT Doppler — a new required
                                  #   secret must be added there or every /send test 500s.
```

**Supabase** — migrations are the source of truth for schema, proven 2026-08-03 by replaying the set onto an empty database. The CI guard is `migration-replay-check.yml` (first run green the same day; it triggers only on `main`, so a feature-branch push runs nothing — `gh run list --workflow=migration-replay-check.yml` settles its state). Ledger history and dead ends: [docs/runbooks/supabase-access.md](docs/runbooks/supabase-access.md).
```bash
# ⚠️ SUPABASE_ACCESS_TOKEN is EMPTY in Doppler on purpose — a value here OVERRIDES the
# CLI's keychain login and breaks `supabase` commands that otherwise work. Leave unset
# until a real sbp_ token is minted (BACKLOG CR01 step 3).
export SUPABASE_DB_PASSWORD=$(doppler secrets get SUPABASE_DB_PASSWORD --project integrity-studio --config prd --plain)
supabase migration list --linked   # local vs remote; any blank `remote` column is pending
supabase db push --dry-run         # preview; add --include-all if a file sorts before the last applied version
supabase db push                   # apply — ALL pending migrations, not just yours

# Apply ONE migration when others are pending (db push would sweep them in too):
supabase db query --linked -f supabase/migrations/<version>_<name>.sql
supabase migration repair --status applied <version>   # then record just that one
```
Working DDL route — no Docker, no DB password. The CLI's keychain holds a valid `sbp_` personal access token, and the Management API query endpoint runs arbitrary SQL including DDL with it:
```bash
RAW=$(security find-generic-password -s "Supabase CLI" -w)   # go-keyring-base64:<b64>
TOK=$(printf '%s' "${RAW#*:}" | base64 -d)                    # -> sbp_...
curl -s -X POST "https://api.supabase.com/v1/projects/<ref>/database/query" \
  -H "Authorization: Bearer $TOK" -H "Content-Type: application/json" \
  -d '{"query":"select 1"}'
```
- `supabase db push --db-url <conn>` works without linking (avoids mutating the linked-project state other sessions share). Use the **session pooler on :5432**, not :6543 — the transaction pooler fails mid-push with `prepared statement "lrupsc_1_0" already exists`. `db dump` shells out to Docker, which is absent here.
- 🔴 `SUPABASE_DB_PASSWORD` does **not** authenticate (SASL 28P01 in both configs; measured 2026-07-31) — the fix is a Dashboard reset plus storing the new value. Read the runbook's dead-ends list before re-deriving alternatives. The Dashboard SQL editor executes SQL **without** writing a ledger row; reconcile with `migration repair --status applied <version>` after using it.
- The service key's Doppler slot is **`SUPABASE_PROVISIONING_KEY`** — `SUPABASE_SERVICE_ROLE_KEY` exists in no config, though it is the name every Worker binds it under; reading the binding name from Doppler silently returns empty.
- `SUPABASE_INTEGRITY_MEMERSHIP_KEY` (typo real) is a third live `sb_secret_` key with full RLS bypass — **do not bind it to a Worker to solve an org-resolution problem**; an `sb_secret_` key is a credential, not a scope. Details in the runbook.
- **`create policy if not exists` is invalid PostgreSQL** — use `drop policy if exists` then `create policy`. And **`migration repair --status applied` writes a ledger row without executing the SQL** (how CR17 happened) — last resort only, never a way past a failing push.
- **RLS is not optional for privacy.** PostgREST exposes every table in `public`, so a table with RLS off is readable with the *publishable* anon key regardless of which key the workers use. RLS on with **zero policies** denies anon and authenticated while `service_role` bypasses — the correct posture for server-only tables. RLS denial returns `200 []`, not an error, so verify with the catalog:
```bash
# any table here is publicly readable
select relname from pg_class c join pg_namespace n on n.oid=c.relnamespace
where n.nspname='public' and c.relkind='r' and c.relrowsecurity=false;
```

## Current Status

**Phase**: Codebase review remediation, CR01–CR31 — canonical status table: [docs/BACKLOG.md](docs/BACKLOG.md)
**Last Updated**: 2026-08-03
**Tests**: green across the board as of 2026-08-03 — but counts in docs have drifted by ~100 before, so run the suites rather than reconciling a number: `flutter test --coverage`, per-worker `npm test`, `npm run lint:workers` (= `tsc --noEmit` × the 6 packages; the **only** worker linter — plain `npm run lint` is `flutter analyze`). That now covers every test file in all six packages: `sender-worker`'s tsconfig `exclude` that hid 111 type errors is gone and **must not come back**. Full story, suite snapshot, and the `node`-types / `globalThis` findings: [docs/runbooks/worker-deps-and-typechecking.md](docs/runbooks/worker-deps-and-typechecking.md).
**Dependencies**: all six worker packages aligned and `npm audit` 0 in each (2026-08-03). Not npm workspaces — audit and bump **per package**. Lockfiles are gitignored, so **declared floors are the only control**: raise them after every `npm update`. The manifest-editing rules (wrangler ≥4.114 forces workers-types v5, vendored nested copies, unpinned `allowScripts`, the disjunct trap): same runbook.
**Database**: Supabase `cfrbahzzklwrnmbtqojl` `ACTIVE_HEALTHY`; ledger replay-proven; RLS enabled on every table in `public`. Dev project: `tumhmtshahktumhqqamk` / `integritystudio-dev`.
**Deployed**: all four production Workers run current source (the 2026-07-30 redeploy closed a four-month gap — history in [docs/runbooks/cloudflare-deploy-notes.md](docs/runbooks/cloudflare-deploy-notes.md)). `api-gateway` healthy; `API_KEY_HMAC_SECRET` still unbound (CR12). **`SUPABASE_JWT_SECRET` is deliberately unbound — do not re-bind it to "fix" a 401**: `api-gateway` verifies Auth0-issued tokens against **Auth0** JWKS, and verifying them against Supabase JWKS is exactly what produced the original `401 Invalid JWT signature` (CR26). Dev workers hold DEV credentials (2026-08-03); no zone route points at any dev worker.
**Stripe**: production account `acct_1SN2e7AwEfePbhfk`, sandbox `acct_1SN2eDBWbFuvm1I6` (dev — the one credential family that was always genuinely isolated). Both webhook endpoints pinned to `api_version=2025-09-30.clover` and subscribed to the five implemented events: test-mode `we_1Ty14zBWbFuvm1I6rvLOD5OW` → `stripe-webhook-dev`, live `we_1Ty29dAwEfePbhfkky1OeqQu` → production `stripe-webhook`. `STRIPE_SECRET_KEY` holds an `rk_live_` restricted key (least privilege; the `sk_live_` is retained in Doppler history). The live Customer Portal configuration is `bpc_1Ty2XDAwEfePbhfk9PndBNgW`. ⚠️ The unused second live key `…B6I8` (slot `STRIPE_API_KEY`) awaits Dashboard revocation — revoke there **first**, then clear the slot; the last-4 is how the Dashboard identifies it.

**Deployment history: read it, don't infer it.** Binding a secret creates a deployment **without shipping code**, so timestamps alone lie — read them as "bindings changed" unless the version's source is `version_upload` (this is how `stripe-webhook` was caught running a months-old build). Version IDs recorded in docs go stale within a day; read the live value:
```bash
npx wrangler deployments list --name <worker>   # what shipped
npx wrangler secret list --name <worker>        # what is bound
```
The versions API reconstructs *when* a binding changed: each version's `resources.bindings` carries binding **names** (values are write-only), so diffing name sets across versions gives the full bind/unbind history. The API reports UTC — **record UTC**, not local time. `secret list` counts secrets only while `resources.bindings` also includes KV/service/DO bindings, so the two counts differ legitimately; reconcile before concluding they disagree. Worked examples: deploy-notes runbook.
```bash
ACCT=$(doppler secrets get CLOUDFLARE_ACCOUNT_ID --project integrity-studio --config prd --plain)
TOKEN=$(doppler secrets get CLOUDFLARE_API_TOKEN --project integrity-studio --config prd --plain)
B=https://api.cloudflare.com/client/v4/accounts/$ACCT/workers/scripts/<worker>/versions
curl -s -H "Authorization: Bearer $TOKEN" "$B?per_page=100"   # ids + created_on + source
curl -s -H "Authorization: Bearer $TOKEN" "$B/<version-id>" \
  | python3 -c 'import json,sys; print(sorted(b["name"] for b in json.load(sys.stdin)["result"]["resources"]["bindings"]))'
```

⚠️ **`sender-worker` deploys via CI on merge to `main`.** A manual `deploy:prd` puts production ahead of `main`, and a later CI run from a stale `main` silently rolls it back — merge promptly after any manual production deploy. The mirror hazard also holds: pushing a stale `main` deploys older code over what is live. (CR29's manual deploys are merged and durable as of 2026-08-03.)

**Not deployable.** `receiver-worker` is a local stub / test double — `deploy:prd` would create a production Worker that nothing binds to and that returns mock responses. `bootstrap-worker` was deleted 2026-07-31; `POST /bootstrap` is a route on `api-gateway` (verified live: **401**, not 404, so the route is mounted and auth-gated).

See [docs/changelog/1.3/CHANGELOG.md](docs/changelog/1.3/CHANGELOG.md) for recent changes.

### Known Issues

Canonical detail, step lists, and live status: [docs/BACKLOG.md](docs/BACKLOG.md#code-review-2026-07-26--2026-07-27-cr01cr31) — read it before working any CR. Entries here are one-line pointers plus the rules that outlive each item, deliberately free of counts that go stale.

**P1**
- **CR29** ✅ closed and durable (2026-08-03): sender fails closed, receiver requires `x-key-id`, `SHARED_SECRET` unbound and its prd slot deleted. Rules that outlive it: a green `/send` never tests the legacy path (`resolveOutboundSigningKey` prefers `v2`); the load-bearing test assertion is `expect(mockReceiverFetch).not.toHaveBeenCalled()`, not the status code; the live gate metric is `auth.key_unresolved` with `miss: "missing_key_id"` at zero (`auth.verified_legacy_key`'s emitting path is deleted, so its silence proves nothing); test helpers meaning "omit this header" must take `null` as the sentinel — `f(undefined)` uses the default; toolkit `receiver-security.e2e.ts` keeps its `assertSignatureAccepted` positive control (without it a 401 passes while testing nothing); and `SHARED_SECRET` stays in the test fixtures with a value *different* from the active key, so "unreachable" is proven with the credential present — do not tidy it out. **Do not provision `SIGNING_KEYS`/`ACTIVE_KEY_ID` into Doppler `dev`** — dev's `RECEIVER` binds the production receiver.
- **CR11** ✅ isolation achieved and dev workers armed (2026-08-03) — `npm run check:env-isolation` PASSES; re-run it rather than trusting this line. Remaining tails are not isolation: scoping the dev deploy token (step 8), restoring the toolkit e2e suite. Auth0 traps: creating any client **auto-enables it on the production connection** (re-check the client list after every creation), and the plain `password` grant resolves via the tenant-wide `default_directory`.
- **CR01** ⚠️ rotations done; revocations pending (two Stripe Dashboard keys, the transcript-exposed `sbp_` token). **A rotation is not a revocation.** On-disk `doppler.json` and `~/.doppler/fallback/` still hold pre-rotation material — do not delete yet.
- **CR12** ⚠️ `API_KEY_HMAC_SECRET` unbound (canonical value lives in `observability-toolkit`); API-key auth routes are broken until it is bound.
- **CR18** ⚠️ resolved except the `…B6I8` Dashboard revocation (see Stripe above).
- **CR14** ✅ effectively closed 2026-08-03: the production receiver's `preview_urls = false` is deployed (toolkit `dbac959`) and verified — its preview URLs return 404 `error code: 1042`; this repo's workers were closed 2026-07-29, `stripe-webhook-dev` 2026-08-03. ✅ **Account-wide as of 2026-08-03 — toolkit `PREVIEW-URLS` is closed too**: `obtool-ingest` (22 of 26 live → 0; it served `INJECT_HMAC_SECRET` from versions back to 2026-02-24 and was the worst of the three, found only by auditing) and `obtool-api` (7 of 9 → 0, no secrets). **0 live preview URLs in the account.** Rules that outlive it: 🔴 **`preview_urls = false` retracts EXISTING preview URLs, not just future ones** — the opposite of what both backlogs assumed, which is why the planned follow-ups (version deletion, credential rotation) were **unnecessary**; a retained version snapshots code **and** bindings as uploaded — rotation neither leaks backwards onto old versions nor cleans them up forwards; within a 404, body `error code: 1042` = previews disabled while Cloudflare's HTML 404 page = previews still on (not evidence of mitigation); the mitigation POST **must include `"enabled":true`** or it takes down the Worker's `workers.dev` hostname — the only route for the shipped Flutter app to `sender-worker`/`integrity-studio-contact` and for Stripe's test-mode delivery; propagation takes seconds, so sample more than once; and workers.dev serves `Python-urllib` a blanket 403 — probe with curl.

**P2**
- **CR20** 🔴 `stripe-webhook`'s cron is the **only** retry path (CR21 returns 2xx before processing via `ctx.waitUntil`) and it is unmonitored — W04 alerting is mandatory.
- **CR31** 🔴 the published API docs advertise four URLs that resolve to nothing, and `api-gateway` has no hostname. Inventory, probe traps, and the recommended fix (four narrow route patterns; **do not repoint the wildcard** — it would 404 all thirteen `obtool-api` routes): [docs/api-routing.md](docs/api-routing.md).
- **CR13** ⚠️ the `routes` key is out of `api-gateway`'s wrangler.toml and a real `deploy:prd` proved it safe (zone routes unchanged). Open: the hostname-topology decision — a decision now, not an investigation (CR31 measured both surfaces).
- **CR25** ⚠️ Auth0 production-readiness: google-oauth2's shared dev-keys disabled ✅; MFA enforcement is a decision (would force all users to enrol); breached-password detection is genuinely plan-gated (PATCH returns 400 "upgrade your subscription"). ✅ **implicit and ROPC closed 2026-08-03 ([[CR34]]): implicit 2 clients → 0, ROPC 3 → 1.** 🔴 **Do not strip the survivor** — `My App` (`vnFenjO3…`) must keep `password`, because `sender-worker`'s `/signin` sends `grant_type=password` against it (`supabase.ts:218`); removing it is a production login outage. `AUTH0_MANAGER` lost ROPC (proven by effect: a wrong-password attempt went `invalid_grant` → `unauthorized_client`) and the dashboard SPA lost `implicit`+`password` (it uses `loginWithRedirect`, auth code + PKCE). ⚠️ Auth0 client ids are **display-truncated** in listings — look the full id up before PATCHing, or you strip grants off the wrong client. Remaining CR25 work split out: custom domain **CR32 (NOT plan-gated — `POST /custom-domains` returns 400, not 403; needs a hostname decision + DNS)**, log streams **CR33** (needs a receiver; the OTLP ingest cannot parse Auth0's format), breached-password **CR35** (spend), MFA enforcement stays here.
- **CR04** ✅ deployed 2026-08-03 — the URL-fragment token handoff is deleted; `access_token` appears nowhere in `lib/`, `test/`, or `e2e/`. (The receiving dashboard never read the fragment; GitHub Pages can set no security headers, which is why the token had to stop landing there.)
- **CR02** ✅ except the dev receiver (lives in the toolkit repo; CR29's resolution took it off the critical path).

**P3**
- **CR22** ⚠️ deployed but unexercised — the 403 path needs a valid API key that fails only the type check, unreachable until CR12. An invalid key returning `401 Invalid JWT format` is CR23's design decision, not a regression.
- **CR16** 📋 by design: `obtool-ingest` (internal, → R2+D1) and `api-gateway`'s `/v1/ingest/otel` (customer-facing, → Supabase) are separate pipelines — **do not de-duplicate them.**
- **Closed**: CR03, CR15, CR17, CR19, CR21, CR24 (**never re-enable the legacy Supabase `anon`/`service_role` JWT keys — those JWTs are disclosed material**), CR26, CR27, CR28.

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
docs/                 # Architecture, routes, changelog, backlog, runbooks
test/                 # Unit + widget tests (~94% coverage)
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
  - **Forwarded to receiver:** `/send` events (`provision_api_key`, `sign_in`) are HMAC-SHA256-signed and forwarded to the production receiver `api-provisioning-receiver` via the `[[services]]` binding; API-key minting happens on the receiver. `resolveOutboundSigningKey` **fails closed on all four misses** — `SIGNING_KEYS` + `ACTIVE_KEY_ID` are the only credential, `x-key-id` is sent unconditionally, and `SHARED_SECRET` is read by nothing. See CR29 above before changing any of that.
  - **`/create-checkout-session` derives the org server-side from the email — never accept an `orgId` from the caller.** The route is origin-gated but *unauthenticated*, and the origin gate is a browser-surface control that origin-less callers (Flutter native, curl) bypass by design — so a client-supplied org id would let any caller attach a subscription to an org they do not own. `supabaseFindOrgIdByEmail` resolves it instead (prefer `default_organization_id`, else oldest active membership, mirroring `custom_access_token_hook`). Resolution is **best-effort by design**: an unknown email or failed lookup logs and proceeds with an unattributed session, because failing checkout to protect a metadata field trades a linking bug for a revenue bug. `stripe-webhook` reads `session.metadata.org_id || session.client_reference_id` to run `linkStripeCustomer` (`workers/stripe-webhook/src/handlers/checkout.ts:24`).
  - ⚠️ **That route is only correct for single-org users.** It resolves an *identity* to an org, so for anyone holding several memberships it silently returns their default org rather than the one being paid for — a real multi-org case would have attached the new subscription to an org that was already paying. **Use it only for the signup flow** (exactly one org, no session yet). Anywhere the caller is authenticated and the org is known, use **`POST /v1/orgs/:id/checkout-session`** on `api-gateway` — the org comes from a membership-checked route parameter, still never from the request body.
  - **Gotcha — mock by URL, not by call order, in `index.test.ts`.** `handleCreateCheckoutSession` makes a Supabase lookup *before* the Stripe call, so `mockResolvedValueOnce`/`mockRejectedValueOnce` bind to the lookup and the Stripe branch under test never runs. Three tests broke this way, two of them only surfacing on the full suite rather than a `-t`-filtered run. Route on `url.includes('/rest/v1/')` instead.
- [workers/receiver-worker/](workers/receiver-worker/) — **Local stub / test double only** (signature verification + replay protection, returns mock responses). The production receiver is `api-provisioning-receiver` in the separate `observability-toolkit` repo, which persists to Supabase. Nothing binds to this stub in production.
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

Deploy targets are set by the **wrangler environment**, not by Doppler: Doppler chooses which secrets get injected; `--env dev` chooses which Worker gets written. Conflating them was CR02 — before 2026-07-27 both scripts ran a plain `wrangler deploy`, so a local `npm run deploy` published straight over production.

The top-level block of each `wrangler.toml` **is** the production config; `[env.dev]` is the dev overlay. Three consequences before editing one:
- `deploy:prd` must never pass `--env`. A named environment renames the Worker (`sender-worker` → `sender-worker-production`), which orphans its Durable Object namespaces, routes, and crons.
- Wrangler does not inherit `durable_objects`, `services`, `vars`, `kv_namespaces`, `r2_buckets`, `d1_databases`, or `queues` into a named environment. Add one at the top level and you must repeat it under `[env.dev]` or the dev Worker silently loses the binding.
- **`routes` and `triggers` are the opposite — they ARE inherited, and omitting them is dangerous.** A named environment with no `routes` key inherits the production routes and binds them to the dev Worker (on 2026-07-27 that handed `api.integritystudio.ai/v1/*` to the secret-less `api-gateway-dev`). Only an explicit `routes = []` (and `crons = []`) detaches a dev environment. The two rules pull in opposite directions: **repeat bindings, empty routes and triggers.**

Both rules are enforced by `workers/lib/deploy-environments.test.ts`.

**Pointing the Flutter app at the dev workers**
```bash
flutter run -d chrome \
  --dart-define=SENDER_WORKER_URL=https://sender-worker-dev.alyshia-b38.workers.dev \
  --dart-define=API_GATEWAY_URL=https://api-gateway-dev.alyshia-b38.workers.dev \
  --dart-define=CONTACT_API_URL=https://integrity-studio-contact-dev.alyshia-b38.workers.dev
```
Without these the app uses the compile-time defaults in `lib/services/`, which point at the **production** workers — including in `ci.yml`, which builds with no `--dart-define`.

**Environment isolation** (status 2026-08-03; proofs and holdings in [docs/runbooks/cloudflare-deploy-notes.md](docs/runbooks/cloudflare-deploy-notes.md)):
- Doppler `dev` is data-isolated from `prd` — its own Supabase project (`tumhmtshahktumhqqamk`), Auth0 tenant (`dev-njjmghdzm23uy0p7`), HMAC secret, and Stripe sandbox. Verify with `npm run check:env-isolation` (PASSES; re-run rather than trust).
- The `*-dev` workers hold those dev credentials. **Deliberately withheld:** `SIGNING_KEYS`/`ACTIVE_KEY_ID`/`SHARED_SECRET` from `sender-worker-dev`, because its `RECEIVER` still binds the **production** receiver (CR02 item 5) — dev `/send` must fail closed until a dev receiver exists.
- **Never push `prd` values into a `*-dev` worker.** Isolation is free on all three vendors (verified 2026-08-02: Supabase 2 free projects per owner, Auth0 extra tenants free, Stripe sandboxes free), so cost never justifies sharing. **`dev` must never receive a copy of a `*_live_` key** — the `rk_live_` in prd being correct least-privilege practice is exactly what makes copying it tempting.
- Deploy auth: `wrangler` authenticates with **`CLOUDFLARE_API_TOKEN`** — `npm run deploy` injects it from Doppler `dev`, `deploy:prd` from `prd`, and the two values are distinct. But dev's token is account-wide in scope (it can reach every production script), so what stops `npm run deploy` hitting production is `--env dev` plus the test asserting it; **separate Cloudflare accounts with pinned wrangler profiles are the only structural fix** (CR11 step 8). `CLOUDFLARE_WORKER_TOKEN` is read by nothing in this repo. Full audit: runbook.

#### Doppler Configuration
- **Project**: `integrity-studio`
- **`dev`**: a separate environment as of 2026-08-03 (see isolation above)
- **`prd`**: production deployments, secret rotation, sensitive operations
- **`stg`**: exists but is **empty** — every credential is unset

Worker runtime secrets are **not** supplied by Doppler. `wrangler deploy` does not turn ambient env vars into Worker secrets; those are set per worker with `wrangler secret put`. Doppler's role at deploy time is to provide `CLOUDFLARE_API_TOKEN`. Check what a worker actually has bound:
```bash
npx wrangler secret list --name <worker>          # or --env dev
```

**Read Doppler values with `doppler secrets get --plain`, not `doppler run`.** On 2026-07-27 `doppler run` served a stale value from the `~/.doppler/fallback/` cache that `secrets get --plain` (and the upstream API) contradicted. Two traps compound it: `sh -c 'echo -n "$V"'` prints the literal `-n ` under POSIX `sh` — use `printf '%s'` — and a prefix alone is weak evidence. Fingerprint instead, which never prints secret material:
```bash
v=$(doppler secrets get NAME --project integrity-studio --config prd --plain | tr -d '\n')
printf 'len=%s sha=%s\n' "${#v}" "$(printf '%s' "$v" | shasum | cut -c1-12)"
```
When binding a secret to a Worker, pipe that captured value into `wrangler secret put` rather than letting `doppler run` inject it. `doppler run` remains the right way to inject `CLOUDFLARE_API_TOKEN` into a deploy — the prohibition is on reading a value back through it.

**Sample twice before concluding a binding is bad.** Cloudflare rolls new versions and config out over seconds, and a single-shot probe on the wrong side of the rollout reads as "the secret was written wrong" when it wasn't (incident in the runbook). Re-probe, preferably in a loop, before diagnosing.

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

**Note:** `sender-worker` reaches the receiver via a service binding — `service = "api-provisioning-receiver"` in `workers/sender-worker/wrangler.toml` (the source of truth). The production receiver lives in the separate `observability-toolkit` repo and is deployed from there; pushing that repo's `main` auto-deploys it when its tests are green.

### GitHub Actions CI/CD

`.github/workflows/ci.yml` runs on push to `main`: all tests must pass, then it deploys `sender-worker` (the only worker on CI — the others deploy manually with `npm run deploy:prd`) and the Flutter web build. `migration-replay-check.yml` replays the migration set onto an empty database, also `main`-only. Secrets: `DOPPLER_TOKEN`, `CLOUDFLARE_API_TOKEN`, `CLOUDFLARE_ACCOUNT_ID`.

**Deployment safety:**
- `npm run deploy` targets `--env dev`, so a local deploy cannot overwrite a production worker (enforced by `workers/lib/deploy-environments.test.ts`)
- All workers have `deploy:prd` for emergency hotfixes; `deploy:prd` uses `--config prd`, never `dev`
- E2E tests use `--config dev`, which is isolated from prod as of 2026-08-03 (`npm run check:env-isolation`)
- `doppler.json` was scrubbed from git history (2026-07-29) and credentials rotated — but **rotated is not revoked**: the on-disk `doppler.json` and `~/.doppler/fallback/` still hold pre-rotation material (CR01)

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

**Prd secrets** are rotated on a schedule. Read values with `doppler secrets get --project integrity-studio --config prd --plain` and fingerprint them (recipe above), then bind with `wrangler secret put` — **not** with `doppler run`, which has served a stale cached value. And a rotation is not a revocation: the superseded credential stays live until it is explicitly deleted at the provider.

See `.github/workflows/ci.yml` for the current production deployment configuration and secret injection.
