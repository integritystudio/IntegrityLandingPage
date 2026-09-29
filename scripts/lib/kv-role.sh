# shellcheck shell=bash
# KV namespace role verdicts for check-env-isolation.sh (UA03, TS35). Sourced, not run.
#
# Pure functions over digests: the caller fetches each value's SHA-1 and passes the
# AUTH pins as arguments, so scripts/lib/kv-role.test.ts can drive every verdict with
# made-up digests. The real pins stay in check-env-isolation.sh.
#
# Requires EMPTY_HASH (the SHA-1 of the empty string) to be set by the caller.
# Each function prints its verdict and returns 1 when the verdict is a failure.

# dev's `KV_NAMESPACE_ID` is AUTH_DEV on purpose (repointed 2026-08-07 so the dev
# functions write there), which also makes a dashboard sync run under dev write
# into AUTH_DEV. UA03 leaves it until the sync's readers are confirmed.
kv_is_known_gap() { [[ "$1:$2" == "dev:KV_NAMESPACE_ID" ]]; }

# kv_auth_verdict <hash> <own_pin> <other_config> <other_pin>
# The AUTH slot must hold this config's own AUTH id.
kv_auth_verdict() {
  local hash=$1 own_pin=$2 other_config=$3 other_pin=$4
  if [[ "$hash" == "$EMPTY_HASH" ]]; then
    echo "missing"; return 1
  elif [[ "$hash" == "$own_pin" ]]; then
    echo "ok (AUTH)"
  elif [[ "$hash" == "$other_pin" ]]; then
    echo "holds $other_config's AUTH id"; return 1
  else
    echo "NOT the AUTH namespace"; return 1
  fi
}

# kv_dashboard_verdict <config> <name> <hash> <own_pin> <other_config> <other_pin>
# A dashboard slot must point at neither config's AUTH. Absent is reported, not
# failed: a slot nothing holds cannot direct a sync into AUTH.
kv_dashboard_verdict() {
  local config=$1 name=$2 hash=$3 own_pin=$4 other_config=$5 other_pin=$6
  if [[ "$hash" == "$EMPTY_HASH" ]]; then
    echo "missing (not checked)"
  elif [[ "$hash" == "$own_pin" ]] && kv_is_known_gap "$config" "$name"; then
    echo "KNOWN GAP (UA03): AUTH, so a dashboard sync here writes into it"
  elif [[ "$hash" == "$own_pin" ]]; then
    echo "POINTS AT AUTH: the dashboard sync would write into it"; return 1
  elif [[ "$hash" == "$other_pin" ]]; then
    echo "POINTS AT $other_config's AUTH: the dashboard sync would write into it"; return 1
  else
    echo "ok (not AUTH)"
  fi
}
