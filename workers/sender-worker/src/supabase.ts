import {
  SUPABASE_PATHS,
  AUTH0_PATHS,
  SUPABASE_HEADER_NAMES,
  SUPABASE_PREFER,
  HEADER_NAMES,
  CONTENT_TYPES,
  PERSONAL_ORG_SLUG_PREFIX,
  PERSONAL_ORG_DEFAULTS,
} from "./types.js";

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
  const res = await fetch(`https://${domain}${AUTH0_PATHS.TOKEN}`, {
    method: "POST",
    headers: { [HEADER_NAMES.CONTENT_TYPE]: CONTENT_TYPES.JSON },
    body: JSON.stringify({
      grant_type: "client_credentials",
      client_id: clientId,
      client_secret: clientSecret,
      audience,
    }),
  });
  if (!res.ok) {
    const err = await res.text();
    throw new Error(`Auth0 token exchange failed: ${res.status} ${err}`);
  }
  const data = await res.json() as { access_token?: string };
  if (!data.access_token) throw new Error("Auth0 token exchange returned no access_token");
  return data.access_token;
}

/**
 * Create a user via the Auth0 Management API.
 * Performs the client credentials token exchange internally before the user create call.
 * Returns the Auth0 `sub` (user_id), which must be stored as `auth0_id` in Supabase.
 *
 * The connection "Username-Password-Authentication" is Auth0's default DB connection name.
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
      connection: "Username-Password-Authentication",
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

/**
 * Create a personal (single-user) default organization for a new user.
 *
 * Personal orgs are distinguished from team/company organizations by their slug prefix
 * (`personal-{userId}`), which allows them to be identified programmatically
 * (e.g. `SELECT * FROM organizations WHERE slug LIKE 'personal-%'`).
 *
 * Call this BEFORE inserting the user row into public.users so the org ID is available
 * for the `default_organization_id` FK. Then call `supabaseAddOrgOwner` AFTER the user
 * row exists (organization_memberships.user_id FKs to public.users).
 *
 * @returns organizationId — UUID of the newly created personal org
 */
export async function supabaseCreatePersonalOrg(
  url: string,
  serviceKey: string,
  userId: string,
  email: string,
): Promise<{ organizationId: string }> {
  // Slug encodes the userId so it is unique and queryable via LIKE 'personal-%'
  const slug = `${PERSONAL_ORG_SLUG_PREFIX}${userId}`;
  // Name uses the email local-part for human readability
  const localPart = email.split("@")[0] ?? email;
  const name = `${localPart} (personal)`;

  const orgRes = await fetch(`${url}${SUPABASE_PATHS.TABLE_ORGANIZATIONS}`, {
    method: "POST",
    headers: {
      [HEADER_NAMES.CONTENT_TYPE]: CONTENT_TYPES.JSON,
      [SUPABASE_HEADER_NAMES.API_KEY]: serviceKey,
      [HEADER_NAMES.AUTHORIZATION]: `Bearer ${serviceKey}`,
      [SUPABASE_HEADER_NAMES.PREFER]: "return=representation",
    },
    body: JSON.stringify({ slug, name, ...PERSONAL_ORG_DEFAULTS }),
  });
  if (!orgRes.ok) {
    const err = await orgRes.text();
    throw new Error(`Create personal org failed: ${orgRes.status} ${err}`);
  }
  const [org] = await orgRes.json() as Array<{ id?: string }>;
  const organizationId = org?.id;
  if (!organizationId) throw new Error("Create personal org returned no id");
  return { organizationId };
}

/**
 * Add the user as owner of their personal org.
 * Must be called AFTER the user row exists in public.users (FK requirement).
 */
export async function supabaseAddOrgOwner(
  url: string,
  serviceKey: string,
  organizationId: string,
  userId: string,
): Promise<void> {
  const memberRes = await fetch(`${url}${SUPABASE_PATHS.TABLE_ORG_MEMBERSHIPS}`, {
    method: "POST",
    headers: {
      [HEADER_NAMES.CONTENT_TYPE]: CONTENT_TYPES.JSON,
      [SUPABASE_HEADER_NAMES.API_KEY]: serviceKey,
      [HEADER_NAMES.AUTHORIZATION]: `Bearer ${serviceKey}`,
      [SUPABASE_HEADER_NAMES.PREFER]: SUPABASE_PREFER.RETURN_MINIMAL,
    },
    body: JSON.stringify({ organization_id: organizationId, user_id: userId, role: "owner" }),
  });
  if (!memberRes.ok) {
    const err = await memberRes.text();
    throw new Error(`Add org owner failed: ${memberRes.status} ${err}`);
  }
}

/**
 * Insert a row into public.users.
 *
 * @param userId - UUID for the Supabase users.id column (caller-generated)
 * @param auth0Sub - Auth0 user_id (e.g. "auth0|abc123"); stored in auth0_id column
 */
export async function supabaseInsertUser(
  url: string,
  serviceKey: string,
  userId: string,
  auth0Sub: string,
  email: string,
  organizationId: string,
): Promise<void> {
  const res = await fetch(`${url}${SUPABASE_PATHS.TABLE_USERS}`, {
    method: "POST",
    headers: {
      [HEADER_NAMES.CONTENT_TYPE]: CONTENT_TYPES.JSON,
      [SUPABASE_HEADER_NAMES.API_KEY]: serviceKey,
      [HEADER_NAMES.AUTHORIZATION]: `Bearer ${serviceKey}`,
      [SUPABASE_HEADER_NAMES.PREFER]: SUPABASE_PREFER.RETURN_MINIMAL,
    },
    body: JSON.stringify({
      id: userId,
      email,
      auth0_id: auth0Sub,
      tier: "starter",
      default_organization_id: organizationId,
    }),
  });
  if (!res.ok) {
    const err = await res.text();
    throw new Error(`Insert user failed: ${res.status} ${err}`);
  }
}

