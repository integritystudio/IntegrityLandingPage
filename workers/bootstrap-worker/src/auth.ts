import { unauthorized } from '../../lib/http';

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
 * IMPORTANT: Must be followed by verifySupabaseJwt before trusting the result.
 */
export function parseJwtHeader(token: string): { ok: true; payload: JwtPayload } | { ok: false; error: string } {
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

/**
 * Verify a Supabase JWT signature (HS256) and expiration against SUPABASE_JWT_SECRET.
 */
export async function verifySupabaseJwt(
  token: string,
  jwtSecret: string,
): Promise<{ ok: true; payload: JwtPayload } | { ok: false; error: Response }> {
  const parseResult = parseJwtHeader(token);
  if (!parseResult.ok) {
    return { ok: false, error: unauthorized('Invalid JWT format') };
  }

  const { payload } = parseResult;

  const now = Math.floor(Date.now() / 1000);
  if (typeof payload.exp !== 'number' || payload.exp < now) {
    return { ok: false, error: unauthorized('JWT expired') };
  }

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

    return { ok: true, payload };
  } catch (err) {
    console.error('JWT verification error:', err);
    return { ok: false, error: unauthorized('JWT verification failed') };
  }
}
