import { describe, it, expect, beforeAll, beforeEach, afterEach, vi } from 'vitest';
import { verifyJwt, parseJwtPayload, resetJwksCache, auth0JwtKey, auth0IssuerFor } from './auth';
import type { JwtVerificationKey } from './auth';

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

/** Base64url-encode a string without padding. */
function b64url(s: string): string {
  return btoa(s).replace(/\+/g, '-').replace(/\//g, '_').replace(/=/g, '');
}

/**
 * Build a compact JWT signed with HS256. The library no longer verifies HS256 at all
 * (removed 2026-07-31), so this exists to forge tokens the verifier must *reject* —
 * plus the parse-only tests, which never reach signature checking.
 */
async function buildJwt(
  claims: Record<string, unknown>,
  secret: string,
): Promise<string> {
  const header = b64url(JSON.stringify({ alg: 'HS256', typ: 'JWT' }));
  const payload = b64url(JSON.stringify(claims));
  const encoder = new TextEncoder();
  const key = await crypto.subtle.importKey(
    'raw',
    encoder.encode(secret),
    { name: 'HMAC', hash: 'SHA-256' },
    false,
    ['sign'],
  );
  const sig = await crypto.subtle.sign(
    'HMAC',
    key,
    encoder.encode(`${header}.${payload}`),
  );
  const sigB64 = btoa(String.fromCharCode(...new Uint8Array(sig)))
    .replace(/\+/g, '-')
    .replace(/\//g, '_')
    .replace(/=/g, '');
  return `${header}.${payload}.${sigB64}`;
}

const NOW = Math.floor(Date.now() / 1000);

// A single ES256 key pair shared by the claim suites below. Verification is
// asymmetric-only since the HS256 path was removed (2026-07-31), so tests whose
// subject is a *claim* — exp, iss, nbf, aud — still need a real signature to get
// past the signature check before the claim under test is reached.
/** Only ever used to *sign tokens that must be rejected*, plus parse-only tests. */
const FORGED_SECRET = 'test-jwt-secret-32-bytes-minimum!!';

let esKey: CryptoKey;
let esJwk: TestJwk;

beforeAll(async () => {
  const pair = await generateEs256KeyPair();
  esKey = pair.privateKey;
  esJwk = { ...pair.jwk, kid: TEST_KID, alg: 'ES256', use: 'sig' };
});

/** Reset the cache and serve the shared key set. Suites that assert on JWKS
 *  mechanics (caching, rotation, fetch failure) stub fetch themselves instead. */
function useSharedJwks(): void {
  resetJwksCache();
  vi.stubGlobal('fetch', async () => new Response(JSON.stringify({ keys: [esJwk] }), { status: 200 }));
}

// ---------------------------------------------------------------------------
// parseJwtPayload
// ---------------------------------------------------------------------------

describe('parseJwtPayload', () => {
  it('returns ok:false for a non-JWT string', () => {
    const result = parseJwtPayload('not-a-jwt');
    expect(result.ok).toBe(false);
  });

  it('returns ok:false for a JWT with invalid base64 payload', () => {
    const result = parseJwtPayload('header.!!!.sig');
    expect(result.ok).toBe(false);
  });

  it('returns ok:true and exposes parts for a well-formed JWT', async () => {
    const token = await buildJwt({ sub: 'u1', exp: NOW + 60, iat: NOW }, FORGED_SECRET);
    const result = parseJwtPayload(token);
    expect(result.ok).toBe(true);
    if (result.ok) {
      expect(result.payload.sub).toBe('u1');
      expect(result.parts).toHaveLength(3);
    }
  });
});

// ---------------------------------------------------------------------------
// verifyJwt — signature
// ---------------------------------------------------------------------------

describe('verifyJwt — signature', () => {
  beforeEach(useSharedJwks);
  afterEach(() => vi.unstubAllGlobals());

  it('rejects a tampered payload', async () => {
    const token = await buildEs256Jwt({ sub: 'u1', exp: NOW + 60, iat: NOW }, esKey);
    const [h, , s] = token.split('.');
    const tampered = `${h}.${b64url(JSON.stringify({ sub: 'attacker', exp: NOW + 60, iat: NOW }))}.${s}`;
    const result = await verifyJwt(tampered, { jwksUrl: JWKS_URL });
    expect(result.ok).toBe(false);
  });

  it('rejects a token signed by a key outside the published set', async () => {
    const attacker = await generateEs256KeyPair();
    const token = await buildEs256Jwt({ sub: 'u1', exp: NOW + 60, iat: NOW }, attacker.privateKey);
    const result = await verifyJwt(token, { jwksUrl: JWKS_URL });
    expect(result.ok).toBe(false);
  });

  it('accepts a validly signed token', async () => {
    const token = await buildEs256Jwt({ sub: 'u1', exp: NOW + 60, iat: NOW }, esKey);
    const result = await verifyJwt(token, { jwksUrl: JWKS_URL });
    expect(result.ok).toBe(true);
  });
});

// ---------------------------------------------------------------------------
// verifyJwt — exp claim
// ---------------------------------------------------------------------------

describe('verifyJwt — exp claim', () => {
  beforeEach(useSharedJwks);
  afterEach(() => vi.unstubAllGlobals());

  it('rejects an expired token', async () => {
    const token = await buildEs256Jwt({ sub: 'u1', exp: NOW - 1, iat: NOW - 120 }, esKey);
    const result = await verifyJwt(token, { jwksUrl: JWKS_URL });
    expect(result.ok).toBe(false);
  });

  it('accepts a non-expired token', async () => {
    const token = await buildEs256Jwt({ sub: 'u1', exp: NOW + 300, iat: NOW }, esKey);
    const result = await verifyJwt(token, { jwksUrl: JWKS_URL });
    expect(result.ok).toBe(true);
  });
});

// ---------------------------------------------------------------------------
// verifyJwt — exp missing or non-numeric
// ---------------------------------------------------------------------------

describe('verifyJwt — missing or non-numeric exp', () => {
  beforeEach(useSharedJwks);
  afterEach(() => vi.unstubAllGlobals());

  // Positive control. Every other assertion here is a rejection, so without this
  // the suite would still pass if the JWKS stub broke — the tokens would fail
  // signature verification and each `ok === false` would hold for the wrong
  // reason. This proves the rejections below are attributable to `exp`.
  it('accepts an otherwise identical token with a valid numeric exp', async () => {
    const token = await buildEs256Jwt({ sub: 'u1', exp: NOW + 60, iat: NOW }, esKey);
    expect((await verifyJwt(token, { jwksUrl: JWKS_URL })).ok).toBe(true);
  });

  it('rejects a token with no exp claim', async () => {
    // Build a token without exp; JwtPayload type has exp: number but JS allows omission.
    const token = await buildEs256Jwt({ sub: 'u1', iat: NOW } as Record<string, unknown>, esKey);
    const result = await verifyJwt(token, { jwksUrl: JWKS_URL });
    expect(result.ok).toBe(false);
  });

  it('rejects a token with a string exp claim', async () => {
    const token = await buildEs256Jwt({ sub: 'u1', exp: 'never', iat: NOW }, esKey);
    const result = await verifyJwt(token, { jwksUrl: JWKS_URL });
    expect(result.ok).toBe(false);
  });

  it('rejects a token with null exp claim', async () => {
    const token = await buildEs256Jwt({ sub: 'u1', exp: null, iat: NOW }, esKey);
    const result = await verifyJwt(token, { jwksUrl: JWKS_URL });
    expect(result.ok).toBe(false);
  });
});

// ---------------------------------------------------------------------------
// verifyJwt — iss claim (V-02, already done)
// ---------------------------------------------------------------------------

describe('verifyJwt — iss claim', () => {
  beforeEach(useSharedJwks);
  afterEach(() => vi.unstubAllGlobals());

  it('rejects a token whose iss does not match issuerUrl', async () => {
    const token = await buildEs256Jwt(
      { sub: 'u1', exp: NOW + 60, iat: NOW, iss: 'https://attacker.example' },
      esKey,
    );
    const result = await verifyJwt(token, { jwksUrl: JWKS_URL }, { issuerUrl: 'https://trusted.example' });
    expect(result.ok).toBe(false);
  });

  it('accepts a token with matching iss', async () => {
    const token = await buildEs256Jwt(
      { sub: 'u1', exp: NOW + 60, iat: NOW, iss: 'https://trusted.example' },
      esKey,
    );
    const result = await verifyJwt(token, { jwksUrl: JWKS_URL }, { issuerUrl: 'https://trusted.example' });
    expect(result.ok).toBe(true);
  });

  it('accepts a token when issuerUrl is not provided', async () => {
    const token = await buildEs256Jwt({ sub: 'u1', exp: NOW + 60, iat: NOW }, esKey);
    const result = await verifyJwt(token, { jwksUrl: JWKS_URL });
    expect(result.ok).toBe(true);
  });
});

// ---------------------------------------------------------------------------
// verifyJwt — nbf claim (V-06)
// ---------------------------------------------------------------------------

describe('verifyJwt — nbf claim (V-06)', () => {
  beforeEach(useSharedJwks);
  afterEach(() => vi.unstubAllGlobals());

  it('rejects a token with nbf more than 30s in the future', async () => {
    const token = await buildEs256Jwt(
      { sub: 'u1', exp: NOW + 600, iat: NOW, nbf: NOW + 60 },
      esKey,
    );
    const result = await verifyJwt(token, { jwksUrl: JWKS_URL });
    expect(result.ok).toBe(false);
  });

  it('accepts a token with nbf within the 30s clock-skew window', async () => {
    const token = await buildEs256Jwt(
      { sub: 'u1', exp: NOW + 600, iat: NOW, nbf: NOW + 25 },
      esKey,
    );
    const result = await verifyJwt(token, { jwksUrl: JWKS_URL });
    expect(result.ok).toBe(true);
  });

  it('accepts a token with nbf in the past', async () => {
    const token = await buildEs256Jwt(
      { sub: 'u1', exp: NOW + 600, iat: NOW, nbf: NOW - 60 },
      esKey,
    );
    const result = await verifyJwt(token, { jwksUrl: JWKS_URL });
    expect(result.ok).toBe(true);
  });

  it('accepts a token with no nbf claim', async () => {
    const token = await buildEs256Jwt({ sub: 'u1', exp: NOW + 60, iat: NOW }, esKey);
    const result = await verifyJwt(token, { jwksUrl: JWKS_URL });
    expect(result.ok).toBe(true);
  });

  it('accepts a token with nbf exactly at the 30s boundary', async () => {
    const token = await buildEs256Jwt(
      { sub: 'u1', exp: NOW + 600, iat: NOW, nbf: NOW + 30 },
      esKey,
    );
    const result = await verifyJwt(token, { jwksUrl: JWKS_URL });
    // nbf == now + 30 means nbf > now + 30 is false → should accept
    expect(result.ok).toBe(true);
  });
});

// ---------------------------------------------------------------------------
// verifyJwt — aud claim (V-18)
// ---------------------------------------------------------------------------

describe('verifyJwt — aud claim (V-18)', () => {
  beforeEach(useSharedJwks);
  afterEach(() => vi.unstubAllGlobals());

  it('rejects a token whose aud does not include the expected audience', async () => {
    const token = await buildEs256Jwt(
      { sub: 'u1', exp: NOW + 60, iat: NOW, aud: 'https://other.api' },
      esKey,
    );
    const result = await verifyJwt(token, { jwksUrl: JWKS_URL }, {
      audience: 'https://api.integritystudio.dev',
    });
    expect(result.ok).toBe(false);
  });

  it('rejects a token with an aud array that does not include the expected audience', async () => {
    const token = await buildEs256Jwt(
      { sub: 'u1', exp: NOW + 60, iat: NOW, aud: ['https://other.api', 'https://another.api'] },
      esKey,
    );
    const result = await verifyJwt(token, { jwksUrl: JWKS_URL }, {
      audience: 'https://api.integritystudio.dev',
    });
    expect(result.ok).toBe(false);
  });

  it('accepts a token with matching aud string', async () => {
    const token = await buildEs256Jwt(
      { sub: 'u1', exp: NOW + 60, iat: NOW, aud: 'https://api.integritystudio.dev' },
      esKey,
    );
    const result = await verifyJwt(token, { jwksUrl: JWKS_URL }, {
      audience: 'https://api.integritystudio.dev',
    });
    expect(result.ok).toBe(true);
  });

  it('accepts a token with aud array containing the expected audience', async () => {
    const token = await buildEs256Jwt(
      {
        sub: 'u1',
        exp: NOW + 60,
        iat: NOW,
        aud: ['https://api.integritystudio.dev', 'https://other.api'],
      },
      esKey,
    );
    const result = await verifyJwt(token, { jwksUrl: JWKS_URL }, {
      audience: 'https://api.integritystudio.dev',
    });
    expect(result.ok).toBe(true);
  });

  it('accepts a token with no aud claim when audience option is not provided', async () => {
    const token = await buildEs256Jwt({ sub: 'u1', exp: NOW + 60, iat: NOW }, esKey);
    const result = await verifyJwt(token, { jwksUrl: JWKS_URL });
    expect(result.ok).toBe(true);
  });

  it('rejects a token with no aud claim when audience option is provided', async () => {
    const token = await buildEs256Jwt({ sub: 'u1', exp: NOW + 60, iat: NOW }, esKey);
    const result = await verifyJwt(token, { jwksUrl: JWKS_URL }, {
      audience: 'https://api.integritystudio.dev',
    });
    expect(result.ok).toBe(false);
  });
});

// ---------------------------------------------------------------------------
// ES256 / JWKS verification
//
// Supabase issues ES256-signed tokens once a project migrates to asymmetric
// signing keys, at which point there is no shared secret to verify against —
// the signature is checked with the public key published at the project's JWKS
// endpoint. These tests use a locally generated P-256 key pair so no network
// access is required.
// ---------------------------------------------------------------------------

/** workers-types' JsonWebKey omits the JOSE registered members we need to set. */
type TestJwk = JsonWebKey & { kid?: string; alg?: string; use?: string };

const JWKS_URL = 'https://project.supabase.co/auth/v1/.well-known/jwks.json';
const TEST_KID = 'test-key-id-1';

function b64urlBytes(bytes: Uint8Array): string {
  return btoa(String.fromCharCode(...bytes)).replace(/\+/g, '-').replace(/\//g, '_').replace(/=/g, '');
}

async function generateEs256KeyPair(): Promise<{ privateKey: CryptoKey; jwk: TestJwk }> {
  // generateKey is typed as CryptoKey | CryptoKeyPair; ECDSA always yields a pair.
  const pair = (await crypto.subtle.generateKey({ name: 'ECDSA', namedCurve: 'P-256' }, true, [
    'sign',
    'verify',
  ])) as CryptoKeyPair;
  const jwk = (await crypto.subtle.exportKey('jwk', pair.publicKey)) as TestJwk;
  return { privateKey: pair.privateKey, jwk };
}

async function buildEs256Jwt(
  claims: Record<string, unknown>,
  privateKey: CryptoKey,
  header: Record<string, unknown> = { alg: 'ES256', typ: 'JWT', kid: TEST_KID },
): Promise<string> {
  const encodedHeader = b64url(JSON.stringify(header));
  const encodedPayload = b64url(JSON.stringify(claims));
  const sig = await crypto.subtle.sign(
    { name: 'ECDSA', hash: 'SHA-256' },
    privateKey,
    new TextEncoder().encode(`${encodedHeader}.${encodedPayload}`),
  );
  return `${encodedHeader}.${encodedPayload}.${b64urlBytes(new Uint8Array(sig))}`;
}

function futureClaims(extra: Record<string, unknown> = {}): Record<string, unknown> {
  return { sub: 'user-1', email: 'a@b.c', iat: NOW, exp: NOW + 3600, ...extra };
}

describe('verifyJwt — ES256 via JWKS', () => {
  let privateKey: CryptoKey;
  let jwk: TestJwk;
  let fetchCalls: number;

  /** Serve the key set from memory, counting calls so caching is observable. */
  function stubJwks(keys: TestJwk[], status = 200): void {
    fetchCalls = 0;
    vi.stubGlobal('fetch', async (url: string | URL) => {
      fetchCalls += 1;
      expect(String(url)).toBe(JWKS_URL);
      return new Response(JSON.stringify({ keys }), { status, headers: { 'content-type': 'application/json' } });
    });
  }

  beforeAll(async () => {
    const pair = await generateEs256KeyPair();
    privateKey = pair.privateKey;
    jwk = { ...pair.jwk, kid: TEST_KID, alg: 'ES256', use: 'sig' };
  });

  beforeEach(() => {
    resetJwksCache();
  });

  afterEach(() => {
    vi.unstubAllGlobals();
  });

  it('accepts a token signed by the published key', async () => {
    stubJwks([jwk]);
    const token = await buildEs256Jwt(futureClaims(), privateKey);
    const result = await verifyJwt(token, { jwksUrl: JWKS_URL });
    expect(result.ok).toBe(true);
    if (result.ok) expect(result.payload.sub).toBe('user-1');
  });

  it('still enforces exp, iss, and aud on asymmetric tokens', async () => {
    stubJwks([jwk]);
    const expired = await buildEs256Jwt(futureClaims({ exp: NOW - 1 }), privateKey);
    expect((await verifyJwt(expired, { jwksUrl: JWKS_URL })).ok).toBe(false);

    const token = await buildEs256Jwt(futureClaims({ iss: 'https://other.example' }), privateKey);
    expect((await verifyJwt(token, { jwksUrl: JWKS_URL }, { issuerUrl: 'https://project.supabase.co/auth/v1' })).ok).toBe(false);

    const wrongAud = await buildEs256Jwt(futureClaims({ aud: 'someone-else' }), privateKey);
    expect((await verifyJwt(wrongAud, { jwksUrl: JWKS_URL }, { audience: 'expected' })).ok).toBe(false);
  });

  it('rejects a token whose kid is not in the key set', async () => {
    stubJwks([{ ...jwk, kid: 'a-different-kid' }]);
    const token = await buildEs256Jwt(futureClaims(), privateKey);
    expect((await verifyJwt(token, { jwksUrl: JWKS_URL })).ok).toBe(false);
  });

  it('rejects an ES256 token with no kid header', async () => {
    stubJwks([jwk]);
    const token = await buildEs256Jwt(futureClaims(), privateKey, { alg: 'ES256', typ: 'JWT' });
    expect((await verifyJwt(token, { jwksUrl: JWKS_URL })).ok).toBe(false);
  });

  it('rejects a signature made by a different key', async () => {
    stubJwks([jwk]);
    const attacker = await generateEs256KeyPair();
    const token = await buildEs256Jwt(futureClaims(), attacker.privateKey);
    expect((await verifyJwt(token, { jwksUrl: JWKS_URL })).ok).toBe(false);
  });

  it('fails closed when the JWKS endpoint errors', async () => {
    stubJwks([], 500);
    const token = await buildEs256Jwt(futureClaims(), privateKey);
    expect((await verifyJwt(token, { jwksUrl: JWKS_URL })).ok).toBe(false);
  });

  it('caches the key set across verifications', async () => {
    stubJwks([jwk]);
    const token = await buildEs256Jwt(futureClaims(), privateKey);
    await verifyJwt(token, { jwksUrl: JWKS_URL });
    await verifyJwt(token, { jwksUrl: JWKS_URL });
    await verifyJwt(token, { jwksUrl: JWKS_URL });
    expect(fetchCalls).toBe(1);
  });

  it('refetches once when an unknown kid appears, so rotation is picked up', async () => {
    const rotatedKid = 'rotated-key-id';
    let served: TestJwk[] = [{ ...jwk, kid: 'stale-kid' }];
    fetchCalls = 0;
    vi.stubGlobal('fetch', async () => {
      fetchCalls += 1;
      return new Response(JSON.stringify({ keys: served }), { status: 200 });
    });

    const token = await buildEs256Jwt(futureClaims(), privateKey, { alg: 'ES256', typ: 'JWT', kid: rotatedKid });
    expect((await verifyJwt(token, { jwksUrl: JWKS_URL })).ok).toBe(false);
    const callsAfterMiss = fetchCalls;
    expect(callsAfterMiss).toBeGreaterThan(1); // initial fetch + one refetch on unknown kid

    served = [{ ...jwk, kid: rotatedKid }];
    resetJwksCache();
    const result = await verifyJwt(token, { jwksUrl: JWKS_URL });
    expect(result.ok).toBe(true);
  });
});

describe('verifyJwt — algorithm confusion defences', () => {
  let privateKey: CryptoKey;
  let jwk: TestJwk;

  beforeAll(async () => {
    const pair = await generateEs256KeyPair();
    privateKey = pair.privateKey;
    jwk = { ...pair.jwk, kid: TEST_KID, alg: 'ES256', use: 'sig' };
  });

  beforeEach(() => {
    resetJwksCache();
    vi.stubGlobal('fetch', async () => new Response(JSON.stringify({ keys: [jwk] }), { status: 200 }));
  });

  afterEach(() => {
    vi.unstubAllGlobals();
  });

  it('refuses an HS256 token outright — the algorithm is not in the allowlist', async () => {
    // The classic attack: sign with the public key as if it were a shared secret.
    // Since 2026-07-31 there is no symmetric path at all, so this is rejected by
    // the allowlist rather than by "no secret happens to be configured" — the
    // property no longer depends on how the caller built its key.
    const token = await buildJwt(futureClaims(), JSON.stringify(jwk));
    expect((await verifyJwt(token, { jwksUrl: JWKS_URL })).ok).toBe(false);
  });

  it('rejects alg: none', async () => {
    const header = b64url(JSON.stringify({ alg: 'none', typ: 'JWT' }));
    const payload = b64url(JSON.stringify(futureClaims()));
    expect((await verifyJwt(`${header}.${payload}.`, { jwksUrl: JWKS_URL })).ok).toBe(false);
  });

  it('rejects an unlisted algorithm', async () => {
    const token = await buildEs256Jwt(futureClaims(), privateKey, { alg: 'ES384', typ: 'JWT', kid: TEST_KID });
    expect((await verifyJwt(token, { jwksUrl: JWKS_URL })).ok).toBe(false);
  });
});


// ---------------------------------------------------------------------------
// The removed symmetric path stays removed
//
// Ported from the suites that used to document the HS256 fallback
// (`supabaseJwtKey`'s "carries the legacy secret as a fallback" / "falls back to
// a bare secret", and "rejects an ES256 token when only an HMAC secret is
// configured"). Those asserted the fallback existed; these assert it cannot come
// back unnoticed, which is the property worth keeping.
//
// Written deliberately against shapes TypeScript now forbids, hence the casts: a
// type cannot fail at runtime. If someone widens JwtVerificationKey again or
// re-adds an hmacSecret read, the compiler goes quiet and only these notice.
// ---------------------------------------------------------------------------

describe('verifyJwt — the symmetric path stays removed', () => {
  beforeEach(useSharedJwks);
  afterEach(() => vi.unstubAllGlobals());

  it('does not treat a bare-string key as an HMAC secret', async () => {
    const token = await buildJwt(futureClaims(), FORGED_SECRET);
    const key = FORGED_SECRET as unknown as JwtVerificationKey;
    expect((await verifyJwt(token, key)).ok).toBe(false);
  });

  it('does not verify an HS256 token against an hmacSecret smuggled onto the key', async () => {
    const token = await buildJwt(futureClaims(), FORGED_SECRET);
    const key = { jwksUrl: JWKS_URL, hmacSecret: FORGED_SECRET } as unknown as JwtVerificationKey;
    expect((await verifyJwt(token, key)).ok).toBe(false);
  });

  it('rejects rather than throws when handed a bare-string key with an ES256 token', async () => {
    // The direct port of "rejects an ES256 token when only an HMAC secret is
    // configured": there is no jwksUrl to resolve, so it must fail closed as a
    // 401 rather than surface as an unhandled error.
    const token = await buildEs256Jwt(futureClaims(), esKey);
    const key = FORGED_SECRET as unknown as JwtVerificationKey;
    await expect(verifyJwt(token, key)).resolves.toMatchObject({ ok: false });
  });
});

describe('auth0JwtKey', () => {
  it('builds the tenant JWKS URL from a bare host', () => {
    expect(auth0JwtKey({ auth0Domain: 'tenant.us.auth0.com' })).toEqual({
      jwksUrl: 'https://tenant.us.auth0.com/.well-known/jwks.json',
    });
  });

  // AUTH0_DOMAIN is spelled as a host in some places and a full origin in others; a doubled
  // scheme would produce a URL that 404s and surface as an opaque "Invalid JWT signature".
  it('normalises a full origin and a trailing slash to the same URL', () => {
    const expected = { jwksUrl: 'https://tenant.us.auth0.com/.well-known/jwks.json' };
    expect(auth0JwtKey({ auth0Domain: 'https://tenant.us.auth0.com' })).toEqual(expected);
    expect(auth0JwtKey({ auth0Domain: 'https://tenant.us.auth0.com/' })).toEqual(expected);
  });

  // No hmacSecret: Auth0 signs with RS256 only, so a symmetric fallback would add an
  // unreachable path while widening the algorithm-confusion surface.
  it('never offers an HMAC fallback', () => {
    expect(auth0JwtKey({ auth0Domain: 'tenant.us.auth0.com' })).not.toHaveProperty('hmacSecret');
  });

  it('fails closed rather than throwing when the domain is unset', () => {
    // An unbound AUTH0_DOMAIN must not turn every request into a 500.
    expect(() => auth0JwtKey({ auth0Domain: '' })).not.toThrow();
  });
});

describe('auth0IssuerFor', () => {
  // verifyJwt compares `iss` by exact string equality and Auth0 emits the trailing slash,
  // so dropping it would reject every otherwise-valid token.
  it('includes the trailing slash Auth0 emits', () => {
    expect(auth0IssuerFor('tenant.us.auth0.com')).toBe('https://tenant.us.auth0.com/');
  });

  it('does not double the scheme when given an origin', () => {
    expect(auth0IssuerFor('https://tenant.us.auth0.com')).toBe('https://tenant.us.auth0.com/');
  });
});
