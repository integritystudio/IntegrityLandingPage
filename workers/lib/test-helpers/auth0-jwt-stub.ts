/**
 * RS256 token + JWKS fixtures for testing Auth0-issued tokens.
 *
 * The Workers that serve the dashboard verify browser tokens against an Auth0 tenant's
 * published key set, so tests cannot mint an HS256 token against a shared secret. This
 * helper generates a throwaway RSA keypair, signs tokens with it, and serves the matching
 * JWKS through the same fetch stub the Supabase routes use — which means the tests drive
 * the real verification path (kid lookup, JWKS fetch, RS256 verify, iss/aud checks)
 * rather than mocking past it.
 */

/** Tenant used by fixtures. Must match the `auth0Domain` passed to the handler options. */
export const TEST_AUTH0_DOMAIN = 'test-tenant.us.auth0.com';
/** API identifier used by fixtures. Must match the `auth0Audience` handler option. */
export const TEST_AUTH0_AUDIENCE = 'https://api.test.integritystudio.dev';
/** `iss` Auth0 emits for TEST_AUTH0_DOMAIN — note the trailing slash. */
export const TEST_AUTH0_ISSUER = `https://${TEST_AUTH0_DOMAIN}/`;

const JWKS_URL = `https://${TEST_AUTH0_DOMAIN}/.well-known/jwks.json`;

const TEST_KID = 'test-signing-key-1';
const RSA_PARAMS = { name: 'RSASSA-PKCS1-v1_5', hash: 'SHA-256', modulusLength: 2048, publicExponent: new Uint8Array([1, 0, 1]) };
/** Far-future `exp` so fixtures never expire mid-suite. */
const FIXTURE_EXP = 9999999999;

function base64url(bytes: Uint8Array): string {
  return btoa(String.fromCharCode(...bytes)).replace(/\+/g, '-').replace(/\//g, '_').replace(/=+$/, '');
}

function base64urlJson(value: unknown): string {
  return base64url(new TextEncoder().encode(JSON.stringify(value)));
}

export interface Auth0JwtFixture {
  /** Sign an RS256 token. `iss`/`aud`/`exp` default to the tenant fixtures. */
  sign(payload: Record<string, unknown>): Promise<string>;
  /**
   * Wrap a fetch implementation so JWKS requests are answered from the fixture and
   * everything else falls through unchanged.
   *
   * Serving the key set here rather than as a route on the Supabase stub keeps JWKS
   * traffic out of `stub.requests`, so tests can still assert exactly which database
   * calls a handler made.
   */
  wrap(inner: typeof fetch): typeof fetch;
}

/**
 * Build a token signer and its matching JWKS route.
 *
 * Call once per test file: the verifier caches key sets by JWKS URL for 10 minutes, so two
 * fixtures sharing a domain within one module would race over the same cache entry.
 */
export async function createAuth0JwtFixture(): Promise<Auth0JwtFixture> {
  // generateKey's return type is the CryptoKey | CryptoKeyPair union; RSA always yields a pair.
  const pair = (await crypto.subtle.generateKey(RSA_PARAMS, true, ['sign', 'verify'])) as CryptoKeyPair;
  const publicJwk = (await crypto.subtle.exportKey('jwk', pair.publicKey)) as unknown as Record<string, unknown>;
  // Auth0 publishes kid/use/alg alongside the key material; resolveSigningKey matches on kid.
  const jwks = { keys: [{ ...publicJwk, kid: TEST_KID, use: 'sig', alg: 'RS256' }] };

  const wrap = (inner: typeof fetch): typeof fetch =>
    (async (input: URL | RequestInfo, init?: RequestInit) => {
      if (String(input) === JWKS_URL) {
        return new Response(JSON.stringify(jwks), {
          status: 200,
          headers: { 'content-type': 'application/json' },
        });
      }
      return inner(input as RequestInfo, init);
    }) as typeof fetch;

  async function sign(payload: Record<string, unknown>): Promise<string> {
    const header = base64urlJson({ alg: 'RS256', typ: 'JWT', kid: TEST_KID });
    const body = base64urlJson({
      iss: TEST_AUTH0_ISSUER,
      aud: TEST_AUTH0_AUDIENCE,
      exp: FIXTURE_EXP,
      ...payload,
    });
    const msg = `${header}.${body}`;
    const sig = await crypto.subtle.sign(
      { name: 'RSASSA-PKCS1-v1_5' },
      pair.privateKey,
      new TextEncoder().encode(msg),
    );
    return `${msg}.${base64url(new Uint8Array(sig))}`;
  }

  return { sign, wrap };
}

/** Handler options fragment pairing with the fixture's tenant. */
export const TEST_AUTH0_OPTS = {
  auth0Domain: TEST_AUTH0_DOMAIN,
  auth0Audience: TEST_AUTH0_AUDIENCE,
} as const;
