import { describe, it, expect, vi, beforeEach, afterEach } from 'vitest';
import { verifyStripeSignature } from './verify';
import worker, { type Env } from './index';
import { REPLAY_WINDOW_MS } from '../../constants';

// Seconds past the replay window, guaranteeing the timestamp is rejected as stale.
const STALE_OFFSET_SECONDS = (REPLAY_WINDOW_MS / 1000) * 2;

const { mockDb, mockHandleCheckout } = vi.hoisted(() => ({
  mockDb: {
    isEventProcessed: vi.fn(),
    logProcessedEvent: vi.fn(),
    addDeadLetter: vi.fn(),
    fetchPendingDeadLetters: vi.fn(),
    resolveDeadLetter: vi.fn(),
    failDeadLetter: vi.fn(),
    abandonDeadLetter: vi.fn(),
    linkStripeCustomer: vi.fn(),
    upsertSubscription: vi.fn(),
    updateOrgBillingStatus: vi.fn(),
    findOrgByStripeCustomerId: vi.fn(),
  },
  mockHandleCheckout: vi.fn(),
}));

vi.mock('./supabase', () => ({
  createSupabaseAdmin: vi.fn(() => mockDb),
}));

vi.mock('./handlers/checkout', () => ({
  handleCheckoutSessionCompleted: mockHandleCheckout,
}));

vi.mock('./handlers/subscription', () => ({
  handleSubscriptionUpdated: vi.fn(),
  handleSubscriptionDeleted: vi.fn(),
}));

vi.mock('./handlers/invoice', () => ({
  handleInvoicePaid: vi.fn(),
  handleInvoicePaymentFailed: vi.fn(),
}));

const MOCK_ENV: Env = {
  STRIPE_WEBHOOK_SECRET: 'test-secret',
  SUPABASE_URL: 'https://test.supabase.co',
  SUPABASE_SERVICE_ROLE_KEY: 'test-key',
};

async function computeStripeSignature(timestamp: number, body: string, secret: string): Promise<string> {
  const encoder = new TextEncoder();
  const key = await crypto.subtle.importKey(
    'raw',
    encoder.encode(secret),
    { name: 'HMAC', hash: 'SHA-256' },
    false,
    ['sign'],
  );
  const sig = await crypto.subtle.sign('HMAC', key, encoder.encode(`${timestamp}.${body}`));
  const hex = [...new Uint8Array(sig)].map((b) => b.toString(16).padStart(2, '0')).join('');
  return `t=${timestamp},v1=${hex}`;
}

describe('Stripe webhook verification', () => {
  it('should reject missing signature header', async () => {
    const result = await verifyStripeSignature(null, '{}', 'secret');
    expect(result.ok).toBe(false);
  });

  it('should reject invalid signature format', async () => {
    const result = await verifyStripeSignature('invalid', '{}', 'secret');
    expect(result.ok).toBe(false);
  });

  it('should reject stale timestamp', async () => {
    const staleTimestamp = Math.floor(Date.now() / 1000) - STALE_OFFSET_SECONDS;
    const result = await verifyStripeSignature(`t=${staleTimestamp},v1=anyhex`, '{}', 'secret');
    expect(result.ok).toBe(false);
  });

  it('should accept valid signature', async () => {
    const timestamp = Math.floor(Date.now() / 1000);
    const body = '{"type":"test"}';
    const secret = 'test_secret';

    const signature = await computeStripeSignature(timestamp, body, secret);
    const result = await verifyStripeSignature(signature, body, secret);

    expect(result.ok).toBe(true);
    if (result.ok) {
      expect(result.timestamp).toBe(timestamp);
    }
  });
});

describe('handleWebhook (fetch handler)', () => {
  let consoleSpy: ReturnType<typeof vi.spyOn>;

  beforeEach(() => {
    vi.clearAllMocks();
    consoleSpy = vi.spyOn(console, 'error').mockImplementation(() => {});
  });

  afterEach(() => {
    consoleSpy.mockRestore();
  });

  async function makeWebhookRequest(body: string, secret = 'test-secret'): Promise<Request> {
    const timestamp = Math.floor(Date.now() / 1000);
    const sig = await computeStripeSignature(timestamp, body, secret);
    return new Request('https://example.com/webhook', {
      method: 'POST',
      headers: { 'stripe-signature': sig, 'content-type': 'application/json' },
      body,
    });
  }

  it('logProcessedEvent failure → console.error logged, 200 still returned', async () => {
    const body = JSON.stringify({ id: 'evt_abc', type: 'checkout.session.completed' });
    const request = await makeWebhookRequest(body);

    mockDb.isEventProcessed.mockResolvedValue({ ok: true, processed: false });
    mockHandleCheckout.mockResolvedValue({ ok: true });
    mockDb.logProcessedEvent.mockResolvedValue({ ok: false, error: 'DB write failed' });

    const response = await worker.fetch(request, MOCK_ENV);
    const json = await response.json<{ ok: boolean; processed: boolean }>();

    expect(response.status).toBe(200);
    expect(json.processed).toBe(true);
    expect(consoleSpy).toHaveBeenCalledWith(
      expect.stringContaining('Failed to log processed event evt_abc'),
      'DB write failed',
    );
  });
});

describe('runReconciliation', () => {
  const checkoutDeadLetter = {
    id: 'dl_1',
    stripe_event_id: 'evt_123',
    event_type: 'checkout.session.completed',
    payload: { id: 'evt_123', type: 'checkout.session.completed' },
    retry_count: 0,
    max_retries: 5,
  };

  beforeEach(() => {
    vi.clearAllMocks();
  });

  it('retries successfully: logProcessedEvent and resolveDeadLetter called', async () => {
    mockDb.fetchPendingDeadLetters.mockResolvedValue([checkoutDeadLetter]);
    mockDb.isEventProcessed.mockResolvedValue({ ok: true, processed: false });
    mockHandleCheckout.mockResolvedValue({ ok: true });
    mockDb.logProcessedEvent.mockResolvedValue({ ok: true });
    mockDb.resolveDeadLetter.mockResolvedValue({ ok: true });

    await worker.scheduled(
      { scheduledTime: Date.now(), cron: '*/15 * * * *' } as ScheduledEvent,
      MOCK_ENV,
      {} as ExecutionContext,
    );

    expect(mockHandleCheckout).toHaveBeenCalledOnce();
    expect(mockDb.logProcessedEvent).toHaveBeenCalledWith('evt_123', 'checkout.session.completed');
    expect(mockDb.resolveDeadLetter).toHaveBeenCalledWith('dl_1');
    expect(mockDb.failDeadLetter).not.toHaveBeenCalled();
  });

  it('idempotency guard: already processed → resolveDeadLetter called, handler skipped', async () => {
    mockDb.fetchPendingDeadLetters.mockResolvedValue([checkoutDeadLetter]);
    mockDb.isEventProcessed.mockResolvedValue({ ok: true, processed: true });
    mockDb.resolveDeadLetter.mockResolvedValue({ ok: true });

    await worker.scheduled(
      { scheduledTime: Date.now(), cron: '*/15 * * * *' } as ScheduledEvent,
      MOCK_ENV,
      {} as ExecutionContext,
    );

    expect(mockHandleCheckout).not.toHaveBeenCalled();
    expect(mockDb.resolveDeadLetter).toHaveBeenCalledWith('dl_1');
    expect(mockDb.logProcessedEvent).not.toHaveBeenCalled();
  });

  it('handler failure → failDeadLetter increments retry counter', async () => {
    mockDb.fetchPendingDeadLetters.mockResolvedValue([checkoutDeadLetter]);
    mockDb.isEventProcessed.mockResolvedValue({ ok: true, processed: false });
    mockHandleCheckout.mockResolvedValue({ ok: false, error: 'DB write failed' });
    mockDb.failDeadLetter.mockResolvedValue({ ok: true });

    await worker.scheduled(
      { scheduledTime: Date.now(), cron: '*/15 * * * *' } as ScheduledEvent,
      MOCK_ENV,
      {} as ExecutionContext,
    );

    expect(mockDb.failDeadLetter).toHaveBeenCalledWith('dl_1', 0, 5, 'DB write failed');
    expect(mockDb.resolveDeadLetter).not.toHaveBeenCalled();
  });

  it('unhandled event type → abandonDeadLetter called', async () => {
    const unknownDl = { ...checkoutDeadLetter, event_type: 'unknown.event.type' };
    mockDb.fetchPendingDeadLetters.mockResolvedValue([unknownDl]);
    mockDb.isEventProcessed.mockResolvedValue({ ok: true, processed: false });
    mockDb.abandonDeadLetter.mockResolvedValue({ ok: true });

    await worker.scheduled(
      { scheduledTime: Date.now(), cron: '*/15 * * * *' } as ScheduledEvent,
      MOCK_ENV,
      {} as ExecutionContext,
    );

    expect(mockDb.abandonDeadLetter).toHaveBeenCalledWith('dl_1');
    expect(mockHandleCheckout).not.toHaveBeenCalled();
  });

  it('isEventProcessed DB error → dead letter skipped, no state mutation', async () => {
    const secondDl = { ...checkoutDeadLetter, id: 'dl_2', stripe_event_id: 'evt_456' };
    mockDb.fetchPendingDeadLetters.mockResolvedValue([checkoutDeadLetter, secondDl]);
    mockDb.isEventProcessed
      .mockResolvedValueOnce({ ok: false, error: 'Connection timeout' })
      .mockResolvedValueOnce({ ok: true, processed: false });
    mockHandleCheckout.mockResolvedValue({ ok: true });
    mockDb.logProcessedEvent.mockResolvedValue({ ok: true });
    mockDb.resolveDeadLetter.mockResolvedValue({ ok: true });

    await worker.scheduled(
      { scheduledTime: Date.now(), cron: '*/15 * * * *' } as ScheduledEvent,
      MOCK_ENV,
      {} as ExecutionContext,
    );

    // dl_1 skipped — no mutations
    expect(mockDb.resolveDeadLetter).not.toHaveBeenCalledWith('dl_1');
    expect(mockDb.failDeadLetter).not.toHaveBeenCalled();
    expect(mockDb.abandonDeadLetter).not.toHaveBeenCalled();
    // dl_2 processed normally
    expect(mockDb.resolveDeadLetter).toHaveBeenCalledWith('dl_2');
  });

  it('logProcessedEvent failure in reconciliation → console.error logged, resolveDeadLetter still called', async () => {
    mockDb.fetchPendingDeadLetters.mockResolvedValue([checkoutDeadLetter]);
    mockDb.isEventProcessed.mockResolvedValue({ ok: true, processed: false });
    mockHandleCheckout.mockResolvedValue({ ok: true });
    mockDb.logProcessedEvent.mockResolvedValue({ ok: false, error: 'Write failed' });
    mockDb.resolveDeadLetter.mockResolvedValue({ ok: true });

    const consoleSpy = vi.spyOn(console, 'error').mockImplementation(() => {});

    await worker.scheduled(
      { scheduledTime: Date.now(), cron: '*/15 * * * *' } as ScheduledEvent,
      MOCK_ENV,
      {} as ExecutionContext,
    );

    expect(consoleSpy).toHaveBeenCalledWith(
      expect.stringContaining('Failed to log processed event evt_123'),
      'Write failed',
    );
    expect(mockDb.resolveDeadLetter).toHaveBeenCalledWith('dl_1');

    consoleSpy.mockRestore();
  });
});
