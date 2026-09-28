import type { ApiKeyTier, BillingStatus } from './types/index';

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

/** The plan an org is held to when its stored plan is not paid for. */
export const UNPAID_PLAN: ApiKeyTier = 'starter';

/**
 * The plan an org's quota and entitlements follow: its `current_plan` while the org is
 * entitled, otherwise `UNPAID_PLAN`.
 *
 * `current_plan` alone is not evidence of payment (CR37). Until 2026-09-27 two
 * unauthenticated paths let the caller choose it, and the rows they wrote persist; a
 * contract-billed enterprise org is entitled only because an operator set its
 * `billing_status` too. Enforcement reads this; display surfaces keep the raw column.
 */
export function effectivePlan(
  currentPlan: ApiKeyTier | null | undefined,
  billingStatus: BillingStatus | null | undefined,
): ApiKeyTier {
  if (!currentPlan || !billingStatus || !isEntitled(billingStatus)) return UNPAID_PLAN;
  return currentPlan;
}

/**
 * Whether a subscription has reached a state it can never leave.
 *
 * Used to decide when `organizations.active_subscription_id` should be cleared. Note this
 * is deliberately *not* the inverse of `isEntitled`: `past_due`, `unpaid`, `paused` and
 * `incomplete` are all unentitled but still describe a live subscription the org owns, so
 * the org should keep pointing at it. Only `canceled` and `incomplete_expired` are
 * terminal — Stripe never transitions out of either.
 *
 * Keeping this beside `isEntitled` for the same reason that one exists: the tempting
 * shorthand (`!isEntitled(status)`) reads as obviously correct and would orphan the
 * pointer the moment a payment failed.
 */
export function isTerminalSubscriptionStatus(status: string): boolean {
  return status === 'canceled' || status === 'incomplete_expired';
}
