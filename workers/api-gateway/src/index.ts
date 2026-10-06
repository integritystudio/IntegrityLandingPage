import { ok, notFound, noContent, buildCors } from '../../lib/http';
import { handleMe } from './routes/me';
import { handleListOrgs, handleOrgDashboard, handleOrgBillingStatus, handleBillingPortal, handleCreateCheckoutSession } from './routes/orgs';
import { handleUsageSummary, handleOrgEntitlements, handleQuotaStatus } from './routes/usage';
import {
  handleAdminListOrgs,
  handleAdminOrgBillingStatus,
  handleAdminUsageSummary,
  handleAdminOrgEntitlements,
  handleAdminQuotaStatus,
} from './routes/admin';
import { handleCreateApiKey, handleRevokeApiKey } from './routes/api-keys';
import { handleHealthCheck } from './routes/health';
import { handleIngestEvent, handleIngestOtel, OTEL_INGEST_ROUTE } from './routes/ingest';
import { handleBootstrap } from './routes/bootstrap';
import { handleAuth0Logs } from './routes/auth0-logs';
import { pollAuth0Logs } from './lib/auth0-log-poller';
import { QuotaDurableObject } from './durable-objects/quota';
import { enforceOrgQuota } from './lib/quota';
import { preVerifyToken } from './lib/helpers';
import { checkOrgRateLimit } from './lib/rate-limit';
import { meteredRoute, recordMeteredRequest } from './lib/usage-ledger';
import { chargesMonthlyQuota, matchAdminOrgRoute, matchOrgRoute } from './lib/org-routes';
import { createSupabaseClient } from '../../lib/supabase';

export interface Env {
  SUPABASE_URL: string;
  SUPABASE_SERVICE_ROLE_KEY: string;
  /**
   * HMAC key that API-key hashes are verified against. Generated in this repo and bound to
   * production 2026-08-06 (BACKLOG.md CR12; verified with a real key — positive control 200,
   * wrong-secret 401). The receiver hashes minted keys with plain SHA-256, so this HMAC layer
   * is entirely this Worker's own; the earlier belief that a canonical value had to come from
   * `api-provisioning-receiver` was wrong. Still optional because the binding can be absent —
   * it is on `api-gateway-dev`, which binds only STRIPE_SECRET_KEY, SUPABASE_SERVICE_ROLE_KEY
   * and SUPABASE_URL (2026-09-27) — and while unset, API-key auth answers 503 and JWT routes
   * are unaffected.
   */
  API_KEY_HMAC_SECRET?: string;
  QUOTA_DO: DurableObjectNamespace;
  /**
   * Auth0 tenant that issues the dashboard's tokens, e.g. `tenant.us.auth0.com`.
   * Both the JWKS URL and the expected `iss` are derived from it (auth0VerifyParams).
   */
  AUTH0_DOMAIN: string;
  /**
   * Auth0 API identifier the token must be scoped to, e.g. `https://api.integritystudio.dev`.
   * When unset, `aud` is not validated — a token minted for any other API of the same
   * tenant would then be accepted, so it should be set in every deployed environment.
   */
  AUTH0_AUDIENCE?: string;
  /** Stripe secret key for billing portal session creation. */
  STRIPE_SECRET_KEY: string;
  /** App URL used as Stripe billing portal return URL (e.g. https://app.integritystudio.ai). */
  APP_URL?: string;
  /** Deployment environment: 'production' | 'staging' | 'development'. Controls log severity for missing config. */
  ENVIRONMENT?: string;
  /** PagerDuty Events API v2 integration key. When set, fires a trigger event on unhealthy health checks. */
  PAGERDUTY_INTEGRATION_KEY?: string;
  /**
   * JSON array of browser origins permitted to call this Worker. Falls back to the shared
   * production defaults in ../../lib/http/cors when unset or malformed.
   */
  ALLOWED_ORIGINS_JSON?: string;
  /**
   * Shared KV namespace backing the per-identity throttle on the routes that carry no org
   * quota (/v1/me, /v1/orgs, /bootstrap). Optional: when unbound the throttle degrades to a
   * per-isolate count rather than switching off.
   */
  RATE_LIMIT_KV?: KVNamespace;
  /**
   * Shared secret the Auth0 log stream sends as `Authorization: Bearer <token>` on every
   * delivery to /v1/auth0-logs (BACKLOG.md CR40). While unbound, that route answers 503.
   */
  AUTH0_LOG_STREAM_TOKEN?: string;
  /**
   * M2M client granted `read:logs` only, used by the scheduled Auth0 log poller
   * (lib/auth0-log-poller.ts). Production only: [env.dev] runs no cron.
   */
  AUTH0_LOG_READER_CLIENT_ID?: string;
  AUTH0_LOG_READER_CLIENT_SECRET?: string;
  /**
   * JSON array of `users.id` UUIDs allowed on the `/v1/admin/*` routes (routes/admin.ts).
   * A copy of the observability dashboard Worker's `STAFF_USER_IDS`; the two drift unless
   * changed together. Unset, `[]` or malformed means nobody is staff and every admin route
   * answers 403.
   */
  STAFF_USER_IDS?: string;
}

const APP_URL_FALLBACK = 'https://app.integritystudio.ai';
/** The org sub-path matched by pattern rather than by the ORG_ROUTES table. */
const REVOKE_API_KEY_PATH = /^\/api-keys\/([^/]+)\/revoke$/;
/** The staff directory and the staff twins of the org read routes (ADMIN-CV-GATEWAY-READ). */
const ADMIN_ORGS_PATH = '/v1/admin/orgs';
const ADMIN_ORG_PATH = /^\/v1\/admin\/orgs\/([^/]+)(\/.*)?$/;
/** The router's answer for a path no route serves. */
const ROUTER_NOT_FOUND_MESSAGE = 'Not found';

/** Every route here is GET or POST; OPTIONS is answered by the preflight branch in fetch(). */
const CORS_ALLOW_METHODS = 'GET, POST, OPTIONS';
/** The Flutter app sends a bearer token, and POST bodies are JSON. */
const CORS_ALLOW_HEADERS = 'Authorization, Content-Type';
/**
 * Non-simple response headers that browser JS needs to read (CR59). Includes both the
 * IETF draft fields and the legacy X-RateLimit-* names kept for backward compatibility.
 */
const CORS_EXPOSE_HEADERS =
  'RateLimit-Policy, RateLimit, Retry-After, X-RateLimit-Remaining-Minute, X-RateLimit-Remaining-Monthly';

// Emitted at most once per isolate so production logs are not flooded.
let auth0Warned = false;
let stripeKeyWarned = false;
let appUrlWarned = false;

/** V-22: Add security headers to all API responses. */
function withSecurityHeaders(res: Response): Response {
  const headers = new Headers(res.headers);
  headers.set('X-Content-Type-Options', 'nosniff');
  headers.set('Cache-Control', 'no-store');
  return new Response(res.body, { status: res.status, statusText: res.statusText, headers });
}

/**
 * CORS headers for a browser caller, from the shared helper (BACKLOG.md CR46). An origin
 * outside the allowlist is answered with the first allowed origin, never its own.
 *
 * No Access-Control-Allow-Credentials: the Flutter app authenticates with an Authorization
 * header, not cookies, so credentialed mode is unnecessary and would widen exposure.
 */
function corsHeaders(origin: string | null, env: Env): Record<string, string> {
  return buildCors(origin, {
    allowedOriginsJson: env.ALLOWED_ORIGINS_JSON,
    allowMethods: CORS_ALLOW_METHODS,
    allowHeaders: CORS_ALLOW_HEADERS,
    exposeHeaders: CORS_EXPOSE_HEADERS,
    disallowedOriginHeader: 'first-allowed',
  }).headers;
}

function withHeaders(res: Response, extra: Record<string, string>): Response {
  const headers = new Headers(res.headers);
  for (const [k, v] of Object.entries(extra)) headers.set(k, v);
  return new Response(res.body, { status: res.status, statusText: res.statusText, headers });
}

export default {
  /**
   * CORS is applied here, at the single outer boundary, rather than inside each route branch.
   * Every response — including the 401 from preVerifyToken and the terminal 404 — passes
   * through withHeaders, so a route added later cannot ship without CORS and be silently
   * unreachable from the browser. That is the failure this Worker had: no CORS at all, which
   * made every /v1/* call from integritystudio.ai fail preflight.
   */
  async fetch(request: Request, env: Env, ctx?: ExecutionContext): Promise<Response> {
    const cors = corsHeaders(request.headers.get('Origin'), env);
    if (request.method === 'OPTIONS') return noContent({ headers: cors });
    return withHeaders(await route(request, env, ctx), cors);
  },

  /**
   * Cron (wrangler.toml [triggers]): pull new Auth0 tenant log entries into auth0_logs.
   * A failed run throws, so it is recorded as an errored invocation rather than a success —
   * the stripe-webhook cron reported success for four months while doing nothing (CR20).
   */
  async scheduled(_event: ScheduledEvent, env: Env, _ctx: ExecutionContext): Promise<void> {
    const result = await pollAuth0Logs({
      auth0Domain: env.AUTH0_DOMAIN,
      clientId: env.AUTH0_LOG_READER_CLIENT_ID,
      clientSecret: env.AUTH0_LOG_READER_CLIENT_SECRET,
      kv: env.RATE_LIMIT_KV,
      supabaseUrl: env.SUPABASE_URL,
      serviceRoleKey: env.SUPABASE_SERVICE_ROLE_KEY,
    });
    if (result.status === 'failed') {
      throw new Error(`[auth0-log-poller] ${result.reason} (inserted ${result.inserted}, pages ${result.pages})`);
    }
    console.log(`[auth0-log-poller] inserted ${result.inserted} over ${result.pages} page(s)`);
  },
};

async function route(request: Request, env: Env, ctx?: ExecutionContext): Promise<Response> {
  if (!auth0Warned && (!env.AUTH0_DOMAIN || !env.AUTH0_AUDIENCE)) {
    // AUTH0_DOMAIN is fatal for every authenticated route, so it is an error, not a warning.
    // A missing AUTH0_AUDIENCE only relaxes `aud` validation, which fails open — hence the
    // separate message, since a silent relaxation is the harder problem to notice.
    if (!env.AUTH0_DOMAIN) {
      console.error('[api-gateway] AUTH0_DOMAIN is not set — every JWT-authenticated route will 401.');
    } else {
      console.warn('[api-gateway] AUTH0_AUDIENCE is not set — JWT aud claim validation is disabled.');
    }
    auth0Warned = true;
  }
  if (!stripeKeyWarned && !env.STRIPE_SECRET_KEY) {
    console.error('[api-gateway] STRIPE_SECRET_KEY is not set — billing portal will fail.');
    stripeKeyWarned = true;
  }
  if (!appUrlWarned && !env.APP_URL) {
    const isNonProd = env.ENVIRONMENT && env.ENVIRONMENT !== 'production';
    const log = isNonProd ? console.error : console.warn;
    log(
      `[api-gateway] APP_URL is not set — billing portal return_url defaults to ${APP_URL_FALLBACK}${isNonProd ? ' (staging/dev misconfiguration)' : ''}.`,
    );
    appUrlWarned = true;
  }

  const { pathname } = new URL(request.url);

  if (pathname === '/health' && request.method === 'GET') {
    return withSecurityHeaders(await handleHealthCheck(env.SUPABASE_URL, env.SUPABASE_SERVICE_ROLE_KEY, env.QUOTA_DO, {
      pdKey: env.PAGERDUTY_INTEGRATION_KEY,
      waitUntil: ctx ? (p: Promise<unknown>) => ctx.waitUntil(p) : undefined,
    }));
  }

  const routeOpts = {
    supabaseUrl: env.SUPABASE_URL,
    serviceRoleKey: env.SUPABASE_SERVICE_ROLE_KEY,
    auth0Domain: env.AUTH0_DOMAIN,
    auth0Audience: env.AUTH0_AUDIENCE,
    rateLimitKv: env.RATE_LIMIT_KV,
  };

  const machineRouteOpts = {
    ...routeOpts,
    hmacSecret: env.API_KEY_HMAC_SECRET,
  };

  if (pathname === '/v1/ingest/events' && request.method === 'POST') {
    return withSecurityHeaders(await handleIngestEvent(
      request,
      { ...machineRouteOpts, doNamespace: env.QUOTA_DO },
    ));
  }

  if (pathname === OTEL_INGEST_ROUTE && request.method === 'POST') {
    return withSecurityHeaders(await handleIngestOtel(
      request,
      { ...machineRouteOpts, doNamespace: env.QUOTA_DO },
    ));
  }

  if (pathname === '/v1/me' && request.method === 'GET') {
    return withSecurityHeaders(await handleMe(request, routeOpts));
  }

  // The staff routes sit outside the `/v1/orgs/:id` branch below on purpose: they must
  // skip its membership pre-check, per-org rate limit, quota reservation and ledger row,
  // because a staff read must never spend or show up in the customer's own usage. The
  // handlers enforce staff membership themselves (routes/admin.ts).
  const adminRouteOpts = {
    ...routeOpts,
    staffUserIds: env.STAFF_USER_IDS,
    waitUntil: ctx ? (p: Promise<unknown>) => ctx.waitUntil(p) : undefined,
  };

  if (pathname === ADMIN_ORGS_PATH && request.method === 'GET') {
    return withSecurityHeaders(await handleAdminListOrgs(request, adminRouteOpts));
  }

  const adminOrgMatch = pathname.match(ADMIN_ORG_PATH);
  if (adminOrgMatch) {
    const orgId = adminOrgMatch[1];
    const route = matchAdminOrgRoute(request.method, adminOrgMatch[2] ?? '');
    switch (route) {
      case 'billingStatus':
        return withSecurityHeaders(await handleAdminOrgBillingStatus(request, orgId, adminRouteOpts));
      case 'usageSummary':
        return withSecurityHeaders(await handleAdminUsageSummary(request, orgId, adminRouteOpts));
      case 'entitlements':
        return withSecurityHeaders(await handleAdminOrgEntitlements(request, orgId, adminRouteOpts));
      case 'quotaStatus':
        return withSecurityHeaders(await handleAdminQuotaStatus(request, orgId, { ...adminRouteOpts, doNamespace: env.QUOTA_DO }));
      case undefined:
        return withSecurityHeaders(notFound(ROUTER_NOT_FOUND_MESSAGE));
    }
  }

  if (pathname === '/v1/orgs' && request.method === 'GET') {
    return withSecurityHeaders(await handleListOrgs(request, routeOpts));
  }

  const orgMatch = pathname.match(/^\/v1\/orgs\/([^/]+)(\/.*)?$/);
  if (orgMatch) {
    const orgId = orgMatch[1];
    const subPath = orgMatch[2] ?? '';
    const startedAt = Date.now();

    // Verify the bearer token is authentic before consuming any quota.
    // An invalid or missing token returns 401 without touching the quota DO,
    // preventing unauthenticated callers from exhausting an org's quota.
    // UA08: pass orgId so cross-org credentials are refused before quota is consumed.
    const preAuth = await preVerifyToken(request, {
      ...routeOpts,
      hmacSecret: env.API_KEY_HMAC_SECRET,
      orgId,
    });
    if (!preAuth.ok) return withSecurityHeaders(preAuth.error);

    // CR36: uniform per-org edge rate limit, applied before the quota DO call.
    // Provides a per-minute ceiling that survives a DO outage (the DO is fail-open;
    // without this a DO outage removes the only per-minute limit on org routes).
    // Uniform rather than plan-tiered: plan-aware limiting would require a Supabase
    // lookup before the DO call; the DO already enforces plan-tiered limits on
    // requests that reach it. This layer protects the DO from load.
    const orgRateLimit = await checkOrgRateLimit(orgId, { RATE_LIMIT_KV: env.RATE_LIMIT_KV });
    if (!orgRateLimit.allowed) {
      return withSecurityHeaders(new Response(
        JSON.stringify({ error: { message: 'Too Many Requests' } }),
        {
          status: 429,
          headers: {
            'Content-Type': 'application/json',
            'Retry-After': String(orgRateLimit.retryAfterSeconds),
          },
        },
      ));
    }

    // TS31: a sub-path no route serves answers here, before the quota check, so a typo
    // spends none of the month and the DO never charges a request the ledger will not
    // record. The edge rate limit above still throttles probing.
    const route = matchOrgRoute(request.method, subPath);
    const revokeKeyId = request.method === 'POST' ? subPath.match(REVOKE_API_KEY_PATH)?.[1] : undefined;
    if (route === undefined && revokeKeyId === undefined) {
      return withSecurityHeaders(notFound(ROUTER_NOT_FOUND_MESSAGE));
    }

    const quotaOpts = {
      doNamespace: env.QUOTA_DO,
      supabaseUrl: env.SUPABASE_URL,
      serviceRoleKey: env.SUPABASE_SERVICE_ROLE_KEY,
    };

    // CR58: usage and quota reads still take this check, for the per-minute limit and
    // so the DO applies any month rollover or plan change before /quota/status reads it.
    const chargeMonthly = chargesMonthlyQuota(request.method, subPath);
    const quota = await enforceOrgQuota(orgId, quotaOpts, { chargeMonthly });
    if (!quota.ok) return withSecurityHeaders(quota.response);

    // UA01: the quota DO reserved one unit for this request; write the same unit
    // to `usage_events` (→ `usage_buckets_daily` via trigger) so what is enforced
    // is also what `/usage/summary` reports. Off the response path via waitUntil.
    const ledger = createSupabaseClient(env.SUPABASE_URL, env.SUPABASE_SERVICE_ROLE_KEY);
    const requestId = crypto.randomUUID();
    const withRateLimitHeaders = (response: Response): Response => {
      if (chargeMonthly) {
        const write = recordMeteredRequest(ledger, {
          orgId,
          route: meteredRoute(request.method, subPath),
          requestId,
          statusCode: response.status,
          latencyMs: Date.now() - startedAt,
        });
        // `recordMeteredRequest` never rejects; the catch is a guard so a future edit
        // inside it cannot turn a lost ledger row into an unhandled rejection here.
        const guarded = write.catch(() => undefined);
        if (ctx) ctx.waitUntil(guarded);
        else void guarded;
      }
      const rl = quota.rateLimitHeaders;
      const headers = new Headers(response.headers);
      headers.set('X-Content-Type-Options', 'nosniff');
      headers.set('Cache-Control', 'no-store');
      for (const [k, v] of Object.entries(rl)) headers.set(k, v);
      return new Response(response.body, { status: response.status, statusText: response.statusText, headers });
    };

    switch (route) {
      case 'dashboard':
        return withRateLimitHeaders(await handleOrgDashboard(request, orgId, routeOpts));
      case 'billingStatus':
        return withRateLimitHeaders(await handleOrgBillingStatus(request, orgId, routeOpts));
      case 'usageSummary':
        return withRateLimitHeaders(await handleUsageSummary(request, orgId, machineRouteOpts));
      case 'entitlements':
        return withRateLimitHeaders(await handleOrgEntitlements(request, orgId, machineRouteOpts));
      case 'quotaStatus':
        return withRateLimitHeaders(await handleQuotaStatus(request, orgId, { ...machineRouteOpts, doNamespace: env.QUOTA_DO }));
      case 'billingPortal':
        return withRateLimitHeaders(await handleBillingPortal(request, orgId, {
          ...routeOpts,
          stripeSecretKey: env.STRIPE_SECRET_KEY,
          returnUrl: `${env.APP_URL ?? APP_URL_FALLBACK}/#/billing`,
          waitUntil: ctx ? (p: Promise<unknown>) => ctx.waitUntil(p) : undefined,
        }));
      case 'checkoutSession':
        return withRateLimitHeaders(await handleCreateCheckoutSession(request, orgId, {
          ...routeOpts,
          stripeSecretKey: env.STRIPE_SECRET_KEY,
          appBaseUrl: env.APP_URL ?? APP_URL_FALLBACK,
          waitUntil: ctx ? (p: Promise<unknown>) => ctx.waitUntil(p) : undefined,
        }));
      case 'createApiKey':
        return withRateLimitHeaders(await handleCreateApiKey(request, orgId, machineRouteOpts));
      case undefined:
        break;
    }

    if (revokeKeyId !== undefined) {
      return withRateLimitHeaders(await handleRevokeApiKey(request, orgId, revokeKeyId, machineRouteOpts));
    }
  }

  if (pathname === '/bootstrap' && request.method === 'POST') {
    return withSecurityHeaders(await handleBootstrap(request, routeOpts));
  }

  if (pathname === '/v1/auth0-logs' && request.method === 'POST') {
    return withSecurityHeaders(await handleAuth0Logs(request, {
      supabaseUrl: env.SUPABASE_URL,
      serviceRoleKey: env.SUPABASE_SERVICE_ROLE_KEY,
      streamToken: env.AUTH0_LOG_STREAM_TOKEN,
    }));
  }

  return withSecurityHeaders(notFound(ROUTER_NOT_FOUND_MESSAGE));
}

export { QuotaDurableObject };
