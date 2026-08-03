# API Provisioning Environment Setup Guide

**Last Updated:** 2026-07-31 (rotation procedure rewritten — correct `SIGNING_KEYS` wire format, receiver-first ordering, split into Procedure A/B; see [CR29](BACKLOG.md#cr29))
**Version:** 2.1

This guide covers HMAC signing-key generation (`SIGNING_KEYS` + `ACTIVE_KEY_ID`, and the legacy `SHARED_SECRET`), Flutter app configuration, the implementation/security reference, and troubleshooting for the API provisioning **sender worker**.

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

Generate a cryptographically secure signing key for HMAC:

```bash
# Generate a new signing key -- the same value goes in BOTH workers' SIGNING_KEYS
# under the same key id, e.g. {"v3": "<value>"}
openssl rand -base64 32
# Output: AbCdEfGhIjKlMnOpQrStUvWxYz1234567890+/=

# Save this value securely:
# - Development: .env.local (git-ignored)
# - Production: Doppler (integrity-studio/prd)
```

**Important — provision `SIGNING_KEYS` + `ACTIVE_KEY_ID`, not `SHARED_SECRET`, for anything new.** The keyed path is the production path: the sender signs with `SIGNING_KEYS[ACTIVE_KEY_ID]` and sends `x-key-id`, and the receiver resolves the matching entry (`workers/sender-worker/src/utils.ts` `resolveOutboundSigningKey`, receiver `resolveSigningKey`). Both sides need the same id → secret pair; `SIGNING_KEYS` is a JSON object, format detailed under Rotation Procedure below.

`SHARED_SECRET` still has to match on both workers **for the deployed receiver only**. CR29 step 2 (2026-08-02, unshipped) removed the keyless fallback, so once it ships the receiver reads `SIGNING_KEYS` alone and this secret authenticates nothing. Rotation cadence/policy is tracked as W05 in `docs/BACKLOG.md`.

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
        ├─ auth0UserSignIn (ROPC → POST /oauth/token, grant_type: password)
        └─ supabaseAddOrgOwner (POST /rest/v1/organization_memberships, role: "owner")
             └─ returns { jwt, auth0Sub, userId, email } 201
  └─→ AuthSuccess(jwt, email) → GoRouter /provision
        └─ ProvisionPage: AuthStorage.saveJwt(jwt)
        └─ POST /send (sender-worker)
              ├─ validates SendRequestSchema {action, jwt, name, email, tier}
              ├─ HMAC-SHA256 signs {x-timestamp}.{body} with SIGNING_KEYS[ACTIVE_KEY_ID]
              │    (500 SIGNING_KEY_UNRESOLVED, forwarding nothing, if that does not resolve)
              └─ POST api-provisioning-receiver /inbox (via service binding), sending x-key-id
                    ├─ resolves x-key-id → SIGNING_KEYS entry; no key id = 401, no fallback
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
.env.local (git-ignored) -- template at workers/sender-worker/.env.example
├── SIGNING_KEYS: {"v2":"test-secret-key-12345"}
├── ACTIVE_KEY_ID: v2
└── SHARED_SECRET: test-secret-key-12345   # not read; present only to mirror production

# Both signing vars are required: ACTIVE_KEY_ID is sent as x-key-id and the receiver
# rejects a request without it, so an unset pair means /send returns 500 and forwards
# nothing (CR29 steps 1-2).
# For local stub testing, run workers/receiver-worker/ separately (see its README).
# The production sender reaches the receiver via the RECEIVER service binding.
```

### Production
```
Cloudflare Secrets (via Doppler integrity-studio/prd):
├── sender-worker (this repo):                                 SIGNING_KEYS + ACTIVE_KEY_ID (v2), SHARED_SECRET
└── api-provisioning-receiver (observability-toolkit repo):    SIGNING_KEYS (MUST contain the same id → secret),
                                                              KEY_ROTATION_DATES, SHARED_SECRET

# SHARED_SECRET is listed last on purpose: it is the legacy credential. The deployed
# receiver still accepts it (keyless), so it must still match; CR29 step 2 removes that
# and step 3 unbinds it. Nothing new should be wired to it.

sender-worker/wrangler.toml:
├── [[services]] binding = "RECEIVER", service = "api-provisioning-receiver"
└── (optional) ALLOWED_ORIGINS_JSON = ["https://www.integritystudio.ai"]
```

---

## Secret Durability and Rotation

### System of Record

**Doppler (`integrity-studio/prd`) is the authoritative source** for all provisioning secrets. Worker runtime secrets are **not** automatically drawn from Doppler — `wrangler deploy` does not promote Doppler values into Worker secrets; they are set per-worker with `wrangler secret put`. The two sets differ today (see CR15 in `docs/BACKLOG.md`).

| Secret family | Doppler `prd` holds | Bound to Worker via |
|---|---|---|
| `SIGNING_KEYS` + `ACTIVE_KEY_ID` (HMAC signing) | ✅ canonical | `wrangler secret put` at deploy time; `ACTIVE_KEY_ID` on the sender only |
| `SHARED_SECRET` (legacy HMAC) | ✅ canonical | `wrangler secret put`; accepted by the **deployed** receiver only — CR29 step 3 unbinds it |
| `KEY_ROTATION_DATES` (rotation alerting) | ✅ canonical | `wrangler secret put` on `api-provisioning-receiver` |
| Auth0 credentials | ✅ canonical | `wrangler secret put` |
| Supabase credentials | ✅ canonical | `wrangler secret put` |
| `STRIPE_WEBHOOK_SECRET` | ✅ canonical (only copy) | `wrangler secret put` on `stripe-webhook` |
| `STRIPE_SECRET_KEY` | ✅ canonical | `wrangler secret put` on `api-gateway`, `sender-worker` |

To verify what is actually bound to a Worker (names only, never values):

```bash
npx wrangler secret list --name sender-worker
npx wrangler secret list --name api-gateway
npx wrangler secret list --name stripe-webhook
```

### Doppler as the Recovery Source

Doppler is accepted as sufficient backup — no additional 1Password or Vault backup is required. Two exceptions:

- **`STRIPE_WEBHOOK_SECRET`**: Stripe exposes the signing secret **only** at endpoint-creation time and will not re-display it. The Doppler `prd` copy is the sole recovery path. If both the Doppler copy and the Worker binding are lost, the Stripe endpoint must be deleted and recreated, generating a new secret. Always ensure a new signing secret is stored in Doppler before closing the endpoint-creation call.
- **Legacy JWT keys**: Supabase's `anon` and `service_role` JWT-format keys are readable in plaintext from the Management API (`GET /v1/projects/{ref}/api-keys`) — treat them as disclosed and track their disabling under CR24 in `docs/BACKLOG.md`.

To fingerprint a Doppler value without exposing secret material:

```bash
v=$(doppler secrets get NAME --project integrity-studio --config prd --plain | tr -d '\n')
printf 'len=%s sha=%s\n' "${#v}" "$(printf '%s' "$v" | shasum | cut -c1-12)"
```

Never use `doppler run` for verification — it can serve a stale value from `~/.doppler/fallback/`. Always use `doppler secrets get --plain`.

### Rotation Procedure

**Current production state: multi-key, provisioned 2026-07-30 — and the legacy key is still live alongside it.** `sender-worker` binds `SIGNING_KEYS` + `ACTIVE_KEY_ID` (key id `v2`) and `api-provisioning-receiver` binds a matching `SIGNING_KEYS`; `resolveOutboundSigningKey` (`workers/sender-worker/src/utils.ts`) prefers the rotated key and sends `x-key-id: v2`. Verified by a live signed round-trip, not from the binding list.

> 🔴 **`SHARED_SECRET` is still accepted *in production*, and no rotation below retires it.** The deployed receiver resolves an **absent** `x-key-id` to `SHARED_SECRET`, so it is a second valid credential sitting outside the key-id mechanism — measured against production `POST /inbox` with controls: `v2` + key id → 200, `SHARED_SECRET` + **no** key id → **200**, garbage → 401. Consequences while that is live: rotating `SHARED_SECRET` (Procedure B) leaves `v2` untouched and vice versa, and **removing a key entry from `SIGNING_KEYS` cannot revoke `SHARED_SECRET`, because that key has no id to remove.**
>
> ✅ **Fixed in code, not yet deployed** ([BACKLOG.md CR29](BACKLOG.md#cr29) step 2, 2026-08-02). `resolveSigningKey` now returns no secret for an absent header (`miss: "missing_key_id"`) and `/inbox` answers `401`, so `SIGNING_KEYS` is the sole authority and dropping an id from it really revokes. Two caveats: **the measurements above still describe the live receiver** until it ships, and even after it ships `SHARED_SECRET` is only *unread*, not revoked — unbinding it is step 3, gated on `auth.key_unresolved{miss:"missing_key_id"}` staying at zero in deployed traffic. Deploy the **sender** first: it is the side that fails loudly (`500 SIGNING_KEY_UNRESOLVED`, forwarding nothing) where a receiver-first order turns any keyless caller into an ambiguous 401.

#### `SIGNING_KEYS` wire format — get this right first

`SIGNING_KEYS` is a **JSON object mapping key id → secret**, parsed as `Record<string, string>` by `resolveOutboundSigningKey` (`workers/sender-worker/src/utils.ts`) and `resolveSigningKey` (receiver):

```jsonc
{"v2": "<base64-secret>", "v3": "<base64-secret>"}   // ✅ correct
[{"id": "v2", "secret": "..."}]                       // ❌ parses, resolves to nothing
```

> ⚠️ **This document described the wrong format until 2026-07-31** ("JSON array of `{id, secret}`"). Anyone who provisioned from the old text should re-check the live value: the array form is valid JSON, so `keys[ACTIVE_KEY_ID]` is simply `undefined`, and on the receiver the same value 401s any key-id'd request.
>
> ✅ **The silent-downgrade half of this is fixed** ([CR29](BACKLOG.md#cr29) step 1, 2026-08-02, unshipped). It used to fail in the worst possible direction — the sender fell back to `SHARED_SECRET` with no `x-key-id` behind nothing but a `console.warn`, so `/send` stayed green while signing with the credential the rotation was meant to replace. `resolveOutboundSigningKey` now returns no secret on all four misses (`active_key_id_unset`, `signing_keys_unset`, `signing_keys_malformed`, `unknown_active_key_id`) and `/send` returns `500 SIGNING_KEY_UNRESOLVED` **without forwarding**. A malformed `SIGNING_KEYS` is therefore now an outage rather than a downgrade — still worth catching with the pre-flight below.

#### Procedure A — rotate a key-id'd key (the standard path)

Use this for scheduled rotation. **Deploy the receiver first**; the sequence is load-bearing and is mirrored in a comment above `forwardToReceiver` (`workers/sender-worker/src/index.ts:195`). If the sender ships first, the receiver gets an `x-key-id` it cannot resolve and returns `401 INVALID_SIGNATURE` on every request.

1. Generate a new value: `openssl rand -base64 32` (44 chars).
2. **Receiver first** — add the new id to its `SIGNING_KEYS` *alongside* the current one (both valid during the overlap), and deploy.
3. **Then the sender** — add the same entry to its `SIGNING_KEYS`, set `ACTIVE_KEY_ID` to the new id, and deploy.
4. Pre-flight before that deploy, because a key id that does not resolve downgrades silently rather than failing. Prints structure only, never secret material, and keeps the secret off `argv` (visible in `ps`) by piping it:

   ```bash
   AK=$(doppler secrets get ACTIVE_KEY_ID --project integrity-studio --config prd --plain | tr -d '\n')
   doppler secrets get SIGNING_KEYS --project integrity-studio --config prd --plain | node -e '
   let s = ""; process.stdin.on("data", d => s += d).on("end", () => {
     const id = process.argv[1];
     let k; try { k = JSON.parse(s); } catch { console.log("FAIL: SIGNING_KEYS is not valid JSON"); process.exit(1); }
     if (k === null || typeof k !== "object" || Array.isArray(k)) {
       console.log(`FAIL: must be a JSON object {id:secret}, got ${Array.isArray(k) ? "an array" : typeof k}`);
       process.exit(1);
     }
     const ok = typeof k[id] === "string" && k[id].length > 0;
     console.log(`ids=${JSON.stringify(Object.keys(k))} active=${id} resolves=${ok}`);
     process.exit(ok ? 0 : 1);
   });' "$AK"
   ```

   Exits non-zero on every failure mode, so it is safe to chain with `&&` before a deploy. `resolves=false` means **`/send` will return `500 SIGNING_KEY_UNRESOLVED` and forward nothing** — fix before deploying. (Before CR29 step 1 the same state silently signed with `SHARED_SECRET` and omitted `x-key-id`, which is why this pre-flight exists: nothing downstream complained.)
5. Verify, then remove the old id from both `SIGNING_KEYS` — receiver last this time, so no in-flight request loses its key.
6. Update `KEY_ROTATION_DATES` (see below).

#### Procedure B — rotate `SHARED_SECRET` (legacy path, live in production only)

⚠️ **This procedure describes a path that no longer exists in code.** CR29 step 2 made `SIGNING_KEYS` the sole authority, so once the receiver ships, rotating `SHARED_SECRET` changes nothing that any request touches — and the step-5 verification below (sign `/inbox` with **no** `x-key-id`, expect success) will correctly return `401`. It is kept only because the *deployed* receiver still accepts the credential, which makes this the emergency path until the fix ships: if `SHARED_SECRET` is disclosed before then, rotating it is the mitigation. After the deploy the correct response is CR29 step 3 — unbind it — not a rotation. Prefer Procedure A in every other case.

1. Generate a new value: `openssl rand -base64 32`
2. Store in Doppler `prd` as `SHARED_SECRET`.
3. Bind to both workers:

   ```bash
   NEW=$(doppler secrets get SHARED_SECRET --project integrity-studio --config prd --plain | tr -d '\n')
   printf '%s' "$NEW" | npx wrangler secret put SHARED_SECRET --name sender-worker
   # api-provisioning-receiver is in observability-toolkit — coordinate with that repo's owner:
   printf '%s' "$NEW" | npx wrangler secret put SHARED_SECRET --name api-provisioning-receiver
   ```

   ⚠️ **A mismatch here no longer announces itself.** This step used to warn that a mismatch window "will fail `/inbox` requests" — true when `SHARED_SECRET` was the only key, and **false since `v2` was provisioned**: the sender prefers `v2`, so its traffic keeps returning `200` while the two `SHARED_SECRET` copies disagree. The mismatch then surfaces only on the fallback path, i.e. during an incident. Bind both sides in one sitting and verify per step 5 rather than relying on traffic to fail.

4. Update `KEY_ROTATION_DATES` (see below).
5. **Verify by signing `/inbox` directly — `/send` cannot verify this rotation.** `resolveOutboundSigningKey` prefers `v2`, so a `200` from `/send` exercises the rotated key and says nothing about `SHARED_SECRET`. Sign `POST /inbox` with the new value and **no** `x-key-id`, and include a positive control (`v2` + `x-key-id: v2`) and a negative control (a garbage secret) so a `401` cannot be mistaken for a bad signing implementation. Canonical string is `${timestamp}.${rawBody}`, hex HMAC-SHA256, headers `x-timestamp`/`x-signature`. Use `curl`: `workers.dev` answers `Python-urllib` with a blanket `403 1010` that mimics a signature failure (BACKLOG.md CR14).

#### `KEY_ROTATION_DATES` (receiver only)

The receiver's scheduled cron alerts via Sentry when any tracked key exceeds 90 days; a stale date keeps re-alerting. The sender does not read this — it appears in `workers/sender-worker/wrangler.toml:112` only as a comment.

```bash
NEW_DATE=$(date -u +"%Y-%m-%dT%H:%M:%S.000Z")
doppler secrets set "KEY_ROTATION_DATES={\"SHARED_SECRET\":\"$NEW_DATE\",\"v2\":\"$NEW_DATE\"}" \
  --project integrity-studio --config prd
# Read the value back with `secrets get --plain`, NOT `doppler run` — see the rule above.
KRD=$(doppler secrets get KEY_ROTATION_DATES --project integrity-studio --config prd --plain | tr -d '\n')
printf '%s' "$KRD" | npx wrangler secret put KEY_ROTATION_DATES --name api-provisioning-receiver
```

Track **every** live key, one entry per id. Set only the date of the key you actually rotated; carry the others forward unchanged.

⚠️ **Drop the `"SHARED_SECRET"` entry when the CR29 step-2 receiver ships.** The key is unread from that point, so the entry alerts on the age of a credential no code path can use — and once step 3 unbinds it, on one that is not even bound. The example above keeps it because it matches what is live today.

> ⚠️ **The previous version of this step used `doppler run … -- sh -c 'echo "$KEY_ROTATION_DATES" | wrangler secret put …'`, which contradicts the rule four paragraphs above** — `doppler run` can inject a stale value from `~/.doppler/fallback/`, so the value written to the Worker need not be the value just set. Replaced with `secrets get --plain` piped through `printf`. (The `echo` was harmless *here* — `JSON.parse` tolerates a trailing newline — but it is the wrong habit for any secret that is not JSON.)

> ⚠️ **Whether a `v2` entry was ever added is still unverified — but narrowed.** The old text only said to add per-key-id entries "if `SIGNING_KEYS` is later provisioned", and it has been since 2026-07-30. **The variable itself is bound** on `api-provisioning-receiver` (confirmed 2026-07-31 by reading the version's binding names — see the CLAUDE.md deployment-history note for the method), so the cron can read it and the alert is not simply dead. What cannot be read from here is the *contents*: secret values are write-only, so a missing `v2` entry is indistinguishable from a present one without receiver-side code or a log line. Check there rather than assuming — a missing entry exempts the **active** key from the 90-day alert while still alerting on the legacy one, which is the failure mode that looks most like success.

> ⚠️ **A green Sentry state means "a date was updated", not "old keys are dead".** The alert measures the age of a string in this JSON blob, so refreshing a date silences it whether or not the superseded credential was retired. Only Procedure A step 5 — removing the id from `SIGNING_KEYS` on both sides — revokes anything.

**Procedure A step 5 is the only revocation these mechanisms offer, and against the deployed receiver it does not reach `SHARED_SECRET`.** With CR29 step 2 shipped it becomes a real revocation, because every accepted credential then has an id to remove; until then, a completed rotation means "the previous *key-id'd* credential is dead", not "the previous credential is dead". `SHARED_SECRET` itself is retired by an unbind ([CR29](BACKLOG.md#cr29) step 3), never by a rotation.

### Rotation Cadence

No fixed cadence is enforced. Priorities:

1. **Immediate** if: a Doppler token leaks, a Worker version with stale code is found carrying live secrets (CR14), or `doppler.json` history-scrub (CR01) is blocked.
2. ~~**Opportunistic** when provisioning `SIGNING_KEYS`~~ — done 2026-07-30; the zero-downtime path is available now.
3. **Quarterly.** CR01's history scrub is complete and `SIGNING_KEYS` is provisioned, so both preconditions are met. ⚠️ **A quarterly rotation is not yet a quarterly revocation** — against the deployed receiver each cycle adds a key and retires only the previous key-id'd one, leaving `SHARED_SECRET` valid indefinitely. [CR29](BACKLOG.md#cr29) step 2 fixes that in code but is unshipped; the cadence becomes a real control once the receiver ships and step 3 unbinds the legacy secret.

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
- ⚠️ **Rotation is not yet a revocation in production** — the deployed receiver accepts a keyless signature, so `SHARED_SECRET` has no rotation handle. Fixed in code, unshipped ([CR29](BACKLOG.md#cr29) steps 1–2); the sender now also fails closed rather than downgrading
- ⚠️ Monitoring and alerting — tracked as W04 in `docs/BACKLOG.md`

---

## Troubleshooting

**1. Signature Mismatch (401 invalid signature)**
```
Cause: the sender's SIGNING_KEYS[ACTIVE_KEY_ID] does not match the receiver's
       SIGNING_KEYS entry for that same id -- or the receiver has no entry for it
Fix: Verify both sides hold the same id -> secret pair
  wrangler secret list (shows secret names, not values)
  Run the Procedure A step-4 pre-flight to confirm ACTIVE_KEY_ID resolves
  Receiver first when adding a key, receiver last when removing one
```
⚠️ **The same 401 covers an absent, empty, or unknown `x-key-id`** — deliberately byte-identical so key ids cannot be enumerated. Removing the header is not a workaround; there is no fallback credential. Sentry's `auth.key_unresolved` + `miss` is the only thing that distinguishes the cause. (Against the **deployed** receiver a keyless request still succeeds instead — CR29 step 2 is unshipped.)

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
