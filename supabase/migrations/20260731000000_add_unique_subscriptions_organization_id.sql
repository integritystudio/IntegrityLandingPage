-- Enforce one subscription row per organization.
--
-- The stripe-webhook Worker upserts subscriptions with ON CONFLICT (organization_id).
-- Postgres requires a unique or exclusion constraint matching the ON CONFLICT target;
-- without one it raises 42P10 and the event is dead-lettered. The first real
-- customer.subscription.updated event (2026-07-31) failed exactly this way:
--   "there is no unique or exclusion constraint matching the ON CONFLICT specification"
--
-- Note the tradeoff this locks in: an organization can now hold at most one
-- subscriptions row, so replacing a subscription overwrites the previous record
-- rather than retaining history. The alternative was to conflict on
-- stripe_subscription_id (already UNIQUE), which would preserve history.

alter table public.subscriptions
  add constraint subscriptions_organization_id_key unique (organization_id);
