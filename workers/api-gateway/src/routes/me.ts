import { notFound, ok } from '../../../lib/http';
import { createSupabaseClient, type SupabaseClient } from '../../../lib/supabase';
import { resolveJwt } from '../lib/helpers';

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
  const auth = await resolveJwt(request, opts.jwtSecret);
  if (!auth.ok) return auth.error;

  const sb = opts._sbOverride ?? createSupabaseClient(opts.supabaseUrl, opts.serviceRoleKey);

  const result = await sb.query<UserRow>('users', {
    filters: [{ column: 'auth0_id', operator: 'eq', value: auth.sub }],
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
