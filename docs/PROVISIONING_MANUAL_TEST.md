# API Provisioning Manual E2E Test Guide

> ⚠️ **DEPRECATED — local-stub only.** This guide tests the **local stub** `workers/receiver-worker/` (a test double) over an obsolete `RECEIVER_WORKER_URL` HTTP wiring. In production the sender reaches the receiver via a **service binding** (`service = "api-provisioning-receiver"` in `workers/sender-worker/wrangler.toml`), and the deployed receiver is **`api-provisioning-receiver`** (separate `observability-toolkit` repo) whose `/health` returns `{ service: "api-provisioning-receiver" }`. Use the integration tests in `observability-toolkit` for production verification. The steps below remain valid only for exercising the in-repo stub locally. See `docs/BACKLOG.md` (W03).

## Overview

This guide provides manual testing procedures for the API provisioning architecture, which includes:
- **Sender Worker** (`workers/sender-worker/`): Signs and forwards requests
- **Receiver Worker** — local stub `workers/receiver-worker/` (test double); production is `api-provisioning-receiver` (`observability-toolkit` repo): Verifies signatures and stores data
- **Request Flow**: Flutter app → Sender Worker (POST /send) → Receiver (POST /inbox, via service binding in prod)

## Prerequisites

```bash
# Wrangler is already installed in devDependencies (package.json)
# Use npx for the project version
npx wrangler --version

# Or install globally (optional)
npm install -g wrangler
```

## Test Environment Setup

### 1. Generate a Signing Key

```bash
# Create a test secret (in production, use: openssl rand -base64 32)
SECRET="&lt;your-test-secret&gt;"
```

Both workers need it under the **same key id** in `SIGNING_KEYS`, and the sender needs
`ACTIVE_KEY_ID` naming that id. Since CR29 step 2 there is no keyless path: the stub rejects a
request with no `x-key-id` (401), and the sender returns `500 SIGNING_KEY_UNRESOLVED` without
forwarding if it cannot resolve one. `SHARED_SECRET` is read by neither.

### 2. Start Receiver Worker

```bash
cd workers/receiver-worker

# Create .env.local with the signing key map
cat > .env.local << EOF
SIGNING_KEYS={"v2":"&lt;your-test-secret&gt;"}
EOF

# Start the worker on port 8788
wrangler dev --port 8788
```

**Expected output:**
```
⛅ wrangler 4.35.0
⎔ Starting local server...
Your Worker is ready at http://localhost:8788
```

### 3. Start Sender Worker (in another terminal)

```bash
cd workers/sender-worker

# Create .env.local with configuration -- the SIGNING_KEYS entry must match the receiver's
cat > .env.local << EOF
SIGNING_KEYS={"v2":"your-test-secret"}
ACTIVE_KEY_ID=v2
RECEIVER_WORKER_URL=http://localhost:8788
EOF

# Start the worker on port 8787
wrangler dev --port 8787
```

**Expected output:**
```
⛅ wrangler 4.35.0
⎔ Starting local server...
Your Worker is ready at http://localhost:8787
```

## Test Cases

### Test 1: Health Check (Receiver Worker)

Verify the receiver-worker health endpoint is accessible.

```bash
curl -s http://localhost:8788/health | jq .
```

**Expected Response (200 OK):**
```json
{
  "ok": true,
  "service": "receiver-worker"
}
```

**Verify:**
- ✓ HTTP status 200
- ✓ `ok` field is `true`
- ✓ `service` field is `"receiver-worker"`

---

### Test 2: Invalid JSON to Sender Worker

Verify sender worker rejects malformed JSON.

```bash
curl -X POST http://localhost:8787/send \
  -H "Content-Type: application/json" \
  -d '{invalid json}'
```

**Expected Response (400 Bad Request):**
```json
{
  "error": "invalid json"
}
```

**Verify:**
- ✓ HTTP status 400
- ✓ Error message is `"invalid json"`

---

### Test 3: Valid Provisioning Event (Full Flow)

Verify the full provisioning pipeline: Flutter app → Sender Worker → Receiver Worker

#### Step 1: Send event via Sender Worker

```bash
PAYLOAD='{"userId":"user123","action":"signup","sentAt":"2026-03-20T12:00:00Z"}'

curl -s -X POST http://localhost:8787/send \
  -H "Content-Type: application/json" \
  -d "${PAYLOAD}" | jq .
```

**Expected Response (200 OK):**
```json
{
  "ok": true,
  "received": {
    "userId": "user123",
    "action": "signup",
    "sentAt": "2026-03-20T12:00:00Z"
  }
}
```

**Verify:**
- ✓ HTTP status 200
- ✓ `ok` is `true`
- ✓ `received` object echoes back the sent payload
- ✓ Sender Worker successfully signed and forwarded to Receiver Worker
- ✓ Receiver Worker verified the signature and accepted the request

---

### Test 4: Direct Receiver API - Missing Auth Headers

Verify the receiver-worker requires authentication headers.

```bash
curl -s -X POST http://localhost:8788/inbox \
  -H "Content-Type: application/json" \
  -d '{"userId":"user456","action":"login"}' | jq .
```

**Expected Response (401 Unauthorized):**
```json
{
  "error": "missing auth headers"
}
```

**Verify:**
- ✓ HTTP status 401
- ✓ Error message is `"missing auth headers"`
- ✓ Direct API access without signature headers is rejected

---

### Test 5: Complex Event Payload

Verify sender and receiver handle nested JSON and metadata correctly.

```bash
PAYLOAD='{"userId":"user789","action":"settings_update","metadata":{"email":"user@example.com","plan":"pro","features":["analytics","export"]}}'

curl -s -X POST http://localhost:8787/send \
  -H "Content-Type: application/json" \
  -d "${PAYLOAD}" | jq .
```

**Expected Response (200 OK):**
```json
{
  "ok": true,
  "received": {
    "userId": "user789",
    "action": "settings_update",
    "metadata": {
      "email": "user@example.com",
      "plan": "pro",
      "features": ["analytics", "export"]
    }
  }
}
```

**Verify:**
- ✓ HTTP status 200
- ✓ Complex nested objects are preserved
- ✓ Arrays in metadata are intact
- ✓ All fields round-trip correctly through sender → receiver

---

### Test 6: Invalid Signature (Direct to Receiver)

Verify the receiver-worker rejects tampered signatures.

```bash
# Generate a timestamp
TIMESTAMP=$(date +%s)000

# Send with invalid signature
curl -s -X POST http://localhost:8788/inbox \
  -H "Content-Type: application/json" \
  -H "x-timestamp: ${TIMESTAMP}" \
  -H "x-signature: invalid_signature_here" \
  -d '{"userId":"user999","action":"test"}' | jq .
```

**Expected Response (401 Unauthorized):**
```json
{
  "error": "invalid signature"
}
```

**Verify:**
- ✓ HTTP status 401
- ✓ Error message is `"invalid signature"`
- ✓ Tampering is detected and rejected

---

### Test 7: Stale Timestamp (Replay Protection)

Verify the receiver-worker rejects requests older than the replay window (5 minutes).

```bash
# Generate a timestamp from 10 minutes ago
OLD_TIMESTAMP=$(($(date +%s) - 600))000

# Compute correct signature for old timestamp
NODE_CMD='
const crypto = require("crypto");
const secret = "&lt;your-test-secret&gt;";
const body = JSON.stringify({userId:"user999",action:"replay_test"});
const ts = "'${OLD_TIMESTAMP}'";
const key = crypto.createHmac("sha256", secret);
key.update(`${ts}.${body}`);
console.log(key.digest("hex"));
'

SIGNATURE=$(node -e "${NODE_CMD}")

curl -s -X POST http://localhost:8788/inbox \
  -H "Content-Type: application/json" \
  -H "x-timestamp: ${OLD_TIMESTAMP}" \
  -H "x-signature: ${SIGNATURE}" \
  -H "x-key-id: v2" \
  -d '{"userId":"user999","action":"replay_test"}' | jq .
```

> ℹ️ Tests 4–6 still return exactly the responses documented here, but for a reason worth
> knowing: the header order is missing-headers → timestamp → key resolution → signature, so
> tests 4 and 5 never reach the key lookup, and a request with no `x-key-id` gets the same
> `invalid signature` a forged one does — deliberately byte-identical, so key ids cannot be
> enumerated. Any test that expects a **successful** `/inbox` call must send `x-key-id`.

**Expected Response (401 Unauthorized):**
```json
{
  "error": "stale or invalid timestamp"
}
```

**Verify:**
- ✓ HTTP status 401
- ✓ Error message is `"stale or invalid timestamp"`
- ✓ Replay protection window (5 minutes) is enforced

---

## Security Verification Checklist

- [ ] **Sender Worker doesn't expose the shared secret to clients** — Secret is only in server environment
- [ ] **Receiver Worker verifies signatures with constant-time comparison** — No timing attacks
- [ ] **Replay protection enforced** — Timestamp window validation (5 minutes)
- [ ] **Invalid JSON rejected early** — Before signature computation
- [ ] **CORS headers present on Sender Worker** (if browser-based client)
- [ ] **Both workers handle errors gracefully** — No stack traces leaked

## Automated Test Run

To run all tests in sequence:

```bash
bash test-provisioning-e2e.sh
```

This script will:
1. Start both workers
2. Run all test cases
3. Report pass/fail status
4. Clean up processes on exit

## Deployment

After manual testing passes:

```bash
# Deploy receiver-worker
cd workers/receiver-worker
wrangler deploy

# Deploy sender-worker
cd workers/sender-worker
wrangler secret put SIGNING_KEYS   # JSON {"v2":"<secret>"}, matching the receiver's
wrangler secret put ACTIVE_KEY_ID  # the id to sign with, e.g. v2
wrangler deploy
```

Then update the Flutter app's `SENDER_WORKER_URL` to point to the deployed sender-worker.

## Last Recorded Results

> Captured 2026-03-20 against the **local stub** `workers/receiver-worker/` (test double) over the obsolete `RECEIVER_WORKER_URL` HTTP wiring — historical reference only, not production. For current end-to-end coverage use the integration tests in `observability-toolkit`. (Consolidated from the former `PROVISIONING_E2E_RESULTS.md`, 2026-06-27.)

**Status:** ⏳ PARTIAL — receiver stub verified; full sender E2E pending environment configuration at time of capture.

| # | Test Case | Expected | Actual | Status |
|---|-----------|----------|--------|--------|
| 1 | Health endpoint accessible | 200 OK, `ok: true` | 200 OK, `ok: true` | ✅ |
| 2 | Missing auth headers rejected | 401, error message | 401, `missing auth headers` | ✅ |
| 3 | Invalid JSON handling | 400, error message | N/A (pending sender config) | ⏳ |
| 4 | Valid event forwarding | 200, echoed payload | N/A (pending sender config) | ⏳ |
| 5 | Complex nested payloads | Preserved structure | N/A (pending sender config) | ⏳ |
| 6 | Signature verification | 401 on invalid sig | N/A (pending sender config) | ⏳ |
| 7 | Replay protection | 401 on stale timestamp | N/A (pending sender config) | ⏳ |

**Security properties verified (stub):**

| Property | Implementation | Status |
|----------|-----------------|--------|
| Shared Secret Storage | Wrangler secrets (not in Flutter) | ✅ |
| Request Signing | HMAC-SHA256 over `timestamp.body` | ✅ |
| Replay Protection | 5-minute timestamp window validation | ✅ |
| Auth Validation | Required headers enforced | ✅ |
| JSON Validation | Invalid JSON rejected early | ✅ |

## References

- [API Provisioning Architecture](docs/api-provisioning.md)
- [Environment Setup Guide](docs/provisioning-environment-setup.md)
- [Sender Worker README](workers/sender-worker/README.md)
- [Receiver Worker Source](workers/receiver-worker/src/index.ts)
- [Cloudflare Workers Crypto](https://developers.cloudflare.com/workers/runtime-apis/web-crypto/)
