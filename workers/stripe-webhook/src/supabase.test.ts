import { describe, it, expect, vi, beforeEach, afterEach } from 'vitest';
import { createSupabaseAdmin } from './supabase';
import { DEAD_LETTER_MAX_RETRIES } from '../../constants';

const { mockQuery, mockInsert, mockUpdate, mockUpsert } = vi.hoisted(() => ({
  mockQuery: vi.fn(),
  mockInsert: vi.fn(),
  mockUpdate: vi.fn(),
  mockUpsert: vi.fn(),
}));

vi.mock('../../lib/supabase', () => ({
  createSupabaseClient: () => ({
    query: mockQuery,
    insert: mockInsert,
    update: mockUpdate,
    upsert: mockUpsert,
    rpc: vi.fn(),
  }),
}));

describe('fetchPendingDeadLetters', () => {
  let db: ReturnType<typeof createSupabaseAdmin>;
  let consoleSpy: ReturnType<typeof vi.spyOn>;

  beforeEach(() => {
    vi.clearAllMocks();
    db = createSupabaseAdmin('https://test.supabase.co', 'test-key');
    consoleSpy = vi.spyOn(console, 'error').mockImplementation(() => {});
  });

  afterEach(() => {
    consoleSpy.mockRestore();
  });

  it('DB error → console.error logged, empty array returned', async () => {
    mockQuery.mockResolvedValue({ ok: false, error: 'Connection timeout' });

    const result = await db.fetchPendingDeadLetters();

    expect(result).toEqual([]);
    expect(consoleSpy).toHaveBeenCalledWith(
      'fetchPendingDeadLetters DB error:',
      'Connection timeout',
    );
  });

  it('non-array data → returns empty array without error', async () => {
    mockQuery.mockResolvedValue({ ok: true, data: null });
    const result = await db.fetchPendingDeadLetters();
    expect(result).toEqual([]);
  });

  it('array data → returns the array of dead letters', async () => {
    const deadLetters = [
      { id: 'dl-1', stripe_event_id: 'evt_1', event_type: 'checkout.session.completed', payload: {}, retry_count: 0, max_retries: 5 },
    ];
    mockQuery.mockResolvedValue({ ok: true, data: deadLetters });
    const result = await db.fetchPendingDeadLetters();
    expect(result).toEqual(deadLetters);
  });

  it('passes custom limit to the query', async () => {
    mockQuery.mockResolvedValue({ ok: true, data: [] });
    await db.fetchPendingDeadLetters(10);
    expect(mockQuery).toHaveBeenCalledWith(
      'webhook_dead_letters',
      expect.objectContaining({ limit: 10 }),
    );
  });
});

describe('isEventProcessed', () => {
  let db: ReturnType<typeof createSupabaseAdmin>;

  beforeEach(() => {
    vi.clearAllMocks();
    db = createSupabaseAdmin('https://test.supabase.co', 'test-key');
  });

  it('returns { ok: true, processed: true } when event exists in log', async () => {
    mockQuery.mockResolvedValue({ ok: true, data: { id: 'evt_123' } });
    const result = await db.isEventProcessed('evt_123');
    expect(result).toEqual({ ok: true, processed: true });
  });

  it('returns { ok: true, processed: false } when event not in log', async () => {
    mockQuery.mockResolvedValue({ ok: true, data: null });
    const result = await db.isEventProcessed('evt_456');
    expect(result).toEqual({ ok: true, processed: false });
  });

  it('returns { ok: false, error } on DB query failure', async () => {
    mockQuery.mockResolvedValue({ ok: false, error: 'Connection timeout' });
    const result = await db.isEventProcessed('evt_789');
    expect(result).toEqual({ ok: false, error: 'Connection timeout' });
  });
});

// ---------------------------------------------------------------------------
// linkStripeCustomer
// ---------------------------------------------------------------------------

describe('linkStripeCustomer', () => {
  let db: ReturnType<typeof createSupabaseAdmin>;

  beforeEach(() => {
    vi.clearAllMocks();
    db = createSupabaseAdmin('https://test.supabase.co', 'test-key');
  });

  it('returns { ok: true } and updates organizations table', async () => {
    mockUpdate.mockResolvedValue({ ok: true });

    const result = await db.linkStripeCustomer('org-1', 'cus_123');

    expect(result).toEqual({ ok: true });
    expect(mockUpdate).toHaveBeenCalledWith(
      'organizations',
      { stripe_customer_id: 'cus_123' },
      [{ column: 'id', operator: 'eq', value: 'org-1' }],
    );
  });

  it('returns { ok: false, error } on DB failure', async () => {
    mockUpdate.mockResolvedValue({ ok: false, error: 'Connection timeout' });

    const result = await db.linkStripeCustomer('org-1', 'cus_123');

    expect(result).toEqual({ ok: false, error: 'Connection timeout' });
  });

  it('returns { ok: false, error: "Unknown error" } when DB result has no error field', async () => {
    mockUpdate.mockResolvedValue({ ok: false });

    const result = await db.linkStripeCustomer('org-1', 'cus_123');

    expect(result).toEqual({ ok: false, error: 'Unknown error' });
  });
});

// ---------------------------------------------------------------------------
// upsertSubscription
// ---------------------------------------------------------------------------

describe('upsertSubscription', () => {
  let db: ReturnType<typeof createSupabaseAdmin>;

  beforeEach(() => {
    vi.clearAllMocks();
    db = createSupabaseAdmin('https://test.supabase.co', 'test-key');
    mockUpdate.mockResolvedValue({ ok: true }); // soft-delete step succeeds by default
  });

  it('returns { ok: true } and calls upsert with correct conflict key', async () => {
    mockUpsert.mockResolvedValue({ ok: true });

    const result = await db.upsertSubscription('org-1', 'sub_abc', 'price_xyz', 'active');

    expect(result).toEqual({ ok: true });
    expect(mockUpsert).toHaveBeenCalledWith(
      'subscriptions',
      expect.objectContaining({
        organization_id: 'org-1',
        stripe_subscription_id: 'sub_abc',
        stripe_price_id: 'price_xyz',
        status: 'active',
      }),
      'organization_id,stripe_subscription_id',
    );
  });

  it('upserts with null price_id for stub rows from checkout handler', async () => {
    mockUpsert.mockResolvedValue({ ok: true });

    const result = await db.upsertSubscription('org-1', 'sub_abc', null, 'active');

    expect(result).toEqual({ ok: true });
    expect(mockUpsert).toHaveBeenCalledWith(
      'subscriptions',
      expect.objectContaining({ stripe_price_id: null }),
      'organization_id,stripe_subscription_id',
    );
  });

  it('returns { ok: false, error } on DB failure', async () => {
    mockUpsert.mockResolvedValue({ ok: false, error: 'Duplicate key violation' });

    const result = await db.upsertSubscription('org-1', 'sub_abc', 'price_xyz', 'active');

    expect(result).toEqual({ ok: false, error: 'Duplicate key violation' });
  });

  it('soft-deletes prior subscriptions with a different ID before upsert', async () => {
    mockUpsert.mockResolvedValue({ ok: true });

    await db.upsertSubscription('org-1', 'sub_new', 'price_xyz', 'active');

    expect(mockUpdate).toHaveBeenCalledWith(
      'subscriptions',
      expect.objectContaining({ status: 'canceled' }),
      [
        { column: 'organization_id', operator: 'eq', value: 'org-1' },
        { column: 'stripe_subscription_id', operator: 'neq', value: 'sub_new' },
        { column: 'status', operator: 'neq', value: 'canceled' },
      ],
    );
  });

  it('returns { ok: false } when soft-delete update fails', async () => {
    mockUpdate.mockResolvedValue({ ok: false, error: 'DB connection error' });

    const result = await db.upsertSubscription('org-1', 'sub_new', 'price_xyz', 'active');

    expect(result).toEqual({ ok: false, error: 'DB connection error' });
    expect(mockUpsert).not.toHaveBeenCalled();
  });
});

// ---------------------------------------------------------------------------
// updateOrgBillingStatus
// ---------------------------------------------------------------------------

describe('updateOrgBillingStatus', () => {
  let db: ReturnType<typeof createSupabaseAdmin>;

  beforeEach(() => {
    vi.clearAllMocks();
    db = createSupabaseAdmin('https://test.supabase.co', 'test-key');
  });

  it('updates billing_status only when planKey and bumpQuotaVersion omitted', async () => {
    mockUpdate.mockResolvedValue({ ok: true });

    await db.updateOrgBillingStatus('org-1', 'active');

    expect(mockUpdate).toHaveBeenCalledWith(
      'organizations',
      { billing_status: 'active' },
      [{ column: 'id', operator: 'eq', value: 'org-1' }],
    );
  });

  it('includes current_plan when planKey provided', async () => {
    mockUpdate.mockResolvedValue({ ok: true });

    await db.updateOrgBillingStatus('org-1', 'active', 'growth');

    expect(mockUpdate).toHaveBeenCalledWith(
      'organizations',
      expect.objectContaining({ billing_status: 'active', current_plan: 'growth' }),
      [{ column: 'id', operator: 'eq', value: 'org-1' }],
    );
  });

  it('includes numeric quota_version when bumpQuotaVersion is true', async () => {
    mockUpdate.mockResolvedValue({ ok: true });

    await db.updateOrgBillingStatus('org-1', 'active', undefined, true);

    expect(mockUpdate).toHaveBeenCalledWith(
      'organizations',
      expect.objectContaining({ quota_version: expect.any(Number) }),
      [{ column: 'id', operator: 'eq', value: 'org-1' }],
    );
  });

  it('does not include quota_version when bumpQuotaVersion is false', async () => {
    mockUpdate.mockResolvedValue({ ok: true });

    await db.updateOrgBillingStatus('org-1', 'past_due', undefined, false);

    const [, updates] = mockUpdate.mock.calls[0];
    expect(updates).not.toHaveProperty('quota_version');
  });

  it('returns { ok: false, error } on DB failure', async () => {
    mockUpdate.mockResolvedValue({ ok: false, error: 'Row not found' });

    const result = await db.updateOrgBillingStatus('org-1', 'inactive');

    expect(result).toEqual({ ok: false, error: 'Row not found' });
  });
});

// ---------------------------------------------------------------------------
// addDeadLetter
// ---------------------------------------------------------------------------

describe('addDeadLetter', () => {
  let db: ReturnType<typeof createSupabaseAdmin>;

  beforeEach(() => {
    vi.clearAllMocks();
    vi.useFakeTimers();
    db = createSupabaseAdmin('https://test.supabase.co', 'test-key');
  });

  afterEach(() => {
    vi.useRealTimers();
  });

  it('inserts with correct fields and next_retry_at 60s in future', async () => {
    vi.setSystemTime(new Date('2026-01-01T00:00:00.000Z'));
    mockInsert.mockResolvedValue({ ok: true });

    const result = await db.addDeadLetter(
      'evt_123',
      'checkout.session.completed',
      { id: 'evt_123' },
      'parse error',
    );

    expect(result).toEqual({ ok: true });
    expect(mockInsert).toHaveBeenCalledWith(
      'webhook_dead_letters',
      expect.objectContaining({
        stripe_event_id: 'evt_123',
        event_type: 'checkout.session.completed',
        payload: { id: 'evt_123' },
        error_message: 'parse error',
        retry_count: 0,
        max_retries: DEAD_LETTER_MAX_RETRIES,
        status: 'pending',
        next_retry_at: '2026-01-01T00:01:00.000Z',
        created_at: '2026-01-01T00:00:00.000Z',
      }),
    );
  });

  it('returns { ok: false, error } on DB failure', async () => {
    mockInsert.mockResolvedValue({ ok: false, error: 'Insert failed' });

    const result = await db.addDeadLetter('evt_123', 'checkout.session.completed', {}, 'err');

    expect(result).toEqual({ ok: false, error: 'Insert failed' });
  });
});

// ---------------------------------------------------------------------------
// failDeadLetter
// ---------------------------------------------------------------------------

describe('failDeadLetter', () => {
  let db: ReturnType<typeof createSupabaseAdmin>;

  beforeEach(() => {
    vi.clearAllMocks();
    vi.useFakeTimers();
    db = createSupabaseAdmin('https://test.supabase.co', 'test-key');
  });

  afterEach(() => {
    vi.useRealTimers();
  });

  it('increments count, stays pending, and sets next_retry_at when below maxRetries', async () => {
    vi.setSystemTime(new Date('2026-01-01T00:00:00.000Z'));
    mockUpdate.mockResolvedValue({ ok: true });

    await db.failDeadLetter('dl-1', 1, 5, 'transient error');

    // next_retry_at = now + 2^1 * 60_000ms = +2 min
    expect(mockUpdate).toHaveBeenCalledWith(
      'webhook_dead_letters',
      expect.objectContaining({
        retry_count: 2,
        status: 'pending',
        next_retry_at: '2026-01-01T00:02:00.000Z',
        error_message: 'transient error',
      }),
      [{ column: 'id', operator: 'eq', value: 'dl-1' }],
    );
  });

  it('sets status to abandoned and omits next_retry_at when newCount reaches maxRetries', async () => {
    mockUpdate.mockResolvedValue({ ok: true });

    await db.failDeadLetter('dl-1', 4, 5, 'final error');

    const [table, updates, filter] = mockUpdate.mock.calls[0];
    expect(table).toBe('webhook_dead_letters');
    expect(filter).toEqual([{ column: 'id', operator: 'eq', value: 'dl-1' }]);
    expect(updates.retry_count).toBe(5);
    expect(updates.status).toBe('abandoned');
    expect(updates).not.toHaveProperty('next_retry_at');
  });

  it('returns { ok: false, error } on DB failure', async () => {
    mockUpdate.mockResolvedValue({ ok: false, error: 'Update failed' });

    const result = await db.failDeadLetter('dl-1', 0, 5, 'err');

    expect(result).toEqual({ ok: false, error: 'Update failed' });
  });
});

// ---------------------------------------------------------------------------
// resolveDeadLetter
// ---------------------------------------------------------------------------

describe('resolveDeadLetter', () => {
  let db: ReturnType<typeof createSupabaseAdmin>;

  beforeEach(() => {
    vi.clearAllMocks();
    db = createSupabaseAdmin('https://test.supabase.co', 'test-key');
  });

  it('updates status to resolved and returns { ok: true }', async () => {
    mockUpdate.mockResolvedValue({ ok: true });

    const result = await db.resolveDeadLetter('dl-1');

    expect(result).toEqual({ ok: true });
    expect(mockUpdate).toHaveBeenCalledWith(
      'webhook_dead_letters',
      expect.objectContaining({ status: 'resolved' }),
      [{ column: 'id', operator: 'eq', value: 'dl-1' }],
    );
  });

  it('returns { ok: false, error } on DB failure', async () => {
    mockUpdate.mockResolvedValue({ ok: false, error: 'Update failed' });

    const result = await db.resolveDeadLetter('dl-1');

    expect(result).toEqual({ ok: false, error: 'Update failed' });
  });
});

// ---------------------------------------------------------------------------
// abandonDeadLetter
// ---------------------------------------------------------------------------

describe('abandonDeadLetter', () => {
  let db: ReturnType<typeof createSupabaseAdmin>;

  beforeEach(() => {
    vi.clearAllMocks();
    db = createSupabaseAdmin('https://test.supabase.co', 'test-key');
  });

  it('updates status to abandoned and returns { ok: true }', async () => {
    mockUpdate.mockResolvedValue({ ok: true });

    const result = await db.abandonDeadLetter('dl-1');

    expect(result).toEqual({ ok: true });
    expect(mockUpdate).toHaveBeenCalledWith(
      'webhook_dead_letters',
      expect.objectContaining({ status: 'abandoned' }),
      [{ column: 'id', operator: 'eq', value: 'dl-1' }],
    );
  });

  it('returns { ok: false, error } on DB failure', async () => {
    mockUpdate.mockResolvedValue({ ok: false, error: 'Update failed' });

    const result = await db.abandonDeadLetter('dl-1');

    expect(result).toEqual({ ok: false, error: 'Update failed' });
  });
});

// ---------------------------------------------------------------------------
// findOrgByStripeCustomerId
// ---------------------------------------------------------------------------

describe('findOrgByStripeCustomerId', () => {
  let db: ReturnType<typeof createSupabaseAdmin>;

  beforeEach(() => {
    vi.clearAllMocks();
    db = createSupabaseAdmin('https://test.supabase.co', 'test-key');
  });

  it('returns { ok: true, orgId } when org found', async () => {
    mockQuery.mockResolvedValue({ ok: true, data: { id: 'org-1' } });

    const result = await db.findOrgByStripeCustomerId('cus_123');

    expect(result).toEqual({ ok: true, orgId: 'org-1' });
  });

  it('returns { ok: true, orgId: null } when no org found', async () => {
    mockQuery.mockResolvedValue({ ok: true, data: null });

    const result = await db.findOrgByStripeCustomerId('cus_unknown');

    expect(result).toEqual({ ok: true, orgId: null });
  });

  it('returns { ok: false, error } on DB failure', async () => {
    mockQuery.mockResolvedValue({ ok: false, error: 'Connection timeout' });

    const result = await db.findOrgByStripeCustomerId('cus_123');

    expect(result).toEqual({ ok: false, error: 'Connection timeout' });
  });
});

// ---------------------------------------------------------------------------
// logProcessedEvent
// ---------------------------------------------------------------------------

describe('logProcessedEvent', () => {
  let db: ReturnType<typeof createSupabaseAdmin>;

  beforeEach(() => {
    vi.clearAllMocks();
    db = createSupabaseAdmin('https://test.supabase.co', 'test-key');
  });

  it('inserts with correct fields and returns { ok: true }', async () => {
    mockInsert.mockResolvedValue({ ok: true });

    const result = await db.logProcessedEvent('evt_123', 'checkout.session.completed');

    expect(result).toEqual({ ok: true });
    expect(mockInsert).toHaveBeenCalledWith(
      'webhook_events_log',
      expect.objectContaining({
        stripe_event_id: 'evt_123',
        event_type: 'checkout.session.completed',
      }),
    );
  });

  it('returns { ok: false, error } on DB failure', async () => {
    mockInsert.mockResolvedValue({ ok: false, error: 'Insert failed' });

    const result = await db.logProcessedEvent('evt_123', 'invoice.paid');

    expect(result).toEqual({ ok: false, error: 'Insert failed' });
  });
});
