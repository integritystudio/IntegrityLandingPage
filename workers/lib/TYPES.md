# Zod Types for API Gateway / Workers Implementation

## Overview
This document catalogs all Zod validation schemas created for the API Gateway and Workers implementation (Phase 4.1). Schemas are organized by domain and can be imported from `workers/lib/index.ts`.

## File Organization

### Core Type Files
- **`types/index.ts`** — TypeScript type definitions for all domains
- **`types/schemas.ts`** — Zod validation schemas for domain models
- **`types/handler-options.ts`** — Route handler configuration and request/response options
- **`types/request-bodies.ts`** — Request payload and query parameter schemas
- **`index.ts`** — Barrel export for all types and schemas

### Crypto Utilities
- **`crypto.ts`** — Shared HMAC-SHA256 primitives (sign, signHex, verify)

## Schemas by Domain

### Authentication & Users

#### JwtPayload
```typescript
JwtPayloadSchema = z.object({
  sub: z.string(),
  email: z.string().email(),
  iat: z.number(),
  exp: z.number(),
}).passthrough()
```
**Purpose:** Shape reference for the claims a verified Auth0 token carries.
**Usage:** Only `types/schemas.test.ts` parses with it. `workers/lib/auth.ts` verifies Auth0-issued RS256/ES256 tokens against the tenant's JWKS and types the payload with its own `JwtPayload` interface; it does not import this schema.

#### UserRow
```typescript
UserRowSchema = z.object({
  id: z.string().uuid(),
  auth0_id: z.string(),
  email: z.string().email(),
  name: z.string().nullable(),
  tier: z.string(),
  created_at: z.string().datetime(),
})
```
**Purpose:** Validates user records from Supabase `users` table.
**Usage:** `/v1/me` endpoint - returns authenticated user profile

### Organizations & Membership

#### Organization
```typescript
OrganizationSchema = z.object({
  id: z.string(),
  slug: z.string(),
  name: z.string(),
  billing_status: BillingStatusSchema,
  current_plan: ApiKeyTierSchema,
  quota_version: z.number(),
})
```
**Billing Status Enum:** Stripe's eight subscription statuses verbatim plus `inactive` ("no subscription exists"): `'inactive' | 'incomplete' | 'incomplete_expired' | 'trialing' | 'active' | 'past_due' | 'canceled' | 'unpaid' | 'paused'`
**Plan Key Enum:** `'starter' | 'growth' | 'enterprise'` (`ApiKeyTierSchema` — the same enum types API keys; there is no separate `PlanKeySchema`)
**Usage:** Org listing, dashboard, and status routes

#### OrgMembership
```typescript
OrgMembershipSchema = z.object({
  organization_id: z.string(),
  user_id: z.string(),
  role: OrgRoleSchema,
  status: OrgMembershipStatusSchema,
})
```
**Role Enum:** `'owner' | 'admin' | 'member' | 'billing_admin' | 'viewer'`
**Status Enum:** `'active' | 'invited' | 'suspended'`
**Usage:** Access control - verify user membership before granting org access

### Entitlements & Usage

#### Entitlement
```typescript
EntitlementSchema = z.object({
  organization_id: z.string(),
  feature_key: z.string(),
  enabled: z.boolean(),
  hard_limit: z.number().nullable(),
  soft_limit: z.number().nullable(),
})
```
**Usage:** `/v1/orgs/{id}/entitlements` - returns feature flags and limits for an org

#### UsageBucket
```typescript
UsageBucketSchema = z.object({
  organization_id: z.string().uuid(),
  bucket_date: z.string(),
  metric_key: z.string(),
  total_quantity: z.number(),
  request_count: z.number(),
  avg_latency_ms: z.number().nullable(),
})
```
**Purpose:** Aggregated daily usage metrics from `usage_buckets_daily` table.
**Usage:** `/v1/orgs/{id}/usage/summary` - returns MTD (month-to-date) usage

### API Keys

#### ApiKey
```typescript
ApiKeySchema = z.object({
  id: z.string().uuid(),
  user_id: z.string().uuid(),
  organization_id: z.string().uuid(),
  prefix: z.string(),
  hash: z.string(),
  name: z.string(),
  tier: ApiKeyTierSchema,
  status: ApiKeyStatusSchema,
  expires_at: z.string().datetime().nullable(),
  last_used_at: z.string().datetime().nullable(),
  created_at: z.string().datetime(),
  revoked_at: z.string().datetime().nullable(),
})
```
**Tier Enum:** `'starter' | 'growth' | 'enterprise'`
**Status Enum:** `'active' | 'revoked' | 'expired'`
**Usage:** API key database model validation

#### CreateApiKeyBody
```typescript
CreateApiKeyBodySchema = z.object({
  name: z.string().min(1).max(255).optional(),
  expires_at: z.string().datetime().optional(),
}).strict()
```
**Usage:** POST `/v1/orgs/{id}/api-keys` request validation

#### CreateApiKeyResponse
```typescript
CreateApiKeyResponseSchema = z.object({
  id: z.string().uuid(),
  name: z.string(),
  prefix: z.string(),
  tier: ApiKeyTierSchema,
  status: ApiKeyStatusSchema,
  expires_at: z.string().datetime().nullable(),
  created_at: z.string().datetime(),
  token: z.string(),
})
```
**Usage:** API key creation response (includes raw token, shown only once)

#### RevokeApiKeyResponse
```typescript
RevokeApiKeyResponseSchema = z.object({
  id: z.string().uuid(),
  status: z.literal('revoked'),
  revoked_at: z.string().datetime(),
})
```
**Usage:** POST `/v1/orgs/{id}/api-keys/{id}/revoke` response

## API Response Schemas

### /v1/me
**Schema:** `MeResponseSchema`
- Returns authenticated user profile (id, email, name, tier, created_at)
- Auth: JWT bearer token required

### /v1/orgs
**Schema:** `ListOrgsResponseSchema`
- Returns array of organizations with user's role in each
- Auth: JWT bearer token required

### /v1/orgs/{id}/dashboard
**Schema:** `OrgDashboardResponseSchema`
- Returns org details, user's role, and entitlements (feature flags + limits)
- Auth: JWT bearer token required
- Access: Must be org member

### /v1/orgs/{id}/billing-status
**Schema:** `OrgBillingStatusResponseSchema`
- Returns org billing status, plan, quota version
- Auth: JWT bearer token required
- Access: Must be org member with 'owner' or 'billing_admin' role

### /v1/orgs/{id}/usage/summary
**Schema:** `UsageSummaryResponseSchema`
- Returns org usage metrics aggregated by day for current month
- Auth: JWT token OR API key (dual auth)
- Access: Must be org member (JWT) or key owner's org (API key)

### /v1/orgs/{id}/entitlements
**Schema:** `OrgEntitlementsResponseSchema`
- Returns entitlements map: feature_key → (boolean | number | null)
- Auth: JWT token OR API key (dual auth)
- Access: Must be org member

## Handler Options Schemas

### BaseRouteOptions
```typescript
BaseRouteOptionsSchema = z.object({
  supabaseUrl: z.string().url(),
  serviceRoleKey: z.string(),
  jwtIssuerUrl: z.string().url().optional(), // expected `iss`; other issuers are rejected (V-02)
})
```
Database access for every route. A `jwtSecret` field lived here until 2026-07-31, when the HS256 verification path it fed was removed as unreachable (CR26). JWT verification takes its key set from `auth0JwtKey({ auth0Domain })` in `workers/lib/auth.ts`, not from these options.

### MachineRouteOptions
```typescript
MachineRouteOptionsSchema = BaseRouteOptionsSchema.extend({
  hmacSecret: z.string(),
})
```
Used by routes supporting both JWT and API key auth (requires HMAC for key verification).

### Env (Worker Environment)
```typescript
EnvSchema = z.object({
  SUPABASE_URL: z.string().url(),            // database access only; not a token issuer
  SUPABASE_SERVICE_ROLE_KEY: z.string(),
  API_KEY_HMAC_SECRET: z.string().optional(), // bound in production since 2026-08-06 (CR12)
  AUTH0_DOMAIN: z.string(),                   // JWKS URL and expected `iss` derive from it
  AUTH0_AUDIENCE: z.string().optional(),      // absent means `aud` is not validated
})
```
Mirrors api-gateway's `Env` by hand — nothing imports this schema, so a drift here is silent. `SUPABASE_JWT_SECRET` is deliberately absent: browser tokens are Auth0-issued and verified against Auth0 JWKS, and verifying them against Supabase is exactly what produced the original `401 Invalid JWT signature` (CR26). Do not re-add it.

### AuthResult
Union type for dual JWT/API key authentication resolution:
```typescript
type AuthResult =
  | { ok: true; type: 'jwt'; sub: string; userId: string }
  | { ok: true; type: 'api_key'; userId: string; organizationId: string }
  | { ok: false; error: Response }
```

## Import Examples

### From workers/lib/index.ts (barrel export)
```typescript
// Workers import the shared package by relative path (no path alias is configured).
import {
  // Types
  type JwtPayload,
  type UserRow,
  type UsageBucket,
  type Env,
  type AuthResult,
  // Schemas
  JwtPayloadSchema,
  UserRowSchema,
  UsageBucketSchema,
  EnvSchema,
  CreateApiKeyBodySchema,
  MeResponseSchema,
} from '../../lib';
```

### Validation in request handlers
```typescript
// Validate request body
const body = await request.json();
const validated = CreateApiKeyBodySchema.parse(body);

// Safe alternative with error handling
const result = CreateApiKeyBodySchema.safeParse(body);
if (!result.success) {
  return badRequest(result.error.flatten());
}
const { name, expires_at } = result.data;
```

## Type Safety Benefits

1. **Compile-time safety:** TypeScript catches mismatches before runtime
2. **Runtime validation:** Zod schemas validate untrusted data (request bodies, DB results)
3. **Documentation:** Schemas serve as source-of-truth for API contracts
4. **IDE autocomplete:** Full IntelliSense support in editors
5. **Error messages:** Clear validation errors for API clients

## Migration Path

To use these schemas in existing route handlers:

1. Import schema from `workers/lib/index.ts`
2. Replace inline type assertions with `.parse()` or `.safeParse()`
3. Update error handling to use `zodValidationError()` from `workers/lib/validation`
4. Add type annotations to function parameters using exported types

## Crypto Utilities

### `workers/lib/crypto.ts`

Shared HMAC-SHA256 primitives used by the workers that sign or verify inter-service messages, API keys, and Stripe webhooks. JWTs are not among them: `auth.ts` verifies asymmetric (RS256/ES256) signatures with WebCrypto against Auth0's JWKS and imports nothing from this module. Exported from `workers/lib/index.ts`.

```typescript
// Sign a message, returns raw bytes
hmacSign(secret: string, message: string): Promise<ArrayBuffer>

// Sign a message, returns lowercase hex string
hmacSignHex(secret: string, message: string): Promise<string>

// Verify a signature using constant-time comparison (crypto.subtle.verify)
hmacVerify(secret: string, signature: Uint8Array, message: string): Promise<boolean>
```

**Usage across workers:**

| Consumer | Function | Purpose |
|---|---|---|
| `lib/api-keys.ts` | `hmacSignHex` | Hash API key secret for storage |
| `lib/api-keys.ts` | `hmacVerify` | Verify API key secret against stored hash |
| `stripe-webhook/src/verify.ts` | `hmacVerify` | Verify Stripe webhook HMAC signature |
| `receiver-worker/src/index.ts` | `hmacVerify` | Verify HMAC-signed inter-worker requests (local stub) |
| `sender-worker/src/crypto.ts` | `hmacSignHex` | Sign requests to the receiver |
| `contact-form/src/index.ts` | `hmacSign` | Generate and validate CSRF tokens (base64url encoded) |

## Related Files

- **workers/lib/auth.ts** — Auth0 JWT verification: RS256/ES256 against the tenant's JWKS, `iss`/`aud`/`exp`/`nbf` checks; no HMAC and no HS256 path
- **workers/lib/api-keys.ts** — API key generation and verification using `hmacSignHex`/`hmacVerify`
- **workers/lib/crypto.ts** — HMAC-SHA256 sign/verify primitives
- **workers/lib/supabase.ts** — Database client with type-safe queries
- **workers/lib/validation/** — Shared validation utilities and error handling
- **workers/api-gateway/** — Route handlers using these schemas
- **docs/research/payments-implementation.md** — Architecture documentation
