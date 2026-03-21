import { describe, it, expect, vi, beforeEach, afterEach } from 'vitest';
import { verifyStripeSignature } from './verify';
import worker, { type Env } from './index';
import { REPLAY_WINDOW_MS } from '../../constants';

// Seconds past the replay window, guaranteeing the timestamp is rejected as stale.
const STALE_OFFSET_SECONDS = (REPLAY_WINDOW_MS / 1000) * 2;

const { mockDb, mockHandleCheckout, mockHandleSubscriptionUpdated } = vi.hoisted(() => ({
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
  mockHandleSubscriptionUpdated: vi.fn(),
}));

vi.mock('./supabase', () => ({
  createSupabaseAdmin: vi.fn(() => mockDb),
}));

vi.mock('./handlers/checkout', () => ({
  handleCheckoutSessionCompleted: mockHandleCheckout,
}));

vi.mock('./handlers/subscription', () => ({
  handleSubscriptionUpdated: mockHandleSubscriptionUpdated,
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

  it('invalid signature → 401 rejected', async () => {
    const request = new Request('https://example.com/webhook', {
      method: 'POST',
      headers: { 'stripe-signature': 'invalid', 'content-type': 'application/json' },
      body: '{"type":"checkout.session.completed","id":"evt_abc"}',
    });

    const response = await worker.fetch(request, MOCK_ENV);
    expect(response.status).toBe(401);
  });

  it('already processed → skipped: true response, handler not called', async () => {
    const body = JSON.stringify({ id: 'evt_dup', type: 'checkout.session.completed' });
    const request = await makeWebhookRequest(body);

    mockDb.isEventProcessed.mockResolvedValue({ ok: true, processed: true });

    const response = await worker.fetch(request, MOCK_ENV);
    const json = await response.json<{ ok: boolean; skipped: boolean }>();

    expect(response.status).toBe(200);
    expect(json.skipped).toBe(true);
    expect(mockHandleCheckout).not.toHaveBeenCalled();
  });

  it('handler failure → addDeadLetter called, 200 returned with error field', async () => {
    const body = JSON.stringify({ id: 'evt_fail', type: 'checkout.session.completed' });
    const request = await makeWebhookRequest(body);

    mockDb.isEventProcessed.mockResolvedValue({ ok: true, processed: false });
    mockHandleCheckout.mockResolvedValue({ ok: false, error: 'DB write failed' });
    mockDb.addDeadLetter.mockResolvedValue({ ok: true });

    const response = await worker.fetch(request, MOCK_ENV);
    const json = await response.json<{ ok: boolean; processed: boolean; error: string }>();

    expect(response.status).toBe(200);
    expect(json.processed).toBe(false);
    expect(json.error).toBe('DB write failed');
    expect(mockDb.addDeadLetter).toHaveBeenCalledWith('evt_fail', 'checkout.session.completed', expect.any(Object), 'DB write failed');
  });

  it('addDeadLetter failure → CRITICAL error logged, 200 still returned', async () => {
    const body = JSON.stringify({ id: 'evt_lost', type: 'checkout.session.completed' });
    const request = await makeWebhookRequest(body);

    mockDb.isEventProcessed.mockResolvedValue({ ok: true, processed: false });
    mockHandleCheckout.mockResolvedValue({ ok: false, error: 'handler error' });
    mockDb.addDeadLetter.mockResolvedValue({ ok: false, error: 'DB unavailable' });

    const response = await worker.fetch(request, MOCK_ENV);
    expect(response.status).toBe(200);
    expect(consoleSpy).toHaveBeenCalledWith(
      expect.stringContaining('CRITICAL'),
      expect.any(String),
      'DB unavailable',
    );
  });

  it('health endpoint → 200 with ok:true', async () => {
    const request = new Request('https://example.com/health', { method: 'GET' });
    const response = await worker.fetch(request, MOCK_ENV);
    const json = await response.json<{ ok: boolean }>();
    expect(response.status).toBe(200);
    expect(json.ok).toBe(true);
  });

  it('unknown route → 404', async () => {
    const request = new Request('https://example.com/unknown', { method: 'GET' });
    const response = await worker.fetch(request, MOCK_ENV);
    expect(response.status).toBe(404);
  });

  it('logProcessedEvent failure → dead letter inserted, processed:false returned', async () => {
    const body = JSON.stringify({ id: 'evt_abc', type: 'checkout.session.completed' });
    const request = await makeWebhookRequest(body);

    mockDb.isEventProcessed.mockResolvedValue({ ok: true, processed: false });
    mockHandleCheckout.mockResolvedValue({ ok: true });
    mockDb.logProcessedEvent.mockResolvedValue({ ok: false, error: 'DB write failed' });
    mockDb.addDeadLetter.mockResolvedValue({ ok: true });

    const response = await worker.fetch(request, MOCK_ENV);
    const json = await response.json<{ ok: boolean; processed: boolean; error: string }>();

    expect(response.status).toBe(200);
    expect(json.processed).toBe(false);
    expect(json.error).toBe('Failed to log processed event');
    expect(consoleSpy).toHaveBeenCalledWith(
      expect.stringContaining('Failed to log processed event evt_abc'),
      'DB write failed',
    );
    expect(mockDb.addDeadLetter).toHaveBeenCalledWith(
      'evt_abc',
      'checkout.session.completed',
      expect.any(Object),
      expect.stringContaining('logProcessedEvent failed'),
    );
  });

  it('logProcessedEvent failure + addDeadLetter failure → CRITICAL logged, processed:false returned', async () => {
    const body = JSON.stringify({ id: 'evt_abc2', type: 'checkout.session.completed' });
    const request = await makeWebhookRequest(body);

    mockDb.isEventProcessed.mockResolvedValue({ ok: true, processed: false });
    mockHandleCheckout.mockResolvedValue({ ok: true });
    mockDb.logProcessedEvent.mockResolvedValue({ ok: false, error: 'DB write failed' });
    mockDb.addDeadLetter.mockResolvedValue({ ok: false, error: 'DB unavailable' });

    const response = await worker.fetch(request, MOCK_ENV);
    const json = await response.json<{ ok: boolean; processed: boolean }>();

    expect(response.status).toBe(200);
    expect(json.processed).toBe(false);
    expect(consoleSpy).toHaveBeenCalledWith(
      expect.stringContaining('CRITICAL'),
      'DB unavailable',
    );
  });
});

describe('parsePriceToPlan (via handleWebhook)', () => {
  let consoleSpy: ReturnType<typeof vi.spyOn>;

  beforeEach(() => {
    vi.clearAllMocks();
    consoleSpy = vi.spyOn(console, 'warn').mockImplementation(() => {});
  });

  afterEach(() => {
    consoleSpy.mockRestore();
  });

  async function makeSubUpdatedRequest(secret = 'test-secret'): Promise<Request> {
    const body = JSON.stringify({ id: 'evt_sub', type: 'customer.subscription.updated', data: { object: {} } });
    const timestamp = Math.floor(Date.now() / 1000);
    const encoder = new TextEncoder();
    const key = await crypto.subtle.importKey('raw', encoder.encode(secret), { name: 'HMAC', hash: 'SHA-256' }, false, ['sign']);
    const sig = await crypto.subtle.sign('HMAC', key, encoder.encode(`${timestamp}.${body}`));
    const hex = [...new Uint8Array(sig)].map((b) => b.toString(16).padStart(2, '0')).join('');
    return new Request('https://example.com/webhook', {
      method: 'POST',
      headers: { 'stripe-signature': `t=${timestamp},v1=${hex}`, 'content-type': 'application/json' },
      body,
    });
  }

  it('valid JSON with valid plan key → priceToPlan map passed to handleSubscriptionUpdated', async () => {
    const env = { ...MOCK_ENV, STRIPE_PRICE_TO_PLAN_JSON: '{"price_abc":"growth"}' };
    mockDb.isEventProcessed.mockResolvedValue({ ok: true, processed: false });
    mockHandleSubscriptionUpdated.mockResolvedValue({ ok: true });
    mockDb.logProcessedEvent.mockResolvedValue({ ok: true });

    await worker.fetch(await makeSubUpdatedRequest(), env);

    expect(mockHandleSubscriptionUpdated).toHaveBeenCalledWith(
      expect.any(Object),
      expect.any(Object),
      { price_abc: 'growth' },
    );
  });

  it('valid JSON with invalid plan value → entry skipped, warn logged, empty map passed', async () => {
    const env = { ...MOCK_ENV, STRIPE_PRICE_TO_PLAN_JSON: '{"price_abc":"enterprise","price_xyz":"invalid_plan"}' };
    mockDb.isEventProcessed.mockResolvedValue({ ok: true, processed: false });
    mockHandleSubscriptionUpdated.mockResolvedValue({ ok: true });
    mockDb.logProcessedEvent.mockResolvedValue({ ok: true });

    await worker.fetch(await makeSubUpdatedRequest(), env);

    expect(mockHandleSubscriptionUpdated).toHaveBeenCalledWith(
      expect.any(Object),
      expect.any(Object),
      { price_abc: 'enterprise' },
    );
    expect(consoleSpy).toHaveBeenCalledWith(expect.stringContaining('invalid_plan'));
  });

  it('invalid JSON → console.warn logged, empty map passed to handler', async () => {
    const env = { ...MOCK_ENV, STRIPE_PRICE_TO_PLAN_JSON: 'not-valid-json' };
    mockDb.isEventProcessed.mockResolvedValue({ ok: true, processed: false });
    mockHandleSubscriptionUpdated.mockResolvedValue({ ok: true });
    mockDb.logProcessedEvent.mockResolvedValue({ ok: true });

    await worker.fetch(await makeSubUpdatedRequest(), env);

    expect(mockHandleSubscriptionUpdated).toHaveBeenCalledWith(
      expect.any(Object),
      expect.any(Object),
      {},
    );
    expect(consoleSpy).toHaveBeenCalledWith(expect.stringContaining('not valid JSON'));
  });

  it('missing env var → empty map passed to handler', async () => {
    mockDb.isEventProcessed.mockResolvedValue({ ok: true, processed: false });
    mockHandleSubscriptionUpdated.mockResolvedValue({ ok: true });
    mockDb.logProcessedEvent.mockResolvedValue({ ok: true });

    await worker.fetch(await makeSubUpdatedRequest(), MOCK_ENV);

    expect(mockHandleSubscriptionUpdated).toHaveBeenCalledWith(
      expect.any(Object),
      expect.any(Object),
      {},
    );
    expect(consoleSpy).not.toHaveBeenCalled();
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

  let consoleSpy: ReturnType<typeof vi.spyOn>;

  beforeEach(() => {
    vi.clearAllMocks();
    consoleSpy = vi.spyOn(console, 'error').mockImplementation(() => {});
  });

  afterEach(() => {
    consoleSpy.mockRestore();
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

  it('logProcessedEvent failure in reconciliation → console.error logged, resolveDeadLetter NOT called (leave pending for retry)', async () => {
    mockDb.fetchPendingDeadLetters.mockResolvedValue([checkoutDeadLetter]);
    mockDb.isEventProcessed.mockResolvedValue({ ok: true, processed: false });
    mockHandleCheckout.mockResolvedValue({ ok: true });
    mockDb.logProcessedEvent.mockResolvedValue({ ok: false, error: 'Write failed' });
    mockDb.resolveDeadLetter.mockResolvedValue({ ok: true });

    await worker.scheduled(
      { scheduledTime: Date.now(), cron: '*/15 * * * *' } as ScheduledEvent,
      MOCK_ENV,
      {} as ExecutionContext,
    );

    expect(consoleSpy).toHaveBeenCalledWith(
      expect.stringContaining('Failed to log processed event evt_123'),
      'Write failed',
    );
    // Dead-letter must NOT be resolved — leave it pending so the next cron run
    // retries the full sequence (handler → logProcessedEvent → resolveDeadLetter).
    // Without a log entry the idempotency guard cannot detect the event as processed.
    expect(mockDb.resolveDeadLetter).not.toHaveBeenCalled();
  });
});
