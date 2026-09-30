import { REPLAY_WINDOW_MS } from '../../constants';
import { hmacVerify } from '../../lib/crypto';
import { hexToBytes } from '../../lib/hex-utils';
import { json } from '../../lib/http/responses';

export interface Env {
  // Retired — SIGNING_KEYS is the sole authority (CR29, closed 2026-08-03; the production
  // receiver unbound this the same day). Kept declared, and kept set in the test fixtures,
  // so the tests prove a keyless request is rejected even with the credential present —
  // "unreachable" rather than merely "absent". Do not tidy it out.
  SHARED_SECRET: string;
  // JSON-encoded Record<string, string> mapping keyId → secret. Required, mirroring the
  // production receiver: it is the only credential /inbox authenticates against, so an
  // unbound map 401s every request. Optional here would let a test pass against a config
  // production rejects — the shape parity is the point of a test double.
  SIGNING_KEYS: string;
}

export interface HealthResponse {
  ok: boolean;
  service: string;
}

/** The production receiver's `ProvisionApiKeyResponse` (observability-toolkit), so a
 *  client built against this stub reads the field production sends. */
export interface InboxSuccessResponse {
  ok: boolean;
  token: string;
  keyId: string;
  prefix: string;
  tier: string;
}

export interface SignInStubResponse {
  ok: boolean;
  user: { userId: string; email: string };
  organizations: never[];
  apiKeys: never[];
}

export interface ErrorResponse {
  error: string;
}

/** Production's key format (observability-toolkit receiver): `obtk_` + 32 random bytes as hex. */
const TOKEN_NAMESPACE = 'obtk_';
const TOKEN_SECRET_BYTES = 32;
/** The stored prefix is the secret's first 8 hex characters, not the namespace. */
const TOKEN_PREFIX_LENGTH = 8;
/** First provisions are always starter (CR37). */
const STUB_TIER = 'starter';

const ACTIONS = {
  PROVISION_API_KEY: 'provision_api_key',
  SIGN_IN: 'sign_in',
} as const;
type KnownAction = (typeof ACTIONS)[keyof typeof ACTIONS];
const KNOWN_ACTIONS: readonly string[] = [ACTIONS.PROVISION_API_KEY, ACTIONS.SIGN_IN];

/**
 * Resolve the signing secret for a request. Every miss returns null, and `handleInbox`
 * turns that into the same 401 an invalid signature gets.
 * - No x-key-id → miss. It used to resolve to SHARED_SECRET, a credential with no key id
 *   and therefore no rotation handle: production measurably answered 200 to a keyless
 *   request, so removing a key from SIGNING_KEYS revoked nothing. Mirrors the production
 *   receiver as of CR29 step 2 — a stub that still accepted keyless requests would let a
 *   test pass on traffic production rejects.
 * - x-key-id present → look up in SIGNING_KEYS JSON map; null if unknown or map absent
 */
export function resolveSigningKey(env: Env, keyId: string | undefined): string | null {
  if (keyId === undefined) return null;
  // Empty/whitespace keyId is a miss for the same reason, and was already one before
  // step 2 — otherwise `x-key-id: ""` bypassed rotation.
  if (keyId.trim() === '') return null;
  if (!env.SIGNING_KEYS) return null;
  let keys: Record<string, string>;
  try {
    keys = JSON.parse(env.SIGNING_KEYS) as Record<string, string>;
  } catch {
    return null;
  }
  if (typeof keys !== 'object' || keys === null || Array.isArray(keys)) return null;
  return keys[keyId] ?? null;
}

async function handleInbox(request: Request, env: Env): Promise<Response> {
  const timestampHeader = request.headers.get('x-timestamp');
  const signatureHeader = request.headers.get('x-signature');
  const keyIdHeader = request.headers.get('x-key-id') ?? undefined;

  if (!timestampHeader || !signatureHeader) {
    return json({ error: 'missing auth headers' }, { status: 401 });
  }

  const ts = Number(timestampHeader);
  if (isNaN(ts) || Math.abs(Date.now() - ts) > REPLAY_WINDOW_MS) {
    return json({ error: 'stale or invalid timestamp' }, { status: 401 });
  }

  const secret = resolveSigningKey(env, keyIdHeader);
  if (!secret) {
    return json({ error: 'invalid signature' }, { status: 401 });
  }

  const rawBody = await request.text();

  const sigBytes = hexToBytes(signatureHeader);
  if (!sigBytes || !await hmacVerify(secret, sigBytes, `${timestampHeader}.${rawBody}`)) {
    return json({ error: 'invalid signature' }, { status: 401 });
  }

  let parsed: unknown;
  try {
    parsed = JSON.parse(rawBody);
  } catch {
    return json({ error: 'invalid json' }, { status: 400 });
  }

  if (typeof parsed !== 'object' || parsed === null || Array.isArray(parsed)) {
    return json({ error: 'invalid payload' }, { status: 400 });
  }

  const payload = parsed as Record<string, unknown>;
  const action = typeof payload.action === 'string' ? payload.action : undefined;
  if (!action || !KNOWN_ACTIONS.includes(action)) {
    return json({ error: 'unknown action' }, { status: 400 });
  }

  if ((action as KnownAction) === ACTIONS.SIGN_IN) {
    const email = typeof payload.email === 'string' ? payload.email : '';
    return json({
      ok: true,
      user: { userId: crypto.randomUUID(), email },
      organizations: [],
      apiKeys: [],
    });
  }

  const tokenHex = [...crypto.getRandomValues(new Uint8Array(TOKEN_SECRET_BYTES))]
    .map((b) => b.toString(16).padStart(2, '0'))
    .join('');
  const response: InboxSuccessResponse = {
    ok: true,
    token: `${TOKEN_NAMESPACE}${tokenHex}`,
    keyId: crypto.randomUUID(),
    prefix: tokenHex.slice(0, TOKEN_PREFIX_LENGTH),
    tier: STUB_TIER,
  };
  return json(response);
}

export default {
  async fetch(request: Request, env: Env): Promise<Response> {
    const { pathname } = new URL(request.url);

    if (pathname === '/health' && request.method === 'GET') {
      return json({ ok: true, service: 'receiver-worker' });
    }

    if (pathname === '/inbox' && request.method === 'POST') {
      return handleInbox(request, env);
    }

    return json({ error: 'not found' }, { status: 404 });
  },
};
