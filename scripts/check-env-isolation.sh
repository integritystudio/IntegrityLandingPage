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
#
# SUPABASE_SERVICE_ROLE_KEY is deliberately RETAINED even though the slot exists
# in neither config (measured 2026-08-02). It is a tripwire, not a live row: if
# anyone re-creates that name it must be compared again. It no longer counts as
# an isolation failure — see the ABSENT verdict below, which exists because a
# name nobody sets is "not measured", not "not isolated". Reading those as the
# same thing inflated this detector's count by one from 2026-07-29 to 2026-08-02
# and masked the two rows underneath it.
SECRETS=(
  SUPABASE_URL
  SUPABASE_SERVICE_ROLE_KEY
  SUPABASE_PROVISIONING_KEY
  SUPABASE_INTEGRITY_MEMERSHIP_KEY
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

# Supabase has the same "distinct but not isolated" hole, reachable by accident.
#
# `POST /v1/projects/{ref}/api-keys` mints a new `sb_secret_` key carrying
# secret_jwt_template {role: service_role}. Pointing dev at one would make
# SUPABASE_SERVICE_ROLE_KEY differ — so the table above would say "ok
# (distinct)" — while the key still bypasses RLS on the PRODUCTION database.
# It would quiet the detector without isolating anything.
#
# SUPABASE_URL is the tell, because it is derived from the project ref and
# cannot differ within one project. If it is shared, every other Supabase
# credential is non-isolating by construction no matter what its hash says.
# Real isolation requires a second Supabase project (`POST /v1/projects`).
SUPABASE_PROJECT_SCOPED=(
  SUPABASE_SERVICE_ROLE_KEY
  SUPABASE_PROVISIONING_KEY
  SUPABASE_INTEGRITY_MEMERSHIP_KEY
  SUPABASE_ANON_KEY
  SUPABASE_JWT_SECRET
  SUPABASE_DB_PASSWORD
)

command -v doppler >/dev/null 2>&1 || { echo "doppler CLI not installed"; exit 2; }
doppler me >/dev/null 2>&1 || { echo "doppler not authenticated — run 'doppler login'"; exit 2; }

# SHA-1 of the empty string: distinguishes "unset in both" from "same value".
EMPTY_HASH="da39a3ee5e6b4b0d3255bfef95601890afd80709"

# `tr -d '\n'` is load-bearing, not tidiness. `doppler secrets get --plain` emits
# a trailing newline for a slot that EXISTS AND IS EMPTY, but nothing at all for
# a slot that is ABSENT — so without stripping it the two hash differently
# (sha1("\n")=adc83b19… vs sha1("")=da39a3ee…) and only the absent case matched
# EMPTY_HASH. Consequence, measured 2026-08-02: SUPABASE_JWT_SECRET exists-but-
# empty in dev and is set in prd, so it hashed adc83b19… against 17e06a04… and
# scored **"ok (distinct)"** — a false PASS on a slot holding no credential at
# all. That is the dangerous direction of this bug: it manufactures isolation
# rather than an alarm. Stripping the newline reclassifies it as "missing in dev".
digest() {
  doppler secrets get "$1" --project "$PROJECT" --config "$2" --plain 2>/dev/null \
    | tr -d '\n' | shasum | cut -d' ' -f1
}

# Emits only the key-type prefix (e.g. `sk_live_`), never the key body.
key_prefix() {
  doppler secrets get "$1" --project "$PROJECT" --config "$2" --plain 2>/dev/null \
    | tr -d '\n' | grep -oE '^(sk|rk|pk)_(live|test)_' || printf '(none)'
}

printf '%-30s %-10s %-10s %s\n' "SECRET" "$BASE_CONFIG" "$PROD_CONFIG" "VERDICT"
printf '%s\n' "----------------------------------------------------------------------"

failures=0
unmeasured=0
for secret in "${SECRETS[@]}"; do
  base_hash="$(digest "$secret" "$BASE_CONFIG")"
  prod_hash="$(digest "$secret" "$PROD_CONFIG")"

  if [[ "$base_hash" == "$EMPTY_HASH" && "$prod_hash" == "$EMPTY_HASH" ]]; then
    # Set in neither config. This is NOT an isolation failure — there is no
    # credential here to share — but it is not a pass either: the detector is
    # watching a name that nobody sets, so this row measures nothing. Counted
    # separately so it can never be mistaken for either verdict. A credential
    # that MOVES SLOTS is exactly what this hides: SUPABASE_SERVICE_ROLE_KEY
    # read "UNSET in both" while the live service key sat, shared, in
    # SUPABASE_PROVISIONING_KEY, which nothing compared.
    verdict="ABSENT in both (measures nothing)"; ((unmeasured++))
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
if [[ "$(digest SUPABASE_URL "$BASE_CONFIG")" == "$(digest SUPABASE_URL "$PROD_CONFIG")" ]]; then
  cat <<EOF
SUPABASE SCOPE: both configs share one SUPABASE_URL, so they are the same
project. ${SUPABASE_PROJECT_SCOPED[*]} therefore cannot
isolate anything, whatever their hashes say above — a per-config
\`sb_secret_\` minted via POST /v1/projects/{ref}/api-keys would read
"ok (distinct)" here while still bypassing RLS on production. Isolation
requires a second project (POST /v1/projects). See BACKLOG.md CR11.
EOF
  echo
fi

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
if (( unmeasured > 0 )); then
  cat <<EOF
NOTE: $unmeasured row(s) are ABSENT in both configs and measure nothing. They are
excluded from the failure count on purpose — "nobody sets this name" is not
evidence of isolation. Before trusting a low count, confirm that no LIVE
credential has moved to a slot this list does not name: that is exactly how
SUPABASE_PROVISIONING_KEY (shared, and a working service_role key against the
production database) went uncompared while SUPABASE_SERVICE_ROLE_KEY scored a
phantom failure in its place.

EOF
fi

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
