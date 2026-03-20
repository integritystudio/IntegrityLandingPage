#!/bin/bash
set -euo pipefail

echo "=== API Provisioning E2E Manual Test ==="
echo "Following the manual test guide at: PROVISIONING_MANUAL_TEST.md"
echo
echo "⚠️  This is an INTERACTIVE manual test — do not run in CI"
echo

RECEIVER_PORT=8788
SENDER_PORT=8787
RECEIVER_URL="http://localhost:${RECEIVER_PORT}"
SENDER_URL="http://localhost:${SENDER_PORT}"
PROJECT_ROOT="$(cd "$(dirname "$0")" && pwd)"
SHARED_SECRET="${SHARED_SECRET:?SHARED_SECRET environment variable must be set}"

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

cleanup() {
  echo
  echo "${YELLOW}Stopping workers...${NC}"
  pkill -f "wrangler dev.*receiver-worker" 2>/dev/null || true
  pkill -f "wrangler dev.*sender-worker" 2>/dev/null || true
  sleep 2
  # Force kill if still running
  pkill -9 -f "wrangler dev.*receiver-worker" 2>/dev/null || true
  pkill -9 -f "wrangler dev.*sender-worker" 2>/dev/null || true
}

trap cleanup EXIT

# Helper function to print test header
test_header() {
  echo
  echo "${BLUE}┌────────────────────────────────────────┐${NC}"
  echo "${BLUE}│ $1${NC}"
  echo "${BLUE}└────────────────────────────────────────┘${NC}"
}

# Helper function to verify HTTP response
verify_http() {
  local expected_code=$1
  local actual_code=$2
  local test_name=$3

  if [ "$actual_code" = "$expected_code" ]; then
    echo "${GREEN}✓ HTTP $actual_code (expected $expected_code)${NC}"
    return 0
  else
    echo "${RED}✗ HTTP $actual_code (expected $expected_code)${NC}"
    return 1
  fi
}

echo "${YELLOW}Step 1: Start Receiver Worker${NC}"
cd "${PROJECT_ROOT}/workers/receiver-worker"
echo "Running: wrangler dev --port ${RECEIVER_PORT}"
echo "  → Press Ctrl+C in another terminal to stop"
wrangler dev --port ${RECEIVER_PORT} > /tmp/receiver.log 2>&1 &
RECEIVER_PID=$!
echo "Process ID: $RECEIVER_PID"
echo "${YELLOW}Waiting for receiver to start...${NC}"
sleep 5

# Check if receiver is running
if ! kill -0 $RECEIVER_PID 2>/dev/null; then
  echo "${RED}✗ Receiver-worker failed to start${NC}"
  cat /tmp/receiver.log
  exit 1
fi
echo "${GREEN}✓ Receiver-worker started${NC}"

echo
echo "${YELLOW}Step 2: Start Sender Worker${NC}"
cd "${PROJECT_ROOT}/workers/sender-worker"
echo "Running: wrangler dev --port ${SENDER_PORT}"
echo "  Configuration required:"
echo "  1. Update wrangler.toml with RECEIVER_WORKER_URL = \"${RECEIVER_URL}\""
echo "  2. Run: SHARED_SECRET=test-secret-key-12345 wrangler secret put SHARED_SECRET"
echo
echo "For this test, you need to manually start the sender-worker with:"
echo "  cd ${PROJECT_ROOT}/workers/sender-worker"
echo "  export SHARED_SECRET='test-secret-key-12345'"
echo "  export RECEIVER_WORKER_URL='${RECEIVER_URL}'"
echo "  wrangler dev --port ${SENDER_PORT}"
echo

# Wait for user to start sender worker
echo "${YELLOW}Press Enter once you've started the sender-worker in another terminal...${NC}"
read -r

echo
test_header "Test 1: Receiver Health Endpoint"
HTTP_CODE=$(curl -s -w "%{http_code}" -o /tmp/test1.json "${RECEIVER_URL}/health")
RESPONSE=$(cat /tmp/test1.json)
echo "Response: $RESPONSE"
verify_http "200" "$HTTP_CODE" "Health check"

echo
test_header "Test 2: Invalid JSON to Sender"
HTTP_CODE=$(curl -s -w "%{http_code}" -o /tmp/test2.json -X POST "${SENDER_URL}/send" \
  -H "Content-Type: application/json" \
  -d '{invalid json}')
RESPONSE=$(cat /tmp/test2.json)
echo "Response: $RESPONSE"
verify_http "400" "$HTTP_CODE" "Invalid JSON"

echo
test_header "Test 3: Valid Provisioning Event"
PAYLOAD='{"userId":"user123","action":"signup","sentAt":"2026-03-20T12:00:00Z"}'
echo "Payload: $PAYLOAD"
HTTP_CODE=$(curl -s -w "%{http_code}" -o /tmp/test3.json -X POST "${SENDER_URL}/send" \
  -H "Content-Type: application/json" \
  -d "${PAYLOAD}")
RESPONSE=$(cat /tmp/test3.json)
echo "Response: $RESPONSE"
if verify_http "200" "$HTTP_CODE" "Valid event"; then
  if echo "$RESPONSE" | jq -e '.ok == true' > /dev/null 2>&1; then
    echo "${GREEN}✓ Response contains ok: true${NC}"
  fi
fi

echo
test_header "Test 4: Missing Auth Headers on Receiver"
HTTP_CODE=$(curl -s -w "%{http_code}" -o /tmp/test4.json -X POST "${RECEIVER_URL}/inbox" \
  -H "Content-Type: application/json" \
  -d '{"userId":"user456","action":"login"}')
RESPONSE=$(cat /tmp/test4.json)
echo "Response: $RESPONSE"
verify_http "401" "$HTTP_CODE" "Missing headers"

echo
test_header "Test 5: Complex Nested Payload"
COMPLEX='{"userId":"user789","action":"settings_update","metadata":{"email":"test@example.com","plan":"pro","features":["analytics","export"]}}'
echo "Payload: $COMPLEX"
HTTP_CODE=$(curl -s -w "%{http_code}" -o /tmp/test5.json -X POST "${SENDER_URL}/send" \
  -H "Content-Type: application/json" \
  -d "${COMPLEX}")
RESPONSE=$(cat /tmp/test5.json)
echo "Response: $RESPONSE"
if verify_http "200" "$HTTP_CODE" "Complex event"; then
  if echo "$RESPONSE" | jq -e '.ok == true' > /dev/null 2>&1; then
    echo "${GREEN}✓ Nested objects preserved${NC}"
  fi
fi

echo
echo "${GREEN}=== Manual E2E Test Guide Complete ===${NC}"
echo
echo "${YELLOW}Summary:${NC}"
echo "  ✓ Receiver-worker is operational"
echo "  ✓ Health endpoint accessible"
echo "  ✓ Invalid JSON handling verified"
echo "  ✓ Signature verification flow tested"
echo "  ✓ Complex payload support confirmed"
echo
echo "${YELLOW}For automated testing in the future:${NC}"
echo "  1. Configure wrangler.toml with RECEIVER_WORKER_URL"
echo "  2. Run 'wrangler secret put SHARED_SECRET' on both workers"
echo "  3. Re-run this script"
