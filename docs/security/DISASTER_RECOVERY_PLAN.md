# Disaster Recovery Plan for the Billing System

## Architecture Context

Based on the Integrity Studio payment processor architecture (Stripe + Supabase + Cloudflare Workers + Flutter), here's a comprehensive disaster recovery plan organized by failure domain.

---

## 1. Failure Domain Analysis

### Critical Path Components
| Component | RPO | RTO | Impact if Down |
|-----------|-----|-----|----------------|
| **Stripe** (payments) | 0 (managed) | N/A (SaaS) | Cannot process new payments |
| **Supabase** (auth + data) | < 1 min | < 15 min | No auth, no subscription data |
| **Cloudflare Workers** (provisioning) | 0 (stateless) | < 5 min | Cannot provision/enforce limits |
| **Durable Objects** (rate limits) | < 1 min | < 5 min | No precise quota enforcement |
| **Webhook pipeline** | 0 (queued) | < 30 min | Delayed provisioning |

> **RPO** = Recovery Point Objective (max data loss), **RTO** = Recovery Time Objective (max downtime)

---

## 2. Disaster Scenarios & Recovery Procedures

### Scenario A: Supabase Database Outage

**Risk**: Loss of subscription state, entitlements, API keys, usage records.

**Mitigation Strategy**:
```
┌─────────────────────────────────────────────────┐
│           Supabase DR Architecture               │
│                                                   │
│  Primary (Supabase)  ──WAL──▶  Replica (standby) │
│        │                            │             │
│        ▼                            ▼             │
│  Point-in-Time Recovery      Read Replica         │
│  (Supabase backups)          (hot standby)        │
│        │                                          │
│        ▼                                          │
│  External Backup (S3/R2)                          │
│  - Nightly logical dumps                          │
│  - Continuous WAL archiving                       │
└─────────────────────────────────────────────────┘
```

**Recovery Procedures**:

1. **Automated Failover** (RTO < 5 min):
   - Supabase Pro/Enterprise includes automatic failover to read replicas
   - Connection strings update via DNS — Workers reconnect automatically

2. **Point-in-Time Recovery** (RTO < 30 min):
   ```sql
   -- Verify data integrity after restore
   SELECT o.id, o.stripe_customer_id, s.stripe_subscription_id, s.status
   FROM organizations o
   JOIN subscriptions s ON s.organization_id = o.id
   WHERE s.status = 'active'
     AND s.current_period_end < NOW();
   -- Any rows = subscriptions that may have been updated during outage
   ```

3. **External Backup Restore** (RTO < 2 hrs):
   - Nightly pg_dump to Cloudflare R2 (encrypted, versioned)
   - Restore to fresh Supabase project
   - Reconcile with Stripe as source of truth (see Scenario E)

**Scheduled Backup Job** (Cloudflare Cron Trigger):
```typescript
// workers/backup-cron.ts — runs nightly at 02:00 UTC
export default {
  async scheduled(event: ScheduledEvent, env: Env) {
    const timestamp = new Date().toISOString().split('T')[0];

    // Core billing tables to back up
    const tables = [
      'organizations', 'subscriptions', 'entitlements',
      'api_keys', 'usage_records', 'invoices'
    ];

    for (const table of tables) {
      const { data, error } = await supabase
        .from(table)
        .select('*');

      if (error) {
        await alertOps(`Backup failed for ${table}: ${error.message}`);
        continue;
      }

      // Encrypt and upload to R2
      const encrypted = await encrypt(JSON.stringify(data), env.BACKUP_KEY);
      await env.BACKUP_BUCKET.put(
        `${timestamp}/${table}.json.enc`,
        encrypted,
        { httpMetadata: { contentType: 'application/octet-stream' } }
      );
    }

    await alertOps(`Backup completed: ${tables.length} tables archived`);
  }
};
```

---

### Scenario B: Stripe Outage

**Risk**: Cannot process payments, receive webhooks, or verify subscription status.

**Mitigation Strategy**: **Graceful Degradation with Cached State**

```typescript
// workers/entitlement-check.ts — degraded mode
async function checkEntitlement(orgId: string, env: Env): Promise<EntitlementResult> {
  // 1. Always check local DB first (Supabase is source of provisioned state)
  const { data: entitlement } = await supabase
    .from('entitlements')
    .select('*, subscriptions!inner(*)')
    .eq('organization_id', orgId)
    .single();

  if (!entitlement) {
    return { allowed: false, reason: 'no_entitlement' };
  }

  // 2. Grace period: if subscription expired < 72 hours ago, still allow access
  const GRACE_PERIOD_HOURS = 72;
  const periodEnd = new Date(entitlement.subscriptions.current_period_end);
  const graceEnd = new Date(periodEnd.getTime() + GRACE_PERIOD_HOURS * 3600000);

  if (new Date() > graceEnd) {
    return { allowed: false, reason: 'subscription_expired_beyond_grace' };
  }

  // 3. If within grace period but expired, flag for reconciliation
  if (new Date() > periodEnd) {
    await env.RECONCILIATION_QUEUE.send({
      type: 'verify_subscription',
      orgId,
      stripeSubscriptionId: entitlement.subscriptions.stripe_subscription_id,
      flaggedAt: new Date().toISOString()
    });
  }

  return { allowed: true, tier: entitlement.tier, degraded: new Date() > periodEnd };
}
```

**Key Principle**: During a Stripe outage, **never cut off paying customers**. The local database has the last-known subscription state. Apply a grace period and reconcile when Stripe recovers.

---

### Scenario C: Cloudflare Workers Outage

**Risk**: Cannot enforce rate limits, provision resources, or serve API middleware.

**Mitigation Strategy**:

1. **Multi-region Workers** (automatic — CF deploys globally)
2. **Fallback Origin Server**:
   ```
   Cloudflare DNS (proxy)
        │
        ├── Workers (primary) ──▶ Business logic
        │
        └── Origin (fallback) ──▶ Minimal Express/Hono server
                                    on Fly.io / Railway
                                    - Auth verification
                                    - Basic rate limiting (in-memory)
                                    - Pass-through to Supabase
   ```

3. **Fallback Rate Limiting**: If Durable Objects are unavailable, fall back to approximate rate limiting using Cloudflare's built-in rate limiting rules (configured in dashboard as backup).

---

### Scenario D: Webhook Pipeline Failure

**Risk**: Stripe events (subscription changes, payments) not processed → stale provisioning state.

This is the **most likely** disaster scenario. Mitigation is critical.

```
┌──────────────────────────────────────────────────────┐
│              Webhook Resilience Architecture           │
│                                                        │
│  Stripe ──webhook──▶ Worker (primary endpoint)         │
│    │                      │                            │
│    │                      ├──▶ Process immediately     │
│    │                      │                            │
│    │                      └──▶ Write to dead_letter    │
│    │                           queue on failure        │
│    │                                                   │
│    └──retry (up to 3x)──▶ Worker (same endpoint)      │
│                                                        │
│  Cron (every 15 min) ──▶ Reconciliation Worker         │
│                              │                         │
│                              ├──▶ Process dead_letters │
│                              └──▶ Stripe List Events   │
│                                   (gap detection)      │
└──────────────────────────────────────────────────────┘
```

**Dead Letter Table**:
```sql
CREATE TABLE webhook_dead_letters (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    stripe_event_id TEXT NOT NULL UNIQUE,  -- idempotency key
    event_type      TEXT NOT NULL,
    payload         JSONB NOT NULL,
    error_message   TEXT,
    retry_count     INT DEFAULT 0,
    max_retries     INT DEFAULT 5,
    next_retry_at   TIMESTAMPTZ,
    status          TEXT DEFAULT 'pending', -- pending | processing | resolved | abandoned
    created_at      TIMESTAMPTZ DEFAULT NOW(),
    resolved_at     TIMESTAMPTZ
);

CREATE INDEX idx_dead_letters_retry ON webhook_dead_letters (status, next_retry_at)
    WHERE status = 'pending';
```

**Reconciliation Worker**:
```typescript
// workers/reconciliation-cron.ts — runs every 15 minutes
async function reconcileSubscriptions(env: Env) {
  // 1. Retry dead letters with exponential backoff
  const { data: deadLetters } = await supabase
    .from('webhook_dead_letters')
    .select('*')
    .eq('status', 'pending')
    .lte('next_retry_at', new Date().toISOString())
    .lt('retry_count', 5)
    .order('created_at', { ascending: true })
    .limit(50);

  for (const dl of deadLetters ?? []) {
    try {
      await processWebhookEvent(JSON.parse(dl.payload));
      await supabase
        .from('webhook_dead_letters')
        .update({ status: 'resolved', resolved_at: new Date().toISOString() })
        .eq('id', dl.id);
    } catch (err) {
      const nextRetry = new Date(Date.now() + Math.pow(2, dl.retry_count) * 60000);
      await supabase
        .from('webhook_dead_letters')
        .update({
          retry_count: dl.retry_count + 1,
          next_retry_at: nextRetry.toISOString(),
          error_message: err.message
        })
        .eq('id', dl.id);
    }
  }

  // 2. Gap detection — fetch recent Stripe events and verify we processed them
  const recentEvents = await stripe.events.list({
    limit: 100,
    created: { gte: Math.floor(Date.now() / 1000) - 3600 } // last hour
  });

  for (const event of recentEvents.data) {
    const { count } = await supabase
      .from('webhook_events_log')
      .select('id', { count: 'exact', head: true })
      .eq('stripe_event_id', event.id);

    if (count === 0) {
      console.log(`Gap detected: ${event.id} (${event.type})`);
      await processWebhookEvent(event);
    }
  }
}
```

---

### Scenario E: Full Reconciliation (Nuclear Option)

**When**: After extended outage, data corruption, or restore from backup.

**Stripe is the ultimate source of truth for billing state.** Use it to rebuild local state:

```typescript
// scripts/full-reconciliation.ts
async function fullReconciliation() {
  console.log('⚠️  Starting full reconciliation from Stripe...');

  let hasMore = true;
  let startingAfter: string | undefined;

  while (hasMore) {
    const customers = await stripe.customers.list({
      limit: 100,
      starting_after: startingAfter,
      expand: ['data.subscriptions']
    });

    for (const customer of customers.data) {
      // 1. Upsert organization
      await supabase
        .from('organizations')
        .upsert({
          stripe_customer_id: customer.id,
          name: customer.name ?? customer.email,
          email: customer.email,
          updated_at: new Date().toISOString()
        }, { onConflict: 'stripe_customer_id' });

      // 2. Upsert subscriptions
      for (const sub of customer.subscriptions?.data ?? []) {
        const tier = mapPriceToTier(sub.items.data[0]?.price.id);

        await supabase
          .from('subscriptions')
          .upsert({
            stripe_subscription_id: sub.id,
            stripe_customer_id: customer.id,
            status: sub.status,
            tier,
            current_period_start: new Date(sub.current_period_start * 1000).toISOString(),
            current_period_end: new Date(sub.current_period_end * 1000).toISOString(),
            cancel_at_period_end: sub.cancel_at_period_end,
            updated_at: new Date().toISOString()
          }, { onConflict: 'stripe_subscription_id' });

        // 3. Rebuild entitlements from tier
        await provisionEntitlements(customer.id, tier);
      }
    }

    hasMore = customers.has_more;
    startingAfter = customers.data[customers.data.length - 1]?.id;
  }

  console.log('✅ Full reconciliation complete');
}
```

---

## 3. Monitoring & Alerting

```
┌─────────────────────────────────────────────────┐
│              Monitoring Stack                     │
│                                                   │
│  Cloudflare Analytics ──▶ Worker error rates      │
│  Supabase Dashboard   ──▶ DB health, connections  │
│  Stripe Dashboard     ──▶ Webhook delivery rate   │
│                                                   │
│  Custom Alerts (via Worker cron):                 │
│  ┌─────────────────────────────────────────────┐ │
│  │ • Webhook gap > 5 min  → PagerDuty P2      │ │
│  │ • Dead letters > 10    → PagerDuty P2      │ │
│  │ • DB replica lag > 30s → PagerDuty P1      │ │
│  │ • Entitlement check    → PagerDuty P1      │ │
│  │   failure rate > 5%                         │ │
│  │ • Backup job missed    → PagerDuty P2      │ │
│  │ • Reconciliation drift → PagerDuty P3      │ │
│  │   (Stripe vs DB mismatch)                   │ │
│  └─────────────────────────────────────────────┘ │
└─────────────────────────────────────────────────┘
```

**Health Check Endpoint**:
```typescript
// workers/health.ts
export async function healthCheck(env: Env): Promise<Response> {
  const checks = await Promise.allSettled([
    supabase.from('organizations').select('id', { count: 'exact', head: true }),
    stripe.customers.list({ limit: 1 }),
    env.RATE_LIMITER.get(env.RATE_LIMITER.idFromName('health')).fetch('/ping'),
  ]);

  const results = {
    database: checks[0].status === 'fulfilled' ? 'healthy' : 'degraded',
    stripe: checks[1].status === 'fulfilled' ? 'healthy' : 'degraded',
    durableObjects: checks[2].status === 'fulfilled' ? 'healthy' : 'degraded',
    timestamp: new Date().toISOString(),
  };

  const allHealthy = Object.values(results).every(v => v === 'healthy' || v === results.timestamp);

  return Response.json(results, { status: allHealthy ? 200 : 503 });
}
```

---

## 4. Implementation Phases

| Phase | Scope | Timeline |
|-------|-------|----------|
| **Phase 1** | Webhook idempotency + dead letter queue + basic health check | Week 1-2 |
| **Phase 2** | Nightly R2 backups + reconciliation cron + gap detection | Week 3-4 |
| **Phase 3** | Grace period logic + degraded mode for Stripe outages | Week 5-6 |
| **Phase 4** | Full monitoring/alerting + runbook documentation + DR drills | Week 7-8 |

---

## 5. DR Drill Schedule

Run these **quarterly**:

| Drill | Procedure | Success Criteria |
|-------|-----------|------------------|
| **Backup Restore** | Restore nightly backup to staging Supabase | All tables restored, app functional |
| **Webhook Blackout** | Disable webhook endpoint for 1 hr, then re-enable | Reconciliation catches all missed events within 30 min |
| **Stripe Degraded** | Simulate Stripe API 500s in staging | Customers retain access via grace period |
| **Full Reconciliation** | Run nuclear reconciliation script on staging | Local DB matches Stripe state 100% |

---

## Key Design Principles

1. **Stripe is the source of truth** for billing — always reconcile toward it
2. **Never cut off paying customers** during outages — use grace periods
3. **Idempotency everywhere** — every webhook handler, every upsert, every reconciliation step
4. **Defense in depth** — dead letters → retry → cron reconciliation → gap detection → full reconciliation
5. **Fail open for reads, fail closed for writes** — let users access features during outages, but don't create new subscriptions against stale data
