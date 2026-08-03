#!/bin/bash
set -euo pipefail

echo "=== API Provisioning E2E (sender-worker, local) ==="
echo
echo "Architecture note:"
echo "  The production receiver is 'api-provisioning-receiver' (in the separate"
echo "  observability-toolkit repo). sender-worker reaches it via a [[services]]"
echo "  binding (RECEIVER -> api-provisioning-receiver), NOT an HTTP URL."
echo "  This script starts sender-worker locally and exercises its self-contained"
echo "  validation/routing surface (paths that are rejected before forwarding)."
echo "  The full provision_api_key / sign_in forwarding happy-path requires the"
echo "  receiver binding + Auth0/Supabase secrets and is NOT covered here."
echo

SENDER_PORT="${SENDER_PORT:-8787}"
SENDER_URL="http://localhost:${SENDER_PORT}"
PROJECT_ROOT="$(cd "$(dirname "$0")" && pwd)"
SENDER_DIR="${PROJECT_ROOT}/workers/sender-worker"
DEV_VARS="${SENDER_DIR}/.dev.vars"

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

DEV_VARS_CREATED=0
SENDER_PID=""

cleanup() {
  echo
  echo "${YELLOW}Stopping sender-worker...${NC}"
  [ -n "$SENDER_PID" ] && kill "$SENDER_PID" 2>/dev/null || true
  pkill -f "wrangler dev.*sender-worker" 2>/dev/null || true
  sleep 1
  pkill -9 -f "wrangler dev.*sender-worker" 2>/dev/null || true
  # Only remove .dev.vars if this script created it
  [ "$DEV_VARS_CREATED" = "1" ] && rm -f "$DEV_VARS" || true
}
trap cleanup EXIT

test_header() {
  echo
  echo "${BLUE}┌────────────────────────────────────────┐${NC}"
  echo "${BLUE}│ $1${NC}"
  echo "${BLUE}└────────────────────────────────────────┘${NC}"
}

FAILURES=0
verify_http() {
  local expected_code=$1
  local actual_code=$2
  if [ "$actual_code" = "$expected_code" ]; then
    echo "${GREEN}✓ HTTP $actual_code (expected $expected_code)${NC}"
  else
    echo "${RED}✗ HTTP $actual_code (expected $expected_code)${NC}"
    FAILURES=$((FAILURES + 1))
  fi
}

# Local dev secrets. No signing credential is strictly required by the assertions below:
# handleSend's only pre-flight is the RECEIVER binding (from wrangler.toml), and every case
# here is rejected by schema validation before any forward, so the key is never resolved.
# They are set anyway to mirror a working config -- since CR29 step 2 the sender signs with
# SIGNING_KEYS[ACTIVE_KEY_ID] and fails closed (500 SIGNING_KEY_UNRESOLVED, forwarding
# nothing) rather than falling back, so a suite that did reach a forward would need them.
if [ ! -f "$DEV_VARS" ]; then
  echo "${YELLOW}Creating temporary ${DEV_VARS} for local dev...${NC}"
  cat > "$DEV_VARS" << 'EOF'
SIGNING_KEYS={"v2":"test-secret-key-12345"}
ACTIVE_KEY_ID=v2
EOF
  DEV_VARS_CREATED=1
fi

echo "${YELLOW}Starting sender-worker (wrangler dev --port ${SENDER_PORT})...${NC}"
cd "$SENDER_DIR"
wrangler dev --port "${SENDER_PORT}" > /tmp/sender.log 2>&1 &
SENDER_PID=$!

echo "${YELLOW}Waiting for sender-worker to become ready...${NC}"
READY=0
for _ in $(seq 1 30); do
  if curl -fsS "${SENDER_URL}/health" > /dev/null 2>&1; then
    READY=1
    break
  fi
  if ! kill -0 "$SENDER_PID" 2>/dev/null; then
    echo "${RED}✗ sender-worker exited during startup${NC}"
    cat /tmp/sender.log
    exit 1
  fi
  sleep 1
done
if [ "$READY" != "1" ]; then
  echo "${RED}✗ sender-worker did not become ready in time${NC}"
  cat /tmp/sender.log
  exit 1
fi
echo "${GREEN}✓ sender-worker is up${NC}"

test_header "Test 1: Health endpoint"
HTTP_CODE=$(curl -s -w "%{http_code}" -o /tmp/test1.json "${SENDER_URL}/health")
RESPONSE=$(cat /tmp/test1.json)
echo "Response: $RESPONSE"
verify_http "200" "$HTTP_CODE"
if echo "$RESPONSE" | jq -e '.service == "api-provisioning-sender"' > /dev/null 2>&1; then
  echo "${GREEN}✓ service == api-provisioning-sender${NC}"
else
  echo "${RED}✗ unexpected service identifier${NC}"
  FAILURES=$((FAILURES + 1))
fi

test_header "Test 2: Invalid JSON to /send → 400"
HTTP_CODE=$(curl -s -w "%{http_code}" -o /tmp/test2.json -X POST "${SENDER_URL}/send" \
  -H "Content-Type: application/json" \
  -d '{invalid json}')
echo "Response: $(cat /tmp/test2.json)"
verify_http "400" "$HTTP_CODE"

test_header "Test 3: Unknown action to /send → 400"
HTTP_CODE=$(curl -s -w "%{http_code}" -o /tmp/test3.json -X POST "${SENDER_URL}/send" \
  -H "Content-Type: application/json" \
  -d '{"action":"bogus"}')
echo "Response: $(cat /tmp/test3.json)"
verify_http "400" "$HTTP_CODE"

test_header "Test 4: sign_in to /send without JWT → 401"
HTTP_CODE=$(curl -s -w "%{http_code}" -o /tmp/test4.json -X POST "${SENDER_URL}/send" \
  -H "Content-Type: application/json" \
  -d '{"action":"sign_in","email":"user@example.com"}')
echo "Response: $(cat /tmp/test4.json)"
verify_http "401" "$HTTP_CODE"

test_header "Test 5: /signup missing email/password → 400"
HTTP_CODE=$(curl -s -w "%{http_code}" -o /tmp/test5.json -X POST "${SENDER_URL}/signup" \
  -H "Content-Type: application/json" \
  -d '{}')
echo "Response: $(cat /tmp/test5.json)"
verify_http "400" "$HTTP_CODE"

test_header "Test 6: /signup invalid email format → 400"
HTTP_CODE=$(curl -s -w "%{http_code}" -o /tmp/test6.json -X POST "${SENDER_URL}/signup" \
  -H "Content-Type: application/json" \
  -d '{"email":"not-an-email","password":"hunter2hunter2"}')
echo "Response: $(cat /tmp/test6.json)"
verify_http "400" "$HTTP_CODE"

test_header "Test 7: Unknown route → 404"
HTTP_CODE=$(curl -s -w "%{http_code}" -o /tmp/test7.json -X POST "${SENDER_URL}/nope" \
  -H "Content-Type: application/json" -d '{}')
echo "Response: $(cat /tmp/test7.json)"
verify_http "404" "$HTTP_CODE"

echo
if [ "$FAILURES" = "0" ]; then
  echo "${GREEN}=== All sender-worker validation checks passed ===${NC}"
else
  echo "${RED}=== ${FAILURES} check(s) failed ===${NC}"
fi

echo
echo "${YELLOW}Not covered here (require the receiver + Auth0/Supabase):${NC}"
echo "  - POST /send  {action: provision_api_key | sign_in} happy-path forwarding"
echo "  - POST /signup full Auth0 ROPC + Supabase user/org creation"
echo "  For those, run the sender-worker integration/live suites:"
echo "    cd workers/sender-worker && npm run test:e2e   # doppler dev config"
echo "    cd workers/sender-worker && npm run test:live  # real staging HTTP"
echo "  and deploy/verify the receiver from the observability-toolkit repo."

exit "$FAILURES"
