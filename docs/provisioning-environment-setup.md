# API Provisioning Environment Setup Guide

**Last Updated:** 2026-03-20
**Version:** 1.0

This guide covers setting up the Sender Worker and Receiver Worker across development, staging, and production environments on Cloudflare.

> ⚠️ **STALE — superseded.** The `receiver-worker` hostnames (`receiver-worker.integritystudio.ai`, `receiver-worker-staging.integritystudio.ai`) and the `RECEIVER_WORKER_URL` env var below describe a retired HTTP-based wiring. The production receiver is now **`api-provisioning-receiver`** (in the separate `observability-toolkit` repo), and `sender-worker` reaches it via a **service binding** (`service = "api-provisioning-receiver"` in `workers/sender-worker/wrangler.toml`), not a URL. Do not follow the receiver deploy steps or URLs here. For production receiver setup, see the `observability-toolkit` repo. Tracked for rewrite in `docs/BACKLOG.md` (W03).

---

## Environment Overview

### Development (Local)
- **Purpose:** Local testing with `wrangler dev`
- **Sender URL:** `http://localhost:8787`
- **Receiver URL:** `http://localhost:8788`
- **CORS Origins:** `http://localhost:8081` (Flutter dev)
- **Secrets:** Generated test secrets (non-sensitive)

### Staging
- **Purpose:** Pre-production testing, internal validation
- **Sender URL:** `https://api-provisioning-sender-staging.integritystudio.ai`
- **Receiver URL:** `https://api-provisioning-receiver-staging.integritystudio.ai`
- **CORS Origins:** `https://staging.integritystudio.ai`
- **Secrets:** Real secrets, but sandboxed from production data

### Production
- **Purpose:** Live service for Flutter app users
- **Sender URL:** `https://api-provisioning-sender.integritystudio.ai`
- **Receiver URL:** `https://api-provisioning-receiver.integritystudio.ai`
- **CORS Origins:** `https://www.integritystudio.ai`
- **Secrets:** Production secrets, strict access control

---

## Prerequisites

1. **Cloudflare Account Access**
   - Account ID and API token for automation
   - Two separate Cloudflare accounts recommended (staging + prod)

2. **CLI Tools**
   ```bash
   npm install -g wrangler          # Cloudflare Workers CLI
   brew install openssl             # For secret generation
   ```

3. **Repository Access**
   - Git credentials configured
   - Write access to IntegrityLandingPage repo

---

## Step 1: Generate Secrets

Generate a cryptographically secure shared secret for HMAC signing:

```bash
# Generate a new SHARED_SECRET (use the same value for both workers in same environment)
openssl rand -base64 32
# Output: AbCdEfGhIjKlMnOpQrStUvWxYz1234567890+/=

# Save this value securely:
# - Development: .env.local (git-ignored)
# - Staging: Cloudflare Secrets Manager
# - Production: Cloudflare Secrets Manager + Vault/1Password backup
```

**Important:** The same `SHARED_SECRET` must be set on BOTH sender-worker and receiver-worker in each environment.

---

## Step 2: Environment-Specific Configuration

### 2a. Development Setup

**Sender Worker (workers/sender-worker/)**

Create `.env.local` (if not exists):
```bash
cat > .env.local << 'EOF'
SHARED_SECRET=test-secret-key-12345
RECEIVER_WORKER_URL=http://localhost:8788
EOF
```

**Receiver Worker (workers/receiver-worker/)**

Create `.env.local` (if not exists):
```bash
cat > .env.local << 'EOF'
SHARED_SECRET=test-secret-key-12345
EOF
```

**Start both workers in separate terminals:**

Terminal 1 (Receiver on port 8788):
```bash
cd workers/receiver-worker
wrangler dev --port 8788
```

Terminal 2 (Sender on port 8787):
```bash
cd workers/sender-worker
wrangler dev --port 8787
```

**Test connectivity:**
```bash
# Health check (receiver)
curl http://localhost:8788/health
# Expected: {"ok":true,"service":"receiver-worker"}

# Test signing flow
curl -X POST http://localhost:8787/send \
  -H "Content-Type: application/json" \
  -d '{"userId":"test123","action":"signup"}'
# Expected: {"ok":true,"received":{"userId":"test123","action":"signup"}}
```

---

### 2b. Staging Setup

**Cloudflare Configuration**

```bash
# Authenticate with Cloudflare
wrangler login

# Get account ID
ACCOUNT_ID=$(wrangler deployments list sender-worker | grep account)
echo $ACCOUNT_ID
```

**Update wrangler.toml for staging**

Sender Worker (`workers/sender-worker/wrangler.toml`):
```toml
name = "sender-worker-staging"
main = "src/index.ts"
compatibility_date = "2026-03-19"

[vars]
# Point to staging receiver
RECEIVER_WORKER_URL = "https://receiver-worker-staging.integritystudio.ai"

# Staging CORS origins
# ALLOWED_ORIGINS_JSON = '["https://staging.integritystudio.ai"]'
```

Receiver Worker (`workers/receiver-worker/wrangler.toml`):
```toml
name = "receiver-worker-staging"
main = "src/index.ts"
compatibility_date = "2026-03-19"
```

**Set secrets on both workers**

```bash
# Sender Worker Staging
cd workers/sender-worker
wrangler secret put SHARED_SECRET --env staging
# Paste your generated secret

# Receiver Worker Staging
cd ../receiver-worker
wrangler secret put SHARED_SECRET --env staging
# Paste the SAME secret
```

**Deploy to staging**

```bash
# Sender Worker
cd workers/sender-worker
wrangler deploy --env staging

# Receiver Worker
cd ../receiver-worker
wrangler deploy --env staging
```

**Verify staging deployment**

```bash
# Health check
curl https://receiver-worker-staging.integritystudio.ai/health

# Test signing flow
curl -X POST https://sender-worker-staging.integritystudio.ai/send \
  -H "Content-Type: application/json" \
  -d '{"userId":"staging-test","action":"signup"}'
```

---

### 2c. Production Setup

**Create Production wrangler Configuration**

Sender Worker (`workers/sender-worker/wrangler.toml`):
```toml
name = "sender-worker"
main = "src/index.ts"
compatibility_date = "2026-03-19"

[vars]
# Production receiver endpoint
RECEIVER_WORKER_URL = "https://receiver-worker.integritystudio.ai"

# Production CORS origin (Flutter web app)
# ALLOWED_ORIGINS_JSON = '["https://www.integritystudio.ai"]'
```

Receiver Worker (`workers/receiver-worker/wrangler.toml`):
```toml
name = "receiver-worker"
main = "src/index.ts"
compatibility_date = "2026-03-19"
```

**Set production secrets (CRITICAL)**

```bash
# Generate a NEW secret for production (different from staging/dev)
openssl rand -base64 32

# Sender Worker Production
cd workers/sender-worker
wrangler secret put SHARED_SECRET
# Paste production secret (NEW, NOT reused from staging)

# Receiver Worker Production (MUST BE IDENTICAL)
cd ../receiver-worker
wrangler secret put SHARED_SECRET
# Paste the SAME secret
```

**Backup secret securely**

```bash
# Store in password manager (1Password, Vault, etc.)
# Format:
#   Service: Cloudflare Sender/Receiver Worker
#   Secret: SHARED_SECRET value
#   Environment: Production
#   Date: 2026-03-20
#   Rotation Policy: Quarterly, after team turnover
```

**Deploy to production**

```bash
# Sender Worker
cd workers/sender-worker
wrangler deploy

# Receiver Worker
cd ../receiver-worker
wrangler deploy
```

**Verify production deployment (post-deploy checks)**

```bash
# 1. Health endpoint is accessible
curl https://receiver-worker.integritystudio.ai/health

# 2. CORS is configured correctly
curl -X OPTIONS https://sender-worker.integritystudio.ai/send \
  -H "Origin: https://www.integritystudio.ai" \
  -v
# Check for: Access-Control-Allow-Origin: https://www.integritystudio.ai

# 3. Signature verification works
curl -X POST https://sender-worker.integritystudio.ai/send \
  -H "Content-Type: application/json" \
  -d '{"userId":"prod-test","action":"verify"}' \
  -v

# 4. Invalid CORS origin is rejected
curl -X OPTIONS https://sender-worker.integritystudio.ai/send \
  -H "Origin: https://evil.example.com" \
  -v
# Should return 204 with NO CORS headers (or Content-Length: 0)
```

---

## Step 3: Flutter App Configuration

### Update Dart Provisioning Service

Update `lib/services/provisioning_service.dart`:

```dart
// Development
const _senderWorkerUrl = String.fromEnvironment(
  'SENDER_WORKER_URL',
  defaultValue: 'http://localhost:8787',  // Dev default
);

// OR set via --dart-define at build time:
// flutter run -d chrome --dart-define=SENDER_WORKER_URL=http://localhost:8787
// flutter build web --dart-define=SENDER_WORKER_URL=https://api-provisioning-sender.integritystudio.ai
```

### Build for Each Environment

**Development**
```bash
flutter run -d chrome \
  --dart-define=SENDER_WORKER_URL=http://localhost:8787
```

**Staging**
```bash
flutter build web \
  --dart-define=SENDER_WORKER_URL=https://api-provisioning-sender-staging.integritystudio.ai
```

**Production**
```bash
flutter build web \
  --dart-define=SENDER_WORKER_URL=https://api-provisioning-sender.integritystudio.ai
```

---

## Step 4: Monitoring & Health Checks

### Health Check Endpoints

```bash
# Receiver health (public endpoint, no auth required)
GET https://receiver-worker.integritystudio.ai/health
Response: {"ok":true,"service":"receiver-worker"}

# Sender health (internal, no endpoint exposed)
# Check via Cloudflare Analytics Dashboard
# Look for POST /send success rate
```

### Cloudflare Monitoring

**Set up alerts for:**
1. Error rate > 5% on `/send` endpoint
2. Error rate > 2% on `/inbox` endpoint
3. Request latency > 2 seconds (p95)

**View metrics:**
```bash
# Via Cloudflare dashboard
wrangler analytics https://analytics-engine-api.cloudflare.com/

# Via Logpush (if enabled)
# Configure to push logs to S3/GCS
```

---

## Step 5: Secret Rotation (Quarterly)

When rotating `SHARED_SECRET`:

### 1. Pre-Rotation (Day 1)
```bash
# Generate new secret
openssl rand -base64 32
# -> NEW_SECRET_VALUE

# Update staging first
cd workers/sender-worker
wrangler secret put SHARED_SECRET --env staging
# Paste NEW_SECRET_VALUE

cd ../receiver-worker
wrangler secret put SHARED_SECRET --env staging
# Paste NEW_SECRET_VALUE

# Deploy staging with new secret
wrangler deploy --env staging
```

### 2. Validation (Day 2)
```bash
# Test staging with new secret
curl -X POST https://sender-worker-staging.integritystudio.ai/send \
  -H "Content-Type: application/json" \
  -d '{"userId":"rotation-test","action":"verify"}'
```

### 3. Production Rotation (Day 3+)
```bash
# Update production
cd workers/sender-worker
wrangler secret put SHARED_SECRET
# Paste NEW_SECRET_VALUE

cd ../receiver-worker
wrangler secret put SHARED_SECRET
# Paste NEW_SECRET_VALUE

# Deploy production
wrangler deploy
```

### 4. Post-Rotation
- Update password manager with new secret
- Delete old secret from all locations
- Document rotation in audit log

---

## Troubleshooting

### Common Issues

**1. Signature Mismatch (401 invalid signature)**
```
Cause: SHARED_SECRET differs between sender and receiver
Fix: Verify secrets are identical on both workers
  wrangler secret list (shows secret names, not values)
  Regenerate and re-set both with same value
```

**2. Stale Timestamp (401 stale or invalid timestamp)**
```
Cause: Server clocks out of sync (>5 min drift)
Fix: Check NTP sync on origin servers
     Cloudflare handles NTP automatically, typically not an issue
```

**3. CORS Rejection (403 forbidden)**
```
Cause: Flutter app origin not in ALLOWED_ORIGINS_JSON
Fix: Update sender-worker vars:
  wrangler deploy --var ALLOWED_ORIGINS_JSON='["https://your-origin"]'
```

**4. Receiver Unreachable (502)**
```
Cause: RECEIVER_WORKER_URL incorrect or receiver not deployed
Fix: Verify URL in sender-worker wrangler.toml
     Check receiver is deployed: curl https://receiver-url/health
```

---

## Deployment Checklist

- [ ] **Development**
  - [ ] `.env.local` files created (git-ignored)
  - [ ] Both workers running locally (`wrangler dev`)
  - [ ] E2E tests pass (`npm test`)
  - [ ] Flutter app connects via `http://localhost:8787`

- [ ] **Staging**
  - [ ] Wrangler configured with staging environment
  - [ ] SHARED_SECRET set identically on both workers
  - [ ] Both workers deployed
  - [ ] Health endpoint responds
  - [ ] CORS headers correct for `staging.integritystudio.ai`
  - [ ] E2E tests pass against staging

- [ ] **Production**
  - [ ] NEW SHARED_SECRET generated (not reused from staging)
  - [ ] Secrets set identically on both workers
  - [ ] Both workers deployed
  - [ ] Health endpoint responds
  - [ ] CORS headers correct for `www.integritystudio.ai`
  - [ ] Canary test passed (test with 1% of requests)
  - [ ] Monitoring alerts configured
  - [ ] Secret backed up securely
  - [ ] Rollback procedure documented

---

## References

- [API Provisioning Architecture](api-provisioning.md)
- [Client Contract](api-provisioning-contract.md)
- [Inter-Worker Contract Validation](inter-worker-contract-validation.md)
- [Cloudflare Secrets Management](https://developers.cloudflare.com/workers/configuration/secrets/)
- [Cloudflare Environments](https://developers.cloudflare.com/workers/wrangler/environments/)
- [Test Provisioning E2E](../test-provisioning-e2e.sh)

---

## Support

For issues or questions:
1. Check [Troubleshooting](#troubleshooting) section
2. Review Cloudflare worker logs: `wrangler tail`
3. Verify secret synchronization: `wrangler secret list`
4. Run E2E tests: `bash test-provisioning-e2e.sh`
