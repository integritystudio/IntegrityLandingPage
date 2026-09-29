#!/usr/bin/env bash
#
# Verify the usage-buckets single-writer migration (CR43) against a throwaway Postgres
# cluster. Touches nothing remote — no Supabase credentials are read or needed.
#
#   ./run.sh                       # default migration, default port
#   ./run.sh --keep                # leave the cluster up for manual psql
#   ./run.sh --migration path.sql  # test a different migration
#   ./run.sh --port 55555          # if 55434 is taken
#
# Exit 0 = every assertion passed. Any FAIL aborts non-zero (ON_ERROR_STOP).
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MIGRATION="$HERE/../../migrations/20260927020000_usage_buckets_single_writer.sql"
PORT=55434
RUN_PREFIX=usagebuckets

# shellcheck source=../_lib/pg-harness.sh
source "$HERE/../_lib/pg-harness.sh" "$@"
