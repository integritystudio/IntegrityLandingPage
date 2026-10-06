# Receiver Worker

> ⚠️ **Local stub / test double only — NOT the production receiver.**
> This worker returns mock responses and is **not deployed**; nothing binds to it.
> The production receiver is **`api-provisioning-receiver`**, which lives in the
> separate `observability-toolkit` repo (`services/api-provisioning-receiver/`),
> persists to Supabase, and is the target of `sender-worker`'s service binding
> (`service = "api-provisioning-receiver"` in `workers/sender-worker/wrangler.toml`).
> Its `deploy` scripts were removed 2026-09-24 and `workers/lib/deploy-environments.test.ts`
> asserts their absence — the Worker of this name was deleted from Cloudflare on 2026-06-26
> and a deploy would recreate the orphan. Run it only locally with `wrangler dev`.

Cloudflare Worker that verifies signed requests from the Sender Worker as part of the API provisioning architecture. Implements HMAC-SHA256 signature verification and replay protection.

## Purpose

The Receiver Worker acts as the trusted endpoint for the provisioning pipeline:

1. **Sender Worker** → (signed request with x-timestamp, x-signature headers) → **Receiver Worker**
2. **Receiver Worker** → (verifies signature, validates timestamp freshness) → stores data / returns response

The Sender Worker is the trust boundary; this worker verifies that all requests come from the legitimate Sender using the `SIGNING_KEYS` entry named by the request's `x-key-id`.

## API

### GET /health

Public health check endpoint (no authentication required).

**Request (against a local `wrangler dev --port 8788`):**
```bash
curl http://localhost:8788/health
```

**Response (200 OK):**
```json
{
  "ok": true,
  "service": "receiver-worker"
}
```

**Use case:** Liveness checks, monitoring, pre-request validation.

### POST /inbox

Receive and verify signed requests from the Sender Worker.

**Request Headers (Required):**
- `x-timestamp` — Milliseconds since epoch when sender created signature
- `x-signature` — HMAC-SHA256 signature (hex string)
- `x-key-id` — Which `SIGNING_KEYS` entry the signature was made with. Required: a
  request without it is rejected, whatever its signature (BACKLOG.md CR29 step 2)
- `Content-Type` — application/json

**Request Body:** a JSON object whose `action` is one of the two the sender forwards,
`provision_api_key` or `sign_in` (anything else is `400 unknown action`):
```json
{
  "action": "provision_api_key",
  "jwt": "<Auth0 access token>",
  "name": "My first key",
  "email": "user@example.com",
  "tier": "starter"
}
```

**Response (200 OK)** for `provision_api_key` — a mock key plus the payload echoed back:
```json
{
  "ok": true,
  "apiKey": "sk-<random>",
  "received": { "action": "provision_api_key", "jwt": "…", "name": "My first key", "email": "user@example.com", "tier": "starter" }
}
```
For `sign_in` the stub returns `{ "ok": true, "user": { "userId": "<random>", "email": "…" }, "organizations": [], "apiKeys": [] }`.
Nothing is persisted — the production receiver writes to Supabase, this stub does not.

**Error Responses:**
- `400 invalid json` — Request body is not valid JSON
- `400 invalid payload` — Body is not a JSON object
- `400 unknown action` — `action` missing or not one of the two above
- `401 missing auth headers` — x-timestamp or x-signature header missing
- `401 stale or invalid timestamp` — Timestamp outside ±5 minute window or non-numeric
- `401 invalid signature` — Signature verification failed, **or** `x-key-id` was absent,
  empty, or unknown. Deliberately one response for all of them, so valid key ids cannot be
  enumerated by diffing responses; the production receiver distinguishes them in telemetry
- `404 not found` — Unknown route

## Configuration

### Environment Variables

None required for basic operation (only the secrets below).

### Secrets

```bash
wrangler secret put SIGNING_KEYS     # {"v2":"<secret>"} — keyId → secret
```

**CRITICAL:** the `SIGNING_KEYS` entry named by the sender's `ACTIVE_KEY_ID` must match the
sender's secret for that key id exactly. If they differ, all requests fail 401 "invalid
signature".

`SHARED_SECRET` is **retired** — CR29 made `SIGNING_KEYS` the sole authority, and the
production receiver unbound it on 2026-08-03 (CR29 closed). It stays declared in `Env`, and
set in the test fixtures, only so the tests can prove a keyless request is rejected even with
the credential present: "unreachable" rather than merely "absent". Do not tidy it out.

## Security Model

| Concern | Implementation |
|---------|-----------------|
| Signature verification | HMAC-SHA256 over `{timestamp}.{body}` — constant-time comparison |
| Replay protection | Timestamp window ±5 minutes (REPLAY_WINDOW_MS = 300,000 ms) |
| Secret storage | Wrangler secrets (never logged or exposed) |
| Inter-service auth | Only signed requests from Sender Worker accepted |

## Deployment

**None.** This package has no `deploy` or `deploy:prd` script, on purpose. The production
receiver is `api-provisioning-receiver`, deployed from the observability-toolkit repo, and the
sender reaches it through the `RECEIVER` service binding in `workers/sender-worker/wrangler.toml`
(`api-provisioning-receiver-dev` under `[env.dev]`). There is no receiver URL variable anywhere.

## Testing

```bash
npm test              # Run once
npm run test:watch    # Watch mode
```

Tests use `vitest` to verify:
- Valid signature verification
- Timestamp freshness validation
- Replay protection (stale timestamps rejected)
- Error handling (missing headers, invalid JSON)
- Content-Type headers

## Development

### Local Testing

Start the receiver in one terminal:
```bash
wrangler dev --port 8788
```

Start the sender in another terminal:
```bash
cd ../sender-worker
wrangler dev --port 8787
```

Test the flow (the sender validates the body against `SendRequestSchema` before signing, so
`action` must be `provision_api_key` or `sign_in` and `jwt` must be JWT-shaped):
```bash
curl -X POST http://localhost:8787/send \
  -H "Content-Type: application/json" \
  -d '{"action":"sign_in","jwt":"<any three dot-separated base64url segments>","email":"test@example.com"}'
```

`/send` only reaches this stub if the sender's `RECEIVER` service binding resolves to it, which
means running both Workers under wrangler's multi-worker local dev rather than two independent
`wrangler dev` sessions. That wiring is not documented in this repo; with the binding
unresolved the sender returns 500 `RECEIVER service binding not configured`.

### Monitoring

There is nothing to monitor here — this stub is never deployed. The production receiver's
signals (`auth.key_unresolved`, replay rejections, provisioning outcomes) are documented in
the observability-toolkit repo and in `docs/observability-signals.md`.

## Common Issues

### 401 "invalid signature"
**Causes:** `x-key-id` absent, empty, or not a key in `SIGNING_KEYS`; or the secret for that
key id differs between the two workers. All four return the same response, so check the
header before suspecting the secret.
**Fix:** confirm the sender sends `x-key-id`, then align the secret for that id
```bash
# Generate new secret
openssl rand -base64 32

# Update both workers, same keyId → same secret
wrangler secret put SIGNING_KEYS   # receiver: {"v2":"<secret>"}
# Then on sender-worker: SIGNING_KEYS with the same entry, and ACTIVE_KEY_ID=v2
```

### 401 "stale or invalid timestamp"
**Cause:** Timestamp outside ±5 minute window (unlikely if Sender is working correctly)
**Fix:** Check server clocks are NTP-synchronized (Cloudflare handles this automatically)

### 400 "invalid json"
**Cause:** Request body is malformed JSON
**Fix:** Validate JSON before sending (check Sender Worker is not truncating body)

## Architecture

See [docs/api-reference.md](../../docs/api-reference.md#provisioning-sender-worker--api-provisioning-receiver) for the full provisioning contract.

## References

- [API reference § Provisioning](../../docs/api-reference.md#provisioning-sender-worker--api-provisioning-receiver)
- [Environment Setup Guide](../../docs/provisioning-environment-setup.md)
- [Sender Worker](../sender-worker/README.md)
- [Shared Constants](../constants.ts)
