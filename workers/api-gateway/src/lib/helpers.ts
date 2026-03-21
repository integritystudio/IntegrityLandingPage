import { unauthorized } from '../../../lib/http';
import { requireBearerToken } from '../../../lib/http/request';
import { verifyJwt } from '../../../lib/auth';
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
  const result = await sb.insert('audit_log', entry as unknown as Record<string, unknown>);
  if (!result.ok) {
    console.error('[audit] Failed to write audit log for action', entry.action, result.error);
  }
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
