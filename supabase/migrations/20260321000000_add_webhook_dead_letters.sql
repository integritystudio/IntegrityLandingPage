-- Migration: Add webhook dead letter queue for Stripe event resilience
-- Backlog: T23 — Webhook Resilience & Dead Letter Queue (Phase 1 of DR plan)
-- See: docs/security/DISASTER_RECOVERY_PLAN.md (Scenario D)

CREATE TABLE IF NOT EXISTS webhook_dead_letters (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    -- Stripe event ID is the idempotency key; globally unique per event
    stripe_event_id TEXT NOT NULL UNIQUE,
    event_type      TEXT NOT NULL,
    payload         JSONB NOT NULL,
    error_message   TEXT,
    retry_count     INT NOT NULL DEFAULT 0,
    max_retries     INT NOT NULL DEFAULT 5,
    next_retry_at   TIMESTAMPTZ,
    -- pending: awaiting retry | resolved: handled | abandoned: max retries exceeded
    status          TEXT NOT NULL DEFAULT 'pending'
                    CHECK (status IN ('pending', 'resolved', 'abandoned')),
    created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    resolved_at     TIMESTAMPTZ
);

-- Index for the reconciliation cron: fetch pending items due for retry
CREATE INDEX IF NOT EXISTS idx_dead_letters_retry
    ON webhook_dead_letters (status, next_retry_at)
    WHERE status = 'pending';

-- Index for gap detection: fast lookup by stripe_event_id
CREATE INDEX IF NOT EXISTS idx_dead_letters_event_id
    ON webhook_dead_letters (stripe_event_id);

-- Webhook events log: records every successfully processed Stripe event for
-- idempotency checks and gap detection in the reconciliation cron.
CREATE TABLE IF NOT EXISTS webhook_events_log (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    stripe_event_id TEXT NOT NULL UNIQUE,
    event_type      TEXT NOT NULL,
    processed_at    TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_webhook_events_log_event_id
    ON webhook_events_log (stripe_event_id);
