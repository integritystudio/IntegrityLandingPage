import Stripe from 'stripe';
import { ok, badRequest, conflict, forbidden, notFound, serverError } from '../../../lib/http';
import { createSupabaseClient, type SupabaseClient } from '../../../lib/supabase';
import { requireBearerToken, safeParseJson } from '../../../lib/http/request';
import { parseApiKey } from '../../../lib/api-keys';
import type { Organization, OrgRole, OrgMembership, Entitlement } from '../../../lib/types';
import { resolveJwt, resolveJwtRateLimited, buildEntitlementMap, writeAuditLog, auth0VerifyParams, resolveUserId, type UserTokenOptions } from '../lib/helpers';

interface OrgsHandlerOptions extends UserTokenOptions {
  supabaseUrl: string;
  serviceRoleKey: string;
}

interface BillingPortalHandlerOptions extends OrgsHandlerOptions {
  stripeSecretKey: string;
  returnUrl: string;
  waitUntil?: (promise: Promise<unknown>) => void;
  _stripeOverride?: Stripe;
}

interface CheckoutSessionHandlerOptions extends OrgsHandlerOptions {
  stripeSecretKey: string;
  appBaseUrl: string;
  waitUntil?: (promise: Promise<unknown>) => void;
  _stripeOverride?: Stripe;
}

const BILLING_ROLES: OrgRole[] = ['owner', 'billing_admin'];

/**
 * Shared auth gate for the billing routes: each requires a user session holding a
 * billing-capable role on the target org, and each must reject API keys explicitly.
 * `preVerifyToken` in index.ts accepts key-shaped tokens, so without the parseApiKey
 * check a key-authenticated caller falls through to `resolveJwt` and gets an opaque
 * 401 instead of "keys can't do this" ([[CR22]]).
 *
 * `operation` is interpolated into the two 403 messages so each route keeps its own
 * wording — 'Billing portal' reproduces the strings `handleBillingPortal` returned
 * before this was extracted, which orgs.test.ts asserts on verbatim.
 */
async function authorizeBillingRequest(
  request: Request,
  orgId: string,
  opts: OrgsHandlerOptions,
  sb: SupabaseClient,
  operation: string,
): Promise<{ ok: true; sub: string } | { ok: false; error: Response }> {
  const tokenResult = requireBearerToken(request);
  if (!tokenResult.ok) return { ok: false, error: tokenResult.error };
  if (parseApiKey(tokenResult.token).ok) {
    return {
      ok: false,
      error: forbidden(`${operation} requires a user session; API keys are not accepted`),
    };
  }

  const auth = await resolveJwt(request, auth0VerifyParams(opts));
  if (!auth.ok) return { ok: false, error: auth.error };

  const user = await resolveUserId(auth.sub, sb);
  if (!user.ok) return { ok: false, error: user.error };

  const memberships = await loadUserMemberships(user.userId, sb);
  const membership = memberships.find((m) => m.organization_id === orgId);
  if (!membership) return { ok: false, error: forbidden('Not a member of this organization') };

  if (!BILLING_ROLES.includes(membership.role)) {
    return { ok: false, error: forbidden(`${operation} requires owner or billing_admin role`) };
  }

  return { ok: true, sub: auth.sub };
}

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
  const auth = await resolveJwtRateLimited(request, opts);
  if (!auth.ok) return auth.error;

  const sb = createSupabaseClient(opts.supabaseUrl, opts.serviceRoleKey);
  const user = await resolveUserId(auth.sub, sb);
  if (!user.ok) return user.error;
  const memberships = await loadUserMemberships(user.userId, sb);

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
  const auth = await resolveJwt(request, auth0VerifyParams(opts));
  if (!auth.ok) return auth.error;

  const sb = createSupabaseClient(opts.supabaseUrl, opts.serviceRoleKey);
  const user = await resolveUserId(auth.sub, sb);
  if (!user.ok) return user.error;
  const memberships = await loadUserMemberships(user.userId, sb);
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
  const auth = await resolveJwt(request, auth0VerifyParams(opts));
  if (!auth.ok) return auth.error;

  const sb = createSupabaseClient(opts.supabaseUrl, opts.serviceRoleKey);
  const user = await resolveUserId(auth.sub, sb);
  if (!user.ok) return user.error;
  const memberships = await loadUserMemberships(user.userId, sb);
  const membership = memberships.find((m) => m.organization_id === orgId);
  if (!membership) return forbidden('Not a member of this organization');

  const orgResult = await sb.query<Organization & { stripe_customer_id: string | null }>('organizations', {
    select: 'id, billing_status, current_plan, quota_version, stripe_customer_id',
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
    /**
     * Whether a Stripe customer exists for this org. Exposed as a boolean rather
     * than the customer id, which the client has no use for and which should not
     * leave the Worker. Without it the client cannot tell a billable org from one
     * that has never been through checkout, so it offered "Manage Billing"
     * unconditionally and every such click returned 404 from handleBillingPortal
     * (20 of 22 orgs on 2026-07-31).
     */
    has_billing_account: Boolean(org.stripe_customer_id),
  });
}

/**
 * POST /v1/orgs/:id/billing-portal
 * Creates a Stripe Customer Portal session and returns the session URL.
 * Requires a user session (Supabase JWT) with owner or billing_admin role.
 * API keys are rejected with 403 — the shared `preVerifyToken` gate accepts
 * them, so without this check a key-authenticated caller would fall through to
 * `resolveJwt` and get an opaque 401 instead of "keys can't do this".
 */
export async function handleBillingPortal(
  request: Request,
  orgId: string,
  opts: BillingPortalHandlerOptions,
): Promise<Response> {
  const sb = createSupabaseClient(opts.supabaseUrl, opts.serviceRoleKey);
  const auth = await authorizeBillingRequest(request, orgId, opts, sb, 'Billing portal');
  if (!auth.ok) return auth.error;

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

/**
 * POST /v1/orgs/:id/checkout-session
 * Starts a Stripe Checkout session so an org with no billing account can subscribe.
 * Requires a user session (owner or billing_admin), like the billing portal.
 *
 * This exists as an org-scoped route rather than reusing `sender-worker`'s
 * `POST /create-checkout-session` because that endpoint takes only `{email, tier}` and
 * resolves the organization itself, via `supabaseFindOrgIdByEmail` — which prefers the
 * user's `default_organization_id` and otherwise takes their oldest active membership.
 * For anyone who belongs to more than one org that resolves to the wrong one: the
 * reporter of this bug owns three, and their default org already holds a paid
 * subscription, so upgrading a *different* org through that path would have attached
 * the new Stripe customer to the org that was already paying and left the intended one
 * still showing no billing account. Taking the org id from the authenticated,
 * membership-checked route parameter removes the guess.
 *
 * The org id must never come from the request body. It is what `stripe-webhook` writes
 * `stripe_customer_id` from on `checkout.session.completed`, so a caller who could name
 * an arbitrary org could repoint another tenant's billing at their own Stripe customer.
 */
export async function handleCreateCheckoutSession(
  request: Request,
  orgId: string,
  opts: CheckoutSessionHandlerOptions,
): Promise<Response> {
  const sb = createSupabaseClient(opts.supabaseUrl, opts.serviceRoleKey);
  const auth = await authorizeBillingRequest(request, orgId, opts, sb, 'Checkout');
  if (!auth.ok) return auth.error;

  const body = await safeParseJson(request);
  const payload =
    body.ok && typeof body.data === 'object' && body.data !== null
      ? (body.data as { plan?: unknown })
      : {};
  const plan = typeof payload.plan === 'string' ? payload.plan.trim() : '';
  if (!plan) return badRequest('Missing required field: plan');

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

  /**
   * An org that already has a Stripe customer must go through the billing portal.
   * Running Checkout again would mint a second customer and `linkStripeCustomer`
   * would overwrite `stripe_customer_id`, orphaning the original subscription —
   * it would keep billing while no longer being reachable from any org row.
   */
  if (orgResult.data[0].stripe_customer_id) {
    return conflict('Organization already has a billing account; use the billing portal');
  }

  const planResult = await sb.query<{ key: string; stripe_price_id: string | null }>('plans', {
    select: 'key, stripe_price_id',
    filters: [{ column: 'key', operator: 'eq', value: plan }],
    limit: 1,
  });

  if (!planResult.ok) return serverError('Failed to load plan');
  if (planResult.data.length === 0) return badRequest(`Unknown plan: ${plan}`);

  /**
   * Null `stripe_price_id` is the catalogue's marker for "not self-serve" — it is how
   * 'enterprise' is represented, since that tier has no Stripe product and is billed by
   * contract. Reading it from the table rather than hardcoding the tier name means a
   * plan becomes purchasable by being given a price, with no code change.
   */
  const priceId = planResult.data[0].stripe_price_id;
  if (!priceId) {
    return badRequest(`Plan ${plan} is not available for self-serve checkout`);
  }

  const base = opts.appBaseUrl.replace(/\/$/, '');
  let sessionUrl: string;
  try {
    const stripe =
      opts._stripeOverride ??
      new Stripe(opts.stripeSecretKey, {
        httpClient: Stripe.createFetchHttpClient(),
      });

    const session = await stripe.checkout.sessions.create({
      mode: 'subscription',
      line_items: [{ price: priceId, quantity: 1 }],
      success_url: `${base}/#/billing`,
      cancel_url: `${base}/#/billing`,
      client_reference_id: orgId,
      metadata: { org_id: orgId },
      // Sessions expire within 24h while the Subscription persists for the life of the
      // billing relationship, so this copy survives to re-derive linkage later.
      subscription_data: { metadata: { org_id: orgId } },
    });
    if (!session.url) return serverError('Stripe response missing session URL');
    sessionUrl = session.url;
  } catch (e) {
    console.error('[checkout-session] Stripe error:', e);
    return serverError('Failed to create checkout session');
  }

  const auditLog = writeAuditLog(sb, {
    organization_id: orgId,
    action: 'checkout_session.created',
    target_type: 'org',
    target_id: orgId,
    metadata: { actor_auth0_id: auth.sub, plan },
  });

  if (opts.waitUntil) {
    opts.waitUntil(auditLog);
  } else {
    await auditLog;
  }

  return ok({ url: sessionUrl });
}
