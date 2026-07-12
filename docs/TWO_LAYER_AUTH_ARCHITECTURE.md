# Two-Layer Auth Architecture

## Overview

Integrity Studio's authentication system uses **two distinct layers**, each answering a different question:

| Layer | Question | Mechanism | Purpose |
|-------|----------|-----------|---------|
| **Layer 1: Human Identity** | *Who is the person?* | Auth0 ROPC + JWT (via sender-worker) | Flutter app sign-in, dashboard access, session management |
| **Layer 2: Machine Access** | *What client/app is calling?* | Org-scoped API keys | API requests, integrations, quota enforcement, billing |

This split enables clean separation of concerns: human authentication is decoupled from machine authorization, allowing independent revocation, rotation, and quota policies.

---

## Layer 1: Human Identity — Auth0 ROPC

### Purpose
Identifies the end-user (person) signing into the Flutter app or web dashboard. Establishes a session that grants access to the user's organizations, memberships, and entitlements.

### Flow

The shipped mechanism is **email + password sign-in via the sender worker** (`workers/sender-worker`, `api-provisioning-sender`), which mints an **Auth0-issued** JWT using the OAuth2 Resource Owner Password Credentials (ROPC) grant. There is no Supabase-OAuth/social-login step and no Custom Access Token Hook in this path — Auth0 signs the token directly.

```
User
  ↓ [submits email + password]
Flutter App
  ↓ [POST /signup or POST /signin to sender-worker]
sender-worker (api-provisioning-sender)
  │
  ├─ /signup:
  │   ├─ auth0CreateUser()   → Auth0 Management API (client_credentials, AUTH0_CLI_* creds)
  │   ├─ supabaseCreatePersonalOrg() + supabaseInsertUser() → org/user rows in Supabase
  │   └─ auth0UserSignIn()   → Auth0 /oauth/token, grant_type=password (AUTH0_CLIENT_* creds)
  │       returns { jwt, auth0Sub, userId, email }
  │
  └─ /signin:
      └─ auth0UserSignIn() → Auth0 /oauth/token, grant_type=password
          returns { jwt, email }
  ↓
Flutter App
  ↓ [stores JWT in secure storage]
POST /bootstrap (with JWT)
  ↓
API returns (BootstrapResponseSchema): {
  user: { id, email },
  organizations: [{ id, slug, name, billing_status, current_plan, quota_version, role }],
  active_org_id,
  entitlements: { [feature_key]: boolean | number | null },
  usage_snapshot: { month_to_date_units, current_minute_remaining }
}
  ↓
App is now authenticated & authorized
```

See `workers/sender-worker/src/index.ts` (`handleSignup`, `handleSignIn`) and `src/supabase.ts` (`auth0CreateUser`, `auth0UserSignIn`) for the exact implementation.

### JWT Claims Strategy

The JWT returned by `/signup` and `/signin` is **issued by Auth0**, not Supabase — Auth0 signs it directly during the ROPC token exchange, so no Postgres hook runs against it. Its shape is a standard Auth0 access/ID token (validated loosely server-side via `JwtPayloadSchema` in `workers/lib/types/schemas.ts`, which requires only `sub`, `email`, `iat`, `exp` and passes through any other claims):

```typescript
interface Auth0JWT {
  sub: string;                    // Auth0 user id ("auth0Sub" in the /signup response)
  email: string;
  iss: string;                    // "https://{AUTH0_DOMAIN}/"
  aud: string;                    // AUTH0_AUDIENCE
  scope: string;                  // "openid profile email"
  iat: number;                    // issued at
  exp: number;                    // Auth0 tenant token-expiry policy

  // NOT present: org_ids, default_org_id, default_org_role, plan, billing_status.
  // Auth0 has no knowledge of Supabase orgs, so none of that is embedded here.
}
```

Supabase does have a Postgres `custom_access_token_hook` function (see
`supabase/migrations/20260326000000_update_custom_access_token_hook.sql`) that would
enrich a **Supabase Auth** session JWT with `org_ids` / `default_org_id` / `default_org_role`
(deliberately excluding mutable `plan`/`billing_status` claims per M18-V01, to avoid
up-to-3600s stale reads). That hook exists as DB-level infrastructure but is not in the
code path exercised by the sender worker's `/signup` and `/signin` — those issue Auth0
JWTs directly and never establish a Supabase Auth session.

**Key design rule:** the JWT carries only stable Auth0 identity (`sub`, `email`). Org
context and all dynamic state (plan, billing status, remaining credits, current usage)
are resolved server-side, per request, via `/bootstrap` and `/snapshot`.

### Auth User Links Bridge

Users migrating from Auth0 → Supabase Auth are linked via `auth_user_links`:

```sql
-- Maps Supabase Auth user → legacy app user
CREATE TABLE public.auth_user_links (
  auth_user_id uuid PRIMARY KEY REFERENCES auth.users(id),
  app_user_id uuid NOT NULL UNIQUE REFERENCES public.users(id),
  created_at timestamptz DEFAULT now()
);
```

This bridge handles:
- **Auth0 → Supabase migration** without disrupting existing user records
- **Multiple auth methods** (user can sign in via Google, GitHub, SAML after initial Auth0 signup)
- **RLS join point** — all org/entitlement policies use this bridge to verify user membership

**Current status:** the `auth_user_links` table and the `custom_access_token_hook` function
(above) exist in Supabase (`supabase/migrations/20260320005000_create_auth_user_links.sql`,
`20260326000000_update_custom_access_token_hook.sql`). Neither is populated or invoked by the
sender worker's `/signup`/`/signin` handlers today (`workers/sender-worker/src/supabase.ts` only
inserts `organizations`, `users`, and `organization_memberships` rows) — they are DB-level
infrastructure for a Supabase Auth session that the current Auth0-ROPC flow does not create.

### RLS Policy Example

```sql
-- Users can only see their org memberships
CREATE POLICY "users_view_own_memberships"
  ON public.organization_memberships FOR SELECT
  USING (
    user_id IN (
      SELECT app_user_id FROM public.auth_user_links
      WHERE auth_user_id = auth.uid()
    )
  );
```

---

## Layer 2: Machine Access — Org-Scoped API Keys

### Purpose
Identifies the calling system (client app, integration, webhook handler) and ties requests to an organization and its billing plan. Enables:
- Per-org rate limiting via Durable Objects
- Usage metering for billing
- Independent key revocation (e.g., compromised integration key doesn't affect user sessions)
- Machine-to-machine calls without user involvement

### Key Types

| Type | Lifetime | Minted By | Used By | Revocable |
|------|----------|-----------|---------|-----------|
| **Interactive capability key** | Short-lived (JWT expiry) | `/bootstrap` endpoint | Flutter app → API calls | No (revoke via session logout) |
| **Long-lived integration key** | Days/months/years | `/api/keys/create` (user dashboard) | Webhooks, external APIs, agents | Yes (user revokes in dashboard) |

### Key Format

Actual format (`API_KEY_REGEX` in `workers/lib/api-keys.ts`): `^int_live_([A-Za-z0-9]{8,})_([A-Za-z0-9]{16,})$`. The prefix does **not** encode `org_id` — org scoping is looked up from the `api_keys` row matched by prefix, not parsed out of the key string.

```
int_live_XyZ12abc_9f3k2N7qP1rT8mZaLxYcQe2Vw
│         │         └─ secret (16+ alphanumeric, random) — the only part that's hashed
│         └─ prefix (8+ alphanumeric, random) — stored in plaintext, does NOT encode org_id
└─ "int_live_" — fixed key-class prefix (live = non-revoked)

key_prefix: "XyZ12abc"          ← plaintext, used for the DB lookup
key_hash:   HMAC-SHA256(hmacSecret, secret)  ← only the secret half is hashed; stored in DB
raw_key:    prefix + "_" + secret            ← only shown once at creation
```

### API Key Storage

```sql
CREATE TABLE public.api_keys (
  id uuid PRIMARY KEY,
  organization_id uuid NOT NULL REFERENCES organizations(id),
  user_id uuid NOT NULL REFERENCES public.users(id),
  prefix text NOT NULL,
  hash text NOT NULL UNIQUE,             -- HMAC-SHA256(hmacSecret, secret) — secret portion only
  name text NOT NULL,
  tier user_defined NOT NULL,            -- "starter" | "growth" | "enterprise"
  status user_defined NOT NULL,          -- "active" | "revoked" | "rotated"
  expires_at timestamptz,
  created_at timestamptz NOT NULL,
  revoked_at timestamptz,
  last_used_at timestamptz
);
```

**Security invariant:** The full key is **never stored**. Only the hash is persisted. This means:
- Key rotation is explicit (user must generate new key)
- Leaked DB doesn't expose live keys
- Key lookup: prefix → record → hash verification

### Usage in API Calls

```bash
# Example: POST /api/usage
curl -H "Authorization: Bearer int_live_XyZ12abc_9f3k2N7qP1rT8mZaLxYcQe2Vw" \
     -H "X-API-Key-Id: <key-id>" \
     https://api.integritystudio.ai/usage

# Worker receives request (see verifyApiKey in workers/lib/api-keys.ts)
# 1. Parse the token into { prefix, secret } via API_KEY_REGEX
# 2. Look up prefix in api_keys table → get hash + organization_id
# 3. HMAC-SHA256 the secret and constant-time-compare against the stored hash
# 4. Use the row's organization_id → call Durable Object for quota check
# 5. Proceed with request
```

---

## Integration Flow: Both Layers at the Edge

### Request Journey (Cloudflare Worker)

```
Request → Worker Gateway
  │
  ├─ [Step 1] Extract auth:
  │   JWT (from Authorization header) or API key (from X-API-Key)
  │
  ├─ [Step 2] Verify signature:
  │   JWT: check Auth0's JWKS (AUTH0_DOMAIN) + expiry
  │   API key: lookup prefix → verify HMAC hash of secret
  │
  ├─ [Step 3] Extract org_id:
  │   JWT: not on the token itself (Auth0 JWTs carry no org data) — resolved via /bootstrap
  │   API key: from api_keys.organization_id
  │
  ├─ [Step 4] Rate limit (Cloudflare, edge-local):
  │   Use org_id as key
  │   Apply plan-based tier limit (illustrative — starter: 60 req/min, growth: 600, enterprise: 3000)
  │
  ├─ [Step 5] Quota check (Durable Object, strong consistency):
  │   POST /check { metric_key, quantity }
  │   Reserve quota optimistically
  │   If denied: return 429 with remaining quota
  │
  ├─ [Step 6] Proxy upstream
  │   On success: POST /commit { success: true }
  │   On failure: POST /commit { success: false } (rollback)
  │
  └─ [Step 7] Return response
      Add headers:
      - X-RateLimit-Remaining
      - X-Quota-Version
      - X-Quota-Warning (if approaching soft limit)
```

### Decision Tree: Layer 1 vs Layer 2

```
Is this a human user signing into the app?
  ↓ YES
  → Use Layer 1 (JWT from Auth0 ROPC via sender-worker /signup or /signin)
  → JWT itself carries only sub/email — no org context
  → Call /bootstrap (with the JWT) to resolve org context and fetch full org/entitlement state
  → Display dashboard

  ↓ NO

Is this an API call or webhook?
  ↓ YES
  → Use Layer 2 (API key)
  → Extract org_id from key record
  → Enforce org-specific rate limit + quota
  → Execute request in org's context

  ↓ NO (no auth provided)
  → Return 401 Unauthorized
```

---

## Design Decisions & Rationale

### 1. Why Two Layers?

**Motivation:** A single auth layer conflates two independent concerns:
- "Am I an authenticated user?" (identity)
- "What am I allowed to do in this org?" (authorization)

**Solution:** Separate layers allow:
- **Independent lifecycle**: Revoke API key without affecting user session
- **Org-level quotas**: API key ties to org → org ties to plan → quota enforced per-org
- **Audit trail clarity**: "Bob@Acme revoked the webhook integration key" ≠ "Bob logged out"

### 2. Why Store Only the Key Hash?

**Motivation:** If DB is compromised, live keys should not leak.

**Implementation** (see `workers/lib/api-keys.ts`: `generateApiKey`, `hashApiKeySecret`, `verifyApiKey`):
```typescript
// On key creation
const { token, prefix, secret } = generateApiKey(); // token = `int_live_${prefix}_${secret}`
const hash = await hashApiKeySecret(secret, hmacSecret); // HMAC-SHA256(hmacSecret, secret)
await db.insert('api_keys', { prefix, hash, ... });
// Return token once to user; only the secret half is ever hashed/stored

// On key validation
const { prefix, secret } = parseApiKey(request_token);
const record = await db.query('SELECT * FROM api_keys WHERE prefix = ?', [prefix]);
const valid = await verifyApiKeyHash(secret, record.hash, hmacSecret); // constant-time HMAC compare
```

### 3. Why JWT Claims Don't Include Mutable Data?

**Motivation:** If plan/billing status changes server-side, an org-aware JWT would be stale until refresh. This is the rationale behind the Supabase `custom_access_token_hook` (see Layer 1 above) — it is not currently exercised, since the shipped flow issues Auth0 JWTs that carry no org data at all, but the same principle applies if/when that hook is wired in.

**Solution (for the hook, if/when used):** Store only stable references in the enriched JWT:
- ✅ `default_org_id` (unchanging reference)
- ✅ `org_ids` (list of org memberships, changes rarely)
- ❌ `remaining_quota` (changes on every request)
- ❌ `subscription_status` (changes from webhook)

**Query mutable data server-side:**
```typescript
// In /bootstrap endpoint
const org = await db.getOrg(org_id);
const subscription = await stripe.getSubscription(org.stripe_subscription_id);
const entitlements = await db.getEntitlements(org_id);
const usage_snapshot = await org_quota_do.snapshot();

return {
  org: { plan: subscription.plan, status: subscription.status, ... },
  usage: usage_snapshot,
  entitlements,
};
```

### 4. Why Use Durable Objects for Quota?

**Motivation:** Quotas must be enforced with strong consistency (no double-spend).

**Trade-offs:**

| Approach | Pros | Cons |
|----------|------|------|
| **Durable Object (chosen)** | Strong consistency, serialized mutations, survives eviction | One per org, potential latency under burst |
| **Supabase with row-level lock** | Simpler, same DB | Blocking reads, network latency, harder to scale |
| **Redis with Lua scripts** | Fast, flexible | Eventually consistent, data loss on eviction |

---

## Security Considerations

### JWT Validation

```typescript
async function verifyJWT(token: string, env: Env): Promise<null | JWTPayload> {
  // Fetch Auth0's JWKS for env.AUTH0_DOMAIN (cached)
  const jwks = await getAuth0Jwks(env.AUTH0_DOMAIN);

  // Verify signature
  const payload = await jwtVerify(token, jwks);

  // Check expiry
  if (payload.exp * 1000 < Date.now()) {
    return null;  // expired
  }

  return payload;
}
```

**Implications:**
- JWTs are Auth0-issued; expiry follows the Auth0 tenant/application token policy
- Re-authentication (no refresh-token flow) happens via `/signin` (Auth0 ROPC)
- Worker does NOT cache JWT validity (fetches JWKS, verifies each request)

*(Illustrative — no `verifyJWT`/`getAuth0Jwks` function currently exists in this repo's
worker code; this shows the intended validation shape for a JWT issued by Auth0.)*

### API Key Validation

```typescript
async function verifyAPIKey(token: string, env: Env): Promise<VerifyApiKeyResult> {
  // Parse into { prefix, secret } via API_KEY_REGEX (int_live_<prefix>_<secret>)
  const parsed = parseApiKey(token);
  if (!parsed.ok) return { ok: false, error: unauthorized('Invalid API key format') };

  // Look up in DB by prefix (indexed for speed)
  const record = await db.query(
    'SELECT * FROM api_keys WHERE prefix = ?',
    [parsed.prefix]
  );
  if (!record || record.status !== 'active' || record.revoked_at !== null) {
    return { ok: false, error: unauthorized('API key not found or revoked') };
  }

  // Verify the secret against the stored HMAC hash (constant-time compare)
  const valid = await verifyApiKeyHash(parsed.secret, record.hash, env.API_KEY_HMAC_SECRET);
  if (!valid) return { ok: false, error: unauthorized('Invalid API key') };

  return { ok: true, apiKey: record, userId: record.user_id, organizationId: record.organization_id };
}
```
(see `workers/lib/api-keys.ts` for the real implementation)

**Implications:**
- Prefix is stored in plaintext for lookup efficiency (prefix is not secret and does not encode org_id)
- Only the secret half of the key is HMAC-hashed and compared (constant-time)
- Status/`revoked_at` check filters out revoked keys
- Lookup is indexed by prefix (O(1) in DB)

### CORS & XSS Protection

```typescript
// In Cloudflare Worker
const response = new Response(body);

// Only send sensitive headers to our domain
if (request.headers.get('origin') === 'https://app.integritystudio.ai') {
  response.headers.set('X-Quota-Version', quotaVersion);
}

// Never expose raw API keys in response
// (they're only shown once at creation)
```

---

## Implementation Phases

### Phase 1: Core Setup (Current)
- ✅ Auth0 ROPC sign-up/sign-in via sender-worker (`/signup`, `/signin`)
- `auth_user_links` bridge table + Custom Access Token Hook exist in Supabase but are not yet wired into this flow
- ✅ `/bootstrap` endpoint
- ✅ Basic JWT validation in Worker
- API keys: create, list, revoke (user dashboard)

### Phase 2: Quota Enforcement
- Durable Object per org
- Two-phase check/commit (quota reservation)
- `/check` and `/commit` endpoints
- Soft + hard limit tracking
- Billing period reset

### Phase 3: Robustness & Observability
- JWT refresh token flow (if needed)
- API key rotation policy
- Real-time quota dashboard
- Audit logging (who revoked what key, when)
- Enterprise custom rate limits

---

## Testing Strategy

### Unit Tests
```typescript
// verifyJWT.test.ts (illustrative — see note in Security Considerations above)
test('valid Auth0 JWT accepted', async () => {
  const token = signJWT({ sub: 'auth0|...', email: 'user@example.com', exp: future }, secret);
  const payload = await verifyJWT(token, env);
  expect(payload.sub).toBe('auth0|...');
});

test('expired JWT rejected', async () => {
  const token = signJWT({ sub: 'auth0|...', email: 'user@example.com', exp: past }, secret);
  const payload = await verifyJWT(token, env);
  expect(payload).toBeNull();
});

// api-keys.test.ts (see workers/lib/api-keys.ts)
test('valid API key lookup and hash verification', async () => {
  const { token, prefix, secret } = generateApiKey();
  await db.insert('api_keys', { prefix, hash: await hashApiKeySecret(secret, hmacSecret) });
  const result = await verifyApiKey(token, hmacSecret, sb);
  expect(result.ok).toBe(true);
});

test('wrong API key secret rejected', async () => {
  const { prefix, secret } = generateApiKey();
  await db.insert('api_keys', { prefix, hash: await hashApiKeySecret(secret, hmacSecret) });
  const result = await verifyApiKey(`int_live_${prefix}_wrongsecretwrongsecret`, hmacSecret, sb);
  expect(result.ok).toBe(false);
});
```

### Integration Tests
```typescript
// auth.integration.test.ts
test('full user sign-in flow', async () => {
  // 1. POST /signin to sender-worker (Auth0 ROPC)
  const signinResponse = await fetch('https://sender/.../signin', {
    method: 'POST',
    body: JSON.stringify({ email, password }),
  });
  const { jwt } = await signinResponse.json();

  // 2. POST /bootstrap with JWT
  const response = await fetch('https://api/.../bootstrap', {
    headers: { Authorization: `Bearer ${jwt}` },
  });

  // 3. Verify response has org context (BootstrapResponseSchema)
  const data = await response.json();
  expect(data.organizations).toBeDefined();
  expect(data.organizations[0].id).toBeDefined();
});

test('API key request with quota enforcement', async () => {
  // 1. Create API key for org
  const key = await createAPIKey(org_id, 'Webhook integration');

  // 2. POST /api/usage with key
  const response = await fetch('https://api/.../usage', {
    headers: { Authorization: `Bearer ${key}` },
    body: JSON.stringify({ metric: 'monthly_units', quantity: 100 }),
  });

  // 3. Verify quota was deducted
  const snapshot = await getOrgQuotaSnapshot(org_id);
  expect(snapshot.monthly_units.remaining).toBe(9900);
});
```

---

## Related Documentation

- **[Payment Processor Research](./roadmap/payment-processor-research.md)** — Full architecture blueprint
- **[Durable Object Quota Enforcement](./DURABLE_OBJECT_QUOTA_ARCHITECTURE.md)** — Quota implementation details
- **[API Key Management](./api-key-management.md)** — User-facing key creation, rotation, revocation
- **[Supabase Auth Setup](./supabase-auth-setup.md)** — Custom Access Token Hook configuration

---

## Glossary

| Term | Definition |
|------|-----------|
| **JWT** | JSON Web Token; currently Auth0-issued (via the sender worker's ROPC grant), carries only `sub`/`email` — org context is resolved separately via `/bootstrap` |
| **API Key** | Long-lived credential for machine-to-machine calls; org-scoped, revocable |
| **auth_user_links** | Bridge table mapping Supabase Auth users to app users during Auth0 migration |
| **quota_version** | Monotonic counter incremented on plan changes; prevents stale webhook replays |
| **Soft limit** | Quota threshold that triggers warnings but doesn't block requests |
| **Hard limit** | Quota ceiling that blocks requests when exceeded |
| **Durable Object** | Cloudflare's strong-consistency storage primitive; one instance per org for serialized quota mutations |

