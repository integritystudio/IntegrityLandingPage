import { ok, notFound } from '../../lib/http';
import { requireBearerToken } from '../../lib/http/request';
import { handleMe } from './routes/me';
import { handleListOrgs, handleOrgDashboard, handleOrgBillingStatus, handleBillingPortal } from './routes/orgs';
import { handleUsageSummary, handleOrgEntitlements, handleQuotaStatus } from './routes/usage';
import { handleCreateApiKey, handleRevokeApiKey } from './routes/api-keys';
import { handleHealthCheck } from './routes/health';
import { handleIngestEvent, handleIngestOtel, OTEL_INGEST_ROUTE } from './routes/ingest';
import { QuotaDurableObject } from './durable-objects/quota';
import { enforceOrgQuota } from './lib/quota';

export interface Env {
  SUPABASE_URL: string;
  SUPABASE_SERVICE_ROLE_KEY: string;
  SUPABASE_JWT_SECRET: string;
  API_KEY_HMAC_SECRET: string;
  QUOTA_DO: DurableObjectNamespace;
  /** JWT issuer URL for `iss` claim validation (V-02). Set to Supabase auth URL. */
  SUPABASE_JWT_ISSUER?: string;
  /** Stripe secret key for billing portal session creation. */
  STRIPE_SECRET_KEY: string;
  /** App URL used as Stripe billing portal return URL (e.g. https://app.integritystudio.ai). */
  APP_URL?: string;
  /** Deployment environment: 'production' | 'staging' | 'development'. Controls log severity for missing config. */
  ENVIRONMENT?: string;
  /** PagerDuty Events API v2 integration key. When set, fires a trigger event on unhealthy health checks. */
  PAGERDUTY_INTEGRATION_KEY?: string;
}

const APP_URL_FALLBACK = 'https://app.integritystudio.ai';

// Emitted at most once per isolate so production logs are not flooded.
let jwtIssuerWarned = false;
let stripeKeyWarned = false;
let appUrlWarned = false;

export default {
  async fetch(request: Request, env: Env, ctx?: ExecutionContext): Promise<Response> {
    if (!jwtIssuerWarned && !env.SUPABASE_JWT_ISSUER) {
      console.warn(
        '[api-gateway] SUPABASE_JWT_ISSUER is not set — JWT iss claim validation (V-02) is disabled.',
      );
      jwtIssuerWarned = true;
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
      return handleHealthCheck(env.SUPABASE_URL, env.SUPABASE_SERVICE_ROLE_KEY, env.QUOTA_DO, {
        pdKey: env.PAGERDUTY_INTEGRATION_KEY,
        waitUntil: ctx ? (p: Promise<unknown>) => ctx.waitUntil(p) : undefined,
      });
    }

    const routeOpts = {
      jwtSecret: env.SUPABASE_JWT_SECRET,
      supabaseUrl: env.SUPABASE_URL,
      serviceRoleKey: env.SUPABASE_SERVICE_ROLE_KEY,
      jwtIssuerUrl: env.SUPABASE_JWT_ISSUER,
    };

    const machineRouteOpts = {
      ...routeOpts,
      hmacSecret: env.API_KEY_HMAC_SECRET,
    };

    if (pathname === '/v1/ingest/events' && request.method === 'POST') {
      return handleIngestEvent(
        request,
        { ...machineRouteOpts },
        ctx ? (p: Promise<unknown>) => ctx.waitUntil(p) : undefined,
      );
    }

    if (pathname === OTEL_INGEST_ROUTE && request.method === 'POST') {
      return handleIngestOtel(
        request,
        { ...machineRouteOpts, doNamespace: env.QUOTA_DO },
        ctx ? (p: Promise<unknown>) => ctx.waitUntil(p) : undefined,
      );
    }

    if (pathname === '/v1/me' && request.method === 'GET') {
      return handleMe(request, routeOpts);
    }

    if (pathname === '/v1/orgs' && request.method === 'GET') {
      return handleListOrgs(request, routeOpts);
    }

    const orgMatch = pathname.match(/^\/v1\/orgs\/([^/]+)(\/.*)?$/);
    if (orgMatch) {
      const orgId = orgMatch[1];
      const subPath = orgMatch[2] ?? '';

      // Require a bearer token before quota enforcement to prevent unauthenticated
      // callers from triggering DO reads and leaking org existence via 429 vs 401.
      // Full auth (JWT or API key) is delegated to each route handler.
      const tokenResult = requireBearerToken(request);
      if (!tokenResult.ok) return tokenResult.error;

      const quotaOpts = {
        doNamespace: env.QUOTA_DO,
        supabaseUrl: env.SUPABASE_URL,
        serviceRoleKey: env.SUPABASE_SERVICE_ROLE_KEY,
      };

      const quota = await enforceOrgQuota(orgId, quotaOpts);
      if (!quota.ok) return quota.response;

      const withRateLimitHeaders = (response: Response): Response => {
        const rl = quota.rateLimitHeaders;
        if (Object.keys(rl).length === 0) return response;
        const headers = new Headers(response.headers);
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

    return notFound('Not found');
  },
};

export { QuotaDurableObject };
