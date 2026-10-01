-- Fixture for the default-org-set-at migration test.
--
-- Reuses the CR50 suite's fixture (tables, seed rows, the UA04 tier triggers and
-- the `membership_writer` role), then applies the CR50 migration itself, so the
-- stamp is tested against the trigger that sets most defaults. Seed rows exist
-- before the migration under test runs, as production's do.

\ir ../default-org-from-membership/fixture.sql
\ir ../../migrations/20260929010000_default_org_from_first_membership.sql
