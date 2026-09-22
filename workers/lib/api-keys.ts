import { hmacSignHex, hmacVerify, sha256Hex } from './crypto';
import { hexToBytes } from './hex-utils';
import { unauthorized } from './http';
import type { SupabaseClient } from './supabase';
import type { ApiKey } from './types';

/**
 * Two key formats reach this Worker, because two issuers write `public.api_keys`.
 *
 * `obtk_` is what the platform actually issues: the Supabase edge functions
 * (`api-keys-create`, `api-keys-rotate`) and the provisioning receiver in
 * observability-toolkit all mint it, it is what `obtool-api`/`obtool-ingest`
 * accept, and all six live rows carry it. Its digest is `sha256(<whole token>)`,
 * stored in `api_keys.hash` and keyed as `apikey:<sha256>` in the obtool `AUTH`
 * KV namespace. There is no separable secret half — the token IS the secret.
 *
 * `int_live_` is minted by exactly one caller, this gateway's own
 * `POST /v1/orgs/:id/api-keys`, and hashes an HMAC of its secret half under
 * `API_KEY_HMAC_SECRET`. No live row uses it.
 *
 * Until 2026-09-21 only `int_live_` parsed, so every real key was rejected
 * before the quota step — `GET /v1/orgs/:id/entitlements` with a valid growth
 * key answered `401 Invalid JWT format`, because a token that fails the API-key
 * regex falls through to the JWT branch (BACKLOG UA07).
 */
export const OBTOOL_API_KEY_PREFIX = 'obtk_';

/** Matches obtk_{64 lowercase hex}. Capture group: [hex body]. */
export const OBTOOL_API_KEY_REGEX = /^obtk_([0-9a-f]{64})$/;

/** Leading hex characters of the body that `api_keys.prefix` stores for display. */
const OBTOOL_PREFIX_LENGTH = 8;

export const API_KEY_PREFIX = 'int_live_';

/**
 * Matches int_live_{8+ alphanum prefix}_{16+ char secret}
 * Capture groups: [prefix, secret]
 */
export const API_KEY_REGEX = /^int_live_([A-Za-z0-9]{8,})_([A-Za-z0-9]{16,})$/;

const ALPHANUM_CHARS = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789';

function randomAlphanum(length: number): string {
  const values = crypto.getRandomValues(new Uint8Array(length));
  return Array.from(values, (b) => ALPHANUM_CHARS[b % ALPHANUM_CHARS.length]).join('');
}

/**
 * Discriminated on `format` rather than carrying an optional `secret`, because
 * only the legacy format HAS a separable secret. A caller that reads `secret`
 * must therefore say which format it means, instead of silently getting
 * `undefined` for an `obtk_` token and hashing it.
 */
export type ParseApiKeyResult =
  | { ok: true; format: 'obtool'; prefix: string }
  | { ok: true; format: 'legacy'; prefix: string; secret: string }
  | { ok: false };

export function parseApiKey(token: string): ParseApiKeyResult {
  const obtool = OBTOOL_API_KEY_REGEX.exec(token);
  if (obtool) {
    return { ok: true, format: 'obtool', prefix: obtool[1].slice(0, OBTOOL_PREFIX_LENGTH) };
  }
  const legacy = API_KEY_REGEX.exec(token);
  if (legacy) return { ok: true, format: 'legacy', prefix: legacy[1], secret: legacy[2] };
  return { ok: false };
}

/**
 * The `api_keys.hash` value for an `obtk_` token: `sha256(<whole token>)`.
 * Mirrors `api-keys-create`/`api-keys-rotate` in the Supabase functions and
 * `sha256Hex` in the obtool Workers' shared `token-hash.ts`; the three must
 * agree or a key verifies in one place and not another.
 */
export async function hashApiKeyToken(token: string): Promise<string> {
  return sha256Hex(token);
}

export async function hashApiKeySecret(secret: string, hmacSecret: string): Promise<string> {
  return hmacSignHex(hmacSecret, secret);
}

/**
 * Verify an API key secret against a stored HMAC-SHA256 hash using a
 * constant-time comparison to prevent timing side-channel attacks.
 */
export async function verifyApiKeyHash(
  secret: string,
  storedHash: string,
  hmacSecret: string,
): Promise<boolean> {
  const storedBytes = hexToBytes(storedHash);
  if (!storedBytes) return false;
  return hmacVerify(hmacSecret, storedBytes, secret);
}

export type VerifyApiKeyResult =
  | { ok: true; apiKey: ApiKey; userId: string; organizationId: string }
  | { ok: false; error: Response };

/**
 * `hmacSecret` is consulted only for the legacy `int_live_` format; an `obtk_`
 * token is verified against a digest that keys on nothing. The parameter stays
 * required so the four call sites keep one shape, and because they already hold
 * the secret by the time they get here.
 */
export async function verifyApiKey(
  token: string,
  hmacSecret: string,
  sb: SupabaseClient,
): Promise<VerifyApiKeyResult> {
  const parsed = parseApiKey(token);
  if (!parsed.ok) return { ok: false, error: unauthorized('Invalid API key format') };

  // An `obtk_` token is looked up BY its digest, which `api_keys_hash_key`
  // makes unique — no candidate row, no comparison, so no timing channel and
  // no prefix collision. `prefix` is unique only per `(organization_id,
  // prefix)`, so the legacy lookup below can in principle draw another org's
  // row and reject a valid key; that hazard does not apply here.
  const result = parsed.format === 'obtool'
    ? await sb.query<ApiKey>('api_keys', {
        filters: [{ column: 'hash', operator: 'eq', value: await hashApiKeyToken(token) }],
        limit: 1,
      })
    : await sb.query<ApiKey>('api_keys', {
        filters: [{ column: 'prefix', operator: 'eq', value: parsed.prefix }],
        limit: 1,
      });

  if (!result.ok || result.data.length === 0) {
    return { ok: false, error: unauthorized('API key not found') };
  }

  const apiKey = result.data[0];

  if (apiKey.status !== 'active' || apiKey.revoked_at !== null) {
    return { ok: false, error: unauthorized('API key is revoked') };
  }

  if (apiKey.expires_at !== null && new Date(apiKey.expires_at) < new Date()) {
    return { ok: false, error: unauthorized('API key is expired') };
  }

  // The obtool lookup already matched on the digest; only the legacy format
  // still has a secret to check against a candidate row.
  if (parsed.format === 'legacy') {
    const valid = await verifyApiKeyHash(parsed.secret, apiKey.hash, hmacSecret);
    if (!valid) return { ok: false, error: unauthorized('Invalid API key') };
  }

  return { ok: true, apiKey, userId: apiKey.user_id, organizationId: apiKey.organization_id };
}

export interface GeneratedApiKey {
  token: string;
  prefix: string;
  secret: string;
}

/**
 * Mints the legacy `int_live_` format, deliberately (BACKLOG UA07 follow-up).
 *
 * Switching this to `obtk_` would hand back a token that passes THIS gateway
 * and fails `obtool-api`/`obtool-ingest`, because those resolve a key through
 * the `AUTH` KV record that only the Supabase edge functions write and this
 * Worker has no Cloudflare credentials to write. A format that promises
 * interoperability it does not have is worse than an honestly separate one, so
 * unifying issuance waits on this route either writing that record or being
 * retired in favour of `api-keys-create`.
 */
export function generateApiKey(): GeneratedApiKey {
  const prefix = randomAlphanum(8);
  const secret = randomAlphanum(32);
  const token = `${API_KEY_PREFIX}${prefix}_${secret}`;
  return { token, prefix, secret };
}
