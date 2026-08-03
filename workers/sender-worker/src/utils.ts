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

/** Why `ACTIVE_KEY_ID` was set but no key could be resolved for it. */
export type OutboundKeyMiss =
  | "signing_keys_unset"
  | "signing_keys_malformed"
  | "unknown_active_key_id";

export type OutboundSigningKey =
  | { secret: string; keyId: string | undefined; miss?: undefined }
  | { secret: null; keyId: undefined; miss: OutboundKeyMiss };

/**
 * Resolve the outbound signing key and key ID.
 * - `ACTIVE_KEY_ID` unset → `SHARED_SECRET`, no `x-key-id` header. Still a supported
 *   configuration, and the documented way to stage `SIGNING_KEYS` before activating it
 *   (see the rotation sequence above `forwardToReceiver`), so it is not a miss.
 * - `ACTIVE_KEY_ID` set + resolvable in `SIGNING_KEYS` → rotated key, send `x-key-id`.
 * - `ACTIVE_KEY_ID` set + not resolvable → **miss, and the caller must not send the
 *   request.**
 *
 * That last case used to fall back to `SHARED_SECRET` and send no `x-key-id`, marked
 * only by a `console.warn`. The receiver resolves an absent `x-key-id` to `SHARED_SECRET`,
 * so the request still succeeded — a typo in `ACTIVE_KEY_ID` silently downgraded every
 * signature to the un-rotatable legacy credential and nothing failed. Failing closed makes
 * a broken rotation loud at the sender instead of invisible; the request is rejected with
 * a 500 rather than signed with a key the operator did not choose. BACKLOG.md CR29 step 1.
 */
export function resolveOutboundSigningKey(env: Env): OutboundSigningKey {
  if (!env.ACTIVE_KEY_ID) return { secret: env.SHARED_SECRET, keyId: undefined };

  if (!env.SIGNING_KEYS) {
    console.error(`[resolveOutboundSigningKey] ACTIVE_KEY_ID "${env.ACTIVE_KEY_ID}" is set but SIGNING_KEYS is not bound`);
    return { secret: null, keyId: undefined, miss: "signing_keys_unset" };
  }

  let parsed: unknown;
  try {
    parsed = JSON.parse(env.SIGNING_KEYS);
  } catch {
    console.error('[resolveOutboundSigningKey] SIGNING_KEYS is not valid JSON');
    return { secret: null, keyId: undefined, miss: "signing_keys_malformed" };
  }
  if (typeof parsed !== "object" || parsed === null || Array.isArray(parsed)) {
    console.error('[resolveOutboundSigningKey] SIGNING_KEYS is not a JSON object of keyId → secret');
    return { secret: null, keyId: undefined, miss: "signing_keys_malformed" };
  }

  const secret = (parsed as Record<string, unknown>)[env.ACTIVE_KEY_ID];
  if (secret === undefined) {
    console.error(`[resolveOutboundSigningKey] ACTIVE_KEY_ID "${env.ACTIVE_KEY_ID}" not found in SIGNING_KEYS`);
    return { secret: null, keyId: undefined, miss: "unknown_active_key_id" };
  }
  // Present but unusable (`{"v2": 123}`, `{"v2": null}`, `{"v2": ""}`) is a malformed map,
  // not an unknown id. The old truthiness check let a number through as `secret: string`.
  if (typeof secret !== "string" || secret === "") {
    console.error(`[resolveOutboundSigningKey] SIGNING_KEYS entry for "${env.ACTIVE_KEY_ID}" is not a non-empty string`);
    return { secret: null, keyId: undefined, miss: "signing_keys_malformed" };
  }
  return { secret, keyId: env.ACTIVE_KEY_ID };
}

// ---------------------------------------------------------------------------
// Auth rate limiting (signup + signin)
// ---------------------------------------------------------------------------

interface AuthRateLimitData { count: number; resetAt: number; }

/** In-process fallback store; per-isolate (not global) but still limits abuse. */
const inMemoryAuthRateLimit = new Map<string, AuthRateLimitData>();

/**
 * Whether this isolate has already logged the "KV not bound" warning.
 * Logged once rather than per request so a misconfigured deploy is visible
 * without flooding the logs at request volume.
 */
let missingKvWarningLogged = false;

/** Clear in-process rate limit store — intended for use in tests only. */
export function clearAuthRateLimitStore(): void {
  inMemoryAuthRateLimit.clear();
  missingKvWarningLogged = false;
}

/**
 * Check whether the IP has exceeded the auth rate limit.
 *
 * Two tiers, and the distinction matters operationally:
 *
 * - **In-memory (always runs).** Counts per isolate. This enforces the limit
 *   on its own — an unbound `RATE_LIMIT_KV` degrades accuracy, it does not
 *   disable limiting. A caller hammering one isolate is denied at
 *   `AUTH_RATE_LIMIT_MAX`.
 * - **KV (when `env.RATE_LIMIT_KV` is bound).** Authoritative count shared
 *   across isolates and colos. Without it, an attacker who spreads requests
 *   across colos, or who waits out isolate recycling, gets more than
 *   `AUTH_RATE_LIMIT_MAX` attempts per window in aggregate. That is the gap
 *   the binding closes; see BACKLOG.md CR03.
 *
 * A KV error is not fatal: the in-memory tier has already counted the request,
 * so the check degrades to the weaker tier rather than failing open.
 *
 * Returns `{ allowed: false, retryAfterSeconds }` when the limit is exceeded.
 */

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
  // Not a fail-open path: the in-memory tier above has already counted this
  // request and denies at the limit. Returning early only skips the stronger
  // cross-isolate count.
  if (!env.RATE_LIMIT_KV) {
    if (!missingKvWarningLogged) {
      missingKvWarningLogged = true;
      console.warn(
        '[auth rate limit] RATE_LIMIT_KV is not bound; limiting per isolate only. ' +
        'Cross-colo attempts are undercounted — bind the namespace in wrangler.toml (BACKLOG.md CR03).',
      );
    }
    return { allowed: true };
  }

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
