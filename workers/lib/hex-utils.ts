/**
 * Convert a lowercase hex string to a Uint8Array.
 * Returns null for empty strings, odd-length input, or non-hex characters.
 * The regex uses `+` (one or more) to reject empty strings — the length check
 * alone passes empty (0 % 2 === 0), but an empty Uint8Array would pass
 * crypto.subtle.verify against itself.
 */
export function hexToBytes(hex: string): Uint8Array | null {
  if (hex.length % 2 !== 0 || !/^[0-9a-f]+$/.test(hex)) return null;
  const bytes = new Uint8Array(hex.length / 2);
  for (let i = 0; i < hex.length; i += 2) {
    bytes[i / 2] = parseInt(hex.slice(i, i + 2), 16);
  }
  return bytes;
}
