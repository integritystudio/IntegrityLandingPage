import { unauthorized } from './http';

export interface JwtPayload {
  sub: string;
  email: string;
  iat: number;
  exp: number;
  [key: string]: unknown;
}

/** Decode a base64url-encoded string to a Uint8Array. */
function base64urlToBytes(value: string): Uint8Array {
  return new Uint8Array(
    atob(value.replace(/-/g, '+').replace(/_/g, '/'))
      .split('')
      .map((c) => c.charCodeAt(0)),
  );
}

/**
 * Parse JWT payload without signature verification.
 * IMPORTANT: Must be followed by verifyJwt before trusting the result.
 */
export function parseJwtPayload(token: string): { ok: true; payload: JwtPayload } | { ok: false; error: string } {
  try {
    const parts = token.split('.');
    if (parts.length !== 3) {
      return { ok: false, error: 'invalid jwt format' };
    }
    const payload = JSON.parse(new TextDecoder().decode(base64urlToBytes(parts[1])));
    return { ok: true, payload };
  } catch {
    return { ok: false, error: 'failed to parse jwt' };
  }
}

export interface VerifyJwtOptions {
  /** Expected value of the `iss` (issuer) claim. When provided, tokens from
   *  any other issuer are rejected — prevents forgery via attacker-controlled JWTs.
   *  Set to your Supabase project auth URL, e.g. https://<ref>.supabase.co/auth/v1 */
  issuerUrl?: string;
}

/**
 * Verify a JWT signature (HS256), expiration, and optional issuer claim.
 */
export async function verifyJwt(
  token: string,
  jwtSecret: string,
  opts: VerifyJwtOptions = {},
): Promise<{ ok: true; payload: JwtPayload } | { ok: false; error: Response }> {
  const parseResult = parseJwtPayload(token);
  if (!parseResult.ok) {
    return { ok: false, error: unauthorized('Invalid JWT format') };
  }

  // Verify signature before claims — avoids leaking claim structure to attacker-crafted tokens.
  try {
    const parts = token.split('.');
    const encoder = new TextEncoder();

    const key = await crypto.subtle.importKey(
      'raw',
      encoder.encode(jwtSecret),
      { name: 'HMAC', hash: 'SHA-256' },
      false,
      ['verify'],
    );

    const isValid = await crypto.subtle.verify(
      'HMAC',
      key,
      base64urlToBytes(parts[2]),
      encoder.encode(parts.slice(0, 2).join('.')),
    );

    if (!isValid) {
      return { ok: false, error: unauthorized('Invalid JWT signature') };
    }
  } catch (err) {
    console.error('JWT verification error:', err);
    return { ok: false, error: unauthorized('JWT verification failed') };
  }

  // Claims validation.
  const { payload } = parseResult;

  const now = Math.floor(Date.now() / 1000);
  if (typeof payload.exp !== 'number' || payload.exp < now) {
    return { ok: false, error: unauthorized('JWT expired') };
  }

  if (opts.issuerUrl !== undefined && (typeof payload.iss !== 'string' || payload.iss !== opts.issuerUrl)) {
    return { ok: false, error: unauthorized('JWT issuer mismatch') };
  }

  return { ok: true, payload };
}
