import { unauthorized } from '../../../lib/http';
import { requireBearerToken } from '../../../lib/http/request';
import { verifyJwt } from '../../../lib/auth';
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

interface PreVerifyTokenOptions {
  jwtSecret: string;
  jwtIssuerUrl?: string;
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

  const jwtResult = await verifyJwt(token, opts.jwtSecret, { issuerUrl: opts.jwtIssuerUrl });
  if (!jwtResult.ok) return jwtResult;
  return { ok: true };
}

export async function resolveJwt(
  request: Request,
  jwtSecret: string,
  jwtIssuerUrl?: string,
): Promise<{ ok: true; sub: string } | { ok: false; error: Response }> {
  const tokenResult = requireBearerToken(request);
  if (!tokenResult.ok) return tokenResult;
  const jwtResult = await verifyJwt(tokenResult.token, jwtSecret, { issuerUrl: jwtIssuerUrl });
  if (!jwtResult.ok) return jwtResult;
  if (!jwtResult.payload.sub) return { ok: false, error: unauthorized('JWT missing sub claim') };
  return { ok: true, sub: jwtResult.payload.sub };
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
