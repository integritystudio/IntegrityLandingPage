import { ok, notFound } from '../../lib/http';
import { handleMe } from './routes/me';

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

    return notFound('Not found');
  },
};
