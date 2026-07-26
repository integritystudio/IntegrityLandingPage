import { describe, it, expect } from 'vitest';
import { verifyJwt, parseJwtPayload } from './auth';

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

/** Base64url-encode a string without padding. */
function b64url(s: string): string {
  return btoa(s).replace(/\+/g, '-').replace(/\//g, '_').replace(/=/g, '');
}

/** Build a compact JWT (header.payload.signature) signed with HS256. */
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

const SECRET = 'test-jwt-secret-32-bytes-minimum!!';
const NOW = Math.floor(Date.now() / 1000);

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
    const token = await buildJwt({ sub: 'u1', exp: NOW + 60, iat: NOW }, SECRET);
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
  it('rejects a tampered payload', async () => {
    const token = await buildJwt({ sub: 'u1', exp: NOW + 60, iat: NOW }, SECRET);
    const [h, , s] = token.split('.');
    const tampered = `${h}.${b64url(JSON.stringify({ sub: 'attacker', exp: NOW + 60, iat: NOW }))}.${s}`;
    const result = await verifyJwt(tampered, SECRET);
    expect(result.ok).toBe(false);
  });

  it('rejects a token signed with a different secret', async () => {
    const token = await buildJwt({ sub: 'u1', exp: NOW + 60, iat: NOW }, 'wrong-secret');
    const result = await verifyJwt(token, SECRET);
    expect(result.ok).toBe(false);
  });

  it('accepts a validly signed token', async () => {
    const token = await buildJwt({ sub: 'u1', exp: NOW + 60, iat: NOW }, SECRET);
    const result = await verifyJwt(token, SECRET);
    expect(result.ok).toBe(true);
  });
});

// ---------------------------------------------------------------------------
// verifyJwt — exp claim
// ---------------------------------------------------------------------------

describe('verifyJwt — exp claim', () => {
  it('rejects an expired token', async () => {
    const token = await buildJwt({ sub: 'u1', exp: NOW - 1, iat: NOW - 120 }, SECRET);
    const result = await verifyJwt(token, SECRET);
    expect(result.ok).toBe(false);
  });

  it('accepts a non-expired token', async () => {
    const token = await buildJwt({ sub: 'u1', exp: NOW + 300, iat: NOW }, SECRET);
    const result = await verifyJwt(token, SECRET);
    expect(result.ok).toBe(true);
  });
});

// ---------------------------------------------------------------------------
// verifyJwt — exp missing or non-numeric
// ---------------------------------------------------------------------------

describe('verifyJwt — missing or non-numeric exp', () => {
  it('rejects a token with no exp claim', async () => {
    // Build a token without exp; JwtPayload type has exp: number but JS allows omission.
    const token = await buildJwt({ sub: 'u1', iat: NOW } as Record<string, unknown>, SECRET);
    const result = await verifyJwt(token, SECRET);
    expect(result.ok).toBe(false);
  });

  it('rejects a token with a string exp claim', async () => {
    const token = await buildJwt({ sub: 'u1', exp: 'never', iat: NOW }, SECRET);
    const result = await verifyJwt(token, SECRET);
    expect(result.ok).toBe(false);
  });

  it('rejects a token with null exp claim', async () => {
    const token = await buildJwt({ sub: 'u1', exp: null, iat: NOW }, SECRET);
    const result = await verifyJwt(token, SECRET);
    expect(result.ok).toBe(false);
  });
});

// ---------------------------------------------------------------------------
// verifyJwt — iss claim (V-02, already done)
// ---------------------------------------------------------------------------

describe('verifyJwt — iss claim', () => {
  it('rejects a token whose iss does not match issuerUrl', async () => {
    const token = await buildJwt(
      { sub: 'u1', exp: NOW + 60, iat: NOW, iss: 'https://attacker.example' },
      SECRET,
    );
    const result = await verifyJwt(token, SECRET, { issuerUrl: 'https://trusted.example' });
    expect(result.ok).toBe(false);
  });

  it('accepts a token with matching iss', async () => {
    const token = await buildJwt(
      { sub: 'u1', exp: NOW + 60, iat: NOW, iss: 'https://trusted.example' },
      SECRET,
    );
    const result = await verifyJwt(token, SECRET, { issuerUrl: 'https://trusted.example' });
    expect(result.ok).toBe(true);
  });

  it('accepts a token when issuerUrl is not provided', async () => {
    const token = await buildJwt({ sub: 'u1', exp: NOW + 60, iat: NOW }, SECRET);
    const result = await verifyJwt(token, SECRET);
    expect(result.ok).toBe(true);
  });
});

// ---------------------------------------------------------------------------
// verifyJwt — nbf claim (V-06)
// ---------------------------------------------------------------------------

describe('verifyJwt — nbf claim (V-06)', () => {
  it('rejects a token with nbf more than 30s in the future', async () => {
    const token = await buildJwt(
      { sub: 'u1', exp: NOW + 600, iat: NOW, nbf: NOW + 60 },
      SECRET,
    );
    const result = await verifyJwt(token, SECRET);
    expect(result.ok).toBe(false);
  });

  it('accepts a token with nbf within the 30s clock-skew window', async () => {
    const token = await buildJwt(
      { sub: 'u1', exp: NOW + 600, iat: NOW, nbf: NOW + 25 },
      SECRET,
    );
    const result = await verifyJwt(token, SECRET);
    expect(result.ok).toBe(true);
  });

  it('accepts a token with nbf in the past', async () => {
    const token = await buildJwt(
      { sub: 'u1', exp: NOW + 600, iat: NOW, nbf: NOW - 60 },
      SECRET,
    );
    const result = await verifyJwt(token, SECRET);
    expect(result.ok).toBe(true);
  });

  it('accepts a token with no nbf claim', async () => {
    const token = await buildJwt({ sub: 'u1', exp: NOW + 60, iat: NOW }, SECRET);
    const result = await verifyJwt(token, SECRET);
    expect(result.ok).toBe(true);
  });

  it('accepts a token with nbf exactly at the 30s boundary', async () => {
    const token = await buildJwt(
      { sub: 'u1', exp: NOW + 600, iat: NOW, nbf: NOW + 30 },
      SECRET,
    );
    const result = await verifyJwt(token, SECRET);
    // nbf == now + 30 means nbf > now + 30 is false → should accept
    expect(result.ok).toBe(true);
  });
});

// ---------------------------------------------------------------------------
// verifyJwt — aud claim (V-18)
// ---------------------------------------------------------------------------

describe('verifyJwt — aud claim (V-18)', () => {
  it('rejects a token whose aud does not include the expected audience', async () => {
    const token = await buildJwt(
      { sub: 'u1', exp: NOW + 60, iat: NOW, aud: 'https://other.api' },
      SECRET,
    );
    const result = await verifyJwt(token, SECRET, {
      audience: 'https://api.integritystudio.dev',
    });
    expect(result.ok).toBe(false);
  });

  it('rejects a token with an aud array that does not include the expected audience', async () => {
    const token = await buildJwt(
      { sub: 'u1', exp: NOW + 60, iat: NOW, aud: ['https://other.api', 'https://another.api'] },
      SECRET,
    );
    const result = await verifyJwt(token, SECRET, {
      audience: 'https://api.integritystudio.dev',
    });
    expect(result.ok).toBe(false);
  });

  it('accepts a token with matching aud string', async () => {
    const token = await buildJwt(
      { sub: 'u1', exp: NOW + 60, iat: NOW, aud: 'https://api.integritystudio.dev' },
      SECRET,
    );
    const result = await verifyJwt(token, SECRET, {
      audience: 'https://api.integritystudio.dev',
    });
    expect(result.ok).toBe(true);
  });

  it('accepts a token with aud array containing the expected audience', async () => {
    const token = await buildJwt(
      {
        sub: 'u1',
        exp: NOW + 60,
        iat: NOW,
        aud: ['https://api.integritystudio.dev', 'https://other.api'],
      },
      SECRET,
    );
    const result = await verifyJwt(token, SECRET, {
      audience: 'https://api.integritystudio.dev',
    });
    expect(result.ok).toBe(true);
  });

  it('accepts a token with no aud claim when audience option is not provided', async () => {
    const token = await buildJwt({ sub: 'u1', exp: NOW + 60, iat: NOW }, SECRET);
    const result = await verifyJwt(token, SECRET);
    expect(result.ok).toBe(true);
  });

  it('rejects a token with no aud claim when audience option is provided', async () => {
    const token = await buildJwt({ sub: 'u1', exp: NOW + 60, iat: NOW }, SECRET);
    const result = await verifyJwt(token, SECRET, {
      audience: 'https://api.integritystudio.dev',
    });
    expect(result.ok).toBe(false);
  });
});
