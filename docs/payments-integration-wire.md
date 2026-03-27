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
ProvisioningService.signUp(email, password) — POSTs to sender-worker /signup
         ↓
sender-worker: auth0CreateUser() — calls Auth0 Management API (client credentials grant)
         ↓
Auth0: creates user, returns auth0_id (sub)
         ↓
sender-worker: supabaseCreatePersonalOrg → supabaseInsertUser → supabaseAddOrgOwner
         ↓
sender-worker returns 201 { jwt }
         ↓
SignupPage receives AuthSuccess(jwt, email) → Navigate to /provision
```

### Key Observations

- `tier` param is displayed in the UI badge but not yet passed to the backend at signup; plan defaults to `starter` in `supabaseCreatePersonalOrg`
- Auth0 post-registration webhook is not yet configured — Supabase provisioning is currently triggered inline by the sender-worker `/signup` handler
- Name field is collected in the UI but not forwarded to the sender-worker (not yet wired)
- On `AuthError`, the error message is shown inline; no redirect to `/request_failure`

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
Auth0 post-registration webhook → sender-worker or receiver-worker
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

### Known Mismatch in sender-worker

`sender-worker/src/supabase.ts` currently calls `supabaseAdminCreateUser` (Supabase Auth) and stores the resulting Supabase UUID as `auth0_id`. This is wrong — the `auth0_id` column must hold the Auth0 `sub`, not a Supabase Auth UUID. The API gateway's user lookups (`me.ts`, `api-keys.ts`) use `auth.sub` from the Auth0 JWT to query `auth0_id`; if the stored value is a Supabase UUID, those lookups will never match.

### What Needs to Be Built

- ~~Remove `supabaseAdminCreateUser` call from sender-worker; replace with Auth0 Management API call~~ ✅ Done — `auth0CreateUser` now uses client credentials grant (`AUTH0_CLIENT_ID`, `AUTH0_CLIENT_SECRET`, `AUTH0_AUDIENCE`) to obtain a management token, then calls `POST /api/v2/users`
- ~~Replace `ContactService.submitForm()` in `signup_page.dart` with Auth0 signup~~ ✅ Done — `ProvisioningService.signUp(email, password)` is now called; on `AuthSuccess` routes to `/provision`
- Configure Auth0 post-registration webhook to trigger provisioning (replace inline Supabase calls in sender-worker `/signup`)
- Forward `name` field from `SignupPage` to sender-worker `/signup` for use in org display name
- Pass `tier` from `SignupPage` to sender-worker so `supabaseCreatePersonalOrg` sets the correct initial plan
- Store Auth0 JWT in secure storage and route directly to authenticated dashboard post-provision
- Wire Stripe checkout for paid tiers (`growth`, `enterprise`) post-signup

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

The Flutter app calls `POST /send` on the sender-worker. The sender validates the payload, then signs and forwards it to the receiver-worker's `/inbox`.

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

Signature format: `HMAC-SHA256(secret, "${timestamp}.${bodyString}")` as hex. The sender-worker signs and the receiver-worker verifies. Replayed requests are rejected via timestamp staleness check.

### `POST /inbox` — request body

| Field | Type | Required | Notes |
|-------|------|----------|-------|
| `action` | string | yes | Must be non-empty |
| `email` | string (email) | yes | Validated by Zod `.email()` |
| `jwt` | string | no (schema) | Required by `provision_api_key` handler |
| `name` | string | no (schema) | Required by `provision_api_key` handler |
| `tier` | `'starter' \| 'growth' \| 'enterprise'` | no | Defaults to `'starter'` |
| `org_name` | string | no | Falls back to email domain if omitted |

Schema: `inboxPayloadSchema` in `workers/receiver-worker/src/api-schemas.ts`

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
