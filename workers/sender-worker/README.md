# Sender Worker

Cloudflare Worker that forwards signed requests to the Receiver Worker as part of the API provisioning architecture. Implements HMAC-SHA256 request signing for inter-service authentication.

## Purpose

The Sender Worker acts as a trusted proxy between the Flutter app and the Receiver Worker:

1. **Flutter app** → (plain HTTPS) → **Sender Worker** (trusts app, signs request)
2. **Sender Worker** → (signed HTTPS) → **Receiver Worker** (verifies signature)

Flutter never holds the inter-service shared secret; the Sender Worker signs requests before forwarding.

## API

### POST /send

Accepts JSON from the Flutter app, signs it with HMAC-SHA256, and forwards to the Receiver Worker.

**Request:**
```bash
curl -X POST https://sender-worker.example.workers.dev/send \
  -H "Content-Type: application/json" \
  -d '{"userId":"user123","action":"signup"}'
```

**Response (200 OK):**
```json
{
  "ok": true,
  "received": {
    "userId": "user123",
    "action": "signup"
  }
}
```

**Error Responses:**
- `400` - Invalid JSON body
- `500` - RECEIVER service binding not configured, or `SIGNING_KEY_UNRESOLVED` (see Secrets)
- `502` - Receiver Worker unreachable

## Configuration

### Environment Variables

```toml
[vars]
RECEIVER_WORKER_URL = "https://receiver-worker.example.workers.dev"
```

### Secrets

```bash
wrangler secret put SIGNING_KEYS    # {"v2":"<secret>"} — must match the receiver's map exactly
wrangler secret put ACTIVE_KEY_ID   # which entry to sign with, e.g. v2
```

Both are required. `ACTIVE_KEY_ID` is sent as `x-key-id` and the receiver rejects a request
without it, so an unset or unresolvable pair is a hard failure: `/send` returns 500
`SIGNING_KEY_UNRESOLVED` and forwards nothing rather than downgrading to another credential.
The cause is in the worker logs, never in the response — a caller must not learn which key id
the operator meant to use.

`SHARED_SECRET` is the legacy pre-rotation key. **Nothing reads it** (CR29 step 2); it stays
bound only until the receiver's `auth.key_unresolved` telemetry confirms no caller still signs
keylessly. Do not add a fallback to it.

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
| CORS | Not needed (Worker-to-Worker, no browser) |

## Testing

```bash
npm test              # Run once
npm run test:watch    # Watch mode
```

Tests use `vitest` with mocked `fetch` to verify:
- Valid request signing and forwarding
- Signature computation matches receiver verification
- Error handling (network, config, JSON validation)
- Status code pass-through from receiver

## Deployment

### Quick Start (Development)
```bash
wrangler deploy
```

### Multi-Environment Deployment
For staging and production setup, see [Environment Setup Guide](../../docs/provisioning-environment-setup.md).

**Key Steps:**
1. Generate a signing key: `openssl rand -base64 32`
2. Add it to the **receiver's** `SIGNING_KEYS` under a new key id and deploy the receiver first,
   then set the same `SIGNING_KEYS` entry plus `ACTIVE_KEY_ID` here
3. Update RECEIVER_WORKER_URL in wrangler.toml
4. Deploy: `wrangler deploy`
5. Verify: `curl https://receiver-worker.integritystudio.ai/health`

Then update the Flutter provisioning service with the deployed Sender Worker URL.

## CORS Configuration

The Sender Worker enforces CORS for browser-based requests. Configure allowed origins:

```toml
# In wrangler.toml (optional, defaults to production origin)
ALLOWED_ORIGINS_JSON = '["https://www.integritystudio.ai"]'
```

Or deploy with vars:
```bash
wrangler deploy --var ALLOWED_ORIGINS_JSON='["https://staging.integritystudio.ai","https://www.integritystudio.ai"]'
```

**CORS Handling:**
- OPTIONS preflight returns 204 with headers (if origin allowed)
- POST from disallowed origin returns 403 forbidden
- Requests without Origin header (server-to-server) pass through unchanged

## References

- [docs/api-provisioning.md](../../docs/api-provisioning.md) — Architecture overview
- [docs/inter-worker-contract-validation.md](../../docs/inter-worker-contract-validation.md) — Client contract + worker compatibility
- [docs/provisioning-environment-setup.md](../../docs/provisioning-environment-setup.md) — **Environment setup guide** ⭐
- [workers/receiver-worker/](../receiver-worker/) — Receiver endpoint (verifies signatures)
- [workers/constants.ts](../constants.ts) — Shared constants (JSON_CONTENT_TYPE, REPLAY_WINDOW_MS)
- [workers/cors-utils.ts](../cors-utils.ts) — CORS helper functions
