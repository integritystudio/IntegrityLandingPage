import {
  HEADER_NAMES,
  CONTENT_TYPES,
  SUPABASE_PATHS,
} from "./types.js";

function supabaseHeaders(serviceRoleKey: string): Record<string, string> {
  return {
    [HEADER_NAMES.CONTENT_TYPE]: CONTENT_TYPES.JSON,
    Authorization: `Bearer ${serviceRoleKey}`,
    apikey: serviceRoleKey,
    Prefer: "return=representation",
  };
}

/**
 * Resolve the organization a checkout should be attributed to, from the buyer's email.
 *
 * Needed because `stripe-webhook`'s `checkout.session.completed` handler reads
 * `session.metadata.org_id || session.client_reference_id` to call
 * `linkStripeCustomer`; with neither set it warns and returns without linking, so
 * `organizations.stripe_customer_id` is never written and no subscription is
 * attached to an org.
 *
 * Resolution mirrors `custom_access_token_hook`: prefer the user's designated
 * `default_organization_id`, else fall back to their oldest active membership.
 * Returns null when the email has no user row or no membership — callers must
 * treat that as "proceed without metadata", never as a checkout failure.
 */
export async function supabaseFindOrgIdByEmail(
  supabaseUrl: string,
  serviceRoleKey: string,
  email: string,
): Promise<string | null> {
  const userRes = await fetch(
    `${supabaseUrl}${SUPABASE_PATHS.USERS}?select=id,default_organization_id&email=eq.${encodeURIComponent(email)}&limit=1`,
    { headers: supabaseHeaders(serviceRoleKey) },
  );
  if (!userRes.ok) {
    throw new Error(`Supabase user lookup failed: ${userRes.status}`);
  }
  const users = (await userRes.json()) as Array<{ id?: string; default_organization_id?: string | null }>;
  const user = users[0];
  if (!user?.id) return null;
  if (user.default_organization_id) return user.default_organization_id;

  const memberRes = await fetch(
    `${supabaseUrl}${SUPABASE_PATHS.ORG_MEMBERSHIPS}?select=organization_id&user_id=eq.${encodeURIComponent(user.id)}&status=eq.active&order=created_at.asc&limit=1`,
    { headers: supabaseHeaders(serviceRoleKey) },
  );
  if (!memberRes.ok) {
    throw new Error(`Supabase membership lookup failed: ${memberRes.status}`);
  }
  const memberships = (await memberRes.json()) as Array<{ organization_id?: string }>;
  return memberships[0]?.organization_id ?? null;
}
