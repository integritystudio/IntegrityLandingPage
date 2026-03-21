import { createSupabaseClient } from '../../lib/supabase';
import type { BillingStatus, PlanKey } from '../../lib/types';
import { DEAD_LETTER_MAX_RETRIES } from '../../constants';

type OkVoid = { ok: true };
type Err = { ok: false; error: string };
type VoidResult = OkVoid | Err;

function toVoidResult(result: { ok: boolean; error?: string }): VoidResult {
  return result.ok ? { ok: true } : { ok: false, error: result.error ?? 'Unknown error' };
}

export function createSupabaseAdmin(supabaseUrl: string, serviceRoleKey: string) {
  const sb = createSupabaseClient(supabaseUrl, serviceRoleKey);

  /**
   * Link Stripe customer to organization.
   */
  async function linkStripeCustomer(orgId: string, stripeCustomerId: string): Promise<VoidResult> {
    const result = await sb.update(
      'organizations',
      { stripe_customer_id: stripeCustomerId },
      [{ column: 'id', operator: 'eq', value: orgId }],
    );
    return toVoidResult(result);
  }

  /**
   * Create or update subscription.
   */
  async function upsertSubscription(
    orgId: string,
    stripeSubscriptionId: string,
    stripePriceId: string | null,
    status: string,
  ): Promise<VoidResult> {
    const now = new Date().toISOString();
    const result = await sb.upsert(
      'subscriptions',
      {
        organization_id: orgId,
        stripe_subscription_id: stripeSubscriptionId,
        stripe_price_id: stripePriceId,
        status,
        created_at: now,
        updated_at: now,
      },
      'organization_id,stripe_subscription_id',
    );
    return toVoidResult(result);
  }

  /**
   * Update org billing status and plan.
   */
  async function updateOrgBillingStatus(
    orgId: string,
    billingStatus: BillingStatus,
    planKey?: PlanKey,
    bumpQuotaVersion?: boolean,
  ): Promise<VoidResult> {
    const updates: Record<string, unknown> = { billing_status: billingStatus };

    if (planKey) {
      updates.current_plan = planKey;
    }

    if (bumpQuotaVersion) {
      updates.quota_version = null;
    }

    const result = await sb.update(
      'organizations',
      updates,
      [{ column: 'id', operator: 'eq', value: orgId }],
    );
    return toVoidResult(result);
  }

  /**
   * Find organization by Stripe customer ID.
   */
  async function findOrgByStripeCustomerId(
    stripeCustomerId: string,
  ): Promise<{ ok: true; orgId: string | null } | Err> {
    const result = await sb.query('organizations', {
      select: 'id',
      filters: [{ column: 'stripe_customer_id', operator: 'eq', value: stripeCustomerId }],
      limit: 1,
      single: true,
    });

    if (!result.ok) {
      return { ok: false, error: result.error };
    }

    const org = result.data as { id: string } | null;
    return { ok: true, orgId: org?.id ?? null };
  }

  /**
   * Check whether a Stripe event has already been processed (idempotency guard).
   * Returns a union to distinguish DB failures from "not yet processed".
   */
  async function isEventProcessed(
    stripeEventId: string,
  ): Promise<{ ok: true; processed: boolean } | { ok: false; error: string }> {
    const result = await sb.query('webhook_events_log', {
      select: 'id',
      filters: [{ column: 'stripe_event_id', operator: 'eq', value: stripeEventId }],
      limit: 1,
      single: true,
    });
    if (!result.ok) return { ok: false, error: result.error };
    return { ok: true, processed: result.data !== null };
  }

  /**
   * Record a successfully processed event to prevent duplicate processing.
   */
  async function logProcessedEvent(stripeEventId: string, eventType: string): Promise<VoidResult> {
    const result = await sb.insert('webhook_events_log', {
      stripe_event_id: stripeEventId,
      event_type: eventType,
      processed_at: new Date().toISOString(),
    });
    return toVoidResult(result);
  }

  /**
   * Write a failed event to the dead letter queue for later retry.
   * Uses next_retry_at = now + 1 min for the first attempt.
   */
  async function addDeadLetter(
    stripeEventId: string,
    eventType: string,
    payload: unknown,
    errorMessage: string,
  ): Promise<VoidResult> {
    const nextRetryAt = new Date(Date.now() + 60_000).toISOString();
    const result = await sb.insert('webhook_dead_letters', {
      stripe_event_id: stripeEventId,
      event_type: eventType,
      payload,
      error_message: errorMessage,
      retry_count: 0,
      max_retries: DEAD_LETTER_MAX_RETRIES,
      next_retry_at: nextRetryAt,
      status: 'pending',
      created_at: new Date().toISOString(),
    });
    return toVoidResult(result);
  }

  interface DeadLetter {
    [key: string]: unknown;
    id: string;
    stripe_event_id: string;
    event_type: string;
    payload: unknown;
    retry_count: number;
    max_retries: number;
  }

  /**
   * Fetch dead letters due for retry (status=pending, next_retry_at <= now, retry_count < max_retries).
   * Filters on next_retry_at to respect exponential backoff timing.
   */
  async function fetchPendingDeadLetters(limit = 50): Promise<DeadLetter[]> {
    const now = new Date().toISOString();
    const result = await sb.query<DeadLetter>('webhook_dead_letters', {
      select: 'id, stripe_event_id, event_type, payload, retry_count, max_retries',
      filters: [
        { column: 'status', operator: 'eq', value: 'pending' },
        { column: 'next_retry_at', operator: 'lte', value: now },
        { column: 'retry_count', operator: 'lt', value: DEAD_LETTER_MAX_RETRIES },
      ],
      order: { column: 'created_at', ascending: true },
      limit,
    });
    if (!result.ok) {
      console.error('fetchPendingDeadLetters DB error:', result.error);
      return [];
    }
    if (!Array.isArray(result.data)) return [];
    return result.data;
  }

  /** Mark a dead letter as resolved (successfully retried). */
  async function resolveDeadLetter(id: string): Promise<VoidResult> {
    const result = await sb.update(
      'webhook_dead_letters',
      { status: 'resolved', resolved_at: new Date().toISOString() },
      [{ column: 'id', operator: 'eq', value: id }],
    );
    return toVoidResult(result);
  }

  /** Increment retry count; abandon if max_retries reached. */
  async function failDeadLetter(id: string, retryCount: number, maxRetries: number, errorMessage: string): Promise<VoidResult> {
    const newCount = retryCount + 1;
    const newStatus = newCount >= maxRetries ? 'abandoned' : 'pending';
    const updates: Record<string, unknown> = {
      retry_count: newCount,
      error_message: errorMessage,
      status: newStatus,
    };
    // Only set next_retry_at if still pending (not abandoned)
    if (newStatus === 'pending') {
      updates.next_retry_at = new Date(Date.now() + Math.pow(2, retryCount) * 60_000).toISOString();
    }
    const result = await sb.update(
      'webhook_dead_letters',
      updates,
      [{ column: 'id', operator: 'eq', value: id }],
    );
    return toVoidResult(result);
  }

  /** Abandon a dead letter that has no registered handler. */
  async function abandonDeadLetter(id: string): Promise<VoidResult> {
    const result = await sb.update(
      'webhook_dead_letters',
      { status: 'abandoned', resolved_at: new Date().toISOString() },
      [{ column: 'id', operator: 'eq', value: id }],
    );
    return toVoidResult(result);
  }

  return {
    linkStripeCustomer,
    upsertSubscription,
    updateOrgBillingStatus,
    findOrgByStripeCustomerId,
    isEventProcessed,
    logProcessedEvent,
    addDeadLetter,
    fetchPendingDeadLetters,
    resolveDeadLetter,
    failDeadLetter,
    abandonDeadLetter,
  };
}

export type SupabaseAdmin = ReturnType<typeof createSupabaseAdmin>;
