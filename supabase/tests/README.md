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

CI (`.github/workflows/supabase-sql-tests.yml`) runs every `*/run.sh` it finds on the
Postgres major that production runs, read from `supabase/config.toml`'s `major_version`
(17 as of 2026-09-28), so a pass there is the one that counts.

## Why a local cluster and not the linked project

Not for lack of access: prd is reachable (the CLI's login-role path and the
Management API `/database/query` endpoint both work; see
[docs/runbooks/supabase-access.md](../../docs/runbooks/supabase-access.md)).
A local cluster lets assertions create and roll back adversarial states —
cycles, inactive memberships, stale tiers — that you would never want to create
in prd, and it runs with no credentials at all.

*(This paragraph said until 2026-09-27 that there was no DDL path to prd,
because `SUPABASE_ACCESS_TOKEN` was empty and `SUPABASE_DB_PASSWORD` failed.
The token has held a valid `sbp_` value since 2026-09-11; the password still
fails, but the CLI does not need it.)*

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

### `users-tier-derivation/`

Covers `migrations/20260927000000_derive_users_tier_from_default_org.sql` (UA04),
which derives `users.tier` from the default organization's `current_plan` by
trigger and backfills existing drift. Port 55433.

| | assertion |
|---|---|
| T1 | backfill fixes drift; no-org users keep their value; `free` maps to `starter` |
| T2 | insert ignores the supplied tier and derives it |
| T3 | a direct write to `tier` is overwritten |
| T4 | changing `default_organization_id` recomputes |
| T5 | a plan change reaches every user of that org and no one else |
| T6 | unknown plan resolves to `starter`; mapping is case-insensitive |
| T7 | a writer with no grant on `users` still propagates (security definer) |
| T8 | clearing the default org keeps the last derived value |
| T9 | invariant: no user with a default org disagrees with its plan |

Mutation-checked: run against an empty migration, T1a fails.

### `default-org-from-membership/`

Covers `migrations/20260929010000_default_org_from_first_membership.sql` (CR50),
which sets a user's `default_organization_id` from their first active membership
when it is null, and backfills it from the oldest active membership. The fixture
applies the UA04 tier migration first, so `tier` following the new default is
tested too. Port 55435.

| | assertion |
|---|---|
| T1 | backfill takes the oldest active membership (age over role); tier follows; a chosen default, an invited-only user and a user with no membership are untouched |
| T2 | a new user's first active membership sets the default, and tier derives from it |
| T3 | a second membership does not move the default |
| T4 | the org's later plan change reaches the new user |
| T5 | invited and suspended memberships set nothing; activation does |
| T6 | a chosen default survives a new active membership |
| T7 | a writer with no grant on `users` still sets it (security definer) |
| T8 | invariant: nobody with an active membership is left without a default |

Mutation-checked: removing the null guard (T3), SECURITY DEFINER (T7, permission
denied), the status gate (T5a), the trigger (T2b) or the backfill (T1a), or
backfilling from the newest membership (T1a), each fails the suite.

### `edge-functions/`

Behavioural tests for the Edge Functions, not the migrations — a Node/vitest package, not
a Postgres cluster. Each function's logic lives in a `handler.ts` that takes its I/O
(`env`, `fetch`, supabase-js's `createClient`) as parameters; `index.ts` only binds it to
`Deno.serve`. The tests drive the handler with the **real** supabase-js client against
`fake-backend.ts`, an in-memory PostgREST + Auth admin + Cloudflare KV that keeps state
and throws on any request shape it does not implement, so assertions are on what was
stored, never on which calls were made.

```bash
cd supabase/tests/edge-functions && npm install && npm test
```

Covers `api-keys-create` today. Mutation-checked: 12 of 12 seeded defects in `handler.ts`
are caught. To type-check a function under Deno from inside this repo (CI does this for
every `supabase/functions/*/index.ts` in `.github/workflows/edge-function-tests.yml`, as a
failing step):
`deno check --no-lock --node-modules-dir=none supabase/functions/<name>/index.ts`.

## Writing a new suite

Copy the three-file shape: `fixture.sql`, `verify.sql`, `run.sh`. A `run.sh` is only
its header comment (lines 2-12 are its `--help`), `set -euo pipefail`, and `HERE`,
`MIGRATION`, `PORT` (unique per suite) and `RUN_PREFIX`, then
`source "$HERE/../_lib/pg-harness.sh" "$@"`, which does the rest. `_lib/` holds no
`run.sh` on purpose: CI runs every `supabase/tests/*/run.sh`. Four traps
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
