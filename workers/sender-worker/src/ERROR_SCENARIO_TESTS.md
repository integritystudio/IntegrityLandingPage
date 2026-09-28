# Integration Test Coverage for Error Scenarios (2026-04-03)

## Overview

Added comprehensive integration test coverage for error scenarios uncovered during the Auth0 credentials migration session. Tests validate:

1. **Error Code Mapping** — Each specific error returns the correct ERROR_CODE constant
2. **Error Detail Field** — Error responses include truncated error messages for debugging
3. **Auth0 Failures** — Token exchange and user creation failures
4. **Supabase Failures** — Organization creation, user insert, and org membership failures
5. **Real-World Error Scenarios** — Tests based on actual production errors encountered

## Tests Added (index.e2e.test.ts)

Tests 1–5 live in the `describe("POST /signup — Error Code Mapping (2026-04-03 Session)")`
block of `src/index.e2e.test.ts`; find them by name rather than by line number, which drifts.

### 1. AUTH0_TOKEN_EXCHANGE_FAILED: Client Credentials Grant Type Not Allowed
**Test**: `returns AUTH0_TOKEN_EXCHANGE_FAILED when Auth0 /oauth/token returns 403 unauthorized_client`

Tests the exact error from this session:
```json
{
  "error": "unauthorized_client",
  "error_description": "Grant type 'client_credentials' not allowed for the client."
}
```

**Validates**:
- Returns 500 status
- Returns correct error code: `AUTH0_TOKEN_EXCHANGE_FAILED`
- Detail field contains "Auth0 token exchange failed"

**Production Blocker Context**: This error occurs when the Auth0 application doesn't have Client Credentials grant type enabled. The e2e test simulates this failure to ensure proper error handling when Auth0 configuration is incomplete.

---

### 2. AUTH0_USER_CREATION_FAILED: Invalid Password Strength
**Test**: `returns AUTH0_USER_CREATION_FAILED when Auth0 /api/v2/users returns 400`

Tests Auth0 user creation failure with 400 Bad Request:
```json
{
  "statusCode": 400,
  "error": "Bad Request",
  "message": "Invalid password strength."
}
```

**Validates**:
- Returns 500 status
- Returns correct error code: `AUTH0_USER_CREATION_FAILED`
- Detail field contains "Auth0 createUser failed"

---

### 3. SUPABASE_ORG_CREATION_FAILED: Invalid Tier
**Test**: `returns SUPABASE_ORG_CREATION_FAILED when org creation returns error`

Tests Supabase org creation failure with invalid tier value:
```json
{
  "code": "400",
  "message": "Invalid request: tier must be one of: starter, growth, enterprise"
}
```

**Validates**:
- Returns 500 status
- Returns correct error code: `SUPABASE_ORG_CREATION_FAILED`
- Detail field contains "Supabase org creation failed"

---

### 4. SUPABASE_USER_INSERT_FAILED: Duplicate User
**Test**: `returns SUPABASE_USER_INSERT_FAILED when user insert returns error`

Tests Supabase user insert failure with duplicate constraint violation:
```json
{
  "code": "23505",
  "message": "duplicate key value violates unique constraint",
  "details": "Key (auth0_id)=(auth0|test-user) already exists."
}
```

**Validates**:
- Returns 500 status
- Returns correct error code: `SUPABASE_USER_INSERT_FAILED`
- Detail field contains "Supabase user insert failed"

---

### 5. SUPABASE_ORG_MEMBERSHIP_FAILED: Invalid Organization
**Test**: `returns SUPABASE_ORG_MEMBERSHIP_FAILED when org membership insert fails`

Tests org membership insert failure:
```json
{
  "code": "400",
  "message": "Invalid organization ID"
}
```

**Validates**:
- Returns 500 status
- Returns correct error code: `SUPABASE_ORG_MEMBERSHIP_FAILED`

---

### 6. Unknown Errors Map to INTERNAL_ERROR
**Test**: `still returns 500 with INTERNAL_ERROR when Auth0 fails for a non-credential reason`
(in the `POST /signin — Auth0 ROPC` block)

Tests that unmapped errors default to `INTERNAL_ERROR`:
```json
{
  "error": "unknown_server_error"
}
```

**Validates**:
- Returns 500 status
- Returns error code: `INTERNAL_ERROR`
- Graceful fallback for unexpected errors

---

## ERROR_CODE Constants Coverage

The new tests validate all error codes added in commit 330b73a:

| Error Code | Scenario | Test |
|---|---|---|
| `AUTH0_UNCONFIGURED` | Missing Auth0 env vars | Unit test (env-validation.test.ts) |
| `AUTH0_TOKEN_EXCHANGE_FAILED` | Token endpoint returns error | ✅ Test #1 |
| `AUTH0_USER_CREATION_FAILED` | User creation endpoint fails | ✅ Test #2 |
| `SUPABASE_ORG_CREATION_FAILED` | Org creation endpoint fails | ✅ Test #3 |
| `SUPABASE_USER_INSERT_FAILED` | User insert endpoint fails | ✅ Test #4 |
| `SUPABASE_ORG_MEMBERSHIP_FAILED` | Membership insert endpoint fails | ✅ Test #5 |
| `INTERNAL_ERROR` | Unknown/unmapped errors | ✅ Test #6 |

---

## Error Response Shape

All error responses now include:
```typescript
{
  error: string;        // Human-readable message
  code: string;         // ERROR_CODE constant for programmatic handling
  description?: string; // Human-readable description mapped from the code
  status: number;       // HTTP status code
  headers: {
    "content-type": "application/json"
  }
}
```

The debug-only `detail` field (full upstream error, truncated to 200 chars) was removed once production stabilised — granular `code` constants remain for debugging.

Example:
```json
{
  "error": "signup failed",
  "code": "AUTH0_TOKEN_EXCHANGE_FAILED"
}
```

---

## Running the Tests

### Unit Tests (Auth0/Supabase error handling logic)
```bash
npm test
# Runs all unit tests, including env-validation.test.ts and supabase.test.ts.
# Counts recorded in docs drift; run the suite for the current number.
```

### E2E Tests (Full request pipeline with mocked Auth0/Supabase)
```bash
npm run test:e2e
# Runs every *.e2e.test.ts in the real workerd runtime. Every outbound call is mocked, so no
# credential is needed; the bindings live in vitest.e2e.config.mts, NOT Doppler — a new
# required secret must be added there or every /send test 500s.
```

---

## Known Issues

None open. The runner previously failed with `Missing "./config" specifier in
"@cloudflare/vitest-pool-workers"` because the config imported `defineWorkersConfig` from the
package's v3 entry point. In the Vitest v4 line the pool is applied as a Vite plugin
(`cloudflareTest(...)`), which is what `vitest.e2e.config.mts` now does — see its header comment.

---

## Next Steps

1. **Fix e2e Test Runner**: ✅ Done — see Known Issues.

2. **Verify Error Handling in Production** (when Auth0 config is fixed):
   - Deploy with current error handling
   - Monitor for error code accuracy

3. **Remove Debug Detail Field** (post-debugging): ✅ Done — `detail` field removed from error responses; granular ERROR_CODE constants retained for debugging.

4. **Document Error Codes** (ongoing):
   - Add ERROR_CODE mappings to API documentation
   - Help frontend handle specific error scenarios

---

## Test Authorship & Session Context

**Session**: Auth0 Credentials Migration (2026-04-03)
**Objective**: Fix `/signup` endpoint returning 500 in production

**Root Causes Addressed**:
1. Missing ENV variable validation at endpoint initialization
2. Production/code credential name mismatch (AUTH0_M2M_* vs AUTH0_CLI_* vs AUTH0_CLIENT_*)
3. Lack of granular error code mapping for debugging
4. No detail field in error responses to show actual service failures

**Commits**:
- `330b73a` — refactor: consolidate to single AUTH0_CLIENT_* credentials for both auth flows
- Added comprehensive error scenario tests to prevent regressions

---

## References

- [BACKLOG.md](../../../docs/BACKLOG.md) — Canonical status of every open item
- [index.ts](./index.ts) — Error handling: `handleSignup`, `handleSignIn` (`errorResponse` itself is in `utils.ts`)
- [types.ts](./types.ts) — `ERROR_CODE` constants and `ERROR_DESCRIPTIONS`
- [index.e2e.test.ts](./index.e2e.test.ts) — Error scenario tests (`POST /signup — Error Code Mapping` block)
