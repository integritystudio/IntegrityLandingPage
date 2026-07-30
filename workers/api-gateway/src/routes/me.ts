import { notFound, ok, serverError } from '../../../lib/http';
import { createSupabaseClient } from '../../../lib/supabase';
import { resolveJwtRateLimited, type UserTokenOptions } from '../lib/helpers';

interface MeHandlerOptions extends UserTokenOptions {
  supabaseUrl: string;
  serviceRoleKey: string;
}

interface UserRow extends Record<string, unknown> {
  id: string;
  auth0_id: string;
  email: string;
  name: string | null;
  tier: string;
  created_at: string;
}

export async function handleMe(request: Request, opts: MeHandlerOptions): Promise<Response> {
  const auth = await resolveJwtRateLimited(request, opts);
  if (!auth.ok) return auth.error;

  const sb = createSupabaseClient(opts.supabaseUrl, opts.serviceRoleKey);

  const result = await sb.query<UserRow>('users', {
    filters: [{ column: 'auth0_id', operator: 'eq', value: auth.sub }],
    select: 'id, auth0_id, email, name, tier, created_at',
    limit: 1,
  });

  if (!result.ok) {
    return serverError('Failed to load user profile');
  }

  if (result.data.length === 0) {
    return notFound('User not found');
  }

  const user = result.data[0];

  return ok({
    id: user.id,
    email: user.email,
    name: user.name,
    tier: user.tier,
    created_at: user.created_at,
  });
}
