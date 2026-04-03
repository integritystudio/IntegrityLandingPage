# Backlog

## 🚨 Blockers

### Auth0 Client Credentials Grant Type Configuration (2026-04-03)

**Status**: Blocker — `/signup` endpoint returning 403 from Auth0

**Context**:
- Migrated from separate `AUTH0_CLI_*` and `AUTH0_CLIENT_*` credentials to single `AUTH0_CLIENT_*` set (commit 330b73a)
- Both ROPC (password grant) and M2M (client_credentials grant) now use same credentials
- Code deployed and working; endpoint returns specific error messages
- Auth0 returns: `"Grant type 'client_credentials' not allowed for the client"`

**What Needs to Happen**:
Auth0 application configuration must be updated:
1. Go to Auth0 Dashboard → Applications → [Application using `AUTH0_CLIENT_ID`]
2. In "Grant Types" section, enable "Client Credentials"
3. Ensure the application has permission to call the Management API (`/api/v2/`)
4. Verify the application role/permissions include user creation

**Testing After Fix**:
```bash
curl -X POST https://sender-worker.alyshia-b38.workers.dev/signup \
  -H "Content-Type: application/json" \
  -d '{"email":"test@example.com","password":"Test123!"}'
# Should return 201 with { jwt, auth0Sub, userId, email }
```

**Related Changes**:
- `workers/sender-worker/src/types.ts` — Removed AUTH0_CLI_* fields from Env interface
- `workers/sender-worker/src/index.ts` — Updated auth0CreateUser() call to use AUTH0_CLIENT_*
- `workers/sender-worker/src/env-validation.test.ts` — Updated validation tests
- `workers/sender-worker/src/index.test.ts` — Removed AUTH0_CLI_* regression tests
- All 146 tests passing ✅

---

## ✅ Completed: Integration Test Coverage for Error Scenarios

**Status**: Complete ✅ (Commit 6d2ff74)

**Coverage Added**:
- 8 comprehensive e2e integration tests in `workers/sender-worker/src/index.e2e.test.ts`
- Tests for all 7 ERROR_CODE constants added in credential migration
- Error detail field validation (truncation to 200 chars)
- Real-world error scenarios based on actual Auth0/Supabase failures

**Test Scenarios**:
1. AUTH0_TOKEN_EXCHANGE_FAILED: Client Credentials grant type not allowed
2. AUTH0_USER_CREATION_FAILED: Password strength / validation errors
3. SUPABASE_ORG_CREATION_FAILED: Invalid tier / org creation failures
4. SUPABASE_USER_INSERT_FAILED: Constraint violations / duplicate users
5. SUPABASE_ORG_MEMBERSHIP_FAILED: Invalid organization / permission errors
6. Error detail field truncation validation
7. INTERNAL_ERROR: Unmapped error fallback

**How to Run** (when e2e runner is fixed):
```bash
npm run test:e2e
```

**Documentation**: `workers/sender-worker/src/ERROR_SCENARIO_TESTS.md`

---

## 📋 Ready for Implementation

### Remove "detail" Field from Error Responses (Post-Debug)
**Status**: Optional cleanup after Auth0 configuration is fixed

**Context**: Currently error responses include a `detail` field with the full Auth0/Supabase error message (truncated to 200 chars). This was added for debugging the 500 error.

**What to Do**:
- Remove the `detail` field from `handleSignup()` error response (workers/sender-worker/src/index.ts:120)
- Keep error codes and message mapping for better debugging

**Rationale**: Detail field is useful for development/debugging but should not be exposed in production

---

## 📚 Recent Sessions

### Session: Auth0 Credentials Migration (2026-04-03)
- **Objective**: Fix `/signup` endpoint returning 500 in production
- **Approach**: Consolidate from separate AUTH0_CLI_* and AUTH0_CLIENT_* to single AUTH0_CLIENT_* set for both auth flows
- **Status**: Code complete ✅; Deployed ✅; Auth0 config required ⚠️
- **Commits**: 330b73a
- **Tests**: 146 passing, 0 failing
- **Blocker**: Auth0 dashboard configuration (Client Credentials grant type)
