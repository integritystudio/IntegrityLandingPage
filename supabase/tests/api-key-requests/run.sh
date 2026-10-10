#!/usr/bin/env bash
#
# Verify the api-key-requests migration against a throwaway Postgres cluster. Touches
# nothing remote — no Supabase credentials are read or needed.
#
#   ./run.sh                       # default migration, default port
#   ./run.sh --keep                # leave the cluster up for manual psql
#   ./run.sh --migration path.sql  # test a different migration
#   ./run.sh --port 55555          # if 55441 is taken
#
# Exit 0 = every assertion passed. Any FAIL aborts non-zero (ON_ERROR_STOP).
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MIGRATION="$HERE/../../migrations/20261010000000_api_key_requests.sql"
PORT=55441
RUN_PREFIX=apikeyrequests

# shellcheck source=../_lib/pg-harness.sh
source "$HERE/../_lib/pg-harness.sh" "$@"

# Two-session checks: a claim arriving while the other function's transaction is open must
# wait for it, then see its committed result. The open transaction sleeps long enough for
# the second session to start and block on the request id's primary key.
HOLD_SECONDS=2
START_DELAY_SECONDS=0.5
USER_ID=00000000-0000-0000-0000-000000000001
ORG_ID=00000000-0000-0000-0000-00000000000a

as_service() { psql_run -qAt -c "set role service_role; $1"; }

# T9 abandon during an uncommitted create returns the key that create commits
REQ9=10000000-0000-0000-0000-000000000009
psql_run -q -o /dev/null <<SQL &
begin;
set role service_role;
select create_api_key_for_request('$REQ9', '$USER_ID', '$ORG_ID', 'aaaa0009', 'hash-t9', 'key-t9', 'starter');
select pg_sleep($HOLD_SECONDS);
commit;
SQL
CREATE_PID=$!
sleep "$START_DELAY_SECONDS"
ABANDONED_KEY="$(as_service "select abandon_api_key_request('$REQ9');")"
wait "$CREATE_PID"
CREATED_KEY="$(psql_run -qAt -c "select id from api_keys where hash = 'hash-t9';")"
if [[ -n "$CREATED_KEY" && "$ABANDONED_KEY" == "$CREATED_KEY" ]]; then
  echo "PASS T9 abandon during an open create waited and returned its key ($CREATED_KEY)"
else
  echo "FAIL T9 abandon returned '${ABANDONED_KEY}', the create committed '${CREATED_KEY}'" >&2
  exit 1
fi

# T10 create during an uncommitted abandon raises once the abandon commits
REQ10=10000000-0000-0000-0000-000000000010
psql_run -q -o /dev/null <<SQL &
begin;
set role service_role;
select abandon_api_key_request('$REQ10');
select pg_sleep($HOLD_SECONDS);
commit;
SQL
ABANDON_PID=$!
sleep "$START_DELAY_SECONDS"
set +e
CREATE_OUTPUT="$(as_service "select create_api_key_for_request('$REQ10', '$USER_ID', '$ORG_ID', 'aaaa0010', 'hash-t10', 'key-t10', 'starter');" 2>&1)"
CREATE_STATUS=$?
set -e
wait "$ABANDON_PID"
KEY_ROWS="$(psql_run -qAt -c "select count(*) from api_keys where hash = 'hash-t10';")"
if [[ $CREATE_STATUS -ne 0 && "$CREATE_OUTPUT" == *api_key_request_abandoned* && "$KEY_ROWS" == "0" ]]; then
  echo "PASS T10 create during an open abandon waited, raised api_key_request_abandoned and minted nothing"
else
  echo "FAIL T10 create exit ${CREATE_STATUS}, output '${CREATE_OUTPUT}', key rows ${KEY_ROWS}" >&2
  exit 1
fi
