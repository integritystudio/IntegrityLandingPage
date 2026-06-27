# API Provisioning Environment Setup Guide

**Last Updated:** 2026-06-26
**Version:** 1.1

This guide covers SHARED_SECRET generation, Flutter app configuration, and troubleshooting for the API provisioning **sender worker**.

> ℹ️ **Scope note.** Sections describing a deployable `receiver-worker`, `RECEIVER_WORKER_URL`, `*.integritystudio.ai` worker hostnames, and `--env staging`/production deploys were **removed** (2026-06-26) — they described a retired HTTP-based wiring. The production receiver is **`api-provisioning-receiver`**, which lives in the separate `observability-toolkit` repo and is reached by `sender-worker` via a **service binding** (`service = "api-provisioning-receiver"` in `workers/sender-worker/wrangler.toml`), not a URL. The live sender is `sender-worker.alyshia-b38.workers.dev` (no custom worker domains exist). This guide also predates the Auth0 ROPC + Supabase flow, so it does **not** cover the required `AUTH0_*` / `SUPABASE_*` sender secrets — see `workers/sender-worker/wrangler.toml` for the current secret list, and the `observability-toolkit` repo for receiver setup. (Stale `receiver-worker` references across the provisioning docs were reconciled to this model — `docs/BACKLOG.md` W03.)

---

## Prerequisites

1. **Cloudflare Account Access**
   - Account ID and API token for automation

2. **CLI Tools**
   ```bash
   npm install -g wrangler          # Cloudflare Workers CLI
   brew install openssl             # For secret generation
   ```

3. **Repository Access**
   - Git credentials configured
   - Write access to IntegrityLandingPage repo (sender) and `observability-toolkit` repo (receiver)

---

## Step 1: Generate Secrets

Generate a cryptographically secure shared secret for HMAC signing:

```bash
# Generate a new SHARED_SECRET (use the same value for both workers in same environment)
openssl rand -base64 32
# Output: AbCdEfGhIjKlMnOpQrStUvWxYz1234567890+/=

# Save this value securely:
# - Development: .env.local (git-ignored)
# - Staging: Cloudflare Secrets Manager
# - Production: Cloudflare Secrets Manager + Vault/1Password backup
```

**Important:** The same `SHARED_SECRET` must be set on both `sender-worker` and `api-provisioning-receiver` for a given environment. (Key rotation is also supported via `SIGNING_KEYS` + `ACTIVE_KEY_ID` with an `x-key-id` header — see `workers/sender-worker/src/utils.ts` and the receiver's `resolveSigningKey`.)

---

## Flutter App Configuration

The Flutter app selects the sender endpoint via a compile-time define, read in `lib/services/provisioning_service.dart`:

```dart
const _senderWorkerUrl = String.fromEnvironment(
  'SENDER_WORKER_URL',
  defaultValue: 'https://sender-worker.alyshia-b38.workers.dev',
);
```

Override it per build with `--dart-define` (URLs below are illustrative — use your actual worker URL):

**Development**
```bash
flutter run -d chrome \
  --dart-define=SENDER_WORKER_URL=http://localhost:8787
```

**Production**
```bash
flutter build web \
  --dart-define=SENDER_WORKER_URL=https://sender-worker.alyshia-b38.workers.dev
```

---

## Troubleshooting

### Common Issues

**1. Signature Mismatch (401 invalid signature)**
```
Cause: SHARED_SECRET differs between sender and receiver
Fix: Verify secrets are identical on both workers
  wrangler secret list (shows secret names, not values)
  Regenerate and re-set both with same value
```

**2. Stale Timestamp (401 stale or invalid timestamp)**
```
Cause: Server clocks out of sync (>5 min drift)
Fix: Check NTP sync on origin servers
     Cloudflare handles NTP automatically, typically not an issue
```

**3. CORS Rejection (403 forbidden)**
```
Cause: Flutter app origin not in ALLOWED_ORIGINS_JSON
Fix: Update sender-worker vars:
  wrangler deploy --var ALLOWED_ORIGINS_JSON='["https://your-origin"]'
```

---

## References

- [API Provisioning Architecture](api-provisioning.md)
- [Client Contract](api-provisioning-contract.md)
- [Inter-Worker Contract Validation](inter-worker-contract-validation.md)
- [Cloudflare Secrets Management](https://developers.cloudflare.com/workers/configuration/secrets/)
- [Cloudflare Environments](https://developers.cloudflare.com/workers/wrangler/environments/)

---

## Support

For issues or questions:
1. Check [Troubleshooting](#troubleshooting) section
2. Review Cloudflare worker logs: `wrangler tail`
3. Verify secret synchronization: `wrangler secret list`
