#!/usr/bin/env bash
#
# Verify the default-org-set-at migration against a throwaway Postgres cluster.
# Touches nothing remote — no Supabase credentials are read or needed.
#
#   ./run.sh                       # default migration, default port
#   ./run.sh --keep                # leave the cluster up for manual psql
#   ./run.sh --migration path.sql  # test a different migration
#   ./run.sh --port 55555          # if 55437 is taken
#
# Exit 0 = every assertion passed. Any FAIL aborts non-zero (ON_ERROR_STOP).
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MIGRATION="$HERE/../../migrations/20261001000000_default_org_set_at.sql"
PORT=55437
RUN_PREFIX=defaultorgsetat

# shellcheck source=../_lib/pg-harness.sh
source "$HERE/../_lib/pg-harness.sh" "$@"
