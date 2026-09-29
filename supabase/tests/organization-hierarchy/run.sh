#!/usr/bin/env bash
#
# Verify the organization-hierarchy migration against a throwaway Postgres
# cluster. Touches nothing remote — no Supabase credentials are read or needed.
#
#   ./run.sh                       # default migration, default port
#   ./run.sh --keep                # leave the cluster up for manual psql
#   ./run.sh --migration path.sql  # test a different migration
#   ./run.sh --port 55555          # if 55432 is taken
#
# Exit 0 = every assertion passed. Any FAIL aborts non-zero (ON_ERROR_STOP).
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MIGRATION="$HERE/../../migrations/20260731010000_add_organization_hierarchy.sql"
PORT=55432
RUN_PREFIX=orghier

# shellcheck source=../_lib/pg-harness.sh
source "$HERE/../_lib/pg-harness.sh" "$@"
