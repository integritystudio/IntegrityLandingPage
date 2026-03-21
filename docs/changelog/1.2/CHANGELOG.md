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
- Reconciliation cron (`workers/reconciliation-cron.ts`) runs every 15 min with exponential backoff
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

---
