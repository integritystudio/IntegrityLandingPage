import { describe, it, expect, vi } from 'vitest';
import {
  isEntitled,
  toBillingStatus,
  STRIPE_SUBSCRIPTION_STATUSES,
  type StripeSubscriptionStatus,
} from './billing';
import { BillingStatusSchema } from './types/schemas';
import type { BillingStatus } from './types/index';

describe('toBillingStatus', () => {
  it.each(STRIPE_SUBSCRIPTION_STATUSES)('passes %s through unchanged', (status) => {
    expect(toBillingStatus(status)).toBe(status);
  });

  it('falls back to inactive on a status Stripe has not defined yet', () => {
    const warn = vi.spyOn(console, 'warn').mockImplementation(() => {});
    expect(toBillingStatus('some_future_status')).toBe('inactive');
    warn.mockRestore();
  });

  it('warns on an unknown status rather than defaulting silently', () => {
    const warn = vi.spyOn(console, 'warn').mockImplementation(() => {});
    toBillingStatus('some_future_status');
    expect(warn).toHaveBeenCalledWith(expect.stringContaining('some_future_status'));
    warn.mockRestore();
  });

  it.each(STRIPE_SUBSCRIPTION_STATUSES)('does not warn for the known status %s', (status) => {
    const warn = vi.spyOn(console, 'warn').mockImplementation(() => {});
    toBillingStatus(status);
    expect(warn).not.toHaveBeenCalled();
    warn.mockRestore();
  });

  // `inactive` is ours, not Stripe's. It must never arrive from a webhook payload, so it
  // is not in the pass-through set — reaching it means something is wrong upstream.
  it('treats inactive as unknown, since Stripe never emits it', () => {
    const warn = vi.spyOn(console, 'warn').mockImplementation(() => {});
    expect(toBillingStatus('inactive')).toBe('inactive');
    expect(warn).toHaveBeenCalled();
    warn.mockRestore();
  });
});

describe('isEntitled', () => {
  it('grants access while trialing — a trial is a granted entitlement, not a pending one', () => {
    expect(isEntitled('trialing')).toBe(true);
  });

  it('grants access when active', () => {
    expect(isEntitled('active')).toBe(true);
  });

  it.each<BillingStatus>([
    'inactive',
    'incomplete',
    'incomplete_expired',
    'past_due',
    'canceled',
    'unpaid',
    'paused',
  ])('does not grant access when %s', (status) => {
    expect(isEntitled(status)).toBe(false);
  });
});

// The union, the Zod enum and the pass-through list are three declarations of one fact.
// Drift between them is silent: a status could parse but never pass through, or vice
// versa. These pin them together so adding a status to one forces the others.
describe('BillingStatus declarations stay in sync', () => {
  it('every Stripe status is accepted by BillingStatusSchema', () => {
    for (const status of STRIPE_SUBSCRIPTION_STATUSES) {
      expect(BillingStatusSchema.safeParse(status).success).toBe(true);
    }
  });

  it('BillingStatusSchema is exactly the Stripe statuses plus inactive', () => {
    expect([...BillingStatusSchema.options].sort()).toEqual(
      [...STRIPE_SUBSCRIPTION_STATUSES, 'inactive'].sort(),
    );
  });

  it('rejects a value that is in neither set', () => {
    expect(BillingStatusSchema.safeParse('some_future_status').success).toBe(false);
  });

  // Compile-time guard: every Stripe status must be assignable to BillingStatus. If one
  // is added to the list without extending the union, this stops typechecking.
  it('every Stripe status is assignable to BillingStatus', () => {
    const assignable: BillingStatus[] = [...STRIPE_SUBSCRIPTION_STATUSES];
    const roundTrip: StripeSubscriptionStatus[] = [...STRIPE_SUBSCRIPTION_STATUSES];
    expect(assignable).toHaveLength(roundTrip.length);
  });
});
