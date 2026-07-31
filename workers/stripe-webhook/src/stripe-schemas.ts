import { z } from 'zod';

const SubscriptionItemSchema = z.object({
  price: z.object({ id: z.string() }),
}).passthrough();

export const CheckoutSessionSchema = z.object({
  customer: z.string().optional(),
  subscription: z.string().optional(),
  client_reference_id: z.string().nullable().optional(),
  metadata: z.object({ org_id: z.string().optional() }).passthrough().optional(),
}).passthrough();

export const SubscriptionSchema = z.object({
  id: z.string(),
  customer: z.string(),
  status: z.string(),
  items: z.object({ data: z.array(SubscriptionItemSchema) }).optional(),
}).passthrough();

// Stripe API 2025-04-30 removed the top-level `invoice.subscription` field and moved
// the reference to `parent.subscription_details.subscription`. Events are delivered
// using the API version pinned on the endpoint, so both shapes can legitimately be in
// flight (a version bump, replayed events, older dead-letter retries) — accept either.
const InvoiceParentSchema = z.object({
  subscription_details: z
    .object({ subscription: z.string().nullable().optional() })
    .passthrough()
    .nullable()
    .optional(),
}).passthrough();

export const InvoiceSchema = z.object({
  customer: z.string(),
  // Legacy location (API < 2025-04-30). Stripe sends null for non-subscription invoices
  // (one-time charges, setup intents). Accepting null prevents those events from being
  // dead-lettered.
  subscription: z.string().nullable().optional(),
  parent: InvoiceParentSchema.nullable().optional(),
}).passthrough();

export type CheckoutSession = z.infer<typeof CheckoutSessionSchema>;
export type Subscription = z.infer<typeof SubscriptionSchema>;
export type Invoice = z.infer<typeof InvoiceSchema>;

/**
 * Resolves an invoice's subscription id from either location, preferring the current
 * one. Returns null only for genuine non-subscription invoices, which callers treat as
 * a skip rather than a failure.
 */
export function getInvoiceSubscriptionId(invoice: Invoice): string | null {
  return invoice.parent?.subscription_details?.subscription ?? invoice.subscription ?? null;
}
