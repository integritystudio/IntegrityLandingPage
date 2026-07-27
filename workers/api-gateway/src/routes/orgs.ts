import Stripe from 'stripe';
import { ok, forbidden, notFound, serverError } from '../../../lib/http';
import { createSupabaseClient, type SupabaseClient } from '../../../lib/supabase';
import type { Organization, OrgRole, OrgMembership, Entitlement } from '../../../lib/types';
import { resolveJwt, buildEntitlementMap, writeAuditLog } from '../lib/helpers';

interface OrgsHandlerOptions {
  jwtSecret: string;
  supabaseUrl: string;
  serviceRoleKey: string;
  jwtIssuerUrl?: string;
}

interface BillingPortalHandlerOptions extends OrgsHandlerOptions {
  stripeSecretKey: string;
  returnUrl: string;
  waitUntil?: (promise: Promise<unknown>) => void;
  _stripeOverride?: Stripe;
}

const BILLING_ROLES: OrgRole[] = ['owner', 'billing_admin'];

async function loadUserMemberships(
  userId: string,
  sb: SupabaseClient,
): Promise<OrgMembership[]> {
  const result = await sb.query<OrgMembership>('organization_memberships', {
    select: 'organization_id, user_id, role, status',
    filters: [
      { column: 'user_id', operator: 'eq', value: userId },
      { column: 'status', operator: 'eq', value: 'active' },
    ],
  });
  if (!result.ok) return [];
  return result.data;
}

async function loadOrgsForMemberships(
  memberships: OrgMembership[],
  sb: SupabaseClient,
): Promise<Array<Organization & { role: OrgRole }>> {
  if (memberships.length === 0) return [];

  const orgIds = new Set(memberships.map((m) => m.organization_id));
  const roleByOrgId = new Map(memberships.map((m) => [m.organization_id, m.role]));

  const result = await sb.query<Organization>('organizations', {
    select: 'id, slug, name, billing_status, current_plan, quota_version',
    filters: [{ column: 'id', operator: 'in', value: [...orgIds] }],
  });

  if (!result.ok) return [];

  return result.data.map((org) => ({ ...org, role: roleByOrgId.get(org.id) as OrgRole }));
}

export async function handleListOrgs(
  request: Request,
  opts: OrgsHandlerOptions,
): Promise<Response> {
  const auth = await resolveJwt(request, opts.jwtSecret, opts.jwtIssuerUrl);
  if (!auth.ok) return auth.error;

  const sb = createSupabaseClient(opts.supabaseUrl, opts.serviceRoleKey);
  const memberships = await loadUserMemberships(auth.sub, sb);

  if (memberships.length === 0) {
    return ok({ organizations: [] });
  }

  const orgs = await loadOrgsForMemberships(memberships, sb);
  return ok({ organizations: orgs });
}

export async function handleOrgDashboard(
  request: Request,
  orgId: string,
  opts: OrgsHandlerOptions,
): Promise<Response> {
  const auth = await resolveJwt(request, opts.jwtSecret, opts.jwtIssuerUrl);
  if (!auth.ok) return auth.error;

  const sb = createSupabaseClient(opts.supabaseUrl, opts.serviceRoleKey);
  const memberships = await loadUserMemberships(auth.sub, sb);
  const membership = memberships.find((m) => m.organization_id === orgId);
  if (!membership) return forbidden('Not a member of this organization');

  const orgResult = await sb.query<Organization>('organizations', {
    select: 'id, slug, name, billing_status, current_plan, quota_version',
    filters: [{ column: 'id', operator: 'eq', value: orgId }],
    limit: 1,
  });

  if (!orgResult.ok || orgResult.data.length === 0) {
    return notFound('Organization not found');
  }

  const org = orgResult.data[0];

  const entResult = await sb.query<Entitlement>('entitlements', {
    filters: [{ column: 'organization_id', operator: 'eq', value: orgId }],
  });

  const entitlements = buildEntitlementMap(entResult.ok ? entResult.data : []);

  return ok({
    org,
    role: membership.role,
    entitlements,
  });
}

export async function handleOrgBillingStatus(
  request: Request,
  orgId: string,
  opts: OrgsHandlerOptions,
): Promise<Response> {
  const auth = await resolveJwt(request, opts.jwtSecret, opts.jwtIssuerUrl);
  if (!auth.ok) return auth.error;

  const sb = createSupabaseClient(opts.supabaseUrl, opts.serviceRoleKey);
  const memberships = await loadUserMemberships(auth.sub, sb);
  const membership = memberships.find((m) => m.organization_id === orgId);
  if (!membership) return forbidden('Not a member of this organization');

  const orgResult = await sb.query<Organization>('organizations', {
    select: 'id, billing_status, current_plan, quota_version',
    filters: [{ column: 'id', operator: 'eq', value: orgId }],
    limit: 1,
  });

  if (!orgResult.ok || orgResult.data.length === 0) {
    return serverError('Failed to load organization');
  }

  const org = orgResult.data[0];

  return ok({
    org_id: orgId,
    billing_status: org.billing_status,
    current_plan: org.current_plan,
    quota_version: org.quota_version,
    role: membership.role,
  });
}

/**
 * POST /v1/orgs/:id/billing-portal
 * Creates a Stripe Customer Portal session and returns the session URL.
 * Requires owner or billing_admin role.
 */
export async function handleBillingPortal(
  request: Request,
  orgId: string,
  opts: BillingPortalHandlerOptions,
): Promise<Response> {
  const auth = await resolveJwt(request, opts.jwtSecret, opts.jwtIssuerUrl);
  if (!auth.ok) return auth.error;

  const sb = createSupabaseClient(opts.supabaseUrl, opts.serviceRoleKey);
  const memberships = await loadUserMemberships(auth.sub, sb);
  const membership = memberships.find((m) => m.organization_id === orgId);
  if (!membership) return forbidden('Not a member of this organization');

  if (!BILLING_ROLES.includes(membership.role)) {
    return forbidden('Billing portal requires owner or billing_admin role');
  }

  const orgResult = await sb.query<{ id: string; stripe_customer_id: string | null }>(
    'organizations',
    {
      select: 'id, stripe_customer_id',
      filters: [{ column: 'id', operator: 'eq', value: orgId }],
      limit: 1,
    },
  );

  if (!orgResult.ok || orgResult.data.length === 0) {
    return notFound('Organization not found');
  }

  const org = orgResult.data[0];
  if (!org.stripe_customer_id) {
    return notFound('No billing account found for this organization');
  }

  const STRIPE_CUSTOMER_ID_PATTERN = /^cus_[A-Za-z0-9]+$/;
  if (!STRIPE_CUSTOMER_ID_PATTERN.test(String(org.stripe_customer_id))) {
    return serverError('Invalid billing account configuration');
  }

  let sessionUrl: string;
  try {
    const stripe =
      opts._stripeOverride ??
      new Stripe(opts.stripeSecretKey, {
        httpClient: Stripe.createFetchHttpClient(),
      });

    const session = await stripe.billingPortal.sessions.create({
      customer: org.stripe_customer_id,
      return_url: opts.returnUrl,
    });
    sessionUrl = session.url;
  } catch (e) {
    console.error('[billing-portal] Stripe error:', e);
    return serverError('Failed to create billing portal session');
  }

  const auditLog = writeAuditLog(sb, {
    organization_id: orgId,
    action: 'billing_portal.accessed',
    target_type: 'org',
    target_id: orgId,
    metadata: { actor_auth0_id: auth.sub },
  });

  if (opts.waitUntil) {
    opts.waitUntil(auditLog);
  } else {
    await auditLog;
  }

  return ok({ url: sessionUrl });
}
