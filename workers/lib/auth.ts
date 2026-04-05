import { hmacVerify } from './crypto';
import { unauthorized } from './http';

/** Seconds of clock-skew tolerance applied to the `nbf` (Not Before) check. */
const NBF_CLOCK_SKEW_SECONDS = 30;

export interface JwtPayload {
  sub: string;
  email: string;
  iat: number;
  exp: number;
  /** RFC 7519 §4.1.5 — Not Before. Optional; validated when present. */
  nbf?: number;
  /** RFC 7519 §4.1.3 — Audience. Optional; validated when VerifyJwtOptions.audience is set. */
  aud?: string | string[];
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
 * Returns `parts` so callers can reuse the split for signature verification.
 */
export function parseJwtPayload(token: string): { ok: true; payload: JwtPayload; parts: string[] } | { ok: false; error: string } {
  try {
    const parts = token.split('.');
    if (parts.length !== 3) {
      return { ok: false, error: 'invalid jwt format' };
    }
    const payload = JSON.parse(new TextDecoder().decode(base64urlToBytes(parts[1])));
    return { ok: true, payload, parts };
  } catch {
    return { ok: false, error: 'failed to parse jwt' };
  }
}

export interface VerifyJwtOptions {
  /** Expected value of the `iss` (issuer) claim. When provided, tokens from
   *  any other issuer are rejected — prevents forgery via attacker-controlled JWTs.
   *  Set to your Supabase project auth URL, e.g. https://<ref>.supabase.co/auth/v1 */
  issuerUrl?: string;
  /** Expected value of the `aud` (audience) claim (RFC 7519 §4.1.3).
   *  When provided, tokens missing this audience or containing a different one
   *  are rejected — prevents tokens issued for one service from being replayed
   *  against another. Set to your API identifier, e.g. https://api.example.com */
  audience?: string;
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

  const { payload, parts } = parseResult;

  // Verify signature before claims — avoids leaking claim structure to attacker-crafted tokens.
  const isValid = await hmacVerify(jwtSecret, base64urlToBytes(parts[2]), parts.slice(0, 2).join('.'));
  if (!isValid) {
    return { ok: false, error: unauthorized('Invalid JWT signature') };
  }

  const now = Math.floor(Date.now() / 1000);
  if (payload.exp < now) {
    return { ok: false, error: unauthorized('JWT expired') };
  }

  if (opts.issuerUrl != null && payload.iss !== opts.issuerUrl) {
    return { ok: false, error: unauthorized('JWT issuer mismatch') };
  }

  // RFC 7519 §4.1.5 — nbf (Not Before): reject tokens used before their validity window.
  // NBF_CLOCK_SKEW_SECONDS tolerates minor time drift between services.
  if (typeof payload.nbf === 'number' && payload.nbf > now + NBF_CLOCK_SKEW_SECONDS) {
    return { ok: false, error: unauthorized('JWT not yet valid') };
  }

  // RFC 7519 §4.1.3 — aud (Audience): reject tokens not intended for this service.
  if (opts.audience != null) {
    const aud = payload.aud;
    const audOk =
      aud === opts.audience ||
      (Array.isArray(aud) && aud.includes(opts.audience));
    if (!audOk) {
      return { ok: false, error: unauthorized('JWT audience mismatch') };
    }
  }

  return { ok: true, payload };
}
