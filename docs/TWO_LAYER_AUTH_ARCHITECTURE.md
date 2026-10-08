# Two-Layer Auth Architecture

Integrity Studio's authentication has **two layers**, each answering a different question:

| Layer | Question | Mechanism | Purpose |
|-------|----------|-----------|---------|
| **Layer 1: Human Identity** | *Who is the person?* | Auth0 Universal Login (authorization code + PKCE) → Auth0 access token | Flutter app sign-in, dashboard access, session management |
| **Layer 2: Machine Access** | *What client/app is calling?* | Org-scoped API keys | API requests, integrations, quota enforcement, billing |

Human authentication is decoupled from machine authorization, so keys and sessions have independent revocation, rotation and quota policies. The flow detail for Layer 1 is in [authentication.md](authentication.md); the cross-repo view of every token and verifier is observability-toolkit `docs/auth-architecture.md`.

---

## Layer 1: Human Identity — Auth0 Universal Login

The browser is redirected to Auth0's hosted page, signs in there, and returns to `/callback` with an authorization code that the app exchanges for tokens using PKCE. integritystudio.ai and integritystudio.dev use the same SPA client (`integritystudio-dashboard`), so one Auth0 session serves both sites. No password reaches a Worker, and no Supabase Auth session is created.

```
User ── "Continue to Sign In" / sign-up form ──▶ https://<tenant>/authorize (code + PKCE S256)
  │
Auth0 Universal Login (password, sign-up, reset)
  │   post-login Action `provision-user-and-enrich-token`:
  │     finds or inserts the public.users row by auth0_id,
  │     adds namespaced roles / permissions / app_user_id claims
  ↓ 302 ──▶ <origin>/callback?code=…&state=…
Flutter App ── POST https://<tenant>/oauth/token (authorization_code + code_verifier)
  │     access token → sessionStorage      refresh token → localStorage (rotating)
  ↓
GET <api-gateway>/v1/orgs            (Authorization: Bearer <access token>)
  no orgs  → /provision   (first API key creates the org, via sender /send → receiver)
  any org  → /dashboard
  ↓
POST /bootstrap → { user: { id, email }, organizations: [{ id, slug, name, billing_status,
                    current_plan, quota_version, role }], active_org_id, entitlements,
                    usage_snapshot: { month_to_date_units } }
```

Code: `lib/services/auth0_service.dart` (`login`, `handleCallback`, `currentSession`, `logout`), `auth0/actions/provision-user-and-enrich-token.cjs`, `workers/api-gateway/src/routes/bootstrap.ts`.

The Action's two guards:
- **Fail closed (CR69).** If no app user id resolves (Supabase answers with an error or an unexpected shape), the Action denies the login rather than issuing a token without app claims. A network failure is not caught, so the Action throws, which also fails the login. Either way a Supabase outage blocks sign-in. A failed profile write alone does not: the Action falls back to a plain read.
- **Narrow email re-link (CR51, CR65).** When no row matches `auth0_id`, the Action falls back to matching by email only if the email is verified *and* the connection strategy is `auth0` (the database connection). Social and enterprise logins are never re-linked by email, because their `email_verified` is the IdP's assertion; the Action inserts a fresh row instead, and if a row already holds that email, `users_email_key` rejects the insert and the login is denied by the fail-closed guard above. The re-link is one-way: it claims only a row whose `auth0_id` is not yet an Auth0 subject (`<provider>|<id>`), with a compare-and-set PATCH on the value it read, so a second database identity sharing a verified email is refused the same way rather than flipping the row from the first.


### Tokens

**Access token** — the only credential the app sends to a Worker. Audience `https://api.integritystudio.dev`, RS256, issuer `https://<AUTH0_DOMAIN>/` — or `https://auth.integritystudio.ai/` for a token obtained through the custom domain, which every verifier also accepts since CR70 (same key set). It carries `sub` and nothing else the platform reads: no `email` (a custom-audience access token has none even with `email` in scope, so `/bootstrap` and `/v1/me` read it from the `users` row), no org ids, no plan. Auth0 knows nothing about Supabase orgs, and all mutable state — plan, billing status, usage — is resolved server-side per request.

**ID token** — carries `email`, the Action's namespaced claims, and — only for clients listed in the Action's `SUPABASE_TPA_CLIENT_IDS` secret — the bare `role = authenticated` claim that Supabase Third-Party Auth requires. The observability dashboard SPA uses it to read Supabase directly through PostgREST; nothing else consumes it, and Auth0 strips non-namespaced claims from access tokens so the Workers never see `role`.

### Supabase identity and RLS

- `public.users.auth0_id` holds the Auth0 subject and is the lookup key everywhere: api-gateway, the provisioning receiver, the api-keys edge functions, the dashboard worker, and the database's own `current_app_user_id()` resolver.
- Writes to `users`, `organizations`, `organization_memberships` and `api_keys` come only from service-role callers (the Action, sender, api-gateway, the receiver, the edge functions). No write policy in `public` is usable by a non-service caller.
- Reads for a Supabase Third-Party Auth session go through `current_app_user_id()` and `current_user_org_ids()`: an `auth0|…` subject resolves via `users.auth0_id`, a uuid-shaped subject via `auth_user_links`. Neither casts the subject to uuid, so no policy calls `auth.uid()`.

```sql
create policy organization_memberships_read_own on public.organization_memberships
  for select to authenticated
  using (user_id = public.current_app_user_id());
```

- `auth_user_links` and `custom_access_token_hook` remain as infrastructure for a Supabase Auth session; no current flow creates one.

---

## Layer 2: Machine Access — Org-Scoped API Keys

Identifies the calling system and ties requests to an organization and its plan: per-org rate limiting and quota via Durable Objects, usage metering for billing, and revocation that never touches a user session.

### Key formats

Two formats verify (`parseApiKey` in `workers/lib/api-keys.ts`):

| Format | Minted by | Accepted by | Hash |
|---|---|---|---|
| **`obtk_<64 lowercase hex>`** | Supabase `api-keys-create` (via the provisioning receiver) and `api-keys-rotate` | obtool-ingest, obtool-api, api-gateway | `sha256(<whole token>)`; `prefix` = first 8 hex, for display. Looked up **by** the digest |
| **`int_live_<prefix>_<secret>`** (legacy) | api-gateway `POST /v1/orgs/:id/api-keys` | api-gateway only | `HMAC-SHA256(API_KEY_HMAC_SECRET, secret)`; looked up by prefix, then constant-time compared |

The `obtk_` edge functions also write the key's record to the obtool `AUTH` KV namespace (`apikey:<sha256>` → `{ tier, status, userId, keyId, prefix, organizationId }`), which is what the telemetry Workers authenticate against. api-gateway cannot write that namespace, so an `int_live_` key never authenticates to obtool-ingest or obtool-api. Neither prefix encodes `org_id`; org scoping comes from the `api_keys` row.

### Storage

```sql
CREATE TABLE public.api_keys (
  id uuid PRIMARY KEY,
  organization_id uuid NOT NULL REFERENCES organizations(id) ON DELETE RESTRICT,
  user_id uuid NOT NULL REFERENCES public.users(id) ON DELETE RESTRICT,
  prefix text NOT NULL,
  hash text NOT NULL UNIQUE,
  name text NOT NULL,
  tier api_key_tier NOT NULL,            -- 'starter' | 'growth' | 'enterprise'; derived from the org's current_plan
  status api_key_status NOT NULL,        -- 'active' | 'inactive' (reversible) | 'revoked' | 'expired'
  expires_at timestamptz,
  created_at timestamptz NOT NULL,
  revoked_at timestamptz,
  last_used_at timestamptz               -- write-behind from obtool-ingest/obtool-api on each cache-miss auth
);
```

Invariants:
- The full key is never stored; only its hash. Rotation is explicit: `api-keys-rotate` creates and syncs the replacement before revoking the old key.
- Only `status = 'active'` authenticates, everywhere. api-gateway refuses any other row; the obtool Workers refuse any KV record whose `status` is not `active` or that lacks `organizationId`. `api-keys-set-status` switches a key between `active` and `inactive` in both the table and KV, and can reconcile every KV record from the table. `api-keys-revoke` sets `revoked` and deletes the KV record. api-gateway's `POST /v1/orgs/:id/api-keys/:keyId/revoke` delegates to that function rather than updating the row itself (CR64), so a gateway revoke also clears KV; it answers 500 if the function or its KV delete fails.
- `ON DELETE RESTRICT` on both foreign keys: a user or org that holds keys cannot be deleted until each key is revoked.

### Verification (api-gateway)

```typescript
// verifyApiKey, workers/lib/api-keys.ts (simplified: lookups are pseudocode, and the
// revoked and non-active checks are separate branches with their own messages)
const parsed = parseApiKey(token);                       // obtk_ or int_live_, else 401
const record = parsed.format === 'obtool'
  ? lookupByHash(await hashApiKeyToken(token))            // unique digest: no candidate row, no timing channel
  : lookupByPrefix(parsed.prefix);
if (!record) return unauthorized('API key not found');
if (record.revoked_at !== null || record.status !== 'active') return unauthorized(...);
if (record.expires_at !== null && new Date(record.expires_at) < new Date()) return unauthorized('API key is expired');
if (parsed.format === 'legacy' && !(await verifyApiKeyHash(parsed.secret, record.hash, hmacSecret))) {
  return unauthorized('Invalid API key');               // constant-time HMAC compare
}
return { ok: true, apiKey: record, userId: record.user_id, organizationId: record.organization_id };
```

---

## Request journey through api-gateway

```
Request → api-gateway
  │
  ├─ [1] Authorization: Bearer <token> — a JWT, or an API key (obtk_ / int_live_)
  │
  ├─ [2] Verify
  │   JWT: verifyJwt (workers/lib/auth.ts) — Auth0 JWKS (AUTH0_DOMAIN, 10-min cache,
  │        one refetch per 30 s for an unknown kid, fail closed), alg allowlist RS256/ES256
  │        (no symmetric branch), exp, iss, nbf (30 s skew), aud = AUTH0_AUDIENCE
  │   API key: verifyApiKey — digest or prefix lookup, status, expiry
  │
  ├─ [3] Resolve the org
  │   JWT: the users row (by auth0_id) and its active memberships
  │   API key: api_keys.organization_id; a key for another org is refused before quota
  │
  ├─ [4] Edge throttle — KV + per-isolate counters, per org on /v1/orgs/:id/*, per JWT subject
  │        on /v1/me, /v1/orgs, /bootstrap; the ceiling that survives a quota-DO outage
  │        (limits: api-reference.md § Rate limits)
  │
  ├─ [5] Quota — Durable Object per org, strong consistency: reserve one unit;
  │        a used-up month answers 429
  │
  ├─ [6] Handle the route; write the metered unit to usage_events via waitUntil
  │
  └─ [7] Respond with the RateLimit headers (api-reference.md § Rate limits)
```

`SUPABASE_JWT_SECRET` is deliberately unbound on api-gateway: these are Auth0-issued tokens, and verifying them against Supabase is what produces `401 Invalid JWT signature`.

### Which layer

```
Human signing into the app?      → Layer 1: Universal Login → access token → /bootstrap for org context
API call or webhook?             → Layer 2: API key → org from the key row → org rate limit + quota
Neither?                         → 401
```

---

## Design decisions

- **Two layers, not one.** "Am I an authenticated user?" and "what may this caller do in this org?" have different lifecycles. A revoked integration key does not end a session; an audit row says "Bob revoked the webhook key", not "Bob logged out".
- **Hash only.** A leaked database exposes no live key. `obtk_` has no separable secret, so its whole-token digest is the lookup key; `int_live_` hashes only its secret half under an HMAC key the Worker holds.
- **No mutable claims in tokens.** Plan, billing status and usage change from webhooks and per request; a token that carried them would be stale until refresh. Tokens carry identity; `/bootstrap`, `/v1/me` and `/v1/orgs/:id/*` carry state.
- **Durable Objects for quota.** Quota needs strong consistency (no double-spend). A DO per org serialises mutations and survives eviction; row locks in Postgres would block reads across the network, and Redis would be eventually consistent.

---

## Tests

- `workers/lib/auth.test.ts` — `verifyJwt`: signature against a JWKS stub, `alg` allowlist, `exp`/`iss`/`nbf`/`aud`, JWKS cache and refetch cooldown.
- `workers/lib/api-keys.test.ts` — both formats, digest lookup, HMAC verification, status and expiry rejection.
- `auth0/actions/provision-user-and-enrich-token.test.ts` — the Action (`npm run test:auth0-actions`; CI runs it on any change under `auth0/`).
- `supabase/tests/{auth0-read-policies,client-write-policies,retire-user-profiles,api-keys-restrict-delete,edge-functions}` — RLS and edge-function behaviour against a local Postgres.
- `workers/sender-worker` `npm run test:e2e` — `/send` signing, forwarding and error mapping under workerd with every outbound call mocked.
- observability-toolkit `services/e2e` — against the dev tenant and dev Workers: a test identity minted through the dev tenant's Management API, `provision_api_key` → `api-keys-create`, and the resulting key authenticating to `obtool-ingest-dev` and `obtool-api-dev`, org-scoped.

---

## Related documentation

- [Authentication](authentication.md) — the Universal Login flow, session lifetime, Worker token checks
- [Auth0 Actions](../auth0/actions/README.md) — the post-login Action and its secrets
- [API reference § Provisioning](api-reference.md#provisioning-sender-worker--api-provisioning-receiver) — sender → receiver → `api-keys-create`
- [Quota Durable Objects](../workers/docs/QUOTA_DURABLE_OBJECTS.md) — quota implementation detail
- [API reference § Usage ingestion](api-reference.md#usage-ingestion) — metering and rate-limit headers
- observability-toolkit `docs/auth-architecture.md` — every token, every verifier, the Supabase identity schema
