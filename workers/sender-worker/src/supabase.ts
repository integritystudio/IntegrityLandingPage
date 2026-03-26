import {
  SUPABASE_PATHS,
  SUPABASE_HEADER_NAMES,
  SUPABASE_PREFER,
  HEADER_NAMES,
  CONTENT_TYPES,
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

export async function supabaseInsertUser(
  url: string,
  serviceKey: string,
  userId: string,
  email: string,
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
      default_organization_id: "29edb193-ae7f-4863-9bb6-e245da74ec1f",
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
