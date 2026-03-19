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
- `500` - Receiver Worker URL or shared secret not configured
- `502` - Receiver Worker unreachable

## Configuration

### Environment Variables

```toml
[vars]
RECEIVER_WORKER_URL = "https://receiver-worker.example.workers.dev"
```

### Secrets

```bash
wrangler secret put SHARED_SECRET
```

Must match the `SHARED_SECRET` in the Receiver Worker for signature verification to succeed.

## Security Model

| Concern | Implementation |
|---------|-----------------|
| Inter-service auth | HMAC-SHA256 signature over `timestamp.body` |
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

```bash
wrangler deploy
```

Then update the Flutter provisioning service with the deployed URL.

## References

- [docs/api-provisioning.md](../../docs/api-provisioning.md) — Architecture overview
- [workers/receiver-worker/](../receiver-worker/) — Receiver endpoint (verifies signatures)
- [workers/constants.ts](../constants.ts) — Shared constants (JSON_CONTENT_TYPE, REPLAY_WINDOW_MS)
