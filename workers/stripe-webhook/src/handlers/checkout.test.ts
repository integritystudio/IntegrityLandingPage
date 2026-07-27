import { describe, it, expect, vi, beforeEach } from 'vitest';
import { handleCheckoutSessionCompleted } from './checkout';
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
  return { id: 'evt_1', type: 'checkout.session.completed', created: 0, data: { object } };
}

describe('handleCheckoutSessionCompleted', () => {
  let consoleSpy: ReturnType<typeof vi.spyOn>;

  beforeEach(() => {
    consoleSpy = vi.spyOn(console, 'warn').mockImplementation(() => {});
  });

  it('returns { ok: false } when payload fails schema validation', async () => {
    // Provide an invalid payload — e.g. customer is a number (schema expects string)
    const event = makeEvent({ customer: 123 });
    const db = makeDb();
    const result = await handleCheckoutSessionCompleted(event, db);
    expect(result.ok).toBe(false);
    if (!result.ok) expect(result.error).toMatch(/Invalid checkout session payload/);
  });

  it('returns { ok: false } when customer is absent', async () => {
    const event = makeEvent({ subscription: 'sub_1' });
    const db = makeDb();
    const result = await handleCheckoutSessionCompleted(event, db);
    expect(result.ok).toBe(false);
    if (!result.ok) expect(result.error).toContain('Missing customer or subscription');
  });

  it('returns { ok: false } when subscription is absent', async () => {
    const event = makeEvent({ customer: 'cus_1' });
    const db = makeDb();
    const result = await handleCheckoutSessionCompleted(event, db);
    expect(result.ok).toBe(false);
    if (!result.ok) expect(result.error).toContain('Missing customer or subscription');
  });

  it('returns { ok: true } silently when org_id is absent from metadata and client_reference_id', async () => {
    const event = makeEvent({ customer: 'cus_1', subscription: 'sub_1' });
    const db = makeDb();
    const result = await handleCheckoutSessionCompleted(event, db);
    expect(result.ok).toBe(true);
    expect(db.linkStripeCustomer).not.toHaveBeenCalled();
    expect(consoleSpy).toHaveBeenCalled();
  });

  it('uses metadata.org_id when present', async () => {
    const event = makeEvent({
      customer: 'cus_1',
      subscription: 'sub_1',
      metadata: { org_id: 'org-meta' },
    });
    const db = makeDb();
    const result = await handleCheckoutSessionCompleted(event, db);
    expect(result.ok).toBe(true);
    expect(db.linkStripeCustomer).toHaveBeenCalledWith('org-meta', 'cus_1');
    expect(db.upsertSubscription).toHaveBeenCalledWith('org-meta', 'sub_1', null, 'active');
  });

  it('falls back to client_reference_id when metadata.org_id is absent', async () => {
    const event = makeEvent({
      customer: 'cus_1',
      subscription: 'sub_1',
      client_reference_id: 'org-ref',
    });
    const db = makeDb();
    const result = await handleCheckoutSessionCompleted(event, db);
    expect(result.ok).toBe(true);
    expect(db.linkStripeCustomer).toHaveBeenCalledWith('org-ref', 'cus_1');
  });

  it('returns { ok: false } when linkStripeCustomer fails', async () => {
    const event = makeEvent({ customer: 'cus_1', subscription: 'sub_1', metadata: { org_id: 'org-1' } });
    const db = makeDb({ linkStripeCustomer: vi.fn().mockResolvedValue({ ok: false, error: 'DB error' }) });
    const result = await handleCheckoutSessionCompleted(event, db);
    expect(result.ok).toBe(false);
    if (!result.ok) expect(result.error).toContain('Failed to link Stripe customer');
  });

  it('returns { ok: false } when upsertSubscription fails', async () => {
    const event = makeEvent({ customer: 'cus_1', subscription: 'sub_1', metadata: { org_id: 'org-1' } });
    const db = makeDb({ upsertSubscription: vi.fn().mockResolvedValue({ ok: false, error: 'Upsert fail' }) });
    const result = await handleCheckoutSessionCompleted(event, db);
    expect(result.ok).toBe(false);
    if (!result.ok) expect(result.error).toContain('Failed to upsert subscription');
  });

  it('returns { ok: true } on fully successful path', async () => {
    const event = makeEvent({ customer: 'cus_1', subscription: 'sub_1', metadata: { org_id: 'org-1' } });
    const db = makeDb();
    const result = await handleCheckoutSessionCompleted(event, db);
    expect(result.ok).toBe(true);
  });
});
