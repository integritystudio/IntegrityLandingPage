# Two-Layer Auth Architecture

## Overview

Integrity Studio's authentication system uses **two distinct layers**, each answering a different question:

| Layer | Question | Mechanism | Purpose |
|-------|----------|-----------|---------|
| **Layer 1: Human Identity** | *Who is the person?* | Supabase OAuth + JWT | Flutter app sign-in, dashboard access, session management |
| **Layer 2: Machine Access** | *What client/app is calling?* | Org-scoped API keys | API requests, integrations, quota enforcement, billing |

This split enables clean separation of concerns: human authentication is decoupled from machine authorization, allowing independent revocation, rotation, and quota policies.

---

## Layer 1: Human Identity — Supabase OAuth

### Purpose
Identifies the end-user (person) signing into the Flutter app or web dashboard. Establishes a session that grants access to the user's organizations, memberships, and entitlements.

### Flow

```
User
  ↓ [clicks "Sign in with Google/GitHub"]
Supabase OAuth
  ↓ [Google returns auth code]
Supabase Auth
  ↓ [issues JWT session token]
Flutter App
  ↓ [stores JWT in secure storage]
POST /bootstrap (with JWT)
  ↓
API returns: {
  user: { id, email, name, picture },
  orgs: [{ id, name, slug, role, plan, entitlements }],
  default_org: { ... },
  api_key_metadata: { ... }
}
  ↓
App is now authenticated & authorized
```

### JWT Claims Strategy

The Supabase Custom Access Token Hook enriches the JWT with compact, stable claims:

```typescript
interface EnrichedJWT {
  sub: string;                    // auth.users.id (Supabase Auth user)
  email: string;
  iss: string;                    // "https://supabase.com"
  aud: "authenticated";
  iat: number;                    // issued at
  exp: number;                    // expires in 3600s

  // Custom org claims (added by hook, stable identity references only)
  org_ids: string[];              // all orgs user belongs to
  default_org_id: string;         // primary org for this user
  default_org_role: string;       // "owner" | "admin" | "member" | "billing_admin" | "viewer"
  // NOTE: default_org_plan and default_org_billing_status are intentionally
  // absent. Both are mutable state queried server-side at runtime (M18-V01).
  // Embedding them caused up to 3600s stale reads, violating SOC 2 CC6.1.
}
```

**Key design rule:** JWT claims are **immutable references only**. Dynamic state (plan, billing status, remaining credits, current usage) is queried server-side via `/bootstrap` and `/snapshot`.

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

```
int_live_org_abcd1234_xxxxxxxxxxxxxxxxxx
│         │   └─ org_id (first 8 chars)
│         └─ key class (live = non-revoked)
└─ prefix (public, in plaintext in DB)

key_prefix: "int_live_org_abcd1234"
key_hash:   sha256(full_key)  ← only this is stored in DB
raw_key:    full_key          ← only shown once at creation
```

### API Key Storage

```sql
CREATE TABLE public.api_keys (
  id uuid PRIMARY KEY,
  organization_id uuid NOT NULL REFERENCES organizations(id),
  user_id uuid NOT NULL REFERENCES public.users(id),
  prefix text NOT NULL,
  hash text NOT NULL UNIQUE,             -- sha256(key_value)
  name text NOT NULL,
  tier user_defined NOT NULL,            -- "new" | "free" | "growth" | "enterprise"
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
curl -H "Authorization: Bearer int_live_org_abcd1234_xxxxxxxxx" \
     -H "X-API-Key-Id: <key-id>" \
     https://api.integritystudio.ai/usage

# Worker receives request
# 1. Extract prefix from Authorization header
# 2. Look up prefix in api_keys table → get hash + org_id
# 3. Verify hash matches request key
# 4. Extract org_id → call Durable Object for quota check
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
  │   JWT: check Supabase public key + expiry
  │   API key: lookup prefix → verify hash
  │
  ├─ [Step 3] Extract org_id:
  │   JWT: from default_org_id claim
  │   API key: from api_keys.organization_id
  │
  ├─ [Step 4] Rate limit (Cloudflare, edge-local):
  │   Use org_id as key
  │   Apply plan-based tier limit (free: 60 req/min, growth: 600, enterprise: 3000)
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
  → Use Layer 1 (JWT from Supabase OAuth)
  → JWT contains org context (default_org_id, plan, role)
  → Call /bootstrap to fetch full org/entitlement state
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

**Implementation:**
```typescript
// On key creation
const raw_key = "int_live_org_abcd1234_xxxxxxxxx";
const hash = sha256(raw_key);
await db.insert('api_keys', { prefix: 'int_live_org_abcd1234', hash, ... });
// Return raw_key once to user

// On key validation
const hash_from_request = sha256(request_key);
const record = await db.query('SELECT * FROM api_keys WHERE hash = ?', [hash_from_request]);
```

### 3. Why JWT Claims Don't Include Mutable Data?

**Motivation:** If plan/billing status changes server-side, JWT would be stale until refresh.

**Solution:** Store only stable references in JWT:
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
  // Fetch Supabase's public key (cached)
  const publicKey = await getSupabasePublicKey(env.SUPABASE_URL);

  // Verify signature
  const payload = await jwtVerify(token, publicKey);

  // Check expiry
  if (payload.exp * 1000 < Date.now()) {
    return null;  // expired
  }

  return payload;
}
```

**Implications:**
- JWTs expire after 3600 seconds
- Refresh tokens (if needed) are handled by Supabase client
- Worker does NOT cache JWT validity (fetches public key, verifies each request)

### API Key Validation

```typescript
async function verifyAPIKey(key: string, env: Env): Promise<null | APIKeyRecord> {
  // Extract prefix (first part before _)
  const prefix = key.substring(0, key.lastIndexOf('_'));

  // Hash the provided key
  const hash = sha256(key);

  // Look up in DB by prefix (indexed for speed)
  const record = await db.query(
    'SELECT * FROM api_keys WHERE prefix = ? AND hash = ? AND status = "active"',
    [prefix, hash]
  );

  if (!record) return null;

  // Update last_used_at (async, don't block request)
  db.update('api_keys', { id: record.id, last_used_at: now() });

  return record;
}
```

**Implications:**
- Prefix is stored in plaintext for lookup efficiency (prefix is not secret)
- Full key must match hash (prevents collision attacks)
- Status check filters out revoked keys
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
- ✅ Supabase OAuth + Custom Access Token Hook
- ✅ `auth_user_links` bridge table
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
// verifyJWT.test.ts
test('valid JWT with claims', async () => {
  const token = signJWT({ org_id: '...', exp: future }, secret);
  const payload = await verifyJWT(token, env);
  expect(payload.org_id).toBe('...');
});

test('expired JWT rejected', async () => {
  const token = signJWT({ org_id: '...', exp: past }, secret);
  const payload = await verifyJWT(token, env);
  expect(payload).toBeNull();
});

// verifyAPIKey.test.ts
test('valid API key lookup and hash verification', async () => {
  const key = 'int_live_org_abcd1234_secret123';
  await db.insert('api_keys', { prefix: 'int_live_org_abcd1234', hash: sha256(key) });
  const record = await verifyAPIKey(key, env);
  expect(record).toBeTruthy();
});

test('wrong API key rejected', async () => {
  const key = 'int_live_org_abcd1234_secret123';
  await db.insert('api_keys', { prefix: 'int_live_org_abcd1234', hash: sha256(key) });
  const record = await verifyAPIKey('int_live_org_abcd1234_wrong', env);
  expect(record).toBeNull();
});
```

### Integration Tests
```typescript
// auth.integration.test.ts
test('full user sign-in flow', async () => {
  // 1. OAuth callback
  const code = '...';
  const sessionResponse = await oauth.exchangeCode(code);
  const jwt = sessionResponse.session.access_token;

  // 2. POST /bootstrap with JWT
  const response = await fetch('https://api/.../bootstrap', {
    headers: { Authorization: `Bearer ${jwt}` },
  });

  // 3. Verify response has org context
  const data = await response.json();
  expect(data.orgs).toBeDefined();
  expect(data.orgs[0].id).toBeDefined();
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
| **JWT** | JSON Web Token; signed credential issued by Supabase, contains user + org claims |
| **API Key** | Long-lived credential for machine-to-machine calls; org-scoped, revocable |
| **auth_user_links** | Bridge table mapping Supabase Auth users to app users during Auth0 migration |
| **quota_version** | Monotonic counter incremented on plan changes; prevents stale webhook replays |
| **Soft limit** | Quota threshold that triggers warnings but doesn't block requests |
| **Hard limit** | Quota ceiling that blocks requests when exceeded |
| **Durable Object** | Cloudflare's strong-consistency storage primitive; one instance per org for serialized quota mutations |

