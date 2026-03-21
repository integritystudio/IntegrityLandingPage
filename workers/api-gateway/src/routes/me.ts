import { notFound, ok, unauthorized } from '../../../lib/http';
import { requireBearerToken } from '../../../lib/http/request';
import { verifyJwt } from '../../../lib/auth';
import { createSupabaseClient, type SupabaseClient } from '../../../lib/supabase';

interface MeHandlerOptions {
  jwtSecret: string;
  supabaseUrl: string;
  serviceRoleKey: string;
  /** Injected in tests to skip real HTTP calls. */
  _sbOverride?: SupabaseClient;
}

interface UserRow extends Record<string, unknown> {
  id: string;
  auth0_id: string;
  email: string;
  name: string | null;
  tier: string;
  default_organization_id: string | null;
  created_at: string;
}

export async function handleMe(request: Request, opts: MeHandlerOptions): Promise<Response> {
  const tokenResult = requireBearerToken(request);
  if (!tokenResult.ok) return tokenResult.error;

  const jwtResult = await verifyJwt(tokenResult.token, opts.jwtSecret);
  if (!jwtResult.ok) return jwtResult.error;

  const { payload } = jwtResult;
  if (!payload.sub) return unauthorized('JWT missing sub claim');

  const sb = opts._sbOverride ?? createSupabaseClient(opts.supabaseUrl, opts.serviceRoleKey);

  const result = await sb.query<UserRow>('users', {
    filters: [{ column: 'auth0_id', operator: 'eq', value: payload.sub }],
    select: 'id, auth0_id, email, name, tier, default_organization_id, created_at',
    limit: 1,
  });

  if (!result.ok || !Array.isArray(result.data) || result.data.length === 0) {
    return notFound('User not found');
  }

  const user = result.data[0];

  return ok({
    id: user.id,
    email: user.email,
    name: user.name,
    tier: user.tier,
    default_organization_id: user.default_organization_id,
    created_at: user.created_at,
  });
}
