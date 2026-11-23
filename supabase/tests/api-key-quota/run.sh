#!/usr/bin/env bash
#
# Verify the api-key-quota migration against a throwaway Postgres cluster. Touches nothing
# remote — no Supabase credentials are read or needed.
#
#   ./run.sh                       # default migration, default port
#   ./run.sh --keep                # leave the cluster up for manual psql
#   ./run.sh --migration path.sql  # test a different migration
#   ./run.sh --port 55555          # if 55442 is taken
#
# Exit 0 = every assertion passed. Any FAIL aborts non-zero (ON_ERROR_STOP).
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MIGRATION="$HERE/../../migrations/20261122010000_api_key_quota_in_create.sql"
PORT=55442
RUN_PREFIX=apikeyquota

# shellcheck source=../_lib/pg-harness.sh
source "$HERE/../_lib/pg-harness.sh" "$@"

# Q6 two concurrent creates for the last slot: the second waits on the first's org lock,
# then sees its committed key and raises. Without the lock both would read 0 and both mint.
HOLD_SECONDS=2
START_DELAY_SECONDS=0.5
USER_ID=00000000-0000-0000-0000-000000000001
ORG_ID=00000000-0000-0000-0000-00000000000a
LIMIT=1

as_service() { psql_run -qAt -c "set role service_role; $1"; }

psql_run -q -o /dev/null <<SQL &
begin;
set role service_role;
select create_api_key_for_request('20000000-0000-0000-0000-000000000061', '$USER_ID', '$ORG_ID', 'bbbb0061', 'hash-q61', 'q6', 'starter', $LIMIT);
select pg_sleep($HOLD_SECONDS);
commit;
SQL
FIRST_PID=$!
sleep "$START_DELAY_SECONDS"
set +e
SECOND_OUTPUT="$(as_service "select create_api_key_for_request('20000000-0000-0000-0000-000000000062', '$USER_ID', '$ORG_ID', 'bbbb0062', 'hash-q62', 'q6', 'starter', $LIMIT);" 2>&1)"
SECOND_STATUS=$?
set -e
wait "$FIRST_PID"
LIVE_KEYS="$(psql_run -qAt -c "select count(*) from api_keys where hash in ('hash-q61', 'hash-q62') and status = 'active';")"
if [[ $SECOND_STATUS -ne 0 && "$SECOND_OUTPUT" == *api_key_quota_exceeded* && "$LIVE_KEYS" == "1" ]]; then
  echo "PASS Q6 a concurrent create for the last slot waited, raised api_key_quota_exceeded and minted nothing"
else
  echo "FAIL Q6 second create exit ${SECOND_STATUS}, output '${SECOND_OUTPUT}', live keys ${LIVE_KEYS}" >&2
  exit 1
fi
