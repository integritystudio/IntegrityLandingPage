# Shared body of every supabase/tests/<suite>/run.sh. Not itself a suite: CI runs
# supabase/tests/*/run.sh, so this file must never be named run.sh.
#
# Sourced by a run.sh that has already set:
#   HERE       the suite directory (holds fixture.sql and verify.sql)
#   MIGRATION  the migration under test (overridable with --migration)
#   PORT       the cluster port (overridable with --port)
#   RUN_PREFIX the mktemp prefix for the throwaway cluster
# and passes its own arguments through: source .../pg-harness.sh "$@"
# The caller's `set -euo pipefail` applies here too.

: "${HERE:?}" "${MIGRATION:?}" "${PORT:?}" "${RUN_PREFIX:?}"

KEEP=0

while [[ $# -gt 0 ]]; do
  case "$1" in
    --migration) MIGRATION="$2"; shift 2 ;;
    --port)      PORT="$2"; shift 2 ;;
    --keep)      KEEP=1; shift ;;
    -h|--help)   sed -n '2,12p' "$0"; exit 0 ;;
    *) echo "unknown arg: $1" >&2; exit 2 ;;
  esac
done

# Homebrew keg-only postgres; fall back to whatever is on PATH.
PGBIN="${PGBIN:-/opt/homebrew/opt/postgresql@15/bin}"
[[ -x "$PGBIN/initdb" ]] || PGBIN="$(dirname "$(command -v initdb || true)")"
if [[ ! -x "$PGBIN/initdb" ]]; then
  echo "ERROR: no postgres binaries found. brew install postgresql@15" >&2
  exit 1
fi

[[ -f "$MIGRATION" ]] || { echo "ERROR: migration not found: $MIGRATION" >&2; exit 1; }

# mktemp -d, so concurrent runs never collide on a fixed path.
RUNDIR="$(mktemp -d "${TMPDIR:-/tmp}/${RUN_PREFIX}.XXXXXX")"
DATA="$RUNDIR/data"
SOCK="$RUNDIR/sock"
mkdir -p "$DATA" "$SOCK"

cleanup() {
  local code=$?
  if [[ $KEEP -eq 1 ]]; then
    echo ""
    echo "cluster kept at $RUNDIR"
    echo "  psql -h $SOCK -p $PORT -U pgtest -d testdb"
    echo "  $PGBIN/pg_ctl -D $DATA stop"
  else
    "$PGBIN/pg_ctl" -D "$DATA" -m immediate stop >/dev/null 2>&1 || true
    rm -rf "$RUNDIR"
  fi
  exit $code
}
trap cleanup EXIT

echo "postgres: $("$PGBIN/postgres" --version)"
echo "migration: $(basename "$MIGRATION")"
echo ""

"$PGBIN/initdb" -D "$DATA" -U pgtest --auth=trust >/dev/null 2>&1
"$PGBIN/pg_ctl" -D "$DATA" \
  -o "-k $SOCK -p $PORT -c listen_addresses=''" \
  -l "$RUNDIR/pg.log" start >/dev/null 2>&1

# pg_ctl returns before the socket is always accepting; poll rather than sleep.
for _ in $(seq 1 30); do
  "$PGBIN/pg_isready" -h "$SOCK" -p "$PORT" -q && break
  sleep 0.2
done
"$PGBIN/pg_isready" -h "$SOCK" -p "$PORT" -q || { cat "$RUNDIR/pg.log"; exit 1; }

"$PGBIN/createdb" -h "$SOCK" -p "$PORT" -U pgtest testdb

psql_run() { "$PGBIN/psql" -h "$SOCK" -p "$PORT" -U pgtest -d testdb -v ON_ERROR_STOP=1 "$@"; }

psql_run -q -f "$HERE/fixture.sql"
echo "fixture loaded"

psql_run -q -f "$MIGRATION"
echo "migration applied"

# -P pager=off so a long NOTICE stream never blocks in CI.
psql_run -P pager=off -f "$HERE/verify.sql"
