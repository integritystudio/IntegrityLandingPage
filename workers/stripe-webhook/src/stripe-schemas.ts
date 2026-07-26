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

export const InvoiceSchema = z.object({
  customer: z.string(),
  // Stripe sends null for non-subscription invoices (one-time charges, setup intents).
  // Accepting null prevents those events from being dead-lettered.
  subscription: z.string().nullable().optional(),
}).passthrough();

export type CheckoutSession = z.infer<typeof CheckoutSessionSchema>;
export type Subscription = z.infer<typeof SubscriptionSchema>;
export type Invoice = z.infer<typeof InvoiceSchema>;
