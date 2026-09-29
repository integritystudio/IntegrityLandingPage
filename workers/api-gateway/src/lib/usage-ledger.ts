/**
 * Usage ledger for metered org routes (BACKLOG UA01, 2026-09-20).
 *
 * `enforceOrgQuota` reserves one `requests` unit in the quota Durable Object for
 * every `/v1/orgs/:id/*` call, and the DO enforces the plan's minute and monthly
 * limits from that. Nothing wrote the same unit anywhere durable: `usage_events`
 * had 0 rows for every org, so `usage_buckets_daily` (filled by the
 * `trigger_upsert_daily_usage_bucket` trigger, live in production) was empty and
 * `/v1/orgs/:id/usage/summary` reported no usage for a paying org. This records
 * exactly what the DO counted — same metric key, same one unit — so the ledger
 * and the enforcement agree by construction.
 *
 * Fire-and-forget by design: the caller hands the promise to `ctx.waitUntil`, a
 * failed insert is logged and never fails the request.
 */
import type { SupabaseClient } from '../../../lib/supabase';

/** Same metric key `enforceOrgQuota` reserves against in the quota DO. */
export const USAGE_METRIC_REQUESTS = 'requests';
/** `usage_events.source` value for gateway-served requests (CHECK constraint member). */
const USAGE_SOURCE_API = 'api';
/** One reservation per request, matching `units: 1` in `enforceOrgQuota`. */
const UNITS_PER_REQUEST = 1;
/** Route template with the org id elided, so rows group by route rather than by tenant. */
const ORG_ROUTE_TEMPLATE = '/v1/orgs/:id';

export interface MeteredRequest {
  orgId: string;
  /** `meteredRoute(method, subPath)` — e.g. `GET /v1/orgs/:id/dashboard`. */
  route: string;
  requestId: string;
  statusCode: number;
  latencyMs: number;
}

export function meteredRoute(method: string, subPath: string): string {
  return `${method} ${ORG_ROUTE_TEMPLATE}${subPath}`;
}

export async function recordMeteredRequest(sb: SupabaseClient, record: MeteredRequest): Promise<void> {
  try {
    const result = await sb.insert('usage_events', {
      organization_id: record.orgId,
      route: record.route,
      metric_key: USAGE_METRIC_REQUESTS,
      quantity: UNITS_PER_REQUEST,
      request_id: record.requestId,
      source: USAGE_SOURCE_API,
      status_code: record.statusCode,
      latency_ms: record.latencyMs,
    });
    if (!result.ok) {
      console.error('[usage-ledger] failed to record', record.route, 'for org', record.orgId, result.error);
    }
  } catch (err) {
    console.error('[usage-ledger] failed to record', record.route, 'for org', record.orgId, err);
  }
}
