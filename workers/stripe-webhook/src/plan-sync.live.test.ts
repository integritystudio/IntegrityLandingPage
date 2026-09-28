/**
 * Live end-to-end test: a Stripe subscription change reaches the org's plan (CR38).
 *
 * Drives the whole path with real services, nothing mocked: the Stripe sandbox
 * emits `customer.subscription.updated`, Stripe delivers it to the registered
 * test-mode endpoint (`stripe-webhook-dev`), and the Worker writes the org row
 * in the dev Supabase project. CR38 was a no-op in production for months
 * because `STRIPE_PRICE_TO_PLAN_JSON` was unbound and every unit test passed
 * regardless — only a run through the deployed Worker can see that.
 *
 * Each run creates its own fixture and removes it: a sandbox customer on
 * Stripe's test card, a personal org linked to it, and a growth subscription.
 * Cleanup deletes the customer (which cancels the subscription), waits for the
 * resulting `customer.subscription.deleted` to land, then deletes the org —
 * deleting the org first would make the Worker dead-letter that event.
 *
 * Required env (injected by Doppler `dev`):
 *   STRIPE_SECRET_KEY — the sandbox key; a live-mode key is refused.
 *   SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY — the dev project; any other is refused.
 * Precondition: `stripe-webhook-dev` has `STRIPE_PRICE_TO_PLAN_JSON` mapping
 * SANDBOX_GROWTH_PRICE_ID to growth (checked first, so a missing binding fails
 * with that message rather than as a plan-sync timeout).
 *
 * Run via: npm run test:live
 */

import { afterEach, beforeEach, describe, expect, it } from 'vitest';

// This worker's tsconfig loads only @cloudflare/workers-types, but the file runs
// under vitest's node environment where process.env is populated by Doppler.
declare const process: { env: Record<string, string | undefined> };

const STRIPE_API_BASE = 'https://api.stripe.com/v1';
/** The Worker Stripe's test-mode endpoint delivers to; Stripe, not this test, picks the target. */
const DEV_WORKER_HEALTH_URL = 'https://stripe-webhook-dev.alyshia-b38.workers.dev/health';
/** `integritystudio-dev`. The fixture writes rows, so any other project is refused. */
const DEV_SUPABASE_PROJECT_REF = 'tumhmtshahktumhqqamk';
const TEST_MODE_KEY_PREFIXES = ['sk_test_', 'rk_test_'];
/** Stripe's reusable test card; attaches without a real payment method. */
const STRIPE_TEST_PAYMENT_METHOD = 'pm_card_visa';
/** The sandbox's $79/month growth price, mapped to growth in stripe-webhook-dev's STRIPE_PRICE_TO_PLAN_JSON. */
const SANDBOX_GROWTH_PRICE_ID = 'price_1Txye8BWbFuvm1I6S4T7JNBD';

const EXPECTED_PLAN = 'growth';
const ENTITLED_STATUS = 'active';
const CANCELED_STATUS = 'canceled';
const UNPAID_PLAN = 'starter';
const INITIAL_BILLING_STATUS = 'inactive';

const POLL_INTERVAL_MS = 1000;
/** Delivery is asynchronous and the Worker processes in waitUntil after its 2xx. */
const WEBHOOK_SETTLE_TIMEOUT_MS = 30000;
const TEST_TIMEOUT_MS = 90000;

const STRIPE_SECRET_KEY = process.env['STRIPE_SECRET_KEY'];
const SUPABASE_URL = process.env['SUPABASE_URL'];
const SUPABASE_SERVICE_ROLE_KEY = process.env['SUPABASE_SERVICE_ROLE_KEY'];
const HAS_CREDENTIALS = Boolean(STRIPE_SECRET_KEY && SUPABASE_URL && SUPABASE_SERVICE_ROLE_KEY);

// Absent credentials skip; present-but-wrong ones fail. A CI or LIVE_TESTS run
// with a missing slot must not report "1 skipped, exit 0".
if ((process.env['CI'] ?? process.env['LIVE_TESTS']) && !HAS_CREDENTIALS) {
  throw new Error(
    'STRIPE_SECRET_KEY, SUPABASE_URL and SUPABASE_SERVICE_ROLE_KEY are required when CI or LIVE_TESTS is set.',
  );
}
if (STRIPE_SECRET_KEY && !TEST_MODE_KEY_PREFIXES.some((prefix) => STRIPE_SECRET_KEY.startsWith(prefix))) {
  throw new Error('Refusing to run: STRIPE_SECRET_KEY is not a test-mode key. Run under Doppler --config dev.');
}
if (SUPABASE_URL && !SUPABASE_URL.includes(DEV_SUPABASE_PROJECT_REF)) {
  throw new Error(`Refusing to run: SUPABASE_URL is not the dev project (${DEV_SUPABASE_PROJECT_REF}).`);
}

interface OrgRow {
  current_plan: string;
  billing_status: string;
  active_subscription_id: string | null;
}

const ORG_SELECT = 'current_plan,billing_status,active_subscription_id';

async function stripePost<T>(path: string, form: Record<string, string> = {}): Promise<T> {
  return stripeRequest<T>('POST', path, form);
}

async function stripeRequest<T>(method: string, path: string, form: Record<string, string> = {}): Promise<T> {
  const response = await fetch(`${STRIPE_API_BASE}${path}`, {
    method,
    headers: {
      authorization: `Bearer ${STRIPE_SECRET_KEY}`,
      'content-type': 'application/x-www-form-urlencoded',
    },
    body: method === 'DELETE' ? undefined : new URLSearchParams(form).toString(),
  });
  const body = (await response.json()) as T & { error?: { message?: string } };
  if (!response.ok) {
    throw new Error(`Stripe ${method} ${path} → ${response.status}: ${body.error?.message ?? 'no message'}`);
  }
  return body;
}

async function supabaseRequest(method: string, pathAndQuery: string, body?: unknown): Promise<Response> {
  const response = await fetch(`${SUPABASE_URL}/rest/v1/${pathAndQuery}`, {
    method,
    headers: {
      apikey: SUPABASE_SERVICE_ROLE_KEY as string,
      authorization: `Bearer ${SUPABASE_SERVICE_ROLE_KEY}`,
      'content-type': 'application/json',
      prefer: 'return=representation',
    },
    body: body === undefined ? undefined : JSON.stringify(body),
  });
  if (!response.ok) {
    throw new Error(`Supabase ${method} ${pathAndQuery} → ${response.status}: ${await response.text()}`);
  }
  return response;
}

async function readOrg(orgId: string): Promise<OrgRow> {
  const response = await supabaseRequest('GET', `organizations?id=eq.${orgId}&select=${ORG_SELECT}`);
  const [row] = (await response.json()) as OrgRow[];
  if (!row) throw new Error(`org ${orgId} not found`);
  return row;
}

/** Re-read the org until `settled` holds or the timeout passes; returns the last row read either way. */
async function waitForOrg(orgId: string, settled: (row: OrgRow) => boolean): Promise<OrgRow> {
  const deadline = Date.now() + WEBHOOK_SETTLE_TIMEOUT_MS;
  let row = await readOrg(orgId);
  while (!settled(row) && Date.now() < deadline) {
    await new Promise((resolve) => setTimeout(resolve, POLL_INTERVAL_MS));
    row = await readOrg(orgId);
  }
  return row;
}

describe.skipIf(!HAS_CREDENTIALS)('stripe-webhook live plan sync (CR38)', () => {
  let customerId: string | null = null;
  let orgId: string | null = null;
  let subscriptionId: string;

  beforeEach(async () => {
    const runId = crypto.randomUUID();

    const customer = await stripePost<{ id: string }>('/customers', {
      email: `cr38-e2e+${runId}@example.com`,
      payment_method: STRIPE_TEST_PAYMENT_METHOD,
      'invoice_settings[default_payment_method]': STRIPE_TEST_PAYMENT_METHOD,
      'metadata[purpose]': 'stripe-webhook plan-sync live test',
    });
    customerId = customer.id;

    // Linked before the subscription exists, so no event can arrive for an unmatched customer.
    const inserted = await supabaseRequest('POST', 'organizations', {
      slug: `cr38-e2e-${runId}`,
      name: 'CR38 plan-sync live test',
      type: 'personal',
      current_plan: UNPAID_PLAN,
      billing_status: INITIAL_BILLING_STATUS,
      stripe_customer_id: customer.id,
    });
    orgId = ((await inserted.json()) as Array<{ id: string }>)[0].id;

    const subscription = await stripePost<{ id: string }>('/subscriptions', {
      customer: customer.id,
      'items[0][price]': SANDBOX_GROWTH_PRICE_ID,
    });
    subscriptionId = subscription.id;
  }, TEST_TIMEOUT_MS);

  afterEach(async () => {
    try {
      if (customerId) {
        // Deleting the customer cancels its subscription; let that event land before the org goes.
        await stripeRequest('DELETE', `/customers/${customerId}`);
        if (orgId) await waitForOrg(orgId, (row) => row.billing_status === CANCELED_STATUS);
      }
    } finally {
      if (orgId) await supabaseRequest('DELETE', `organizations?id=eq.${orgId}`);
      customerId = null;
      orgId = null;
    }
  }, TEST_TIMEOUT_MS);

  it('writes the mapped plan to the org when its subscription is updated', async () => {
    const health = (await (await fetch(DEV_WORKER_HEALTH_URL)).json()) as { priceToPlanEntries?: number };
    expect(health.priceToPlanEntries, 'stripe-webhook-dev has no STRIPE_PRICE_TO_PLAN_JSON bound').toBeGreaterThan(0);

    // invoice.paid only moves billing_status; current_plan is written by customer.subscription.updated alone.
    await stripePost(`/subscriptions/${subscriptionId}`, { 'metadata[plan_sync_probe]': new Date().toISOString() });

    const org = await waitForOrg(orgId as string, (row) => row.current_plan === EXPECTED_PLAN);
    expect(org).toMatchObject({ current_plan: EXPECTED_PLAN, billing_status: ENTITLED_STATUS });
    expect(org.active_subscription_id).not.toBeNull();
  }, TEST_TIMEOUT_MS);
});
