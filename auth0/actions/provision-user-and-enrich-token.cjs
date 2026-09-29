// Post-login runs on refresh-token exchanges too; those are not logins (UA02).
const REFRESH_TOKEN_PROTOCOL = 'oauth2-refresh-token';

/**
 * Profile columns written to public.users on every run (UA02). `login_count` is Auth0's own
 * count, so a repeated run cannot inflate it; `last_login` is skipped on a refresh-token
 * exchange, which is not a login.
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
  if (transaction?.protocol !== REFRESH_TOKEN_PROTOCOL) fields.last_login = new Date().toISOString();
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

  // 2. If not found by auth0_id, try by email (handles migrated Supabase users)
  if (!Array.isArray(users) || !users[0]) {
    userRes = await fetch(
      `${SUPABASE_URL}/rest/v1/users?email=eq.${encodeURIComponent(email)}&select=id,email&limit=1`,
      { headers }
    );
    users = await userRes.json();

    if (Array.isArray(users) && users[0]) {
      // Backfill auth0_id (and the profile) for migrated user
      await fetch(
        `${SUPABASE_URL}/rest/v1/users?id=eq.${users[0].id}`,
        {
          method: 'PATCH',
          headers,
          body: JSON.stringify({ auth0_id: auth0Id, ...profile }),
        }
      );
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
  if (!appUserId) return; // fail open — don't block login

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
};
