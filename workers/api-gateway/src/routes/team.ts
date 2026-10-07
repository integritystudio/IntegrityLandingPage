import { conflict, forbidden, getBearerToken, notFound, ok, serverError, serviceUnavailable, unauthorized } from '../../../lib/http';
import { createSupabaseClient, type SupabaseClient } from '../../../lib/supabase';
import { resolveJwtRateLimited, resolveUserId, writeAuditLog, type UserTokenOptions } from '../lib/helpers';

/**
 * "Join your team" (CR54). A corporate signup is unverified at its first provision, so the
 * receiver gives it a personal org (CR47), and nothing provisions it again once the address
 * is verified. These routes let that user join the team org for their email domain on request:
 * GET says whether there is one to join, POST joins it as a member once Auth0 says the address
 * is verified. Only an existing team org can be joined — creating one stays with the receiver.
 */
interface TeamHandlerOptions extends UserTokenOptions {
  supabaseUrl: string;
  serviceRoleKey: string;
}

interface TeamOrgRow extends Record<string, unknown> {
  id: string;
  name: string;
}

interface MembershipRow extends Record<string, unknown> {
  role: string;
  status: string;
}

interface UserinfoBody {
  email?: unknown;
  email_verified?: unknown;
}

const TEAM_ORG_TYPE = 'team';
const ACTIVE_MEMBERSHIP = 'active';
/** Joiners are members, never owners — the same rule the receiver applies to later joiners (CR47). */
const JOINED_ROLE = 'member';
const MEMBERSHIP_CONFLICT_COLUMNS = 'organization_id,user_id';
const AUTH0_USERINFO_PATH = '/userinfo';
/** Auth0 statuses on /userinfo that mean the token, not Auth0, is the problem. */
const USERINFO_TOKEN_REJECTED = new Set([401, 403]);

/** The part after the last `@`, lower-cased; `null` when there is none. */
export function emailDomain(email: string): string | null {
  const at = email.lastIndexOf('@');
  if (at < 0 || at === email.length - 1) return null;
  return email.slice(at + 1).toLowerCase();
}

type TeamLookup = { ok: true; team: TeamOrgRow | null } | { ok: false; error: Response };

async function findTeamOrg(sb: SupabaseClient, domain: string): Promise<TeamLookup> {
  const result = await sb.query<TeamOrgRow>('organizations', {
    select: 'id, name',
    filters: [
      { column: 'type', operator: 'eq', value: TEAM_ORG_TYPE },
      { column: 'domain', operator: 'eq', value: domain },
    ],
    limit: 1,
  });
  if (!result.ok) {
    console.error('[team] team org lookup failed for domain', domain, result.error);
    return { ok: false, error: serverError('Failed to look up team') };
  }
  return { ok: true, team: result.data[0] ?? null };
}

type MembershipLookup = { ok: true; membership: MembershipRow | null } | { ok: false; error: Response };

async function findMembership(sb: SupabaseClient, orgId: string, userId: string): Promise<MembershipLookup> {
  const result = await sb.query<MembershipRow>('organization_memberships', {
    select: 'role, status',
    filters: [
      { column: 'organization_id', operator: 'eq', value: orgId },
      { column: 'user_id', operator: 'eq', value: userId },
    ],
    limit: 1,
  });
  if (!result.ok) {
    console.error('[team] membership lookup failed for org', orgId, result.error);
    return { ok: false, error: serverError('Failed to look up membership') };
  }
  return { ok: true, membership: result.data[0] ?? null };
}

type VerifiedEmail = { ok: true; email: string } | { ok: false; error: Response };

/**
 * The verified address, from Auth0 itself. An access token carries no `email_verified` claim,
 * and `users.email` says nothing about verification, so /userinfo is the authority — the same
 * check the receiver makes before it groups anyone by domain.
 */
async function fetchVerifiedEmail(auth0Domain: string, token: string): Promise<VerifiedEmail> {
  let res: Response;
  try {
    res = await fetch(`https://${auth0Domain}${AUTH0_USERINFO_PATH}`, {
      headers: { authorization: `Bearer ${token}` },
    });
  } catch (err) {
    console.error('[team] Auth0 /userinfo unreachable', err);
    return { ok: false, error: serviceUnavailable('Could not verify email') };
  }
  if (USERINFO_TOKEN_REJECTED.has(res.status)) {
    return { ok: false, error: unauthorized('Could not verify email') };
  }
  if (!res.ok) {
    console.error('[team] Auth0 /userinfo returned', res.status);
    return { ok: false, error: serviceUnavailable('Could not verify email') };
  }
  const body = await res.json() as UserinfoBody;
  if (typeof body.email !== 'string' || body.email_verified !== true) {
    return { ok: false, error: forbidden('Verify your email address before joining your team') };
  }
  return { ok: true, email: body.email };
}

/** GET /v1/me/team — the team org for the caller's email domain, if there is one, and whether they belong to it. */
export async function handleGetTeam(request: Request, opts: TeamHandlerOptions): Promise<Response> {
  const auth = await resolveJwtRateLimited(request, opts);
  if (!auth.ok) return auth.error;

  const sb = createSupabaseClient(opts.supabaseUrl, opts.serviceRoleKey);
  const user = await resolveUserId(auth.sub, sb);
  if (!user.ok) return user.error;

  const domain = emailDomain(user.email);
  if (!domain) return ok({ domain: null, team: null, member: false });

  const lookup = await findTeamOrg(sb, domain);
  if (!lookup.ok) return lookup.error;
  if (!lookup.team) return ok({ domain, team: null, member: false });

  const membership = await findMembership(sb, lookup.team.id, user.userId);
  if (!membership.ok) return membership.error;

  return ok({
    domain,
    team: { id: lookup.team.id, name: lookup.team.name },
    member: membership.membership?.status === ACTIVE_MEMBERSHIP,
  });
}

/**
 * POST /v1/me/team — join the team org for the caller's verified email domain as a member.
 * Idempotent for an active member. A suspended or invited row is left alone (409): someone
 * put it in that state, and this route must not undo a removal.
 */
export async function handleJoinTeam(request: Request, opts: TeamHandlerOptions): Promise<Response> {
  const auth = await resolveJwtRateLimited(request, opts);
  if (!auth.ok) return auth.error;
  const token = getBearerToken(request);
  if (!token) return unauthorized('Missing bearer token');

  const sb = createSupabaseClient(opts.supabaseUrl, opts.serviceRoleKey);
  const user = await resolveUserId(auth.sub, sb);
  if (!user.ok) return user.error;

  const verified = await fetchVerifiedEmail(opts.auth0Domain, token);
  if (!verified.ok) return verified.error;

  const domain = emailDomain(verified.email);
  if (!domain) return forbidden('Your email address has no domain');

  const lookup = await findTeamOrg(sb, domain);
  if (!lookup.ok) return lookup.error;
  if (!lookup.team) return notFound('No team exists for your email domain');
  const team = lookup.team;

  const inserted = await sb.insertOrIgnore('organization_memberships', {
    organization_id: team.id,
    user_id: user.userId,
    role: JOINED_ROLE,
    status: ACTIVE_MEMBERSHIP,
  }, MEMBERSHIP_CONFLICT_COLUMNS);
  if (!inserted.ok) {
    console.error('[team] membership insert failed for org', team.id, inserted.error);
    return serverError('Failed to join team');
  }

  if (inserted.data.length === 0) {
    const existing = await findMembership(sb, team.id, user.userId);
    if (!existing.ok) return existing.error;
    if (existing.membership?.status !== ACTIVE_MEMBERSHIP) {
      return conflict('Your membership of this team is not active; ask a team owner');
    }
    return ok({ organizationId: team.id, name: team.name, role: existing.membership.role, joined: false });
  }

  await writeAuditLog(sb, {
    organization_id: team.id,
    actor_user_id: user.userId,
    action: 'org.member_joined',
    target_type: 'organization_membership',
    target_id: user.userId,
    new_values: { role: JOINED_ROLE, domain },
  });

  return ok({ organizationId: team.id, name: team.name, role: JOINED_ROLE, joined: true });
}
