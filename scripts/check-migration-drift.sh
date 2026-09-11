#!/usr/bin/env bash
#
# Detect schema drift between migration SQL files and the live Supabase database.
#
# Parses CREATE TABLE and CREATE [OR REPLACE] FUNCTION statements from every
# migration file and verifies each object exists in the live database via the
# Supabase Management API.  Reports missing objects and exits non-zero if any
# are found.
#
# Root cause this guards against (BACKLOG.md CR17):
#   `supabase migration repair --status applied` writes the ledger row without
#   executing the SQL, so a migration can appear applied while its objects are
#   absent.  This script catches that gap.
#
# Known limits:
#   - Checks object *presence* only, not column types, constraints, or defaults.
#   - Cannot verify DML-only migrations.
#   - Parses single-line CREATE TABLE/FUNCTION declarations only; multi-line
#     statements (CREATE TABLE\n  public.name) will be missed.  Supabase
#     migrations in this repo use single-line declarations throughout.
#   - Skips triggers: 20260320010002's triggers are deliberately absent
#     (duplicated by phase1_consolidated; see BACKLOG.md CR17).
#
# Usage:
#   SUPABASE_ACCESS_TOKEN=<token> bash scripts/check-migration-drift.sh
#
#   # With Doppler:
#   SUPABASE_ACCESS_TOKEN=$(doppler secrets get SUPABASE_ACCESS_TOKEN \
#     --project integrity-studio --config prd --plain) \
#     bash scripts/check-migration-drift.sh
#
# Exit codes:
#   0  all declared objects are present in the live database, OR the check was
#      skipped because SUPABASE_ACCESS_TOKEN is unset (see below)
#   1  one or more declared objects are missing
#   2  prerequisites missing or API call failed

set -uo pipefail

PROJECT_REF="cfrbahzzklwrnmbtqojl"
MIGRATIONS_DIR="${MIGRATIONS_DIR:-supabase/migrations}"
TOKEN="${SUPABASE_ACCESS_TOKEN:-}"

# ── Prerequisites ─────────────────────────────────────────────────────────────

# A missing token is a SKIP, not a failure. Doppler prd has held a valid sbp_
# token since before 2026-09-11 (the slot was deliberately empty for a while —
# BACKLOG.md CR01 step 3), so in CI this path now means a Doppler outage or a
# revoked token, not "unconfigured". It stays a SKIP because a check that is
# always failing is a check nobody reads; other prerequisite problems below
# still exit 2, because those mean the environment is broken.
if [[ -z "$TOKEN" ]]; then
  echo "SKIPPED: migration drift not checked — SUPABASE_ACCESS_TOKEN is unset."
  echo "  Mint a personal access token at supabase.com/dashboard/account/tokens and"
  echo "  store it as SUPABASE_ACCESS_TOKEN in Doppler prd to enable this check."
  exit 0
fi

for cmd in curl jq; do
  command -v "$cmd" >/dev/null 2>&1 || { echo "error: $cmd is required" >&2; exit 2; }
done

if [[ ! -d "$MIGRATIONS_DIR" ]]; then
  echo "error: migrations directory not found: $MIGRATIONS_DIR" >&2
  exit 2
fi

# ── Management API query ──────────────────────────────────────────────────────

run_query() {
  local sql="$1"
  local body
  body=$(printf '%s' "$sql" | jq -Rs '{"query": .}')

  local response http_code
  response=$(curl -sf \
    -w '\n__HTTP_CODE__%{http_code}' \
    -H "Authorization: Bearer $TOKEN" \
    -H "Content-Type: application/json" \
    -d "$body" \
    "https://api.supabase.com/v1/projects/$PROJECT_REF/database/query" 2>&1) || {
      echo "error: Management API request failed (curl error)" >&2
      exit 2
    }

  http_code=$(echo "$response" | grep '__HTTP_CODE__' | sed 's/.*__HTTP_CODE__//')
  local body_only
  body_only=$(echo "$response" | grep -v '__HTTP_CODE__')

  if [[ "$http_code" != "200" ]] && [[ "$http_code" != "201" ]]; then
    echo "error: Management API returned HTTP $http_code" >&2
    echo "       response: $body_only" >&2
    exit 2
  fi

  echo "$body_only"
}

# ── Parse expected objects from migration SQL ─────────────────────────────────

# Walk the migration files in version order and replay CREATE TABLE / DROP TABLE
# into a set: a table declared by an early file and dropped by a later one is
# NOT expected live. Order matters — 20260320000000 drops five tables as
# pre-create cleanup and recreates them in the same file, so a flat
# "created minus dropped" set would wrongly exclude them; replaying statements
# in file+line order keeps them. (Before 2026-09-11 this only collected creates,
# so the first versioned DROP TABLE — 20260910000000 — turned the check red for
# three tables that were absent by design.)
# Lower-case before matching so the patterns work on both macOS and GNU tools.
expected_tables() {
  ls "$MIGRATIONS_DIR"/*.sql | sort | while read -r f; do
    grep -v '^--' "$f" | tr '[:upper:]' '[:lower:]'
  done | awk '
    /create table/ {
      if (match($0, /create table (if not exists )?(public\.)?[a-z_][a-z0-9_]*/)) {
        n = substr($0, RSTART, RLENGTH); sub(/.* /, "", n); live[n] = 1
      }
    }
    /drop table/ {
      if (match($0, /drop table (if exists )?(public\.)?[a-z_][a-z0-9_]*/)) {
        n = substr($0, RSTART, RLENGTH); sub(/.* /, "", n); delete live[n]
      }
    }
    END { for (n in live) print n }
  ' | sed -E 's/^public\.//' | sort -u
}

# Parse CREATE [OR REPLACE] FUNCTION [public.]name( from all migration files.
expected_functions() {
  grep -rhi 'create.*function' "$MIGRATIONS_DIR" \
    | grep -v '^--' \
    | tr '[:upper:]' '[:lower:]' \
    | sed -E 's/.*function (public\.)?([a-zA-Z_][a-zA-Z0-9_]*)\(.*/\2/' \
    | sort -u
}

# ── Fetch live objects ────────────────────────────────────────────────────────

live_tables() {
  run_query \
    "SELECT tablename FROM pg_tables WHERE schemaname = 'public' ORDER BY tablename;" \
  | jq -r '.[].tablename'
}

live_functions() {
  run_query \
    "SELECT p.proname \
     FROM pg_proc p \
     JOIN pg_namespace n ON n.oid = p.pronamespace \
     WHERE n.nspname = 'public' \
     ORDER BY p.proname;" \
  | jq -r '.[].proname'
}

# ── Comparison ────────────────────────────────────────────────────────────────

missing=0

# Compare expected list against live list; return number of missing objects.
check_objects() {
  local label="$1"
  local expected="$2"
  local live="$3"
  local local_missing=0

  printf '\n%s\n' "$label"
  printf '%s\n' "$(printf '─%.0s' {1..40})"

  while IFS= read -r obj; do
    [[ -z "$obj" ]] && continue
    if echo "$live" | grep -qx "$obj"; then
      printf '  %-40s ok\n' "$obj"
    else
      printf '  %-40s MISSING\n' "$obj"
      local_missing=$((local_missing + 1))
    fi
  done <<< "$expected"

  missing=$((missing + local_missing))
}

echo "Migration drift check — project $PROJECT_REF"
echo "Migrations: $MIGRATIONS_DIR"

EXPECTED_TABLES=$(expected_tables)
EXPECTED_FUNCTIONS=$(expected_functions)
LIVE_TABLES=$(live_tables)
LIVE_FUNCTIONS=$(live_functions)

check_objects "Tables" "$EXPECTED_TABLES" "$LIVE_TABLES"
check_objects "Functions" "$EXPECTED_FUNCTIONS" "$LIVE_FUNCTIONS"

echo
if (( missing > 0 )); then
  cat <<EOF
FAIL: $missing object(s) declared in migration SQL are absent from the live database.

This typically means one of:
  1. A migration was recorded with 'supabase migration repair --status applied'
     without running the SQL.  Repair: '--status reverted', fix, then 'db push'.
  2. A migration SQL file has a syntax error that aborted it partway through.

Repair procedure (BACKLOG.md CR17):
  supabase migration repair --status reverted --version <version>
  supabase db push --include-all
  bash scripts/check-migration-drift.sh   # should now pass
EOF
  exit 1
fi

echo "PASS: all $(echo "$EXPECTED_TABLES" | grep -c .) tables and $(echo "$EXPECTED_FUNCTIONS" | grep -c .) functions are present."
exit 0
