# API Architecture

The HTTP surfaces Integrity Studio ships or depends on: which Worker owns which hostname, how `api-gateway` dispatches, how usage is metered, and how an API key is provisioned through `sender-worker` and `api-provisioning-receiver`.

Authentication is out of scope here. [TWO_LAYER_AUTH_ARCHITECTURE.md](TWO_LAYER_AUTH_ARCHITECTURE.md) is the authoritative description of tokens, API-key formats, key storage and the api-gateway request pipeline; where the two documents disagree, that one is correct. Worker source is collected in [`repomix/repomix-workers.xml`](repomix/repomix-workers.xml).

---

## System overview

The component map — which Workers talk to which, the signed provisioning hop, where keys and usage rows are written — is a diagram in [api-system-overview.html](api-system-overview.html) (published at https://claude.ai/artifact/WhzPznK3hC8b3rqdrVVgsF), with the component table beside it.

---

## Hostnames

| Hostname | Worker | Binding |
|---|---|---|
| `api.integritystudio.dev` | `api-gateway` | Workers custom domain |
| `api.integritystudio.ai` | `obtool-api` | zone route `api.integritystudio.ai/*` |
| `ingest.integritystudio.ai` | `obtool-ingest` | zone route `ingest.integritystudio.ai/*` |

`sender-worker`, `stripe-webhook` and `integrity-studio-contact` have no custom hostname and are reached at their `*.workers.dev` URLs.

The customer-facing product API and the observability API live on **separate hostnames** rather than as path prefixes on one. A path split on a shared host would make this repo's zone routes a hand-maintained mirror of another repo's dispatch table, so every new `api-gateway` route would 404 until a pattern was added. Separate hostnames remove that coupling.

### Invariants

- `api.integritystudio.ai/*` stays bound to `obtool-api`. Pointing it at `api-gateway` would 404 every observability route.
- A route claims a URL pattern on a zone; a custom domain binds a whole hostname to one Worker and owns its DNS record (an `AAAA` to `100::`, proxied). Both mechanisms must be considered when asking what serves a hostname.
- `routes` is inherited by wrangler named environments. `workers/api-gateway/wrangler.toml` declares the custom domain at the top level and `routes = []` under `[env.dev]`, so the dev Worker never receives the production hostname. `workers/lib/deploy-environments.test.ts` and `npm run check:api-routing` enforce this.
- Routes and custom domains attach only to zones hosted on Cloudflare.

---

## Route tables

### `api-gateway`

Dispatch is hand-rolled on `pathname` + `method` in `workers/api-gateway/src/index.ts`; the fixed `/v1/orgs/:id/*` sub-paths are a table in `src/lib/org-routes.ts`. A method mismatch is a `404`.

| Method | Path | Caller |
|---|---|---|
| GET | `/health` | anyone |
| POST | `/v1/ingest/events` | JWT or API key — [Usage ingestion](#usage-ingestion) |
| POST | `/v1/ingest/otel` | API key |
| GET | `/v1/me`, `/v1/orgs` | JWT |
| GET, POST | `/v1/me/team` | JWT — POST needs a verified email ([CR54](changelog/1.4/CHANGELOG.md#cr54)) |
| GET | `/v1/orgs/:id/dashboard`, `/billing-status`, `/usage/summary`, `/entitlements`, `/quota/status` | JWT, active member |
| POST | `/v1/orgs/:id/billing-portal`, `/checkout-session`, `/api-keys` | JWT, active member |
| POST | `/v1/orgs/:id/api-keys/:keyId/revoke` | JWT, active member |
| GET | `/v1/admin/orgs`, `/v1/admin/orgs/:id/{billing-status,usage/summary,entitlements,quota/status}` | JWT, `users.id` in `STAFF_USER_IDS` |
| POST | `/bootstrap` | JWT |
| POST | `/v1/auth0-logs` | `AUTH0_LOG_STREAM_TOKEN` (the scheduled Auth0 log poller is the primary feed) |
| OPTIONS | any | CORS preflight |

- API keys are a sub-resource of an org; there is no top-level `/v1/api-keys`.
- Every `/v1/orgs/:id/*` request reserves one quota unit and records the same unit in `usage_events`, so what is enforced is what `/usage/summary` reports. `/usage/summary` and `/quota/status` count against the per-minute window only, so an org that has used its month can still read its usage.
- `/v1/me/team` lets a user join the existing team org for their email domain (`organizations.type = 'team'`, matching `domain`). GET reports the team and whether the caller is an active member, from `users.email`; POST checks the address with Auth0 `/userinfo` (`email_verified === true`, else 403), adds an active `member` row (404 when no team org exists, 409 for a suspended or invited row, idempotent for an active one) and writes an `org.member_joined` audit row. It never creates a team org or touches the personal org.
- `/v1/admin/*` is dispatched outside the org branch: staff reads take no org throttle, reserve no quota and write no usage row. Each staff view of an org writes an `admin.org_viewed` audit row (at most one per org per hour). `STAFF_USER_IDS` is shared with `quality-metrics-dashboard`.

### `obtool-api`

Hono app in `observability-toolkit/services/obtool-api`. `authMiddleware` covers all of `/v1/*`, so any `/v1/` path, real or not, answers `401` to an unauthenticated caller.

| Method | Path |
|---|---|
| GET | `/health` *(public)* |
| GET | `/v1/traces`, `/v1/traces/:traceId`, `/v1/traces/:traceId/raw` |
| GET | `/v1/metrics`, `/v1/metrics/histograms`, `/v1/metrics/exponential-histograms` |
| GET | `/v1/logs` |
| GET | `/v1/sessions`, `/v1/sessions/:sessionId` |
| GET | `/v1/cost` |
| GET, POST | `/v1/datasets` |
| GET, DELETE | `/v1/datasets/:id` |
| GET | `/v1/evaluations` |

The two route sets are disjoint apart from `/health`. The two OTEL ingest paths — `obtool-ingest` (internal, to R2 and D1) and `api-gateway`'s `/v1/ingest/otel` (customer-facing, to Supabase) — are separate by design and are not to be merged.

### Client endpoints

The Flutter app's endpoints are compile-time constants, overridable with `--dart-define`. CI builds without overrides, so the defaults are what ships, and they are production.

| URL | Used by | Serves |
|---|---|---|
| `https://api.integritystudio.dev` | `API_GATEWAY_URL` — `provisioning_service.dart`, `dashboard_service.dart` | `api-gateway` |
| `https://sender-worker.alyshia-b38.workers.dev` | `SENDER_WORKER_URL` — `provisioning_service.dart` | `sender-worker` |
| `https://api.integritystudio.ai/v1` | `docs_api_page.dart` — documented base URL | `obtool-api` |
| `https://api.integritystudio.ai/v1/traces` | `docs_api_page.dart` | `obtool-api` |
| `https://api.integritystudio.ai/health` | `docs_quickstart_page.dart` | `obtool-api` |
| `https://ingest.integritystudio.ai` | docs pages | `obtool-ingest` |

`npm run check:api-routing` requires every API-subdomain URL in `lib/**/*.dart` to appear in this table and to resolve. `api-gateway` keys its CORS allowlist on the requesting `Origin`, not on its own host, so the allowlist is independent of which hostname serves it.

---

## Usage ingestion

### Data flow

```
client ── POST /v1/ingest/events ──▶ api-gateway
                                      bearer token → JSON → schema → org access → quota → insert
                                                                                         │
                                       usage_events (append-only) ◀──────────────────────┘
                                          │ trigger_upsert_daily_usage_bucket
                                          ▼
                                       usage_buckets_daily (org, UTC day, metric_key)
                                          │
                                          ▼
                              /v1/orgs/:id/usage/summary, /bootstrap usage_snapshot
```

- **One writer per table.** `usage_events` is written by `api-gateway` only (ingest routes and metered org requests). `usage_buckets_daily` is written only by the database trigger `upsert_daily_usage_bucket()`, which increments totals and keeps `avg_latency_ms` weighted by `latency_sample_count` (events that carried a latency). Monthly figures are computed from daily buckets when read; there is no monthly table. `rollupMonthlyBucket` in `workers/api-gateway/src/aggregation.ts` is a library function with no production caller.
- **202 means stored.** The `usage_events` insert completes before the response.
- **Not idempotent.** `request_id` is generated server-side per request and is indexed but not unique, so a retried request is a second event. Clients should retry only when no response was received.

### `POST /v1/ingest/events`

Handler `handleIngestEvent` (`workers/api-gateway/src/routes/ingest.ts`); schema `IngestEventRequestSchema` (`workers/lib/types/usage.ts`).

Org access depends on the credential:
- **JWT** — the `sub` resolves to `users.id`, which must hold an `active` membership in `org_id`; the row records `user_id`.
- **API key** — the key's `organization_id` must equal `org_id`; the row records `api_key_id` and a null `user_id`.

| Field | Type | Constraint | Default |
|---|---|---|---|
| `org_id` | uuid | required | — |
| `metric_key` | string | 1–128 chars | — |
| `quantity` | int | 1–1,000,000 | `1` |
| `source` | enum | `api` \| `ingest` \| `job` \| `internal` \| `migration` | `api` |
| `route` | string | ≥ 1 char | `null` |
| `status_code` | int | 100–599 | `null` |
| `latency_ms` | int | 0–300,000 | `null` |
| `metadata` | object | ≤ 50 top-level keys, ≤ 8,192 bytes as JSON | `{}` |

| Status | Meaning |
|---|---|
| 202 `{ ok: true, request_id }` | stored |
| 400 | body is not JSON |
| 401 | missing, malformed, unknown, revoked or expired credential; JWT without a resolvable user |
| 403 | not a member of `org_id`, or key belongs to another org |
| 422 `{ error: "Validation failed", fieldErrors }` | schema violation |
| 429 `{ error: { message, reason } }` + `Retry-After` | quota exhausted — see [Rate limits](#rate-limits) |
| 500 | insert failed |

Each call is one event and reserves one quota request regardless of `quantity`.

### `POST /v1/ingest/otel`

API-key only; the org comes from the key. Accepts `{ spans: [...] }` (1–1,000 spans, `IngestOtelRequestSchema`) and stores one `usage_events` row with `metric_key = 'otel_events'`, `quantity = spans.length`, `source = 'ingest'` and the spans in `metadata`. Reserves one quota request; returns `202 { ok, request_id, span_count }`.

### Rate limits

Two layers sit in front of handlers:

1. **Edge throttle** — KV plus per-isolate counters: 300 requests/60 s per org on `/v1/orgs/:id/*`, 120 requests/60 s per JWT subject on `/v1/me`, `/v1/me/team`, `/v1/orgs` and `/bootstrap`. This is the ceiling that holds when the quota Durable Object is unreachable.
2. **Quota Durable Object** — one per org (`workers/api-gateway/src/durable-objects/quota.ts`), serialising reservations so concurrent requests cannot double-spend. Limits follow the org's **effective** plan: a paid plan applies only while its billing status is entitled; otherwise starter.

| Plan | Per minute | Per month |
|---|---|---|
| starter | 60 | 10,000 |
| growth | 600 | 500,000 |
| enterprise | 6,000 | unlimited |

The Durable Object **fails open**: if it cannot be reached the request proceeds without quota headers, favouring availability over strict enforcement.

Responses that pass through quota carry:

```
RateLimit-Policy: "minute";q=60;w=60, "month";q=10000
RateLimit: "minute";r=48;t=40, "month";r=9000;t=1339200
X-RateLimit-Remaining-Minute: 48
X-RateLimit-Remaining-Monthly: 9000
```

`q=` is the ceiling, `w=` the window length in seconds (absent for the calendar month), `r=` the remainder and `t=` seconds to reset (month resets at 00:00 UTC on the 1st). Enterprise omits the `month` item. The `X-RateLimit-*` pair is the legacy form. All are listed in `Access-Control-Expose-Headers`. A 429 adds `Retry-After` for the exceeded window.

---

## Provisioning: `sender-worker` → `api-provisioning-receiver`

### Topology and trust boundaries

```
Flutter app ── POST /send (x-session-data: base64 token) ──▶ sender-worker
   untrusted                                                  validates, signs
                                                                  │ RECEIVER service binding
                                    POST /inbox (x-timestamp, x-signature, x-key-id)
                                                                  ▼
                                                    api-provisioning-receiver
                                    key id + signature + timestamp + nonce, Auth0 /userinfo
                                                                  │
                                                                  ▼
                                          api-keys-create → api_keys row + obtool AUTH KV
```

- **The sender is the trust boundary.** The browser never holds a signing key; it sends plain JSON over HTTPS, and the sender signs what it forwards.
- **No public hop.** The sender reaches the receiver through a Cloudflare service binding (`[[services]] binding = "RECEIVER"` in `workers/sender-worker/wrangler.toml`); the receiver has no URL in this path. The dev sender binds the dev receiver.
- **Keys are minted outside this repo.** The receiver calls the `api-keys-create` edge function, which writes the hashed key to `api_keys` and its record to the KV namespace that `obtool-api` and `obtool-ingest` authenticate against.
- **Each mint carries a per-attempt `requestId`** (a UUID in the `api-keys-create` body). The function creates through `create_api_key_for_request`, which claims the id in the same transaction. A receiver that loses the response calls `abandon_api_key_request`, which returns the key that attempt made (or makes a create that has not committed yet fail with 409), and revokes it. After its KV write the function re-reads the key and takes the KV record down if it was revoked in between. Without `requestId` the function inserts directly, as before ([`20261010000000_api_key_requests.sql`](../supabase/migrations/20261010000000_api_key_requests.sql)).
- Provisioning follows Universal Login: the app signs in, calls `GET /v1/orgs`, and routes a user with no org to `/provision`, which issues the first key and creates the org ([Layer 1 flow](TWO_LAYER_AUTH_ARCHITECTURE.md#layer-1-human-identity--auth0-universal-login)).

### `sender-worker` routes

`workers/sender-worker/src/index.ts`; schemas in `src/types.ts`.

| Method | Path | Request | Response |
|---|---|---|---|
| GET | `/health` | — | `{ ok, service: "api-provisioning-sender", version, timestamp }` |
| POST | `/send` | `SendRequestSchema` | receiver's response, passed through |
| POST | `/create-checkout-session` | `{ email, tier }` | `{ checkoutUrl }` |

The Auth0 ROPC routes `/signup`, `/signin` and `/forgot-password` were deleted by [CR49](changelog/1.4/CHANGELOG.md#cr49) and now answer 404.

`/create-checkout-session` is unauthenticated and resolves the org from the email server-side, which is correct only for a single-org user at sign-up. Authenticated callers with a known org use `POST /v1/orgs/:id/checkout-session` on `api-gateway`, where the org comes from a membership-checked path parameter. Neither route accepts an org id in the body.

### `/send` contract

`SendRequestSchema` is a discriminated union on `action`:

```jsonc
{ "action": "provision_api_key", "jwt": "<token>", "name": "my-key", "email": "a@b.com", "org_name": "optional" }
{ "action": "sign_in", "jwt": "<token>", "email": "a@b.com" }
```

- **Token delivery** — `x-session-data` (base64, keeps a raw JWT out of WAF pattern matching), else `body.jwt`, else `Authorization: Bearer`.
- **Plan is server-side state.** No request carries a plan; a `tier` field is accepted and discarded. The key's tier derives from the org's plan.
- **`org_name`** is optional; the receiver otherwise derives it from the email's registrable domain.
- **Success** — `200 { ok: true, token: "obtk_…", keyId, prefix, tier }`. `token` is returned once; `prefix` (first 8 hex digits) is safe to log.

Errors are `{ error, code }`:

| Status | `code` | Origin |
|---|---|---|
| 400 | `UNKNOWN_ACTION`, `INVALID_EMAIL`, `MISSING_FIELDS`, `JSON_PARSE_ERROR` | sender validation |
| 401 | `INVALID_AUTH` | token missing or not JWT-shaped |
| 403 | `FORBIDDEN` | `Origin` not allowed |
| 500 | `SIGNING_KEY_UNRESOLVED` | no usable signing key; nothing is forwarded |
| 500 / 502 | `INTERNAL_ERROR` | binding missing / receiver unreachable |
| receiver's | `QUOTA_EXCEEDED`, `RATE_LIMITED`, `REPLAY_DETECTED`, `INVALID_EMAIL_DOMAIN`, `NOT_IMPLEMENTED`, `RECEIVER_ERROR` | passed through with the receiver's status; the sender adds a `description` for known codes |

`QUOTA_EXCEEDED` is the per-tier key limit: starter 3, growth 10, enterprise unlimited.

### Signed request

| Header | Value |
|---|---|
| `x-timestamp` | milliseconds since epoch |
| `x-signature` | lowercase hex `HMAC-SHA256(SIGNING_KEYS[ACTIVE_KEY_ID], "<timestamp>.<body>")` |
| `x-key-id` | `ACTIVE_KEY_ID`, always present |
| `X-Forwarded-For` | caller's `CF-Connecting-IP` |

The body is the validated payload re-serialised. The receiver accepts it only if:

1. `x-key-id` names an entry in its own `SIGNING_KEYS` — there is no keyless path, so deleting an id revokes it;
2. the signature matches, compared in constant time;
3. the timestamp is within 5 minutes in the past or 30 seconds in the future;
4. the signature has not been seen within that window (nonce in KV);
5. the token is valid at Auth0 `/userinfo` and its email matches the request byte for byte.

An unknown key id and a forged signature produce the same rejection, so key ids cannot be enumerated.

The sender **fails closed**: if `ACTIVE_KEY_ID` is unset, or `SIGNING_KEYS` is unbound, malformed or lacks that id, it returns `SIGNING_KEY_UNRESOLVED` and sends nothing rather than signing with any fallback. Each environment has its own key ids and secrets; production and dev share none. Key setup and rotation: [provisioning-environment-setup.md](provisioning-environment-setup.md).

### CORS

`sender-worker` uses the shared allowlist in `workers/lib/http/cors.ts`, configured by `ALLOWED_ORIGINS_JSON` (never `*`). Preflight returns `204` allowing `GET, POST, OPTIONS` and `content-type, authorization, x-session-data`. A request with a disallowed `Origin` gets `403`; a request without `Origin` (native clients, server-to-server) is not origin-checked. CORS governs browsers only and is not an authorization control.

### Flutter client

`ProvisioningService` (`lib/services/provisioning_service.dart`) is a static client over Dio with test seams (`setDioForTesting`, `retryDelay`) and sealed success/error results.

| Method | Target |
|---|---|
| `sendEvent` | `POST $SENDER_WORKER_URL/send`; retries 500, 504, timeouts and connection errors twice (1 s, 2 s); reads the key from `token` |
| `createCheckoutSession` | `POST $SENDER_WORKER_URL/create-checkout-session` |
| `bootstrap` | `POST $API_GATEWAY_URL/bootstrap` |

Dart request and response shapes are checked against the Workers' Zod schemas by contract tests; see the Testing Strategy in [CLAUDE.md](../CLAUDE.md).

---

## Code map

| Concern | Location |
|---|---|
| api-gateway dispatch | `workers/api-gateway/src/index.ts`, `src/lib/org-routes.ts` |
| Ingestion | `workers/api-gateway/src/routes/ingest.ts`, `workers/lib/types/usage.ts` |
| Quota | `workers/api-gateway/src/durable-objects/quota.ts`, `src/lib/quota.ts`, `src/lib/rate-limit.ts` |
| Usage ledger | `workers/api-gateway/src/lib/usage-ledger.ts`, `supabase/migrations/*usage_buckets*` |
| Sender | `workers/sender-worker/src/index.ts`, `src/types.ts`, `src/utils.ts` |
| Receiver | observability-toolkit `services/api-provisioning-receiver/src/` |
| Shared HTTP / CORS | `workers/lib/http/` |
| Flutter client | `lib/services/provisioning_service.dart`, `lib/models/provisioning_models.dart` |
| Hostname guard | `scripts/check-api-routing.sh`, `workers/lib/deploy-environments.test.ts` |
