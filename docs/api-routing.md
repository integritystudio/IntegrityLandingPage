# API routing — what serves `api.integritystudio.ai`

**Measured 2026-08-03.** Every table below is live state or source, not intent. Re-measure with the commands in [Keeping this in sync](#keeping-this-in-sync) before relying on it; tracked by [BACKLOG.md CR31](BACKLOG.md#cr31).

## The one-line answer

`api.integritystudio.ai/*` routes to **`obtool-api`**, the observability read API. `api-gateway` — which serves the account, billing, and ingest endpoints the product actually depends on — has **no hostname at all** and is reachable only at `https://api-gateway.alyshia-b38.workers.dev`.

That is backwards from what the names imply, and **four** published URLs across four documentation pages resolve to nothing.

## Live zone routes

All worker routes in the account, both zones. Read via `GET /zones/<id>/workers/routes`.

| Pattern | Script | Zone |
|---|---|---|
| `api.integritystudio.ai/*` | `obtool-api` | `integritystudio.ai` |
| `ingest.integritystudio.ai/*` | `obtool-ingest` | `integritystudio.ai` |
| `api.alephatx.info/*` | `tcad-api` | `alephatx.info` |

There are no others. `api-gateway`, `sender-worker`, `stripe-webhook`, and `integrity-studio-contact` are all workers.dev-only.

This confirms CR13 step 1 held: `workers/api-gateway/wrangler.toml` carries no `routes` key, so its `deploy:prd` has never captured `api.integritystudio.ai`.

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

This is what makes a path-split viable with no code change on either side.

## What the documentation advertises

Every `integritystudio.ai` URL in `lib/**/*.dart`, checked against the inventories above.

| Advertised | Site | Status |
|---|---|---|
| `https://api.integritystudio.ai/v1` | `docs_api_page.dart:117` — "Production" base | ✅ correct as a base for the observability API |
| `GET /v1/traces` | `docs_api_page.dart:250` | ✅ exists on `obtool-api` |
| `https://ingest.integritystudio.ai` | various | ✅ resolves; route → `obtool-ingest` |
| `GET /v1/health` | `docs_quickstart_page.dart:515` | 🔴 **401.** Health lives at `/health`; the `/v1/*` middleware catches `/v1/health` first. The quickstart's first command fails for every reader |
| `POST /v1/alerts` | `docs_alerts_page.dart:217` | 🔴 **No such route on either worker.** 401 from the middleware, 404 behind it even with a valid key. A documented endpoint with no server-side implementation |
| `https://sandbox-api.integritystudio.ai/v1` | `docs_api_page.dart:119` — "Sandbox" base | 🔴 **NXDOMAIN.** No DNS record, no route in either zone. Connection fails outright |
| `https://status.integritystudio.ai` | `docs_index_page.dart:498` — "Status" quick-link | 🔴 **NXDOMAIN.** A dead link in the quick-links row on the docs landing page |

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
| Flutter | `API_GATEWAY_URL` | `https://api-gateway.alyshia-b38.workers.dev` — `lib/services/provisioning_service.dart:21`, `lib/services/dashboard_service.dart:15` |

`ci.yml` builds with no `--dart-define`, so shipped builds use that default. The product's account and billing API is served to customers from a workers.dev hostname.

## Recommendation — split by path, do not repoint the wildcard

Repointing `api.integritystudio.ai/*` to `api-gateway` would `404` all thirteen `obtool-api` routes, including `/v1/traces` — the one documented endpoint that currently works. That is a straight regression.

Cloudflare matches the **most specific** route, so adding narrower patterns leaves the wildcard as the fallback:

```
api.integritystudio.ai/v1/me         -> api-gateway
api.integritystudio.ai/v1/orgs*      -> api-gateway
api.integritystudio.ai/v1/ingest/*   -> api-gateway
api.integritystudio.ai/bootstrap     -> api-gateway
api.integritystudio.ai/*             -> obtool-api      (unchanged)
```

Four new patterns. `/v1/orgs*` covers the nested api-keys routes. No code change on either worker — both already serve these paths.

`/health` stays with `obtool-api` via the wildcard, leaving `api-gateway`'s health check workers.dev-only. Acceptable for an internal check.

### The hazard this re-opens

Adding these means putting a `routes` key back into `workers/api-gateway/wrangler.toml` — exactly what CR13 step 1 removed.

- Put it at the **top level only**, and add an explicit `routes = []` under `[env.dev]`.
- `routes` **is inherited** into named environments. Omitting it there hands production traffic to the secret-less `api-gateway-dev` — the 2026-07-27 incident.
- `workers/lib/deploy-environments.test.ts` asserts the empty-dev-routes rule. Run it before deploying.
- Prefer creating the routes via Dashboard/API first and codifying them in `wrangler.toml` afterwards, so the route exists before any deploy can move it.

### Not recommended

- **Fold `obtool-api` into `api-gateway`.** CR16 records the two OTEL pipelines as deliberately separate — internal versus customer-facing — and says explicitly not to de-duplicate them. Convergence is an eventual goal, not current priority.
- **Front `obtool-api` behind `api-gateway` via a service binding.** Architecturally the cleanest ("gateway" is in the name), but it is a real implementation project and needs the CR16 decision first.

## Keeping this in sync

Every table above is measured. Re-run these before trusting it.

```bash
# Zone routes (needs a token with zone read — the dev workers token is 403 here by design)
GK=$(doppler secrets get CLOUDFLARE_GLOBAL_API_KEY --project integrity-studio --config dev --plain)
curl -s -H "X-Auth-Email: alyshia@integritystudio.ai" -H "X-Auth-Key: $GK" \
  "https://api.cloudflare.com/client/v4/zones/822492ca06069b369c2a75d3789fb7fa/workers/routes" \
  | python3 -c 'import json,sys; [print(r["pattern"],"->",r["script"]) for r in json.load(sys.stdin)["result"]]'

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
