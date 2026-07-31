import { describe, it, expect, vi, beforeEach } from 'vitest';
import { handleSubscriptionUpdated, handleSubscriptionDeleted } from './subscription';
import type { StripeEvent } from '../../../lib/types';
import type { SupabaseAdmin } from '../supabase';
import { STRIPE_SUBSCRIPTION_STATUSES } from '../../../lib/billing';

function makeDb(overrides: Partial<SupabaseAdmin> = {}): SupabaseAdmin {
  return {
    linkStripeCustomer: vi.fn().mockResolvedValue({ ok: true }),
    upsertSubscription: vi.fn().mockResolvedValue({ ok: true }),
    updateOrgBillingStatus: vi.fn().mockResolvedValue({ ok: true }),
    findOrgByStripeCustomerId: vi.fn().mockResolvedValue({ ok: true, orgId: 'org-1' }),
    isEventProcessed: vi.fn().mockResolvedValue({ ok: true, processed: false }),
    claimEvent: vi.fn().mockResolvedValue({ ok: true, claimed: true }),
    unclaimEvent: vi.fn().mockResolvedValue({ ok: true }),
    addDeadLetter: vi.fn().mockResolvedValue({ ok: true }),
    fetchPendingDeadLetters: vi.fn().mockResolvedValue([]),
    resolveDeadLetter: vi.fn().mockResolvedValue({ ok: true }),
    failDeadLetter: vi.fn().mockResolvedValue({ ok: true }),
    abandonDeadLetter: vi.fn().mockResolvedValue({ ok: true }),
    ...overrides,
  };
}

function makeSubEvent(object: Record<string, unknown>): StripeEvent {
  return { id: 'evt_1', type: 'customer.subscription.updated', created: 0, data: { object } };
}

const VALID_SUBSCRIPTION = {
  id: 'sub_1',
  customer: 'cus_1',
  status: 'active',
  items: { data: [{ price: { id: 'price_abc' } }] },
};

describe('handleSubscriptionUpdated', () => {
  it('returns { ok: false } when payload fails schema validation', async () => {
    // id is required — omit it
    const event = makeSubEvent({ customer: 'cus_1', status: 'active' });
    const db = makeDb();
    const result = await handleSubscriptionUpdated(event, db);
    expect(result.ok).toBe(false);
    if (!result.ok) expect(result.error).toMatch(/Invalid subscription payload/);
  });

  it('returns { ok: false } when customer field is absent', async () => {
    // customer is required by SubscriptionSchema
    const event = makeSubEvent({ id: 'sub_1', status: 'active' });
    const db = makeDb();
    const result = await handleSubscriptionUpdated(event, db);
    expect(result.ok).toBe(false);
  });

  it('returns { ok: false } when findOrgByStripeCustomerId fails', async () => {
    const event = makeSubEvent(VALID_SUBSCRIPTION);
    const db = makeDb({ findOrgByStripeCustomerId: vi.fn().mockResolvedValue({ ok: false, error: 'HTTP 500: Connection timeout' }) });
    const result = await handleSubscriptionUpdated(event, db);
    expect(result.ok).toBe(false);
    if (!result.ok) expect(result.error).toContain('Failed to find org');
  });

  it('returns { ok: false } when no org found for customer (retryable, will dead-letter)', async () => {
    const event = makeSubEvent(VALID_SUBSCRIPTION);
    const db = makeDb({ findOrgByStripeCustomerId: vi.fn().mockResolvedValue({ ok: true, orgId: null }) });
    const result = await handleSubscriptionUpdated(event, db);
    expect(result.ok).toBe(false);
    if (!result.ok) expect(result.error).toContain('No org found for Stripe customer cus_1');
    expect(db.upsertSubscription).not.toHaveBeenCalled();
    expect(db.updateOrgBillingStatus).not.toHaveBeenCalled();
  });

  it('calls upsertSubscription with price and status when items present', async () => {
    const event = makeSubEvent(VALID_SUBSCRIPTION);
    const db = makeDb();
    await handleSubscriptionUpdated(event, db, {});
    expect(db.upsertSubscription).toHaveBeenCalledWith('org-1', 'sub_1', 'price_abc', 'active');
  });

  it('skips upsertSubscription when items is absent', async () => {
    const event = makeSubEvent({ id: 'sub_1', customer: 'cus_1', status: 'active' });
    const db = makeDb();
    const result = await handleSubscriptionUpdated(event, db, {});
    expect(result.ok).toBe(true);
    expect(db.upsertSubscription).not.toHaveBeenCalled();
  });

  it('returns { ok: false } when upsertSubscription fails', async () => {
    const event = makeSubEvent(VALID_SUBSCRIPTION);
    const db = makeDb({ upsertSubscription: vi.fn().mockResolvedValue({ ok: false, error: 'HTTP 409: Duplicate key violation' }) });
    const result = await handleSubscriptionUpdated(event, db, {});
    expect(result.ok).toBe(false);
    if (!result.ok) expect(result.error).toContain('Failed to upsert subscription');
  });

  it('maps price to plan key when priceToPlan contains the price', async () => {
    const event = makeSubEvent(VALID_SUBSCRIPTION);
    const db = makeDb();
    await handleSubscriptionUpdated(event, db, { price_abc: 'growth' });
    expect(db.updateOrgBillingStatus).toHaveBeenCalledWith('org-1', 'active', 'growth', true);
  });

  it('passes undefined planKey when price is not in priceToPlan', async () => {
    const event = makeSubEvent(VALID_SUBSCRIPTION);
    const db = makeDb();
    await handleSubscriptionUpdated(event, db, {});
    expect(db.updateOrgBillingStatus).toHaveBeenCalledWith('org-1', 'active', undefined, true);
  });

  // billing_status now mirrors Stripe's vocabulary, so every status is stored verbatim.
  //
  // This replaces a test that asserted `trialing` -> 'inactive' as intended behaviour.
  // It passed for four months because no real subscription had ever reached the Worker,
  // so the test documented the defect rather than catching it. The exhaustive list is
  // kept here — not just in billing.test.ts — because this is where a regression would
  // actually surface: what the handler writes to the org row (CR27).
  it.each(STRIPE_SUBSCRIPTION_STATUSES)('stores Stripe status %s verbatim', async (status) => {
    const event = makeSubEvent({ ...VALID_SUBSCRIPTION, status });
    const db = makeDb();
    await handleSubscriptionUpdated(event, db, {});
    expect(db.updateOrgBillingStatus).toHaveBeenCalledWith('org-1', status, undefined, true);
  });

  it('falls back to inactive and warns on a status Stripe has not defined yet', async () => {
    const warn = vi.spyOn(console, 'warn').mockImplementation(() => {});
    const event = makeSubEvent({ ...VALID_SUBSCRIPTION, status: 'some_future_status' });
    const db = makeDb();
    await handleSubscriptionUpdated(event, db, {});
    // Safe by default — an unknown state must not grant entitlement...
    expect(db.updateOrgBillingStatus).toHaveBeenCalledWith('org-1', 'inactive', undefined, true);
    // ...but visible, which the old silent fallthrough was not.
    expect(warn).toHaveBeenCalledWith(expect.stringContaining('some_future_status'));
    warn.mockRestore();
  });

  // The row written to `subscriptions` and the org's billing_status must agree; they are
  // written by two different calls from the same handler and could drift apart.
  it('writes the same status to the subscriptions row and the org', async () => {
    const event = makeSubEvent({ ...VALID_SUBSCRIPTION, status: 'trialing' });
    const db = makeDb();
    await handleSubscriptionUpdated(event, db, {});
    expect(db.upsertSubscription).toHaveBeenCalledWith('org-1', 'sub_1', 'price_abc', 'trialing');
    expect(db.updateOrgBillingStatus).toHaveBeenCalledWith('org-1', 'trialing', undefined, true);
  });

  it('returns { ok: false } when updateOrgBillingStatus fails', async () => {
    const event = makeSubEvent(VALID_SUBSCRIPTION);
    const db = makeDb({ updateOrgBillingStatus: vi.fn().mockResolvedValue({ ok: false, error: 'HTTP 500: DB connection error' }) });
    const result = await handleSubscriptionUpdated(event, db, {});
    expect(result.ok).toBe(false);
    if (!result.ok) expect(result.error).toContain('Failed to update org');
  });

  it('returns { ok: true } on fully successful path', async () => {
    const event = makeSubEvent(VALID_SUBSCRIPTION);
    const db = makeDb();
    const result = await handleSubscriptionUpdated(event, db, { price_abc: 'enterprise' });
    expect(result.ok).toBe(true);
  });
});

describe('handleSubscriptionDeleted', () => {
  it('returns { ok: false } when payload fails schema validation', async () => {
    const event = makeSubEvent({ customer: 'cus_1', status: 'canceled' });
    const db = makeDb();
    const result = await handleSubscriptionDeleted(event, db);
    expect(result.ok).toBe(false);
    if (!result.ok) expect(result.error).toMatch(/Invalid subscription payload/);
  });

  it('returns { ok: false } when customer field is absent', async () => {
    const event = makeSubEvent({ id: 'sub_1', status: 'canceled' });
    const db = makeDb();
    const result = await handleSubscriptionDeleted(event, db);
    expect(result.ok).toBe(false);
  });

  it('returns { ok: false } when findOrgByStripeCustomerId fails', async () => {
    const event = makeSubEvent(VALID_SUBSCRIPTION);
    const db = makeDb({ findOrgByStripeCustomerId: vi.fn().mockResolvedValue({ ok: false, error: 'HTTP 500: Connection timeout' }) });
    const result = await handleSubscriptionDeleted(event, db);
    expect(result.ok).toBe(false);
    if (!result.ok) expect(result.error).toContain('Failed to find org');
  });

  it('returns { ok: false } when no org found for customer (retryable, will dead-letter)', async () => {
    const event = makeSubEvent(VALID_SUBSCRIPTION);
    const db = makeDb({ findOrgByStripeCustomerId: vi.fn().mockResolvedValue({ ok: true, orgId: null }) });
    const result = await handleSubscriptionDeleted(event, db);
    expect(result.ok).toBe(false);
    if (!result.ok) expect(result.error).toContain('No org found for Stripe customer cus_1');
    expect(db.upsertSubscription).not.toHaveBeenCalled();
    expect(db.updateOrgBillingStatus).not.toHaveBeenCalled();
  });

  it('calls upsertSubscription with canceled status when items present', async () => {
    const event = makeSubEvent(VALID_SUBSCRIPTION);
    const db = makeDb();
    await handleSubscriptionDeleted(event, db);
    expect(db.upsertSubscription).toHaveBeenCalledWith('org-1', 'sub_1', 'price_abc', 'canceled');
  });

  it('skips upsertSubscription when items is absent', async () => {
    const event = makeSubEvent({ id: 'sub_1', customer: 'cus_1', status: 'canceled' });
    const db = makeDb();
    const result = await handleSubscriptionDeleted(event, db);
    expect(result.ok).toBe(true);
    expect(db.upsertSubscription).not.toHaveBeenCalled();
  });

  it('returns { ok: false } when upsertSubscription fails', async () => {
    const event = makeSubEvent(VALID_SUBSCRIPTION);
    const db = makeDb({ upsertSubscription: vi.fn().mockResolvedValue({ ok: false, error: 'HTTP 409: Duplicate key violation' }) });
    const result = await handleSubscriptionDeleted(event, db);
    expect(result.ok).toBe(false);
    if (!result.ok) expect(result.error).toContain('Failed to mark subscription canceled');
  });

  it('downgrades org to starter plan with canceled billing status', async () => {
    const event = makeSubEvent(VALID_SUBSCRIPTION);
    const db = makeDb();
    await handleSubscriptionDeleted(event, db);
    expect(db.updateOrgBillingStatus).toHaveBeenCalledWith('org-1', 'canceled', 'starter', true);
  });

  it('returns { ok: false } when updateOrgBillingStatus fails', async () => {
    const event = makeSubEvent(VALID_SUBSCRIPTION);
    const db = makeDb({ updateOrgBillingStatus: vi.fn().mockResolvedValue({ ok: false, error: 'HTTP 500: DB connection error' }) });
    const result = await handleSubscriptionDeleted(event, db);
    expect(result.ok).toBe(false);
    if (!result.ok) expect(result.error).toContain('Failed to downgrade org');
  });

  it('returns { ok: true } on fully successful path', async () => {
    const event = makeSubEvent(VALID_SUBSCRIPTION);
    const db = makeDb();
    const result = await handleSubscriptionDeleted(event, db);
    expect(result.ok).toBe(true);
  });
});
