/**
 * With SENTRY_DSN unset the SDK must send nothing. A file of its own because the SDK's
 * client outlives a request: once any request in a module has had a DSN, later ones
 * without it still report.
 */
import { it, expect, vi, afterAll } from 'vitest';
import type { Env } from './types';
import worker from './index';

const env: Env = {
  RECEIVER: { fetch: vi.fn() } as unknown as Fetcher,
  SUPABASE_URL: 'https://supabase.test',
  SUPABASE_SERVICE_ROLE_KEY: 'test-service-role-key',
  STRIPE_SECRET_KEY: 'sk_test_abc123',
  STRIPE_PLAN_TO_PRICE_JSON: JSON.stringify({ growth: 'price_growth_monthly' }),
};
const EXPECTED_HOSTS = new Set(['supabase.test', 'api.stripe.com']);
/** Long enough for a flush that was going to send something to have sent it. */
const NO_EVENT_WAIT_MS = 200;

afterAll(() => {
  vi.restoreAllMocks();
});

it('sends nothing to Sentry when SENTRY_DSN is unset, even for an email with no org', async () => {
  const hosts: string[] = [];
  vi.spyOn(globalThis, 'fetch').mockImplementation(async (input) => {
    const url = new URL(typeof input === 'string' ? input : input instanceof URL ? input.href : (input as Request).url);
    hosts.push(url.host);
    const body = url.pathname.startsWith('/rest/v1/') ? [] : { url: 'https://checkout.stripe.com/pay/test' };
    return new Response(JSON.stringify(body), { status: 200, headers: { 'content-type': 'application/json' } });
  });

  const response = await worker.fetch(new Request('https://worker.test/create-checkout-session', {
    method: 'POST',
    headers: { 'content-type': 'application/json' },
    body: JSON.stringify({ email: 'buyer@example.com', tier: 'growth' }),
  }), env);
  await new Promise<void>((resolve) => { setTimeout(resolve, NO_EVENT_WAIT_MS); });

  expect(response.status).toBe(200);
  expect(hosts.filter((host) => !EXPECTED_HOSTS.has(host))).toEqual([]);
});
