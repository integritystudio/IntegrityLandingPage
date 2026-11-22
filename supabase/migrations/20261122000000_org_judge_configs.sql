-- An org's specified judge (observability-toolkit docs/roadmap/judge-model-tiers.md, Phase 4):
-- the provider and model it names, and the AI Gateway BYOK alias that holds its key.
--
-- The key itself never lands here. The provisioning receiver
-- (observability-toolkit services/api-provisioning-receiver, action set_judge_config) stores
-- it in the gateway's Secrets Store through a provider config and keeps only that config's
-- alias and id, so a judge request can name the alias in `cf-aig-byok-alias`. No row means
-- the org has no specified judge: the hosted runner must refuse rather than fall back.
--
-- Written only by the receiver and read by the dashboard worker, both with the service role,
-- so anon and authenticated get nothing (hosted default privileges grant them every new
-- table in public; 20261007010000).

create table public.org_judge_configs (
  organization_id uuid primary key references public.organizations(id) on delete cascade,
  provider text not null check (provider in ('anthropic', 'openai')),
  model text not null check (model ~ '^[a-z0-9][a-z0-9.:-]{0,127}$'),
  byok_alias text not null check (byok_alias ~ '^[a-z0-9-]{1,64}$'),
  provider_config_id text not null,
  key_preview text,
  updated_by uuid references public.users(id) on delete set null,
  updated_at timestamptz not null default now()
);

alter table public.org_judge_configs enable row level security;
revoke all on table public.org_judge_configs from anon, authenticated;
grant select, insert, update, delete on table public.org_judge_configs to service_role;
