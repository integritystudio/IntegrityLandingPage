#!/usr/bin/env bash
# check-api-routing.sh — sync guard for docs/api-routing.md (BACKLOG.md CR31)
#
# Three assertions, all runnable in CI without Cloudflare credentials:
#
#   1. Every API-subdomain host advertised in lib/**/*.dart resolves via DNS.
#      Two of the four original CR31 defects were NXDOMAIN — a route-table
#      comparison alone would have missed them.
#
#   2. Every API-subdomain URL advertised in lib/**/*.dart appears in
#      docs/api-routing.md. Catches a URL added to docs without a doc update.
#      Pattern is anchored on `https?://` so sandbox-api.* stays distinct from
#      api.* — the un-anchored form merged them and hid the status.* defect.
#
#   3. workers/api-gateway/wrangler.toml must not claim a top-level `routes`
#      key without also setting `routes = []` under [env.dev]. Omitting the
#      dev override inherits production routes, which handed
#      api.integritystudio.ai/v1/* to the secret-less api-gateway-dev on
#      2026-07-27. Overlaps deploy-environments.test.ts deliberately.
#
# Probing live routes requires zone-read credentials (the dev token 403s by
# design — that denial is CR13's protection). Keep live probes in the document's
# "Keeping this in sync" section, not here.
#
# Usage:
#   bash scripts/check-api-routing.sh           # from repo root
#   npm run check:api-routing

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

DOC="$REPO_ROOT/docs/api-routing.md"
TOML="$REPO_ROOT/workers/api-gateway/wrangler.toml"

FAIL=0
pass() { echo "  PASS: $*"; }
fail() { echo "  FAIL: $*"; FAIL=1; }

# ---------------------------------------------------------------------------
# Extract API-subdomain URLs from lib/**/*.dart
# Only check hosts with a subdomain prefix (api., ingest., sandbox-api., etc.)
# Skip the main domain (integritystudio.ai without a subdomain) — those are
# internal app routes, not external API calls that need DNS verification.
# ---------------------------------------------------------------------------

ALL_URLS=$(grep -rhoE "https?://[a-z0-9.-]*integritystudio\.ai[a-zA-Z0-9/{}:_.%-]*" \
  "$REPO_ROOT/lib/" --include='*.dart' 2>/dev/null | sort -u)

# Filter to subdomain URLs — hosts like api.integritystudio.ai, ingest.integritystudio.ai.
# Exclude the bare main domain (integritystudio.ai without a subdomain) since those are
# internal app routes, not external API calls that need DNS verification.
API_URLS=$(echo "$ALL_URLS" | grep -E "https?://[a-z0-9-]+\.integritystudio\.ai" || true)

if [ -z "$API_URLS" ]; then
  echo "check-api-routing.sh: no API-subdomain URLs found in lib/ — nothing to check"
  exit 0
fi

echo "API-subdomain URLs found in lib/**/*.dart:"
echo "$API_URLS" | sed 's/^/  /'
echo ""

# Distinct hosts (strip scheme with -E so `?` is interpreted as ERE quantifier)
API_HOSTS=$(echo "$API_URLS" | grep -oE "https?://[a-z0-9.-]+" | sed -E 's|https?://||' | sort -u)

# ---------------------------------------------------------------------------
# Check 1: DNS resolution
# ---------------------------------------------------------------------------
echo "=== Check 1: DNS resolution ==="
while IFS= read -r host; do
  result=$(dig +short "$host" A 2>/dev/null | grep -v '^;' | head -1 || true)
  if [ -z "$result" ]; then
    fail "$host does not resolve — NXDOMAIN or no A record; add DNS or remove from docs"
  else
    pass "$host -> $result"
  fi
done <<< "$API_HOSTS"

# ---------------------------------------------------------------------------
# Check 2: Every API-subdomain URL appears in api-routing.md
# ---------------------------------------------------------------------------
echo ""
echo "=== Check 2: API routing doc coverage ==="

if [ ! -f "$DOC" ]; then
  fail "$DOC not found — cannot verify advertised URLs; create or restore it"
else
  while IFS= read -r url; do
    # Check if the doc mentions the URL in any form:
    #   - full bare URL without scheme: api.integritystudio.ai/v1/traces
    #   - path only:                    /v1/traces
    # The table may use either form depending on context.
    bare="${url#https://}"
    bare="${bare#http://}"
    path="/${bare#*/}"    # everything after the first slash, including leading /
    # If URL has no path component (bare host only), path == the full bare
    if [ "$path" = "/$bare" ]; then path=""; fi

    if grep -qF "$bare" "$DOC" || { [ -n "$path" ] && grep -qF "$path" "$DOC"; }; then
      pass "$url found in api-routing.md"
    else
      fail "$url is in lib/**/*.dart but not in $DOC"
      echo "        Add it to the 'What the documentation advertises' table and mark its status."
    fi
  done <<< "$API_URLS"
fi

# ---------------------------------------------------------------------------
# Check 3: api-gateway wrangler.toml routes safety
# ---------------------------------------------------------------------------
echo ""
echo "=== Check 3: api-gateway routes safety ==="

if [ ! -f "$TOML" ]; then
  fail "$TOML not found"
else
  # Only lines BEFORE the first [section] header are top-level.
  # Read until the first line starting with `[`, then check if routes appeared.
  has_toplevel_routes=$(awk '/^\[/{exit} /^routes[[:space:]]*=/{print "yes"; exit}' "$TOML")
  if [ "$has_toplevel_routes" = "yes" ]; then
    # Production has routes — [env.dev] must explicitly empty them.
    # Look for `routes = []` in the [env.dev] block (stops at next unrelated section).
    has_dev_empty_routes=$(awk '
      /^\[env\.dev\]/{in_dev=1; next}
      in_dev && /^\[[^e]/{exit}
      in_dev && /^routes[[:space:]]*=[[:space:]]*\[\]/{print "yes"; exit}
    ' "$TOML")
    if [ "$has_dev_empty_routes" = "yes" ]; then
      pass "$TOML has top-level routes and routes=[] under [env.dev]"
    else
      fail "$TOML has top-level routes but [env.dev] does not set routes=[] — see CR13: this hands production routes to the dev worker"
    fi
  else
    pass "$TOML has no top-level routes key"
  fi
fi

# ---------------------------------------------------------------------------
echo ""
if [ "$FAIL" -ne 0 ]; then
  echo "check-api-routing.sh FAILED"
  exit 1
fi
echo "check-api-routing.sh PASSED"
