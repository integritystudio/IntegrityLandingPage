const encoder = new TextEncoder();
const HMAC_ALGORITHM = "HMAC";
const HASH_ALGORITHM = "SHA-256";

async function importHmacKey(secret: string, usages: KeyUsage[]): Promise<CryptoKey> {
  return crypto.subtle.importKey(
    "raw",
    encoder.encode(secret),
    { name: HMAC_ALGORITHM, hash: HASH_ALGORITHM },
    false,
    usages,
  );
}

function toHex(buffer: ArrayBuffer): string {
  return [...new Uint8Array(buffer)]
    .map((b) => b.toString(16).padStart(2, "0"))
    .join("");
}

export async function signMessage(secret: string, message: string): Promise<string> {
  const key = await importHmacKey(secret, ["sign"]);
  const sig = await crypto.subtle.sign(HMAC_ALGORITHM, key, encoder.encode(message));
  return toHex(sig);
}
