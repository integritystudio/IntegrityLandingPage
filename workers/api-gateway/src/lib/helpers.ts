import { unauthorized, tooManyRequests } from '../../../lib/http';
import { checkIdentityRateLimit } from './rate-limit';
import { requireBearerToken } from '../../../lib/http/request';
import { verifyJwt, auth0JwtKey, auth0IssuerFor } from '../../../lib/auth';
import type { JwtVerificationKey } from '../../../lib/auth';
import { parseApiKey, verifyApiKey } from '../../../lib/api-keys';
import { createSupabaseClient } from '../../../lib/supabase';
import type { Entitlement } from '../../../lib/types';
import type { SupabaseClient } from '../../../lib/supabase';

export interface AuditLogEntry {
  organization_id?: string;
  actor_user_id?: string;
  action: string;
  target_type: string;
  target_id: string;
  new_values?: Record<string, unknown>;
  metadata?: Record<string, unknown>;
}

export async function writeAuditLog(sb: SupabaseClient, entry: AuditLogEntry): Promise<void> {
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
  hmacSecret: string;
  supabaseUrl: string;
  serviceRoleKey: string;
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
    const sb = createSupabaseClient(opts.supabaseUrl, opts.serviceRoleKey);
    const result = await verifyApiKey(token, opts.hmacSecret, sb);
    if (!result.ok) return result;
    return { ok: true };
  }

  const { key, issuerUrl, audience } = auth0VerifyParams(opts);
  const jwtResult = await verifyJwt(token, key, { issuerUrl, audience });
  if (!jwtResult.ok) return jwtResult;
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
    return { ok: false, error: unauthorized('No user record for this identity') };
  }
  return { ok: true, userId: result.data[0].id, email: result.data[0].email };
}

export function buildEntitlementMap(rows: Entitlement[]): Record<string, boolean | number | null> {
  const map: Record<string, boolean | number | null> = {};
  for (const ent of rows) {
    if (!ent.enabled) {
      map[ent.feature_key] = false;
      continue;
    }
    map[ent.feature_key] = ent.hard_limit ?? ent.soft_limit ?? true;
  }
  return map;
}
