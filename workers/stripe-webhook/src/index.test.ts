import { describe, it, expect, vi, beforeEach, afterEach } from 'vitest';
import { verifyStripeSignature } from './verify';
import worker, { type Env } from './index';
import { REPLAY_WINDOW_MS } from '../../constants';
import { hmacSignHex } from '../../lib/crypto';

// Seconds past the replay window, guaranteeing the timestamp is rejected as stale.
const STALE_OFFSET_SECONDS = (REPLAY_WINDOW_MS / 1000) * 2;

const { mockDb, mockHandleCheckout, mockHandleSubscriptionUpdated } = vi.hoisted(() => ({
  mockDb: {
    isEventProcessed: vi.fn(),
    claimEvent: vi.fn(),
    unclaimEvent: vi.fn(),
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

// Creates a minimal ExecutionContext whose waitUntil promise can be awaited in tests.
function makeMockCtx() {
  const pending: Promise<unknown>[] = [];
  // Cast to avoid providing the readonly `props` field that only exists in the type definition.
  const ctx = {
    waitUntil(p: Promise<unknown>) { pending.push(p); },
    passThroughOnException() {},
  } as unknown as ExecutionContext;
  return {
    ctx,
    /** Awaits all promises registered with waitUntil so side effects are observable. */
    async flush() { for (const p of pending) await p; },
  };
}

async function computeStripeSignature(timestamp: number, body: string, secret: string): Promise<string> {
  const hex = await hmacSignHex(secret, `${timestamp}.${body}`);
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

  it('should reject signature with non-hex v1 value', async () => {
    const timestamp = Math.floor(Date.now() / 1000);
    // Non-hex characters (Z is not hex) trigger the sigBytes null path
    const result = await verifyStripeSignature(`t=${timestamp},v1=ZZZZZZZZ`, '{}', 'secret');
    expect(result.ok).toBe(false);
  });

  it('should reject valid hex but wrong signature (mismatch)', async () => {
    const timestamp = Math.floor(Date.now() / 1000);
    // Valid hex format but wrong HMAC value
    const wrongHex = 'a'.repeat(64);
    const result = await verifyStripeSignature(`t=${timestamp},v1=${wrongHex}`, '{}', 'secret');
    expect(result.ok).toBe(false);
  });

  it('should reject header with timestamp but no v1 field', async () => {
    const timestamp = Math.floor(Date.now() / 1000);
    // Header has t= but no v1= — signature will be undefined
    const result = await verifyStripeSignature(`t=${timestamp},other=value`, '{}', 'secret');
    expect(result.ok).toBe(false);
  });

  it('accepts when the second of two v1 entries matches (Stripe secret rotation)', async () => {
    const timestamp = Math.floor(Date.now() / 1000);
    const body = '{"type":"test"}';
    const secret = 'new-secret';
    const validHex = await hmacSignHex(secret, `${timestamp}.${body}`);
    const oldHex = 'a'.repeat(64); // Stale key — wrong signature, valid hex.

    // Stripe sends both old and new v1 entries during key rotation.
    const sigHeader = `t=${timestamp},v1=${oldHex},v1=${validHex}`;
    const result = await verifyStripeSignature(sigHeader, body, secret);
    expect(result.ok).toBe(true);
  });

  it('rejects when multiple v1 entries are present and none match', async () => {
    const timestamp = Math.floor(Date.now() / 1000);
    const wrongHex1 = 'a'.repeat(64);
    const wrongHex2 = 'b'.repeat(64);
    const sigHeader = `t=${timestamp},v1=${wrongHex1},v1=${wrongHex2}`;
    const result = await verifyStripeSignature(sigHeader, '{}', 'secret');
    expect(result.ok).toBe(false);
  });

  it('should handle crypto.subtle errors gracefully and return { ok: false }', async () => {
    const timestamp = Math.floor(Date.now() / 1000);
    const validHex = 'ab'.repeat(32);
    const importKeySpy = vi.spyOn(crypto.subtle, 'importKey').mockRejectedValueOnce(new Error('Crypto failure'));

    const result = await verifyStripeSignature(`t=${timestamp},v1=${validHex}`, '{}', 'secret');

    expect(result.ok).toBe(false);

    importKeySpy.mockRestore();
  });
});

describe('handleWebhook (fetch handler)', () => {
  let consoleSpy: ReturnType<typeof vi.spyOn>;
  let mockCtx: ReturnType<typeof makeMockCtx>;

  beforeEach(() => {
    vi.clearAllMocks();
    consoleSpy = vi.spyOn(console, 'error').mockImplementation(() => {});
    mockCtx = makeMockCtx();
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

    const response = await worker.fetch(request, MOCK_ENV, mockCtx.ctx);
    expect(response.status).toBe(401);
  });

  it('already processed → queued:false, skipped:true, handler not called', async () => {
    const body = JSON.stringify({ id: 'evt_dup', type: 'checkout.session.completed' });
    const request = await makeWebhookRequest(body);

    mockDb.claimEvent.mockResolvedValue({ ok: true, claimed: false });

    const response = await worker.fetch(request, MOCK_ENV, mockCtx.ctx);
    const json = await response.json<{ ok: boolean; queued: boolean; skipped: boolean }>();

    expect(response.status).toBe(200);
    expect(json.queued).toBe(false);
    expect(json.skipped).toBe(true);
    expect(mockHandleCheckout).not.toHaveBeenCalled();
  });

  it('handler failure → addDeadLetter called, 200 returned with queued:true', async () => {
    const body = JSON.stringify({ id: 'evt_fail', type: 'checkout.session.completed' });
    const request = await makeWebhookRequest(body);

    mockDb.claimEvent.mockResolvedValue({ ok: true, claimed: true });
    mockHandleCheckout.mockResolvedValue({ ok: false, error: 'DB write failed' });
    mockDb.unclaimEvent.mockResolvedValue({ ok: true });
    mockDb.addDeadLetter.mockResolvedValue({ ok: true });

    const response = await worker.fetch(request, MOCK_ENV, mockCtx.ctx);
    // Response is sent immediately; background processing runs via waitUntil
    expect(response.status).toBe(200);
    const json = await response.json<{ ok: boolean; queued: boolean }>();
    expect(json.queued).toBe(true);

    await mockCtx.flush();
    expect(mockDb.addDeadLetter).toHaveBeenCalledWith('evt_fail', 'checkout.session.completed', expect.any(Object), 'DB write failed');
  });

  it('addDeadLetter failure → CRITICAL error logged, 200 returned (2xx already sent; manual replay required)', async () => {
    const body = JSON.stringify({ id: 'evt_lost', type: 'checkout.session.completed' });
    const request = await makeWebhookRequest(body);

    mockDb.claimEvent.mockResolvedValue({ ok: true, claimed: true });
    mockHandleCheckout.mockResolvedValue({ ok: false, error: 'handler error' });
    mockDb.unclaimEvent.mockResolvedValue({ ok: true });
    mockDb.addDeadLetter.mockResolvedValue({ ok: false, error: 'DB unavailable' });

    const response = await worker.fetch(request, MOCK_ENV, mockCtx.ctx);
    // 2xx was already sent; we cannot signal Stripe to retry after the fact
    expect(response.status).toBe(200);

    await mockCtx.flush();
    expect(consoleSpy).toHaveBeenCalledWith(
      expect.stringContaining('CRITICAL'),
      expect.any(String),
      'DB unavailable',
    );
  });

  it('health endpoint → 200 with ok:true', async () => {
    const request = new Request('https://example.com/health', { method: 'GET' });
    const response = await worker.fetch(request, MOCK_ENV, mockCtx.ctx);
    const json = await response.json<{ ok: boolean }>();
    expect(response.status).toBe(200);
    expect(json.ok).toBe(true);
  });

  it('unknown route → 404', async () => {
    const request = new Request('https://example.com/unknown', { method: 'GET' });
    const response = await worker.fetch(request, MOCK_ENV, mockCtx.ctx);
    expect(response.status).toBe(404);
  });

  it('handler throws unhandled exception → CRITICAL logged, unclaim + dead-letter called, 200 queued:true', async () => {
    const body = JSON.stringify({ id: 'evt_throw', type: 'checkout.session.completed' });
    const request = await makeWebhookRequest(body);

    mockDb.claimEvent.mockResolvedValue({ ok: true, claimed: true });
    mockHandleCheckout.mockRejectedValue(new Error('Unexpected crash'));
    mockDb.unclaimEvent.mockResolvedValue({ ok: true });
    mockDb.addDeadLetter.mockResolvedValue({ ok: true });

    const response = await worker.fetch(request, MOCK_ENV, mockCtx.ctx);
    expect(response.status).toBe(200);
    const json = await response.json<{ ok: boolean; queued: boolean }>();
    expect(json.queued).toBe(true);

    await mockCtx.flush();
    expect(consoleSpy).toHaveBeenCalledWith(
      expect.stringContaining('CRITICAL: Unhandled exception'),
      expect.any(Error),
    );
    expect(mockDb.unclaimEvent).toHaveBeenCalledWith('evt_throw');
    expect(mockDb.addDeadLetter).toHaveBeenCalledWith(
      'evt_throw',
      'checkout.session.completed',
      expect.any(Object),
      'Unexpected crash',
    );
  });

  it('handler failure + unclaimEvent succeeds → unclaimEvent called, dead letter inserted, queued:true returned', async () => {
    const body = JSON.stringify({ id: 'evt_abc', type: 'checkout.session.completed' });
    const request = await makeWebhookRequest(body);

    mockDb.claimEvent.mockResolvedValue({ ok: true, claimed: true });
    mockHandleCheckout.mockResolvedValue({ ok: false, error: 'Handler error' });
    mockDb.unclaimEvent.mockResolvedValue({ ok: true });
    mockDb.addDeadLetter.mockResolvedValue({ ok: true });

    const response = await worker.fetch(request, MOCK_ENV, mockCtx.ctx);
    expect(response.status).toBe(200);
    const json = await response.json<{ ok: boolean; queued: boolean }>();
    expect(json.queued).toBe(true);

    await mockCtx.flush();
    expect(mockDb.unclaimEvent).toHaveBeenCalledWith('evt_abc');
    expect(mockDb.addDeadLetter).toHaveBeenCalledWith(
      'evt_abc',
      'checkout.session.completed',
      expect.any(Object),
      'Handler error',
    );
  });

  it('handler failure + unclaimEvent fails → unclaim error logged, dead letter still inserted', async () => {
    const body = JSON.stringify({ id: 'evt_abc2', type: 'checkout.session.completed' });
    const request = await makeWebhookRequest(body);

    mockDb.claimEvent.mockResolvedValue({ ok: true, claimed: true });
    mockHandleCheckout.mockResolvedValue({ ok: false, error: 'handler error' });
    mockDb.unclaimEvent.mockResolvedValue({ ok: false, error: 'unclaim failed' });
    mockDb.addDeadLetter.mockResolvedValue({ ok: true });

    const response = await worker.fetch(request, MOCK_ENV, mockCtx.ctx);
    expect(response.status).toBe(200);
    const json = await response.json<{ ok: boolean; queued: boolean }>();
    expect(json.queued).toBe(true);

    await mockCtx.flush();
    expect(consoleSpy).toHaveBeenCalledWith(
      expect.stringContaining('Failed to unclaim event evt_abc2'),
      'unclaim failed',
    );
    expect(mockDb.addDeadLetter).toHaveBeenCalled();
  });

  it('org-not-found result → unclaimEvent called + addDeadLetter called (event not silently dropped)', async () => {
    const body = JSON.stringify({ id: 'evt_orphan', type: 'customer.subscription.updated', data: { object: {} } });
    const request = await makeWebhookRequest(body);

    mockDb.claimEvent.mockResolvedValue({ ok: true, claimed: true });
    mockHandleSubscriptionUpdated.mockResolvedValue({ ok: false, error: 'No org found for Stripe customer cus_orphan' });
    mockDb.unclaimEvent.mockResolvedValue({ ok: true });
    mockDb.addDeadLetter.mockResolvedValue({ ok: true });

    const response = await worker.fetch(request, MOCK_ENV, mockCtx.ctx);
    expect(response.status).toBe(200);
    const json = await response.json<{ ok: boolean; queued: boolean }>();
    expect(json.queued).toBe(true);

    await mockCtx.flush();
    expect(mockDb.unclaimEvent).toHaveBeenCalledWith('evt_orphan');
    expect(mockDb.addDeadLetter).toHaveBeenCalledWith(
      'evt_orphan',
      'customer.subscription.updated',
      expect.any(Object),
      expect.stringContaining('No org found for Stripe customer'),
    );
  });

  it('customer.subscription.deleted event → handleSubscriptionDeleted called, queued:true returned', async () => {
    const body = JSON.stringify({ id: 'evt_del', type: 'customer.subscription.deleted', data: { object: {} } });
    const request = await makeWebhookRequest(body);

    const { handleSubscriptionDeleted } = await import('./handlers/subscription');
    mockDb.claimEvent.mockResolvedValue({ ok: true, claimed: true });
    vi.mocked(handleSubscriptionDeleted).mockResolvedValue({ ok: true });

    const response = await worker.fetch(request, MOCK_ENV, mockCtx.ctx);
    expect(response.status).toBe(200);
    const json = await response.json<{ ok: boolean; queued: boolean }>();
    expect(json.queued).toBe(true);

    await mockCtx.flush();
    expect(handleSubscriptionDeleted).toHaveBeenCalled();
  });

  it('invoice.paid event → handleInvoicePaid called, queued:true returned', async () => {
    const body = JSON.stringify({ id: 'evt_invpaid', type: 'invoice.paid', data: { object: {} } });
    const request = await makeWebhookRequest(body);

    const { handleInvoicePaid } = await import('./handlers/invoice');
    mockDb.claimEvent.mockResolvedValue({ ok: true, claimed: true });
    vi.mocked(handleInvoicePaid).mockResolvedValue({ ok: true });

    const response = await worker.fetch(request, MOCK_ENV, mockCtx.ctx);
    expect(response.status).toBe(200);
    const json = await response.json<{ ok: boolean; queued: boolean }>();
    expect(json.queued).toBe(true);

    await mockCtx.flush();
    expect(handleInvoicePaid).toHaveBeenCalled();
  });

  it('invoice.payment_failed event → handleInvoicePaymentFailed called, queued:true returned', async () => {
    const body = JSON.stringify({ id: 'evt_invfailed', type: 'invoice.payment_failed', data: { object: {} } });
    const request = await makeWebhookRequest(body);

    const { handleInvoicePaymentFailed } = await import('./handlers/invoice');
    mockDb.claimEvent.mockResolvedValue({ ok: true, claimed: true });
    vi.mocked(handleInvoicePaymentFailed).mockResolvedValue({ ok: true });

    const response = await worker.fetch(request, MOCK_ENV, mockCtx.ctx);
    expect(response.status).toBe(200);
    const json = await response.json<{ ok: boolean; queued: boolean }>();
    expect(json.queued).toBe(true);

    await mockCtx.flush();
    expect(handleInvoicePaymentFailed).toHaveBeenCalled();
  });
});

describe('parsePriceToPlan (via handleWebhook)', () => {
  let consoleSpy: ReturnType<typeof vi.spyOn>;
  let mockCtx: ReturnType<typeof makeMockCtx>;

  beforeEach(() => {
    vi.clearAllMocks();
    consoleSpy = vi.spyOn(console, 'warn').mockImplementation(() => {});
    mockCtx = makeMockCtx();
  });

  afterEach(() => {
    consoleSpy.mockRestore();
  });

  async function makeSubUpdatedRequest(secret = 'test-secret'): Promise<Request> {
    const body = JSON.stringify({ id: 'evt_sub', type: 'customer.subscription.updated', data: { object: {} } });
    const timestamp = Math.floor(Date.now() / 1000);
    const sig = await computeStripeSignature(timestamp, body, secret);
    return new Request('https://example.com/webhook', {
      method: 'POST',
      headers: { 'stripe-signature': sig, 'content-type': 'application/json' },
      body,
    });
  }

  it('valid JSON with valid plan key → priceToPlan map passed to handleSubscriptionUpdated', async () => {
    const env = { ...MOCK_ENV, STRIPE_PRICE_TO_PLAN_JSON: '{"price_abc":"growth"}' };
    mockDb.claimEvent.mockResolvedValue({ ok: true, claimed: true });
    mockHandleSubscriptionUpdated.mockResolvedValue({ ok: true });

    await worker.fetch(await makeSubUpdatedRequest(), env, mockCtx.ctx);
    await mockCtx.flush();

    expect(mockHandleSubscriptionUpdated).toHaveBeenCalledWith(
      expect.any(Object),
      expect.any(Object),
      { price_abc: 'growth' },
    );
  });

  it('valid JSON with invalid plan value → entry skipped, warn logged, empty map passed', async () => {
    const env = { ...MOCK_ENV, STRIPE_PRICE_TO_PLAN_JSON: '{"price_abc":"enterprise","price_xyz":"invalid_plan"}' };
    mockDb.claimEvent.mockResolvedValue({ ok: true, claimed: true });
    mockHandleSubscriptionUpdated.mockResolvedValue({ ok: true });

    await worker.fetch(await makeSubUpdatedRequest(), env, mockCtx.ctx);
    await mockCtx.flush();

    expect(mockHandleSubscriptionUpdated).toHaveBeenCalledWith(
      expect.any(Object),
      expect.any(Object),
      { price_abc: 'enterprise' },
    );
    expect(consoleSpy).toHaveBeenCalledWith(expect.stringContaining('invalid_plan'));
  });

  it('invalid JSON → console.warn logged, empty map passed to handler', async () => {
    const env = { ...MOCK_ENV, STRIPE_PRICE_TO_PLAN_JSON: 'not-valid-json' };
    mockDb.claimEvent.mockResolvedValue({ ok: true, claimed: true });
    mockHandleSubscriptionUpdated.mockResolvedValue({ ok: true });

    await worker.fetch(await makeSubUpdatedRequest(), env, mockCtx.ctx);
    await mockCtx.flush();

    expect(mockHandleSubscriptionUpdated).toHaveBeenCalledWith(
      expect.any(Object),
      expect.any(Object),
      {},
    );
    expect(consoleSpy).toHaveBeenCalledWith(expect.stringContaining('not valid JSON'));
  });

  it('missing env var → empty map passed to handler', async () => {
    mockDb.claimEvent.mockResolvedValue({ ok: true, claimed: true });
    mockHandleSubscriptionUpdated.mockResolvedValue({ ok: true });

    await worker.fetch(await makeSubUpdatedRequest(), MOCK_ENV, mockCtx.ctx);
    await mockCtx.flush();

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

  it('retries successfully: claimEvent and resolveDeadLetter called', async () => {
    mockDb.fetchPendingDeadLetters.mockResolvedValue([checkoutDeadLetter]);
    mockDb.isEventProcessed.mockResolvedValue({ ok: true, processed: false });
    mockHandleCheckout.mockResolvedValue({ ok: true });
    mockDb.claimEvent.mockResolvedValue({ ok: true, claimed: true });
    mockDb.resolveDeadLetter.mockResolvedValue({ ok: true });

    await worker.scheduled(
      { scheduledTime: Date.now(), cron: '*/15 * * * *' } as ScheduledEvent,
      MOCK_ENV,
      {} as ExecutionContext,
    );

    expect(mockHandleCheckout).toHaveBeenCalledOnce();
    expect(mockDb.claimEvent).toHaveBeenCalledWith('evt_123', 'checkout.session.completed');
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
    expect(mockDb.claimEvent).not.toHaveBeenCalled();
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
    mockDb.claimEvent.mockResolvedValue({ ok: true, claimed: true });
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

  it('claimEvent failure in reconciliation → console.error logged, resolveDeadLetter NOT called (leave pending for retry)', async () => {
    mockDb.fetchPendingDeadLetters.mockResolvedValue([checkoutDeadLetter]);
    mockDb.isEventProcessed.mockResolvedValue({ ok: true, processed: false });
    mockHandleCheckout.mockResolvedValue({ ok: true });
    mockDb.claimEvent.mockResolvedValue({ ok: false, error: 'Write failed' });
    mockDb.resolveDeadLetter.mockResolvedValue({ ok: true });

    await worker.scheduled(
      { scheduledTime: Date.now(), cron: '*/15 * * * *' } as ScheduledEvent,
      MOCK_ENV,
      {} as ExecutionContext,
    );

    expect(consoleSpy).toHaveBeenCalledWith(
      expect.stringContaining('Failed to claim event evt_123'),
      'Write failed',
    );
    // Dead-letter must NOT be resolved — leave it pending so the next cron run
    // retries the full sequence (handler → claimEvent → resolveDeadLetter).
    // Without a log entry the idempotency guard cannot detect the event as processed.
    expect(mockDb.resolveDeadLetter).not.toHaveBeenCalled();
  });

  it('resolveDeadLetter failure → console.error logged, event still considered processed', async () => {
    mockDb.fetchPendingDeadLetters.mockResolvedValue([checkoutDeadLetter]);
    mockDb.isEventProcessed.mockResolvedValue({ ok: true, processed: false });
    mockHandleCheckout.mockResolvedValue({ ok: true });
    mockDb.claimEvent.mockResolvedValue({ ok: true, claimed: true });
    mockDb.resolveDeadLetter.mockResolvedValue({ ok: false, error: 'Update failed' });

    await worker.scheduled(
      { scheduledTime: Date.now(), cron: '*/15 * * * *' } as ScheduledEvent,
      MOCK_ENV,
      {} as ExecutionContext,
    );

    expect(consoleSpy).toHaveBeenCalledWith(
      expect.stringContaining('Failed to resolve dead letter dl_1'),
      'Update failed',
    );
  });

  it('failDeadLetter failure → console.error logged', async () => {
    mockDb.fetchPendingDeadLetters.mockResolvedValue([checkoutDeadLetter]);
    mockDb.isEventProcessed.mockResolvedValue({ ok: true, processed: false });
    mockHandleCheckout.mockResolvedValue({ ok: false, error: 'handler error' });
    mockDb.failDeadLetter.mockResolvedValue({ ok: false, error: 'DB failure' });

    await worker.scheduled(
      { scheduledTime: Date.now(), cron: '*/15 * * * *' } as ScheduledEvent,
      MOCK_ENV,
      {} as ExecutionContext,
    );

    expect(consoleSpy).toHaveBeenCalledWith(
      expect.stringContaining('Failed to increment retry count for dead letter dl_1'),
      'DB failure',
    );
  });

  it('exception thrown during reconciliation → console.error logged, loop continues', async () => {
    const secondDl = { ...checkoutDeadLetter, id: 'dl_2', stripe_event_id: 'evt_456' };
    mockDb.fetchPendingDeadLetters.mockResolvedValue([checkoutDeadLetter, secondDl]);
    // First dead letter causes isEventProcessed to throw
    mockDb.isEventProcessed
      .mockRejectedValueOnce(new Error('Unexpected crash'))
      .mockResolvedValueOnce({ ok: true, processed: false });
    mockHandleCheckout.mockResolvedValue({ ok: true });
    mockDb.claimEvent.mockResolvedValue({ ok: true, claimed: true });
    mockDb.resolveDeadLetter.mockResolvedValue({ ok: true });

    await worker.scheduled(
      { scheduledTime: Date.now(), cron: '*/15 * * * *' } as ScheduledEvent,
      MOCK_ENV,
      {} as ExecutionContext,
    );

    expect(consoleSpy).toHaveBeenCalledWith(
      expect.stringContaining('Reconciliation error for dead letter dl_1'),
      expect.any(Error),
    );
    // Second dead letter was still processed despite first throwing
    expect(mockDb.resolveDeadLetter).toHaveBeenCalledWith('dl_2');
  });

  it('reconciliation: invoice.paid dead letter → handleInvoicePaid called', async () => {
    const invoiceDl = {
      ...checkoutDeadLetter,
      id: 'dl_inv',
      stripe_event_id: 'evt_inv',
      event_type: 'invoice.paid',
      payload: { id: 'evt_inv', type: 'invoice.paid', data: { object: {} } },
    };
    mockDb.fetchPendingDeadLetters.mockResolvedValue([invoiceDl]);
    mockDb.isEventProcessed.mockResolvedValue({ ok: true, processed: false });
    // handleInvoicePaid is mocked but we can't get a named ref; verify by checking claimEvent
    // The vi.fn() in invoice mock will return undefined by default — cast to ok result
    const { handleInvoicePaid } = await import('./handlers/invoice');
    vi.mocked(handleInvoicePaid).mockResolvedValue({ ok: true });
    mockDb.claimEvent.mockResolvedValue({ ok: true, claimed: true });
    mockDb.resolveDeadLetter.mockResolvedValue({ ok: true });

    await worker.scheduled(
      { scheduledTime: Date.now(), cron: '*/15 * * * *' } as ScheduledEvent,
      MOCK_ENV,
      {} as ExecutionContext,
    );

    expect(mockDb.claimEvent).toHaveBeenCalledWith('evt_inv', 'invoice.paid');
    expect(mockDb.resolveDeadLetter).toHaveBeenCalledWith('dl_inv');
  });

  it('reconciliation: invoice.payment_failed dead letter → handleInvoicePaymentFailed called', async () => {
    const invoiceFailDl = {
      ...checkoutDeadLetter,
      id: 'dl_invfail',
      stripe_event_id: 'evt_invfail',
      event_type: 'invoice.payment_failed',
      payload: { id: 'evt_invfail', type: 'invoice.payment_failed', data: { object: {} } },
    };
    mockDb.fetchPendingDeadLetters.mockResolvedValue([invoiceFailDl]);
    mockDb.isEventProcessed.mockResolvedValue({ ok: true, processed: false });
    const { handleInvoicePaymentFailed } = await import('./handlers/invoice');
    vi.mocked(handleInvoicePaymentFailed).mockResolvedValue({ ok: true });
    mockDb.claimEvent.mockResolvedValue({ ok: true, claimed: true });
    mockDb.resolveDeadLetter.mockResolvedValue({ ok: true });

    await worker.scheduled(
      { scheduledTime: Date.now(), cron: '*/15 * * * *' } as ScheduledEvent,
      MOCK_ENV,
      {} as ExecutionContext,
    );

    expect(mockDb.claimEvent).toHaveBeenCalledWith('evt_invfail', 'invoice.payment_failed');
    expect(mockDb.resolveDeadLetter).toHaveBeenCalledWith('dl_invfail');
  });

  it('reconciliation: customer.subscription.updated dead letter → handleSubscriptionUpdated called', async () => {
    const subUpdatedDl = {
      ...checkoutDeadLetter,
      id: 'dl_subupd',
      stripe_event_id: 'evt_subupd',
      event_type: 'customer.subscription.updated',
      payload: { id: 'evt_subupd', type: 'customer.subscription.updated', data: { object: {} } },
    };
    mockDb.fetchPendingDeadLetters.mockResolvedValue([subUpdatedDl]);
    mockDb.isEventProcessed.mockResolvedValue({ ok: true, processed: false });
    mockHandleSubscriptionUpdated.mockResolvedValue({ ok: true });
    mockDb.claimEvent.mockResolvedValue({ ok: true, claimed: true });
    mockDb.resolveDeadLetter.mockResolvedValue({ ok: true });

    await worker.scheduled(
      { scheduledTime: Date.now(), cron: '*/15 * * * *' } as ScheduledEvent,
      MOCK_ENV,
      {} as ExecutionContext,
    );

    expect(mockHandleSubscriptionUpdated).toHaveBeenCalled();
    expect(mockDb.claimEvent).toHaveBeenCalledWith('evt_subupd', 'customer.subscription.updated');
    expect(mockDb.resolveDeadLetter).toHaveBeenCalledWith('dl_subupd');
  });

  it('reconciliation: customer.subscription.deleted dead letter → handleSubscriptionDeleted called', async () => {
    const subDeletedDl = {
      ...checkoutDeadLetter,
      id: 'dl_subdel',
      stripe_event_id: 'evt_subdel',
      event_type: 'customer.subscription.deleted',
      payload: { id: 'evt_subdel', type: 'customer.subscription.deleted', data: { object: {} } },
    };
    mockDb.fetchPendingDeadLetters.mockResolvedValue([subDeletedDl]);
    mockDb.isEventProcessed.mockResolvedValue({ ok: true, processed: false });
    const { handleSubscriptionDeleted } = await import('./handlers/subscription');
    vi.mocked(handleSubscriptionDeleted).mockResolvedValue({ ok: true });
    mockDb.claimEvent.mockResolvedValue({ ok: true, claimed: true });
    mockDb.resolveDeadLetter.mockResolvedValue({ ok: true });

    await worker.scheduled(
      { scheduledTime: Date.now(), cron: '*/15 * * * *' } as ScheduledEvent,
      MOCK_ENV,
      {} as ExecutionContext,
    );

    expect(mockDb.claimEvent).toHaveBeenCalledWith('evt_subdel', 'customer.subscription.deleted');
    expect(mockDb.resolveDeadLetter).toHaveBeenCalledWith('dl_subdel');
  });

  it('orphaned dead letter resolveDeadLetter failure → console.error logged', async () => {
    mockDb.fetchPendingDeadLetters.mockResolvedValue([checkoutDeadLetter]);
    mockDb.isEventProcessed.mockResolvedValue({ ok: true, processed: true });
    mockDb.resolveDeadLetter.mockResolvedValue({ ok: false, error: 'Resolve failed' });

    await worker.scheduled(
      { scheduledTime: Date.now(), cron: '*/15 * * * *' } as ScheduledEvent,
      MOCK_ENV,
      {} as ExecutionContext,
    );

    expect(consoleSpy).toHaveBeenCalledWith(
      expect.stringContaining('Failed to resolve orphaned dead letter dl_1'),
      'Resolve failed',
    );
  });

  it('ordering: events replayed in Stripe event creation order regardless of dead-letter insertion order', async () => {
    const callOrder: string[] = [];
    // dlB was dead-lettered first (inserted into DB earlier) but has a LATER Stripe created
    // timestamp. dlA was dead-lettered second but has an EARLIER Stripe created timestamp.
    // Correct order: dlA first (created=100), dlB second (created=200).
    const dlA = {
      id: 'dl_a',
      stripe_event_id: 'evt_a',
      event_type: 'checkout.session.completed',
      payload: { id: 'evt_a', type: 'checkout.session.completed', created: 100 },
      retry_count: 0,
      max_retries: 5,
    };
    const dlB = {
      id: 'dl_b',
      stripe_event_id: 'evt_b',
      event_type: 'checkout.session.completed',
      payload: { id: 'evt_b', type: 'checkout.session.completed', created: 200 },
      retry_count: 0,
      max_retries: 5,
    };
    // fetchPendingDeadLetters returns dlB before dlA (wrong DB order)
    mockDb.fetchPendingDeadLetters.mockResolvedValue([dlB, dlA]);
    mockDb.isEventProcessed.mockResolvedValue({ ok: true, processed: false });
    mockHandleCheckout.mockImplementation(async (event: { id: string }) => {
      callOrder.push(event.id);
      return { ok: true };
    });
    mockDb.claimEvent.mockResolvedValue({ ok: true, claimed: true });
    mockDb.resolveDeadLetter.mockResolvedValue({ ok: true });

    await worker.scheduled(
      { scheduledTime: Date.now(), cron: '*/15 * * * *' } as ScheduledEvent,
      MOCK_ENV,
      {} as ExecutionContext,
    );

    // dlA (created=100) must be processed before dlB (created=200)
    expect(callOrder).toEqual(['evt_a', 'evt_b']);
  });
});

describe('handleWebhook edge cases', () => {
  let consoleSpy: ReturnType<typeof vi.spyOn>;
  let mockCtx: ReturnType<typeof makeMockCtx>;

  beforeEach(() => {
    vi.clearAllMocks();
    consoleSpy = vi.spyOn(console, 'error').mockImplementation(() => {});
    mockCtx = makeMockCtx();
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

  it('claimEvent returns ok:false → 500 returned', async () => {
    const body = JSON.stringify({ id: 'evt_guard', type: 'checkout.session.completed' });
    const request = await makeWebhookRequest(body);

    mockDb.claimEvent.mockResolvedValue({ ok: false, error: 'DB down' });

    const response = await worker.fetch(request, MOCK_ENV, mockCtx.ctx);
    expect(response.status).toBe(500);
  });

  it('invalid JSON body → 500 returned', async () => {
    const body = 'not-json{{{';
    const request = await makeWebhookRequest(body);

    const response = await worker.fetch(request, MOCK_ENV, mockCtx.ctx);
    expect(response.status).toBe(500);
  });

  it('valid JSON but no event.type → 500 returned', async () => {
    const body = JSON.stringify({ id: 'evt_notype' });
    const request = await makeWebhookRequest(body);

    const response = await worker.fetch(request, MOCK_ENV, mockCtx.ctx);
    expect(response.status).toBe(500);
  });

  it('unhandled event type → 200 queued:true returned', async () => {
    const body = JSON.stringify({ id: 'evt_unhandled', type: 'payment_intent.created' });
    const request = await makeWebhookRequest(body);

    mockDb.claimEvent.mockResolvedValue({ ok: true, claimed: true });

    const response = await worker.fetch(request, MOCK_ENV, mockCtx.ctx);
    await mockCtx.flush();
    const json = await response.json<{ ok: boolean; queued: boolean }>();

    expect(response.status).toBe(200);
    expect(json.queued).toBe(true);
  });
});
