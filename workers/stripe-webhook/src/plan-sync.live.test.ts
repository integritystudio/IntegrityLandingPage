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
 * The same run checks UA10: the plan write reaches the org's members, because
 * `organizations_propagate_tier` derives `users.tier` from the default org's
 * `current_plan`. Only the Worker's real write fires that trigger.
 *
 * Each run creates its own fixture and removes it: a sandbox customer on
 * Stripe's test card, a personal org linked to it, a dev user whose default org
 * it is, and a growth subscription. Cleanup deletes the customer (which cancels
 * the subscription) and the user, waits for the resulting
 * `customer.subscription.deleted` to land, then deletes the org — deleting the
 * org first would make the Worker dead-letter that event. If the
 * Stripe side cannot be removed, or its event does not land in time, the org is
 * kept (so late events still match it) and the run fails naming the ids.
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
/** `plan_to_api_key_tier('growth')`, which the org's members must follow. */
const EXPECTED_TIER = 'growth';
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

async function readUserTier(userId: string): Promise<string> {
  const response = await supabaseRequest('GET', `users?id=eq.${userId}&select=tier`);
  const [row] = (await response.json()) as Array<{ tier: string }>;
  if (!row) throw new Error(`user ${userId} not found`);
  return row.tier;
}

interface SettleResult {
  settled: boolean;
  /** The last row read, so a timeout still reports the state the org was left in. */
  row: OrgRow;
}

/** Re-read the org until `isSettled` holds or WEBHOOK_SETTLE_TIMEOUT_MS passes. */
async function waitForOrg(orgId: string, isSettled: (row: OrgRow) => boolean): Promise<SettleResult> {
  const deadline = Date.now() + WEBHOOK_SETTLE_TIMEOUT_MS;
  let row = await readOrg(orgId);
  while (!isSettled(row) && Date.now() < deadline) {
    await new Promise((resolve) => setTimeout(resolve, POLL_INTERVAL_MS));
    row = await readOrg(orgId);
  }
  return { settled: isSettled(row), row };
}

describe.skipIf(!HAS_CREDENTIALS)('stripe-webhook live plan sync (CR38)', () => {
  let customerId: string | null = null;
  let orgId: string | null = null;
  let userId: string | null = null;
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
    const [org] = (await inserted.json()) as Array<{ id: string }>;
    if (!org) throw new Error('organizations insert returned no row');
    orgId = org.id;

    const insertedUser = await supabaseRequest('POST', 'users', {
      auth0_id: `cr38-e2e|${runId}`,
      email: `cr38-e2e+${runId}@example.com`,
      default_organization_id: org.id,
    });
    const [user] = (await insertedUser.json()) as Array<{ id: string }>;
    if (!user) throw new Error('users insert returned no row');
    userId = user.id;

    const subscription = await stripePost<{ id: string }>('/subscriptions', {
      customer: customer.id,
      'items[0][price]': SANDBOX_GROWTH_PRICE_ID,
    });
    subscriptionId = subscription.id;
  }, TEST_TIMEOUT_MS);

  afterEach(async () => {
    const [customer, org, user] = [customerId, orgId, userId];
    customerId = null;
    orgId = null;
    userId = null;

    // Deleting the customer cancels its subscription. The org goes only once that
    // event has landed: an org deleted earlier makes the Worker dead-letter it, and one
    // deleted while Stripe still bills would dead-letter every renewal. Otherwise keep
    // it — a late event settles it to canceled — and fail with the ids to clean up.
    if (customer) {
      try {
        await stripeRequest('DELETE', `/customers/${customer}`);
      } catch (error) {
        throw new Error(
          `cleanup: sandbox customer ${customer} not deleted; kept dev org ${org} and its user ${user}. ${String(error)}`,
        );
      }
    }
    // The user plays no part in Stripe's events, and the org cannot be deleted while it references it.
    if (user) await supabaseRequest('DELETE', `users?id=eq.${user}`);
    if (!org) return;
    if (customer) {
      const cancel = await waitForOrg(org, (row) => row.billing_status === CANCELED_STATUS);
      if (!cancel.settled) {
        throw new Error(
          `cleanup: dev org ${org} still ${cancel.row.billing_status} after ${WEBHOOK_SETTLE_TIMEOUT_MS}ms; ` +
            'kept it so the late customer.subscription.deleted does not dead-letter. Delete it once canceled.',
        );
      }
    }
    await supabaseRequest('DELETE', `organizations?id=eq.${org}`);
  }, TEST_TIMEOUT_MS);

  it('writes the mapped plan to the org when its subscription is updated', async () => {
    const health = (await (await fetch(DEV_WORKER_HEALTH_URL)).json()) as { priceToPlanEntries?: number };
    expect(health.priceToPlanEntries, 'stripe-webhook-dev has no STRIPE_PRICE_TO_PLAN_JSON bound').toBeGreaterThan(0);

    // invoice.paid only moves billing_status; current_plan is written by customer.subscription.updated alone.
    await stripePost(`/subscriptions/${subscriptionId}`, { 'metadata[plan_sync_probe]': new Date().toISOString() });

    const { row: org } = await waitForOrg(orgId as string, (row) => row.current_plan === EXPECTED_PLAN);
    expect(org, `org state after waiting up to ${WEBHOOK_SETTLE_TIMEOUT_MS}ms`).toMatchObject({
      current_plan: EXPECTED_PLAN,
      billing_status: ENTITLED_STATUS,
    });
    expect(org.active_subscription_id).not.toBeNull();
  }, TEST_TIMEOUT_MS);

  it("moves the default org's members to the mapped tier (UA10)", async () => {
    await stripePost(`/subscriptions/${subscriptionId}`, { 'metadata[plan_sync_probe]': new Date().toISOString() });

    const { row: org } = await waitForOrg(orgId as string, (row) => row.current_plan === EXPECTED_PLAN);
    expect(org.current_plan, 'the plan never synced, so the tier had nothing to follow').toBe(EXPECTED_PLAN);
    expect(await readUserTier(userId as string), 'users.tier did not follow current_plan').toBe(EXPECTED_TIER);
  }, TEST_TIMEOUT_MS);
});
