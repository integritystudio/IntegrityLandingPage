import { ok, notFound, noContent } from '../../lib/http';
import { getAllowedOrigins, ALLOWED_ORIGINS } from '../../http-helpers';
import { handleMe } from './routes/me';
import { handleListOrgs, handleOrgDashboard, handleOrgBillingStatus, handleBillingPortal } from './routes/orgs';
import { handleUsageSummary, handleOrgEntitlements, handleQuotaStatus } from './routes/usage';
import { handleCreateApiKey, handleRevokeApiKey } from './routes/api-keys';
import { handleHealthCheck } from './routes/health';
import { handleIngestEvent, handleIngestOtel, OTEL_INGEST_ROUTE } from './routes/ingest';
import { handleBootstrap } from './routes/bootstrap';
import { QuotaDurableObject } from './durable-objects/quota';
import { enforceOrgQuota } from './lib/quota';
import { preVerifyToken } from './lib/helpers';

export interface Env {
  SUPABASE_URL: string;
  SUPABASE_SERVICE_ROLE_KEY: string;
  /**
   * HMAC key that API-key hashes are verified against. Optional because production has
   * never had it bound: the canonical value belongs to `api-provisioning-receiver`, which
   * mints the keys, and inventing one here would fail to verify every key already issued
   * (BACKLOG.md CR12). While unset, API-key auth answers 503 and JWT routes are unaffected.
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
   * production defaults in ../../http-helpers when unset or malformed.
   */
  ALLOWED_ORIGINS_JSON?: string;
  /**
   * Shared KV namespace backing the per-identity throttle on the routes that carry no org
   * quota (/v1/me, /v1/orgs, /bootstrap). Optional: when unbound the throttle degrades to a
   * per-isolate count rather than switching off.
   */
  RATE_LIMIT_KV?: KVNamespace;
}

const APP_URL_FALLBACK = 'https://app.integritystudio.ai';

/** Every route here is GET or POST; OPTIONS is answered by the preflight branch in fetch(). */
const CORS_ALLOW_METHODS = 'GET, POST, OPTIONS';
/** The Flutter app sends a bearer token, and POST bodies are JSON. */
const CORS_ALLOW_HEADERS = 'Authorization, Content-Type';
const CORS_MAX_AGE_SECONDS = '86400';

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
 * CORS headers for a browser caller. An origin outside the allowlist is answered with the
 * first allowed origin rather than its own value, so an unknown origin never receives an
 * Access-Control-Allow-Origin that matches it.
 *
 * No Access-Control-Allow-Credentials: the Flutter app authenticates with an Authorization
 * header, not cookies, so credentialed mode is unnecessary and would widen exposure.
 */
function corsHeaders(origin: string | null, env: Env): Record<string, string> {
  const allowed = getAllowedOrigins(env);
  // getAllowedOrigins passes an explicit `[]` straight through, which would make allowed[0]
  // undefined and emit the literal header value "undefined". Fall back to the shared default.
  const fallbackOrigin = allowed[0] ?? ALLOWED_ORIGINS[0];
  return {
    'Access-Control-Allow-Origin': origin && allowed.includes(origin) ? origin : fallbackOrigin,
    'Access-Control-Allow-Methods': CORS_ALLOW_METHODS,
    'Access-Control-Allow-Headers': CORS_ALLOW_HEADERS,
    'Access-Control-Max-Age': CORS_MAX_AGE_SECONDS,
    // Vary: Origin so a cache cannot serve origin-A's response to origin-B.
    Vary: 'Origin',
  };
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
      { ...machineRouteOpts },
      ctx ? (p: Promise<unknown>) => ctx.waitUntil(p) : undefined,
    ));
  }

  if (pathname === OTEL_INGEST_ROUTE && request.method === 'POST') {
    return withSecurityHeaders(await handleIngestOtel(
      request,
      { ...machineRouteOpts, doNamespace: env.QUOTA_DO },
      ctx ? (p: Promise<unknown>) => ctx.waitUntil(p) : undefined,
    ));
  }

  if (pathname === '/v1/me' && request.method === 'GET') {
    return withSecurityHeaders(await handleMe(request, routeOpts));
  }

  if (pathname === '/v1/orgs' && request.method === 'GET') {
    return withSecurityHeaders(await handleListOrgs(request, routeOpts));
  }

  const orgMatch = pathname.match(/^\/v1\/orgs\/([^/]+)(\/.*)?$/);
  if (orgMatch) {
    const orgId = orgMatch[1];
    const subPath = orgMatch[2] ?? '';

    // Verify the bearer token is authentic before consuming any quota.
    // An invalid or missing token returns 401 without touching the quota DO,
    // preventing unauthenticated callers from exhausting an org's quota.
    const preAuth = await preVerifyToken(request, {
      ...routeOpts,
      hmacSecret: env.API_KEY_HMAC_SECRET,
    });
    if (!preAuth.ok) return withSecurityHeaders(preAuth.error);

    const quotaOpts = {
      doNamespace: env.QUOTA_DO,
      supabaseUrl: env.SUPABASE_URL,
      serviceRoleKey: env.SUPABASE_SERVICE_ROLE_KEY,
    };

    const quota = await enforceOrgQuota(orgId, quotaOpts);
    if (!quota.ok) return withSecurityHeaders(quota.response);

    const withRateLimitHeaders = (response: Response): Response => {
      const rl = quota.rateLimitHeaders;
      const headers = new Headers(response.headers);
      headers.set('X-Content-Type-Options', 'nosniff');
      headers.set('Cache-Control', 'no-store');
      for (const [k, v] of Object.entries(rl)) headers.set(k, v);
      return new Response(response.body, { status: response.status, statusText: response.statusText, headers });
    };

    if (subPath === '/dashboard' && request.method === 'GET') {
      return withRateLimitHeaders(await handleOrgDashboard(request, orgId, routeOpts));
    }
    if (subPath === '/billing-status' && request.method === 'GET') {
      return withRateLimitHeaders(await handleOrgBillingStatus(request, orgId, routeOpts));
    }
    if (subPath === '/usage/summary' && request.method === 'GET') {
      return withRateLimitHeaders(await handleUsageSummary(request, orgId, machineRouteOpts));
    }
    if (subPath === '/entitlements' && request.method === 'GET') {
      return withRateLimitHeaders(await handleOrgEntitlements(request, orgId, machineRouteOpts));
    }
    if (subPath === '/quota/status' && request.method === 'GET') {
      return withRateLimitHeaders(await handleQuotaStatus(request, orgId, { ...machineRouteOpts, doNamespace: env.QUOTA_DO }));
    }
    if (subPath === '/billing-portal' && request.method === 'POST') {
      return withRateLimitHeaders(await handleBillingPortal(request, orgId, {
        ...routeOpts,
        stripeSecretKey: env.STRIPE_SECRET_KEY,
        returnUrl: `${env.APP_URL ?? APP_URL_FALLBACK}/#/billing`,
        waitUntil: ctx ? (p: Promise<unknown>) => ctx.waitUntil(p) : undefined,
      }));
    }
    if (subPath === '/api-keys' && request.method === 'POST') {
      return withRateLimitHeaders(await handleCreateApiKey(request, orgId, machineRouteOpts));
    }

    const revokeMatch = subPath.match(/^\/api-keys\/([^/]+)\/revoke$/);
    if (revokeMatch && request.method === 'POST') {
      return withRateLimitHeaders(await handleRevokeApiKey(request, orgId, revokeMatch[1], machineRouteOpts));
    }
  }

  if (pathname === '/bootstrap' && request.method === 'POST') {
    return withSecurityHeaders(await handleBootstrap(request, routeOpts));
  }

  return withSecurityHeaders(notFound('Not found'));
}

export { QuotaDurableObject };
