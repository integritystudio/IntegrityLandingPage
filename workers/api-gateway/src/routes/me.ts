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
  default_organization_id: string | null;
}

interface OrgPlanRow extends Record<string, unknown> {
  current_plan: string | null;
}

interface MembershipOrgRow extends Record<string, unknown> {
  organization_id: string;
}

type SupabaseClient = ReturnType<typeof createSupabaseClient>;

const USER_SELECT = 'id, auth0_id, email, name, tier, created_at, default_organization_id';
const ACTIVE_MEMBERSHIP = 'active';

/**
 * The plan a user is on is their organization's `current_plan`, not `users.tier`.
 *
 * `users.tier` predates organizations and nothing in billing updates it: the
 * owner of a paid `growth` org still carried `starter` there and this route
 * reported it, while `api-keys-create` (which reads `org.current_plan ??
 * user.tier`) minted `growth` keys for the same user. The org is chosen the
 * way the rest of the gateway chooses it — `default_organization_id` first,
 * otherwise the oldest active membership — and `null` means "no org plan
 * resolved", in which case the caller falls back to the legacy column.
 */
async function resolveOrgPlan(sb: SupabaseClient, user: UserRow): Promise<string | null> {
  let orgId = user.default_organization_id;

  if (!orgId) {
    const membership = await sb.query<MembershipOrgRow>('organization_memberships', {
      select: 'organization_id',
      filters: [
        { column: 'user_id', operator: 'eq', value: user.id },
        { column: 'status', operator: 'eq', value: ACTIVE_MEMBERSHIP },
      ],
      order: { column: 'created_at', ascending: true },
      single: true,
    });
    if (!membership.ok) {
      console.error('[me] membership lookup failed for user', user.id, membership.error);
      return null;
    }
    if (!membership.data) return null;
    orgId = membership.data.organization_id;
  }

  const org = await sb.query<OrgPlanRow>('organizations', {
    select: 'current_plan',
    filters: [{ column: 'id', operator: 'eq', value: orgId }],
    single: true,
  });
  if (!org.ok) {
    console.error('[me] organization lookup failed for org', orgId, org.error);
    return null;
  }
  return org.data?.current_plan ?? null;
}

export async function handleMe(request: Request, opts: MeHandlerOptions): Promise<Response> {
  const auth = await resolveJwtRateLimited(request, opts);
  if (!auth.ok) return auth.error;

  const sb = createSupabaseClient(opts.supabaseUrl, opts.serviceRoleKey);

  const result = await sb.query<UserRow>('users', {
    filters: [{ column: 'auth0_id', operator: 'eq', value: auth.sub }],
    select: USER_SELECT,
    limit: 1,
  });

  if (!result.ok) {
    return serverError('Failed to load user profile');
  }

  if (result.data.length === 0) {
    return notFound('User not found');
  }

  const user = result.data[0];
  const orgPlan = await resolveOrgPlan(sb, user);

  return ok({
    id: user.id,
    email: user.email,
    name: user.name,
    tier: orgPlan ?? user.tier,
    created_at: user.created_at,
  });
}
