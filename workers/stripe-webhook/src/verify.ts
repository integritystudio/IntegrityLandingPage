import { REPLAY_WINDOW_MS } from '../../constants';
import { hmacVerify } from '../../lib/crypto';
import { hexToBytes } from '../../lib/hex-utils';
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

  // Parse header: "t=1234567890,v1=signature_hex[,v1=signature_hex2,...]"
  // During key rotation Stripe sends multiple v1 entries; we must accept any one of
  // them. Collecting into an array rather than using an object avoids the last-write-
  // wins problem that would reject webhooks when two v1 values are present.
  let timestampRaw: string | null = null;
  const v1Signatures: string[] = [];

  for (const part of signatureHeader.split(',')) {
    const eqIndex = part.indexOf('=');
    if (eqIndex > 0) {
      const key = part.slice(0, eqIndex);
      const val = part.slice(eqIndex + 1);
      if (key === 'v1') {
        v1Signatures.push(val);
      } else if (key === 't') {
        timestampRaw = val;
      }
    }
  }

  const timestamp = timestampRaw ? Number(timestampRaw) : null;

  if (!timestamp || isNaN(timestamp)) {
    return { ok: false, error: unauthorized('Invalid stripe-signature timestamp') };
  }

  if (v1Signatures.length === 0) {
    return { ok: false, error: unauthorized('Missing v1 signature in stripe-signature') };
  }

  // Reject stale timestamps; REPLAY_WINDOW_MS is in ms, timestamp is in seconds.
  const nowSeconds = Math.floor(Date.now() / 1000);
  const replayWindowSeconds = REPLAY_WINDOW_MS / 1000;
  if (Math.abs(nowSeconds - timestamp) > replayWindowSeconds) {
    return { ok: false, error: unauthorized('Stripe signature timestamp is stale') };
  }

  // Accept the webhook if ANY of the v1 signatures is valid (rotation window).
  const signedPayload = `${timestamp}.${rawBody}`;
  let isValid = false;
  for (const sig of v1Signatures) {
    const sigBytes = hexToBytes(sig);
    if (!sigBytes) continue;
    // Verify signature using constant-time HMAC comparison to prevent timing side-channels.
    if (await hmacVerify(webhookSecret, sigBytes, signedPayload)) {
      isValid = true;
      break;
    }
  }

  if (!isValid) {
    return { ok: false, error: unauthorized('Invalid Stripe signature') };
  }
  return { ok: true, timestamp };
}
