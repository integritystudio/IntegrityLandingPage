# Stripe Webhook Handler Design: Subscription Updates

> **Research record — implemented.** Shipped in `workers/stripe-webhook/src/handlers/subscription.ts` (`customer.subscription.updated`/`deleted`). Condensed from the original proposal; see [changelog 1.3](../changelog/1.3/CHANGELOG.md) "Superseded Design-Doc Reconciliation".

**Original date:** 2026-07-12 (pre-implementation) · **Domain:** Billing webhook architecture

---

## Overview

Design for the Stripe webhook handler covering subscription lifecycle events. The handler processes `customer.subscription.updated` and `customer.subscription.deleted`, updating billing status, syncing plan tier, recomputing entitlements, and invalidating edge caches via `quota_version` bumps.

**Responsibilities:**
1. Verify Stripe event authenticity (HMAC-SHA256 signature)
2. Idempotency via Stripe event ID tracking
3. Resolve organization by Stripe customer ID
4. Upsert subscription records (price, status)
5. Update org billing status and plan tier
6. Recompute entitlements when plan changes
7. Bump `quota_version` to invalidate caches
8. Handle edge cases (unknown plans, missing orgs, network failures)

## Architecture

```text
Stripe Dashboard / API (subscription updated/deleted)
        │
        ▼
Cloudflare Worker (POST /webhooks)
  1. Verify HMAC signature
  2. Check idempotency
  3. Resolve org by customer ID
  4. Upsert subscription
  5. Update billing + plan
  6. Recompute entitlements
  7. Bump quota_version
  8. Record event
        │
   ┌────┼──────────────┐
   ▼    ▼              ▼
Supabase (DB)   Durable Objects   Logs
                (quota invalidation)
```

## Database schema

**Idempotency table:**
```sql
CREATE TABLE stripe_events (
  id            TEXT PRIMARY KEY,       -- Stripe event ID (evt_1Abc...)
  event_type    TEXT NOT NULL,
  processed_at  TIMESTAMPTZ NOT NULL DEFAULT now()
);
-- Cleanup: delete events older than 30 days (Stripe retry window is 3 days)
```

**Atomic RPCs:**
- `update_org_billing(org_id, billing_status, plan_key?, bump_quota_version?)` — updates `organizations.billing_status`/`current_plan`, conditionally increments `quota_version`, in a single statement.
- `replace_entitlements(org_id, entitlements_jsonb)` — deletes all existing entitlement rows for the org and inserts the new set atomically (no partial-state window).

**Existing tables used (no schema changes required):**
- `organizations`: `stripe_customer_id`, `current_plan` (free|growth|enterprise), `billing_status` (active|past_due|cancelled|inactive), `quota_version`
- `subscriptions`: `organization_id`, `stripe_subscription_id` (unique), `stripe_price_id` (→ plan via `PRICE_TO_PLAN`), `status`, timestamps
- `entitlements`: `organization_id`, `feature_key` (unique per org), `enabled`, `hard_limit`, `soft_limit`

## Handler flows

**`handleSubscriptionUpdated`:**
1. Validate event shape (customer ID, subscription ID, status)
2. Idempotency guard — skip if event ID already processed
3. Resolve org by Stripe customer ID
4. Extract price ID, resolve plan key via `PRICE_TO_PLAN`
5. Upsert subscription record
6. Update org billing status + plan
7. If plan changed (detected via `previous_attributes.items`), recompute entitlements
8. Mark event processed; return 200 OK

**`handleSubscriptionDeleted`:**
1. Validate event shape
2. Idempotency guard
3. Resolve org
4. Mark subscription canceled
5. Downgrade org to free plan
6. Recompute entitlements to free-tier limits
7. Mark event processed

**Billing-status mapping:** Stripe subscription statuses map directly onto `organizations.billing_status`, with `trialing` treated as `active` (trialing users get full plan access, not a limited-access tier). Status-only changes (no `items` in `previous_attributes`) update `billing_status` without touching entitlements; plan changes trigger a full entitlement recompute.

**Entry point routing** (`workers/stripe-webhook/src/index.ts`): parse body → verify `stripe-signature` header via HMAC → reject replays outside a 5-minute window → route by `event.type` to the matching handler → unknown event types return `{ ok: true }` without processing → handler failures return 400 with the error, uncaught exceptions return 500.

## Idempotency and security considerations

- **Signature verification** is mandatory before any processing; unsigned/invalid requests get 401.
- **Replay protection** rejects events with a `created` timestamp outside a 5-minute window, independent of the idempotency table.
- **Idempotency is non-fatal** — if the `stripe_events` table is unavailable, events still process rather than blocking (graceful degradation over strict correctness).
- **RPC with direct-update fallback**: the Worker calls the `update_org_billing`/`replace_entitlements` RPCs first; if unavailable (e.g. migration not yet deployed) it falls back to a direct table update. This decouples Worker deploys from migration deploys — no chicken-and-egg dependency in CI/CD.
- **Entitlement recompute failure does not fail the webhook** — billing status is the critical path; entitlements can be repaired independently, so a partial failure still leaves billing state correct.
- **Plan-change detection via `previous_attributes`** avoids unnecessary entitlement rewrites on pure status-change events (e.g. `active` → `past_due`).
- **Plan definitions live in code** (`PLAN_ENTITLEMENTS` in `plans.ts`), not the DB, so they deploy atomically with the Worker rather than needing a separate runtime data migration.
- **30-day idempotency cleanup window** — generous margin over Stripe's 3-day retry window.

## Key design decisions

| Decision | Rationale | Alternative |
|----------|-----------|--------------|
| RPC + direct-update fallback | Worker deploys before migration runs | Wait for migration first (more complex CI/CD) |
| Idempotency is non-fatal | Events still process if table missing | Fail the webhook if table missing |
| Entitlement failure doesn't fail webhook | Billing status is critical; entitlements are repairable | Fail webhook if entitlements fail |
| `trialing` → `active` | Trialing users get full plan access | Limited access during trial |
| `previous_attributes` for plan-change detection | Avoids unnecessary entitlement rewrites | Always recompute (wastes IO) |
| `PLAN_ENTITLEMENTS` as code, not DB | Plan definitions deploy atomically with code | Plans in DB (adds runtime complexity) |
| 30-day cleanup window | Stripe retries max 3 days; safe margin | 3-day cleanup (risky if async jobs lag) |

## Testing coverage

Unit tests cover: idempotency (duplicate events produce no duplicate writes), plan-change detection (recomputes entitlements only when `previous_attributes.items` present), unknown-plan handling (billing status updates, plan left unchanged, warning logged), missing-org handling (returns 200, not 400), and subscription-deleted downgrade (org reset to free plan + free-tier entitlements).

Integration tests (staging, real Stripe) cover end-to-end upgrade/downgrade/cancellation flows and event-replay idempotency.

## Observability

Structured logs keyed by event type and `org_id`/`status`/`plan_key`; warnings for missing-org lookups and RPC fallback; errors for entitlement recompute failures (non-fatal to the webhook). Metrics: events processed by type, webhook latency (P50/P95/P99), idempotency cache hits, plan-change events by plan, entitlement-recompute failure count.

## Related documentation

- [TWO_LAYER_AUTH_ARCHITECTURE.md](../TWO_LAYER_AUTH_ARCHITECTURE.md) — auth context
- [DISASTER_RECOVERY_PLAN.md](../security/DISASTER_RECOVERY_PLAN.md) — webhook resilience & reconciliation
- [SECURITY_VULNERABILITY_REPORT.md](../security/SECURITY_VULNERABILITY_REPORT.md) — security considerations
- [Durable Object Quota Architecture](../DURABLE_OBJECT_QUOTA_ARCHITECTURE.md) — quota enforcement
