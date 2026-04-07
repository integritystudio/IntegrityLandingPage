const ENCODER = new TextEncoder();
const HMAC_ALG = { name: 'HMAC', hash: 'SHA-256' } as const;

type KeyUsage = "decrypt" | "deriveBits" | "deriveKey" | "encrypt" | "sign" | "unwrapKey" | "verify" | "wrapKey";

async function importHmacKey(secret: string, usages: KeyUsage[]): Promise<CryptoKey> {
  return crypto.subtle.importKey('raw', ENCODER.encode(secret), HMAC_ALG, false, usages);
}

/** Sign a message with HMAC-SHA256. Returns raw bytes. */
export async function hmacSign(secret: string, message: string): Promise<ArrayBuffer> {
  const key = await importHmacKey(secret, ['sign']);
  return crypto.subtle.sign('HMAC', key, ENCODER.encode(message));
}

/** Sign a message with HMAC-SHA256. Returns lowercase hex string. */
export async function hmacSignHex(secret: string, message: string): Promise<string> {
  const buf = await hmacSign(secret, message);
  return [...new Uint8Array(buf)].map((b) => b.toString(16).padStart(2, '0')).join('');
}

/**
 * Verify an HMAC-SHA256 signature using a constant-time comparison.
 * `signature` must be the raw bytes of the expected signature.
 */
export async function hmacVerify(
  secret: string,
  signature: Uint8Array,
  message: string,
): Promise<boolean> {
  try {
    const key = await importHmacKey(secret, ['verify']);
    return await crypto.subtle.verify('HMAC', key, signature, ENCODER.encode(message));
  } catch {
    return false;
  }
}
