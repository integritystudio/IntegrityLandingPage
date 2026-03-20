import type { SupabaseAdmin } from '../supabase';
import type { StripeEvent } from '../../../lib/types';

type HandlerResult = { ok: true } | { ok: false; error: string };

/**
 * Handle checkout.session.completed event.
 * Links Stripe customer to organization and creates subscription.
 */
export async function handleCheckoutSessionCompleted(
  event: StripeEvent,
  db: SupabaseAdmin,
): Promise<HandlerResult> {
  const session = event.data.object as any;

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

  return { ok: true };
}
