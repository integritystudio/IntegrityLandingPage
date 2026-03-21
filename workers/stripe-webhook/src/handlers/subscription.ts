import type { SupabaseAdmin } from '../supabase';
import type { BillingStatus, HandlerResult, PlanKey, StripeEvent } from '../../../lib/types';
import { SubscriptionSchema } from '../stripe-schemas';


function resolveBillingStatus(stripeStatus: string): BillingStatus {
  if (stripeStatus === 'active') return 'active';
  if (stripeStatus === 'past_due') return 'past_due';
  return 'inactive';
}

/**
 * Handle customer.subscription.updated event.
 * Updates subscription status and may recompute entitlements.
 */
export async function handleSubscriptionUpdated(
  event: StripeEvent,
  db: SupabaseAdmin,
  priceToPlan: Record<string, PlanKey> = {},
): Promise<HandlerResult> {
  const parseResult = SubscriptionSchema.safeParse(event.data.object);
  if (!parseResult.success) {
    return { ok: false, error: `Invalid subscription payload: ${parseResult.error.issues.map((i) => i.message).join('; ')}` };
  }
  const subscription = parseResult.data;

  if (!subscription.customer) {
    return { ok: false, error: 'Subscription missing customer' };
  }

  const findResult = await db.findOrgByStripeCustomerId(subscription.customer);
  if (!findResult.ok) {
    return { ok: false, error: `Failed to find org: ${findResult.error}` };
  }

  if (!findResult.orgId) {
    console.warn(`No org found for Stripe customer ${subscription.customer}`);
    return { ok: true };
  }

  const firstItem = subscription.items?.data?.[0];
  if (firstItem) {
    const priceId: string = firstItem.price.id;
    const upsertResult = await db.upsertSubscription(
      findResult.orgId,
      subscription.id,
      priceId,
      subscription.status,
    );
    if (!upsertResult.ok) {
      return { ok: false, error: `Failed to upsert subscription: ${upsertResult.error}` };
    }
  }

  const planKey = firstItem ? priceToPlan[firstItem.price.id] : undefined;
  const billingStatus = resolveBillingStatus(subscription.status);

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
  // Deletion always downgrades to 'free'; price mapping is unused here.
  _priceToPlan: Record<string, PlanKey> = {},
): Promise<HandlerResult> {
  const parseResult = SubscriptionSchema.safeParse(event.data.object);
  if (!parseResult.success) {
    return { ok: false, error: `Invalid subscription payload: ${parseResult.error.issues.map((i) => i.message).join('; ')}` };
  }
  const subscription = parseResult.data;

  if (!subscription.customer) {
    return { ok: false, error: 'Subscription missing customer' };
  }

  const findResult = await db.findOrgByStripeCustomerId(subscription.customer);
  if (!findResult.ok) {
    return { ok: false, error: `Failed to find org: ${findResult.error}` };
  }

  if (!findResult.orgId) {
    console.warn(`No org found for Stripe customer ${subscription.customer}`);
    return { ok: true };
  }

  const firstItem = subscription.items?.data?.[0];
  if (firstItem) {
    const upsertResult = await db.upsertSubscription(
      findResult.orgId,
      subscription.id,
      firstItem.price.id,
      'canceled',
    );
    if (!upsertResult.ok) {
      return { ok: false, error: `Failed to mark subscription canceled: ${upsertResult.error}` };
    }
  }

  const updateResult = await db.updateOrgBillingStatus(
    findResult.orgId,
    'canceled',
    'free',
    true, // bump quota version
  );

  if (!updateResult.ok) {
    return { ok: false, error: `Failed to downgrade org: ${updateResult.error}` };
  }

  return { ok: true };
}
