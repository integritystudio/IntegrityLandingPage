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
| T1 | backfill takes the oldest active membership (age over role); tier follows; a chosen default, an invited-only user and a user with no membership are untouched; a `created_at` tie goes to the lower membership id, whichever arrived first |
| T2 | a new user's first active membership sets the default, and tier derives from it |
| T3 | a second membership does not move the default |
| T4 | the org's later plan change reaches the new user |
| T5 | invited and suspended memberships set nothing; activation does |
| T6 | a chosen default survives a new active membership |
| T7 | a writer with no grant on `users` still sets it (security definer) |
| T8 | invariant: nobody with an active membership is left without a default — asserted at the end of every block (T4–T7) and again at rest |

Mutation-checked: removing the null guard (T3), SECURITY DEFINER (T7, permission
denied), the status gate (T5a), the trigger (T2b) or the backfill (T1a), or
backfilling from the newest membership (T1a), each fails the suite. So does dropping
the `id` tie-break or reversing it (T1f), and a default cleared inside a block fails
that block's invariant.

### `api-keys-restrict-delete/`

Covers `migrations/20260930000000_api_keys_restrict_delete.sql` (UA13), which turns
`api_keys`' two foreign keys from `ON DELETE CASCADE` into `RESTRICT`, so deleting a
user or org can no longer drop key rows while their AUTH KV records keep
authenticating. The fixture carries production's `auth.users → public.users` CASCADE,
so the Supabase admin delete path is tested too. Port 55436.

| | assertion |
|---|---|
| T1 | both constraints read `confdeltype = 'r'` |
| T2 | deleting a key-holding user is refused (23503) and no key row is removed |
| T3 | deleting that user's `auth.users` entry is refused the same way |
| T4 | deleting an org that holds keys is refused |
| T5 | a revoked row blocks too — revocation keeps the row |
| T6 | the supported order works: delete the key rows, then the user; memberships still cascade |
| T7 | a key-less user and org delete as before (the signup rollback path) |
| T8 | at rest, every key row is still present |

Mutation-checked: run against a no-op migration, the suite fails at T1a.

### `default-org-set-at/`

Covers `migrations/20261001000000_default_org_set_at.sql`, which stamps
`users.default_organization_set_at` whenever `default_organization_id` changes. The
fixture reuses `default-org-from-membership/`'s and applies the CR50 migration, so
the stamp is tested against the trigger that sets most defaults. Port 55437.

| | assertion |
|---|---|
| S1 | existing rows stay null — no invented history |
| S2 | a default set by the CR50 trigger carries the membership's `created_at` exactly |
| S3 | changing the default stamps it, and `tier` still follows |
| S4 | re-writing the same default is not a change; a direct write to the stamp is overwritten, null or set |
| S5 | clearing the default is stamped |
| S6 | on insert the stamp follows the default, whatever the writer supplies |
| S7 | a writer with no grant on `users` still gets the stamp |

Mutation-checked: dropping the keep-old branch (S4b), stamping every insert (S2a),
leaving the stamp column out of the trigger's column list (S4b), `clock_timestamp()`
for `now()` (S2c), and `<>` for `is distinct from` (S2c) each fail the suite.

### `client-write-policies/`

Covers `migrations/20261005000000_drop_client_write_policies.sql`, which drops the three
policies that let a signed-in caller write `users` and `api_keys` through PostgREST. The
fixture carries every policy production holds on both tables and the hosted bodies of
`auth.jwt()`, `auth.uid()` and `auth.role()`, so callers are set up the way PostgREST
sets them up. Port 55438.

| | assertion |
|---|---|
| W1 | a new Supabase Auth account cannot create its own `users` row |
| W2 | an account planted before the migration cannot insert a key row, even naming a real org |
| W3 | nor rewrite the key row it holds; the stored row is unchanged |
| R1 | an account still reads its own `users` row and its own key, and no other |
| R2 | the `auth_user_links` read path still resolves |
| S1 | the service role still inserts a user and a key and updates it |
| C1 | the write policies left on the two tables are exactly `service_role_full_access` and `Users can update own data` |
| Z1 | at rest, nothing was added or changed |

Mutation-checked: a no-op migration fails W1 — without the migration the insert goes
through. Dropping only the `users` policy fails W2; leaving
`users_update_own_keys` fails W3a; also dropping `users_read_own_keys` (R1b),
`users_view_own_api_keys` (R2) or `Users can update own data` (C1), or revoking the
service role's insert grant (S1), each fails the suite.

### `retire-user-profiles/`

Covers `migrations/20261006000000_retire_user_profiles.sql` (CR61 step 7), which drops the
legacy `user_profiles` table, the `handle_new_user` trigger on `auth.users` that fed it, the
`user_details` view that joined it, and `users`' last client write policy. The fixture
reuses `client-write-policies/`'s with that migration applied, then adds the four objects as
production holds them (the trigger function verbatim). Port 55439.

| | assertion |
|---|---|
| T1 | table, view, trigger function and trigger are all gone |
| T2 | an `auth.users` insert still succeeds, with no trigger left on the table |
| W1 | the account that planted its own `users` row can no longer edit it; the row is unchanged |
| R1 | an account still reads its own `users` row and its own key, and no other |
| R2 | the `auth_user_links` read path still resolves |
| S1 | the service role still inserts a user and a key and updates it |
| C1 | **the invariant:** no write policy in `public` is usable by a non-service caller — the same query `scripts/check-migration-replay.sh` now runs after every replay |
| C2 | `users` keeps exactly its three read policies |
| Z1 | at rest, nothing was added or changed |

Mutation-checked: a no-op migration fails T1a; keeping the `users` policy fails W1a; keeping
the trigger and function fails T1c; dropping `users_read_own_keys` fails R1b; revoking the
service role's insert grant fails S1; adding a client write policy on another table fails C1.
`drop table … cascade` in place of the explicit view drop is an equivalent mutant and passes.

### `auth0-read-policies/`

Covers `migrations/20261007000000_auth0_sub_read_policies.sql` (CR62 step 3), which replaces
every `auth.uid()` read policy — 22 policies on 13 tables, plus `user_ancestor_org_ids()` —
with one policy per table over `current_app_user_id()` (an Auth0 subject via
`users.auth0_id`, a Supabase Auth uuid via `auth_user_links`) and
`current_user_org_ids(roles)`, together with its follow-up
`20261007010000_resolvers_revoke_anon_execute.sql` (the harness's `FOLLOWUPS`). The fixture
chains `retire-user-profiles/` with its migration applied, adds the nine other tables with
production's policies verbatim, sets the hosted project's default function privileges, and
**pre-checks that a read under an `auth0|…` subject raises 22P02 before the migration**, so a
fixture that is not production's shape fails before proving anything. Port 55440.

| | assertion |
|---|---|
| A1 | an Auth0 subject reads its own rows on `users`, `api_keys`, `user_roles`, `user_activity`, `organization_memberships`, and no other |
| A2 | org-scoped tables answer for the active membership only; a suspended membership grants nothing; the ancestor walk reaches the parent org |
| A3 | role narrowing: an admin reads `audit_log` but not `billing_event_log`; a plain member reads neither |
| A4 | a Supabase Auth uuid subject still resolves through `auth_user_links` |
| A5 | a uuid subject with no bridge row resolves to nobody, even when a `users` row carries that uuid as `auth0_id` |
| A6 | a stranger's token reads no private row on any of the 13 tables and raises nothing; `plans` and `roles` still answer |
| A7 | `anon` reads only the public tables and cannot execute either resolver |
| A8 | the write side is as CR61 left it: no update to `users`, no key insert, no membership self-promotion |
| S1 | the service role still reads everything |
| C1 | no policy and no function in `public` calls `auth.uid()` — also asserted by `scripts/check-migration-replay.sh` after every replay |
| C2 | every private read policy is `to authenticated`; the public reads stay public |
| C3 | the CR61 invariant still holds |
| C4 | both resolvers are `security definer`, `search_path = ''`, executable by `authenticated` and `service_role` only |
| Z1 | at rest, nothing was added or changed |

The first run caught a real defect: as a `sql` function the resolver was inlined, the planner
pulled the claim subquery up and evaluated `sub::uuid` as an init-plan before `CASE` chose an
arm, so an Auth0 subject still raised 22P02. It is `plpgsql` for that reason. The production
push then showed what the suite had missed: `anon` still held EXECUTE on both resolvers
(trap 5 below); the follow-up migration revokes it, and with the default privileges in the
fixture the first migration alone now fails A7d, as production did.

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

**5. Hosted Supabase grants EXECUTE on new functions to `anon`, `authenticated` and
`service_role` by default privilege, on top of PostgreSQL's grant to `PUBLIC`.** A migration
that does `revoke … from public; grant … to authenticated, service_role` leaves `anon`'s
explicit grant in place there, while a bare local cluster has no such default and the
suite reads "authenticated+service_role" — measured on 2026-10-06 after `20261007000000`
pushed. A fixture that creates the API roles must also run
`alter default privileges for role <owner> in schema public grant execute on functions to
anon, authenticated, service_role`, or every grant assertion is weaker than production.

Prefer assertions that compare against an expected set (`assert_visible`) over
ones that print rows for a human to eyeball; the latter is how a bypassed-RLS
run looks correct.
