import { describe, it, expect } from 'vitest';
import { verifyStripeSignature } from './verify';
import { REPLAY_WINDOW_MS } from '../../constants';

// Seconds past the replay window, guaranteeing the timestamp is rejected as stale.
const STALE_OFFSET_SECONDS = (REPLAY_WINDOW_MS / 1000) * 2;

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
