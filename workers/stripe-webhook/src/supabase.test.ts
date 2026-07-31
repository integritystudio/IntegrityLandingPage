import { describe, it, expect, vi, beforeEach, afterEach } from 'vitest';
import { createSupabaseAdmin } from './supabase';
import { DEAD_LETTER_MAX_RETRIES } from '../../constants';
import {
  createSupabaseFetchStub,
  createdRows,
  httpError,
  noContent,
  okRows,
  updatedRows,
  TEST_SERVICE_ROLE_KEY,
  TEST_SUPABASE_URL,
  type RecordedRequest,
  type RouteResponder,
  type SupabaseFetchStub,
} from '../../lib/test-helpers/supabase-fetch-stub';

/**
 * These tests drive a REAL Supabase REST client (`createSupabaseAdmin` builds one
 * internally) over a stubbed fetch transport. Mocking the client would hide the
 * only thing this module does — mapping domain operations onto PostgREST calls —
 * so every assertion below is against the actual wire format: verbs, tables,
 * filter serialization, request bodies and `Prefer` headers.
 */

const DEAD_LETTERS_TABLE = 'webhook_dead_letters';
const EVENTS_LOG_TABLE = 'webhook_events_log';
const ORGANIZATIONS_TABLE = 'organizations';
const SUBSCRIPTIONS_TABLE = 'subscriptions';

const RETURN_REPRESENTATION = 'return=representation';
const RETURN_MINIMAL = 'return=minimal';
const MERGE_DUPLICATES = 'resolution=merge-duplicates,return=representation';
const IGNORE_DUPLICATES = 'resolution=ignore-duplicates,return=representation';

const DEAD_LETTER_SELECT = 'id, stripe_event_id, event_type, payload, retry_count, max_retries';

/** Installs the stub as global fetch and returns it for assertions. */
function stubSupabase(routes: Record<string, RouteResponder>): SupabaseFetchStub {
  const stub = createSupabaseFetchStub(routes);
  vi.stubGlobal('fetch', stub.fetch);
  return stub;
}

function makeAdmin(): ReturnType<typeof createSupabaseAdmin> {
  return createSupabaseAdmin(TEST_SUPABASE_URL, TEST_SERVICE_ROLE_KEY);
}

/** Body of an update/rpc-style request, which the client sends as a bare object. */
function objectBody(request: RecordedRequest): Record<string, unknown> {
  return request.body as Record<string, unknown>;
}

/** Body of an insert/upsert, which the client always wraps in an array. */
function rowsBody(request: RecordedRequest): Array<Record<string, unknown>> {
  return request.body as Array<Record<string, unknown>>;
}

afterEach(() => {
  vi.unstubAllGlobals();
});

describe('fetchPendingDeadLetters', () => {
  let db: ReturnType<typeof createSupabaseAdmin>;
  let consoleSpy: ReturnType<typeof vi.spyOn>;

  beforeEach(() => {
    db = makeAdmin();
    consoleSpy = vi.spyOn(console, 'error').mockImplementation(() => {});
  });

  afterEach(() => {
    consoleSpy.mockRestore();
  });

  it('DB error → console.error logged, empty array returned', async () => {
    stubSupabase({ [`GET ${DEAD_LETTERS_TABLE}`]: httpError(500, 'Connection timeout') });

    const result = await db.fetchPendingDeadLetters();

    expect(result).toEqual([]);
    expect(consoleSpy).toHaveBeenCalledWith(
      'fetchPendingDeadLetters DB error:',
      'HTTP 500: Connection timeout',
    );
  });

  it('non-array data → filtered out, returning empty array', async () => {
    // PostgREST always answers a select with a JSON array, but the client wraps
    // any non-array body in one, so a malformed null response surfaces as [null].
    // fetchPendingDeadLetters filters non-object entries so the retry loop
    // never receives a phantom dead letter.
    stubSupabase({
      [`GET ${DEAD_LETTERS_TABLE}`]: () =>
        new Response('null', { status: 200, headers: { 'content-type': 'application/json' } }),
    });

    const result = await db.fetchPendingDeadLetters();

    expect(result).toEqual([]);
  });

  it('empty result set → returns empty array without error', async () => {
    stubSupabase({ [`GET ${DEAD_LETTERS_TABLE}`]: okRows([]) });

    const result = await db.fetchPendingDeadLetters();

    expect(result).toEqual([]);
  });

  it('array data → returns the array of dead letters', async () => {
    const deadLetters = [
      { id: 'dl-1', stripe_event_id: 'evt_1', event_type: 'checkout.session.completed', payload: {}, retry_count: 0, max_retries: 5 },
    ];
    stubSupabase({ [`GET ${DEAD_LETTERS_TABLE}`]: okRows(deadLetters) });

    const result = await db.fetchPendingDeadLetters();

    expect(result).toEqual(deadLetters);
  });

  it('passes custom limit to the query', async () => {
    const stub = stubSupabase({ [`GET ${DEAD_LETTERS_TABLE}`]: okRows([]) });

    await db.fetchPendingDeadLetters(10);

    expect(stub.find('GET', DEAD_LETTERS_TABLE)!.url.searchParams.get('limit')).toBe('10');
  });

  it('sends select, ordering and all three retry filters on the wire', async () => {
    vi.useFakeTimers();
    vi.setSystemTime(new Date('2026-01-01T00:00:00.000Z'));
    try {
      const stub = stubSupabase({ [`GET ${DEAD_LETTERS_TABLE}`]: okRows([]) });

      await db.fetchPendingDeadLetters();

      const params = stub.find('GET', DEAD_LETTERS_TABLE)!.url.searchParams;
      expect(params.get('select')).toBe(DEAD_LETTER_SELECT);
      // getAll, not get: a filter that is dropped or overwritten during
      // serialization silently widens the query, so assert the full multiset.
      expect(params.getAll('status')).toEqual(['eq.pending']);
      expect(params.getAll('next_retry_at')).toEqual(['lte.2026-01-01T00:00:00.000Z']);
      expect(params.getAll('retry_count')).toEqual([`lt.${DEAD_LETTER_MAX_RETRIES}`]);
      expect(params.get('order')).toBe('created_at.asc');
      expect(params.get('limit')).toBe('50');
    } finally {
      vi.useRealTimers();
    }
  });
});

describe('isEventProcessed', () => {
  let db: ReturnType<typeof createSupabaseAdmin>;

  beforeEach(() => {
    db = makeAdmin();
  });

  it('returns { ok: true, processed: true } when event exists in log', async () => {
    const stub = stubSupabase({ [`GET ${EVENTS_LOG_TABLE}`]: okRows([{ id: 'evt_123' }]) });

    const result = await db.isEventProcessed('evt_123');

    expect(result).toEqual({ ok: true, processed: true });
    const params = stub.find('GET', EVENTS_LOG_TABLE)!.url.searchParams;
    expect(params.get('select')).toBe('id');
    expect(params.getAll('stripe_event_id')).toEqual(['eq.evt_123']);
    expect(params.get('limit')).toBe('1');
  });

  it('returns { ok: true, processed: false } when event not in log', async () => {
    stubSupabase({ [`GET ${EVENTS_LOG_TABLE}`]: okRows([]) });

    const result = await db.isEventProcessed('evt_456');

    expect(result).toEqual({ ok: true, processed: false });
  });

  it('returns { ok: false, error } on DB query failure', async () => {
    stubSupabase({ [`GET ${EVENTS_LOG_TABLE}`]: httpError(500, 'Connection timeout') });

    const result = await db.isEventProcessed('evt_789');

    expect(result).toEqual({ ok: false, error: 'HTTP 500: Connection timeout' });
  });
});

// ---------------------------------------------------------------------------
// linkStripeCustomer
// ---------------------------------------------------------------------------

describe('linkStripeCustomer', () => {
  let db: ReturnType<typeof createSupabaseAdmin>;

  beforeEach(() => {
    db = makeAdmin();
  });

  it('returns { ok: true } and updates organizations table', async () => {
    const stub = stubSupabase({
      [`PATCH ${ORGANIZATIONS_TABLE}`]: updatedRows([{ id: 'org-1', stripe_customer_id: 'cus_123' }]),
    });

    const result = await db.linkStripeCustomer('org-1', 'cus_123');

    expect(result).toEqual({ ok: true });
    const patch = stub.find('PATCH', ORGANIZATIONS_TABLE)!;
    expect(patch.body).toEqual({ stripe_customer_id: 'cus_123' });
    expect(patch.url.searchParams.getAll('id')).toEqual(['eq.org-1']);
    expect(patch.headers['prefer']).toBe(RETURN_REPRESENTATION);
  });

  it('authenticates every call with the service role key', async () => {
    const stub = stubSupabase({ [`PATCH ${ORGANIZATIONS_TABLE}`]: updatedRows([]) });

    await db.linkStripeCustomer('org-1', 'cus_123');

    const patch = stub.find('PATCH', ORGANIZATIONS_TABLE)!;
    expect(patch.headers['authorization']).toBe(`Bearer ${TEST_SERVICE_ROLE_KEY}`);
    expect(patch.headers['apikey']).toBe(TEST_SERVICE_ROLE_KEY);
    expect(patch.headers['content-type']).toBe('application/json');
    expect(patch.url.origin).toBe(new URL(TEST_SUPABASE_URL).origin);
  });

  it('returns { ok: false, error } on DB failure', async () => {
    stubSupabase({ [`PATCH ${ORGANIZATIONS_TABLE}`]: httpError(500, 'Connection timeout') });

    const result = await db.linkStripeCustomer('org-1', 'cus_123');

    expect(result).toEqual({ ok: false, error: 'HTTP 500: Connection timeout' });
  });

  it('returns { ok: false, error } when the DB failure carries no message body', async () => {
    // The `?? 'Unknown error'` fallback in toVoidResult is unreachable against a
    // real client: extractHttpError always produces an `HTTP <status>: ` prefix,
    // so a bodyless failure still surfaces a non-empty error string.
    stubSupabase({ [`PATCH ${ORGANIZATIONS_TABLE}`]: httpError(500, '') });

    const result = await db.linkStripeCustomer('org-1', 'cus_123');

    expect(result).toEqual({ ok: false, error: 'HTTP 500: ' });
  });
});

// ---------------------------------------------------------------------------
// upsertSubscription
// ---------------------------------------------------------------------------

describe('upsertSubscription', () => {
  let db: ReturnType<typeof createSupabaseAdmin>;

  beforeEach(() => {
    db = makeAdmin();
  });

  /** Soft-delete step succeeds by default; callers override the POST route. */
  const subscriptionRoutes = (
    overrides: Record<string, RouteResponder> = {},
  ): Record<string, RouteResponder> => ({
    [`PATCH ${SUBSCRIPTIONS_TABLE}`]: updatedRows([]),
    [`POST ${SUBSCRIPTIONS_TABLE}`]: createdRows([{ id: 'sub-row-1' }]),
    ...overrides,
  });

  it('returns { ok: true } and calls upsert with correct conflict key', async () => {
    const stub = stubSupabase(subscriptionRoutes());

    const result = await db.upsertSubscription('org-1', 'sub_abc', 'price_xyz', 'active');

    expect(result).toEqual({ ok: true });
    const post = stub.find('POST', SUBSCRIPTIONS_TABLE)!;
    // Must name a column set that a unique index actually covers. This was
    // 'organization_id,stripe_subscription_id', for which no index exists — Postgres
    // requires one matching the conflict target exactly, so every real
    // customer.subscription.updated event failed with 42P10 and dead-lettered.
    // subscriptions_organization_id_key (migration 20260731000000) covers this target.
    expect(post.url.searchParams.get('on_conflict')).toBe('organization_id');
    expect(post.headers['prefer']).toBe(MERGE_DUPLICATES);
    expect(rowsBody(post)).toEqual([
      expect.objectContaining({
        organization_id: 'org-1',
        stripe_subscription_id: 'sub_abc',
        stripe_price_id: 'price_xyz',
        status: 'active',
      }),
    ]);
  });

  it('stamps created_at and updated_at with the same timestamp as the soft-delete', async () => {
    const stub = stubSupabase(subscriptionRoutes());

    await db.upsertSubscription('org-1', 'sub_abc', 'price_xyz', 'active');

    const cancelled = objectBody(stub.find('PATCH', SUBSCRIPTIONS_TABLE)!);
    const [row] = rowsBody(stub.find('POST', SUBSCRIPTIONS_TABLE)!);
    expect(row.created_at).toBe(row.updated_at);
    expect(cancelled.updated_at).toBe(row.updated_at);
  });

  it('upserts with null price_id for stub rows from checkout handler', async () => {
    const stub = stubSupabase(subscriptionRoutes());

    const result = await db.upsertSubscription('org-1', 'sub_abc', null, 'active');

    expect(result).toEqual({ ok: true });
    // A dropped null would silently preserve the previous price, so assert the
    // key is present on the wire and explicitly null.
    const [row] = rowsBody(stub.find('POST', SUBSCRIPTIONS_TABLE)!);
    expect(row).toHaveProperty('stripe_price_id', null);
  });

  it('returns { ok: false, error } on DB failure', async () => {
    stubSupabase(subscriptionRoutes({
      [`POST ${SUBSCRIPTIONS_TABLE}`]: httpError(409, 'Duplicate key violation'),
    }));

    const result = await db.upsertSubscription('org-1', 'sub_abc', 'price_xyz', 'active');

    expect(result).toEqual({ ok: false, error: 'HTTP 409: Duplicate key violation' });
  });

  it('soft-deletes prior subscriptions with a different ID before upsert', async () => {
    const stub = stubSupabase(subscriptionRoutes());

    await db.upsertSubscription('org-1', 'sub_new', 'price_xyz', 'active');

    const patch = stub.find('PATCH', SUBSCRIPTIONS_TABLE)!;
    expect(objectBody(patch)).toEqual(expect.objectContaining({ status: 'canceled' }));
    const params = patch.url.searchParams;
    expect(params.getAll('organization_id')).toEqual(['eq.org-1']);
    expect(params.getAll('stripe_subscription_id')).toEqual(['neq.sub_new']);
    expect(params.getAll('status')).toEqual(['neq.canceled']);
    // The cancel must be scoped before the upsert lands.
    expect(stub.requests.indexOf(patch)).toBeLessThan(
      stub.requests.indexOf(stub.find('POST', SUBSCRIPTIONS_TABLE)!),
    );
  });

  it('returns { ok: false } when soft-delete update fails', async () => {
    const stub = stubSupabase(subscriptionRoutes({
      [`PATCH ${SUBSCRIPTIONS_TABLE}`]: httpError(500, 'DB connection error'),
    }));

    const result = await db.upsertSubscription('org-1', 'sub_new', 'price_xyz', 'active');

    expect(result).toEqual({ ok: false, error: 'HTTP 500: DB connection error' });
    expect(stub.findAll('POST', SUBSCRIPTIONS_TABLE)).toHaveLength(0);
  });
});

// ---------------------------------------------------------------------------
// updateOrgBillingStatus
// ---------------------------------------------------------------------------

describe('updateOrgBillingStatus', () => {
  let db: ReturnType<typeof createSupabaseAdmin>;

  beforeEach(() => {
    db = makeAdmin();
  });

  it('updates billing_status only when planKey and bumpQuotaVersion omitted', async () => {
    const stub = stubSupabase({ [`PATCH ${ORGANIZATIONS_TABLE}`]: updatedRows([{ id: 'org-1' }]) });

    await db.updateOrgBillingStatus('org-1', 'active');

    const patch = stub.find('PATCH', ORGANIZATIONS_TABLE)!;
    expect(patch.body).toEqual({ billing_status: 'active' });
    expect(patch.url.searchParams.getAll('id')).toEqual(['eq.org-1']);
  });

  it('includes current_plan when planKey provided', async () => {
    const stub = stubSupabase({ [`PATCH ${ORGANIZATIONS_TABLE}`]: updatedRows([{ id: 'org-1' }]) });

    await db.updateOrgBillingStatus('org-1', 'active', 'growth');

    const patch = stub.find('PATCH', ORGANIZATIONS_TABLE)!;
    expect(patch.body).toEqual(
      expect.objectContaining({ billing_status: 'active', current_plan: 'growth' }),
    );
    expect(patch.url.searchParams.getAll('id')).toEqual(['eq.org-1']);
  });

  it('includes numeric quota_version when bumpQuotaVersion is true', async () => {
    const stub = stubSupabase({ [`PATCH ${ORGANIZATIONS_TABLE}`]: updatedRows([{ id: 'org-1' }]) });

    await db.updateOrgBillingStatus('org-1', 'active', undefined, true);

    const patch = stub.find('PATCH', ORGANIZATIONS_TABLE)!;
    expect(patch.body).toEqual(expect.objectContaining({ quota_version: expect.any(Number) }));
    expect(patch.url.searchParams.getAll('id')).toEqual(['eq.org-1']);
  });

  it('does not include quota_version when bumpQuotaVersion is false', async () => {
    const stub = stubSupabase({ [`PATCH ${ORGANIZATIONS_TABLE}`]: updatedRows([{ id: 'org-1' }]) });

    await db.updateOrgBillingStatus('org-1', 'past_due', undefined, false);

    expect(objectBody(stub.find('PATCH', ORGANIZATIONS_TABLE)!)).not.toHaveProperty('quota_version');
  });

  it('returns { ok: false, error } on DB failure', async () => {
    stubSupabase({ [`PATCH ${ORGANIZATIONS_TABLE}`]: httpError(404, 'Row not found') });

    const result = await db.updateOrgBillingStatus('org-1', 'inactive');

    expect(result).toEqual({ ok: false, error: 'HTTP 404: Row not found' });
  });
});

// ---------------------------------------------------------------------------
// addDeadLetter
// ---------------------------------------------------------------------------

describe('addDeadLetter', () => {
  let db: ReturnType<typeof createSupabaseAdmin>;

  beforeEach(() => {
    vi.useFakeTimers();
    db = makeAdmin();
  });

  afterEach(() => {
    vi.useRealTimers();
  });

  it('inserts with correct fields and next_retry_at 60s in future', async () => {
    vi.setSystemTime(new Date('2026-01-01T00:00:00.000Z'));
    const stub = stubSupabase({ [`POST ${DEAD_LETTERS_TABLE}`]: createdRows([{ id: 'dl-1' }]) });

    const result = await db.addDeadLetter(
      'evt_123',
      'checkout.session.completed',
      { id: 'evt_123' },
      'parse error',
    );

    expect(result).toEqual({ ok: true });
    const insert = stub.find('POST', DEAD_LETTERS_TABLE)!;
    expect(rowsBody(insert)).toEqual([
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
    ]);
  });

  it('requests the representation via the Prefer header, not a query param', async () => {
    const stub = stubSupabase({ [`POST ${DEAD_LETTERS_TABLE}`]: createdRows([{ id: 'dl-1' }]) });

    await db.addDeadLetter('evt_123', 'checkout.session.completed', {}, 'err');

    const insert = stub.find('POST', DEAD_LETTERS_TABLE)!;
    expect(insert.headers['prefer']).toBe(RETURN_REPRESENTATION);
    expect(insert.url.searchParams.has('returning')).toBe(false);
    expect([...insert.url.searchParams.keys()]).toEqual([]);
  });

  it('returns { ok: false, error } on DB failure', async () => {
    stubSupabase({ [`POST ${DEAD_LETTERS_TABLE}`]: httpError(500, 'Insert failed') });

    const result = await db.addDeadLetter('evt_123', 'checkout.session.completed', {}, 'err');

    expect(result).toEqual({ ok: false, error: 'HTTP 500: Insert failed' });
  });
});

// ---------------------------------------------------------------------------
// failDeadLetter
// ---------------------------------------------------------------------------

describe('failDeadLetter', () => {
  let db: ReturnType<typeof createSupabaseAdmin>;

  beforeEach(() => {
    vi.useFakeTimers();
    db = makeAdmin();
  });

  afterEach(() => {
    vi.useRealTimers();
  });

  it('increments count, stays pending, and sets next_retry_at when below maxRetries', async () => {
    vi.setSystemTime(new Date('2026-01-01T00:00:00.000Z'));
    const stub = stubSupabase({ [`PATCH ${DEAD_LETTERS_TABLE}`]: updatedRows([{ id: 'dl-1' }]) });

    await db.failDeadLetter('dl-1', 1, 5, 'transient error');

    // next_retry_at = now + 2^1 * 60_000ms = +2 min
    const patch = stub.find('PATCH', DEAD_LETTERS_TABLE)!;
    expect(patch.body).toEqual(
      expect.objectContaining({
        retry_count: 2,
        status: 'pending',
        next_retry_at: '2026-01-01T00:02:00.000Z',
        error_message: 'transient error',
      }),
    );
    expect(patch.url.searchParams.getAll('id')).toEqual(['eq.dl-1']);
  });

  it('sets status to abandoned and omits next_retry_at when newCount reaches maxRetries', async () => {
    const stub = stubSupabase({ [`PATCH ${DEAD_LETTERS_TABLE}`]: updatedRows([{ id: 'dl-1' }]) });

    await db.failDeadLetter('dl-1', 4, 5, 'final error');

    const patch = stub.find('PATCH', DEAD_LETTERS_TABLE)!;
    const updates = objectBody(patch);
    expect(patch.table).toBe(DEAD_LETTERS_TABLE);
    expect(patch.url.searchParams.getAll('id')).toEqual(['eq.dl-1']);
    expect(updates.retry_count).toBe(5);
    expect(updates.status).toBe('abandoned');
    expect(updates).not.toHaveProperty('next_retry_at');
  });

  it('returns { ok: false, error } on DB failure', async () => {
    stubSupabase({ [`PATCH ${DEAD_LETTERS_TABLE}`]: httpError(500, 'Update failed') });

    const result = await db.failDeadLetter('dl-1', 0, 5, 'err');

    expect(result).toEqual({ ok: false, error: 'HTTP 500: Update failed' });
  });
});

// ---------------------------------------------------------------------------
// resolveDeadLetter
// ---------------------------------------------------------------------------

describe('resolveDeadLetter', () => {
  let db: ReturnType<typeof createSupabaseAdmin>;

  beforeEach(() => {
    db = makeAdmin();
  });

  it('updates status to resolved and returns { ok: true }', async () => {
    const stub = stubSupabase({ [`PATCH ${DEAD_LETTERS_TABLE}`]: updatedRows([{ id: 'dl-1' }]) });

    const result = await db.resolveDeadLetter('dl-1');

    expect(result).toEqual({ ok: true });
    const patch = stub.find('PATCH', DEAD_LETTERS_TABLE)!;
    expect(patch.body).toEqual(expect.objectContaining({ status: 'resolved' }));
    expect(objectBody(patch).resolved_at).toEqual(expect.any(String));
    expect(patch.url.searchParams.getAll('id')).toEqual(['eq.dl-1']);
  });

  it('returns { ok: false, error } on DB failure', async () => {
    stubSupabase({ [`PATCH ${DEAD_LETTERS_TABLE}`]: httpError(500, 'Update failed') });

    const result = await db.resolveDeadLetter('dl-1');

    expect(result).toEqual({ ok: false, error: 'HTTP 500: Update failed' });
  });
});

// ---------------------------------------------------------------------------
// abandonDeadLetter
// ---------------------------------------------------------------------------

describe('abandonDeadLetter', () => {
  let db: ReturnType<typeof createSupabaseAdmin>;

  beforeEach(() => {
    db = makeAdmin();
  });

  it('updates status to abandoned and returns { ok: true }', async () => {
    const stub = stubSupabase({ [`PATCH ${DEAD_LETTERS_TABLE}`]: updatedRows([{ id: 'dl-1' }]) });

    const result = await db.abandonDeadLetter('dl-1');

    expect(result).toEqual({ ok: true });
    const patch = stub.find('PATCH', DEAD_LETTERS_TABLE)!;
    expect(patch.body).toEqual(expect.objectContaining({ status: 'abandoned' }));
    expect(patch.url.searchParams.getAll('id')).toEqual(['eq.dl-1']);
  });

  it('returns { ok: false, error } on DB failure', async () => {
    stubSupabase({ [`PATCH ${DEAD_LETTERS_TABLE}`]: httpError(500, 'Update failed') });

    const result = await db.abandonDeadLetter('dl-1');

    expect(result).toEqual({ ok: false, error: 'HTTP 500: Update failed' });
  });
});

// ---------------------------------------------------------------------------
// findOrgByStripeCustomerId
// ---------------------------------------------------------------------------

describe('findOrgByStripeCustomerId', () => {
  let db: ReturnType<typeof createSupabaseAdmin>;

  beforeEach(() => {
    db = makeAdmin();
  });

  it('returns { ok: true, orgId } when org found', async () => {
    const stub = stubSupabase({ [`GET ${ORGANIZATIONS_TABLE}`]: okRows([{ id: 'org-1' }]) });

    const result = await db.findOrgByStripeCustomerId('cus_123');

    expect(result).toEqual({ ok: true, orgId: 'org-1' });
    const params = stub.find('GET', ORGANIZATIONS_TABLE)!.url.searchParams;
    expect(params.get('select')).toBe('id');
    expect(params.getAll('stripe_customer_id')).toEqual(['eq.cus_123']);
    expect(params.get('limit')).toBe('1');
  });

  it('returns { ok: true, orgId: null } when no org found', async () => {
    stubSupabase({ [`GET ${ORGANIZATIONS_TABLE}`]: okRows([]) });

    const result = await db.findOrgByStripeCustomerId('cus_unknown');

    expect(result).toEqual({ ok: true, orgId: null });
  });

  it('returns { ok: false, error } on DB failure', async () => {
    stubSupabase({ [`GET ${ORGANIZATIONS_TABLE}`]: httpError(500, 'Connection timeout') });

    const result = await db.findOrgByStripeCustomerId('cus_123');

    expect(result).toEqual({ ok: false, error: 'HTTP 500: Connection timeout' });
  });
});

// ---------------------------------------------------------------------------
// claimEvent
// ---------------------------------------------------------------------------

describe('claimEvent', () => {
  let db: ReturnType<typeof createSupabaseAdmin>;

  beforeEach(() => {
    db = makeAdmin();
  });

  it('returns { ok: true, claimed: true } when row is newly inserted', async () => {
    const stub = stubSupabase({ [`POST ${EVENTS_LOG_TABLE}`]: createdRows([{ id: 'row_1' }]) });

    const result = await db.claimEvent('evt_123', 'checkout.session.completed');

    expect(result).toEqual({ ok: true, claimed: true });
    const post = stub.find('POST', EVENTS_LOG_TABLE)!;
    // The claim is only atomic if ON CONFLICT DO NOTHING actually reaches
    // PostgREST — that lives entirely in the Prefer header and on_conflict param.
    expect(post.headers['prefer']).toBe(IGNORE_DUPLICATES);
    expect(post.url.searchParams.get('on_conflict')).toBe('stripe_event_id');
    expect(rowsBody(post)).toEqual([
      expect.objectContaining({
        stripe_event_id: 'evt_123',
        event_type: 'checkout.session.completed',
        processed_at: expect.any(String),
      }),
    ]);
  });

  it('returns { ok: true, claimed: false } when row already exists (duplicate)', async () => {
    // PostgREST answers an ignored duplicate with 201 and an empty row array.
    stubSupabase({ [`POST ${EVENTS_LOG_TABLE}`]: createdRows([]) });

    const result = await db.claimEvent('evt_123', 'invoice.paid');

    expect(result).toEqual({ ok: true, claimed: false });
  });

  it('returns { ok: false, error } on DB failure', async () => {
    stubSupabase({ [`POST ${EVENTS_LOG_TABLE}`]: httpError(500, 'Insert failed') });

    const result = await db.claimEvent('evt_123', 'invoice.paid');

    expect(result).toEqual({ ok: false, error: 'HTTP 500: Insert failed' });
  });
});

// ---------------------------------------------------------------------------
// unclaimEvent
// ---------------------------------------------------------------------------

describe('unclaimEvent', () => {
  let db: ReturnType<typeof createSupabaseAdmin>;

  beforeEach(() => {
    db = makeAdmin();
  });

  it('deletes by stripe_event_id and returns { ok: true }', async () => {
    const stub = stubSupabase({ [`DELETE ${EVENTS_LOG_TABLE}`]: noContent() });

    const result = await db.unclaimEvent('evt_123');

    expect(result).toEqual({ ok: true });
    const del = stub.find('DELETE', EVENTS_LOG_TABLE)!;
    // An unfiltered DELETE would wipe the whole idempotency log.
    expect([...del.url.searchParams.keys()]).toEqual(['stripe_event_id']);
    expect(del.url.searchParams.getAll('stripe_event_id')).toEqual(['eq.evt_123']);
    expect(del.headers['prefer']).toBe(RETURN_MINIMAL);
    expect(del.body).toBeUndefined();
  });

  it('treats a 200 delete response as success', async () => {
    stubSupabase({ [`DELETE ${EVENTS_LOG_TABLE}`]: okRows([{ id: 'row_1' }]) });

    const result = await db.unclaimEvent('evt_123');

    expect(result).toEqual({ ok: true });
  });

  it('returns { ok: false, error } on DB failure', async () => {
    stubSupabase({ [`DELETE ${EVENTS_LOG_TABLE}`]: httpError(500, 'Delete failed') });

    const result = await db.unclaimEvent('evt_123');

    expect(result).toEqual({ ok: false, error: 'HTTP 500: Delete failed' });
  });
});
