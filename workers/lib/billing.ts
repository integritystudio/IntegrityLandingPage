import type { BillingStatus } from './types/index';

/**
 * Stripe's subscription lifecycle, verbatim and in Stripe's own order.
 *
 * @see https://docs.stripe.com/api/subscriptions/object#subscription_object-status
 *
 * `inactive` is deliberately absent: it is our own value for "no Stripe subscription
 * exists", which Stripe cannot express because a status presupposes a subscription
 * object. This list is therefore the set of values `toBillingStatus` will pass through.
 */
export const STRIPE_SUBSCRIPTION_STATUSES = [
  'incomplete',
  'incomplete_expired',
  'trialing',
  'active',
  'past_due',
  'canceled',
  'unpaid',
  'paused',
] as const;

export type StripeSubscriptionStatus = (typeof STRIPE_SUBSCRIPTION_STATUSES)[number];

const KNOWN_STATUSES: ReadonlySet<string> = new Set(STRIPE_SUBSCRIPTION_STATUSES);

/**
 * Store a Stripe subscription status as our `billing_status`.
 *
 * `BillingStatus` mirrors Stripe's vocabulary, so this is a pass-through rather than a
 * mapping. That is the point: the lossy mapping this replaces collapsed everything except
 * `active` and `past_due` into `inactive`, which filed `trialing` as unentitled and made
 * `unpaid`, `canceled` and `paused` indistinguishable from never having subscribed. It
 * went unnoticed for four months because no real subscription reached the Worker (CR27).
 *
 * An unrecognised status still falls back to `inactive` — safe by default, since an
 * unknown state must not grant access — but warns rather than defaulting silently, which
 * is what allowed the original mis-mapping to hide.
 */
export function toBillingStatus(stripeStatus: string): BillingStatus {
  if (KNOWN_STATUSES.has(stripeStatus)) {
    return stripeStatus as BillingStatus;
  }
  console.warn(
    `Unrecognized Stripe subscription status '${stripeStatus}'; storing 'inactive'. ` +
      'If Stripe has added a status, add it to STRIPE_SUBSCRIPTION_STATUSES and to ' +
      'BillingStatus/BillingStatusSchema rather than leaving it to this fallback.',
  );
  return 'inactive';
}

/**
 * Whether a billing status grants access to paid functionality.
 *
 * Stripe treats `trialing` and `active` as its two good-standing states — a trial is a
 * *granted* entitlement, not a pending one, which is the whole purpose of
 * `trial_period_days`. Both therefore grant access.
 *
 * **Use this instead of comparing to `'active'`.** That comparison reads as obviously
 * correct and silently locks out every trial user; keeping the rule in one place is what
 * stops it being re-derived incorrectly at each call site.
 */
export function isEntitled(status: BillingStatus): boolean {
  return status === 'active' || status === 'trialing';
}
