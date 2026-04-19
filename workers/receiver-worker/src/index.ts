import { REPLAY_WINDOW_MS } from '../../constants';
import { hmacVerify } from '../../lib/crypto';
import { hexToBytes } from '../../lib/hex-utils';
import { json } from '../../lib/http/responses';

export interface Env {
  SHARED_SECRET: string;
  // JSON-encoded Record<string, string> mapping keyId → secret; enables x-key-id rotation.
  SIGNING_KEYS?: string;
}

export interface HealthResponse {
  ok: boolean;
  service: string;
}

export interface InboxSuccessResponse {
  ok: boolean;
  apiKey: string;
  received: Record<string, unknown>;
}

export interface ErrorResponse {
  error: string;
}

/**
 * Resolve the signing secret for a request.
 * - No x-key-id → use SHARED_SECRET (backward compat)
 * - x-key-id present → look up in SIGNING_KEYS JSON map; returns null if unknown or map absent
 */
export function resolveSigningKey(env: Env, keyId: string | undefined): string | null {
  if (!keyId) return env.SHARED_SECRET;
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

  const apiKey = `sk-${crypto.randomUUID().replace(/-/g, '')}`;
  return json({ ok: true, apiKey, received: parsed });
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
