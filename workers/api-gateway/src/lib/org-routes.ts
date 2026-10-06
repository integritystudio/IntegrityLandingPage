interface OrgRoute {
  method: string;
  subPath: string;
  /** `false` exempts the route from the monthly quota; omitted means charged. */
  chargesMonthly?: false;
}

/**
 * The `/v1/orgs/:id/*` routes with a fixed sub-path: the router dispatches on this
 * table and `chargesMonthlyQuota` reads it, so a route's path and whether it spends
 * the monthly quota are written once (TS31). `POST /api-keys/:keyId/revoke` is matched
 * by pattern in the router and is charged.
 */
export const ORG_ROUTES = {
  dashboard: { method: 'GET', subPath: '/dashboard' },
  billingStatus: { method: 'GET', subPath: '/billing-status' },
  /**
   * Org reads that report usage or quota (CR58). Charging them spent the quota they
   * report: the Usage page polls `/usage/summary` every 30 s, which alone is 2,880
   * units a day against starter's 10,000 a month. They still pass both per-minute
   * limits (the edge limiter and the DO's minute window), and they write no ledger
   * row, because the ledger records what the DO charged against the month.
   */
  usageSummary: { method: 'GET', subPath: '/usage/summary', chargesMonthly: false },
  entitlements: { method: 'GET', subPath: '/entitlements' },
  quotaStatus: { method: 'GET', subPath: '/quota/status', chargesMonthly: false },
  billingPortal: { method: 'POST', subPath: '/billing-portal' },
  checkoutSession: { method: 'POST', subPath: '/checkout-session' },
  createApiKey: { method: 'POST', subPath: '/api-keys' },
} as const satisfies Record<string, OrgRoute>;

export type OrgRouteName = keyof typeof ORG_ROUTES;

/** The fixed route for an exact method and sub-path, if there is one. */
export function matchOrgRoute(method: string, subPath: string): OrgRouteName | undefined {
  return (Object.keys(ORG_ROUTES) as OrgRouteName[]).find(
    (name) => ORG_ROUTES[name].method === method && ORG_ROUTES[name].subPath === subPath,
  );
}

/**
 * Whether an org request is charged against the monthly quota, and so ledgered. Only
 * the routes marked `chargesMonthly: false` are exempt. The router answers a sub-path
 * no route serves with 404 before asking (TS31), so the one unlisted path that reaches
 * here is the revoke pattern, which is charged.
 */
export function chargesMonthlyQuota(method: string, subPath: string): boolean {
  const name = matchOrgRoute(method, subPath);
  const route: OrgRoute | undefined = name && ORG_ROUTES[name];
  return route?.chargesMonthly !== false;
}

/**
 * The staff twins of the four customer read routes, under `/v1/admin/orgs/:id/*`
 * (ADMIN-CV-GATEWAY-READ). Same sub-paths and payloads as `ORG_ROUTES`, so the
 * observability dashboard's admin view reads exactly what the customer reads; GET only,
 * because the gateway's CORS allows `GET, POST, OPTIONS` and these must never mutate.
 * They are dispatched outside the `/v1/orgs/:id` branch, so none of them pays the
 * per-org rate limit, reserves quota, or writes a ledger row.
 */
export const ADMIN_ORG_ROUTES = {
  billingStatus: { method: 'GET', subPath: ORG_ROUTES.billingStatus.subPath },
  usageSummary: { method: 'GET', subPath: ORG_ROUTES.usageSummary.subPath },
  entitlements: { method: 'GET', subPath: ORG_ROUTES.entitlements.subPath },
  quotaStatus: { method: 'GET', subPath: ORG_ROUTES.quotaStatus.subPath },
} as const satisfies Record<string, OrgRoute>;

export type AdminOrgRouteName = keyof typeof ADMIN_ORG_ROUTES;

/** The staff route for an exact method and sub-path, if there is one. */
export function matchAdminOrgRoute(method: string, subPath: string): AdminOrgRouteName | undefined {
  return (Object.keys(ADMIN_ORG_ROUTES) as AdminOrgRouteName[]).find(
    (name) => ADMIN_ORG_ROUTES[name].method === method && ADMIN_ORG_ROUTES[name].subPath === subPath,
  );
}
