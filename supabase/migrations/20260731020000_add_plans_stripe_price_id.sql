-- Link the plan catalog to Stripe.
--
-- Before this, the mapping was one-directional: Stripe products and prices carry a
-- `metadata.plan_key` tag, so Stripe -> plan key resolved, but nothing in Postgres
-- answered "which price backs the starter plan?". Callers had to query the Stripe API
-- and filter on metadata, or hardcode the id. `subscriptions.stripe_price_id` was no
-- substitute: it records what an org was actually charged, not what a plan costs.
--
-- Only recurring prices are eligible — a one-time price cannot back a subscription.
-- The growth product also has a $79 one-time price (price_1Ty247AwEfePbhfkCzMuiAwP)
-- which is deliberately NOT referenced here.
--
-- enterprise stays NULL on purpose: it has no Stripe product, and its plans row has
-- NULL monthly_units/requests_per_minute/concurrent_jobs, i.e. custom, sales-led pricing.

alter table public.plans
  add column stripe_price_id text;

comment on column public.plans.stripe_price_id is
  'Recurring Stripe price backing this plan. NULL when the plan has no self-serve price.';

update public.plans set stripe_price_id = 'price_1Tz7OcAwEfePbhfkWsvaOxF3' where key = 'starter';
update public.plans set stripe_price_id = 'price_1TxypvAwEfePbhfkeG9iUvTf' where key = 'growth';
