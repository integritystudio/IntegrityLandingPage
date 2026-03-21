import { ok, notFound } from '../../lib/http';
import { handleMe } from './routes/me';
import { handleListOrgs, handleOrgDashboard, handleOrgBillingStatus } from './routes/orgs';
import { handleUsageSummary, handleOrgEntitlements } from './routes/usage';

export interface Env {
  SUPABASE_URL: string;
  SUPABASE_SERVICE_ROLE_KEY: string;
  SUPABASE_JWT_SECRET: string;
  API_KEY_HMAC_SECRET: string;
}

export default {
  async fetch(request: Request, env: Env): Promise<Response> {
    const { pathname } = new URL(request.url);

    if (pathname === '/health' && request.method === 'GET') {
      return ok({ ok: true, service: 'api-gateway' });
    }

    if (pathname === '/v1/me' && request.method === 'GET') {
      return handleMe(request, {
        jwtSecret: env.SUPABASE_JWT_SECRET,
        supabaseUrl: env.SUPABASE_URL,
        serviceRoleKey: env.SUPABASE_SERVICE_ROLE_KEY,
      });
    }

    const routeOpts = {
      jwtSecret: env.SUPABASE_JWT_SECRET,
      supabaseUrl: env.SUPABASE_URL,
      serviceRoleKey: env.SUPABASE_SERVICE_ROLE_KEY,
    };

    const machineRouteOpts = {
      ...routeOpts,
      hmacSecret: env.API_KEY_HMAC_SECRET,
    };

    if (pathname === '/v1/orgs' && request.method === 'GET') {
      return handleListOrgs(request, routeOpts);
    }

    const orgMatch = pathname.match(/^\/v1\/orgs\/([^/]+)(\/.*)?$/);
    if (orgMatch) {
      const orgId = orgMatch[1];
      const subPath = orgMatch[2] ?? '';

      if (subPath === '/dashboard' && request.method === 'GET') {
        return handleOrgDashboard(request, orgId, routeOpts);
      }
      if (subPath === '/billing-status' && request.method === 'GET') {
        return handleOrgBillingStatus(request, orgId, routeOpts);
      }
      if (subPath === '/usage/summary' && request.method === 'GET') {
        return handleUsageSummary(request, orgId, machineRouteOpts);
      }
      if (subPath === '/entitlements' && request.method === 'GET') {
        return handleOrgEntitlements(request, orgId, machineRouteOpts);
      }
    }

    return notFound('Not found');
  },
};
