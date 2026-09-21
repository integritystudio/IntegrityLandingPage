import type { Entitlement } from './types/index';

/**
 * Plan → entitlement projection (BACKLOG UA01, 2026-09-20).
 *
 * `public.entitlements` was designed as the materialised projection of a plan
 * (docs/research/payments-implementation.md § "Plan → entitlement projection"),
 * but no writer was ever built: the table held 0 rows for every org while
 * `plans.features` and the plan limits sat one join away. Every reader —
 * `/bootstrap`, `/v1/orgs/:id/dashboard`, `/v1/orgs/:id/entitlements` — therefore
 * returned `{}` and the dashboard rendered a paying growth org as having nothing.
 *
 * The decision here is to DERIVE rather than materialise: the plan row is the
 * truth for defaults, and `entitlements` rows are the per-org OVERRIDE layer on
 * top of it. That keeps the table (and its RLS) for the one thing only a row can
 * express — this org differs from its plan — while removing the writer, the
 * backfill and the drift a second copy of `plans` would carry. The quota Durable
 * Object still enforces limits from its own `DEFAULT_QUOTAS`; unifying that with
 * `plans` is deliberately out of scope here.
 *
 * Wire contract (what the Flutter `BootstrapEntitlements` model reads):
 *   feature flags  → boolean            (`usage_dashboard`, `alerts`, `compliance_summary`, …)
 *   plan limits    → number | null      (`monthly_units`, `requests_per_minute`, `concurrent_jobs`;
 *                                        `null` = unlimited, as the enterprise row stores it)
 */

/** Row shape of `public.plans`, as `PLAN_SELECT` returns it. */
export interface PlanRow extends Record<string, unknown> {
  key: string;
  monthly_units: number | null;
  requests_per_minute: number | null;
  concurrent_jobs: number | null;
  features: Record<string, unknown> | null;
}

export type EntitlementMap = Record<string, boolean | number | null>;

/** Plan limit columns projected as numeric entitlements. Order is the wire order. */
export const PLAN_LIMIT_KEYS = ['monthly_units', 'requests_per_minute', 'concurrent_jobs'] as const;

/** PostgREST `select` for a `PlanRow`. */
export const PLAN_SELECT = 'key, monthly_units, requests_per_minute, concurrent_jobs, features';

/**
 * The entitlements a plan grants on its own: every boolean in `plans.features`
 * plus the three limit columns. A missing plan (unknown key, lookup failure)
 * projects to nothing, so callers degrade to explicit rows rather than to a
 * guessed plan. Non-boolean feature values are ignored — the column is a flag
 * bag, and a stray number there must not masquerade as a limit.
 */
export function projectPlanEntitlements(plan: PlanRow | null | undefined): EntitlementMap {
  if (!plan) return {};
  const map: EntitlementMap = {};
  for (const [feature, value] of Object.entries(plan.features ?? {})) {
    if (typeof value === 'boolean') map[feature] = value;
  }
  for (const key of PLAN_LIMIT_KEYS) {
    const value = plan[key];
    map[key] = typeof value === 'number' ? value : null;
  }
  return map;
}

/**
 * Plan projection overlaid with explicit `entitlements` rows. Row semantics are
 * unchanged from before UA01: a disabled row is `false`; an enabled row is its
 * hard limit, else its soft limit, else `true`. A row always wins over the plan
 * for the same key, which is what makes the table an override layer.
 */
export function buildEntitlementMap(rows: Entitlement[], plan?: PlanRow | null): EntitlementMap {
  const map = projectPlanEntitlements(plan);
  for (const ent of rows) {
    if (!ent.enabled) {
      map[ent.feature_key] = false;
      continue;
    }
    map[ent.feature_key] = ent.hard_limit ?? ent.soft_limit ?? true;
  }
  return map;
}
