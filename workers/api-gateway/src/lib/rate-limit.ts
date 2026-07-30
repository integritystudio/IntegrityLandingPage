/**
 * Per-identity request throttle for the routes that carry no org quota.
 *
 * Quota (`enforceOrgQuota`) is billing metering keyed on an organization, and it only guards
 * `/v1/orgs/:id/*`. The identity-scoped routes — `/v1/me`, `/v1/orgs`, `/bootstrap` — cannot use
 * it: they have no org in the request, `/bootstrap` is what *tells* the client which orgs exist,
 * and metering them against an org would let a billing state block sign-in and onboarding. They
 * were therefore unprotected: authenticated, but free to call in a loop.
 *
 * This closes that gap with the mechanism the concern actually calls for — a rate limit rather
 * than a quota. It mirrors `sender-worker`'s `checkAuthRateLimit`, with two differences that
 * matter here:
 *
 * - **Keyed on the JWT subject, not the client IP.** These callers are authenticated, so the
 *   identity is known and precise; IP would both over-count users behind a shared NAT and
 *   under-count one account spread across addresses. The subject must come from a *verified*
 *   token — limiting on an unverified claim would let a caller mint a fresh subject per request
 *   and walk straight past the limit.
 * - Applied uniformly across the identity-scoped routes, so protecting one does not just move
 *   the asymmetry somewhere else.
 */

/** Requests allowed per identity per window. A dashboard load makes ~7 calls, so this is ~17
 *  page loads a minute — far above real use, low enough to stop a loop. */
export const IDENTITY_RATE_LIMIT_MAX = 120;
/** Window length in seconds. */
export const IDENTITY_RATE_LIMIT_WINDOW_SECONDS = 60;
/** KV keys are namespaced so this cannot collide with sender-worker's `auth_rl:` entries. */
const KV_KEY_PREFIX = 'gw_id_rl:';
/** Floor for the KV TTL; Cloudflare rejects an expirationTtl below 60s. */
const MIN_KV_TTL_SECONDS = 60;
/** Cap on distinct identities tracked in one isolate, so the map cannot grow without bound. */
const MAX_TRACKED_IDENTITIES = 10_000;

interface RateLimitWindow {
  count: number;
  resetAt: number;
}

export interface RateLimitEnv {
  RATE_LIMIT_KV?: KVNamespace;
}

export type RateLimitResult =
  | { allowed: true }
  | { allowed: false; retryAfterSeconds: number };

const inMemoryWindows = new Map<string, RateLimitWindow>();
let missingKvWarningLogged = false;

/**
 * Drop windows that have already expired. Called on each miss rather than on a timer, since a
 * Worker isolate has no scheduler; the cap is a backstop for the pathological case where every
 * request is a fresh identity.
 */
function pruneExpired(now: number): void {
  for (const [key, window] of inMemoryWindows) {
    if (window.resetAt <= now) inMemoryWindows.delete(key);
  }
  if (inMemoryWindows.size > MAX_TRACKED_IDENTITIES) inMemoryWindows.clear();
}

/**
 * Count one request against `identity` and report whether it may proceed.
 *
 * Two tiers, matching sender-worker: an in-memory window that always runs, and KV as the
 * authoritative cross-isolate count when the namespace is bound. A KV failure is not fail-open —
 * the in-memory tier has already counted the request and denies at the limit on its own; losing
 * KV only weakens the count to per-isolate. The KV read/modify/write is not atomic, so
 * concurrent requests can overshoot slightly; that is an acceptable trade for a throttle whose
 * job is to stop loops rather than to meter billing precisely.
 */
export async function checkIdentityRateLimit(
  identity: string,
  env: RateLimitEnv,
): Promise<RateLimitResult> {
  const now = Date.now();
  const windowMs = IDENTITY_RATE_LIMIT_WINDOW_SECONDS * 1000;

  const existing = inMemoryWindows.get(identity);
  if (existing && existing.resetAt > now) {
    if (existing.count >= IDENTITY_RATE_LIMIT_MAX) {
      return { allowed: false, retryAfterSeconds: Math.ceil((existing.resetAt - now) / 1000) };
    }
    existing.count++;
  } else {
    pruneExpired(now);
    inMemoryWindows.set(identity, { count: 1, resetAt: now + windowMs });
  }

  if (!env.RATE_LIMIT_KV) {
    if (!missingKvWarningLogged) {
      missingKvWarningLogged = true;
      console.warn(
        '[gateway rate limit] RATE_LIMIT_KV is not bound; limiting per isolate only. ' +
        'A caller spread across colos is undercounted — bind the namespace in wrangler.toml.',
      );
    }
    return { allowed: true };
  }

  const kvKey = `${KV_KEY_PREFIX}${identity}`;
  try {
    const stored = (await env.RATE_LIMIT_KV.get(kvKey, 'json')) as RateLimitWindow | null;
    const data: RateLimitWindow =
      !stored || stored.resetAt < now
        ? { count: 1, resetAt: now + windowMs }
        : { count: stored.count + 1, resetAt: stored.resetAt };

    const ttlSeconds = Math.max(Math.ceil((data.resetAt - now) / 1000), MIN_KV_TTL_SECONDS);
    await env.RATE_LIMIT_KV.put(kvKey, JSON.stringify(data), { expirationTtl: ttlSeconds });

    if (data.count > IDENTITY_RATE_LIMIT_MAX) {
      return { allowed: false, retryAfterSeconds: Math.ceil((data.resetAt - now) / 1000) };
    }
  } catch {
    console.error('[gateway rate limit] KV error; falling back to the in-memory count');
  }

  return { allowed: true };
}

/** Reset module state. Tests only — isolates are per-request in production. */
export function resetIdentityRateLimit(): void {
  inMemoryWindows.clear();
  missingKvWarningLogged = false;
}
