# Stripe Webhook Handler Implementation: Subscription Updates

**Status:** Ready for implementation
**Priority:** P1 (blocks billing enforcement)
**Estimated effort:** 2–3 sprints (weeks 3–8)
**Dependencies:** Two-layer auth, Durable Objects quota enforcement, database schema (Phase 1)

---

## Overview

This document describes the implementation of the Stripe webhook handler for subscription lifecycle events. The handler processes `customer.subscription.updated` and `customer.subscription.deleted` events, updating billing status, syncing plans, recomputing entitlements, and invalidating edge caches via quota version bumps.

**Key responsibilities:**
1. Verify Stripe event authenticity (HMAC-SHA256 signature)
2. Idempotency via Stripe event ID tracking
3. Resolve organization by Stripe customer ID
4. Upsert subscription records (price, status)
5. Update org billing status and plan tier
6. Recompute entitlements when plan changes
7. Bump quota_version to invalidate caches
8. Handle edge cases (unknown plans, missing orgs, network failures)

---

## Architecture

```
┌──────────────────────────────────────┐
│     Stripe Dashboard / API           │
│  (subscription updated/deleted)      │
└────────────────┬─────────────────────┘
                 │
                 ▼
┌──────────────────────────────────────┐
│  Cloudflare Worker (POST /webhooks)  │
│                                      │
│  1. Verify HMAC signature            │
│  2. Check idempotency                │
│  3. Resolve org by customer ID       │
│  4. Upsert subscription              │
│  5. Update billing + plan            │
│  6. Recompute entitlements           │
│  7. Bump quota_version               │
│  8. Record event                     │
└────────────────┬─────────────────────┘
                 │
    ┌────────────┼────────────┐
    │            │            │
    ▼            ▼            ▼
 Supabase   Durable Objects  Logs
  (DB)    (quota invalidation)
```

---

## Database Schema

### 1. Idempotency Table

```sql
CREATE TABLE stripe_events (
  id            TEXT PRIMARY KEY,       -- Stripe event ID (evt_1Abc...)
  event_type    TEXT NOT NULL,          -- customer.subscription.updated, etc.
  processed_at  TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX idx_stripe_events_processed_at
  ON stripe_events (processed_at);

-- Cleanup: delete events older than 30 days (Stripe retry window is 3 days)
-- SELECT cron.schedule('cleanup-stripe-events', '0 3 * * *',
--   $$DELETE FROM stripe_events WHERE processed_at < now() - interval '30 days'$$);
```

### 2. Atomic Update Functions (RPCs)

**Billing status + plan + quota_version bump:**
```sql
CREATE OR REPLACE FUNCTION update_org_billing(
  p_org_id              UUID,
  p_billing_status      TEXT,
  p_plan_key            TEXT DEFAULT NULL,
  p_bump_quota_version  BOOLEAN DEFAULT FALSE
)
RETURNS VOID AS $$
BEGIN
  UPDATE organizations
  SET
    billing_status = p_billing_status,
    current_plan   = COALESCE(p_plan_key, current_plan),
    quota_version  = CASE
      WHEN p_bump_quota_version THEN quota_version + 1
      ELSE quota_version
    END,
    updated_at     = now()
  WHERE id = p_org_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
```

**Atomic entitlement replacement:**
```sql
CREATE OR REPLACE FUNCTION replace_entitlements(
  p_org_id       UUID,
  p_entitlements JSONB
)
RETURNS VOID AS $$
BEGIN
  -- Delete all existing entitlements for this org
  DELETE FROM entitlements WHERE organization_id = p_org_id;

  -- Insert the new set from JSON array
  INSERT INTO entitlements (organization_id, feature_key, enabled, hard_limit, soft_limit, created_at)
  SELECT
    p_org_id,
    (ent->>'feature_key')::TEXT,
    (ent->>'enabled')::BOOLEAN,
    (ent->>'hard_limit')::INTEGER,
    (ent->>'soft_limit')::INTEGER,
    now()
  FROM jsonb_array_elements(p_entitlements) AS ent;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
```

### 3. Existing Tables (no schema changes required)

**organizations table:**
- `stripe_customer_id` TEXT — Stripe customer ID (link to subscriptions)
- `current_plan` TEXT — free | growth | enterprise
- `billing_status` TEXT — active | past_due | cancelled | inactive
- `quota_version` BIGINT — Version counter (bumped on plan changes)

**subscriptions table:**
- `organization_id` UUID
- `stripe_subscription_id` TEXT (unique)
- `stripe_price_id` TEXT — Maps to plan via PRICE_TO_PLAN lookup
- `status` TEXT — Stripe subscription status
- `created_at`, `updated_at` TIMESTAMPTZ

**entitlements table:**
- `organization_id` UUID
- `feature_key` TEXT (unique per org)
- `enabled` BOOLEAN
- `hard_limit` INTEGER
- `soft_limit` INTEGER

---

## Implementation Files

### File 1: `workers/stripe-webhook/src/plans.ts`

Configuration file — single source of truth for price→plan mapping and entitlement matrix.

**Key exports:**
- `PRICE_TO_PLAN: Record<string, PlanKey>` — Maps Stripe price IDs to plan keys
- `PLAN_ENTITLEMENTS: Record<PlanKey, EntitlementDef[]>` — Plan→entitlements matrix
- `resolvePlan(priceId: string): PlanKey | undefined` — Price lookup

**Tasks:**
1. Fill in `PRICE_TO_PLAN` with actual Stripe price IDs from dashboard
2. Tune entitlement limits in `PLAN_ENTITLEMENTS` to match pricing
3. Add new plans/features as needed (backward-compatible)

**Example:**
```typescript
export const PRICE_TO_PLAN: Record<string, PlanKey> = {
  'price_1Oa5uAAa1234Growth_monthly': 'growth',
  'price_1Oa5uAAa1234Growth_annual': 'growth',
  'price_1Oa5uAAa1234Ent_monthly': 'enterprise',
};

export const PLAN_ENTITLEMENTS: Record<PlanKey, EntitlementDef[]> = {
  free: [
    { feature_key: 'api_requests', enabled: true, hard_limit: 1_000, soft_limit: 800 },
    { feature_key: 'team_members', enabled: true, hard_limit: 2, soft_limit: null },
    // ...
  ],
  // ...
};
```

### File 2: `workers/stripe-webhook/src/supabase.ts`

Supabase client wrapper with idempotency and entitlement recomputation.

**Key methods:**
- `createSupabaseAdmin(supabaseUrl, serviceRoleKey)` — Factory
- `linkStripeCustomer(orgId, stripeCustomerId)` — Link org to Stripe
- `upsertSubscription(orgId, stripeSubId, priceId, status)` — Sync subscription
- `updateOrgBillingStatus(orgId, status, planKey?, bumpQuotaVersion?)` — Atomic update with RPC fallback
- `recomputeEntitlements(orgId, planKey)` — Atomically replace entitlements
- `isEventProcessed(eventId)` — Idempotency check
- `markEventProcessed(eventId, eventType)` — Record event

**Design pattern: RPC with fallback**
```typescript
async function updateOrgBillingStatus(...) {
  // Try atomic RPC first
  const result = await sb.rpc('update_org_billing', { /* params */ });

  if (!result.ok) {
    // Fallback: direct update (works before migration deploys)
    console.warn('RPC unavailable, falling back to direct update');
    const fallback = await sb.update('organizations', { /* data */ }, /* filters */);
    return toVoidResult(fallback);
  }

  return { ok: true };
}
```

This allows the Worker to deploy before the SQL migration runs (no chicken-and-egg dependency).

### File 3: `workers/stripe-webhook/src/handlers/subscription.ts`

Core webhook handlers with idempotency, plan-change detection, and entitlement recomputation.

**Exports:**
- `handleSubscriptionUpdated(event: StripeEvent, db: SupabaseAdmin)` — Subscription updated handler
- `handleSubscriptionDeleted(event: StripeEvent, db: SupabaseAdmin)` — Subscription deleted handler

**`handleSubscriptionUpdated` flow:**
```
1. Validate event shape (customer ID, subscription ID, status)
2. Idempotency guard (skip if already processed)
3. Resolve org by Stripe customer ID
4. Extract price ID, resolve plan key
5. Upsert subscription record
6. Update org billing status + plan
7. If plan changed, recompute entitlements
8. Mark event as processed
9. Return 200 OK
```

**`handleSubscriptionDeleted` flow:**
```
1. Validate event shape
2. Idempotency guard
3. Resolve org
4. Mark subscription as canceled
5. Downgrade org to free plan
6. Recompute entitlements to free-tier limits
7. Mark event as processed
```

### File 4: `workers/stripe-webhook/src/index.ts` (main handler)

Entry point — integrates signature verification, routing, and error handling.

```typescript
import { handleSubscriptionUpdated, handleSubscriptionDeleted } from './handlers/subscription';
import { createSupabaseAdmin } from './supabase';

export default {
  async fetch(request: Request, env: Env): Promise<Response> {
    if (request.method !== 'POST') {
      return new Response('Method not allowed', { status: 405 });
    }

    try {
      // 1. Parse request body
      const body = await request.text();
      const event: StripeEvent = JSON.parse(body);

      // 2. Verify Stripe signature
      const signature = request.headers.get('stripe-signature');
      if (!signature || !verifyStripeSignature(body, signature, env.STRIPE_WEBHOOK_SECRET)) {
        return new Response('Unauthorized', { status: 401 });
      }

      // 3. Replay protection (5-minute window)
      if (isReplay(event.created)) {
        return new Response('Replay detected', { status: 400 });
      }

      // 4. Route by event type
      const db = createSupabaseAdmin(env.SUPABASE_URL, env.SUPABASE_SERVICE_ROLE_KEY);

      let result;
      switch (event.type) {
        case 'customer.subscription.updated':
          result = await handleSubscriptionUpdated(event, db);
          break;
        case 'customer.subscription.deleted':
          result = await handleSubscriptionDeleted(event, db);
          break;
        default:
          // Ignore unknown events
          return Response.json({ ok: true });
      }

      if (!result.ok) {
        console.error(`[${event.type}] ${result.error}`);
        return Response.json({ error: result.error }, { status: 400 });
      }

      return Response.json({ ok: true });
    } catch (err) {
      console.error('Webhook handler error:', err);
      return Response.json({ error: 'Internal error' }, { status: 500 });
    }
  }
};
```

---

## Implementation Steps

### Phase 1: Infrastructure (Week 1–2)

**Step 1: Create SQL migration**
```bash
cd supabase/migrations
touch 20260401000000_stripe_webhook_infrastructure.sql
# Add: stripe_events table, update_org_billing RPC, replace_entitlements RPC
```

**Step 2: Deploy migration**
```bash
supabase db push
# Verify: `\dt stripe_events` in Supabase dashboard
```

**Step 3: Create plan configuration file**
```bash
touch workers/stripe-webhook/src/plans.ts
# Export PRICE_TO_PLAN (empty for now), PLAN_ENTITLEMENTS
# Find your Stripe price IDs: Dashboard → Products → Pricing → copy price_xxx IDs
```

**Step 4: Update `wrangler.toml` with Supabase bindings**
```toml
[env.production]
vars = { SUPABASE_URL = "https://..." }
secrets = ["SUPABASE_SERVICE_ROLE_KEY", "STRIPE_WEBHOOK_SECRET"]
```

### Phase 2: Core Implementation (Week 3–4)

**Step 5: Implement Supabase client wrapper**
```bash
touch workers/stripe-webhook/src/supabase.ts
# Implement: createSupabaseAdmin, all DB methods
# Test each method in unit tests
```

**Step 6: Implement subscription handlers**
```bash
touch workers/stripe-webhook/src/handlers/subscription.ts
# Implement: handleSubscriptionUpdated, handleSubscriptionDeleted
# Add comprehensive error logging
```

**Step 7: Implement main handler & signature verification**
```bash
# Update workers/stripe-webhook/src/index.ts
# Add: Stripe signature verification, replay protection, routing
```

### Phase 3: Testing & Deployment (Week 5–8)

**Step 8: Write comprehensive test suite**
```bash
touch workers/stripe-webhook/tests/handlers.test.ts
# Test: idempotency, plan changes, missing orgs, invalid plans, edge cases
# Use mock Stripe events from Stripe docs
```

**Step 9: Integration test with real Stripe (staging)**
```bash
# 1. Create test Stripe account (or use sandbox)
# 2. Set webhook endpoint URL to staging Worker
# 3. Trigger subscription updates via Stripe dashboard
# 4. Verify: DB updates, entitlements, quota_version bumps
# 5. Send duplicate events, verify idempotency
```

**Step 10: Deploy to production**
```bash
wrangler deploy --env production
# 1. Update Stripe webhook endpoint to prod URL
# 2. Monitor logs for errors
# 3. Test with small customer (upgrade, downgrade, cancel)
```

---

## Key Design Decisions

| Decision | Rationale | Alternative |
|----------|-----------|-------------|
| **RPC + direct-update fallback** | Worker deploys before migration runs (no chicken-and-egg) | Wait for migration to deploy first (more complex CI/CD) |
| **Idempotency is non-fatal** | If table missing, events still process (graceful degradation) | Fail the webhook if table missing (blocking) |
| **Entitlement failure doesn't fail webhook** | Billing status is critical; entitlements can be repaired | Fail webhook if entitlements fail (blocks billing) |
| **`trialing` → `active`** | Trialing users get full plan access (better UX) | Trialing users get limited access (less UX-friendly) |
| **`previous_attributes` for plan change detection** | Avoid unnecessary entitlement rewrites on status changes | Always recompute on any event (wastes IO) |
| **`PLAN_ENTITLEMENTS` as code, not DB** | Plan definitions deployed atomically with code | Plans in DB (adds runtime complexity) |
| **30-day cleanup window** | Stripe retries max 3 days; 30 days is safe margin | 3-day cleanup (risky if async jobs lag) |

---

## Testing Strategy

### Unit Tests

```typescript
describe('handleSubscriptionUpdated', () => {
  it('idempotency: skips duplicate events', async () => {
    // 1. Process event, mark as processed
    // 2. Process same event again
    // 3. Verify: no duplicate DB writes
  });

  it('plan change detection: recomputes entitlements', async () => {
    // 1. Subscription on growth plan
    // 2. Send event with previous_attributes.items
    // 3. Verify: entitlements recomputed to new plan
  });

  it('status change: does not recompute entitlements', async () => {
    // 1. Subscription active → past_due
    // 2. Send event without items in previous_attributes
    // 3. Verify: billing_status updated, entitlements unchanged
  });

  it('unknown plan: logs warning, keeps existing plan', async () => {
    // 1. Price ID maps to unknown plan
    // 2. Verify: billing_status updated, plan unchanged
  });

  it('missing org: logs warning, returns 200', async () => {
    // 1. Stripe customer ID not linked to any org
    // 2. Verify: webhook returns 200 (not 400)
  });
});

describe('handleSubscriptionDeleted', () => {
  it('downgrades to free plan', async () => {
    // 1. Subscription deleted
    // 2. Verify: org.current_plan = 'free', billing_status = 'canceled'
  });

  it('recomputes to free entitlements', async () => {
    // 1. Subscription deleted
    // 2. Verify: entitlements match PLAN_ENTITLEMENTS['free']
  });
});
```

### Integration Tests

```typescript
describe('Stripe webhook integration (staging)', () => {
  it('end-to-end: upgrade from free to growth', async () => {
    // 1. Create org on free plan
    // 2. Trigger subscription.created → subscription.updated (growth plan)
    // 3. Verify: DB has subscription record, entitlements updated
    // 4. Query quota_version, verify incremented
  });

  it('e2e: subscription cancellation', async () => {
    // 1. Org on growth plan
    // 2. Trigger customer.subscription.deleted
    // 3. Verify: downgraded to free, entitlements reset
  });

  it('e2e: idempotency - replay same event', async () => {
    // 1. Trigger subscription.updated
    // 2. Replay same event 3x
    // 3. Verify: single DB write, no duplicates
  });
});
```

---

## Monitoring & Alerting

### Logs to track

```typescript
// Success
console.log(`[subscription.updated] org=${orgId} status=${billingStatus} plan=${planKey}`);

// Warning (non-fatal)
console.warn(`[subscription.updated] No org for customer=${customerId}`);
console.warn(`RPC update_org_billing unavailable, falling back to direct update`);

// Error (investigate, but don't block)
console.error(`[subscription.updated] Entitlement recompute failed: ${error}`);
```

### Metrics to expose

- Webhook events processed (counter, by event type)
- Webhook latency (histogram, P50/P95/P99)
- Idempotency cache hits (counter)
- Plan change events (counter, by plan)
- Entitlement recompute failures (counter)

### Alerting

Set up PagerDuty alerts for:
- Webhook handler error rate > 5% (P2)
- Webhook latency P95 > 5s (P2)
- Entitlement recompute failures > 10 per hour (P3)

---

## Deployment Checklist

- [ ] SQL migration deployed (`stripe_events`, RPCs)
- [ ] `PRICE_TO_PLAN` filled in with real Stripe price IDs
- [ ] `PLAN_ENTITLEMENTS` tuned to match pricing
- [ ] Supabase bindings added to `wrangler.toml`
- [ ] Stripe webhook secret stored in Cloudflare (encrypted)
- [ ] Unit tests passing (100% coverage)
- [ ] Integration tests passing on staging
- [ ] Logs reviewed, no errors
- [ ] Alerting configured in PagerDuty
- [ ] Runbook created (in `docs/runbooks/subscription-webhook-failure.md`)
- [ ] Staging webhook endpoint updated in Stripe dashboard
- [ ] Production webhook endpoint configured in Stripe dashboard
- [ ] Rollback plan documented (revert worker, check dead letter queue)

---

## Rollback Plan

If deployment causes issues:

1. **Revert Worker:** `wrangler rollback --env production`
2. **Check dead letter queue:** Query `webhook_dead_letters` table for pending events
3. **Reconcile manually:** Run full-reconciliation script to rebuild billing state from Stripe
4. **Post-mortem:** Review logs, identify root cause, fix in new PR

---

## Related Documentation

- **[TWO_LAYER_AUTH_ARCHITECTURE.md](../TWO_LAYER_AUTH_ARCHITECTURE.md)** — Authentication context
- **[DISASTER_RECOVERY_PLAN.md](../security/DISASTER_RECOVERY_PLAN.md)** — Webhook resilience & reconciliation
- **[SECURITY_VULNERABILITY_REPORT.md](../security/SECURITY_VULNERABILITY_REPORT.md)** — Security considerations
- **[Durable Object Quota Architecture](../DURABLE_OBJECT_QUOTA_ARCHITECTURE.md)** — Quota enforcement

---

## References

- Stripe Webhooks: https://stripe.com/docs/webhooks
- Stripe Event Types: https://stripe.com/docs/api/events/types
- Verifying Signatures: https://stripe.com/docs/webhooks/signatures
- Subscription Object: https://stripe.com/docs/api/subscriptions/object
