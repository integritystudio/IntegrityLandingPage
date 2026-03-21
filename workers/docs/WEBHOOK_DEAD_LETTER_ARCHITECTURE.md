# Webhook Dead Letter Architecture

## Overview

The Stripe webhook system uses a two-layer retry model:

1. **Stripe layer (suppressed):** Stripe retries failed webhooks automatically. We suppress this by returning HTTP 200 for all processed events — including failures — and manage retries ourselves.
2. **Dead letter queue:** Handler failures are written to `webhook_dead_letters`. A reconciliation cron (every 15 min) retries pending dead letters with exponential backoff.

---

## Failure Modes and Retry Behavior

There are two distinct failure paths when processing a Stripe webhook event:

### Path A: Handler failure

**What happens:** The business logic handler (`handleCheckoutSessionCompleted`, etc.) returns `ok: false`.

**In webhook handler:** `addDeadLetter(eventId, eventType, payload, error)` is called. Event is NOT recorded in `webhook_events_log`.

**In reconciliation cron:** `failDeadLetter(id, retry_count, max_retries, error)` is called. `retry_count` is incremented. When `retry_count >= max_retries`, the dead letter is abandoned.

**Operator signal:** Dead letter row accumulates a rising `retry_count` with the handler error in the `last_error` column.

### Path B: logProcessedEvent failure (handler succeeded, logging failed)

**What happens:** The handler returns `ok: true` but writing the idempotency record to `webhook_events_log` fails.

**In webhook handler:** `addDeadLetter(eventId, eventType, payload, "logProcessedEvent failed: ...")` is called. Event is NOT recorded in `webhook_events_log` — meaning the idempotency guard cannot detect it as processed.

**In reconciliation cron:** When the cron retries and the handler succeeds again but `logProcessedEvent` fails again, the cron calls `continue` (does not call `failDeadLetter`). `retry_count` is NOT incremented.

**Operator signal:** Dead letter row stays pending indefinitely with `retry_count = 0` and a `"logProcessedEvent failed"` error. Without inspecting `last_error`, it is indistinguishable from a new dead letter awaiting its first retry.

---

## Accepted Assumptions (M38, M39)

### M38: Failure mode conflation

**Accepted assumption:** Handler failures and logProcessedEvent failures share the same dead letter row structure with no `failure_type` discriminator column. An operator querying `webhook_dead_letters` cannot distinguish "handler failed" from "handler succeeded but logging failed" by column alone — they must inspect `last_error` text.

**Accepted trade-off:** Both failure paths have reasonable retry behavior:
- Handler failures retry with exponential backoff until `max_retries` is reached.
- Logging failures retry on every cron tick without consuming `retry_count`, because logging is expected to be transient infrastructure.

**If this becomes a problem:** Add a `failure_type` enum column (`handler_error` | `logging_error`) to `webhook_dead_letters` with separate backoff curves per type.

### M39: Indefinite pending on sustained logging outage

**Accepted assumption:** When `logProcessedEvent` fails repeatedly (e.g., sustained Supabase outage), the dead letter stays pending indefinitely — `retry_count` is never incremented, so `max_retries` is never reached, and the row is never abandoned.

**Rationale:** This is intentional. Abandoning a dead letter where the handler succeeded but logging failed would silently drop the event from the idempotency record, allowing Stripe retries to replay it. Indefinite pending is safer than silent abandonment.

**Handler idempotency requirement:** All handlers MUST be fully idempotent. Because a dead letter in Path B causes the handler to run again on each cron tick (until logging succeeds), re-running a handler that already applied its DB write must produce no net effect.

**If sustained logging failures occur:**
1. The dead letter stays in `pending` state with a `"logProcessedEvent failed"` error.
2. The handler runs on each cron tick (idempotent, so no duplicate side effects).
3. Once Supabase connectivity is restored, `logProcessedEvent` succeeds, `resolveDeadLetter` is called, and the row is resolved normally.
4. If logging never recovers permanently, a manual `resolveDeadLetter` call is required to clean up the row.

---

## Flow Diagrams

### Initial webhook processing

```
Stripe POST /webhook
  ↓
verifyStripeSignature()
  ↓
isEventProcessed(eventId)         ← idempotency guard
  ├─ DB error → 500 serverError   ← NOTE: only case where Stripe retry is NOT suppressed
  ├─ already processed → 200 skipped
  └─ not processed → continue
      ↓
    handler(event, db)
      ├─ ok: false → addDeadLetter() → 200 {processed: false, error}   [Path A]
      └─ ok: true → logProcessedEvent(eventId)
            ├─ ok: false → addDeadLetter("logProcessedEvent failed") → 200  [Path B]
            └─ ok: true → 200 {processed: true}                            [Success]
```

**Note on Stripe retry suppression:** All paths except `isEventProcessed` DB error return HTTP 200. The 500 on idempotency check failure is the sole case where Stripe's built-in retry takes over.

### Reconciliation cron (every 15 min)

```
fetchPendingDeadLetters(50)
  ↓
for each dead letter:
  ↓
  isEventProcessed(stripe_event_id)
    ├─ DB error → skip (fail-closed, no double-process)
    ├─ processed → resolveDeadLetter()   ← orphan cleanup (e.g. prior resolveDeadLetter failed)
    └─ not processed → handler(event, db)
          ├─ unknown event_type → abandonDeadLetter() ← removed from retry queue immediately
          ├─ ok: false → failDeadLetter() (retry_count++)              [Path A retry]
          └─ ok: true → logProcessedEvent()
                ├─ ok: false → continue (retry_count unchanged)        [Path B retry]
                └─ ok: true → resolveDeadLetter()
                      └─ if resolveDeadLetter fails: leave pending; next run's isEventProcessed
                         guard detects event as processed and calls resolveDeadLetter again
```

---

## Files

| File | Role |
|------|------|
| `workers/stripe-webhook/src/index.ts` | Webhook handler + reconciliation cron |
| `workers/stripe-webhook/src/handlers/` | Business logic handlers (must be idempotent) |
| `workers/stripe-webhook/src/supabase.ts` | DB client: `addDeadLetter`, `failDeadLetter`, `resolveDeadLetter`, `logProcessedEvent` |

---

## Testing

```bash
cd workers/stripe-webhook
npx vitest run
```

Tests cover handler success/failure paths, idempotency guard, dead letter creation, and reconciliation retry logic.
