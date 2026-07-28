#!/usr/bin/env bash
#
# Verify that the Doppler `dev` config is actually a separate environment from
# `prd` (BACKLOG.md CR11).
#
# On 2026-07-27 every credential below was byte-identical between the two
# configs, so `--config dev` selected the production Supabase project and the
# production Auth0 tenant. Documentation claimed the opposite ("E2E tests use
# --config dev (isolated from prod)"), and nothing detected the drift.
#
# This script is that detector. It compares hashes only — no secret value is
# printed, so it is safe to run in CI and paste output into a ticket.
#
# Usage:
#   bash scripts/check-env-isolation.sh            # compare dev vs prd
#   BASE_CONFIG=stg bash scripts/check-env-isolation.sh
#
# Exit codes:
#   0  every credential differs between the two configs
#   1  at least one is shared, empty in both, or missing — not isolated
#   2  prerequisites missing (doppler CLI, or not logged in)

set -uo pipefail

PROJECT="${DOPPLER_PROJECT:-integrity-studio}"
BASE_CONFIG="${BASE_CONFIG:-dev}"
PROD_CONFIG="${PROD_CONFIG:-prd}"

# Credentials that must differ for the environments to be meaningfully separate.
# Each one, if shared, means a dev-config process reads or writes production
# state: the database, the identity tenant, or the inter-worker trust boundary.
SECRETS=(
  SUPABASE_URL
  SUPABASE_SERVICE_ROLE_KEY
  SUPABASE_ANON_KEY
  SUPABASE_JWT_SECRET
  AUTH0_DOMAIN
  AUTH0_CLIENT_ID
  AUTH0_CLIENT_SECRET
  AUTH0_CLI_ID
  AUTH0_CLI_SECRET
  SHARED_SECRET
  STRIPE_SECRET_KEY
  STRIPE_API_KEY
  STRIPE_WEBHOOK_SECRET
)

# Stripe needs a second, stronger check, and the reason is worth stating.
#
# On 2026-07-28 `dev`'s STRIPE_SECRET_KEY held a `pk_live_` key belonging to the
# PRODUCTION Stripe account. It differed from prd's value, so the hash
# comparison above would have called it "ok (distinct)" — while it pointed
# straight at production. Distinctness is necessary but not sufficient.
#
# Stripe encodes the mode in the key prefix, so we can assert it directly: dev
# must hold test-mode keys, prd must hold live-mode keys. A prefix is a type
# marker, not secret material, so printing it is safe.
#
# STRIPE_WEBHOOK_SECRET is deliberately absent here — `whsec_` carries no mode
# marker, so it can only be checked for distinctness. Its isolation rests on the
# two endpoints living on different accounts.
STRIPE_MODED_KEYS=(
  STRIPE_SECRET_KEY
  STRIPE_API_KEY
)
LIVE_KEY_RE='^(sk|rk|pk)_live_'
TEST_KEY_RE='^(sk|rk|pk)_test_'

command -v doppler >/dev/null 2>&1 || { echo "doppler CLI not installed"; exit 2; }
doppler me >/dev/null 2>&1 || { echo "doppler not authenticated — run 'doppler login'"; exit 2; }

# SHA-1 of the empty string: distinguishes "unset in both" from "same value".
EMPTY_HASH="da39a3ee5e6b4b0d3255bfef95601890afd80709"

digest() {
  doppler secrets get "$1" --project "$PROJECT" --config "$2" --plain 2>/dev/null | shasum | cut -d' ' -f1
}

# Emits only the key-type prefix (e.g. `sk_live_`), never the key body.
key_prefix() {
  doppler secrets get "$1" --project "$PROJECT" --config "$2" --plain 2>/dev/null \
    | tr -d '\n' | grep -oE '^(sk|rk|pk)_(live|test)_' || printf '(none)'
}

printf '%-30s %-10s %-10s %s\n' "SECRET" "$BASE_CONFIG" "$PROD_CONFIG" "VERDICT"
printf '%s\n' "----------------------------------------------------------------------"

failures=0
for secret in "${SECRETS[@]}"; do
  base_hash="$(digest "$secret" "$BASE_CONFIG")"
  prod_hash="$(digest "$secret" "$PROD_CONFIG")"

  if [[ "$base_hash" == "$EMPTY_HASH" && "$prod_hash" == "$EMPTY_HASH" ]]; then
    verdict="UNSET in both"; ((failures++))
  elif [[ "$base_hash" == "$EMPTY_HASH" ]]; then
    verdict="missing in $BASE_CONFIG"; ((failures++))
  elif [[ "$base_hash" == "$prod_hash" ]]; then
    verdict="SHARED WITH PRODUCTION"; ((failures++))
  else
    verdict="ok (distinct)"
  fi

  printf '%-30s %-10s %-10s %s\n' "$secret" "${base_hash:0:8}" "${prod_hash:0:8}" "$verdict"
done

echo
printf '%-30s %-14s %-14s %s\n' "STRIPE KEY MODE" "$BASE_CONFIG" "$PROD_CONFIG" "VERDICT"
printf '%s\n' "----------------------------------------------------------------------"

for secret in "${STRIPE_MODED_KEYS[@]}"; do
  base_prefix="$(key_prefix "$secret" "$BASE_CONFIG")"
  prod_prefix="$(key_prefix "$secret" "$PROD_CONFIG")"

  if [[ "$base_prefix" =~ $LIVE_KEY_RE ]]; then
    verdict="$BASE_CONFIG HOLDS A LIVE KEY"; ((failures++))
  elif [[ "$prod_prefix" =~ $TEST_KEY_RE ]]; then
    verdict="$PROD_CONFIG holds a TEST key"; ((failures++))
  elif [[ "$base_prefix" == "(none)" || "$prod_prefix" == "(none)" ]]; then
    verdict="unset or unrecognised prefix"; ((failures++))
  elif [[ "$base_prefix" =~ $TEST_KEY_RE && "$prod_prefix" =~ $LIVE_KEY_RE ]]; then
    verdict="ok (test in $BASE_CONFIG, live in $PROD_CONFIG)"
  else
    verdict="unexpected combination"; ((failures++))
  fi

  printf '%-30s %-14s %-14s %s\n' "$secret" "$base_prefix" "$prod_prefix" "$verdict"
done

echo
if (( failures > 0 )); then
  cat <<EOF
FAIL: $failures check(s) failed across ${#SECRETS[@]} credentials and
${#STRIPE_MODED_KEYS[@]} Stripe mode assertions.

'--config $BASE_CONFIG' is not a safety boundary. Anything run against it
reads and writes production state. Do not push these values into the *-dev
workers — that yields a second production-capable worker, not a dev
environment. See BACKLOG.md CR11 for the provisioning runbook.

A "HOLDS A LIVE KEY" verdict is the more dangerous one: that credential is
distinct from prd's — so the hash table above may well call it "ok" — while
still authenticating against the production Stripe account. See CR18.
EOF
  exit 1
fi

echo "PASS: ${#SECRETS[@]} credentials differ between $BASE_CONFIG and $PROD_CONFIG,"
echo "      and ${#STRIPE_MODED_KEYS[@]} Stripe keys are test-mode in $BASE_CONFIG / live-mode in $PROD_CONFIG."
