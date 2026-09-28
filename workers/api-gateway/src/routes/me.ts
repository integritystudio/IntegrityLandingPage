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

/** `plan: null` means the user belongs to no organization; `ok: false` means a lookup failed. */
type OrgPlanResult = { ok: true; plan: string | null } | { ok: false };

const USER_SELECT = 'id, auth0_id, email, name, created_at, default_organization_id';
const ACTIVE_MEMBERSHIP = 'active';
/** The plan of a user with no organization — the same answer `plan_to_api_key_tier` gives an unknown plan. */
const DEFAULT_TIER = 'starter';

/**
 * The plan a user is on is their organization's `current_plan`, and nothing else.
 *
 * `users.tier` predates organizations and billing never wrote it, so this route
 * once reported `starter` for the owner of a paid `growth` org (UA04). Since
 * migration 20260927000000 the column is derived from the default org's plan by
 * trigger, which left the old fallback to it with nothing to add — as of UA11 it
 * is not read at all. The org is chosen the way the rest of the gateway chooses
 * it: `default_organization_id` first, otherwise the oldest active membership.
 * `plan: null` means the user has no organization, and the caller reports
 * `DEFAULT_TIER`. A failed lookup is an error, not a guess: reporting a wrong
 * plan to a paying user during an outage is worse than a 500, and the route
 * already 500s when the user row itself fails to load.
 */
async function resolveOrgPlan(sb: SupabaseClient, user: UserRow): Promise<OrgPlanResult> {
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
      return { ok: false };
    }
    if (!membership.data) return { ok: true, plan: null };
    orgId = membership.data.organization_id;
  }

  const org = await sb.query<OrgPlanRow>('organizations', {
    select: 'current_plan',
    filters: [{ column: 'id', operator: 'eq', value: orgId }],
    single: true,
  });
  if (!org.ok) {
    console.error('[me] organization lookup failed for org', orgId, org.error);
    return { ok: false };
  }
  return { ok: true, plan: org.data?.current_plan ?? null };
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
  if (!orgPlan.ok) {
    return serverError('Failed to load user profile');
  }

  return ok({
    id: user.id,
    email: user.email,
    name: user.name,
    tier: orgPlan.plan ?? DEFAULT_TIER,
    created_at: user.created_at,
  });
}
