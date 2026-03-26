import {
  SUPABASE_PATHS,
  SUPABASE_HEADER_NAMES,
  SUPABASE_PREFER,
  HEADER_NAMES,
  CONTENT_TYPES,
  PERSONAL_ORG_SLUG_PREFIX,
  PERSONAL_ORG_DEFAULTS,
} from "./types.js";

/**
 * Create user via admin API — no email sent, no rate limit.
 * Sets email_confirm: true to bypass email confirmation entirely.
 */
export async function supabaseAdminCreateUser(
  url: string,
  serviceKey: string,
  email: string,
  password: string,
): Promise<{ userId: string }> {
  const res = await fetch(`${url}${SUPABASE_PATHS.ADMIN_USERS}`, {
    method: "POST",
    headers: {
      [HEADER_NAMES.CONTENT_TYPE]: CONTENT_TYPES.JSON,
      [SUPABASE_HEADER_NAMES.API_KEY]: serviceKey,
      [HEADER_NAMES.AUTHORIZATION]: `Bearer ${serviceKey}`,
    },
    body: JSON.stringify({ email, password, email_confirm: true }),
  });
  if (!res.ok) {
    const err = await res.text();
    throw new Error(`Admin createUser failed: ${res.status} ${err}`);
  }
  const data = await res.json() as { id?: string };
  const userId = data.id;
  if (!userId) throw new Error("Admin createUser returned no user id");
  return { userId };
}

/**
 * Create a personal (single-user) default organization for a new user.
 *
 * Personal orgs are distinguished from team/company organizations by their slug prefix
 * (`personal-{userId}`), which allows them to be identified programmatically
 * (e.g. `SELECT * FROM organizations WHERE slug LIKE 'personal-%'`).
 *
 * The owner membership is created immediately so the user has full access to their org.
 *
 * @returns organizationId — UUID of the newly created personal org
 */
export async function supabaseCreatePersonalOrg(
  url: string,
  serviceKey: string,
  userId: string,
  email: string,
): Promise<{ organizationId: string }> {
  const serviceHeaders = {
    [HEADER_NAMES.CONTENT_TYPE]: CONTENT_TYPES.JSON,
    [SUPABASE_HEADER_NAMES.API_KEY]: serviceKey,
    [HEADER_NAMES.AUTHORIZATION]: `Bearer ${serviceKey}`,
    [SUPABASE_HEADER_NAMES.PREFER]: "return=representation",
  };

  // Slug encodes the userId so it is unique and queryable
  const slug = `${PERSONAL_ORG_SLUG_PREFIX}${userId}`;
  // Name uses the email local-part for human readability
  const localPart = email.split("@")[0] ?? email;
  const name = `${localPart} (personal)`;

  const orgRes = await fetch(`${url}${SUPABASE_PATHS.TABLE_ORGANIZATIONS}`, {
    method: "POST",
    headers: serviceHeaders,
    body: JSON.stringify({
      slug,
      name,
      ...PERSONAL_ORG_DEFAULTS,
    }),
  });
  if (!orgRes.ok) {
    const err = await orgRes.text();
    throw new Error(`Create personal org failed: ${orgRes.status} ${err}`);
  }
  const [org] = await orgRes.json() as Array<{ id?: string }>;
  const organizationId = org?.id;
  if (!organizationId) throw new Error("Create personal org returned no id");

  const memberRes = await fetch(`${url}${SUPABASE_PATHS.TABLE_ORG_MEMBERSHIPS}`, {
    method: "POST",
    headers: { ...serviceHeaders, [SUPABASE_HEADER_NAMES.PREFER]: SUPABASE_PREFER.RETURN_MINIMAL },
    body: JSON.stringify({
      organization_id: organizationId,
      user_id: userId,
      role: "owner",
    }),
  });
  if (!memberRes.ok) {
    const err = await memberRes.text();
    throw new Error(`Create org membership failed: ${memberRes.status} ${err}`);
  }

  return { organizationId };
}

export async function supabaseInsertUser(
  url: string,
  serviceKey: string,
  userId: string,
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
      auth0_id: userId,
      tier: "new",
      default_organization_id: organizationId,
    }),
  });
  if (!res.ok) {
    const err = await res.text();
    throw new Error(`Insert user failed: ${res.status} ${err}`);
  }
}

export async function supabaseSignIn(
  url: string,
  anonKey: string,
  email: string,
  password: string,
): Promise<{ jwt: string; userId: string }> {
  const res = await fetch(`${url}${SUPABASE_PATHS.SIGNIN_PASSWORD}`, {
    method: "POST",
    headers: {
      [HEADER_NAMES.CONTENT_TYPE]: CONTENT_TYPES.JSON,
      [SUPABASE_HEADER_NAMES.API_KEY]: anonKey,
    },
    body: JSON.stringify({ email, password }),
  });
  if (!res.ok) {
    const err = await res.text();
    throw new Error(`SignIn failed: ${res.status} ${err}`);
  }
  const data = await res.json() as { access_token?: string; user?: { id?: string } };
  const jwt = data.access_token;
  const userId = data.user?.id;
  if (!jwt || !userId) throw new Error("SignIn returned no access token or user id");
  return { jwt, userId };
}
