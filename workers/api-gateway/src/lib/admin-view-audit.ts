/**
 * One `audit_log` row per org a staff member opens, not one per request
 * (ADMIN-CV-GATEWAY-READ). The dashboard's admin Usage page polls every 30 s, so a row
 * per request would be ~120 an hour from one open tab and say nothing one row does not.
 *
 * "Opened" is the first admin read of an org by a user within
 * `ADMIN_VIEW_AUDIT_WINDOW_SECONDS`. The window is tracked the way the rate limiters
 * track theirs (rate-limit.ts): an in-memory map that always runs, and `RATE_LIMIT_KV`
 * as the cross-isolate record when it is bound. A KV error falls back to the in-memory
 * answer, so the worst case is a second row from another isolate, never a missing one.
 */
import type { SupabaseClient } from '../../../lib/supabase';
import { writeAuditLog } from './helpers';

/** How long one row stands for a user's reads of one org. */
export const ADMIN_VIEW_AUDIT_WINDOW_SECONDS = 3600;
/** Namespaced so the keys cannot collide with the rate limiters' entries in the same KV. */
const KV_KEY_PREFIX = 'gw_admin_view:';
/** Cap on distinct (user, org) pairs tracked in one isolate, so the map cannot grow without bound. */
const MAX_TRACKED_VIEWS = 10_000;
const KV_SEEN_VALUE = '1';
const MS_PER_SECOND = 1000;

export interface AdminOrgView {
  /** `users.id` of the staff member. */
  userId: string;
  /** Their Auth0 subject, kept in the row's metadata as the other routes do. */
  sub: string;
  orgId: string;
  /** The route label, e.g. `GET /v1/admin/orgs/:id/usage/summary`. */
  route: string;
}

const inMemorySeen = new Map<string, number>();

function pruneExpired(now: number): void {
  for (const [key, expiresAt] of inMemorySeen) {
    if (expiresAt <= now) inMemorySeen.delete(key);
  }
  if (inMemorySeen.size > MAX_TRACKED_VIEWS) inMemorySeen.clear();
}

/** Whether this is the first read of `key` in the window, recording it either way. */
async function firstViewInWindow(kv: KVNamespace | undefined, key: string, now: number): Promise<boolean> {
  const expiresAt = inMemorySeen.get(key);
  if (expiresAt !== undefined && expiresAt > now) return false;

  pruneExpired(now);
  inMemorySeen.set(key, now + ADMIN_VIEW_AUDIT_WINDOW_SECONDS * MS_PER_SECOND);

  if (!kv) return true;
  try {
    if ((await kv.get(key)) !== null) return false;
    await kv.put(key, KV_SEEN_VALUE, { expirationTtl: ADMIN_VIEW_AUDIT_WINDOW_SECONDS });
  } catch {
    console.error('[admin-view-audit] KV error; relying on the in-memory window');
  }
  return true;
}

/**
 * Write the `admin.org_viewed` row for this view unless the same user opened the same org
 * within the window. Never rejects: `writeAuditLog` logs its own failures.
 */
export async function recordAdminOrgView(
  sb: SupabaseClient,
  kv: KVNamespace | undefined,
  view: AdminOrgView,
): Promise<void> {
  const key = `${KV_KEY_PREFIX}${view.userId}:${view.orgId}`;
  if (!(await firstViewInWindow(kv, key, Date.now()))) return;

  await writeAuditLog(sb, {
    organization_id: view.orgId,
    actor_user_id: view.userId,
    action: 'admin.org_viewed',
    target_type: 'org',
    target_id: view.orgId,
    metadata: { actor_auth0_id: view.sub, route: view.route },
  });
}

/** Reset module state. Tests only — isolates are per-request in production. */
export function resetAdminViewAudit(): void {
  inMemorySeen.clear();
}
