#!/bin/bash
# Deploy API Provisioning Workers (Sender & Receiver)
# Supports development, staging, and production environments
#
# Usage:
#   ./scripts/deploy-provisioning-workers.sh dev
#   ./scripts/deploy-provisioning-workers.sh staging
#   ./scripts/deploy-provisioning-workers.sh prod
#
# This script will:
# 1. Validate environment and tools
# 2. Prompt for configuration (secrets, URLs)
# 3. Deploy both sender and receiver workers
# 4. Run health checks
# 5. Display summary

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Configuration
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
WORKERS_DIR="$PROJECT_ROOT/workers"

# Environment from argument
ENVIRONMENT="${1:-}"

# Helper functions
log_info() {
  echo -e "${BLUE}ℹ${NC} $*"
}

log_success() {
  echo -e "${GREEN}✓${NC} $*"
}

log_warn() {
  echo -e "${YELLOW}⚠${NC} $*"
}

log_error() {
  echo -e "${RED}✗${NC} $*"
}

print_header() {
  echo ""
  echo -e "${BLUE}═══════════════════════════════════════${NC}"
  echo -e "${BLUE}$1${NC}"
  echo -e "${BLUE}═══════════════════════════════════════${NC}"
}

# Validate environment argument
if [ -z "$ENVIRONMENT" ]; then
  log_error "Environment not specified"
  echo ""
  echo "Usage: $0 <dev|staging|prod>"
  echo ""
  echo "Examples:"
  echo "  $0 dev      # Local development"
  echo "  $0 staging  # Staging environment"
  echo "  $0 prod     # Production"
  exit 1
fi

if [[ ! "$ENVIRONMENT" =~ ^(dev|staging|prod)$ ]]; then
  log_error "Invalid environment: $ENVIRONMENT (must be dev, staging, or prod)"
  exit 1
fi

# Validate prerequisites
print_header "Validating Prerequisites"

if ! command -v wrangler &> /dev/null; then
  log_error "wrangler not found. Install with: npm install -g wrangler"
  exit 1
fi
log_success "wrangler found: $(wrangler --version)"

if ! command -v openssl &> /dev/null; then
  log_error "openssl not found. Install with: brew install openssl"
  exit 1
fi
log_success "openssl found"

if [ ! -d "$WORKERS_DIR/sender-worker" ]; then
  log_error "sender-worker directory not found at $WORKERS_DIR/sender-worker"
  exit 1
fi
log_success "sender-worker found"

if [ ! -d "$WORKERS_DIR/receiver-worker" ]; then
  log_error "receiver-worker directory not found at $WORKERS_DIR/receiver-worker"
  exit 1
fi
log_success "receiver-worker found"

# Environment-specific configuration
print_header "Environment Configuration"

case "$ENVIRONMENT" in
  dev)
    log_info "Development setup (local with wrangler dev)"
    SENDER_NAME="sender-worker"
    RECEIVER_NAME="receiver-worker"
    SENDER_PORT=8787
    RECEIVER_PORT=8788
    RECEIVER_URL="http://localhost:$RECEIVER_PORT"
    CORS_ORIGINS="http://localhost:8081"
    IS_DEPLOYMENT=false
    ;;
  staging)
    log_info "Staging environment"
    SENDER_NAME="sender-worker-staging"
    RECEIVER_NAME="receiver-worker-staging"
    RECEIVER_URL="https://receiver-worker-staging.integritystudio.ai"
    CORS_ORIGINS="https://staging.integritystudio.ai"
    IS_DEPLOYMENT=true
    ;;
  prod)
    log_info "Production environment"
    SENDER_NAME="sender-worker"
    RECEIVER_NAME="receiver-worker"
    RECEIVER_URL="https://receiver-worker.integritystudio.ai"
    CORS_ORIGINS="https://www.integritystudio.ai"
    IS_DEPLOYMENT=true
    ;;
esac

echo ""
echo "Environment: $ENVIRONMENT"
echo "Sender: $SENDER_NAME"
echo "Receiver: $RECEIVER_NAME"
echo "Receiver URL: $RECEIVER_URL"
echo "CORS Origins: $CORS_ORIGINS"

# Secret handling
print_header "Secret Management"

if [ "$ENVIRONMENT" = "dev" ]; then
  log_info "Using test secret for development"
  SHARED_SECRET="test-secret-key-12345"
  log_warn "This is NOT a secure secret. Use only for local development."
else
  log_info "Checking for existing secret in wrangler..."

  read -p "Has the SHARED_SECRET already been set on both workers? (y/n) " -n 1 -r
  echo ""

  if [[ $REPLY =~ ^[Yy]$ ]]; then
    log_info "Skipping secret creation (assuming already set)"
    SHARED_SECRET="[existing secret]"
  else
    log_info "Generating new SHARED_SECRET..."
    SHARED_SECRET=$(openssl rand -base64 32)

    echo ""
    echo -e "${YELLOW}Generated SHARED_SECRET (save this securely):${NC}"
    echo ""
    echo "  $SHARED_SECRET"
    echo ""

    log_warn "You must set this secret on BOTH workers before deployment:"
    echo ""
    echo "  Sender Worker:"
    echo "    cd $WORKERS_DIR/sender-worker"
    echo "    wrangler secret put SHARED_SECRET"
    echo "    # Paste: $SHARED_SECRET"
    echo ""
    echo "  Receiver Worker:"
    echo "    cd $WORKERS_DIR/receiver-worker"
    echo "    wrangler secret put SHARED_SECRET"
    echo "    # Paste: $SHARED_SECRET (MUST BE IDENTICAL)"
    echo ""

    read -p "Press Enter once secrets are set on both workers..."
  fi
fi

# Deployment
if [ "$IS_DEPLOYMENT" = true ]; then
  print_header "Deploying to Cloudflare"

  log_info "Deploying Receiver Worker..."
  cd "$WORKERS_DIR/receiver-worker"
  wrangler deploy
  log_success "Receiver Worker deployed"

  log_info "Deploying Sender Worker..."
  cd "$WORKERS_DIR/sender-worker"

  # Deploy with CORS origins
  CORS_JSON=$(jq -c -n --arg origins "$CORS_ORIGINS" '[($origins | split(",") | .[])]')
  wrangler deploy --var "ALLOWED_ORIGINS_JSON=$CORS_JSON"
  log_success "Sender Worker deployed"
else
  print_header "Local Development Setup"

  log_info "For local development, start both workers in separate terminals:"
  echo ""
  echo "Terminal 1 - Receiver:"
  echo "  cd $WORKERS_DIR/receiver-worker"
  echo "  wrangler dev --port $RECEIVER_PORT"
  echo ""
  echo "Terminal 2 - Sender:"
  echo "  cd $WORKERS_DIR/sender-worker"
  echo "  wrangler dev --port $SENDER_PORT"
  echo ""
fi

# Health checks
print_header "Health Checks"

if [ "$IS_DEPLOYMENT" = true ]; then
  log_info "Testing Receiver Worker health endpoint..."

  HEALTH_RESPONSE=$(curl -s "$RECEIVER_URL/health" || echo "")

  if echo "$HEALTH_RESPONSE" | grep -q '"ok":true'; then
    log_success "Receiver health check passed"
  else
    log_warn "Receiver health check failed or timed out"
    log_info "Response: $HEALTH_RESPONSE"
  fi
else
  log_info "After starting workers, test with:"
  echo ""
  echo "  curl http://localhost:8788/health"
  echo "  curl -X POST http://localhost:8787/send \\"
  echo "    -H 'Content-Type: application/json' \\"
  echo "    -d '{\"userId\":\"test\",\"action\":\"verify\"}'"
  echo ""
fi

# Summary
print_header "Deployment Summary"

echo ""
echo "Configuration:"
echo "  Environment: $ENVIRONMENT"
echo "  Sender Worker: $SENDER_NAME"
echo "  Receiver Worker: $RECEIVER_NAME"
echo "  Receiver URL: $RECEIVER_URL"
echo "  CORS Origins: $CORS_ORIGINS"
echo "  Shared Secret: $([ "$SHARED_SECRET" = "[existing secret]" ] && echo "Set via wrangler" || echo "Generated")"
echo ""

if [ "$IS_DEPLOYMENT" = true ]; then
  log_success "Deployment completed successfully"
  echo ""
  echo "Next steps:"
  echo "  1. Verify workers are operational:"
  echo "     curl $RECEIVER_URL/health"
  echo ""
  echo "  2. Update Flutter app with Sender Worker URL"
  echo "  3. Run end-to-end tests"
  echo "  4. Configure monitoring and alerts"
  echo ""
else
  log_success "Development environment configured"
  echo ""
  echo "Next steps:"
  echo "  1. Start both workers (see instructions above)"
  echo "  2. Update Flutter to use http://localhost:8787"
  echo "  3. Run: npm test"
  echo ""
fi

echo -e "${BLUE}═══════════════════════════════════════${NC}"
echo ""

log_success "Done!"
