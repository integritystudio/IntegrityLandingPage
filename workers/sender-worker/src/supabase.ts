import {
  AUTH0_PATHS,
  AUTH0_CONNECTION,
  HEADER_NAMES,
  CONTENT_TYPES,
  SUPABASE_PATHS,
  ORG_TYPES,
  MEMBERSHIP_ROLES,
} from "./types.js";

export const EMAIL_SEPARATOR = /@/;
export const DOT_TO_HYPHEN_REGEX = /\./g;
export const SLUG_SANITIZE_REGEX = /[^a-z0-9-]+/g;
export const SLUG_TRIM_REGEX = /^-|-$/g;

function supabaseHeaders(serviceRoleKey: string): Record<string, string> {
  return {
    [HEADER_NAMES.CONTENT_TYPE]: CONTENT_TYPES.JSON,
    Authorization: `Bearer ${serviceRoleKey}`,
    apikey: serviceRoleKey,
    Prefer: "return=representation",
  };
}

/**
 * Generate a unique slug from an email address.
 * Email addresses are unique in Auth0, ensuring slug uniqueness.
 */
export function dedupSlug(email: string, tier: string): string {
  const [username, domain] = email.toLowerCase().split(EMAIL_SEPARATOR);
  const baseSlug = username
    .replace(DOT_TO_HYPHEN_REGEX, "-")
    .replace(SLUG_SANITIZE_REGEX, "-")
    .replace(SLUG_TRIM_REGEX, "");

  const domainPart = domain
    .replace(DOT_TO_HYPHEN_REGEX, "-")
    .replace(SLUG_SANITIZE_REGEX, "")
    .replace(SLUG_TRIM_REGEX, "");

  return `${baseSlug}-${domainPart}`;
}

/**
 * Insert a personal org into the `organizations` table.
 * Returns the new org's UUID.
 */
export async function supabaseCreatePersonalOrg(
  supabaseUrl: string,
  serviceRoleKey: string,
  name: string,
  tier: string,
  email: string,
): Promise<string> {
  const slug = dedupSlug(email, tier);
  const res = await fetch(`${supabaseUrl}${SUPABASE_PATHS.ORGANIZATIONS}`, {
    method: "POST",
    headers: supabaseHeaders(serviceRoleKey),
    body: JSON.stringify({ name, slug, type: ORG_TYPES.PERSONAL, current_plan: tier }),
  });
  if (!res.ok) {
    const err = await res.text();
    throw new Error(`Supabase org creation failed: ${res.status} ${err}`);
  }
  const data = (await res.json()) as Array<{ id: string }>;
  const orgId = data[0]?.id;
  if (!orgId) throw new Error("Supabase org creation returned no id");
  return orgId;
}

/**
 * Insert a user row into the `users` table.
 * `id` is a client-generated UUID; `auth0_id` is the Auth0 sub.
 */
export async function supabaseInsertUser(
  supabaseUrl: string,
  serviceRoleKey: string,
  userId: string,
  auth0Sub: string,
  email: string,
): Promise<void> {
  const res = await fetch(`${supabaseUrl}${SUPABASE_PATHS.USERS}`, {
    method: "POST",
    headers: supabaseHeaders(serviceRoleKey),
    body: JSON.stringify({ id: userId, auth0_id: auth0Sub, email }),
  });
  if (!res.ok) {
    const err = await res.text();
    throw new Error(`Supabase user insert failed: ${res.status} ${err}`);
  }
}

/**
 * Insert an owner membership row into `organization_memberships`.
 */
export async function supabaseAddOrgOwner(
  supabaseUrl: string,
  serviceRoleKey: string,
  orgId: string,
  userId: string,
): Promise<void> {
  const res = await fetch(`${supabaseUrl}${SUPABASE_PATHS.ORG_MEMBERSHIPS}`, {
    method: "POST",
    headers: supabaseHeaders(serviceRoleKey),
    body: JSON.stringify({ organization_id: orgId, user_id: userId, role: MEMBERSHIP_ROLES.OWNER }),
  });
  if (!res.ok) {
    const err = await res.text();
    throw new Error(`Supabase org membership insert failed: ${res.status} ${err}`);
  }
}

async function auth0FetchToken(domain: string, body: Record<string, string>, errorLabel: string): Promise<string> {
  const res = await fetch(`https://${domain}${AUTH0_PATHS.TOKEN}`, {
    method: "POST",
    headers: { [HEADER_NAMES.CONTENT_TYPE]: CONTENT_TYPES.JSON },
    body: JSON.stringify(body),
  });
  if (!res.ok) {
    const err = await res.text();
    throw new Error(`${errorLabel}: ${res.status} ${err}`);
  }
  const data = await res.json() as { access_token?: string };
  if (!data.access_token) throw new Error(`${errorLabel} returned no access_token`);
  return data.access_token;
}

/**
 * Obtain a short-lived Management API token via the client credentials grant.
 * Called once per signup; the token is not cached (Workers are ephemeral).
 */
async function auth0GetMgmtToken(
  domain: string,
  clientId: string,
  clientSecret: string,
  audience: string,
): Promise<string> {
  return auth0FetchToken(domain, {
    grant_type: "client_credentials",
    client_id: clientId,
    client_secret: clientSecret,
    audience,
  }, "Auth0 token exchange failed");
}

/**
 * Obtain a user-scoped access token via the Resource Owner Password Credentials grant.
 * Called immediately after user creation so the signup response can include a JWT.
 *
 * Note: ROPC must be enabled on both the Auth0 application (password grant) and the
 * Auth0 tenant (Advanced Settings → Grant Types). New users with unverified emails
 * will fail if the Auth0 API requires verified emails.
 */
export async function auth0UserSignIn(
  domain: string,
  clientId: string,
  clientSecret: string,
  audience: string,
  email: string,
  password: string,
): Promise<string> {
  return auth0FetchToken(domain, {
    grant_type: "password",
    username: email,
    password,
    client_id: clientId,
    client_secret: clientSecret,
    audience,
    scope: "openid profile email",
  }, "Auth0 user signin failed");
}

/**
 * Create a user via the Auth0 Management API.
 * Performs the client credentials token exchange internally before the user create call.
 * Returns the Auth0 `sub` (user_id), which must be stored as `auth0_id` in Supabase.
 */
export async function auth0CreateUser(
  domain: string,
  clientId: string,
  clientSecret: string,
  audience: string,
  email: string,
  password: string,
): Promise<{ auth0Sub: string }> {
  const mgmtToken = await auth0GetMgmtToken(domain, clientId, clientSecret, audience);
  const res = await fetch(`https://${domain}${AUTH0_PATHS.USERS}`, {
    method: "POST",
    headers: {
      [HEADER_NAMES.CONTENT_TYPE]: CONTENT_TYPES.JSON,
      [HEADER_NAMES.AUTHORIZATION]: `Bearer ${mgmtToken}`,
    },
    body: JSON.stringify({
      email,
      password,
      connection: AUTH0_CONNECTION,
      email_verified: false,
    }),
  });
  if (!res.ok) {
    const err = await res.text();
    throw new Error(`Auth0 createUser failed: ${res.status} ${err}`);
  }
  const data = await res.json() as { user_id?: string };
  const auth0Sub = data.user_id;
  if (!auth0Sub) throw new Error("Auth0 createUser returned no user_id");
  return { auth0Sub };
}


