# Payments Integration Wire

Documents the current state of the signup/payments flow and the intended target architecture.

---

## ~~Current Flow: Lead Capture via Resend~~ (replaced 2026-03-27)

~~**Bottom line: the current flow does NOT create a user account. It sends an email.**~~

This flow has been replaced. `SignupPage` no longer calls `ContactService.submitForm()`. See **Current Flow** below.

---

## Current Flow: Auth0 Account Creation

```
/signup?tier=starter  →  click "Start Free Trial"
         ↓
SignupPage collects: name, email, password, terms checkbox
         ↓
ProvisioningService.signUp(email, password, name:, tier:) — POSTs to sender-worker /signup
         ↓
sender-worker: auth0CreateUser() — calls Auth0 Management API (client credentials grant)
         ↓
Auth0: creates user, returns auth0_id (sub)
         ↓
sender-worker: supabaseCreatePersonalOrg(name, tier) → supabaseInsertUser → supabaseAddOrgOwner
         ↓
sender-worker returns 201 { jwt }
         ↓
SignupPage receives AuthSuccess(jwt, email) → Navigate to /provision
SignupPage receives AuthError → Navigate to /request_failure
```

### Key Observations

- Auth0 post-registration webhook is not yet configured — Supabase provisioning is currently triggered inline by the sender-worker `/signup` handler

### Involved Files

| Layer | File |
|-------|------|
| Router | `lib/routing/app_router.dart` |
| UI | `lib/pages/signup_page.dart` |
| Service | `lib/services/provisioning_service.dart` |
| Worker | `workers/sender-worker/src/index.ts` (`POST /signup`) |
| Auth | Auth0 Management API (`auth0CreateUser`) |
| Supabase | `workers/sender-worker/src/supabase.ts` |

---

## Target Flow: Auth0 Webhook-Driven Provisioning

Auth0 is the identity provider. Supabase provisioning should be triggered by the Auth0 post-registration webhook rather than inline in the sender-worker. The current inline provisioning is a temporary arrangement.

```
/signup?tier=starter  →  click "Start Free Trial"
         ↓
SignupPage collects: email, password, (name, company optional)
         ↓
ProvisioningService.signup() — calls Auth0 Management API
         ↓
Auth0: creates user, issues JWT (sub = Auth0 user ID)
         ↓
Auth0 post-registration webhook → sender-worker → (service binding) → api-provisioning-receiver
         ↓
Provisioning (triggered by webhook):
  1. supabaseCreatePersonalOrg — inserts organizations row (plan: starter)
  2. supabaseInsertUser        — inserts users row (auth0_id = Auth0 sub, tier: starter)
  3. supabaseAddOrgOwner       — inserts organization_memberships row (role: owner)
         ↓
SignupPage receives Auth0 JWT
         ↓
Navigate to dashboard (authenticated)
```

### What Needs to Be Built

- ~~Remove `supabaseAdminCreateUser` call from sender-worker; replace with Auth0 Management API call~~ ✅ Done — `auth0CreateUser` now uses client credentials grant
- ~~Replace `ContactService.submitForm()` in `signup_page.dart` with Auth0 signup~~ ✅ Done — `ProvisioningService.signUp(email, password)` is now called; on `AuthSuccess` routes to `/provision`
- ~~Forward `name` field from `SignupPage` to sender-worker `/signup` for use in org display name~~ ✅ Done — `ProvisioningService.signUp(name:, tier:)` passes both; sender-worker forwards to `supabaseCreatePersonalOrg`
- ~~Pass `tier` from `SignupPage` to sender-worker so `supabaseCreatePersonalOrg` sets the correct initial plan~~ ✅ Done — `current_plan` is now set from the request `tier`; invalid/absent values default to `starter`
- ~~On `AuthError`, error shown inline with no redirect~~ ✅ Done — `AuthError` now navigates to `/request_failure`
- ~~Store Auth0 JWT in secure storage and route directly to authenticated dashboard post-provision~~ ✅ Done — ROPC exchange in sender-worker `/signup` returns real JWT; `AuthStorage` saves it to `localStorage`; `ProvisionPage` shows "Go to Dashboard" → opens `integritystudio.dev?access_token=JWT`
- ~~Wire Stripe checkout for `growth` tier post-signup~~ ✅ Done — `POST /create-checkout-session` on sender-worker; `CheckoutPage` redirects to Stripe; `CheckoutSuccessPage` prompts sign-in to activate
- Wire Stripe checkout for `enterprise` tier — pending (enterprise uses contact-sales flow with no Auth0 signup; requires reworking that path first)

### Involved Files (target)

| Layer | File |
|-------|------|
| Router | `lib/routing/app_router.dart` |
| UI | `lib/pages/signup_page.dart` |
| Service | `lib/services/provisioning_service.dart` |
| Auth | Auth0 Management API + post-registration webhook (webhook not yet configured) |
| Worker | `workers/sender-worker/src/index.ts` |
| Supabase | `workers/sender-worker/src/supabase.ts` |

---

## Plan Tier Values

| Value | Display Name | Notes |
|-------|-------------|-------|
| `starter` | Free | Default on signup; no payment required |
| `growth` | Growth | Paid; requires Stripe checkout |
| `enterprise` | Enterprise | Custom pricing; requires sales contact |

Canonical Zod schema: `ApiKeyTierSchema` in `workers/lib/types/schemas.ts`

---

## Payments Processing Architecture

### Stripe Webhook Pipeline

The stripe-webhook worker handles five event types. All events are verified via Stripe signature before processing.

```
Stripe → stripe-webhook worker (POST /webhook)
         ├─ checkout.session.completed
         │    └─ linkStripeCustomer(org, customerId)
         │    └─ upsertSubscription(org, subscriptionId, priceId=null, 'active')
         │
         ├─ customer.subscription.updated          ← tier is captured here
         │    ├─ priceId = subscription.items[0].price.id
         │    ├─ planKey = priceToPlan[priceId]    ← STRIPE_PRICE_TO_PLAN_JSON mapping
         │    ├─ upsertSubscription(org, subscriptionId, priceId, status)
         │    └─ updateOrgBillingStatus(org, billingStatus, planKey, bumpQuotaVersion=true)
         │
         ├─ customer.subscription.deleted
         │    └─ updateOrgBillingStatus(org, 'canceled', 'starter', bumpQuotaVersion=true)
         │
         ├─ invoice.paid
         │    └─ marks subscription active, bumps quota version
         │
         └─ invoice.payment_failed
              └─ marks billing_status past_due
```

Failed events are written to a dead-letter table and retried by a reconciliation cron every 15 minutes with exponential backoff.

### Price-to-Plan Mapping

Stripe price IDs are opaque strings (e.g., `price_1Abc123`). The env var `STRIPE_PRICE_TO_PLAN_JSON` bridges them to internal tier values:

```json
{
  "price_growth_monthly": "growth",
  "price_growth_annual": "growth",
  "price_enterprise_annual": "enterprise"
}
```

At worker startup, `parsePriceToPlan()` validates each value against `ApiKeyTierSchema`. Invalid entries are dropped with a `console.warn`; a malformed JSON string disables the mapping entirely (returns `{}`). No Stripe price ID maps to `starter` — downgrade is always hardcoded.

**File**: `workers/stripe-webhook/src/index.ts`

### Supabase: What Gets Written

`updateOrgBillingStatus` writes to the `organizations` table:

| Column | Written when |
|--------|-------------|
| `billing_status` | Every subscription/invoice event |
| `current_plan` | Only when `planKey` is provided (subscription.updated) |
| `quota_version` | When `bumpQuotaVersion=true`; set to `Date.now()` |

Signature:
```typescript
updateOrgBillingStatus(
  orgId: string,
  billingStatus: BillingStatus,
  planKey?: ApiKeyTier,
  bumpQuotaVersion?: boolean,
): Promise<VoidResult>
```

**File**: `workers/stripe-webhook/src/supabase.ts`

---

## ApiKeyTier: Capture → Storage → Validation

### 1. Capture (Stripe webhook)

`customer.subscription.updated` extracts the Stripe price ID from the subscription payload and looks it up in the `priceToPlan` map. The resolved `ApiKeyTier` value is passed to `updateOrgBillingStatus`.

### 2. Storage (Supabase)

`organizations.current_plan` stores the tier value. This column is the authoritative source of truth for an org's plan. Default at org creation: `starter` (set by sender-worker `supabaseCreatePersonalOrg`).

### 3. Validation at request time (API Gateway)

Every inbound API request runs through `enforceOrgQuota`:

```
Request → api-gateway
  ↓
enforceOrgQuota()
  ├─ SELECT current_plan, quota_version FROM organizations WHERE id = orgId
  ├─ planKey = org.current_plan ?? 'starter'
  └─ checkAndReserve(QuotaDO, { orgId, planKey, quotaVersion, ... })
       ↓
  Quota Durable Object
  ├─ If quotaVersion > stored version: reset limits to DEFAULT_QUOTAS[planKey]
  └─ Check minute + monthly usage against limits → allowed: true/false
```

**File**: `workers/api-gateway/src/lib/quota.ts`

### 4. Quota limits per tier

Defined in the Quota Durable Object (`workers/api-gateway/src/durable-objects/quota.ts`):

| Tier | Requests/minute | Monthly limit |
|------|----------------|---------------|
| `starter` | 60 | 10,000 |
| `growth` | 600 | 500,000 |
| `enterprise` | 6,000 | unlimited |

When `quota_version` in the org row increases (bumped by Stripe events), the Durable Object resets its cached limits to the new plan on the next request. This makes plan changes take effect immediately without a cache invalidation step.

### 5. Fail-open behavior

If the Quota Durable Object is unavailable, `enforceOrgQuota` returns `ok: true` and allows the request through. Rate limit headers are omitted. This is a deliberate availability-over-correctness tradeoff.

---

## Involved Files

| Component | File |
|-----------|------|
| Tier schema | `workers/lib/types/schemas.ts` (`ApiKeyTierSchema`) |
| Tier type | `workers/lib/types/index.ts` (`ApiKeyTier`) |
| Stripe webhook entry | `workers/stripe-webhook/src/index.ts` |
| Price-to-plan mapping | `workers/stripe-webhook/src/index.ts` (`parsePriceToPlan`) |
| Checkout handler | `workers/stripe-webhook/src/handlers/checkout.ts` |
| Subscription handlers | `workers/stripe-webhook/src/handlers/subscription.ts` |
| Supabase writes | `workers/stripe-webhook/src/supabase.ts` |
| Quota enforcement | `workers/api-gateway/src/lib/quota.ts` |
| Quota Durable Object | `workers/api-gateway/src/durable-objects/quota.ts` |

---

## Sender Worker API: `/send`

The Flutter app calls `POST /send` on the sender-worker. The sender validates the payload, then signs and forwards it to the production receiver `api-provisioning-receiver` over a Cloudflare service binding (`env.RECEIVER.fetch(".../inbox")`), not a public URL.

### Validation (sender-side)

| Field | Type | Required | Notes |
|-------|------|----------|-------|
| `action` | string | yes | Must be `provision_api_key`; any other value (including absent) → 400 `UNKNOWN_ACTION` |
| `jwt` | string | yes | Auth0 JWT for the authenticated user |
| `name` | string | yes | Display name for the API key |
| `email` | string | yes | Must pass email regex; invalid → 400 `INVALID_EMAIL` |
| `tier` | `'starter' \| 'growth' \| 'enterprise'` | no | Invalid/absent values silently default to `'starter'` |
| `org_name` | string | no | Forwarded as-is if present, omitted otherwise |

The sender normalizes the payload (applies `tier` default, strips unknown fields) before signing.

### HMAC signing

`x-signature = HMAC-SHA256(SHARED_SECRET, "{x-timestamp}.{normalizedBody}")` as hex.

---

## Receiver Worker API: `/inbox`

All provisioning actions share a single endpoint. Requests must carry HMAC authentication headers signed by the sender-worker.

### HMAC Headers (all requests)

| Header | Required |
|--------|----------|
| `x-timestamp` | yes |
| `x-signature` | yes |

Signature format: `HMAC-SHA256(secret, "${timestamp}.${bodyString}")` as hex. The sender-worker signs and the receiver (`api-provisioning-receiver`) verifies. Replayed requests are rejected via timestamp staleness check.

### `POST /inbox` — request body

| Field | Type | Required | Notes |
|-------|------|----------|-------|
| `action` | string | yes | Must be non-empty |
| `email` | string (email) | yes | Validated by Zod `.email()` |
| `jwt` | string | no (schema) | Required by `provision_api_key` handler |
| `name` | string | no (schema) | Required by `provision_api_key` handler |
| `tier` | `'starter' \| 'growth' \| 'enterprise'` | no | Defaults to `'starter'` |
| `org_name` | string | no | Falls back to email domain if omitted |

Schema: `inboxPayloadSchema` in the production receiver `api-provisioning-receiver` (`observability-toolkit` repo, `services/api-provisioning-receiver/src/`). The local stub `workers/receiver-worker/src/` mirrors a subset for contract tests only.

### `action: 'provision_api_key'` — additional handler checks

| Field | Notes |
|-------|-------|
| `jwt` | Must match a valid Supabase user; email on token must equal `email` field |
| `name` | API key display name |
| `email` | Domain extracted via `emailDomainSchema`; MX records checked; compared against JWT user |

### Example request

```http
POST /inbox
x-timestamp: 1711234567890
x-signature: a3f2...c9d1
Content-Type: application/json

{
  "action": "provision_api_key",
  "email": "user@example.com",
  "jwt": "<supabase-jwt>",
  "name": "My API Key",
  "tier": "starter",
  "org_name": "Example Corp"
}
```

---

## API Key Provisioning Flow

_Last updated: 2026-03-27 (signup gap fixes: name, tier, AuthError redirect)_

### Architecture

```
Flutter App
  └─→ Sender Worker
      └─→ Receiver Worker
          ├─→ Auth0 (/userinfo)
          ├─→ Supabase REST (user lookup, org upsert, membership)
          └─→ Supabase Edge Function (api-keys-create)
```

### Step-by-step

**1. Sender** — builds `{action, jwt, name, email, tier?, org_name?}`, signs `HMAC-SHA256(timestamp.body)`, `POST /inbox`

**2. Receiver transport validation**

| Check | Error |
|-------|-------|
| `x-timestamp` + `x-signature` present | 401 `MISSING_AUTH_HEADERS` |
| Timestamp ±5 min window | 401 `INVALID_TIMESTAMP` |
| HMAC constant-time match | 401 `INVALID_SIGNATURE` |
| Valid JSON body | 400 `JSON_PARSE_ERROR` |

**3. Receiver payload validation**
- `inboxPayloadSchema` discriminated union on `action`
- Email domain + MX check (Cloudflare DoH, fail-open, 2 retries) → 400 `INVALID_EMAIL_DOMAIN`

**4. Auth0 `/userinfo`** — confirms JWT live + unexpired; cross-checks email claim

**5. Supabase** — `GET /rest/v1/users?auth0_id=eq.{sub}` → Supabase UUID

**6. Supabase** — `POST /rest/v1/organizations {domain, name, type:'team', current_plan:tier}`
- 201 → new org; 409+23505 → existing org; else propagates

**7. Supabase** — `POST /rest/v1/organization_memberships`
- 204 → added; 409+23505 → already member; else propagates

**8. Edge fn `api-keys-create`** — `POST {SUPABASE_URL}/functions/v1/api-keys-create`

Response: `{ token: /^obtk_[0-9a-f]{64}$/, keyId, prefix, tier }`

**9. Response** — transparent proxy
- Sender reads `receiverRes.text()`, re-emits same status + `content-type`
- No parsing or transformation
- CORS: `access-control-allow-origin` added if origin in `ALLOWED_ORIGINS_JSON` (fallback: `integritystudio.ai`, `www.integritystudio.ai`); 403 for others
- Error paths:

| Condition | Response |
|-----------|----------|
| `RECEIVER` service binding missing | 500 `INTERNAL_ERROR` ("RECEIVER service binding not configured") |
| `SHARED_SECRET` missing | 500 `INTERNAL_ERROR` |
| `SendRequestSchema` fails | 400/401 field-specific |
| `env.RECEIVER.fetch` `TypeError` (binding unreachable) | 502 "receiver-worker unreachable" |
| Other thrown error | 500 "send failed" |

### Key schemas

All in the production receiver `api-provisioning-receiver` (`observability-toolkit` repo, `services/api-provisioning-receiver/src/`):

`inboxPayloadSchema`, `actionSchema`, `auth0UserinfoSchema`, `provisionApiKeyResultSchema`, `apiKeyTierSchema`, `emailToRegistrableDomainSchema`
