/**
 * Live signature-verification tests against a deployed stripe-webhook Worker.
 *
 * These sign requests exactly as Stripe does and send them over the network, so
 * they exercise `verifyStripeSignature` against the real deployed binding rather
 * than a test double. That covers three things unit tests cannot: that the
 * Worker actually has a signing secret bound, that the bound secret is the one
 * Stripe issued for the registered endpoint, and that the timestamp tolerance
 * and multi-signature rotation branches behave the same in workerd.
 *
 * Required env (injected by Doppler at runtime):
 *   STRIPE_WEBHOOK_SECRET — the endpoint's `whsec_…`. Stripe returns this only
 *     from the create call and will not disclose it on retrieve, so it has to be
 *     captured at registration time.
 * Optional env:
 *   STRIPE_WEBHOOK_TARGET_URL — defaults to the dev Worker.
 *
 * The default target is deliberately the dev Worker: a request that clears
 * verification proceeds into the handler, and against a database-backed Worker
 * that inserts a row into `webhook_events_log`. Repoint this only when you want
 * that side effect.
 *
 * Run via: npm run test:live
 */

import { describe, expect, it } from 'vitest';
import { REPLAY_WINDOW_MS } from '../../constants';

// This worker's tsconfig loads only @cloudflare/workers-types, but the file runs
// under vitest's node environment where process.env is populated by Doppler.
declare const process: { env: Record<string, string | undefined> };

const DEFAULT_TARGET_URL = 'https://stripe-webhook-dev.alyshia-b38.workers.dev/webhook';
/** Cloudflare answers unrecognised clients with error 1010; Stripe's own agent passes. */
const STRIPE_USER_AGENT = 'Stripe/1.0 (+https://stripe.com/docs/webhooks)';

const MS_PER_SECOND = 1000;
const SIGNATURE_HEX_LENGTH = 64;
const INVALID_SIGNATURE = '0'.repeat(SIGNATURE_HEX_LENGTH);
const REPLAY_WINDOW_SECONDS = REPLAY_WINDOW_MS / MS_PER_SECOND;
/** Twice the tolerance, so the staleness assertion is not sensitive to clock skew. */
const STALE_OFFSET_SECONDS = REPLAY_WINDOW_SECONDS * 2;

const HTTP_OK = 200;
const HTTP_UNAUTHORIZED = 401;
const HTTP_SERVER_ERROR = 500;

/**
 * A verified request continues into the handler, so its final status depends on
 * what the target Worker can reach. With no database binding the idempotency
 * claim fails with 500; fully configured it returns 200. Both prove the
 * signature was accepted — only 401 means verification rejected it.
 */
const VERIFIED_STATUSES = [HTTP_OK, HTTP_SERVER_ERROR];

const WEBHOOK_SECRET = process.env['STRIPE_WEBHOOK_SECRET'];
const TARGET_URL = process.env['STRIPE_WEBHOOK_TARGET_URL'] ?? DEFAULT_TARGET_URL;

const HEX_RADIX = 16;
const HEX_DIGITS_PER_BYTE = 2;

/** HMAC-SHA256 over `{timestamp}.{payload}`, the same construction the Worker verifies. */
export async function signPayload(
  secret: string,
  payload: string,
  timestampSeconds: number,
): Promise<string> {
  const encoder = new TextEncoder();
  const key = await crypto.subtle.importKey(
    'raw',
    encoder.encode(secret),
    { name: 'HMAC', hash: 'SHA-256' },
    false,
    ['sign'],
  );
  const mac = await crypto.subtle.sign('HMAC', key, encoder.encode(`${timestampSeconds}.${payload}`));
  return Array.from(new Uint8Array(mac))
    .map((byte) => byte.toString(HEX_RADIX).padStart(HEX_DIGITS_PER_BYTE, '0'))
    .join('');
}

export function buildSignatureHeader(timestampSeconds: number, ...signatures: string[]): string {
  return [`t=${timestampSeconds}`, ...signatures.map((signature) => `v1=${signature}`)].join(',');
}

function nowSeconds(): number {
  return Math.floor(Date.now() / MS_PER_SECOND);
}

/** A snapshot-format event whose customer intentionally matches no org, so handlers no-op. */
function buildEvent(id: string): string {
  return JSON.stringify({
    id,
    object: 'event',
    type: 'customer.subscription.updated',
    data: {
      object: {
        id: 'sub_live_probe',
        object: 'subscription',
        customer: 'cus_live_probe_unmatched',
        status: 'active',
        items: { data: [{ price: { id: 'price_live_probe' } }] },
      },
    },
  });
}

async function postEvent(payload: string, signatureHeader: string | null): Promise<Response> {
  const headers: Record<string, string> = {
    'content-type': 'application/json',
    'user-agent': STRIPE_USER_AGENT,
  };
  if (signatureHeader !== null) {
    headers['stripe-signature'] = signatureHeader;
  }
  return fetch(TARGET_URL, { method: 'POST', headers, body: payload });
}

describe.skipIf(!WEBHOOK_SECRET)('stripe-webhook live signature verification', () => {
  const secret = WEBHOOK_SECRET as string;

  it('accepts an event signed with the endpoint secret', async () => {
    const payload = buildEvent('evt_live_probe_valid');
    const timestamp = nowSeconds();
    const response = await postEvent(
      payload,
      buildSignatureHeader(timestamp, await signPayload(secret, payload, timestamp)),
    );

    expect(VERIFIED_STATUSES).toContain(response.status);
  });

  it('accepts when only one of several v1 signatures is valid, as during secret rotation', async () => {
    const payload = buildEvent('evt_live_probe_rotation');
    const timestamp = nowSeconds();
    const response = await postEvent(
      payload,
      buildSignatureHeader(
        timestamp,
        INVALID_SIGNATURE,
        await signPayload(secret, payload, timestamp),
      ),
    );

    expect(VERIFIED_STATUSES).toContain(response.status);
  });

  it('rejects a tampered signature', async () => {
    const payload = buildEvent('evt_live_probe_tampered');
    const response = await postEvent(payload, buildSignatureHeader(nowSeconds(), INVALID_SIGNATURE));

    expect(response.status).toBe(HTTP_UNAUTHORIZED);
    expect(await response.text()).toContain('Invalid Stripe signature');
  });

  it('rejects a correctly signed event whose timestamp is outside the replay window', async () => {
    const payload = buildEvent('evt_live_probe_stale');
    const staleTimestamp = nowSeconds() - STALE_OFFSET_SECONDS;
    const response = await postEvent(
      payload,
      buildSignatureHeader(staleTimestamp, await signPayload(secret, payload, staleTimestamp)),
    );

    expect(response.status).toBe(HTTP_UNAUTHORIZED);
    expect(await response.text()).toContain('stale');
  });

  it('rejects a request with no stripe-signature header', async () => {
    const response = await postEvent(buildEvent('evt_live_probe_unsigned'), null);

    expect(response.status).toBe(HTTP_UNAUTHORIZED);
    expect(await response.text()).toContain('Missing stripe-signature header');
  });
});
