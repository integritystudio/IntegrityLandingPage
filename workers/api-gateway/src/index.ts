import { ok, notFound } from '../../lib/http';

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

    return notFound('Not found');
  },
};
