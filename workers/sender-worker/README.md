# Sender Worker

Cloudflare Worker (`api-provisioning-sender`, deployed as `sender-worker`) that fronts the Flutter app for account provisioning. It has two distinct paths:

- **Inline (no receiver):** `POST /signup`, `POST /signin` and `POST /forgot-password` talk to Auth0 and Supabase directly.
- **Forwarded to the receiver:** `POST /send` events are HMAC-SHA256-signed and forwarded to the production receiver `api-provisioning-receiver` over the `RECEIVER` service binding, which is where API keys are minted.

`POST /create-checkout-session` opens a Stripe Checkout session, and `GET /health` reports liveness and the deployed version.

## Purpose

For the forwarded path the Sender Worker is the trust boundary between the Flutter app and the receiver:

1. **Flutter app** → (plain HTTPS, origin-gated) → **Sender Worker** (validates, signs the request)
2. **Sender Worker** → (signed request over the `RECEIVER` service binding) → **api-provisioning-receiver** (verifies the signature, mints the key)

Flutter never holds the inter-service signing keys; the Sender Worker signs requests before forwarding.

## API

Every schema below lives in `src/types.ts`; the route constants are `ROUTES` in the same file.

| Method | Route | Body | Notes |
|---|---|---|---|
| GET | `/health` | — | `{ ok, service, version, timestamp }` |
| POST | `/signup` | `{ email, password, tier? }` | Creates the Auth0 user and the Supabase org, user and owner membership inline, then signs in via Auth0 ROPC. `tier` (default `starter`) is written to the org's `current_plan` **unverified** — BACKLOG.md CR37 |
| POST | `/signin` | `{ email, password }` | Auth0 ROPC → `{ jwt, email }` |
| POST | `/forgot-password` | `{ email }` | Triggers Auth0's change-password email; always 200 so accounts cannot be enumerated |
| POST | `/send` | `SendRequestSchema` (below) | Signed and forwarded to the receiver |
| POST | `/create-checkout-session` | `CreateCheckoutSessionSchema`: `{ email, tier }` | Returns `{ checkoutUrl }`. The org is derived server-side from the email — never from the body |

`/signup` and `/signin` are rate-limited per client IP (`AUTH_RATE_LIMIT_MAX` per `AUTH_RATE_LIMIT_WINDOW_SECONDS`, cross-isolate via the `RATE_LIMIT_KV` binding).

### POST /send

The body is a discriminated union on `action`:

```json
{
  "action": "provision_api_key",
  "jwt": "<Auth0 access token>",
  "name": "My first key",
  "email": "user@example.com",
  "tier": "starter",
  "org_name": "Example Inc"
}
```

`tier` falls back to `starter` when absent or unrecognised. `org_name` is optional: when it is missing the receiver derives the team org name from the email's registrable domain, which is more accurate than anything a client can send for subdomain addresses. The other action is `sign_in`: `{ "action": "sign_in", "jwt": "…", "email": "…" }`.

The JWT is taken from, in order: a base64-wrapped `x-session-data` header, the body's `jwt` field, then an `Authorization: Bearer` header.

**Response:** the receiver's status and body are passed through; error bodies are enriched with an `ERROR_CODE` and description.

**Error responses (from this Worker, before anything is forwarded):**
- `400` — invalid JSON, unknown `action`, invalid `email`, or missing fields
- `401` — `jwt` missing or not JWT-shaped
- `500` — `RECEIVER` service binding not configured, or `SIGNING_KEY_UNRESOLVED` (see Secrets)
- `502` — receiver unreachable

## Configuration

### Service binding

```toml
[[services]]
binding = "RECEIVER"
service = "api-provisioning-receiver"   # production; [env.dev] repeats this with api-provisioning-receiver-dev
```

There is no receiver URL variable — `/send` calls `env.RECEIVER.fetch(...)`. `services` is not inherited by a named environment, so `[env.dev]` repeats the block with the dev receiver; `../lib/deploy-environments.test.ts` asserts that a dev environment never binds a production service.

### Secrets

Set per Worker with `wrangler secret put` (add `--env dev` for `sender-worker-dev`). The full list, with the history that explains each entry, is the comment block at the bottom of `wrangler.toml`.

```bash
wrangler secret put SIGNING_KEYS    # {"v2":"<secret>"} — must match the receiver's map exactly
wrangler secret put ACTIVE_KEY_ID   # which entry to sign with, e.g. v2
```

Both are required. `ACTIVE_KEY_ID` is sent as `x-key-id` and the receiver rejects a request
without it, so an unset or unresolvable pair is a hard failure: `/send` returns 500
`SIGNING_KEY_UNRESOLVED` and forwards nothing rather than downgrading to another credential.
The cause is in the worker logs, never in the response — a caller must not learn which key id
the operator meant to use.

`SHARED_SECRET` is retired (BACKLOG.md CR29, closed 2026-08-03): nothing reads it, it is
unbound from both Workers, and it is deleted from Doppler. The test fixtures still set it, with a
value different from the active key, so the suites prove that signing ignores it while it is
present. Do not add a fallback to it, and do not tidy the fixture out.

Rotation order is load-bearing: add the new key to the **receiver's** `SIGNING_KEYS` and deploy
that first, then set `ACTIVE_KEY_ID` here. The reverse order sends a key id the receiver does not
recognise, which it rejects with a 401 indistinguishable from a forged signature.

## Security Model

| Concern | Implementation |
|---------|-----------------|
| Inter-service auth | HMAC-SHA256 signature over `timestamp.body`, keyed by `x-key-id` |
| Key rotation | `SIGNING_KEYS` map + `ACTIVE_KEY_ID`; every request carries its key id, so removing an entry revokes it |
| Replay protection | Receiver validates 5-minute timestamp window |
| Secret storage | Wrangler secrets (never in Flutter) |
| Browser origin gate | A request carrying an `Origin` not on the allowlist gets 403; origin-less callers (native app, curl) pass — see CORS Configuration |

## Testing

```bash
npm test              # unit tests (vitest, mocked fetch)
npm run test:watch    # watch mode
npm run test:e2e      # workerd runtime, every outbound call mocked; bindings live in vitest.e2e.config.mts, not Doppler
npm run test:live     # real Auth0 Management API calls against the PRODUCTION tenant — read CLAUDE.md before running
```

The unit and e2e suites verify:
- Request signing and forwarding, including that `x-key-id` reaches the wire in the real runtime
- Signature computation matches receiver verification
- Error handling (network, config, JSON validation, Auth0 and Supabase failures)
- Status code pass-through from the receiver
- The origin gate (preflight, disallowed origin, origin-less passthrough)

## Deployment

```bash
npm run deploy        # wrangler deploy --env dev → sender-worker-dev (Doppler `dev` token)
npm run deploy:prd    # wrangler deploy           → sender-worker, the live Worker (Doppler `prd` token)
```

A bare `wrangler deploy` uses the top-level config, which is **production**. Production also
deploys from CI on every merge to `main`, so a manual `deploy:prd` is rolled back by the next CI
run from a stale `main` — merge promptly after one.

### Key rotation

1. Generate a signing key: `openssl rand -base64 32`
2. Add it to the **receiver's** `SIGNING_KEYS` under a new key id and deploy the receiver first
   (observability-toolkit, `services/api-provisioning-receiver`)
3. Set the same `SIGNING_KEYS` entry plus `ACTIVE_KEY_ID` here
4. Update `KEY_ROTATION_DATES` on the receiver, or the new key ages without triggering the rotation alert
5. Verify `GET /health` on this Worker, then exercise `/send`

The Flutter app reaches this Worker through the compile-time default in
`lib/services/provisioning_service.dart`; override it with `--dart-define=SENDER_WORKER_URL=…`.

## CORS Configuration

The Worker gates browser requests on the `Origin` header. Allowed by default are the
`integritystudio.ai` origins hard-coded in `src/index.ts` plus any
`https://*.integritystudio-ai-c1a.pages.dev` preview origin. Replace the fixed list with the
`ALLOWED_ORIGINS_JSON` secret, a JSON array of origins:

```bash
wrangler secret put ALLOWED_ORIGINS_JSON --env dev   # e.g. '["https://staging.example.com"]'
```

**Handling:**
- OPTIONS preflight returns 204, with `access-control-allow-origin` only when the origin is allowed
- A request from a disallowed origin returns 403
- Requests without an `Origin` header (server-to-server, native) pass through unchanged — which is
  why `/create-checkout-session` must never trust a caller-supplied org id

## References

- [docs/api-provisioning.md](../../docs/api-provisioning.md) — Architecture overview
- [docs/inter-worker-contract-validation.md](../../docs/inter-worker-contract-validation.md) — Client contract + worker compatibility
- [docs/provisioning-environment-setup.md](../../docs/provisioning-environment-setup.md) — Environment setup guide
- [workers/receiver-worker/](../receiver-worker/) — Local stub / test double of the receiver (production lives in observability-toolkit)
- [workers/constants.ts](../constants.ts) — Shared constants (`REPLAY_WINDOW_MS`, dead-letter and rate-limit defaults)
- [workers/lib/deploy-environments.test.ts](../lib/deploy-environments.test.ts) — The deploy-safety invariants this config must satisfy
