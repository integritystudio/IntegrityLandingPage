# Types and Schemas in `workers/lib`

## Overview

`workers/lib` keeps two kinds of type, on purpose:

- **Plain TypeScript types** for domain models — `types/index.ts`. Nothing parses these at runtime; they type rows read through the Supabase client and the shapes handlers assemble.
- **Zod schemas** only where something is actually parsed — a request body or parameter, a Durable Object payload, an ingest payload, a log-stream entry, or the Supabase client's own option/result contract.

The split dates from 2026-09-27 (TS09, `4df6d71`): seventeen domain and response schemas that no request parsed were deleted, together with `types.zod.ts` and `types/provisioning.ts`, because a schema nothing parses is documentation that drifts — and this file had drifted twice. **Do not re-add a schema for a shape that is only typed.** When a new payload needs validation, add the schema next to the code that parses it and list it here.

Everything is exported from `workers/lib/index.ts`; workers import it by relative path (no path alias is configured).

## File Organization

| File | Holds |
|---|---|
| `types/index.ts` | Plain TS enums and interfaces for domain models (below), plus type re-exports from the schema files |
| `types/schemas.ts` | `BillingStatusSchema`, `ApiKeyTierSchema`, and the quota Durable Object contract |
| `types/request-bodies.ts` | Request payload and parameter schemas |
| `types/usage.ts` | Usage-event and OTel ingest schemas, `UsageBucketSchema`, summary and flush shapes |
| `types/audit.ts` | Audit log, user activity and session, billing event log schemas |
| `types/auth0.ts` | Auth0 log-stream entry and ingest request/response schemas |
| `types/supabase.ts` | The Supabase client's query, insert, update and RPC option and result schemas |
| `types/handler-options.ts` | Route handler options (`BaseRouteOptions`, `MachineRouteOptions`), `Env`, `AuthResult` |
| `crypto.ts` | Shared HMAC-SHA256 primitives (sign, signHex, verify) |
| `index.ts` | Barrel for all of the above |

**Removed 2026-09-27 (TS09):** `types.zod.ts` (never imported by any module), `types/provisioning.ts`, and from `types/schemas.ts` the `Organization`, `OrgMembership`, `Entitlement`, `BootstrapResponse`, `StripeEvent`, `JwtPayload`, `UserRow`, `ApiKey`, `CreateApiKeyResponse`, `RevokeApiKeyResponse`, `MeResponse`, `ListOrgsResponse`, `OrgDashboardResponse`, `OrgBillingStatusResponse`, `UsageSummaryResponse` and `OrgEntitlementsResponse` schemas, plus the `OrgRole`, `OrgMembershipStatus` and `ApiKeyStatus` enum schemas. Their TypeScript types survive in `types/index.ts`.

## Domain Types (`types/index.ts`, plain TypeScript)

### String-union enums

- **`OrgRole`** — `'owner' | 'admin' | 'member' | 'billing_admin' | 'viewer'`
- **`BillingStatus`** — Stripe's eight subscription statuses verbatim plus `inactive` ("no subscription exists"): `'inactive' | 'incomplete' | 'incomplete_expired' | 'trialing' | 'active' | 'past_due' | 'canceled' | 'unpaid' | 'paused'`. Several of these grant access; use `isEntitled` from `billing.ts` rather than comparing to `'active'` — that comparison silently excluded trial users for four months (CR27). For the plan an org's limits follow, use `effectivePlan(current_plan, billing_status)` from the same file (CR37). Zod twin: `BillingStatusSchema`.
- **`OrgMembershipStatus`** — `'active' | 'invited' | 'suspended'`
- **`ApiKeyStatus`** — `'active' | 'revoked' | 'expired'`
- **`ApiKeyTier`** — `'starter' | 'growth' | 'enterprise'`. Also the organization plan key; there is no separate `PlanKey`. Zod twin: `ApiKeyTierSchema`.

### Interfaces

- **`JwtPayload`** — `sub`, `email`, `iat`, `exp`, plus an index signature for further claims. A shape reference only: `workers/lib/auth.ts` verifies Auth0-issued RS256/ES256 tokens against the tenant's JWKS and types the verified payload itself.
- **`UserRow`** — a Supabase `users` row: `id`, `auth0_id`, `email`, `name | null`, `tier`, `created_at`. Read by `/v1/me` and `/bootstrap`.
- **`Organization`** — `id`, `slug`, `name`, `billing_status: BillingStatus`, `current_plan: ApiKeyTier`, `quota_version`.
- **`OrgMembership`** — `organization_id`, `user_id`, `role: OrgRole`, `status: OrgMembershipStatus`.
- **`Entitlement`** — `organization_id`, `feature_key`, `enabled`, `hard_limit | null`, `soft_limit | null`.
- **`BootstrapResponse`** — `user`, `organizations` (each `Organization & { role }`), `active_org_id`, an `entitlements` map, and `usage_snapshot` with `month_to_date_units` and an optional `unavailable: true` that distinguishes "no usage yet" from "could not read usage".
- **`ApiKey`** — an `api_keys` row: `id`, `user_id`, `organization_id`, `prefix`, `hash`, `name`, `tier`, `status`, `expires_at`, `last_used_at`, `created_at`, `revoked_at`.
- **`StripeEvent`** — `id`, `type`, `created`, `data.object`, optional `data.previous_attributes`.
- **`UsageBucket`** — a `usage_buckets_daily` row: `organization_id`, `bucket_date`, `metric_key`, `total_quantity`, `request_count`, `avg_latency_ms | null`. The Zod twin `UsageBucketSchema` in `types/usage.ts` additionally requires `updated_at` and pins `bucket_date` to `YYYY-MM-DD`.

## Runtime Schemas (Zod)

The file named next to each schema is the source of truth; field lists are not reproduced here because they drifted the last two times they were.

### Enums — `types/schemas.ts`

`BillingStatusSchema` and `ApiKeyTierSchema` are the Zod forms of the two enums above, used wherever a plan or billing status arrives from outside (Stripe events, quota requests).

### Quota Durable Object contract — `types/schemas.ts`

`QuotaCheckRequestSchema` (`orgId`, `metricKey`, `units`, `requestId`, `planKey`, `quotaVersion`), `QuotaCheckResponseSchema` (`allowed`, `reason`, `remainingMinute`, `remainingMonthly`), `QuotaStatusResponseSchema`, `QuotaFlushResultSchema`, `OrgPlanRowSchema` (`current_plan`, `quota_version`) and `OrgQuotaMiddlewareOptionsSchema`. `workers/api-gateway/src/lib/quota.ts` parses every DO response with these. `QuotaFlushResultSchema` belongs to `flushUsage()`, which has no non-test caller — BACKLOG.md CR45.

### Request bodies and parameters — `types/request-bodies.ts`

- `CreateApiKeyBodySchema` — `POST /v1/orgs/{id}/api-keys` body
- `OrgIdParamSchema`, `ApiKeyIdParamSchema` — route parameters
- `PaginationParamsSchema` — list query parameters
- `StripeEventBodySchema` — the envelope `stripe-webhook` parses before dispatching on `type`

### Usage and ingest — `types/usage.ts`

- `UsageEventSchema`, `UsageEventIngestionSchema`, `IngestEventRequestSchema`, `IngestEventResponseSchema` — `POST /v1/ingest/events` (no quota or rate limit on that route yet — BACKLOG.md CR42)
- `OtelSpanSchema`, `IngestOtelRequestSchema` (bounded to 1 000 spans), `IngestOtelMetadataSchema`, `IngestOtelResponseSchema` — `POST /v1/ingest/otel`
- `UsageBucketSchema`, `MonthlyUsageSummarySchema`, `UsageQueryResponseSchema` — `/v1/orgs/{id}/usage/summary`
- `UsageFlushResultSchema`

### Audit — `types/audit.ts`

`AuditActionSchema` (a pinned enum: an audit write whose action is outside it is refused), `AuditLogSchema`, `UserActivitySchema`, `UserSessionSchema`, `UserSessionsResponseSchema`, `DeviceTypeSchema`, `BillingEventTypeSchema`, `BillingEventLogSchema`.

### Auth0 log stream — `types/auth0.ts`

`Auth0LogSchema` (one log entry), `Auth0LogStreamEventSchema` (the `{log_id, data}` wrapper a log stream delivers), `IngestAuth0LogRequestSchema` (a batch of those) and `IngestAuth0LogResponseSchema` for `POST /v1/auth0-logs` (bearer-token gated by `AUTH0_LOG_STREAM_TOKEN` — BACKLOG.md CR40), and the `Auth0LogRow` type.

### Supabase client contract — `types/supabase.ts`

`FilterOperatorSchema`, `QueryFilterSchema`, `QueryOptionsSchema`, `InsertOptionsSchema`, `UpdateOptionsSchema`, `RpcOptionsSchema`, `SupabaseQueryResultSchema`, `SupabaseRpcResultSchema`, `SupabaseRowSchema`. These describe what `workers/lib/supabase.ts` accepts and returns; note that `update` and `deleteRows` accept an empty filter list — BACKLOG.md CR44.

## API Responses

No Zod schema validates a response: handlers assemble the JSON directly, typed by `types/index.ts` (`BootstrapResponse`) or inline. The unused response schemas listed under *Removed* above were deleted in TS09. Route facts that outlive them:

| Route | Auth | Access |
|---|---|---|
| `GET /v1/me` | JWT | authenticated user |
| `GET /v1/orgs` | JWT | authenticated user |
| `GET /v1/orgs/{id}/dashboard` | JWT | org member |
| `GET /v1/orgs/{id}/billing-status` | JWT | `owner` or `billing_admin` |
| `GET /v1/orgs/{id}/usage/summary` | JWT or API key | org member, or the key's own org |
| `GET /v1/orgs/{id}/entitlements` | JWT or API key | org member |

Since UA08 (2026-09-27), membership for every `/v1/orgs/{id}/*` route is enforced in `preVerifyToken` **before** quota is reserved, and re-checked by the handler.

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
  type Organization,
  type Env,
  type AuthResult,
  // Schemas
  ApiKeyTierSchema,
  BillingStatusSchema,
  CreateApiKeyBodySchema,
  QuotaCheckResponseSchema,
  EnvSchema,
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

- **workers/lib/types/*.ts** — the schema files catalogued above; read the file, not this page, for field-level detail
- **workers/lib/auth.ts** — Auth0 JWT verification: RS256/ES256 against the tenant's JWKS, `iss`/`aud`/`exp`/`nbf` checks; no HMAC and no HS256 path
- **workers/lib/api-keys.ts** — API key generation and verification using `hmacSignHex`/`hmacVerify`
- **workers/lib/crypto.ts** — HMAC-SHA256 sign/verify primitives
- **workers/lib/supabase.ts** — Database client with type-safe queries
- **workers/lib/validation/** — Shared validation utilities and error handling
- **workers/api-gateway/** — Route handlers using these schemas
- **docs/research/payments-implementation.md** — Architecture documentation
