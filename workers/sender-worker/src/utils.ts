import { json } from "../../lib/http/responses.js";
import { CORS_HEADERS, HEADER_NAMES, HTTP_STATUS, type Env } from "./types.js";

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

export function corsPreflightResponse(): Response {
  return new Response(null, {
    status: HTTP_STATUS.NO_CONTENT,
    headers: CORS_HEADERS,
  });
}
