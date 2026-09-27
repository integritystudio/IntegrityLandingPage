# Webhook Dead Letter Architecture

## Overview

The Stripe webhook system uses a two-layer retry model:

1. **Stripe layer (suppressed):** Stripe retries anything that is not a 2xx. The handler verifies the signature, **atomically claims** the event (`claimEvent`: `INSERT … ON CONFLICT DO NOTHING` into `webhook_events_log`), and returns `200 {ok: true, queued: true}` *before* running any business logic; the handler itself runs afterwards inside `ctx.waitUntil` (BACKLOG.md CR21). A duplicate delivery loses the claim and gets `200 {ok: true, queued: false, skipped: true, reason: 'already_processed'}`. The only non-2xx paths are a bad signature and a claim that fails at the database (`500 Failed to check idempotency`) — those are the only cases where Stripe's own retry takes over.
2. **Dead letter queue:** When the deferred handler fails, the claim is removed (`unclaimEvent`) and the event is written to `webhook_dead_letters`. A reconciliation cron (every 15 min) retries pending dead letters with exponential backoff (`2^retry_count × 1 min`, up to `DEAD_LETTER_MAX_RETRIES = 5`).

---

## Failure Modes and Retry Behavior

There are two distinct failure paths once an event has been claimed:

### Path A: Handler failure

**What happens:** The business logic handler (`handleCheckoutSessionCompleted`, etc.) returns `ok: false`, or throws — `processEvent` converts a throw into `ok: false` so it takes the same path.

**In the deferred handler (`processEvent`):** Stripe has already received the 2xx. `unclaimEvent(eventId)` deletes the `webhook_events_log` row (best effort), then `addDeadLetter(eventId, eventType, payload, error)` writes the row with `retry_count = 0`, `max_retries = 5`, `next_retry_at = now + 1 min`. If the dead-letter insert itself fails there is no retry path left — a `CRITICAL` log line carries the full payload and recovery is a manual replay.

**In reconciliation cron:** the handler runs again; on `ok: false`, `failDeadLetter(id, retry_count, max_retries, error)` increments `retry_count` and sets the next backoff. When `retry_count >= max_retries` the dead letter is abandoned.

**Operator signal:** Dead letter row accumulates a rising `retry_count` with the handler error in `error_message`.

### Path B: Claim failure after a successful retry (handler succeeded, claim write failed)

**What happens:** In the cron, the handler returns `ok: true` but `claimEvent` — the write that records the event as processed — returns a DB error.

**In reconciliation cron:** the cron logs and `continue`s. It does **not** call `failDeadLetter`, so `retry_count` is not incremented, and it does not resolve the row. `claimed: false` (another cron tick already claimed it) is *not* an error: the event is logged, so the row is resolved normally.

**Operator signal:** Dead letter row stays pending with `retry_count` unchanged. Without inspecting the cron logs it is indistinguishable from a dead letter awaiting its first retry.

Note that the original webhook path has no Path B: the claim happens *before* the handler, so "handler succeeded but logging failed" cannot occur there. The inverse hazard exists instead — if `unclaimEvent` fails after a handler failure, the event stays logged as processed, the cron's guard sees it as processed and **resolves the dead letter without retrying**. That is logged as an error; it is not self-healing.

---

## Accepted Assumptions (M38, M39)

### M38: Failure mode conflation

**Accepted assumption:** Handler failures and claim-write failures share the same dead letter row structure with no `failure_type` discriminator column. An operator querying `webhook_dead_letters` cannot distinguish "handler failed" from "handler succeeded but the claim write failed" by column alone.

**Accepted trade-off:** Both failure paths have reasonable retry behavior:
- Handler failures retry with exponential backoff until `max_retries` is reached.
- Claim-write failures retry on every cron tick without consuming `retry_count`, because the database write is expected to be transient infrastructure.

**If this becomes a problem:** Add a `failure_type` enum column (`handler_error` | `logging_error`) to `webhook_dead_letters` with separate backoff curves per type.

### M39: Indefinite pending on sustained database outage

**Accepted assumption:** When `claimEvent` fails repeatedly in the cron (e.g., sustained Supabase outage), the dead letter stays pending indefinitely — `retry_count` is never incremented, so `max_retries` is never reached, and the row is never abandoned.

**Rationale:** This is intentional. Abandoning a dead letter where the handler succeeded but the claim was never written would drop the event from the idempotency record. Indefinite pending is safer than silent abandonment.

**Handler idempotency requirement:** All handlers MUST be fully idempotent. A Path B dead letter causes the handler to run again on each cron tick until the claim write succeeds, so re-running a handler that already applied its DB write must produce no net effect.

**If sustained database failures occur:**
1. The dead letter stays in `pending` state with its original `error_message`.
2. The handler runs on each eligible cron tick (idempotent, so no duplicate side effects).
3. Once Supabase connectivity is restored, `claimEvent` succeeds, `resolveDeadLetter` is called, and the row is resolved normally.
4. If the write never recovers, a manual `resolveDeadLetter` call is required to clean up the row.

---

## Flow Diagrams

### Initial webhook processing (`handleWebhook` → `processEvent`)

```
Stripe POST /webhook
  ↓
verifyStripeSignature()
  ├─ invalid → 4xx (Stripe retries)
  ↓
claimEvent(eventId, eventType)        ← atomic idempotency claim
  ├─ DB error      → 500 "Failed to check idempotency"   ← Stripe retry NOT suppressed
  ├─ claimed=false → 200 {ok:true, queued:false, skipped:true, reason:'already_processed'}
  └─ claimed=true  → 200 {ok:true, queued:true}          ← response sent HERE
        ↓ (ctx.waitUntil)
      processEvent(event, db, priceToPlan)
        ├─ unknown event.type → log, done (claim stays)
        ├─ ok: true           → done
        └─ ok: false / threw  → unclaimEvent(eventId)          [Path A]
                                  └─ fails → logged; cron will RESOLVE, not retry
                                addDeadLetter(next_retry_at = now + 1 min)
                                  └─ fails → CRITICAL log with payload; manual replay
```

**Note on Stripe retry suppression:** Every claimed event returns 200 before its handler runs, so Stripe never retries a handler failure — the cron owns that schedule. Only a signature failure or a claim that errors at the database yields a non-2xx.

### Reconciliation cron (every 15 min, `runReconciliation`)

```
fetchPendingDeadLetters(50)            ← status=pending, next_retry_at <= now, retry_count < max
  ↓ sorted by payload.created ascending (replay in Stripe's order)
for each dead letter:
  ↓
  isEventProcessed(stripe_event_id)
    ├─ DB error  → skip (fail-closed, no double-process)
    ├─ processed → resolveDeadLetter()   ← orphan cleanup (prior resolve failed, or unclaim failed)
    └─ not processed → handler(event, db)
          ├─ unknown event_type → abandonDeadLetter() ← removed from retry queue immediately
          ├─ ok: false → failDeadLetter() (retry_count++, backoff 2^n × 1 min)  [Path A retry]
          └─ ok: true  → claimEvent()
                ├─ DB error      → continue (retry_count unchanged)             [Path B]
                └─ claimed (either value) → resolveDeadLetter()
                      └─ if resolveDeadLetter fails: leave pending; next run's isEventProcessed
                         guard detects event as processed and calls resolveDeadLetter again
```

**Note on `fetchPendingDeadLetters` timing:**

The cron queries with `next_retry_at <= now()`. `addDeadLetter` writes `next_retry_at = now() + 1 minute`, and `failDeadLetter` doubles the delay on each retry. This means:
- First cron tick after creation (if within the minute): dead letter is **excluded**
- Cron tick 1+ minutes later: dead letter is **included** and retried
- **Impact:** every dead letter has at least a 1-minute initial delay before its first cron retry

This backoff window gives transient infrastructure issues time to resolve before the retry. If immediate retry is needed, `next_retry_at` can be updated manually or the cron run by hand.

---

## Files

| File | Role |
|------|------|
| `workers/stripe-webhook/src/index.ts` | `handleWebhook` (verify → claim → 2xx → `waitUntil(processEvent)`) + `runReconciliation` cron |
| `workers/stripe-webhook/src/handlers/` | Business logic handlers (must be idempotent) |
| `workers/stripe-webhook/src/supabase.ts` | DB client: `claimEvent`, `unclaimEvent`, `isEventProcessed`, `addDeadLetter`, `fetchPendingDeadLetters`, `failDeadLetter`, `resolveDeadLetter`, `abandonDeadLetter` |
| `workers/constants.ts` | `DEAD_LETTER_MAX_RETRIES`, `DEAD_LETTER_INITIAL_RETRY_DELAY_MS` |

---

## Testing

```bash
cd workers/stripe-webhook
npx vitest run
```

Tests cover the claim-before-ack flow, duplicate suppression, dead letter creation on handler failure, and reconciliation retry logic.
