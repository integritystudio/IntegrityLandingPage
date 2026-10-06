#!/usr/bin/env bash
#
# Verify the auth0-sub-read-policies migration against a throwaway Postgres cluster.
# Touches nothing remote — no Supabase credentials are read or needed.
#
#   ./run.sh                       # default migration, default port
#   ./run.sh --keep                # leave the cluster up for manual psql
#   ./run.sh --migration path.sql  # test a different migration
#   ./run.sh --port 55555          # if 55440 is taken
#
# Exit 0 = every assertion passed. Any FAIL aborts non-zero (ON_ERROR_STOP).
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MIGRATION="$HERE/../../migrations/20261007000000_auth0_sub_read_policies.sql"
FOLLOWUPS=("$HERE/../../migrations/20261007010000_resolvers_revoke_anon_execute.sql")
PORT=55440
RUN_PREFIX=auth0readpolicies

# shellcheck source=../_lib/pg-harness.sh
source "$HERE/../_lib/pg-harness.sh" "$@"
