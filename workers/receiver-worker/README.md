# Receiver Worker

> ⚠️ **Local stub / test double only — NOT the production receiver.**
> This worker returns mock responses and is **not deployed**; nothing binds to it.
> The production receiver is **`api-provisioning-receiver`**, which lives in the
> separate `observability-toolkit` repo (`services/api-provisioning-receiver/`),
> persists to Supabase, and is the target of `sender-worker`'s service binding
> (`service = "api-provisioning-receiver"` in `workers/sender-worker/wrangler.toml`).
> The deploy steps and `*.integritystudio.ai` URLs below describe a retired setup —
> do not follow them to deploy this stub. They are retained only as reference for
> the shared signature/replay contract this stub mirrors.

Cloudflare Worker that verifies signed requests from the Sender Worker as part of the API provisioning architecture. Implements HMAC-SHA256 signature verification and replay protection.

## Purpose

The Receiver Worker acts as the trusted endpoint for the provisioning pipeline:

1. **Sender Worker** → (signed request with x-timestamp, x-signature headers) → **Receiver Worker**
2. **Receiver Worker** → (verifies signature, validates timestamp freshness) → stores data / returns response

The Sender Worker is the trust boundary; this worker verifies that all requests come from the legitimate Sender using the shared secret.

## API

### GET /health

Public health check endpoint (no authentication required).

**Request:**
```bash
curl https://receiver-worker.integritystudio.ai/health
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

**Request Body:**
```json
{
  "userId": "user123",
  "action": "signup",
  "sentAt": "2026-03-20T10:15:30.000Z"
}
```

**Response (200 OK):**
```json
{
  "ok": true,
  "received": {
    "userId": "user123",
    "action": "signup",
    "sentAt": "2026-03-20T10:15:30.000Z"
  }
}
```

**Error Responses:**
- `400 invalid json` — Request body is not valid JSON
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

`SHARED_SECRET` is **no longer read for authentication** — CR29 step 2 made `SIGNING_KEYS`
the sole authority. It stays declared in `Env` only so the tests can prove a keyless request
is rejected with the credential still present, which is production's state until CR29 step 3
unbinds it.

## Security Model

| Concern | Implementation |
|---------|-----------------|
| Signature verification | HMAC-SHA256 over `{timestamp}.{body}` — constant-time comparison |
| Replay protection | Timestamp window ±5 minutes (REPLAY_WINDOW_MS = 300,000 ms) |
| Secret storage | Wrangler secrets (never logged or exposed) |
| Inter-service auth | Only signed requests from Sender Worker accepted |

## Deployment

```bash
wrangler deploy
```

Then configure the Sender Worker with the Receiver Worker URL:
```bash
# In sender-worker/wrangler.toml:
[vars]
RECEIVER_WORKER_URL = "https://receiver-worker.integritystudio.ai"
```

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

Test the flow:
```bash
# This creates a proper HMAC signature and forwards it
curl -X POST http://localhost:8787/send \
  -H "Content-Type: application/json" \
  -d '{"userId":"test","action":"verify"}'
```

### Monitoring

**Check health endpoint:**
```bash
curl https://receiver-worker.integritystudio.ai/health
```

**View logs:**
```bash
wrangler tail
```

**Verify signature validation success rate:**
- Check Cloudflare Analytics dashboard for POST /inbox endpoint
- Look for 200 vs 401 status code ratio

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

See [docs/api-provisioning.md](../../docs/api-provisioning.md) for complete architecture overview.

## References

- [API Provisioning Architecture](../../docs/api-provisioning.md)
- [Client & Inter-Worker Contracts](../../docs/inter-worker-contract-validation.md)
- [Environment Setup Guide](../../docs/provisioning-environment-setup.md)
- [Sender Worker](../sender-worker/README.md)
- [Shared Constants](../constants.ts)
