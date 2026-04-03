import type { SupabaseAdmin } from '../supabase';
import type { BillingStatus, HandlerResult, StripeEvent } from '../../../lib/types';
import { InvoiceSchema } from '../stripe-schemas';

/**
 * Resolves the org ID for a given Stripe customer ID.
 * Returns null orgId (with ok: true) when no org is found — caller decides whether to skip.
 */
async function resolveOrgId(
  customerId: string,
  db: SupabaseAdmin,
): Promise<{ ok: true; orgId: string | null } | { ok: false; error: string }> {
  const findResult = await db.findOrgByStripeCustomerId(customerId);
  if (!findResult.ok) {
    return { ok: false, error: `Failed to find org: ${findResult.error}` };
  }
  if (!findResult.orgId) {
    console.warn(`No org found for Stripe customer ${customerId}`);
  }
  return { ok: true, orgId: findResult.orgId };
}

async function setBillingStatus(
  orgId: string,
  status: BillingStatus,
  db: SupabaseAdmin,
): Promise<HandlerResult> {
  const updateResult = await db.updateOrgBillingStatus(
    orgId,
    status,
    undefined,
    true, // bump quota version
  );
  if (!updateResult.ok) {
    return { ok: false, error: `Failed to update org: ${updateResult.error}` };
  }
  return { ok: true };
}

/**
 * Handle invoice.paid event.
 * Updates subscription and org billing status to active.
 */
export async function handleInvoicePaid(
  event: StripeEvent,
  db: SupabaseAdmin,
): Promise<HandlerResult> {
  const parseResult = InvoiceSchema.safeParse(event.data.object);
  if (!parseResult.success) {
    return { ok: false, error: `Invalid invoice payload: ${parseResult.error.issues.map((i) => i.message).join('; ')}` };
  }
  const invoice = parseResult.data;

  if (!invoice.subscription) {
    return { ok: false, error: 'Invoice missing subscription' };
  }

  const resolved = await resolveOrgId(invoice.customer, db);
  if (!resolved.ok) return resolved;
  if (!resolved.orgId) return { ok: true };

  return setBillingStatus(resolved.orgId, 'active', db);
}

/**
 * Handle invoice.payment_failed event.
 * Updates org billing status to past_due.
 */
export async function handleInvoicePaymentFailed(
  event: StripeEvent,
  db: SupabaseAdmin,
): Promise<HandlerResult> {
  const parseResult = InvoiceSchema.safeParse(event.data.object);
  if (!parseResult.success) {
    return { ok: false, error: `Invalid invoice payload: ${parseResult.error.issues.map((i) => i.message).join('; ')}` };
  }
  const invoice = parseResult.data;

  const resolved = await resolveOrgId(invoice.customer, db);
  if (!resolved.ok) return resolved;
  if (!resolved.orgId) return { ok: true };

  return setBillingStatus(resolved.orgId, 'past_due', db);
}
