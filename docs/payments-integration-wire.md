# Payments Integration Wire

How a Stripe payment becomes an org's plan: the webhook pipeline, the price-to-plan mapping, what is written to Supabase, and how api-gateway enforces the result.

Out of scope here: sign-up ([authentication.md](authentication.md#sign-up)), the `/send` → `/inbox` provisioning hop and its signing ([api-reference.md § Provisioning](api-reference.md#provisioning-sender-worker--api-provisioning-receiver)), and quota limits and rate-limit headers ([api-reference.md § Rate limits](api-reference.md#rate-limits)).

---

## Plan Tier Values

| Value | Display Name | Notes |
|-------|-------------|-------|
| `starter` | Free | Every new org starts here; no payment required |
| `growth` | Growth | Paid, $79/month; requires Stripe checkout |
| `enterprise` | Enterprise | Paid, $50/user/month, 6-user minimum (graduated tier: $300 flat for users 1–6). Contract-billed orgs also exist; they need `billing_status = 'active'` set by hand |

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
         ├─ customer.subscription.created          ← same handler as `updated`; the only subscription event when one is created outside Checkout
         ├─ customer.subscription.updated          ← tier is captured here (needs a price in `plans` — CR38)
         │    ├─ org = stripe_customer_id match, else link from subscription.metadata.org_id (only an org with no customer)
         │    ├─ priceId = subscription.items[0].price.id
         │    ├─ planKey = priceToPlan[priceId]    ← from the `plans` table
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

Stripe price IDs are opaque strings (e.g., `price_1Abc123`). The Supabase `plans` table bridges them to internal tier values, one row per plan:

| `key` | `stripe_price_id` |
|---|---|
| `starter` | `price_...` |
| `growth` | `price_...` |
| `enterprise` | `price_...`, or null when billed by contract |

On each `customer.subscription.created` or `customer.subscription.updated` event, `loadPriceToPlan()` (`workers/stripe-webhook/src/supabase.ts`) reads the table and validates each `key` against `ApiKeyTierSchema`. A row with no price or an unknown key is left out, the second with a `console.warn`. A failed read fails the event, so it is dead-lettered and retried rather than handled without a plan. api-gateway's checkout and `scripts/full-reconciliation.ts` read the same table, so the three cannot disagree. Until 2026-11-20 the Worker read a `STRIPE_PRICE_TO_PLAN_JSON` secret instead.

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

`organizations.current_plan` stores the tier value. It is written only by `stripe-webhook` and by operators; no request can set it (CR37). The provisioning receiver creates every new org at `starter`.

### 3. Validation at request time (API Gateway)

Every metered api-gateway request runs through `enforceOrgQuota`:

```
Request → api-gateway
  ↓
enforceOrgQuota()
  ├─ SELECT current_plan, quota_version, billing_status FROM organizations WHERE id = orgId
  ├─ planKey = effectivePlan(current_plan, billing_status)   ← a paid plan counts only while isEntitled(billing_status)
  └─ checkAndReserve(QuotaDO, { orgId, planKey, quotaVersion, ... })
       ↓
  Quota Durable Object
  ├─ If quotaVersion > stored version: reset limits to DEFAULT_QUOTAS[planKey]
  └─ Check minute + monthly usage against limits → allowed: true/false
```

**File**: `workers/api-gateway/src/lib/quota.ts`; `effectivePlan` and `isEntitled` are in `workers/lib/billing.ts`.

When `quota_version` in the org row increases (bumped by Stripe events), the Durable Object resets its cached limits to the new plan on the next request, so plan changes take effect without a cache invalidation step. Per-tier limits and the fail-open behaviour: [api-reference.md § Rate limits](api-reference.md#rate-limits).

---

## Involved Files

| Component | File |
|-----------|------|
| Tier schema | `workers/lib/types/schemas.ts` (`ApiKeyTierSchema`) |
| Tier type | `workers/lib/types/index.ts` (`ApiKeyTier`) |
| Effective plan | `workers/lib/billing.ts` (`effectivePlan`, `isEntitled`) |
| Stripe webhook entry | `workers/stripe-webhook/src/index.ts` |
| Price-to-plan mapping | `workers/stripe-webhook/src/supabase.ts` (`loadPriceToPlan`) |
| Checkout handler | `workers/stripe-webhook/src/handlers/checkout.ts` |
| Subscription handlers | `workers/stripe-webhook/src/handlers/subscription.ts` |
| Supabase writes | `workers/stripe-webhook/src/supabase.ts` |
| Quota enforcement | `workers/api-gateway/src/lib/quota.ts` |
| Quota Durable Object | `workers/api-gateway/src/durable-objects/quota.ts` |
