#!/usr/bin/env bash
# CR30 guard: prove the migration ledger can rebuild the schema from NOTHING.
#
# Replays every file in supabase/migrations/ onto an empty local database and
# fails if the replay fails — or if it "succeeds" without producing the objects
# whose absence was the original defect.
#
# Why this exists: `migration list` and scripts/check-migration-drift.sh both
# compare the ledger against PRODUCTION, which has had every object since
# before the ledger existed. A green drift check is therefore consistent with
# a ledger that cannot build anything — which was the actual state of this
# repo until 2026-08-03: 10 tables, 3 enums, 2 columns on a ledger-managed
# table, and 1 view (43% of `public`) existed only in production, plus three
# ordering defects where migrations read objects created by LATER migrations.
# None of that is detectable by comparing against a database that already
# works. Only a replay onto an empty database catches this class.
#
# Needs Docker (the Supabase local stack) — runs in CI, not on machines
# without it. No secrets: everything is local containers.
set -euo pipefail

cd "$(dirname "$0")/.."

command -v supabase >/dev/null 2>&1 || { echo "FAIL: supabase CLI not installed"; exit 2; }
command -v docker   >/dev/null 2>&1 || { echo "FAIL: docker not available (local stack needs it)"; exit 2; }
command -v psql     >/dev/null 2>&1 || { echo "FAIL: psql not available (needed for assertions)"; exit 2; }

cleanup() { supabase stop --no-backup >/dev/null 2>&1 || true; }
trap cleanup EXIT

# Full stack, not `db start`: the auth service is what guarantees `auth.users`
# and `auth.uid()` exist, and the baseline migrations FK into auth.users.
echo "== starting local stack =="
supabase start

# Deterministic empty->replay, regardless of what `start` already applied.
# There is no supabase/seed.sql, so reset applies migrations only.
echo "== replaying ledger onto empty database =="
supabase db reset

# `reset` exiting 0 proves the files RAN; now prove they produced the schema.
# The objects below are exactly the classes the 2026-08-03 defect hid: the
# pre-ledger tables, the enums, the two out-of-band organizations columns, and
# the user_details VIEW (invisible to any table-level check).
DB_PORT="$(sed -n '/^\[db\]/,/^\[/p' supabase/config.toml | grep -m1 '^port' | grep -oE '[0-9]+')"
DB_URL="postgresql://postgres:postgres@127.0.0.1:${DB_PORT:-54322}/postgres"

echo "== asserting rebuilt schema =="
missing="$(psql "$DB_URL" -tA -c "
  select string_agg(t, ', ')
  from unnest(array[
    'users','api_keys','roles','analytics_projects','provider_oauth_tokens',
    'stripe_events','user_activity','user_profiles','user_roles','user_sessions',
    'organizations','organization_memberships','subscriptions','entitlements',
    'plans','auth_user_links','user_details'
  ]) t
  where to_regclass('public.' || t) is null;")"

if [[ -n "$missing" ]]; then
  echo "FAIL: replay reported success but these objects do not exist: $missing"
  exit 1
fi

enums="$(psql "$DB_URL" -tA -c "
  select count(*) from pg_type t
  join pg_namespace n on n.oid = t.typnamespace
  where n.nspname = 'public' and t.typtype = 'e';")"
if [[ "$enums" -lt 3 ]]; then
  echo "FAIL: expected >= 3 enums in public, found $enums"
  exit 1
fi

orgcols="$(psql "$DB_URL" -tA -c "
  select count(*) from information_schema.columns
  where table_schema = 'public' and table_name = 'organizations'
    and column_name in ('domain', 'type');")"
if [[ "$orgcols" -ne 2 ]]; then
  echo "FAIL: organizations.domain/.type missing (found $orgcols of 2)"
  exit 1
fi

echo "PASS: full ledger replays onto an empty database and rebuilds the schema."
