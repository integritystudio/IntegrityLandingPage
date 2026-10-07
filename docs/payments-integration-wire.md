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
         ├─ customer.subscription.updated          ← tier is captured here (needs STRIPE_PRICE_TO_PLAN_JSON bound — CR38)
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
| Price-to-plan mapping | `workers/stripe-webhook/src/index.ts` (`parsePriceToPlan`) |
| Checkout handler | `workers/stripe-webhook/src/handlers/checkout.ts` |
| Subscription handlers | `workers/stripe-webhook/src/handlers/subscription.ts` |
| Supabase writes | `workers/stripe-webhook/src/supabase.ts` |
| Quota enforcement | `workers/api-gateway/src/lib/quota.ts` |
| Quota Durable Object | `workers/api-gateway/src/durable-objects/quota.ts` |
