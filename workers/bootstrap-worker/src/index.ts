import { ok, unauthorized, serverError, notFound } from '../../lib/http';
import { requireBearerToken } from '../../lib/http/request';
import { verifySupabaseJwt, supabaseJwtKey } from './auth';
import { loadOrgContext, buildBootstrapResponse } from './bootstrap';

export interface Env {
  SUPABASE_URL: string;
  SUPABASE_SERVICE_ROLE_KEY: string;
  SUPABASE_JWT_SECRET: string;
  ALLOWED_ORIGINS_JSON?: string;
}

const HARDCODED_ALLOWED_ORIGINS = [
  'https://integritystudio.ai',
  'https://www.integritystudio.ai',
];

function getAllowedOrigins(env: Env): string[] {
  if (env.ALLOWED_ORIGINS_JSON) {
    try {
      const parsed: unknown = JSON.parse(env.ALLOWED_ORIGINS_JSON);
      if (Array.isArray(parsed) && parsed.every((v) => typeof v === 'string')) {
        return parsed as string[];
      }
      console.error('[bootstrap] ALLOWED_ORIGINS_JSON must be a JSON array of strings; using defaults');
    } catch {
      console.error('[bootstrap] ALLOWED_ORIGINS_JSON is not valid JSON; using defaults');
    }
  }
  return HARDCODED_ALLOWED_ORIGINS;
}

function corsHeaders(origin: string | null, env: Env): Record<string, string> {
  const allowed = getAllowedOrigins(env);
  const allowedOrigin = origin && allowed.includes(origin) ? origin : allowed[0];
  return {
    'Access-Control-Allow-Origin': allowedOrigin,
    'Access-Control-Allow-Methods': 'POST, OPTIONS',
    'Access-Control-Allow-Headers': 'Authorization, Content-Type',
    'Access-Control-Max-Age': '86400',
    Vary: 'Origin',
  };
}

function withCors(response: Response, origin: string | null, env: Env): Response {
  const headers = new Headers(response.headers);
  for (const [k, v] of Object.entries(corsHeaders(origin, env))) headers.set(k, v);
  return new Response(response.body, { status: response.status, statusText: response.statusText, headers });
}

async function handleBootstrap(request: Request, env: Env): Promise<Response> {
  const tokenResult = requireBearerToken(request);
  if (!tokenResult.ok) return tokenResult.error;

  const jwtResult = await verifySupabaseJwt(
    tokenResult.token,
    supabaseJwtKey({ supabaseUrl: env.SUPABASE_URL, jwtSecret: env.SUPABASE_JWT_SECRET }),
  );
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
    const origin = request.headers.get('Origin');

    if (request.method === 'OPTIONS') {
      return new Response(null, {
        status: 204,
        headers: corsHeaders(origin, env),
      });
    }

    if (pathname === '/health' && request.method === 'GET') {
      return ok({ ok: true, service: 'bootstrap-worker' });
    }

    if (pathname === '/bootstrap' && request.method === 'POST') {
      return withCors(await handleBootstrap(request, env), origin, env);
    }

    return withCors(notFound('Not found'), origin, env);
  },
};
