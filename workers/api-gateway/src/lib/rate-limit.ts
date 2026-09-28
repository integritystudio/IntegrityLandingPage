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
export const MAX_TRACKED_IDENTITIES = 10_000;

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

// ---------------------------------------------------------------------------
// Per-org rate limiter for /v1/orgs/:id/* routes (CR36)
//
// The quota Durable Object enforces per-minute and per-monthly limits for
// authenticated org-scoped routes, but it fails open on an outage — so a DO
// outage removes the only per-minute ceiling those routes have. This limiter
// runs before the DO call, is keyed on org_id, and uses the same RATE_LIMIT_KV
// namespace. It is deliberately uniform (not plan-tiered): reading the plan
// from Supabase to tier it would require a Supabase call before the DO call,
// adding latency and a second point of failure. The DO already enforces plan-
// tiered per-minute limits; this layer protects the DO from load and provides
// a floor when the DO is unavailable.
// ---------------------------------------------------------------------------

/**
 * Requests allowed per org per window. An org can have multiple simultaneous
 * users, so this is higher than the per-identity limit. 300/minute = 5/s,
 * enough for a team actively using the dashboard while still stopping loops.
 */
export const ORG_RATE_LIMIT_MAX = 300;
/** Window length in seconds — matches the identity rate limit window. */
export const ORG_RATE_LIMIT_WINDOW_SECONDS = 60;
/** KV key prefix — distinct from the identity prefix to avoid collisions. */
const ORG_KV_KEY_PREFIX = 'gw_org_rl:';
/** Cap on distinct orgs tracked in one isolate. */
export const MAX_TRACKED_ORGS = 10_000;

const orgInMemoryWindows = new Map<string, RateLimitWindow>();
let orgMissingKvWarningLogged = false;

function pruneOrgExpired(now: number): void {
  for (const [key, window] of orgInMemoryWindows) {
    if (window.resetAt <= now) orgInMemoryWindows.delete(key);
  }
  if (orgInMemoryWindows.size > MAX_TRACKED_ORGS) orgInMemoryWindows.clear();
}

/**
 * Count one request against `orgId` and report whether it may proceed.
 *
 * Same two-tier design as checkIdentityRateLimit: in-memory always runs, KV is
 * the authoritative cross-isolate count. KV failure is not fail-open — the
 * in-memory tier has already counted the request and denies at the limit.
 */
export async function checkOrgRateLimit(
  orgId: string,
  env: RateLimitEnv,
): Promise<RateLimitResult> {
  const now = Date.now();
  const windowMs = ORG_RATE_LIMIT_WINDOW_SECONDS * 1000;

  const existing = orgInMemoryWindows.get(orgId);
  if (existing && existing.resetAt > now) {
    if (existing.count >= ORG_RATE_LIMIT_MAX) {
      return { allowed: false, retryAfterSeconds: Math.ceil((existing.resetAt - now) / 1000) };
    }
    existing.count++;
  } else {
    pruneOrgExpired(now);
    orgInMemoryWindows.set(orgId, { count: 1, resetAt: now + windowMs });
  }

  if (!env.RATE_LIMIT_KV) {
    if (!orgMissingKvWarningLogged) {
      orgMissingKvWarningLogged = true;
      console.warn(
        '[gateway org rate limit] RATE_LIMIT_KV is not bound; limiting per isolate only. ' +
        'An org spread across colos is undercounted — bind the namespace in wrangler.toml.',
      );
    }
    return { allowed: true };
  }

  const kvKey = `${ORG_KV_KEY_PREFIX}${orgId}`;
  try {
    const stored = (await env.RATE_LIMIT_KV.get(kvKey, 'json')) as RateLimitWindow | null;
    const data: RateLimitWindow =
      !stored || stored.resetAt < now
        ? { count: 1, resetAt: now + windowMs }
        : { count: stored.count + 1, resetAt: stored.resetAt };

    const ttlSeconds = Math.max(Math.ceil((data.resetAt - now) / 1000), MIN_KV_TTL_SECONDS);
    await env.RATE_LIMIT_KV.put(kvKey, JSON.stringify(data), { expirationTtl: ttlSeconds });

    if (data.count > ORG_RATE_LIMIT_MAX) {
      return { allowed: false, retryAfterSeconds: Math.ceil((data.resetAt - now) / 1000) };
    }
  } catch {
    console.error('[gateway org rate limit] KV error; falling back to the in-memory count');
  }

  return { allowed: true };
}

/** Reset org rate limit module state. Tests only. */
export function resetOrgRateLimit(): void {
  orgInMemoryWindows.clear();
  orgMissingKvWarningLogged = false;
}
