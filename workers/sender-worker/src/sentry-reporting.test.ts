/**
 * Sentry reporting from POST /create-checkout-session, through the real SDK with the
 * network doubled. A file of its own: the SDK keeps the `fetch` it sees on its first
 * request, so the stub below has to be installed before this module's Worker handles
 * anything, and must stay installed for the whole file.
 */
import { describe, it, expect, beforeAll, afterAll, beforeEach, vi } from 'vitest';
import type { Env } from './types';
import worker from './index';

const SENTRY_HOST = 'o0.ingest.sentry.invalid';
const TEST_ORG_ID = '1649a1c1-6377-4c4b-9fc2-4d7534372915';
const CHECKOUT_EMAIL = 'buyer@example.com';
const CHECKOUT_URL = 'https://checkout.stripe.com/pay/test';

const env: Env = {
  RECEIVER: { fetch: vi.fn() } as unknown as Fetcher,
  SUPABASE_URL: 'https://supabase.test',
  SUPABASE_SERVICE_ROLE_KEY: 'test-service-role-key',
  STRIPE_SECRET_KEY: 'sk_test_abc123',
  STRIPE_PLAN_TO_PRICE_JSON: JSON.stringify({ growth: 'price_growth_monthly' }),
  SENTRY_DSN: `https://publickey@${SENTRY_HOST}/1`,
  SENTRY_ENVIRONMENT: 'test',
};

type SentryEvent = {
  environment?: string;
  tags?: Record<string, string>;
  fingerprint?: string[];
  exception?: { values?: Array<{ type?: string; value?: string }> };
};

/** What Supabase answers for the signup email; reset before each test. */
const supabase: { users: Array<{ id: string; default_organization_id: string | null }>; userLookupStatus: number | null } = {
  users: [],
  userLookupStatus: null,
};
const envelopes: string[] = [];

const json = (body: unknown, status = 200) =>
  new Response(JSON.stringify(body), { status, headers: { 'content-type': 'application/json' } });

beforeAll(() => {
  vi.spyOn(globalThis, 'fetch').mockImplementation(async (input, init) => {
    const url = typeof input === 'string' ? input : input instanceof URL ? input.href : (input as Request).url;
    if (new URL(url).host === SENTRY_HOST) {
      const body = init?.body;
      envelopes.push(typeof body === 'string' ? body : new TextDecoder().decode(body as BufferSource));
      return json({});
    }
    if (url.includes('/rest/v1/users')) {
      return supabase.userLookupStatus ? json({ message: 'boom' }, supabase.userLookupStatus) : json(supabase.users);
    }
    if (url.includes('/rest/v1/organization_memberships')) return json([]);
    return json({ url: CHECKOUT_URL });
  });
});

afterAll(() => {
  vi.restoreAllMocks();
});

beforeEach(() => {
  envelopes.length = 0;
  supabase.users = [];
  supabase.userLookupStatus = null;
});

const sentEvents = (): SentryEvent[] => envelopes.flatMap((envelope) =>
  envelope.split('\n').filter(Boolean).map((line) => JSON.parse(line) as SentryEvent).filter((item) => item.exception));

const sleep = (ms: number) => new Promise<void>((resolve) => { setTimeout(resolve, ms); });
/** Long enough for a flush that was going to send something to have sent it. */
const NO_EVENT_WAIT_MS = 200;
const POLL_INTERVAL_MS = 10;
const EVENT_TIMEOUT_MS = 2_000;

/** The flush completes on a later tick than the promises `waitUntil` was handed. */
async function theOneEvent(): Promise<SentryEvent> {
  for (let waited = 0; waited < EVENT_TIMEOUT_MS && sentEvents().length === 0; waited += POLL_INTERVAL_MS) {
    await sleep(POLL_INTERVAL_MS);
  }
  expect(sentEvents()).toHaveLength(1);
  return sentEvents()[0];
}

/** The Worker's own handler takes no ctx; the Sentry wrapper around it does. */
const handle = worker.fetch as (request: Request, env: Env, ctx: ExecutionContext) => Promise<Response>;

/** The SDK flushes from `ctx.waitUntil`, after the response has been returned. */
async function checkout(): Promise<Response> {
  const pending: Array<Promise<unknown>> = [];
  const ctx = { waitUntil: (promise: Promise<unknown>) => { pending.push(promise); }, passThroughOnException: () => {} } as unknown as ExecutionContext;
  const response = await handle(new Request('https://worker.test/create-checkout-session', {
    method: 'POST',
    headers: { 'content-type': 'application/json' },
    body: JSON.stringify({ email: CHECKOUT_EMAIL, tier: 'growth' }),
  }), env, ctx);
  await Promise.all(pending);
  return response;
}

describe('POST /create-checkout-session — Sentry reporting', () => {
  it('reports a checkout for an email with no org, and still returns the checkout URL', async () => {
    const response = await checkout();

    expect(response.status).toBe(200);
    expect(await response.json()).toEqual({ checkoutUrl: CHECKOUT_URL });
    const event = await theOneEvent();
    expect(event.exception?.values?.[0]?.value).toBe('Checkout started for an email that resolves to no organization');
    expect(event.tags).toMatchObject({ checkout_issue: 'no-org', tier: 'growth', email_domain: 'example.com' });
    expect(event.fingerprint).toEqual(['sender-worker', 'checkout', 'no-org']);
    expect(event.environment).toBe('test');
    expect(envelopes.join('\n')).not.toContain(CHECKOUT_EMAIL);
  });

  it('reports a failed org lookup as its own issue', async () => {
    supabase.userLookupStatus = 500;

    const response = await checkout();

    expect(response.status).toBe(200);
    const event = await theOneEvent();
    expect(event.tags).toMatchObject({ checkout_issue: 'org-lookup-failed' });
    expect(event.fingerprint).toEqual(['sender-worker', 'checkout', 'org-lookup-failed']);
    expect(envelopes.join('\n')).not.toContain(CHECKOUT_EMAIL);
  });

  it('reports nothing when the email resolves to an org', async () => {
    supabase.users = [{ id: 'user-1', default_organization_id: TEST_ORG_ID }];

    await checkout();
    await sleep(NO_EVENT_WAIT_MS);

    expect(envelopes).toEqual([]);
  });

  it('attaches nothing from the request: no body, headers, breadcrumbs or address', async () => {
    await checkout();

    const event = await theOneEvent() as SentryEvent & { request?: unknown; breadcrumbs?: unknown[] };
    expect(event.request).toBeUndefined();
    expect(event.breadcrumbs ?? []).toEqual([]);
    expect(envelopes.join('\n')).not.toContain('buyer');
  });
});
