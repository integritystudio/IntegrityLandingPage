import { hexToBytes } from './hex-utils';
import { unauthorized } from './http';
import type { SupabaseClient } from './supabase';
import type { ApiKey } from './types';

export const API_KEY_PREFIX = 'int_live_';

/**
 * Matches int_live_{8+ alphanum prefix}_{16+ char secret}
 * Capture groups: [prefix, secret]
 */
export const API_KEY_REGEX = /^int_live_([A-Za-z0-9]{8,})_([A-Za-z0-9]{16,})$/;

const HEX_CHARS = '0123456789abcdef';
const ALPHANUM_CHARS = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789';

function randomAlphanum(length: number): string {
  const values = crypto.getRandomValues(new Uint8Array(length));
  return Array.from(values, (b) => ALPHANUM_CHARS[b % ALPHANUM_CHARS.length]).join('');
}

export type ParseApiKeyResult =
  | { ok: true; prefix: string; secret: string }
  | { ok: false };

export function parseApiKey(token: string): ParseApiKeyResult {
  const match = API_KEY_REGEX.exec(token);
  if (!match) return { ok: false };
  return { ok: true, prefix: match[1], secret: match[2] };
}

export async function hashApiKeySecret(secret: string, hmacSecret: string): Promise<string> {
  const key = await crypto.subtle.importKey(
    'raw',
    new TextEncoder().encode(hmacSecret),
    { name: 'HMAC', hash: 'SHA-256' },
    false,
    ['sign'],
  );
  const signature = await crypto.subtle.sign('HMAC', key, new TextEncoder().encode(secret));
  return Array.from(new Uint8Array(signature), (b) => HEX_CHARS[b >> 4] + HEX_CHARS[b & 0xf]).join('');
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

  const encoder = new TextEncoder();
  const key = await crypto.subtle.importKey(
    'raw',
    encoder.encode(hmacSecret),
    { name: 'HMAC', hash: 'SHA-256' },
    false,
    ['verify'],
  );

  try {
    return await crypto.subtle.verify('HMAC', key, storedBytes, encoder.encode(secret));
  } catch {
    return false;
  }
}

export type VerifyApiKeyResult =
  | { ok: true; apiKey: ApiKey; userId: string; organizationId: string }
  | { ok: false; error: Response };

export async function verifyApiKey(
  token: string,
  hmacSecret: string,
  sb: SupabaseClient,
): Promise<VerifyApiKeyResult> {
  const parsed = parseApiKey(token);
  if (!parsed.ok) return { ok: false, error: unauthorized('Invalid API key format') };

  const { prefix, secret } = parsed;

  const result = await sb.query<ApiKey>('api_keys', {
    filters: [{ column: 'prefix', operator: 'eq', value: prefix }],
    limit: 1,
  });

  if (!result.ok || !Array.isArray(result.data) || result.data.length === 0) {
    return { ok: false, error: unauthorized('API key not found') };
  }

  const apiKey = result.data[0];

  if (apiKey.status !== 'active' || apiKey.revoked_at !== null) {
    return { ok: false, error: unauthorized('API key is revoked') };
  }

  if (apiKey.expires_at !== null && new Date(apiKey.expires_at) < new Date()) {
    return { ok: false, error: unauthorized('API key is expired') };
  }

  const valid = await verifyApiKeyHash(secret, apiKey.hash, hmacSecret);
  if (!valid) return { ok: false, error: unauthorized('Invalid API key') };

  return { ok: true, apiKey, userId: apiKey.user_id, organizationId: apiKey.organization_id };
}

export interface GeneratedApiKey {
  token: string;
  prefix: string;
  secret: string;
}

export function generateApiKey(): GeneratedApiKey {
  const prefix = randomAlphanum(8);
  const secret = randomAlphanum(32);
  const token = `${API_KEY_PREFIX}${prefix}_${secret}`;
  return { token, prefix, secret };
}
