# API Provisioning Environment Setup Guide

**Last Updated:** 2026-06-27
**Version:** 2.0

This guide covers `SHARED_SECRET` generation, Flutter app configuration, the implementation/security reference, and troubleshooting for the API provisioning **sender worker**.

> ℹ️ **Scope note.** The production receiver is **`api-provisioning-receiver`**, which lives in the separate `observability-toolkit` repo and is reached by `sender-worker` via a **service binding** (`service = "api-provisioning-receiver"` in `workers/sender-worker/wrangler.toml`), not a URL. The live sender is `sender-worker.alyshia-b38.workers.dev` (no custom worker domains exist). Earlier sections describing a deployable in-repo `receiver-worker`, `RECEIVER_WORKER_URL`, `*.integritystudio.ai` worker hostnames, and `--env staging` deploys described a retired HTTP-based wiring and were removed (consolidated 2026-06-27, `docs/BACKLOG.md` W03). This guide predates the Auth0 ROPC + Supabase flow, so it does **not** cover the required `AUTH0_*` / `SUPABASE_*` sender secrets — see `workers/sender-worker/wrangler.toml` for the current secret list, and the `observability-toolkit` repo for receiver setup.

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
# - Production: Doppler (integrity-studio/prd)
```

**Important:** The same `SHARED_SECRET` must be set on both `sender-worker` and `api-provisioning-receiver` for a given environment. Key rotation is also supported via `SIGNING_KEYS` + `ACTIVE_KEY_ID` with an `x-key-id` header — see `workers/sender-worker/src/utils.ts` and the receiver's `resolveSigningKey`. Rotation cadence/policy is tracked as W05 in `docs/BACKLOG.md`.

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

## User Provisioning Workflow

Full data flow for user creation and API key provisioning, by tier.

### Starter (free, no payment)

```
SignupPage (/signup?tier=starter)
  └─→ POST /signup (sender-worker)
        ├─ auth0CreateUser (M2M client credentials → POST /api/v2/users)
        ├─ supabaseCreatePersonalOrg (POST /rest/v1/organizations, current_plan: "starter")
        ├─ supabaseInsertUser (POST /rest/v1/users, auth0_id = auth0Sub)
        ├─ supabaseAddOrgOwner (POST /rest/v1/organization_memberships, role: "owner")
        └─ auth0UserSignIn (ROPC → POST /oauth/token, grant_type: password)
             └─ returns { jwt, auth0Sub, userId, email } 201
  └─→ AuthSuccess(jwt, email) → GoRouter /provision
        └─ ProvisionPage: AuthStorage.saveJwt(jwt)
        └─ POST /send (sender-worker)
              ├─ validates SendRequestSchema {action, jwt, name, email, tier}
              ├─ HMAC-SHA256 signs {x-timestamp}.{body} with SHARED_SECRET
              └─ POST api-provisioning-receiver /inbox (via service binding)
                    ├─ verifies x-timestamp (±5 min) + x-signature constant-time
                    ├─ Auth0 /userinfo (validates JWT live)
                    ├─ Supabase GET /rest/v1/users?auth0_id=eq.{sub} → Supabase UUID
                    ├─ Supabase POST /rest/v1/organizations {domain, type:"team", current_plan:tier}
                    ├─ Supabase POST /rest/v1/organization_memberships
                    └─ Supabase Edge Fn POST /functions/v1/api-keys-create
                         └─ returns { token: /obtk_[0-9a-f]{64}/, keyId, prefix, tier }
  └─→ "Go to Dashboard" → window.open(integritystudio.dev?access_token=<jwt>)
```

### Growth (paid, Stripe checkout)

```
SignupPage (/signup?tier=growth)
  └─→ POST /signup (sender-worker) — same Auth0 + Supabase steps as starter
        └─ returns { jwt, auth0Sub, userId, email } 201
  └─→ AuthSuccess → GoRouter /checkout (CheckoutArgs{email, tier})
        └─ CheckoutPage: POST /create-checkout-session (sender-worker)
              ├─ validates CreateCheckoutSessionSchema {email, tier}
              ├─ looks up priceId from STRIPE_PLAN_TO_PRICE_JSON[tier]
              └─ POST https://api.stripe.com/v1/checkout/sessions
                    mode: subscription, line_items[0][price]: priceId
                    success_url: {APP_BASE_URL}/checkout-success?email=...&tier=...
                    cancel_url:  {APP_BASE_URL}/signup?tier=...
                    └─ returns { checkoutUrl }
        └─ window.location.href = checkoutUrl (browser leaves app → Stripe hosted page)
  └─→ Stripe payment complete → /checkout-success?email=&tier=
        └─ CheckoutSuccessPage: "Sign In to Activate" → /signin
  └─→ User signs in → /provision → same provision flow as starter
        (Stripe webhook separately: checkout.session.completed + customer.subscription.updated
         → updateOrgBillingStatus(org, "active", "growth", bumpQuota=true)
         → quota_version bumped → Quota DO resets limits to growth tier on next API request)
```

### Enterprise (contact sales, no provisioning)

```
SignupPage (/signup?tier=enterprise)
  └─→ ContactService.submitForm() → POST contact-form worker
        ├─ CSRF validation, KV rate limiting, idempotency check
        └─ Resend API → sends email to sales team
  └─→ GoRouter /request_success (no Auth0 user, no Supabase row, no API key)
```

### Key Boundaries

| Concern | Where |
|---|---|
| Auth0 user creation | sender-worker `auth0CreateUser` (M2M grant) |
| Supabase provisioning (signup) | sender-worker `handleSignup` (inline, pre-webhook) |
| JWT issuance | sender-worker `auth0UserSignIn` (ROPC) |
| JWT persistence | `AuthStorage.saveJwt` → `localStorage['auth_jwt']` |
| API key creation | api-provisioning-receiver → Supabase Edge Fn `api-keys-create` |
| Plan upgrade (Stripe → Supabase) | stripe-webhook worker `updateOrgBillingStatus` |
| Quota enforcement | api-gateway `enforceOrgQuota` + Quota Durable Object |

---

## Current Configuration Model

### Development (Local)
```
.env.local (git-ignored)
└── SHARED_SECRET: test-secret-key-12345

# For local stub testing, run workers/receiver-worker/ separately (see its README).
# The production sender reaches the receiver via the RECEIVER service binding.
```

### Production
```
Cloudflare Secrets (via Doppler integrity-studio/prd):
├── sender-worker (this repo):                                 SHARED_SECRET
└── api-provisioning-receiver (observability-toolkit repo):    SHARED_SECRET (MUST match)

sender-worker/wrangler.toml:
├── [[services]] binding = "RECEIVER", service = "api-provisioning-receiver"
└── (optional) ALLOWED_ORIGINS_JSON = ["https://www.integritystudio.ai"]
```

---

## Implementation Reference

### CORS (Environment-Aware)
- Production origins: `https://integritystudio.ai`, `https://www.integritystudio.ai`
- Development origins: `http://localhost:<port>` (configurable)
- Configurable via the `ALLOWED_ORIGINS_JSON` environment variable
- Proper OPTIONS preflight handling; 403 rejection for disallowed origins

### HMAC-SHA256 Signing
- Message format: `{timestamp}.{body}`
- Hex-encoded signature (lowercase, zero-padded)
- Constant-time comparison in receiver
- Shared secret managed via wrangler secrets / Doppler

### Replay Protection
- 5-minute timestamp window (configurable constant)
- Validates timestamp freshness on every request (±5 min)
- Non-numeric timestamp rejection

### Error Handling
- Consistent error response format: `{ error: string }`
- Proper HTTP status codes (400, 401, 403, 404, 500, 502)
- All responses include `Content-Type: application/json; charset=utf-8`

---

## Security Checklist

- ✅ HMAC-SHA256 with 256-bit random secrets
- ✅ Secrets stored in Doppler (`integrity-studio/prd`), never in code
- ✅ CORS validation (no wildcard origins)
- ✅ Timestamp replay protection (±5 minutes)
- ✅ Constant-time signature comparison
- ✅ HTTPS-only (enforced by Cloudflare)
- ✅ Content-Type validation (`application/json`)
- ✅ Secret rotation mechanism shipped (`SIGNING_KEYS`/`ACTIVE_KEY_ID`/`x-key-id`); cadence/policy tracked as W05
- ⚠️ Monitoring and alerting — tracked as W04 in `docs/BACKLOG.md`

---

## Troubleshooting

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

**4. Receiver Unreachable (502)**
```
Cause: RECEIVER service binding missing or api-provisioning-receiver not deployed
Fix: Check [[services]] binding in workers/sender-worker/wrangler.toml
     and confirm api-provisioning-receiver is deployed (observability-toolkit repo)
```

---

## References

- [API Provisioning Architecture](api-provisioning.md)
- [Client & Inter-Worker Contracts](inter-worker-contract-validation.md)
- [Provisioning Manual E2E Test Guide](PROVISIONING_MANUAL_TEST.md)
- [Sender Worker README](../workers/sender-worker/README.md)
- [Cloudflare Secrets Management](https://developers.cloudflare.com/workers/configuration/secrets/)

---

## Support

For issues or questions:
1. Check the [Troubleshooting](#troubleshooting) section
2. Review Cloudflare worker logs: `wrangler tail`
3. Verify secret synchronization: `wrangler secret list`
