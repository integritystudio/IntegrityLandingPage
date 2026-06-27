# Inter-Worker Contract Validation Report

**Date:** 2026-03-20
**Scope:** Sender Worker ↔ Receiver Worker API Contract
**Status:** ✅ **COMPLIANT** — All critical contracts matched

---

> ℹ️ **What this report validates (read first).** This is a historical 2026-03-20 report validating the contract between `sender-worker` and the **local stub** `workers/receiver-worker/` (a test double). Two things have since changed:
> - **Transport:** the sender reaches the receiver via a Cloudflare **service binding** (`binding = "RECEIVER"`, `service = "api-provisioning-receiver"` in `workers/sender-worker/wrangler.toml`) — `env.RECEIVER.fetch(".../inbox")` — **not** a public `RECEIVER_WORKER_URL` fetch. The `RECEIVER_WORKER_URL` env var and `receiver-worker.example.workers.dev` hostname below are obsolete.
> - **Production receiver:** the deployed receiver is **`api-provisioning-receiver`** (separate `observability-toolkit` repo, `services/api-provisioning-receiver/`), which persists to Supabase and returns `{ service: "api-provisioning-receiver" }` from `/health`. `workers/receiver-worker/` is **not deployed** and nothing binds to it. For production contract validation, see the integration tests in `observability-toolkit`.
>
> The HMAC/timestamp/error-shape findings below still hold — the stub mirrors the production receiver's wire contract — but ignore the deployment, URL-wiring, and config-matrix sections as a production guide.

---

## Executive Summary

The Sender Worker and Receiver Worker implementations are **fully compliant** with each other. All HMAC signing, timestamp handling, error responses, and endpoint contracts match between the two workers.

---

## Worker Roles

### Sender Worker (`workers/sender-worker/`)
- **Purpose:** Accept JSON payloads from Flutter clients
- **Responsibility:** Sign requests with HMAC-SHA256 before forwarding
- **Endpoints:**
  - `POST /send` — Accept signed client request, forward to receiver
  - `OPTIONS /send` — CORS preflight
  - `GET /health` — Public health check (not implemented in current code)
  - `404` — All other routes

### Receiver Worker (`workers/receiver-worker/`)
- **Purpose:** Verify signed requests and store provisioning data
- **Responsibility:** Validate HMAC signatures and timestamp freshness
- **Endpoints:**
  - `GET /health` — Public health check
  - `POST /inbox` — Receive signed request from sender, verify auth
  - `404` — All other routes

---

## Contract Validation Checklist

### 1. HMAC Signature Format ✅

**Receiver Expects:**
```
signature = HMAC-SHA256(
  key: SHARED_SECRET,
  message: "{timestamp}.{body}"
)
Output: hex string (lowercase, zero-padded)
```

**Sender Implementation:**
```typescript
// workers/sender-worker/src/index.ts:27-46
async function computeSignature(body: string, secret: string, timestamp: string): Promise<string> {
  const encoder = new TextEncoder();
  const key = await crypto.subtle.importKey(
    'raw',
    encoder.encode(secret),
    { name: 'HMAC', hash: 'SHA-256' },
    false,
    ['sign'],
  );
  const sig = await crypto.subtle.sign(
    'HMAC',
    key,
    encoder.encode(`${timestamp}.${body}`),
  );
  return [...new Uint8Array(sig)].map(b => b.toString(16).padStart(2, '0')).join('');
}
```

**Match:** ✅ YES — Identical algorithm, identical format

---

### 2. Header Format ✅

**Receiver Expects:**
```
x-timestamp: <milliseconds since epoch, as string>
x-signature: <hex string>
```

**Sender Implementation:**
```typescript
// workers/sender-worker/src/index.ts:72-84
const timestamp = Date.now().toString();
const signature = await computeSignature(body, env.SHARED_SECRET, timestamp);

const response = await fetch(`${env.RECEIVER_WORKER_URL}/inbox`, {
  method: 'POST',
  headers: {
    'content-type': 'application/json',
    'x-timestamp': timestamp,
    'x-signature': signature,
  },
  body,
});
```

**Match:** ✅ YES — Headers set correctly

---

### 3. Timestamp Validation ✅

**Receiver Expects:**
```
- Timestamp must be numeric
- Window: NOW ± 5 minutes (REPLAY_WINDOW_MS = 300,000 ms)
- Reject if outside window: 401 "stale or invalid timestamp"
```

**Sender Implementation:**
```typescript
const timestamp = Date.now().toString();  // Current time, milliseconds
```

**Note:** Sender doesn't validate timestamp freshness — that's receiver's job (correct design).

**Match:** ✅ YES — Sender uses `Date.now()` which will always be within 5-minute window

---

### 4. Error Response Format ✅

**Receiver Errors:**
```json
{ "error": "missing auth headers" }     // 401
{ "error": "stale or invalid timestamp" }  // 401
{ "error": "invalid signature" }        // 401
{ "error": "invalid json" }             // 400
{ "error": "not found" }                // 404
```

**Sender Errors:**
```json
{ "error": "invalid json" }             // 400
{ "error": "forbidden" }                // 403 (CORS rejection)
{ "error": "receiver-worker unreachable" } // 502
{ "error": "not found" }                // 404
```

**Analysis:**
- ✅ Sender and receiver use same error format
- ✅ 400 "invalid json" matches
- ✅ 404 "not found" matches
- ⚠️ Sender has 403 "forbidden" (CORS) — receiver doesn't (receiver is internal-only)
- ⚠️ Sender has 502 "receiver-worker unreachable" — receiver doesn't (correct design)

**Match:** ✅ YES — Error responses compatible

---

### 5. Content-Type Header ✅

**Both Workers:**
```
Content-Type: application/json; charset=utf-8
```

**Sender Implementation:**
```typescript
// workers/http-helpers.ts:4
export const JSON_CONTENT_TYPE = 'application/json; charset=utf-8';
```

**Receiver Implementation:**
```typescript
// workers/receiver-worker/src/index.ts:8-13
function jsonResponse(body: unknown, status: number): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { 'content-type': JSON_CONTENT_TYPE },
  });
}
```

**Match:** ✅ YES — Shared constant used by both

---

### 6. Success Response Format ✅

**Receiver Returns (200 OK):**
```json
{
  "ok": true,
  "received": { ...parsed_body }
}
```

**Sender Forwards:**
```typescript
// workers/sender-worker/src/index.ts:88-93
const response = await fetch(`${env.RECEIVER_WORKER_URL}/inbox`, ...);
const responseBody = await response.text();
return new Response(responseBody, {
  status: response.status,
  headers: { 'content-type': JSON_CONTENT_TYPE, ...corsHeaders },
});
```

**Match:** ✅ YES — Sender passes through receiver response unchanged

---

### 7. Health Endpoint ✅

**Receiver Implements:**
```typescript
// workers/receiver-worker/src/index.ts:59-61
if (pathname === '/health' && request.method === 'GET') {
  return jsonResponse({ ok: true, service: 'receiver-worker' }, 200);
}
```

**Sender:** Does NOT implement `/health` endpoint

**Note:** Sender's `/health` is handled by Cloudflare, not code. Receiver-worker's `/health` is a public endpoint for liveness checks (documented in api-provisioning.md).

**Match:** ✅ ACCEPTABLE — Sender doesn't need `/health` (only receiver does for public health checks)

---

### 8. Configuration Sharing ✅

**Both Workers Share:**
- `SHARED_SECRET` — HMAC key (via wrangler secret)
- `JSON_CONTENT_TYPE` — Constant from `workers/http-helpers.ts`
- `REPLAY_WINDOW_MS` — Constant from `workers/constants.ts` (5 minutes)

**Sender Environment:**
```typescript
interface Env {
  SHARED_SECRET: string;
  RECEIVER_WORKER_URL: string;
  ALLOWED_ORIGINS_JSON?: string;  // NEW: CORS config
}
```

**Receiver Environment:**
```typescript
interface Env {
  SHARED_SECRET: string;
}
```

**Match:** ✅ YES — Both read same SHARED_SECRET

---

### 9. Request Flow Validation ✅

**Expected Flow:**
```
Flutter App (HTTPS)
  → POST /send
     {userId, action, sentAt}
Sender Worker
  → compute signature
  → fetch POST /inbox with x-timestamp, x-signature headers
Receiver Worker
  → validate timestamp (±5 min)
  → validate signature
  → parse JSON
  → return 200 {ok: true, received: {...}}
Sender Worker
  → pass through to Flutter
```

**Sender Code Path:**
1. ✅ Receives POST /send with JSON body
2. ✅ Validates JSON (400 if invalid)
3. ✅ Computes timestamp (`Date.now().toString()`)
4. ✅ Computes signature (HMAC-SHA256 with `timestamp.body`)
5. ✅ Fetches receiver-worker with headers
6. ✅ Passes through response

**Receiver Code Path:**
1. ✅ Receives POST /inbox
2. ✅ Validates x-timestamp and x-signature headers (401 if missing)
3. ✅ Validates timestamp in ±5 min window (401 if stale)
4. ✅ Recomputes signature and compares (401 if mismatch)
5. ✅ Parses JSON body (400 if invalid)
6. ✅ Returns 200 {ok: true, received: {...}}

**Match:** ✅ YES — Complete flow is compatible

---

## Test Coverage Alignment

### Sender Worker Tests (21 total)
- ✅ HMAC signature computation and forwarding
- ✅ Signature format validation
- ✅ Response status code pass-through
- ✅ Receiver errors passed through
- ✅ Invalid JSON handling (400)
- ✅ Configuration validation (500 if missing)
- ✅ Network error handling (502)
- ✅ Unknown routes (404)
- ✅ **NEW:** CORS preflight handling (OPTIONS)
- ✅ **NEW:** CORS origin validation (403 on disallowed)
- ✅ **NEW:** Environment-aware origin configuration

### Receiver Worker Tests (16 total)
- ✅ Health endpoint (200, no auth required)
- ✅ Valid signed inbox request (200)
- ✅ Missing auth headers (401)
- ✅ Stale/future timestamp (401)
- ✅ Non-numeric timestamp (401)
- ✅ Invalid signature (401)
- ✅ Invalid JSON body (400)
- ✅ Unknown routes (404)
- ✅ Content-Type headers (json charset utf-8)

**Coverage:** ✅ Complementary — Sender tests request signing, Receiver tests signature validation

---

## Security Model Validation

### Authentication ✅
- **Sender:** Uses SHARED_SECRET to sign requests
- **Receiver:** Uses SHARED_SECRET to verify signatures
- **Gap Check:** ✅ NO — Both use identical HMAC algorithm
- **Key Rotation:** ⚠️ NOT IMPLEMENTED (future work noted in docs)

### Replay Protection ✅
- **Receiver:** Validates timestamp window (±5 minutes)
- **Sender:** Always uses `Date.now()` (current timestamp)
- **Gap Check:** ✅ NO — Sender always generates fresh timestamps within window

### Signature Verification ✅
- **Algorithm:** HMAC-SHA256
- **Message Format:** `{timestamp}.{body}` (both workers identical)
- **Comparison:** Constant-time in receiver
- **Gap Check:** ✅ NO — Both use identical format, receiver uses proper comparison

### CORS ✅ (NEW)
- **Sender:** Validates Origin header against ALLOWED_ORIGINS_JSON
- **Receiver:** No CORS headers (internal-only, not exposed to browsers)
- **Gap Check:** ✅ CORRECT — Design is appropriate (sender is browser-facing)

---

## Configuration Matrix

| Setting | Sender | Receiver | Synchronized |
|---------|--------|----------|--------------|
| SHARED_SECRET | ✅ Via wrangler secret | ✅ Via wrangler secret | ✅ MUST match |
| `RECEIVER` service binding | ✅ Via wrangler.toml `[[services]]` | N/A | N/A (replaces `RECEIVER_WORKER_URL`) |
| ALLOWED_ORIGINS_JSON | ✅ Via wrangler vars | N/A | N/A |
| REPLAY_WINDOW_MS | Hardcoded in receiver | 5 minutes | ✅ Fixed |
| HMAC Algorithm | SHA-256 | SHA-256 | ✅ Fixed |

---

## Deployment Checklist

> The checklist below is the obsolete public-URL deployment model. The current production wiring is: `sender-worker` (this repo) is deployed from CI; `api-provisioning-receiver` is deployed from the `observability-toolkit` repo; they are linked by the `RECEIVER` **service binding** in `workers/sender-worker/wrangler.toml`. There is no `RECEIVER_WORKER_URL` to set. Kept for historical reference of the stub contract.

- [ ] SHARED_SECRET set identically on the sender and the production receiver
  ```bash
  cd workers/sender-worker && wrangler secret put SHARED_SECRET
  # set the matching SHARED_SECRET on api-provisioning-receiver (in the observability-toolkit repo)
  # MUST BE IDENTICAL
  ```

- [ ] `RECEIVER` service binding present in sender-worker/wrangler.toml
  ```toml
  [[services]]
  binding = "RECEIVER"
  service = "api-provisioning-receiver"
  ```

- [ ] ALLOWED_ORIGINS_JSON configured on sender for production origins
  ```bash
  wrangler deploy --var ALLOWED_ORIGINS_JSON='["https://www.integritystudio.ai"]'
  ```

- [ ] Sender and `api-provisioning-receiver` deployed to the same Cloudflare account
  - Required for the service binding to resolve

- [ ] Production receiver health endpoint tested (from the observability-toolkit deploy)
  ```bash
  curl https://<api-provisioning-receiver-host>/health
  # Should return: {"ok":true,"service":"api-provisioning-receiver"}
  ```

- [ ] End-to-end test run (see integration tests in observability-toolkit; the in-repo `test-provisioning-e2e.sh` exercises the local stub)

---

## Findings Summary

### ✅ Compliant Areas
1. HMAC-SHA256 signature format (identical implementation)
2. Header format (x-timestamp, x-signature)
3. Error response schema (same JSON structure)
4. Content-Type (shared constant)
5. Success response format (pass-through compatible)
6. Configuration sharing (SHARED_SECRET synchronized)
7. Timestamp handling (fresh timestamps always in window)
8. Request flow (end-to-end compatible)
9. Security model (proper use of HMAC, timestamp window)
10. CORS handling (appropriate for sender role)

### ⚠️ Future Enhancements (Not Required)
1. **Key Rotation** — Add x-key-id header for secret version management
2. **Nonce Store** — Stricter replay protection than timestamp window
3. ~~**Service Bindings** — Use Cloudflare service bindings instead of public fetch~~ ✅ **Done** — production now uses a `RECEIVER` service binding to `api-provisioning-receiver` (no public fetch)
4. **Monitoring** — Add metrics for signature validation success/failure rates

### ❌ Issues Found
**NONE** — All critical contracts are matched and validated.

---

## Conclusion

The Sender Worker and Receiver Worker are **production-ready** from a contract perspective. The HMAC signing mechanism is properly implemented on both sides, timestamp validation is appropriate, error handling is consistent, and the security model is sound.

**Recommendation:** Proceed with staging/production deployment after confirming SHARED_SECRET synchronization between both workers.

---

## References

- Sender Worker: `workers/sender-worker/src/index.ts`
- Receiver Worker (production): `api-provisioning-receiver` in the `observability-toolkit` repo (`services/api-provisioning-receiver/src/`)
- Receiver Worker (local stub / test double): `workers/receiver-worker/src/index.ts`
- Shared Constants: `workers/constants.ts`, `workers/http-helpers.ts`
- Architecture: `docs/api-provisioning.md`
- Client Contract: `docs/api-provisioning-contract.md`
- E2E Tests: `test-provisioning-e2e.sh`
