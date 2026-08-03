-- CR30 part 4: two columns production has on `organizations` that the ledger
-- never adds. `create table organizations` (20260320000000) declares 10 of
-- production's 13; parent_organization_id arrived via 20260731010000, and
-- `domain` + `type` arrived out of band. Sorts here because 20260731010000
-- READS `type` -- placing this later fails with `column "type" does not exist`.
-- Idempotent, so it is a no-op against production.

alter table public.organizations
  add column if not exists domain text,
  add column if not exists type public.organization_type not null default 'personal'::public.organization_type;

create unique index if not exists organizations_team_domain_unique
  on public.organizations using btree (domain) where (type = 'team'::public.organization_type);

