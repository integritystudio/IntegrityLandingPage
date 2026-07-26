import { json } from "../../lib/http/responses.js";
import {
  AUTH_RATE_LIMIT_MAX,
  AUTH_RATE_LIMIT_WINDOW_SECONDS,
  CORS_HEADERS,
  HEADER_NAMES,
  HTTP_STATUS,
  type Env,
} from "./types.js";

export function errorResponse(error: string, code: string, status: number): Response {
  return json({ error, code }, { status });
}

/** Real client IP from the inbound edge request; undefined if unavailable. */
export function getClientIp(request: Request): string | undefined {
  return (
    request.headers.get(HEADER_NAMES.CF_CONNECTING_IP) ??
    request.headers.get(HEADER_NAMES.X_FORWARDED_FOR) ??
    undefined
  );
}

/**
 * Resolve the outbound signing key and key ID.
 * - ACTIVE_KEY_ID set + SIGNING_KEYS contains it → use rotated key, send x-key-id
 * - Otherwise → fall back to SHARED_SECRET, no x-key-id header
 */
export function resolveOutboundSigningKey(env: Env): { secret: string; keyId: string | undefined } {
  if (env.ACTIVE_KEY_ID && env.SIGNING_KEYS) {
    let keys: Record<string, string>;
    try {
      keys = JSON.parse(env.SIGNING_KEYS) as Record<string, string>;
    } catch {
      console.error('[resolveOutboundSigningKey] SIGNING_KEYS is not valid JSON; falling back to SHARED_SECRET');
      return { secret: env.SHARED_SECRET, keyId: undefined };
    }
    const secret = keys[env.ACTIVE_KEY_ID];
    if (secret) return { secret, keyId: env.ACTIVE_KEY_ID };
    console.warn(`[resolveOutboundSigningKey] ACTIVE_KEY_ID "${env.ACTIVE_KEY_ID}" not found in SIGNING_KEYS; falling back to SHARED_SECRET`);
  }
  return { secret: env.SHARED_SECRET, keyId: undefined };
}

// ---------------------------------------------------------------------------
// Auth rate limiting (signup + signin)
// ---------------------------------------------------------------------------

interface AuthRateLimitData { count: number; resetAt: number; }

/** In-process fallback store; per-isolate (not global) but still limits abuse. */
const inMemoryAuthRateLimit = new Map<string, AuthRateLimitData>();

/**
 * Check whether the IP has exceeded the auth rate limit.
 * Uses KV for cross-DC accuracy when `env.RATE_LIMIT_KV` is bound;
 * falls back to per-isolate in-memory counting otherwise.
 *
 * Returns `{ allowed: false, retryAfterSeconds }` when the limit is exceeded.
 */
/** Clear in-process rate limit store — intended for use in tests only. */
export function clearAuthRateLimitStore(): void {
  inMemoryAuthRateLimit.clear();
}

export async function checkAuthRateLimit(
  ip: string,
  env: Pick<Env, 'RATE_LIMIT_KV'>,
): Promise<{ allowed: true } | { allowed: false; retryAfterSeconds: number }> {
  const now = Date.now();
  const windowMs = AUTH_RATE_LIMIT_WINDOW_SECONDS * 1000;

  // --- In-memory check (always runs; fast path) ---
  const memKey = ip;
  const memEntry = inMemoryAuthRateLimit.get(memKey);
  if (memEntry && memEntry.resetAt > now) {
    if (memEntry.count >= AUTH_RATE_LIMIT_MAX) {
      return { allowed: false, retryAfterSeconds: Math.ceil((memEntry.resetAt - now) / 1000) };
    }
    memEntry.count++;
  } else {
    inMemoryAuthRateLimit.set(memKey, { count: 1, resetAt: now + windowMs });
  }

  // --- KV check (authoritative cross-DC count when available) ---
  if (!env.RATE_LIMIT_KV) return { allowed: true };

  const kvKey = `auth_rl:${ip}`;
  try {
    const stored = await env.RATE_LIMIT_KV.get(kvKey, 'json') as AuthRateLimitData | null;
    let data: AuthRateLimitData;
    if (!stored || stored.resetAt < now) {
      data = { count: 1, resetAt: now + windowMs };
    } else {
      data = { count: stored.count + 1, resetAt: stored.resetAt };
    }
    const ttlSeconds = Math.max(Math.ceil((data.resetAt - now) / 1000), 60);
    await env.RATE_LIMIT_KV.put(kvKey, JSON.stringify(data), { expirationTtl: ttlSeconds });
    if (data.count > AUTH_RATE_LIMIT_MAX) {
      return { allowed: false, retryAfterSeconds: Math.ceil((data.resetAt - now) / 1000) };
    }
  } catch {
    // KV error — in-memory already allowed; degrade gracefully
    console.error('[auth rate limit] KV error; using in-memory fallback for', ip);
  }

  return { allowed: true };
}

export function corsPreflightResponse(): Response {
  return new Response(null, {
    status: HTTP_STATUS.NO_CONTENT,
    headers: CORS_HEADERS,
  });
}
