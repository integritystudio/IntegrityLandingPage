// Post-login runs on refresh-token exchanges too; those are not logins (UA02).
const REFRESH_TOKEN_PROTOCOL = 'oauth2-refresh-token';

// A silent sign-in — an /authorize that reuses the Auth0 session, e.g. opening
// integritystudio.dev after signing in to integritystudio.ai, which share one session since
// CR48 — also runs post-login, and Auth0 does not count it as a login (CR60). The event does
// not say whether the session was reused, but `event.authentication.methods` lists the
// methods completed during the *session*, each with the time it was used, so the latest
// timestamp is when Auth0 last authenticated the user: this transaction on a login, the
// original login on a session reuse. A method older than this is a session reuse, not a
// slow login: `mfa` is stamped when the challenge completes, and first-party clients show
// no consent screen after the password step.
const SILENT_SIGN_IN_MAX_AGE_MS = 60_000;

/** Latest `event.authentication.methods[].timestamp` as epoch ms, or null when absent. */
function lastAuthenticatedAtMs(event) {
  const methods = event.authentication?.methods;
  if (!Array.isArray(methods)) return null;
  let latest = null;
  for (const method of methods) {
    const used = Date.parse(method?.timestamp);
    if (!Number.isNaN(used) && (latest === null || used > latest)) latest = used;
  }
  return latest;
}

/**
 * Every Auth0 user_id is `<provider>|<id>` (`auth0|…`, `google-oauth2|…`). A users row whose
 * auth0_id has that shape belongs to an Auth0 identity, and the email re-link never takes it
 * from that identity (CR65); anything else is a pre-Auth0 placeholder the re-link may claim once.
 */
const AUTH0_SUBJECT_SEPARATOR = '|';

function isAuth0Subject(value) {
  return typeof value === 'string' && value.includes(AUTH0_SUBJECT_SEPARATOR);
}

/**
 * Supabase Third-Party Auth maps a token to the `authenticated` database role only when it
 * carries a bare `role` claim (CR62). Auth0 strips non-namespaced claims from access tokens,
 * so it goes on the ID token — and only for the clients named in the SUPABASE_TPA_CLIENT_IDS
 * secret (comma-separated client ids). Every other client's ID token stays a plain OIDC
 * token that Supabase rejects, so switching the integration on did not turn every login
 * into a database credential.
 */
const SUPABASE_ROLE_CLAIM = 'role';
const SUPABASE_AUTHENTICATED_ROLE = 'authenticated';
const CLIENT_ID_LIST_SEPARATOR = ',';

function supabaseClientIds(secrets) {
  return (secrets.SUPABASE_TPA_CLIENT_IDS ?? '')
    .split(CLIENT_ID_LIST_SEPARATOR)
    .map((id) => id.trim())
    .filter(Boolean);
}

/**
 * Profile columns written to public.users on every run (UA02). `login_count` is Auth0's own
 * count, so a repeated run cannot inflate it; `last_login` is skipped on a refresh-token
 * exchange, which is not a login, and on any other run it is the time Auth0 last
 * authenticated the user, so a silent sign-in rewrites the original login time rather than
 * its own start time (CR60). Only an event with no authentication methods falls back to now.
 */
function profileFields(event) {
  const { user, stats, transaction } = event;
  const fields = {
    name: user.name ?? null,
    nickname: user.nickname ?? null,
    picture: user.picture ?? null,
    email_verified: user.email_verified === true,
  };
  if (typeof stats?.logins_count === 'number') fields.login_count = stats.logins_count;
  if (transaction?.protocol === REFRESH_TOKEN_PROTOCOL) return fields;

  const authenticatedAt = lastAuthenticatedAtMs(event);
  if (authenticatedAt === null) {
    fields.last_login = new Date().toISOString();
    return fields;
  }
  fields.last_login = new Date(authenticatedAt).toISOString();
  if (Date.now() - authenticatedAt > SILENT_SIGN_IN_MAX_AGE_MS) {
    console.log(`silent sign-in for ${user.user_id}: session authenticated ${fields.last_login}, not counted as a login; last_login kept at that time (CR60)`);
  }
  return fields;
}

exports.onExecutePostLogin = async (event, api) => {
  const { SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY } = event.secrets;
  const headers = {
    'apikey': SUPABASE_SERVICE_ROLE_KEY,
    'Authorization': `Bearer ${SUPABASE_SERVICE_ROLE_KEY}`,
    'Content-Type': 'application/json',
    'Prefer': 'return=representation',
  };

  const auth0Id = event.user.user_id; // e.g. "auth0|abc123"
  const email = event.user.email;
  const profile = profileFields(event);
  const byAuth0Id = `${SUPABASE_URL}/rest/v1/users?auth0_id=eq.${encodeURIComponent(auth0Id)}&select=id,email`;

  // 1. Write the profile onto the row with this auth0_id; the returned row supplies the id,
  //    so lookup and update are one request. A failed write falls back to a plain read, so
  //    the claims below never depend on the profile columns.
  let userRes = await fetch(byAuth0Id, { method: 'PATCH', headers, body: JSON.stringify(profile) });
  if (!userRes.ok) {
    console.log(`profile write failed (${userRes.status}); reading the user instead`);
    userRes = await fetch(`${byAuth0Id}&limit=1`, { headers });
  }
  let users = await userRes.json();

  // 2. If not found by auth0_id, try by email — but only when BOTH of:
  //    (a) the email is verified (CR51) AND
  //    (b) the connection is the Auth0 database connection (CR65).
  //
  //    (a) An unverified address can be registered by anyone; re-linking without
  //    verification lets whoever registers the address inherit an existing row's
  //    memberships and roles. Skip the lookup when unverified. Step 3 then inserts a
  //    fresh row; if a row already holds this email, `users_email_key` rejects the
  //    insert, no app user id resolves, and the login is denied (CR69), so the new
  //    identity inherits nothing.
  //
  //    (b) Social and enterprise connections (Google, GitHub, SAML, …) assert
  //    email_verified on the IdP's word. If re-linking is permitted from those
  //    connections, any identity that controls the same email address on ANY IdP can
  //    claim an existing row's memberships and API keys — account takeover the
  //    moment a second connection is enabled. Restrict to strategy = 'auth0', the
  //    built-in database connection, where verification is through an email click
  //    that the same address must receive.
  //
  //    The re-link is one-way (CR65): it claims only a row whose auth0_id is not yet an
  //    Auth0 subject. A row that already belongs to another Auth0 identity is left alone,
  //    so a second identity with the same verified email cannot take it, and the two can
  //    no longer flip the row between them on alternate logins. That identity falls
  //    through to step 3, whose insert `users_email_key` rejects, and the login is denied.
  //    Linking two identities to one row is Auth0 account linking's job, not this one's.
  const isAllowedRelinkConnection = event.connection?.strategy === 'auth0';
  if (!Array.isArray(users) || !users[0]) {
    if (event.user.email_verified === true && isAllowedRelinkConnection) {
      userRes = await fetch(
        `${SUPABASE_URL}/rest/v1/users?email=eq.${encodeURIComponent(email)}&select=id,email,auth0_id&limit=1`,
        { headers }
      );
      const byEmail = await userRes.json();
      const existing = Array.isArray(byEmail) ? byEmail[0] : undefined;

      if (existing && isAuth0Subject(existing.auth0_id)) {
        console.log(`users row ${existing.id} already belongs to another Auth0 identity; refusing to re-link it to ${auth0Id} (CR65)`);
      } else if (existing) {
        // Claim the placeholder. Filtering on the auth0_id just read makes this a
        // compare-and-set: if another login claimed the row in between, nothing matches,
        // no row comes back, and this login falls through to step 3 like any refusal.
        const claimRes = await fetch(
          `${SUPABASE_URL}/rest/v1/users?id=eq.${existing.id}&auth0_id=eq.${encodeURIComponent(existing.auth0_id)}`,
          {
            method: 'PATCH',
            headers,
            body: JSON.stringify({ auth0_id: auth0Id, ...profile }),
          }
        );
        users = claimRes.ok ? await claimRes.json() : [];
      }
    } else if (event.user.email_verified !== true) {
      console.log(`email not verified for ${email}; skipping email-based re-link (CR51)`);
    } else {
      console.log(`connection strategy "${event.connection?.strategy}" not in re-link allowlist; skipping email-based re-link (CR65)`);
    }
  }

  // 3. Provision new public.users row if still not found
  if (!Array.isArray(users) || !users[0]) {
    const insertRes = await fetch(`${SUPABASE_URL}/rest/v1/users`, {
      method: 'POST',
      headers,
      body: JSON.stringify({ auth0_id: auth0Id, email, ...profile }),
    });
    const inserted = await insertRes.json();
    users = Array.isArray(inserted) ? inserted : [inserted];
  }

  const appUserId = users[0]?.id;
  if (!appUserId) {
    // Supabase is unreachable or returned an unexpected shape. Deny the login rather than
    // issuing a token with no app claims — a token without claims passes through the API
    // as if the user had no memberships, which silently grants or withholds access based
    // on whatever the previous cached token said (CR69).
    console.error('auth/provision-user: could not resolve app user id; denying login');
    api.access.deny('Unable to provision user account. Please try again.');
    return;
  }

  // 4. Load permissions from user_roles → roles
  const rolesRes = await fetch(
    `${SUPABASE_URL}/rest/v1/user_roles?user_id=eq.${appUserId}&select=roles(name,permissions)`,
    { headers }
  );
  const roleRows = await rolesRes.json();

  const permissions = new Set();
  const roleNames = [];
  if (Array.isArray(roleRows)) {
    for (const row of roleRows) {
      if (!row?.roles) continue;
      roleNames.push(row.roles.name);
      for (const perm of (row.roles.permissions ?? [])) {
        permissions.add(perm);
      }
    }
  }

  // 5. Enrich token with app-level claims
  api.idToken.setCustomClaim('https://integritystudio.dev/roles', roleNames);
  api.idToken.setCustomClaim('https://integritystudio.dev/permissions', [...permissions]);
  api.accessToken.setCustomClaim('https://integritystudio.dev/roles', roleNames);
  api.accessToken.setCustomClaim('https://integritystudio.dev/permissions', [...permissions]);
  api.accessToken.setCustomClaim('https://integritystudio.dev/app_user_id', appUserId);

  // 6. A Supabase-bound client gets the role claim on its ID token, after the row exists:
  //    the database resolves the subject through users.auth0_id (current_app_user_id()),
  //    so a token for an unresolved user would authenticate as nobody.
  if (supabaseClientIds(event.secrets).includes(event.client?.client_id)) {
    api.idToken.setCustomClaim(SUPABASE_ROLE_CLAIM, SUPABASE_AUTHENTICATED_ROLE);
  }
};
