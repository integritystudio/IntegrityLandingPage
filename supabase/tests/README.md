# Supabase migration tests

Assertion harnesses that run a migration against a **throwaway local Postgres
cluster**. No Supabase credentials are read, nothing remote is contacted, and
nothing is written to any hosted database.

Each suite builds a cluster in `mktemp -d`, loads a fixture replicating the
slice of prd schema under test, applies the migration, runs assertions, and
tears the cluster down.

## Running

```bash
./organization-hierarchy/run.sh              # exit 0 = all assertions passed
./organization-hierarchy/run.sh --keep       # leave cluster up for manual psql
./organization-hierarchy/run.sh --port 55555 # if the default port is taken
./organization-hierarchy/run.sh --migration path/to/other.sql
```

Requires Postgres binaries. On this machine they are keg-only Homebrew:
`/opt/homebrew/opt/postgresql@15/bin` (auto-detected; override with `PGBIN`).
`brew install postgresql@15` if missing. There is no Docker dependency.

## Why a local cluster and not the linked project

DDL cannot be applied through PostgREST, and at time of writing there was no
working DDL path to prd from this machine: `SUPABASE_ACCESS_TOKEN` is empty in
both Doppler configs (so the Management API `/database/query` endpoint 401s) and
`SUPABASE_DB_PASSWORD` fails auth against `aws-1-us-east-1.pooler.supabase.com`
on both 5432 and 6543. A local cluster also means assertions can create and roll
back adversarial states — cycles, inactive memberships — that you would never
want to create in prd.

## Suites

### `organization-hierarchy/`

Covers `migrations/20260731010000_add_organization_hierarchy.sql`, which adds
`organizations.parent_organization_id`, promotes the umbrella org to
`type='parent-organization'`, and adds an RLS policy letting a member of a child
org read its ancestors.

| | assertion |
|---|---|
| T0 | harness: the role switch actually took effect |
| T1 | parent linkage recorded with the right types |
| T2 | self-parent rejected by the CHECK constraint |
| T3 | member of a child org sees child **and** parent, nothing else |
| T4 | unrelated user sees only their own org — no parent leak |
| T5 | no JWT → zero rows |
| T6 | `status <> 'active'` membership confers nothing |
| T7 | the walk is **upward only** — a parent member gains no children |
| T8 | a parent cycle (`a → b → a`) terminates instead of hanging |
| T9 | multi-level walk reaches a grandparent |
| T10 | a naive inline policy still recurses (justifies the function indirection) |

## Writing a new suite

Copy the three-file shape: `fixture.sql`, `verify.sql`, `run.sh`. Four traps
account for every false-pass encountered while building the first suite — all
four produce a green run that proves nothing.

**1. `SET LOCAL` outside a transaction is a silent no-op.** It emits only a
`WARNING`, so the role never switches and every query runs as the table owner.
Wrap role-switching tests in explicit `begin; … rollback;`.

**2. A table's owner bypasses RLS.** Enabling RLS does nothing to the role that
owns the table. Assertions must run as a non-owner (`authenticated`). Call
`assert_role('authenticated')` inside each transaction so a failed switch raises
instead of passing quietly.

**3. RLS enabled with no policy returns zero rows — including in a subquery.**
If policy A on table X reads table Y, and Y has RLS on but no policy, A silently
matches nothing. The fixture must carry *every* policy in the read chain, not
just the one under test. This is what broke T3 on the first run: the fixture had
`organizations` policies but not `organization_memberships` or `auth_user_links`.

**4. `security definer` functions do not observe RLS on the tables they read.**
That is the point — it is how `user_ancestor_org_ids()` avoids infinite
recursion — but it means a definer-backed policy and an inline policy have
different visibility into inner tables. Trap 3 is easy to miss precisely because
the definer path keeps working while the inline path goes dark.

Prefer assertions that compare against an expected set (`assert_visible`) over
ones that print rows for a human to eyeball; the latter is how a bypassed-RLS
run looks correct.
