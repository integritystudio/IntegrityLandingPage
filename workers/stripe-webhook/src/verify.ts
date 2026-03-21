import { REPLAY_WINDOW_MS } from '../../constants';
import { unauthorized } from '../../lib/http';

/**
 * Verify Stripe webhook signature using HS256.
 * Stripe format: t=<timestamp>,v1=<signature>
 */
export async function verifyStripeSignature(
  signatureHeader: string | null,
  rawBody: string,
  webhookSecret: string,
): Promise<
  | { ok: true; timestamp: number }
  | { ok: false; error: Response }
> {
  if (!signatureHeader) {
    return { ok: false, error: unauthorized('Missing stripe-signature header') };
  }

  // Parse header: "t=1234567890,v1=signature_hex"
  // Use limit 2 so values containing '=' (e.g. base64) are preserved intact.
  const parts: Record<string, string> = {};
  for (const part of signatureHeader.split(',')) {
    const eqIndex = part.indexOf('=');
    if (eqIndex > 0) {
      parts[part.slice(0, eqIndex)] = part.slice(eqIndex + 1);
    }
  }

  const timestamp = parts.t ? Number(parts.t) : null;
  const signature = parts.v1;

  if (!timestamp || isNaN(timestamp)) {
    return { ok: false, error: unauthorized('Invalid stripe-signature timestamp') };
  }

  if (!signature) {
    return { ok: false, error: unauthorized('Missing v1 signature in stripe-signature') };
  }

  // Reject stale timestamps; REPLAY_WINDOW_MS is in ms, timestamp is in seconds.
  const nowSeconds = Math.floor(Date.now() / 1000);
  const replayWindowSeconds = REPLAY_WINDOW_MS / 1000;
  if (Math.abs(nowSeconds - timestamp) > replayWindowSeconds) {
    return { ok: false, error: unauthorized('Stripe signature timestamp is stale') };
  }

  // Verify signature using constant-time HMAC comparison to prevent timing side-channels.
  try {
    // Validate hex before conversion — Stripe signatures are lowercase hex
    if (!/^[0-9a-f]+$/.test(signature) || signature.length % 2 !== 0) {
      return { ok: false, error: unauthorized('Invalid Stripe signature format') };
    }

    const signedContent = `${timestamp}.${rawBody}`;
    const encoder = new TextEncoder();
    const key = await crypto.subtle.importKey(
      'raw',
      encoder.encode(webhookSecret),
      { name: 'HMAC', hash: 'SHA-256' },
      false,
      ['verify'],
    );

    const sigBytes = new Uint8Array(signature.length / 2);
    for (let i = 0; i < signature.length; i += 2) {
      sigBytes[i / 2] = parseInt(signature.slice(i, i + 2), 16);
    }

    const isValid = await crypto.subtle.verify('HMAC', key, sigBytes, encoder.encode(signedContent));
    if (!isValid) {
      return { ok: false, error: unauthorized('Invalid Stripe signature') };
    }

    return { ok: true, timestamp };
  } catch (err) {
    console.error('Stripe signature verification error:', err);
    return { ok: false, error: unauthorized('Signature verification failed') };
  }
}
