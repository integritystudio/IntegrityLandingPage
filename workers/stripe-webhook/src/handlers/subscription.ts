import type { SubscriptionPeriod, SupabaseAdmin } from '../supabase';
import type { HandlerResult, ApiKeyTier, StripeEvent } from '../../../lib/types';
import { toBillingStatus } from '../../../lib/billing';
import { SubscriptionSchema, type SubscriptionItem } from '../stripe-schemas';

const MS_PER_SECOND = 1_000;

/**
 * Billing period of a subscription item as ISO timestamps, or `undefined` when the
 * item carries neither bound. Stripe sends epoch seconds; the column is timestamptz.
 * Both bounds or nothing — a half-open period would be a Stripe payload bug, not a
 * state worth persisting.
 */
export function subscriptionPeriod(item: SubscriptionItem | undefined): SubscriptionPeriod | undefined {
  if (item?.current_period_start === undefined || item.current_period_end === undefined) return undefined;
  return {
    start: new Date(item.current_period_start * MS_PER_SECOND).toISOString(),
    end: new Date(item.current_period_end * MS_PER_SECOND).toISOString(),
  };
}


// Status handling lives in `workers/lib/billing.ts`. `BillingStatus` mirrors Stripe's
// vocabulary, so storing a status needs no mapping here — `toBillingStatus` is a
// validated pass-through, and `isEntitled` holds the only policy decision.

/**
 * Handle customer.subscription.updated event.
 * Updates subscription status and may recompute entitlements.
 */
export async function handleSubscriptionUpdated(
  event: StripeEvent,
  db: SupabaseAdmin,
  priceToPlan: Record<string, ApiKeyTier> = {},
): Promise<HandlerResult> {
  const parseResult = SubscriptionSchema.safeParse(event.data.object);
  if (!parseResult.success) {
    return { ok: false, error: `Invalid subscription payload: ${parseResult.error.issues.map((i) => i.message).join('; ')}` };
  }
  const subscription = parseResult.data;

  const findResult = await db.findOrgByStripeCustomerId(subscription.customer);
  if (!findResult.ok) {
    return { ok: false, error: `Failed to find org: ${findResult.error}` };
  }

  if (!findResult.orgId) {
    return { ok: false, error: `No org found for Stripe customer ${subscription.customer}` };
  }

  const firstItem = subscription.items?.data?.[0];
  if (firstItem) {
    const priceId: string = firstItem.price.id;
    const upsertResult = await db.upsertSubscription(
      findResult.orgId,
      subscription.id,
      priceId,
      subscription.status,
      subscriptionPeriod(firstItem),
    );
    if (!upsertResult.ok) {
      return { ok: false, error: `Failed to upsert subscription: ${upsertResult.error}` };
    }
  }

  const planKey = firstItem ? priceToPlan[firstItem.price.id] : undefined;
  const billingStatus = toBillingStatus(subscription.status);

  const updateResult = await db.updateOrgBillingStatus(
    findResult.orgId,
    billingStatus,
    planKey,
    true, // bump quota version to notify clients
  );

  if (!updateResult.ok) {
    return { ok: false, error: `Failed to update org: ${updateResult.error}` };
  }

  return { ok: true };
}

/**
 * Handle customer.subscription.deleted event.
 * Downgrades org to free plan and cancels billing.
 */
export async function handleSubscriptionDeleted(
  event: StripeEvent,
  db: SupabaseAdmin,
  // Deletion always downgrades to 'starter'; price mapping is unused here.
  _priceToPlan: Record<string, ApiKeyTier> = {},
): Promise<HandlerResult> {
  const parseResult = SubscriptionSchema.safeParse(event.data.object);
  if (!parseResult.success) {
    return { ok: false, error: `Invalid subscription payload: ${parseResult.error.issues.map((i) => i.message).join('; ')}` };
  }
  const subscription = parseResult.data;

  const findResult = await db.findOrgByStripeCustomerId(subscription.customer);
  if (!findResult.ok) {
    return { ok: false, error: `Failed to find org: ${findResult.error}` };
  }

  if (!findResult.orgId) {
    return { ok: false, error: `No org found for Stripe customer ${subscription.customer}` };
  }

  const firstItem = subscription.items?.data?.[0];
  if (firstItem) {
    const upsertResult = await db.upsertSubscription(
      findResult.orgId,
      subscription.id,
      firstItem.price.id,
      'canceled',
      subscriptionPeriod(firstItem),
    );
    if (!upsertResult.ok) {
      return { ok: false, error: `Failed to mark subscription canceled: ${upsertResult.error}` };
    }
  }

  const updateResult = await db.updateOrgBillingStatus(
    findResult.orgId,
    'canceled',
    'starter',
    true, // bump quota version
  );

  if (!updateResult.ok) {
    return { ok: false, error: `Failed to downgrade org: ${updateResult.error}` };
  }

  return { ok: true };
}
