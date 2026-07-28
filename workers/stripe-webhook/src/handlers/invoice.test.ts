import { describe, it, expect, vi, beforeEach } from 'vitest';
import { handleInvoicePaid, handleInvoicePaymentFailed } from './invoice';
import type { StripeEvent } from '../../../lib/types';
import type { SupabaseAdmin } from '../supabase';

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

function makeEvent(object: Record<string, unknown>): StripeEvent {
  return { id: 'evt_1', type: 'invoice.paid', created: 0, data: { object } };
}

describe('handleInvoicePaid', () => {
  it('returns { ok: false } when payload fails schema validation', async () => {
    // customer must be a string; pass a number to fail the schema
    const event = makeEvent({ customer: 123, subscription: 'sub_1' });
    const db = makeDb();
    const result = await handleInvoicePaid(event, db);
    expect(result.ok).toBe(false);
    if (!result.ok) expect(result.error).toMatch(/Invalid invoice payload/);
  });

  it('returns { ok: false } when subscription field is absent', async () => {
    const event = makeEvent({ customer: 'cus_1' });
    const db = makeDb();
    const result = await handleInvoicePaid(event, db);
    expect(result.ok).toBe(false);
    if (!result.ok) expect(result.error).toContain('Invoice missing subscription');
  });

  it('returns { ok: false } when customer field is absent', async () => {
    const event = makeEvent({ subscription: 'sub_1' });
    const db = makeDb();
    // customer is required by the schema, so this should fail schema validation
    const result = await handleInvoicePaid(event, db);
    expect(result.ok).toBe(false);
  });

  it('returns { ok: false } when findOrgByStripeCustomerId fails', async () => {
    const event = makeEvent({ customer: 'cus_1', subscription: 'sub_1' });
    const db = makeDb({ findOrgByStripeCustomerId: vi.fn().mockResolvedValue({ ok: false, error: 'HTTP 500: Connection timeout' }) });
    const result = await handleInvoicePaid(event, db);
    expect(result.ok).toBe(false);
    if (!result.ok) expect(result.error).toContain('Failed to find org');
  });

  it('returns { ok: false } when no org found for customer (retryable, will dead-letter)', async () => {
    const event = makeEvent({ customer: 'cus_orphan', subscription: 'sub_1' });
    const db = makeDb({ findOrgByStripeCustomerId: vi.fn().mockResolvedValue({ ok: true, orgId: null }) });
    const result = await handleInvoicePaid(event, db);
    expect(result.ok).toBe(false);
    if (!result.ok) expect(result.error).toContain('No org found for Stripe customer cus_orphan');
    expect(db.updateOrgBillingStatus).not.toHaveBeenCalled();
  });

  it('returns { ok: false } when updateOrgBillingStatus fails', async () => {
    const event = makeEvent({ customer: 'cus_1', subscription: 'sub_1' });
    const db = makeDb({ updateOrgBillingStatus: vi.fn().mockResolvedValue({ ok: false, error: 'HTTP 500: DB connection error' }) });
    const result = await handleInvoicePaid(event, db);
    expect(result.ok).toBe(false);
    if (!result.ok) expect(result.error).toContain('Failed to update org');
  });

  it('sets billing_status to active on success', async () => {
    const event = makeEvent({ customer: 'cus_1', subscription: 'sub_1' });
    const db = makeDb();
    const result = await handleInvoicePaid(event, db);
    expect(result.ok).toBe(true);
    expect(db.updateOrgBillingStatus).toHaveBeenCalledWith('org-1', 'active', undefined, true);
  });
});

describe('handleInvoicePaymentFailed', () => {
  it('returns { ok: false } when payload fails schema validation', async () => {
    const event = makeEvent({ customer: 123 });
    const db = makeDb();
    const result = await handleInvoicePaymentFailed(event, db);
    expect(result.ok).toBe(false);
    if (!result.ok) expect(result.error).toMatch(/Invalid invoice payload/);
  });

  it('returns { ok: false } when customer field is absent', async () => {
    const event = makeEvent({ subscription: 'sub_1' });
    const db = makeDb();
    const result = await handleInvoicePaymentFailed(event, db);
    expect(result.ok).toBe(false);
  });

  it('returns { ok: false } when findOrgByStripeCustomerId fails', async () => {
    const event = makeEvent({ customer: 'cus_1' });
    const db = makeDb({ findOrgByStripeCustomerId: vi.fn().mockResolvedValue({ ok: false, error: 'HTTP 500: Connection timeout' }) });
    const result = await handleInvoicePaymentFailed(event, db);
    expect(result.ok).toBe(false);
    if (!result.ok) expect(result.error).toContain('Failed to find org');
  });

  it('returns { ok: false } when no org found for customer (retryable, will dead-letter)', async () => {
    const event = makeEvent({ customer: 'cus_orphan' });
    const db = makeDb({ findOrgByStripeCustomerId: vi.fn().mockResolvedValue({ ok: true, orgId: null }) });
    const result = await handleInvoicePaymentFailed(event, db);
    expect(result.ok).toBe(false);
    if (!result.ok) expect(result.error).toContain('No org found for Stripe customer cus_orphan');
    expect(db.updateOrgBillingStatus).not.toHaveBeenCalled();
  });

  it('returns { ok: false } when updateOrgBillingStatus fails', async () => {
    const event = makeEvent({ customer: 'cus_1' });
    const db = makeDb({ updateOrgBillingStatus: vi.fn().mockResolvedValue({ ok: false, error: 'HTTP 500: DB connection error' }) });
    const result = await handleInvoicePaymentFailed(event, db);
    expect(result.ok).toBe(false);
    if (!result.ok) expect(result.error).toContain('Failed to update org');
  });

  it('sets billing_status to past_due on success', async () => {
    const event = makeEvent({ customer: 'cus_1' });
    const db = makeDb();
    const result = await handleInvoicePaymentFailed(event, db);
    expect(result.ok).toBe(true);
    expect(db.updateOrgBillingStatus).toHaveBeenCalledWith('org-1', 'past_due', undefined, true);
  });
});
