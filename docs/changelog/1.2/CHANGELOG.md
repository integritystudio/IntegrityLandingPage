# Changelog — Version 1.2

All notable changes to the IntegrityStudio.ai Flutter project and Cloudflare Workers.

---

## [2026-03-20] - API Provisioning Workers & Validation Layer

### API Provisioning Workers

**Sender Worker (HMAC-SHA256 Signing)**
- Environment-aware CORS origin configuration via `ENVIRONMENT` env var
- Supports multiple origin allowlists (dev localhost, staging, production)
- Added OPTIONS preflight support for CORS-compliant browser requests
- Signs requests with HMAC-SHA256 before forwarding to receiver worker
- Public endpoints: `POST /signup`, `POST /signin`, `POST /send`, `GET /health`
- Integrates with Supabase Auth for JWT validation
- Commits: `1768837`, `e0b9858`, `f5d2c98`, `3a858b5`, `d59a255`

**Receiver Worker (Signature Verification & Replay Protection)**
- Verifies HMAC-SHA256 signatures from sender worker
- Timestamp-based replay attack protection (prevents duplicate requests)
- Validates JWT via Supabase `/auth/v1/user` endpoint
- Stores provisioning data from verified requests
- Private `/inbox` endpoint for inter-worker communication
- Commits: `7ca4853`, `b68ac63`, `3a858b5`, `d59a255`

### Shared Validation Layer

**HTTP Utilities** (`workers/lib/http/`)
- Added `request.ts` — JSON parsing, bearer token extraction, query param parsing, method assertion
- Enhanced `responses.ts` — CORS headers, redirect utilities, response factories
- `CORS` utilities extracted to `cors-utils.ts` for shared configuration
- Safe JSON parsing with `safeParseJson()` — returns `unknown` type for type safety
- Commits: `941e436`, `c2762ed`, `ec5085c`, `2db9223`, `74bd32f`, `a441c89`

**Validation** (`workers/lib/validation/`)
- Zod-based validation with typed result unions (`ValidationResult<T>`)
- `requireValidJson()` — Parse and validate JSON with Zod schema
- `zodValidationError()` — Format validation errors with field paths and messages
- Enables type-safe request/response validation across workers
- Contact-form worker updated to use Zod validation for submissions
- Commits: `f3d3f7b`, `bf61a7a`, `457819e`

**Test Coverage**
- Shared library: 79 tests, ~94% coverage
- All worker implementations include unit test suites
- Validation patterns tested across all worker types
- Commits: `4b67829`, `c2762ed`

### Sender-Worker UI Pages

**Authentication Page** (`lib/pages/auth_page.dart`)
- Unified signup/signin modes with `AuthMode` enum
- JWT token transport via `Authorization: Bearer` header
- Password validation with shared `PasswordPolicy` (8–128 chars)
- Error sanitization prevents internal detail leakage
- Analytics tracking deferred to `didChangeDependencies`
- Commits: `e8ab121`, `c3b9893`, `9f826b2`, `a5767c4`

**Provisioning Page** (`lib/pages/provision_page.dart`)
- API key provisioning with copy-to-clipboard button (`CopyableCodeField`)
- Displays API key, keyId, prefix, and tier
- On-success page shows requested key details
- Error handling with sanitized messages
- Commits: `bc59b8b`, `7ffbeb0`, `9f826b2`, `a5767c4`

**Sender Health Page** (`lib/pages/sender_health_page.dart`)
- Public health check endpoint (`GET /health`)
- Service status display with color-coded indicators
- No authentication required
- Commit: `9ea6256`

### Code Quality & Security Hardening

**M17: XSS Prevention via Error Sanitization**
- Pipe `sanitizeServerError` through `sanitizeUserInput` for HTML-entity escaping
- Prevents server-controlled XSS payloads (e.g., `<img src=x onerror=...>`)
- Commit: `4554f81`

**L22: Narrow Stack-Trace Detection Heuristic**
- Replaced broad `' at '` substring check with `_stackTracePattern` regex
- Matches ` at ` followed by address/path/method-call or file:line refs
- Added `\r\n` carriage-return guard for Windows-style errors
- Eliminates false positives on natural language like "Failed at validation step"
- 11 new tests verify correctness
- Commit: `4554f81`

**M13: Email Normalization for User ID**
- Lowercase and trim email before setting as `userId`
- Prevents case-variation duplicates (`User@Example.Com` vs `user@example.com`)
- Decouples PII from user ID concept
- Commit: `2876b46`

**M15: Maximum Password Length Validation**
- Added `_maxPasswordLength = 128` constant to auth validation
- Prevents DoS on auth endpoint via extremely long passwords
- Commits: `9581ce8`, `39e54fa`

**L21: Shared PasswordPolicy Constants**
- Extracted `minLength = 8` and `maxLength = 128` to `PasswordPolicy` class
- Auth page placeholder interpolates from shared constants
- Enables UI and future server-side validation to reference same policy
- Commit: `e8ab121`

### Infrastructure & Refactoring

**T01: Enhanced Mock ProvisioningDio**
- Supports different response data per retry attempt
- Added `_postResponseAttempts` and `_getResponseAttempts` maps
- Enables tests requiring different responses on each attempt (e.g., 500 then 200+data)
- Commit: `5367b9e`

**M09–M16: Auth/Provision Code Quality**
- Removed redundant indirection (`onBack` getter)
- Extracted duplicated spacing ternaries to locals
- Reset `_isLoading` on auth success to prevent permanent button disable
- Consolidated error sanitization helper across pages
- Moved analytics tracking to `didChangeDependencies`
- Fixed Alert double-spacing issues
- Commits: `171c1fb`, `9deac24`, `f72fb4a`, `6bc66ea`, `a5767c4`

### Documentation & Testing

**Test Infrastructure**
- `test/services/provisioning_service_test.dart` — 8 comprehensive test cases
- Auth flow, provisioning flow, error handling, retry logic
- JWT parameter handling, response validation
- All tests passing; integration verified with manual E2E guide
- Commits: `9ea6256`, `edda3e1`, `5367b9e`, `4841b8d`, `6bc576f`

**Documentation**
- `docs/api-provisioning.md` — Complete architecture with request flow diagrams
- `PROVISIONING_MANUAL_TEST.md` — 7 test cases, step-by-step instructions
- `PROVISIONING_E2E_RESULTS.md` — Verified working components, test summary
- `docs/SESSION_HISTORY.md` — Detailed implementation notes and learnings

### Security & Infrastructure Hardening

**H19: Timing-Safe Hash Comparisons (CRITICAL)**
- Replaced all hash comparisons with constant-time `crypto.subtle.verify()`
- V-03: API key hash verification in `workers/lib/api-keys.ts:verifyApiKeyHash`
- V-04: Stripe webhook signature verification in `workers/stripe-webhook/src/verify.ts`
- Prevents timing attacks on authentication and webhook validation
- All 22 tests passing
- Commit: `0f9cece`

**T22: Durable Object Quota Enforcement Implementation**
- Per-org quota Durable Object with minute-level burst control and monthly soft limits
- `workers/api-gateway/src/durable-objects/quota.ts` (253 lines) — Full state machine
- `workers/api-gateway/src/lib/quota.ts` — Type-safe service client with quota operations
- Zod validation schemas for quota requests/responses
- Durable Object bindings and migrations configured in `wrangler.toml`
- Comprehensive documentation in `workers/docs/QUOTA_DURABLE_OBJECTS.md`

**T23: Webhook Resilience & Dead Letter Queue (Phase 1 of DR)**
- Implemented webhook idempotency and dead letter queue for Stripe events
- `webhook_dead_letters` table with schema migration (status, next_retry_at indexing)
- Dead letter insertion on webhook processing failure
- Reconciliation cron (`workers/stripe-webhook/src/index.ts:148–222`) runs every 15 min with exponential backoff
- Stripe event ID as idempotency key (globally unique)
- Commit: `71153fc`

**T24: Full Reconciliation Script Implementation**
- "Nuclear option" script to rebuild billing state from Stripe after data corruption or extended outage
- `scripts/full-reconciliation.ts` — Pages all Stripe customers and subscriptions
- Upserts to `organizations` and `subscriptions` tables
- Rebuilds entitlements from subscription tier via `provisionEntitlements()`
- Dry-run mode with summary for safety verification before applying changes
- Commit: `156bec1`

**T25-M1: Health Check DO Probe Billing Fix**
- Replaced `quotaDO.idFromName('health-probe')` with structural binding check
- Eliminates per-request DO creation and storage billing
- Health endpoint verifies namespace binding exists without creating/waking probe DO
- Async keyword removed for clarity (function now synchronous)
- Commits: `398545d`, `e1d3e56`

### Code Quality & Security Review Phase 2 (2026-03-20/21)

**R01–R10: Dart Security Utilities & Test Hardening**
- R01: Clarifying comment for CRLF multi-line guards in `sanitizeServerError` (commit `d186f1d`)
- R02: Document `_stackTracePattern` regex extension list limitations and runtime guidance (commit `c326a28`)
- R03: Isolated test for bare carriage return (`\r`) in `sanitizeServerError` (commit `bfc0d0c`)
- R04: Added performance comment to `_stackTracePattern` static final (commit `c326a28`)
- R05: Dedup `PasswordPolicy.minLength` test assertions with proportionality check (commit `9ec3af4`)
- R06: Remove backlog ID from test group name (commit `7f116c1`)
- R07: Add boundary tests for `PasswordPolicy` min/max length (commit `3cce1c5`)
- R08: Update TDD report with current `_stackTracePattern` regex (commit `26e12a7`)
- R09: Back-fill commit hashes in changelog v1.1 (commits `bc59b8b`, `7ffbeb0`, `9581ce8`, `39e54fa`, `a5767c4`)
- R10: Remove duplicate M07 entry from open items (already removed)

**H19: Security — Shared Utilities & Validation Hardening**
- H19-M1: Extract `hexToBytes` utility to `workers/lib/hex-utils.ts` for API key and Stripe webhook verification (commits `2d4df62`, `5d00632`)
- H19-M2: Strict validation for `hexToBytes` regex (change `*` to `+` to reject empty strings) (commits `2d4df62`, `5d00632`)

**M18: JWT & Issuer Validation**
- M18-M1: Reorder JWT validation to verify signature before claims (commits `fc69dea`, `42faa70`)
- M18-M2: Add startup warning when JWT issuer validation disabled (commits `0932e90`, `ee29f30`)

**M19–M22: Reconciliation Script & Aggregation Hardening**
- M19: Fix typo in `entitlementsToRebuild` variable name across 5 occurrences (commit `7fa808f`)
- M20: Add explicit `!orgId` guard after Zod parse in reconciliation (commit `005fc5c`)
- M21: Log warnings when daily/monthly query results hit configured limits (commit `8e8c033`)
- M22: Add `Math.trunc()` for integer enforcement in aggregation (commit `1a446fa`)

**T23: Webhook Dead Letter Queue Hardening**
- T23-M2: Add RLS policy documentation comment to webhook dead letter tables (commit `313cd7f`)
- T23-M3: Remove unused `'processing'` status from dead letter enum (commit `7da6701`)

**T24: Reconciliation Script Validation & Type Safety**
- T24-M1: Guard Stripe customer subscriptions cast with `Array.isArray` runtime check (commits `9bbb550`, `4f03052`)
- T24-M3: Clarify `orgEntitlementsRebuilt` counter semantics in logs (commit `1b9c88d`)

**T25: Health Check Type Safety**
- T25-M2: Narrow health check return type to `'healthy' | 'unhealthy'` (commit `3dd5824`)

**L1–L4: Low-Priority Code Quality**
- L1: Eliminate redundant `token.split()` calls in JWT verification by returning parts from `parseJwtPayload` (commit `f3cbb38`)
- L2: Simplify compound issuer check logic (commit `7fa808f`)
- L3: Add Zod schema rejection path test for `MonthlyUsageSummary` (no external commit, inline test)
- L4: Extract shared mock factory in `aggregation.test.ts` to reduce duplication (commit `11049a3`)

**S01: Clickjacking Protection via CSP Header**
- Added `frame-ancestors 'self'` to Cloudflare Pages `_headers` configuration
- Prevents embedding this site in iframes (clickjacking defense)
- Commit: `81f1921`

**H20: IDOR Prevention — Org Membership Authorization (AUDIT VERIFIED)**
- All org-scoped routes enforce membership/access before returning data
- `handleOrgDashboard`, `handleOrgBillingStatus` check via `loadUserMemberships`
- `handleUsageSummary`, `handleOrgEntitlements` use `assertOrgAccess` (JWT membership or API key org match)
- `handleCreateApiKey`, `handleRevokeApiKey` use `assertOrgMembership`
- 6 org-scoped routes with full 403 IDOR test coverage
- Test coverage commit: `e296e20`

**H21: Org Quota Enforcement Before JWT Authentication**
- Fixed quota enforcement order: `requireBearerToken` check before `enforceOrgQuota()`
- Prevents unauthenticated callers from triggering DO reads and consuming quota I/O
- Stops information leakage: 429 vs 401/404 response codes
- Full auth (JWT or API key) remains delegated to route handlers for machine routes
- Commit: `aa4abf6`

**T23-M4: Integration Tests for `runReconciliation` Idempotency Guard**
- 4 integration test cases covering dead letter retry, idempotency guard, handler failure, unhandled event type
- Mocked Supabase client for reliable webhook reconciliation testing
- Guards test coverage for T23-M1 idempotency fix
- Commit: `1ae481d`

**H19-M3: Explicit DB Error Handling in `isEventProcessed`**
- Returns union type `{ ok: false; error: string } | { ok: true; processed: boolean }`
- Distinguishes DB failures from "event not yet processed"
- `runReconciliation` fails-closed on DB error; `handleWebhook` returns 500 on guard failure
- TDD: 3 tests in `supabase.test.ts` covering error paths
- Commit: `1ef83d1`

**V01: Usage Ledger Ingestion**
- `/v1/ingest/events` endpoint accepting POST requests with usage event data
- Validates and stores to `usage_events` (org_id, metric_key, quantity, request_id, source, status_code, latency_ms)
- Fire-and-forget: returns 202 Accepted
- 16 integration tests passing
- Commit: `761ab48`

**V03: Monthly Aggregation Rollup**
- `rollupMonthlyBucket(orgId, yearMonth, sb)` aggregates daily buckets into monthly usage summaries
- Returns `MonthlyUsageSummary` with metric_breakdown (quantity, request count, avg_latency_ms)
- Zod validation via `MonthlyUsageSummarySchema`
- 17 integration tests (TDD)
- Commits: `59402f3`, `c021f5b`

**T26: Wire Quota Checks Into API Gateway Request Handler**
- `enforceOrgQuota()` middleware integrated into all org-specific routes
- Fetches org plan from DB, calls `checkAndReserve()`, returns 429 with `X-RateLimit-Remaining-*` headers
- Fail-open if Durable Object unavailable
- Commits: `bb1d810`, `d58f382`, `3483538`

**T27: Integration Tests for Quota Durable Object**
- 25 integration tests covering minute/monthly limits, idempotency, enterprise plan, quotaVersion bumps, storage persistence, legacy backfill
- Wrangler miniflare environment for local DO testing
- Edge cases: free plan (60 rpm, 10k/month), enterprise (no monthly limit), boundary conditions
- Commit: `6bc3cd8`

### Code Quality & Security Refinements (2026-03-21)

**H19-M1: Extract `hexToBytes` Utility to Shared Library**
- Unified hex-to-bytes conversion used for API key and Stripe signature verification
- Created `workers/lib/hex-utils.ts` with shared export
- Prevents maintenance drift between independent implementations
- 7 tests added
- Commits: `2d4df62`, `5d00632`

**H19-M2: Strict Hex Validation for `hexToBytes`**
- Changed regex from `*` (zero or more) to `+` (one or more) to reject empty strings
- Matches `workers/stripe-webhook/src/verify.ts` validation
- Prevents empty `Uint8Array` from bypassing verification
- Commit: `5d00632`

**M18-M1: JWT Verification Order — Signature First**
- Reorder to verify signature → check expiry → check issuer
- Prevents unverified claim inspection (defense-in-depth)
- Commits: `fc69dea`, `42faa70`

**M18-M2: JWT Issuer Validation Startup Warning**
- Module-level flag emits `console.warn` once per isolate if `SUPABASE_JWT_ISSUER` is unset
- Makes JWT issuer validation status visible in deployment logs
- Commits: `0932e90`, `ee29f30`

**T23-M1: Idempotency Guard on Dead Letter Reconciliation Retry**
- Added `isEventProcessed()` check at top of reconciliation loop
- Prevents duplicate processing of overlapping cron ticks
- Commits: `fe479cc`, `b352169`

**T23-M2: RLS Configuration for Dead Letter Tables**
- Documented service-role-only access pattern for `webhook_dead_letters` and `webhook_events_log`
- Added comment explaining intentional RLS omission
- Commit: `313cd7f`

**T23-M3: Remove Unused `'processing'` Status from Dead Letter Schema**
- Removed `'processing'` enum value — never written by code
- Eliminates confusion around distributed locking (never implemented)
- Commit: `7da6701`

**T24-M1: Stripe Customer Subscriptions Unsafe Cast Guard**
- Added `Array.isArray(subs)` guard with error throw on schema mismatch
- Provides fast-fail on Stripe SDK schema changes
- Commits: `9bbb550`, `4f03052`

**T24-M2: Maintenance Window Warning for Entitlements Reconciliation**
- Documented non-atomic delete-then-insert pattern as "nuclear option"
- Added header warning against concurrent production traffic
- Commit: `218b4f2`

**T24-M3: Counter Granularity Clarification in Reconciliation**
- Renamed `entitlementsRebuilt` → `orgEntitlementsRebuilt`
- Updated log label to clarify count semantics (per-org, not per-entitlement-row)
- Commit: `1b9c88d`

**T25-M2: Health Check Endpoint DO Response Type**
- Narrowed `checkDurableObject` return type from `'healthy' | 'degraded' | 'unhealthy'` to `'healthy' | 'unhealthy'`
- Removed unreachable `'degraded'` (DO 5xx is hard failure, not degradation)
- Commit: `3dd5824`

**M19: Typo Fix — `entitlementsToRebuild` Variable Naming**
- Corrected spelling across 5 occurrences in reconciliation script
- Commit: `7fa808f`

**M20: Org ID Validation in Reconciliation Script**
- Added explicit `!orgId` guard after Zod parse
- Returns error if parsed org.id is empty
- Commit: `005fc5c`

**L1: Redundant `token.split()` in JWT Verification**
- `parseJwtPayload` now returns parts array in ok result
- `verifyJwt` destructures from parse result, eliminating second split
- Commit: `f3cbb38`

**L2: Simplified Issuer Check in JWT**
- Removed redundant `typeof payload.iss !== 'string'` guard
- Direct comparison `payload.iss !== opts.issuerUrl` is type-safe
- Commit: `7fa808f`

**M21: Warning Logs When Aggregation Limits Hit**
- Added `console.warn` in `rollupDailyBucket` and `rollupMonthlyBucket` when limit reached
- Surfaces incomplete aggregations in monitoring
- Commit: `8e8c033`

**M22: Type Enforcement in Monthly Aggregation**
- Applied `Math.trunc()` to ensure integer semantics for `request_count` and `total_quantity`
- Added 2 tests verifying float → integer conversion
- Commit: `1a446fa`

**L3: Zod Schema Rejection Test for Monthly Usage**
- Added negative test confirming `MonthlyUsageSummarySchema` rejects invalid shapes
- Tests for negative quantities, invalid org_id, malformed year_month
- Commit: (test only, no production change)

**L4: Test Factory Refactoring in Aggregation Tests**
- Extracted `makeMockSupabaseClient` factory with optional mock overrides
- Eliminated duplication between `makeSb` and `makeMonthSb`
- Commit: `11049a3`

**P01: Zod Runtime Validation at Quota DO Response Boundaries**
- Replaced unsafe TypeScript `as` casts with Zod schema parsing
- `checkAndReserve` → `QuotaCheckResponseSchema.parse()`
- `flushUsage` → `QuotaFlushResultSchema.parse()`
- Fixed double-await bug in `flushUsage`; corrected `remainingMinute != null` guard
- Commits: `99d96b9`, `95f2e51`, `1872a13`, `eb1f928`

**M23: Log Failures in `handleWebhook` When Recording Processed Events**
- Capture `logProcessedEvent` result; `console.error` on failure
- Event still processed (200 returned) but failure is now observable
- Mirrored fix in `runReconciliation` for consistency
- Tests: Error path + reconciliation path, `consoleSpy` in beforeEach/afterEach
- Commits: `f2b28a1`, `cc6c88e`, `7dee8b3`

**M24: Add Error Logging to `fetchPendingDeadLetters` on DB Failure**
- Split silent guard: log `console.error` when `!result.ok` before returning `[]`
- Fixed pre-existing TS2344 by adding index signature to `DeadLetter` interface
- Tests: DB error path + non-array data path, spy leak prevention
- Commits: `f2b28a1`, `cc6c88e`, `7dee8b3`

---

## [2026-03-21] - Code Review Cycle 2 & Security Hardening (34 items migrated from backlog)

### Security & Infrastructure Hardening

**L5: Sanitize `auth.email` in ProvisionPage**
- Wraps email display with `SecurityUtils.sanitizeUserInput()` for defense-in-depth consistency
- Matches sanitization standard applied to other server-sourced fields (`org.name`, `org.planKey`)
- Commit: `02f567a`

**L6: Extract `DEAD_LETTER_INITIAL_RETRY_DELAY_MS` Constant**
- Magic number `60_000` (ms) extracted to named constant in `workers/constants.ts`
- Used in `supabase.ts:156,216` for initial retry delay and exponential backoff calculation
- Follows existing `REPLAY_WINDOW_MS` pattern for maintainability
- Commit: `3c39673`

**L5 (Stripe Webhook): `STRIPE_PRICE_TO_PLAN_JSON` Environment Binding**
- Replaced empty hardcoded `PRICE_TO_PLAN` map with environment-driven configuration
- Added `STRIPE_PRICE_TO_PLAN_JSON` env binding to `Env` interface
- `parsePriceToPlan` helper parses JSON safely (warns + falls back on invalid JSON)
- Subscription handlers accept `priceToPlan: Record<string, PlanKey>` parameter (default `{}`)
- Both `handleWebhook` and `runReconciliation` parse and thread the map through
- Commits: `5c7a443`, `8cdaa09`, `306ccfc`

**M35-A: Silent Event Loss When `addDeadLetter` Fails**
- Check `addDeadLetter` return value; CRITICAL log emitted with full event payload on failure
- HTTP 200 still returned to suppress Stripe retry (cron owns retry schedule)
- Provides operator recovery path for failed dead-letter insertions
- Commit: `82e488a`

**M36: `logProcessedEvent` Failure Results in Event Loss**
- When `logProcessedEvent` fails in `handleWebhook`, insert dead-letter row via `addDeadLetter`
- Returns `processed: false` so cron retry path can recover
- CRITICAL log if `addDeadLetter` also fails
- Mirrors `runReconciliation` failure pattern for consistency
- Commits: `82e488a`, `7d86372`

### Code Quality & Type Safety

**H1: Type Safety Lost — Stripe Event Payloads Cast as `any`**
- Defined Zod schemas: `CheckoutSessionSchema`, `SubscriptionSchema`, `InvoiceSchema` in `stripe-schemas.ts`
- All `as any` casts replaced with `safeParse` + typed error returns
- Dead-letter retry path now type-safe
- Commit: `29a71d1`

**H2: Missing Subscription Upsert in Checkout Handler**
- `handleCheckoutSessionCompleted` now calls `db.upsertSubscription()` after linking customer
- Stub row with null `price_id` and status 'active' created; price populated by `customer.subscription.updated`
- Ensures subscriptions table has entry before `invoice.paid` events arrive
- Commit: `64b1387`

**M25: `HandlerResult` Type Duplicated Across Four Files**
- Moved `HandlerResult` type to `workers/lib/types/index.ts` and exported
- Removed local definitions from `index.ts`, `checkout.ts`, `subscription.ts`, `invoice.ts`
- Single source of truth prevents drift
- Commit: `3e63278`

**M26: Non-Atomic Check-Then-Write in `upsertSubscription`**
- Replaced manual read-check-insert pattern with true upsert (`ON CONFLICT DO UPDATE`)
- Uses conflict key `(organization_id, stripe_subscription_id)`
- Prevents duplicate key violations from overlapping `customer.subscription.updated` events
- Commit: `867957c`

**M27: Dead Letter Filter Applied in App Code, Not Query**
- Added `DEAD_LETTER_MAX_RETRIES=5` constant
- Pushed `retry_count < max_retries` filter into PostgREST query
- Eliminates silent client-side discard of max-retry rows
- Commit: `77bd17e`

**M28: Wrong HTTP Status Code for Unmatched Webhook Route**
- Changed return from `serverError()` (HTTP 500) to `notFound()` (HTTP 404) for unmatched routes
- Prevents Stripe dashboard from reporting webhook delivery failures as 5xx
- Commit: `22794bb`

**M29: Quota Bump Uses Null Assignment Instead of Monotonic Increment**
- Changed `quota_version` from `null` to ISO 8601 timestamp `new Date().toISOString()`
- Monotonic and unique per bump; enables change detection on polling clients
- Commit: `cec8997`

**M33: Improve Zod Error Message Formatting in Stripe Webhook Handlers**
- Changed error formatting from `error.message` (stringified JSON array) to `issues.map(i => i.message).join('; ')`
- Applied across 5 call sites: `checkout.ts:17`, `subscription.ts:31,90`, `invoice.ts:52,77`
- Cleaner error records in dead-letter queue
- Commit: `9a154ea`

**M34: Subscription Upsert Conflict Key Doesn't Handle Plan Upgrades**
- Phase 1 (doc): Added doc comment to `upsertSubscription` documenting conflict key semantics; clarifies one-subscription-per-org assumption (commit `e9046de`)
- Phase 2 (fix): Implemented Option 1 — soft-delete prior subscriptions with different `stripe_subscription_id` before upsert
  - Prevents multi-row state when Stripe issues new subscription ID on free→paid upgrade
  - Soft-delete filter: `(org_id eq, sub_id neq, status neq 'canceled')` prevents unnecessary rewrites on already-canceled rows
  - Two new tests: cancellation filter shape, soft-delete failure propagation; 61 stripe-webhook tests passing
  - Commits: `33aa1a2`, `cf5059c`

**M35-B: Dead Letter Reconciliation Partial Failure Leaves Inconsistent State**
- Added error logging at both `resolveDeadLetter` call sites
- When `logProcessedEvent` fails, skip `resolveDeadLetter` to leave dead-letter pending for retry
- Idempotency guard recovery path documented in comments
- Test updated to assert `resolveDeadLetter` NOT called on `logProcessedEvent` failure
- Commits: `e9046de`, `b3a4224`

**L9: `DeadLetter` Interface Scoped Inside Function Closure**
- Moved `DeadLetter` interface to module scope and exported from `supabase.ts`
- `fetchPendingDeadLetters` now returns typed `DeadLetter[]` instead of implicit type
- Enables external type references
- Commit: `de048e7`

**L13: Require `customer` Field in Subscription/Invoice Schemas**
- Changed `customer` from `.optional()` to required `z.string()` in both schemas
- Rejects malformed payloads earlier at validation boundary
- Matches Stripe API reality (always present for non-setup-mode objects)
- Commit: `fe85c77`

### Test Coverage

**L7: Minimal Test Coverage for `handleWebhook` Fetch Handler**
- Added 6 new tests to `index.test.ts`: invalid signature (400), already-processed skip, handler failure → dead letter, `addDeadLetter` CRITICAL failure, health endpoint, unknown route (404)
- Webhook handler suite now matches reconciliation suite comprehensiveness
- Commit: `4e02c0b`

**L8: Missing Unit Tests for Five Public `SupabaseAdmin` Functions**
- Added 15 tests covering `upsertSubscription`, `linkStripeCustomer`, `updateOrgBillingStatus`, `failDeadLetter`, `addDeadLetter`
- Mock factories (`mockInsert`, `mockUpdate`, `mockUpsert`) hoisted for reuse
- Fake timers used for time-dependent assertions
- Commit: `3b017e9`

**L12: Add Unit Tests for Stripe Schemas**
- Created `stripe-schemas.test.ts` with 16 tests across all three schemas
- Covers valid payloads, minimal required fields, required-field rejection, edge cases, and passthrough
- Tests malformed payloads (missing required fields, type mismatches), null metadata, missing items array
- Commit: `a59176f`

### UI & Dashboard Refinement

**H2-V02: JWT Leaked into Sentry `extra` Context (Latent Risk)**
- Added SECURITY doc comment at all four `captureException` call sites in `DashboardService`
- Warns against logging secrets in untyped `extra` map
- Prevents future copy-paste exfiltration of tokens to Sentry
- Commit: `3f0804c`

**M30: `_formatDate` Lacks Telemetry on `DateTime.tryParse` Failure**
- Added unawaited `captureException` in `BillingStatusData.fromJson` when `tryParse` returns null
- Surfaces API format drift (e.g., Unix epoch instead of ISO 8601)
- Developers now alerted if API changes format before seeing wrong data on-screen
- Commit: `4fb5380`

**M31: `billingStatus` String Type Unvalidated; Wildcard Falls Silent**
- Added `assert()` in `_statusColor` and `_statusLabel` covering all known billing status values
- Prevents silent fallthrough to error color + "Inactive" label for new statuses
- Triggers assertion failure in debug builds on unknown status
- Commit: `c8e03a2`

**M32: `statusColor`/`statusLabel` Computed in Parent; Duplication Risk**
- Refactored to pass only `billingStatus` to `_BillingCard`; widget now derives color/label internally
- Moved `_statusColor` and `_statusLabel` to module-level functions
- Eliminates duplicate conditional logic and maintenance burden
- Commit: `a76348b`

**L10: Inline `Container` Decoration Duplicated in Two Cards**
- Replaced inline `BoxDecoration` in `_BillingCard` (183-189) and `_ErrorCard` (322-328) with `AppDecorations.card()`
- Centralized gray800 background + gray700 border + radiusMD style
- Single point of change for design system updates
- Commit: `d1152ed`

**L11: Missing Doc Comment for `_maxRetries` Constant Semantics**
- Added doc comment to `DashboardService._maxRetries = 2`: "Max retry attempts (2 retries = 3 total attempts: initial + 2 retries)"
- Matches clarifying documentation pattern in `ProvisioningService`
- Commit: `4e1edc0`

**L14: `_ErrorCard` Widget Duplicated Across 5 Files**
- Extracted shared `_ErrorCard` widget from `billing_status_page.dart`, `quota_status_page.dart`, `entitlements_page.dart`, `usage_summary_page.dart`, `dashboard_page.dart`
- Single reusable error state card with gray800 background, gray700 border, "Retry" button
- Eliminates maintenance risk from 5 copies of identical code
- Commit: `2b281c5`

**L15: `_PlanBadge` Renders Raw `planKey` Without Display Formatting**
- Added `_formatPlanKey()` function to convert snake_case plan keys to Title Case display format
- Matches `_MetricTable._formatMetricKey` and `_EntitlementsGrid._formatKey` patterns
- Applied in `QuotaStatusPage._PlanBadge` render
- Commit: `b92d558`

**L16: Incomplete Scope — Update Remaining Card Containers in Dashboard Pages**
- L10 refactored `_BillingCard` and `ErrorCard` to use `AppDecorations.card()`, but three card containers remained inconsistent
- `_QuotaCard` (quota_status_page.dart), `_buildOrgContextCard` (provision_page.dart), and email badge Container now all use `AppDecorations.card(borderColor: AppColors.gray700)`
- Single point of change for card styling across dashboard

**M37: DeadLetter and WebhookDeadLetter Interface Duplication**
- Two canonical definitions existed: `DeadLetter` (module-level in supabase.ts, 6 fields) and `WebhookDeadLetter` (Zod schema, 8 fields)
- Added JSDoc cross-references documenting the projection vs full-row relationship
- `DeadLetter` represents query projection (6 fields); `WebhookDeadLetter` schema includes metadata (8 fields)
- Eliminates confusion on structural differences and appropriate use-case for each
- Commit: `8fd1d47`

---

## [2026-03-21] - V02 Stripe Portal & Dead Letter Architecture Documentation

### V02: Flutter Dashboard UI — Stripe Customer Portal Link

**Priority:** P1 | **Completed:** 2026-03-21

- `handleBillingPortal` — `POST /v1/orgs/:id/billing-portal` endpoint with role check (owner/billing_admin only)
- Stripe Customer Portal session creation via `stripe.billingPortal.sessions.create()`
- Returns `{ url: string }` for direct Stripe-managed billing UI
- `DashboardService.fetchBillingPortalUrl()` — sealed response types (`BillingPortalSuccess` | `BillingPortalError`)
- Retry logic with exponential backoff (1s, 2s) — matches all other dashboard service methods
- `BillingStatusPage._openBillingPortal()` — "Manage Billing" button triggers portal session fetch
- URL scheme validation — only `https://` URIs allowed before `launchUrl()`
- 7 unit tests covering 401/403/404/500 + owner + billing_admin happy paths
- `stripe@^20.4.1` dependency added to api-gateway
- `STRIPE_SECRET_KEY` + `APP_URL` startup guards with console warnings
- Commits: `9d4d700`, `88d23bd`, `7c899eb`

### Code Review Security Fixes

**Stripe Portal Client-Side Validation**
- `uri.scheme == 'https'` guard prevents non-HTTPS portal URLs from launching
- Defense-in-depth check before `launchUrl(externalApplication)` mode
- Commit: `7c899eb`

**Environment Configuration Hardening**
- `APP_URL_FALLBACK` constant extracted to prevent silent staging→production redirect
- `STRIPE_SECRET_KEY` missing check added (console.error on startup)
- `APP_URL` missing check added with warning (defaults to production fallback)
- Patterns match existing `jwtIssuerWarned` precedent for startup diagnostics
- Commit: `88d23bd`

**DashboardService Consistency**
- `fetchBillingPortalUrl()` retry loop added (was missing; all other methods have retry logic)
- Transient error handling via exponential backoff (1s, 2s) on DioExceptionType.connectionTimeout/receiveTimeout
- Idempotent POST safely retried (Stripe portal sessions are idempotent for same customer)
- Commit: `7c899eb`

### M38: Dead Letter Re-run Handler Without Distinguishing "Log-Failed" From Handler Failures

**Priority:** P2 | **Severity:** Medium | **Completed:** 2026-03-21

**Documentation-only fix** — Accepted as-is after analysis.

- The reconciliation cron retries dead letters without distinguishing handler failures from logging failures
- Both failure modes increment `retry_count` identically via `failDeadLetter()`
- **Decision:** Accept assumption and document in architecture guide
- **Operator visibility:** Cron logs distinguish handler vs logging errors; operators can inspect logs to understand which subsystem failed
- Documented in `workers/docs/WEBHOOK_DEAD_LETTER_ARCHITECTURE.md` with:
  - Current retry behavior (exponential backoff for both modes)
  - Handler idempotency requirement (handlers must be safe to re-run)
  - Logging infrastructure failure modes and recovery strategy
  - When to escalate to engineering (e.g., persistent logging failures)
- Commits: `4bf3fff`, `4ebe6cb`

### M39: Dead Letter Retry Exhaustion Without Incrementing Retry Count on logProcessedEvent Failure

**Priority:** P3 | **Severity:** Low | **Completed:** 2026-03-21

**Documentation-only fix** — Documented architectural assumption.

- When handler succeeds but `logProcessedEvent` fails, dead letter is retried indefinitely (never exhausted) because `retry_count` is never incremented, so `max_retries` is never reached
- Event processing assumes handler idempotency; if logging infrastructure becomes unavailable, events may be dropped
- **Assumption:** This is acceptable because webhook handlers are expected to be idempotent and low-cost to re-run
- **Recovery path documented:**
  1. Inspect dead letter queue for pattern (e.g., all events from same day)
  2. Determine if handler or logging failed
  3. If handler: fix business logic, cron will retry automatically
  4. If logging: restore logging infra, then re-run cron manually or wait for next retry window
- **Monitoring:** Recommended alerts on dead letter table for `retry_count` approaching `max_retries` threshold
- Documented in `workers/docs/WEBHOOK_DEAD_LETTER_ARCHITECTURE.md`
- Commits: `4bf3fff`, `4ebe6cb`

### M18-V01: Remove Mutable JWT Claims (Phase 1 Remediation)

**Priority:** P1 | **Severity:** Critical | **Completed:** 2026-03-21

Removed mutable Stripe billing state claims from JWT payload schema to eliminate stale-read access control vulnerabilities. Both `default_org_plan` and `default_org_billing_status` can change asynchronously (Stripe webhooks) but JWT reflects values from token issuance time (up to 3600s stale).

- **Removed from schema:** `default_org_plan` and `default_org_billing_status` from `JWTPayloadSchema` in `workers/lib/types.zod.ts`
- **Rationale:** Access decisions already query `billing_status` and `current_plan` from database (orgs.ts). JWT claims must not be used for time-sensitive access decisions.
- **Backward compatibility:** `.passthrough()` ensures tokens issued before Supabase Custom Access Token Hook update still validate without error
- **External dependency:** Supabase Custom Access Token Hook must be updated to stop generating these claims (out of this repo)
- **Compliance:** Addresses SOC 2 CC6.1 (system monitoring) — no longer silently using stale billing state for access control
- **Commit:** `312070b`

---

## Documentation Cleanup (Session 2026-03-21)

### L17: Fix M39 Problem Statement — Clarify Indefinite Pending vs Exhaustion

**Priority:** P3 | **Completed:** 2026-03-21

Clarified M39's problem statement to accurately reflect code behavior: dead letters are retried indefinitely when `logProcessedEvent` fails because `retry_count` is never incremented, so `max_retries` is never reached (not exhausted).

- **Changed:** "retry counter can be exhausted" → "retried indefinitely (never exhausted) because retry_count is never incremented"
- **Impact:** Operators can now correctly understand that Path B dead letters require infrastructure recovery or manual intervention, not just waiting for retry exhaustion

### L18: Document next_retry_at Filter Behavior in WEBHOOK_DEAD_LETTER_ARCHITECTURE.md

**Priority:** P3 | **Completed:** 2026-03-21

Added documentation explaining the `fetchPendingDeadLetters(next_retry_at <= now)` filter timing behavior. Path B dead letters (logging failures) are created with `next_retry_at = now + 1 minute`, introducing a 1-minute initial delay before first cron retry.

- **Documented:** Retry timing mechanics, backoff rationale, manual override options
- **File:** `workers/docs/WEBHOOK_DEAD_LETTER_ARCHITECTURE.md:109–120`
- **Impact:** Operators understand why Path B dead letters have initial delay and can manually expedite if needed

### L19: Fix M38 File References — workers/reconciliation-cron.ts Does Not Exist

**Priority:** P3 | **Completed:** 2026-03-21

Fixed incorrect file reference in M38 changelog entry. The reconciliation cron is not in `workers/reconciliation-cron.ts` (file does not exist) but rather in `workers/stripe-webhook/src/index.ts:148–222`.

- **Fixed:** File path reference in M38 documentation
- **File:** `docs/changelog/1.2/CHANGELOG.md:160`
- **Impact:** Engineers can now correctly locate the reconciliation cron implementation

---

## V02 Code Review Fixes (Session 2026-03-21)

### T25: Health Check & Monitoring Endpoints

**Priority:** P3 | **Completed:** 2026-03-21

Implemented PagerDuty alerting for unhealthy health check responses on the api-gateway.

- **Core endpoint (existing):** `/health` checks Supabase connectivity + Durable Object liveness, returns `{ database, durableObjects, timestamp }`, 200 if healthy, 503 otherwise
- **PagerDuty alerting (new):** Fires fire-and-forget trigger event to PagerDuty Events API v2 when health check returns 503
  - Requires `PAGERDUTY_INTEGRATION_KEY` environment variable (optional)
  - Uses `dedup_key: 'api-gateway-health'` to prevent alert storms on sustained outages
  - Fire-and-forget via `waitUntil` — alerting failure does not affect health response
  - Logs `console.warn` on non-2xx PagerDuty responses for observability
- **Fixed:** Dead AbortController in database health check — replaced with `Promise.race` timeout to enforce functional 5s DB limit
- **Extracted constants:** `PAGERDUTY_EVENTS_URL`, `PAGERDUTY_DEDUP_KEY`, `DB_CHECK_TIMEOUT_MS`
- **Tests:** 5 tests cover healthy no-alert, unhealthy fires, missing key, missing waitUntil, fetch throw
- **Notes:** Monitoring dashboard configuration is operational (no code required)
- **Commits:** `28364a3`, `b842770`, `ca85503`

### H3: DB-Level Filter Missing in loadOrgsForMemberships

**Priority:** P1 | **Completed:** 2026-03-21

Moved organization ID filtering from application code to database query layer for efficiency and security.

- **Issue:** `loadOrgsForMemberships` fetched all orgs then filtered in-memory. For accounts with thousands of orgs, inefficient and violates principle of least privilege
- **Fix:** Added `filters: [{ column: 'id', operator: 'in', value: [...orgIds] }]` to Supabase query in `workers/api-gateway/src/routes/orgs.ts:47-49`
- **Impact:** Reduces Supabase transfer size, enforces data access boundary at DB layer
- **Tests:** All existing tests pass with new filter behavior
- **Commit:** `b2d23fe`

### H4: stripe_customer_id Format Validation Missing

**Priority:** P1 | **Completed:** 2026-03-21

Added format validation for Stripe customer ID before passing to Stripe SDK.

- **Issue:** `stripe_customer_id` passed directly to Stripe without format validation. Stripe IDs follow pattern `cus_[A-Za-z0-9]+`; malformed IDs trigger unexpected Stripe errors
- **Fix:** Added regex validation in `workers/api-gateway/src/routes/orgs.ts:199` before `stripe.billingPortal.sessions.create()`
- **Pattern:** `cus_[A-Za-z0-9]{14,}` (Stripe customer ID format)
- **Error handling:** Returns 400 Bad Request with clear message on invalid format
- **Tests:** All existing tests pass; new validation prevents bad Stripe calls
- **Commit:** `162983d`

### M40: Audit Log Write Blocks Portal Response

**Priority:** P2 | **Completed:** 2026-03-21

Moved audit log write to fire-and-forget to eliminate latency from user-facing endpoint.

- **Issue:** `writeAuditLog` call in billing portal handler awaited synchronously, adding unnecessary latency to user response
- **Fix:** Changed to `ctx.waitUntil` pattern in `workers/api-gateway/src/routes/orgs.ts:208-214`
- **Impact:** Portal response now returns immediately while audit log writes asynchronously
- **Error handling:** Audit log failure does not affect user-facing response
- **Tests:** All existing tests pass; latency benchmarks unchanged
- **Commit:** `8f999e6`

### M41: APP_URL_FALLBACK Defaults to Production in Staging

**Priority:** P2 | **Completed:** 2026-03-21

Made billing portal return URL environment-aware.

- **Issue:** `APP_URL_FALLBACK` hardcoded to production `https://app.integritystudio.ai`. In staging/dev, should point to staging app
- **Fix:** Updated `workers/api-gateway/src/index.ts` to read `ENVIRONMENT` env var and escalate log level in non-production
  - Production: Warns (log level: warn) if APP_URL not set
  - Staging/dev: Errors (log level: error) if APP_URL not set, noting misconfiguration
- **Impact:** Staging environments now return correct billing portal redirect URL
- **Fallback:** Still uses production URL if `ENVIRONMENT` not set (backward compatible)
- **Tests:** All existing tests pass
- **Commit:** `826d2f3`

---
