import { type ApiKeyTier } from "./types.js";

export type CheckoutSessionResult =
  | { ok: true; checkoutUrl: string }
  | { ok: false; error: string };

const STRIPE_CHECKOUT_URL = "https://api.stripe.com/v1/checkout/sessions";

/**
 * Create a Stripe Checkout session for a subscription tier.
 *
 * `orgId` is what lets `stripe-webhook` attach the resulting subscription to an
 * organization: its `checkout.session.completed` handler reads
 * `session.metadata.org_id || session.client_reference_id` and, finding neither,
 * warns and returns without calling `linkStripeCustomer`. It is optional and
 * omitted silently when null — a checkout that cannot be attributed is still a
 * sale, so an unresolvable org must never block payment. The caller is
 * responsible for logging that case.
 *
 * The org id is also copied to `subscription_data[metadata][org_id]`. Sessions
 * expire within 24h while the Subscription object persists for the life of the
 * billing relationship, so that copy survives to re-derive linkage later. No
 * handler reads it today.
 */
export async function createStripeCheckoutSession(
  stripeSecretKey: string,
  planToPriceJson: string,
  appBaseUrl: string,
  email: string,
  tier: ApiKeyTier,
  orgId?: string | null,
): Promise<CheckoutSessionResult> {
  let planToPrice: Record<string, unknown>;
  try {
    planToPrice = JSON.parse(planToPriceJson) as Record<string, unknown>;
  } catch {
    return { ok: false, error: "invalid STRIPE_PLAN_TO_PRICE_JSON configuration" };
  }

  const priceId = planToPrice[tier];
  if (typeof priceId !== "string" || !priceId) {
    return { ok: false, error: `no Stripe price configured for tier: ${tier}` };
  }

  const base = appBaseUrl.replace(/\/$/, "");
  const successUrl = `${base}/checkout-success?email=${encodeURIComponent(email)}&tier=${tier}`;
  const cancelUrl = `${base}/signup?tier=${tier}`;

  const params = new URLSearchParams({
    mode: "subscription",
    "payment_method_types[]": "card",
    "line_items[0][price]": priceId,
    "line_items[0][quantity]": "1",
    success_url: successUrl,
    cancel_url: cancelUrl,
    customer_email: email,
  });

  if (orgId) {
    params.set("metadata[org_id]", orgId);
    params.set("subscription_data[metadata][org_id]", orgId);
  }

  const res = await fetch(STRIPE_CHECKOUT_URL, {
    method: "POST",
    headers: {
      Authorization: `Bearer ${stripeSecretKey}`,
      "Content-Type": "application/x-www-form-urlencoded",
    },
    body: params.toString(),
  });

  if (!res.ok) {
    const err = await res.text();
    console.error("[stripe] checkout session creation failed:", res.status, err);
    return { ok: false, error: "failed to create checkout session" };
  }

  const data = (await res.json()) as { url?: string };
  if (!data.url) {
    return { ok: false, error: "Stripe response missing session URL" };
  }

  return { ok: true, checkoutUrl: data.url };
}
