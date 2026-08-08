# API routing — which worker serves which hostname

**Measured 2026-08-08** (previously 2026-08-03). Every table below is live state or source, not intent. Re-measure with the commands in [Keeping this in sync](#keeping-this-in-sync) before relying on it; tracked by [BACKLOG.md CR31](BACKLOG.md#cr31) and [CR13](BACKLOG.md#cr13).

## The one-line answer

Two hostnames, two workers, no overlap:

| Hostname | Worker | Surface |
|---|---|---|
| `api.integritystudio.ai` | `obtool-api` | observability read API — traces, metrics, logs, sessions |
| `api.integritystudio.dev` | `api-gateway` | account, billing, ingest — what the product depends on |

**This changed on 2026-08-08.** Until then `api-gateway` had no hostname at all and was reachable only at `https://api-gateway.alyshia-b38.workers.dev` — a workers.dev URL that the shipped Flutter app called directly and that customers could not sensibly be handed as an integration target. CR13 resolved that with **option C, a separate branded hostname**, rather than the path-split this document previously recommended; see [Resolved — separate hostname](#resolved--separate-hostname-not-a-path-split).

⚠️ **The old workers.dev hostname still answers 200** and is deliberately left alive — nothing forces a client off it, so an unmigrated caller does not break. Do not read its continued existence as the app still using it; the Flutter default was repointed in the same change.

## Live zone routes and custom domains

🔴 **These are two different mechanisms and a worker can be reached by either. Querying only `workers/routes` — as the first version of this document did — reports `api-gateway` as having no hostname, which is now false.** A **route** claims a URL pattern on a zone and can capture paths another worker serves; a **custom domain** binds one hostname to one worker and creates its own DNS record. Check both endpoints or the answer is wrong.

**Routes** — `GET /zones/<id>/workers/routes`, all three zones:

| Pattern | Script | Zone |
|---|---|---|
| `api.integritystudio.ai/*` | `obtool-api` | `integritystudio.ai` |
| `ingest.integritystudio.ai/*` | `obtool-ingest` | `integritystudio.ai` |
| `api.alephatx.info/*` | `tcad-api` | `alephatx.info` |

**Custom domains** — `GET /accounts/<id>/workers/domains`:

| Hostname | Script | Environment |
|---|---|---|
| `api.integritystudio.dev` | `api-gateway` | production |

There are no others. `sender-worker`, `stripe-webhook`, and `integrity-studio-contact` remain workers.dev-only.

**Zones**: `integritystudio.ai` (`822492ca…`), `integritystudio.dev` (`838f8d6b…`, added 2026-08-08), `alephatx.info` (`4b49af46…`) — all active.

`workers/api-gateway/wrangler.toml` now carries a `routes` key again, but as `[{ pattern = "api.integritystudio.dev", custom_domain = true }]` — a hostname binding on a zone these workers solely occupy, **not** the `api.integritystudio.ai/v1/*` pattern CR13 step 1 removed. The distinction is load-bearing: see [the hazard](#the-hazard-a-routes-key-re-opens).

## Route inventories

### `obtool-api` — lives in `observability-toolkit/services/obtool-api`

Hono app. `authMiddleware` is mounted on `/v1/*`, so **every** `/v1/` path returns `401` before routing — a 401 proves the middleware ran, not that the route exists. Source: `src/index.ts`, `src/routes/*.ts`.

| Method | Path |
|---|---|
| GET | `/health` *(public — outside the auth middleware)* |
| GET | `/v1/traces`, `/v1/traces/:traceId`, `/v1/traces/:traceId/raw` |
| GET | `/v1/metrics`, `/v1/metrics/histograms` |
| GET | `/v1/logs` |
| GET | `/v1/sessions`, `/v1/sessions/:sessionId` |
| GET | `/v1/cost` |
| GET | `/v1/datasets` |
| POST | `/v1/datasets` |
| GET, DELETE | `/v1/datasets/:id` |
| GET | `/v1/evaluations` |

Fifteen method+path pairs over thirteen distinct paths — `/v1/datasets` and `/v1/datasets/:id` each carry a write method. Anything else under `/v1/` → `401` (middleware), then `404`. Anything outside `/v1/` → `404`.

### `api-gateway` — `workers/api-gateway/src/index.ts`

Hand-rolled dispatch on `pathname` + `method`; a method mismatch falls through to `404`.

| Method | Path |
|---|---|
| GET | `/health` |
| POST | `/v1/ingest/events` |
| POST | `/v1/ingest/otel` *(`OTEL_INGEST_ROUTE`, `routes/ingest.ts:140`)* |
| GET | `/v1/me` |
| GET | `/v1/orgs` |
| GET | `/v1/orgs/:id/dashboard` |
| GET | `/v1/orgs/:id/billing-status` |
| GET | `/v1/orgs/:id/usage/summary` |
| GET | `/v1/orgs/:id/entitlements` |
| GET | `/v1/orgs/:id/quota/status` |
| POST | `/v1/orgs/:id/billing-portal` |
| POST | `/v1/orgs/:id/checkout-session` |
| POST | `/v1/orgs/:id/api-keys` |
| POST | `/v1/orgs/:id/api-keys/:keyId/revoke` |
| POST | `/bootstrap` |
| OPTIONS | *any* — CORS preflight, answered at the outer boundary |

Note API keys are nested under `/v1/orgs/:id/`; there is no top-level `/v1/api-keys`.

## The surfaces are disjoint

**One overlap: `/health`.** Every other path belongs to exactly one worker.

| Owner | Prefixes |
|---|---|
| `obtool-api` | `/v1/traces*` `/v1/metrics*` `/v1/logs` `/v1/sessions*` `/v1/cost` `/v1/datasets*` `/v1/evaluations` |
| `api-gateway` | `/v1/me` `/v1/orgs*` `/v1/ingest/*` `/bootstrap` |

Disjointness is why a path-split *would* have worked with no code change on either side. It is also why **repointing the wildcard never could** — see below. The chosen answer uses neither: separate hostnames make the question moot, and this table is now the evidence that the two surfaces never needed to share one host in the first place.

## What the documentation advertises

Every `integritystudio.ai` URL in `lib/**/*.dart`, checked against the inventories above.

| Advertised | Site | Status |
|---|---|---|
| `https://api.integritystudio.ai/v1` | `docs_api_page.dart:117` — "Production" base | ✅ correct as a base for the observability API |
| `GET /v1/traces` | `docs_api_page.dart:250` | ✅ exists on `obtool-api` |
| `https://ingest.integritystudio.ai` | various | ✅ resolves; route → `obtool-ingest` |
| `https://api.integritystudio.ai/health` | `docs_quickstart_page.dart` — health check example | ✅ exists on `obtool-api` (public — outside the `/v1/*` auth middleware) |
| ~~`GET /v1/health`~~ | ~~`docs_quickstart_page.dart:515`~~ | ✅ **Fixed 2026-08-03 (CR31)** — was 🔴 401; path corrected to `/health` |
| ~~`POST /v1/alerts`~~ | ~~`docs_alerts_page.dart:217`~~ | ✅ **Fixed 2026-08-03 (CR31)** — was 🔴 no such route; API code block removed from docs |
| ~~`https://sandbox-api.integritystudio.ai/v1`~~ | ~~`docs_api_page.dart:119`~~ | ✅ **Fixed 2026-08-03 (CR31)** — was 🔴 NXDOMAIN; Sandbox row removed from docs |
| ~~`https://status.integritystudio.ai`~~ | ~~`docs_index_page.dart:498`~~ | ✅ **Fixed 2026-08-03 (CR31)** — was 🔴 NXDOMAIN; Status quick-link removed from docs |

Measured live:

```
GET https://api.integritystudio.ai/v1/health  -> 401      GET .../health -> 200
dig +short sandbox-api.integritystudio.ai     -> (empty)
dig +short status.integritystudio.ai          -> (empty)
dig +short api.integritystudio.ai             -> 172.67.129.159 104.21.1.162
dig +short ingest.integritystudio.ai          -> 104.21.1.162  172.67.129.159
```

⚠️ **`status.integritystudio.ai` was found only after the grep was fixed, and that is the whole argument for the sync guard.** The first version of the recipe below matched on the bare substring `api.integritystudio.ai`, which is *contained in* `sandbox-api.integritystudio.ai` — so `grep -o` printed the same string for both and the two hosts collapsed into one row. The pattern now anchors on `https?://` and captures the full host. A checker that normalises away the thing it is checking passes silently; this one did, on the exact defect it was written to find.

## Where the clients actually point

| Client | Constant | Default |
|---|---|---|
| Flutter | `API_GATEWAY_URL` | `https://api.integritystudio.dev` — `lib/services/provisioning_service.dart:22`, `lib/services/dashboard_service.dart:16` |
| Flutter | `SENDER_WORKER_URL` | `https://sender-worker.alyshia-b38.workers.dev` — `lib/services/provisioning_service.dart:15` |

`ci.yml:212` runs `flutter build web --release` with **no `--dart-define`**, so the compile-time default is exactly what ships. That cuts both ways: it is why the workers.dev default was a live-user-path fact rather than a dev convenience, and it is why repointing the constant is sufficient to move the shipped app — no config, no env, no deploy flag.

⚠️ **`SENDER_WORKER_URL` is still workers.dev and was left that way deliberately.** CR13 step 5 named only the two `API_GATEWAY_URL` sites, and `sender-worker` has no branded hostname to move to. It needs its own decision, not a tag-along.

**CORS is unaffected by the hostname change, measured rather than assumed.** `api-gateway` keys its allowlist on the *requesting* `Origin`, not on its own host: a preflight from `Origin: https://integritystudio.ai` returns `204` with `access-control-allow-origin: https://integritystudio.ai` on **both** the new and old hostnames, with identical allow-headers and methods.

## Resolved — separate hostname, not a path-split

**Decided and executed 2026-08-08 (CR13, option C).** `api-gateway` is bound to `api.integritystudio.dev` as a Workers **custom domain**. Live: `GET /health` → `200 {"database":"healthy","durableObjects":"healthy"}`, `/v1/me` → `401` (auth-gated, so the route is mounted).

> ⚠️ **This section previously recommended a 4-pattern path-split on `api.integritystudio.ai`** — `/v1/me`, `/v1/orgs*`, `/v1/ingest/*`, `/bootstrap`, leaving the wildcard as fallback. That analysis was sound and is **not** what was built. It is recorded here rather than deleted because the reason it lost is the useful part: a split would have made this repo's route list a hand-maintained mirror of a dispatch table living in another repo, so every new `api-gateway` route would silently 404 until someone remembered to add a pattern here. A separate hostname has no such coupling.

Why a hostname was available at all: `integritystudio.dev` was migrated from Porkbun to Cloudflare on 2026-08-08, which is what made a custom domain possible. Before that, the zone was not on Cloudflare and **no** Workers route or custom domain could attach to it — a registrar-level constraint no config change could satisfy.

### Repointing the wildcard stays ruled out

Not superseded — still true, and the reason is worth keeping: pointing `api.integritystudio.ai/*` at `api-gateway` would `404` all thirteen `obtool-api` routes including `/v1/traces`, the endpoint `docs_api_page.dart:250` publishes and which works today. That is a straight regression regardless of who `obtool-api` serves. The audience question only decides whether the observability API should eventually move to an internal name.

`/health` exists on both workers and is the sole path overlap; each now answers on its own hostname, so the ambiguity that made it worth noting is gone.

### The hazard a `routes` key re-opens

`workers/api-gateway/wrangler.toml` carries a `routes` key again. It is a custom domain rather than a path pattern, but the **inheritance** hazard is identical and unchanged:

- Keep it at the **top level only**, with an explicit `routes = []` under `[env.dev]`.
- `routes` **is inherited** into named environments. Omitting it there hands the production hostname to the secret-less `api-gateway-dev` — the 2026-07-27 incident, which ran for ~14 hours.
- `workers/lib/deploy-environments.test.ts` asserts the empty-dev-routes rule and is **mutation-verified**: deleting the explicit `routes = []` fails exactly that assertion.
- ⚠️ **That guard was dormant for this worker until 2026-08-08.** It only fires when production declares routes, and `api-gateway` declared none between CR13 step 1 (2026-07-29) and the custom domain. Declaring a hostname is what armed it — so its passing today means something, where its passing last week did not.
- The custom domain was created via the API **before** being codified in `wrangler.toml`, so the binding existed before any deploy could move it. Prefer that order.
- ⚠️ Cloudflare represents a custom domain as an `AAAA` record to the discard prefix **`100::`**. Do not "correct" that record or set it to DNS-only — graying it unbinds the worker while leaving the hostname resolving, which surfaces as a `522` rather than an obvious failure.

### Not recommended

- **Fold `obtool-api` into `api-gateway`.** CR16 records the two OTEL pipelines as deliberately separate — internal versus customer-facing — and says explicitly not to de-duplicate them. Convergence is an eventual goal, not current priority.
- **Front `obtool-api` behind `api-gateway` via a service binding.** Architecturally the cleanest ("gateway" is in the name), but it is a real implementation project and needs the CR16 decision first.

## Keeping this in sync

Every table above is measured. Re-run these before trusting it.

```bash
# Zone routes. NOTE the `--config dev` is load-bearing and not interchangeable:
# dev's CLOUDFLARE_GLOBAL_API_KEY is a LEGACY GLOBAL KEY (works with the
# email+key headers below), while prd's secret OF THE SAME NAME is a `cfat_`
# account token that fails BOTH this form (400) and Bearer. Same name, different
# credential class, per config — verified 2026-08-08.
GK=$(doppler secrets get CLOUDFLARE_GLOBAL_API_KEY --project integrity-studio --config dev --plain)
curl -s -H "X-Auth-Email: alyshia@integritystudio.ai" -H "X-Auth-Key: $GK" \
  "https://api.cloudflare.com/client/v4/zones/822492ca06069b369c2a75d3789fb7fa/workers/routes" \
  | python3 -c 'import json,sys; [print(r["pattern"],"->",r["script"]) for r in json.load(sys.stdin)["result"]]'

# Simpler alternative that also works: prd's CLOUDFLARE_API_TOKEN as a Bearer token.
doppler run --project integrity-studio --config prd -- sh -c 'curl -s \
  -H "Authorization: Bearer $CLOUDFLARE_API_TOKEN" \
  "https://api.cloudflare.com/client/v4/zones/822492ca06069b369c2a75d3789fb7fa/workers/routes"' \
  | python3 -c 'import json,sys; [print(r["pattern"],"->",r["script"]) for r in json.load(sys.stdin)["result"]]'

# CUSTOM DOMAINS — a separate endpoint. Querying only workers/routes reports
# api-gateway as having no hostname, which is wrong. Check both.
doppler run --project integrity-studio --config prd -- sh -c 'curl -s \
  -H "Authorization: Bearer $CLOUDFLARE_API_TOKEN" \
  "https://api.cloudflare.com/client/v4/accounts/b3868dd0fd5c0faa7d98aa325a9c2377/workers/domains"' \
  | python3 -c 'import json,sys; [print(d["hostname"],"->",d["service"]) for d in json.load(sys.stdin)["result"]]'

# api-gateway route table
grep -nE "pathname === '|subPath === '|pathname\.match\(" workers/api-gateway/src/index.ts

# obtool-api route table (separate repo)
grep -rhoE "\.(get|post|put|delete)\('[^']*'" \
  ~/.claude/mcp-servers/observability-toolkit/services/obtool-api/src/routes/*.ts | sort -u

# What the docs advertise — anchor on the scheme so sandbox-api/status stay distinct hosts
grep -rhoE "https?://[a-z0-9.-]*integritystudio\.ai[a-zA-Z0-9/{}:_.-]*" lib/ --include='*.dart' | sort -u

# ...then confirm every host in that list resolves
dig +short <host>
```

Three traps, all of which produced wrong readings while this document was being written:

- **`curl` defaults to GET.** Probing a POST-only route returns `404` and reads as "route missing". `/v1/ingest/otel`, `/v1/ingest/events`, and `/bootstrap` are all POST.
- **A `401` proves auth ran, not that the route exists.** `obtool-api` auth-gates all of `/v1/*`, so every path under it — real or invented — returns `401`. Read the source for the route table; use probes only for what is live.
- **A substring pattern merges subdomains.** `api.integritystudio.ai` is a substring of `sandbox-api.integritystudio.ai`, so the un-anchored grep printed one host for two and hid a dead link. Anchor on `https?://`.
- **Querying one endpoint answers a different question than you asked.** `workers/routes` alone reports `api-gateway` as hostname-less; it is bound by a *custom domain*, a separate endpoint. "No route" and "not reachable" are not the same claim.
- **A secret name is not a credential type.** `CLOUDFLARE_GLOBAL_API_KEY` is a legacy global key in `dev` and a `cfat_` account token in `prd`, so the correct auth *header form* differs by config under one name. An auth failure here means "wrong form for this value", not "bad credential" — the same class of error as reading a `401` as "route missing".

⚠️ **A fourth trap, added 2026-08-08 and the reason this document needed a coherent pass rather than a line edit:** it recommended a path-split for five days after that split had been rejected in favour of a separate hostname, and its client table pointed at a workers.dev default that no longer shipped. **A measurement document rots at exactly the moment the thing it measured is acted on** — the decision that makes it stale is the same event that makes it worth re-reading. Re-measure this file whenever a hostname, route, or client default changes, not on a schedule.
