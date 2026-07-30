import { hmacVerify } from './crypto';
import { unauthorized } from './http';

/** Seconds of clock-skew tolerance applied to the `nbf` (Not Before) check. */
const NBF_CLOCK_SKEW_SECONDS = 30;

/** Path of a Supabase project's published JSON Web Key Set, relative to SUPABASE_URL. */
const JWKS_PATH = '/auth/v1/.well-known/jwks.json';
/**
 * Path of an Auth0 tenant's published JSON Web Key Set. Note this is the bare
 * well-known path — Auth0 does not nest it under a prefix the way Supabase does.
 */
const AUTH0_JWKS_PATH = '/.well-known/jwks.json';
/** How long a fetched key set is reused before being refreshed. */
const JWKS_CACHE_TTL_MS = 10 * 60 * 1000;
/**
 * Minimum gap between refetches triggered by an unrecognised `kid`. Without it,
 * tokens bearing a bogus kid would force one upstream fetch per request.
 */
const JWKS_UNKNOWN_KID_REFETCH_COOLDOWN_MS = 30 * 1000;
/** Upper bound on the JWKS request; verification fails closed if exceeded. */
const JWKS_FETCH_TIMEOUT_MS = 3000;

const ALG_HS256 = 'HS256';
const ALG_ES256 = 'ES256';
const ALG_RS256 = 'RS256';

/**
 * WebCrypto parameters per supported asymmetric algorithm. Membership in this
 * map *is* the allowlist — an `alg` absent from it is rejected outright, so
 * `none` and unexpected algorithms can never reach a verification path.
 */
const ASYMMETRIC_ALGS = {
  [ALG_ES256]: {
    importParams: { name: 'ECDSA', namedCurve: 'P-256' },
    verifyParams: { name: 'ECDSA', hash: 'SHA-256' },
  },
  [ALG_RS256]: {
    importParams: { name: 'RSASSA-PKCS1-v1_5', hash: 'SHA-256' },
    verifyParams: { name: 'RSASSA-PKCS1-v1_5' },
  },
} as const satisfies Record<string, { importParams: SubtleCryptoImportKeyAlgorithm; verifyParams: SubtleCryptoImportKeyAlgorithm }>;

type AsymmetricAlg = keyof typeof ASYMMETRIC_ALGS;

/**
 * How to verify a token's signature.
 *
 * - A bare string is a legacy HS256 shared secret (Supabase's "JWT secret").
 * - `{ jwksUrl }` verifies asymmetric signatures against the project's
 *   published key set, which is what Supabase issues once a project has
 *   migrated to ES256 signing keys. `hmacSecret` may be supplied alongside it
 *   so tokens minted before the migration still verify until they expire.
 */
export type JwtVerificationKey = string | { jwksUrl: string; hmacSecret?: string };

/** Build the JWKS URL for a Supabase project from its base URL. */
export function jwksUrlFor(supabaseUrl: string): string {
  return `${supabaseUrl.replace(/\/+$/, '')}${JWKS_PATH}`;
}

/**
 * Verification key for a Supabase project: JWKS-first, with the legacy HS256
 * secret accepted as a fallback when one is configured. Derived from
 * `supabaseUrl` so each environment automatically verifies against its own
 * project — no extra secret to bind, and nothing to keep in sync.
 */
export function supabaseJwtKey(opts: { supabaseUrl?: string; jwtSecret?: string }): JwtVerificationKey {
  if (opts.supabaseUrl) {
    return { jwksUrl: jwksUrlFor(opts.supabaseUrl), hmacSecret: opts.jwtSecret };
  }
  return opts.jwtSecret ?? '';
}

/**
 * Normalise an Auth0 tenant domain to a bare host. Accepts the plain host
 * (`tenant.us.auth0.com`) as well as a full origin, because AUTH0_DOMAIN is
 * spelled both ways across our Workers and a doubled scheme yields a JWKS URL
 * that 404s — which surfaces as an opaque "Invalid JWT signature".
 */
function auth0Host(domain: string): string {
  // An unbound AUTH0_DOMAIN must fail closed, not throw. Returning '' yields a JWKS URL
  // whose fetch fails and an issuer no token can match, so verification rejects the token
  // — a 401 rather than an unhandled TypeError surfacing as a 500 on every request.
  if (!domain) return '';
  return domain.replace(/^https?:\/\//, '').replace(/\/+$/, '');
}

/**
 * Canonical `iss` value for an Auth0 tenant. Auth0 always emits the issuer with
 * a trailing slash, and verifyJwt compares `iss` by exact string equality, so
 * omitting it rejects every otherwise-valid token.
 */
export function auth0IssuerFor(domain: string): string {
  return `https://${auth0Host(domain)}/`;
}

/**
 * Verification key for an Auth0 tenant: RS256 against the tenant's published key set.
 *
 * Deliberately no `hmacSecret` fallback. Auth0 signs these tokens with RS256 only,
 * so a symmetric fallback would add no reachable verification path while widening
 * the algorithm-confusion surface that verifySignature otherwise closes.
 */
export function auth0JwtKey(opts: { auth0Domain: string }): JwtVerificationKey {
  return { jwksUrl: `https://${auth0Host(opts.auth0Domain)}${AUTH0_JWKS_PATH}` };
}

interface JwksCacheEntry {
  keys: JsonWebKey[];
  fetchedAt: number;
  lastUnknownKidFetchAt: number;
  imported: Map<string, CryptoKey>;
}

const jwksCache = new Map<string, JwksCacheEntry>();

/** Drop all cached key sets. Exported for tests; not used in request paths. */
export function resetJwksCache(): void {
  jwksCache.clear();
}

async function fetchJwks(jwksUrl: string): Promise<JsonWebKey[] | null> {
  try {
    const response = await fetch(jwksUrl, { signal: AbortSignal.timeout(JWKS_FETCH_TIMEOUT_MS) });
    if (!response.ok) {
      console.error('[auth] JWKS fetch failed with status', response.status, jwksUrl);
      return null;
    }
    const body = (await response.json()) as { keys?: JsonWebKey[] };
    if (!Array.isArray(body.keys)) {
      console.error('[auth] JWKS response has no keys array', jwksUrl);
      return null;
    }
    return body.keys;
  } catch (e) {
    console.error('[auth] JWKS fetch threw for', jwksUrl, e);
    return null;
  }
}

/**
 * Resolve the signing key for `kid`, fetching the key set when it is absent or
 * stale. An unrecognised kid triggers at most one refetch per cooldown window,
 * so key rotation is picked up promptly without letting forged kids drive
 * unbounded upstream traffic.
 */
async function resolveSigningKey(jwksUrl: string, kid: string, alg: AsymmetricAlg): Promise<CryptoKey | null> {
  const now = Date.now();
  let entry = jwksCache.get(jwksUrl);

  if (!entry || now - entry.fetchedAt > JWKS_CACHE_TTL_MS) {
    const keys = await fetchJwks(jwksUrl);
    // Fail closed on fetch failure, but keep any still-usable cached entry
    // rather than discarding it — a transient upstream blip should not turn
    // every request into a 401 while the cached key is still valid.
    if (keys) {
      entry = { keys, fetchedAt: now, lastUnknownKidFetchAt: 0, imported: new Map() };
      jwksCache.set(jwksUrl, entry);
    } else if (!entry) {
      return null;
    }
  }

  const cachedKey = entry.imported.get(kid);
  if (cachedKey) return cachedKey;

  let jwk = entry.keys.find((k) => (k as { kid?: string }).kid === kid);

  if (!jwk && now - entry.lastUnknownKidFetchAt > JWKS_UNKNOWN_KID_REFETCH_COOLDOWN_MS) {
    entry.lastUnknownKidFetchAt = now;
    const keys = await fetchJwks(jwksUrl);
    if (keys) {
      entry.keys = keys;
      entry.fetchedAt = now;
      entry.imported.clear();
      jwk = keys.find((k) => (k as { kid?: string }).kid === kid);
    }
  }

  if (!jwk) return null;

  try {
    const key = await crypto.subtle.importKey('jwk', jwk, ASYMMETRIC_ALGS[alg].importParams, false, ['verify']);
    entry.imported.set(kid, key);
    return key;
  } catch (e) {
    console.error('[auth] JWKS key import failed for kid', kid, e);
    return null;
  }
}

interface JwtHeader {
  alg?: string;
  kid?: string;
}

/** Decode the JOSE header. Untrusted: `alg` selects a path, never a key. */
function parseJwtHeader(encodedHeader: string): JwtHeader | null {
  try {
    return JSON.parse(new TextDecoder().decode(base64urlToBytes(encodedHeader))) as JwtHeader;
  } catch {
    return null;
  }
}

/**
 * Check a token's signature against `key`.
 *
 * The header's `alg` chooses *which* verification path runs, but never which
 * key material is used, which is what defeats algorithm confusion: an `HS256`
 * token is only ever checked against a configured HMAC secret, so a JWKS
 * public key can never be replayed as a shared secret.
 */
async function verifySignature(
  key: JwtVerificationKey,
  header: JwtHeader,
  signingInput: string,
  sigBytes: Uint8Array,
): Promise<boolean> {
  const alg = header.alg;
  if (!alg) return false;

  const hmacSecret = typeof key === 'string' ? key : key.hmacSecret;

  if (alg === ALG_HS256) {
    if (!hmacSecret) return false;
    return hmacVerify(hmacSecret, sigBytes, signingInput);
  }

  if (!(alg in ASYMMETRIC_ALGS)) return false;
  if (typeof key === 'string') return false;
  if (!header.kid) return false;

  const asymmetricAlg = alg as AsymmetricAlg;
  const signingKey = await resolveSigningKey(key.jwksUrl, header.kid, asymmetricAlg);
  if (!signingKey) return false;

  try {
    return await crypto.subtle.verify(
      ASYMMETRIC_ALGS[asymmetricAlg].verifyParams,
      signingKey,
      sigBytes as unknown as BufferSource,
      new TextEncoder().encode(signingInput),
    );
  } catch (e) {
    console.error('[auth] asymmetric JWT verification threw', e);
    return false;
  }
}

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
 * Verify a JWT's signature, expiration, and optional issuer/audience claims.
 *
 * `key` accepts either a legacy HS256 shared secret or a JWKS source (see
 * {@link JwtVerificationKey} and {@link supabaseJwtKey}). Supabase projects
 * issue ES256-signed tokens once migrated to asymmetric signing keys, so the
 * JWKS form is the forward-looking one; passing a bare secret remains valid
 * for projects still on a symmetric key.
 */
export async function verifyJwt(
  token: string,
  key: JwtVerificationKey,
  opts: VerifyJwtOptions = {},
): Promise<{ ok: true; payload: JwtPayload } | { ok: false; error: Response }> {
  const parseResult = parseJwtPayload(token);
  if (!parseResult.ok) {
    return { ok: false, error: unauthorized('Invalid JWT format') };
  }

  const { payload, parts } = parseResult;

  const header = parseJwtHeader(parts[0]);
  if (!header) {
    return { ok: false, error: unauthorized('Invalid JWT format') };
  }

  // Verify signature before claims — avoids leaking claim structure to attacker-crafted tokens.
  let sigBytes: Uint8Array;
  try {
    sigBytes = base64urlToBytes(parts[2]);
  } catch {
    return { ok: false, error: unauthorized('Invalid JWT signature') };
  }
  const isValid = await verifySignature(key, header, parts.slice(0, 2).join('.'), sigBytes);
  if (!isValid) {
    return { ok: false, error: unauthorized('Invalid JWT signature') };
  }

  const now = Math.floor(Date.now() / 1000);
  // Reject tokens with a missing, non-numeric, or already-expired exp claim.
  // typeof guard is required: undefined < now evaluates to false in JS, so an
  // absent exp would otherwise be treated as a never-expiring token.
  if (typeof payload.exp !== 'number' || payload.exp < now) {
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
