import { unauthorized } from '../../../lib/http';
import { requireBearerToken } from '../../../lib/http/request';
import { verifyJwt } from '../../../lib/auth';
import type { Entitlement } from '../../../lib/types';

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
