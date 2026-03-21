import type { SupabaseAdmin } from '../supabase';
import type { StripeEvent, HandlerResult } from '../../../lib/types';
import { CheckoutSessionSchema } from '../stripe-schemas';

/**
 * Handle checkout.session.completed event.
 * Links Stripe customer to organization and creates subscription.
 */
export async function handleCheckoutSessionCompleted(
  event: StripeEvent,
  db: SupabaseAdmin,
): Promise<HandlerResult> {
  const parseResult = CheckoutSessionSchema.safeParse(event.data.object);
  if (!parseResult.success) {
    return { ok: false, error: `Invalid checkout session payload: ${parseResult.error.issues.map((i) => i.message).join('; ')}` };
  }
  const session = parseResult.data;

  if (!session.customer || !session.subscription) {
    return { ok: false, error: 'Missing customer or subscription in checkout session' };
  }

  // org_id must be set during checkout creation via metadata or client_reference_id
  const orgId = session.metadata?.org_id || session.client_reference_id;
  if (!orgId) {
    console.warn('Checkout session missing org_id in metadata or client_reference_id');
    return { ok: true };
  }

  const linkResult = await db.linkStripeCustomer(orgId, session.customer);
  if (!linkResult.ok) {
    return { ok: false, error: `Failed to link Stripe customer: ${linkResult.error}` };
  }

  // Create a stub subscription row so invoice.paid queries don't miss it.
  // stripe_price_id starts null; customer.subscription.updated fires next and populates it.
  const upsertResult = await db.upsertSubscription(orgId, session.subscription, null, 'active');
  if (!upsertResult.ok) {
    return { ok: false, error: `Failed to upsert subscription: ${upsertResult.error}` };
  }

  return { ok: true };
}
