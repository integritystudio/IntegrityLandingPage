import { ok, unauthorized, serverError } from '../../lib/http';
import { requireBearerToken } from '../../lib/http/request';
import { verifySupabaseJwt } from './auth';
import { loadOrgContext, buildBootstrapResponse } from './bootstrap';

export interface Env {
  SUPABASE_URL: string;
  SUPABASE_SERVICE_ROLE_KEY: string;
  SUPABASE_JWT_SECRET: string;
  ALLOWED_ORIGINS_JSON?: string;
}

async function handleBootstrap(request: Request, env: Env): Promise<Response> {
  const tokenResult = requireBearerToken(request);
  if (!tokenResult.ok) return tokenResult.error;

  const jwtResult = await verifySupabaseJwt(tokenResult.token, env.SUPABASE_JWT_SECRET);
  if (!jwtResult.ok) return jwtResult.error;

  const { payload } = jwtResult;
  if (!payload.sub) return unauthorized('JWT missing sub claim');

  const contextResult = await loadOrgContext(
    payload.sub,
    request.headers.get('x-org-id'),
    env.SUPABASE_URL,
    env.SUPABASE_SERVICE_ROLE_KEY,
  );
  if (!contextResult.ok) return contextResult.error;

  const response = await buildBootstrapResponse(
    payload.sub,
    payload.email ?? '',
    contextResult.orgs,
    contextResult.activeOrgId,
    env.SUPABASE_URL,
    env.SUPABASE_SERVICE_ROLE_KEY,
  );
  if (!response) return serverError('Failed to build bootstrap response');

  return new Response(JSON.stringify(response), {
    status: 200,
    headers: { 'content-type': 'application/json; charset=utf-8' },
  });
}

export default {
  async fetch(request: Request, env: Env): Promise<Response> {
    const { pathname } = new URL(request.url);

    if (pathname === '/health' && request.method === 'GET') {
      return ok({ ok: true, service: 'bootstrap-worker' });
    }

    if (pathname === '/bootstrap' && request.method === 'POST') {
      return handleBootstrap(request, env);
    }

    return serverError('Not found');
  },
};
