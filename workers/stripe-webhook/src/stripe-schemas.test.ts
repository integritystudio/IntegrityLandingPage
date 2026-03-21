import { describe, it, expect } from 'vitest';
import { CheckoutSessionSchema, InvoiceSchema, SubscriptionSchema } from './stripe-schemas';

describe('CheckoutSessionSchema', () => {
  it('accepts valid checkout session with all fields', () => {
    const result = CheckoutSessionSchema.safeParse({
      customer: 'cus_123',
      subscription: 'sub_456',
      client_reference_id: 'org_789',
      metadata: { org_id: 'org_789' },
    });
    expect(result.success).toBe(true);
  });

  it('accepts minimal checkout session (all optional fields absent)', () => {
    const result = CheckoutSessionSchema.safeParse({});
    expect(result.success).toBe(true);
  });

  it('accepts guest checkout session with no customer', () => {
    const result = CheckoutSessionSchema.safeParse({ subscription: 'sub_456' });
    expect(result.success).toBe(true);
  });

  it('accepts null client_reference_id', () => {
    const result = CheckoutSessionSchema.safeParse({ client_reference_id: null });
    expect(result.success).toBe(true);
  });

  it('passes through unknown fields', () => {
    const result = CheckoutSessionSchema.safeParse({ unknown_field: 'value', customer: 'cus_123' });
    expect(result.success).toBe(true);
    if (result.success) {
      expect((result.data as Record<string, unknown>).unknown_field).toBe('value');
    }
  });
});

describe('SubscriptionSchema', () => {
  it('accepts valid subscription with all fields', () => {
    const result = SubscriptionSchema.safeParse({
      id: 'sub_123',
      customer: 'cus_456',
      status: 'active',
      items: { data: [{ price: { id: 'price_789' } }] },
    });
    expect(result.success).toBe(true);
  });

  it('accepts subscription without items (optional)', () => {
    const result = SubscriptionSchema.safeParse({
      id: 'sub_123',
      customer: 'cus_456',
      status: 'active',
    });
    expect(result.success).toBe(true);
  });

  it('rejects subscription missing required customer', () => {
    const result = SubscriptionSchema.safeParse({ id: 'sub_123', status: 'active' });
    expect(result.success).toBe(false);
  });

  it('rejects subscription missing required id', () => {
    const result = SubscriptionSchema.safeParse({ customer: 'cus_123', status: 'active' });
    expect(result.success).toBe(false);
  });

  it('rejects subscription missing required status', () => {
    const result = SubscriptionSchema.safeParse({ id: 'sub_123', customer: 'cus_123' });
    expect(result.success).toBe(false);
  });

  it('accepts items with empty data array', () => {
    const result = SubscriptionSchema.safeParse({
      id: 'sub_123',
      customer: 'cus_456',
      status: 'active',
      items: { data: [] },
    });
    expect(result.success).toBe(true);
  });

  it('passes through unknown fields', () => {
    const result = SubscriptionSchema.safeParse({
      id: 'sub_123',
      customer: 'cus_456',
      status: 'active',
      unknown_field: 'value',
    });
    expect(result.success).toBe(true);
  });
});

describe('InvoiceSchema', () => {
  it('accepts valid invoice with all fields', () => {
    const result = InvoiceSchema.safeParse({
      customer: 'cus_123',
      subscription: 'sub_456',
    });
    expect(result.success).toBe(true);
  });

  it('accepts invoice without subscription (optional)', () => {
    const result = InvoiceSchema.safeParse({ customer: 'cus_123' });
    expect(result.success).toBe(true);
  });

  it('rejects invoice missing required customer', () => {
    const result = InvoiceSchema.safeParse({ subscription: 'sub_456' });
    expect(result.success).toBe(false);
  });

  it('rejects empty object (customer is required)', () => {
    const result = InvoiceSchema.safeParse({});
    expect(result.success).toBe(false);
  });

  it('passes through unknown fields', () => {
    const result = InvoiceSchema.safeParse({ customer: 'cus_123', amount_due: 2000 });
    expect(result.success).toBe(true);
  });
});
