import { json } from "../../lib/http/responses.js";
import { HEADER_NAMES, type Env } from "./types.js";

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

/** Why no usable outbound signing key could be resolved. */
export type OutboundKeyMiss =
  | "active_key_id_unset"
  | "signing_keys_unset"
  | "signing_keys_malformed"
  | "unknown_active_key_id";

export type OutboundSigningKey =
  | { secret: string; keyId: string; miss?: undefined }
  | { secret: null; keyId: undefined; miss: OutboundKeyMiss };

/**
 * Resolve the outbound signing key and key ID. `SIGNING_KEYS` + `ACTIVE_KEY_ID` are the only
 * way to sign anything: a resolvable pair returns that secret and its key id, and **every**
 * other configuration is a miss whose request must not be sent.
 *
 * Two fail-closed decisions, both BACKLOG.md CR29, both about one trap — the sender used to
 * sign with `SHARED_SECRET` and send no `x-key-id`, which the receiver accepted as
 * legacy-signed. A downgrade therefore succeeded on the wire and nothing failed anywhere.
 * - Step 1: `ACTIVE_KEY_ID` set but unresolvable stopped falling back. A typo in the key id
 *   had been silently signing every request with the un-rotatable legacy credential, marked
 *   only by a `console.warn`.
 * - Step 2: `ACTIVE_KEY_ID` **unset** is now a miss too. It used to be a supported staging
 *   configuration — bind `SIGNING_KEYS`, deploy, activate later — but the receiver now
 *   rejects a request carrying no `x-key-id`, so that config emits requests guaranteed to
 *   401. Staging is unaffected because it belongs on the *receiver*: add the key to its
 *   `SIGNING_KEYS` first (the sequence above `forwardToReceiver`), then set both vars here.
 *
 * Failing closed is deliberately louder than the 401 it prevents. The receiver's rejection is
 * byte-identical to a forged signature — that indistinguishability is intentional, so key ids
 * cannot be enumerated — which means a keyless deploy would surface as an apparent attack on
 * production rather than as the misconfiguration it is.
 */
export function resolveOutboundSigningKey(env: Env): OutboundSigningKey {
  if (!env.ACTIVE_KEY_ID) {
    console.error('[resolveOutboundSigningKey] ACTIVE_KEY_ID is not set, so no key id can be sent; the receiver rejects keyless requests');
    return { secret: null, keyId: undefined, miss: "active_key_id_unset" };
  }

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
