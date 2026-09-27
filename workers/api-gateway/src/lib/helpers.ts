import { unauthorized, tooManyRequests, serviceUnavailable, forbidden, notFound } from '../../../lib/http';
import { checkIdentityRateLimit } from './rate-limit';
import { requireBearerToken } from '../../../lib/http/request';
import { verifyJwt, auth0JwtKey, auth0IssuerFor } from '../../../lib/auth';
import type { JwtVerificationKey } from '../../../lib/auth';
import { parseApiKey, verifyApiKey } from '../../../lib/api-keys';
import { createSupabaseClient } from '../../../lib/supabase';
import { PLAN_SELECT, type PlanRow } from '../../../lib/entitlements';
import type { SupabaseClient } from '../../../lib/supabase';
import { AuditActionSchema, type AuditAction } from '../../../lib/types/audit';

export interface AuditLogEntry {
  organization_id?: string;
  actor_user_id?: string;
  action: AuditAction;
  target_type: string;
  target_id: string;
  new_values?: Record<string, unknown>;
  metadata?: Record<string, unknown>;
}

export async function writeAuditLog(sb: SupabaseClient, entry: AuditLogEntry): Promise<void> {
  // The type already rejects unknown actions at compile time; this catches a value that
  // reached here through a cast. Skipping keeps the table's vocabulary closed — the column
  // is unconstrained text, so nothing downstream would refuse it.
  const action = AuditActionSchema.safeParse(entry.action);
  if (!action.success) {
    console.error('[audit] Refusing to write unknown audit action', entry.action);
    return;
  }
  try {
    const result = await sb.insert('audit_log', entry as unknown as Record<string, unknown>);
    if (!result.ok) {
      console.error('[audit] Failed to write audit log for action', entry.action, result.error);
    }
  } catch (e) {
    console.error('[audit] Exception writing audit log for action', entry.action, e);
  }
}

/**
 * The Auth0 tenant that issues the browser tokens this Worker accepts.
 *
 * Every route resolves the caller by treating the JWT `sub` as `users.auth0_id`
 * (see routes/me.ts, routes/api-keys.ts, loadUserMemberships), so Auth0 — not
 * Supabase — is the issuer these tokens must be verified against. Supabase is
 * reached with the service role key and issues no token in this flow.
 */
export interface UserTokenOptions {
  auth0Domain: string;
  /** Auth0 API identifier the token must be scoped to. Omit to skip `aud` validation. */
  auth0Audience?: string;
  /**
   * KV namespace backing the per-identity throttle on the routes that carry no org quota.
   * Optional: when absent the throttle still counts per isolate (see checkIdentityRateLimit),
   * so an unbound namespace weakens the limit rather than disabling it.
   */
  rateLimitKv?: KVNamespace;
}

/**
 * Verification parameters for a browser token, all derived from the tenant domain.
 *
 * Centralised so key, issuer and audience cannot drift apart per route. Deriving
 * the issuer here rather than reading a separate env var also means it cannot be
 * silently unset: an absent issuer var disables `iss` validation without failing,
 * which is exactly how this Worker shipped with iss checking off in production.
 */
export function auth0VerifyParams(
  opts: UserTokenOptions,
): { key: JwtVerificationKey; issuerUrl: string; audience?: string } {
  return {
    key: auth0JwtKey({ auth0Domain: opts.auth0Domain }),
    issuerUrl: auth0IssuerFor(opts.auth0Domain),
    audience: opts.auth0Audience,
  };
}

interface PreVerifyTokenOptions extends UserTokenOptions {
  hmacSecret?: string;
  supabaseUrl: string;
  serviceRoleKey: string;
  /**
   * When set, verifies the caller belongs to this org before returning ok.
   * Prevents an authenticated credential from a different org from spending this org's
   * quota and polluting its usage ledger (UA08).
   *
   * API keys: verified by comparing the key's stored organization_id (cheap, no extra DB call).
   * JWTs: verified by querying organization_memberships (one extra DB call). Fails open on
   * DB errors — the route handlers still enforce membership and will 403 any unauthorized caller,
   * but only after quota has already been consumed in that failure mode.
   */
  orgId?: string;
}

/**
 * Resolve the HMAC key that API-key hashes are verified against.
 *
 * `API_KEY_HMAC_SECRET` has never been bound in production (BACKLOG.md CR12): the canonical
 * value belongs to `api-provisioning-receiver`, which mints the keys. Absence is therefore a
 * server-configuration fault, not a credential failure — hence 503 rather than 401, which
 * would tell the caller their key is bad when the server simply cannot check it. Callers must
 * invoke this only once a token is known to be key-shaped, so JWT auth stays unaffected.
 */
export function requireHmacSecret(
  hmacSecret: string | undefined,
): { ok: true; hmacSecret: string } | { ok: false; error: Response } {
  if (!hmacSecret) {
    console.error('API_KEY_HMAC_SECRET is not bound; API-key authentication is unavailable');
    return { ok: false, error: serviceUnavailable('API key authentication is unavailable') };
  }
  return { ok: true, hmacSecret };
}

/**
 * Verify the bearer token is authentic before consuming any quota.
 * Prevents unauthenticated callers from exhausting an org's quota via a
 * garbage token that passes the presence-only `requireBearerToken` check.
 *
 * - API keys (matching `int_live_…` format): verified via HMAC + DB lookup.
 * - JWTs: verified cryptographically (no DB call).
 *
 * Returns `{ ok: false; error }` for missing, invalid, or expired tokens.
 */
export async function preVerifyToken(
  request: Request,
  opts: PreVerifyTokenOptions,
): Promise<{ ok: true } | { ok: false; error: Response }> {
  const tokenResult = requireBearerToken(request);
  if (!tokenResult.ok) return tokenResult;
  const { token } = tokenResult;

  if (parseApiKey(token).ok) {
    const secret = requireHmacSecret(opts.hmacSecret);
    if (!secret.ok) return secret;
    const sb = createSupabaseClient(opts.supabaseUrl, opts.serviceRoleKey);
    const result = await verifyApiKey(token, secret.hmacSecret, sb);
    if (!result.ok) return result;
    // UA08: refuse a cross-org API key before the quota DO is touched.
    // The key row already carries organization_id — no extra DB call.
    if (opts.orgId !== undefined && result.organizationId !== opts.orgId) {
      return { ok: false, error: forbidden('API key does not belong to this organization') };
    }
    return { ok: true };
  }

  const { key, issuerUrl, audience } = auth0VerifyParams(opts);
  const jwtResult = await verifyJwt(token, key, { issuerUrl, audience });
  if (!jwtResult.ok) return jwtResult;

  // UA08: for JWT callers, verify org membership before the quota DO is touched.
  // Fails open on DB errors — the handler still checks membership and will 403 unauthorized
  // callers, but only after the quota unit has already been consumed.
  if (opts.orgId !== undefined) {
    const sub = jwtResult.payload.sub;
    if (!sub) return { ok: false, error: unauthorized('JWT missing sub claim') };
    const sb = createSupabaseClient(opts.supabaseUrl, opts.serviceRoleKey);
    const user = await resolveUserId(sub, sb);
    if (user.ok) {
      const membership = await sb.query<{ user_id: string }>('organization_memberships', {
        select: 'user_id',
        filters: [
          { column: 'user_id', operator: 'eq', value: user.userId },
          { column: 'organization_id', operator: 'eq', value: opts.orgId },
          { column: 'status', operator: 'eq', value: 'active' },
        ],
        limit: 1,
      });
      if (membership.ok && membership.data.length === 0) {
        return { ok: false, error: forbidden('Not a member of this organization') };
      }
      // membership.ok false (DB error) → fail open; handler re-checks and will 403.
    }
    // user.ok false (DB error) → fail open.
  }

  return { ok: true };
}

/**
 * Verify the caller's token and count the request against their per-identity throttle.
 *
 * For the identity-scoped routes (`/v1/me`, `/v1/orgs`, `/bootstrap`), which have no org to meter
 * against and so never reach `enforceOrgQuota`. The throttle runs *after* verification, so the
 * subject it keys on is authentic — limiting on an unverified claim would let a caller mint a new
 * subject per request and bypass it — and *before* the handler's database work, so a rejected
 * caller costs nothing beyond one cached signature check.
 */
export async function resolveJwtRateLimited(
  request: Request,
  opts: UserTokenOptions,
): Promise<{ ok: true; sub: string } | { ok: false; error: Response }> {
  const auth = await resolveJwt(request, auth0VerifyParams(opts));
  if (!auth.ok) return auth;

  const limit = await checkIdentityRateLimit(auth.sub, { RATE_LIMIT_KV: opts.rateLimitKv });
  if (!limit.allowed) {
    return {
      ok: false,
      error: tooManyRequests('Too many requests', { retry_after_seconds: limit.retryAfterSeconds }),
    };
  }

  return auth;
}

export async function resolveJwt(
  request: Request,
  params: { key: JwtVerificationKey; issuerUrl?: string; audience?: string },
): Promise<{ ok: true; sub: string } | { ok: false; error: Response }> {
  const tokenResult = requireBearerToken(request);
  if (!tokenResult.ok) return tokenResult;
  const jwtResult = await verifyJwt(tokenResult.token, params.key, {
    issuerUrl: params.issuerUrl,
    audience: params.audience,
  });
  if (!jwtResult.ok) return jwtResult;
  if (!jwtResult.payload.sub) return { ok: false, error: unauthorized('JWT missing sub claim') };
  return { ok: true, sub: jwtResult.payload.sub };
}

/**
 * Translate a JWT `sub` (an Auth0 subject, e.g. `auth0|abc123`) into the internal
 * `users.id` UUID.
 *
 * These two identifiers are NOT interchangeable, and confusing them fails quietly.
 * `users.auth0_id` holds the sub; every foreign key — `organization_memberships.user_id`,
 * `usage_events.user_id` — holds the UUID. Passing a sub into one of those filters makes
 * PostgREST reject the comparison against a uuid column with a 400, and because the
 * query helpers treat a failed query as "no rows", the caller sees an empty membership
 * list and returns an empty dashboard instead of an error. Resolve here, once, and pass
 * the UUID downstream.
 */
export async function resolveUserId(
  auth0Sub: string,
  sb: SupabaseClient,
): Promise<{ ok: true; userId: string; email: string } | { ok: false; error: Response }> {
  const result = await sb.query<{ id: string; email: string }>('users', {
    // `email` comes along because this row is the only authoritative source for it: an Auth0
    // *access* token carries no `email` claim (OIDC claims go to the ID token / userinfo), so a
    // handler that needs the address must read it here rather than from the JWT payload.
    select: 'id, email',
    filters: [{ column: 'auth0_id', operator: 'eq', value: auth0Sub }],
    limit: 1,
  });
  if (!result.ok) {
    console.error('[auth] users lookup failed for sub', auth0Sub, result.error);
    return { ok: false, error: unauthorized('Could not resolve user') };
  }
  if (result.data.length === 0) {
    // Authentic token, but no provisioned row — a signup that half-completed.
    return { ok: false, error: notFound('No user record for this identity') };
  }
  return { ok: true, userId: result.data[0].id, email: result.data[0].email };
}

// Plan projection + row overlay live in the shared lib (UA01); re-exported so the
// routes keep one import site.
export { buildEntitlementMap } from '../../../lib/entitlements';

/**
 * The `plans` row for a plan key, or null when the key is empty, unknown or the
 * lookup fails. Null degrades the caller to explicit `entitlements` rows only —
 * never to a guessed plan — and the failure is logged because an org silently
 * reporting no entitlements is exactly the state UA01 was filed for.
 */
export async function loadPlan(sb: SupabaseClient, planKey: string | null | undefined): Promise<PlanRow | null> {
  if (!planKey) return null;
  const result = await sb.query<PlanRow>('plans', {
    select: PLAN_SELECT,
    filters: [{ column: 'key', operator: 'eq', value: planKey }],
    single: true,
  });
  if (!result.ok) {
    console.error('[entitlements] plan lookup failed for', planKey, result.error);
    return null;
  }
  return result.data;
}

/**
 * `loadPlan` for an org that has not been fetched yet: one read for its `current_plan`.
 * A missing org row also resolves to null: every caller has already passed a
 * membership check that 403s/404s an unknown org, so "no row" here is a race with
 * a delete, not a state worth failing the response over.
 */
export async function loadOrgPlan(sb: SupabaseClient, orgId: string): Promise<PlanRow | null> {
  const org = await sb.query<{ current_plan: string | null }>('organizations', {
    select: 'current_plan',
    filters: [{ column: 'id', operator: 'eq', value: orgId }],
    single: true,
  });
  if (!org.ok) {
    console.error('[entitlements] organization lookup failed for', orgId, org.error);
    return null;
  }
  return loadPlan(sb, org.data?.current_plan);
}
