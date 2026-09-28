-- Give the enterprise plan a self-serve Stripe price (CR38, 2026-09-27).
--
-- Owner decision: enterprise is $50 per user per month with a minimum of six users.
-- The live price is graduated-tiered: a flat $300 covers the first six users and each
-- further user is $50. The tier, not checkout, is what enforces the minimum: the live
-- Customer Portal allows quantity changes, and a quantity cut below six still bills $300.
-- Checkout opens at six seats (PLAN_MIN_SEATS in workers/lib/billing.ts) so the recorded
-- quantity matches the bill.
--
--   product  prod_VLAHKmFFGaNWpO  observability-toolkit-enterprise  metadata.plan_key=enterprise
--   price    price_1UKTwYAwEfePbhfkAS5HUuqk  usd, monthly, licensed, unit_label "user"
--
-- 20260731020000 left enterprise NULL because it had no Stripe product. A non-null price
-- is what makes api-gateway's POST /v1/orgs/:id/checkout-session sell the plan; no code
-- keys on the tier name. Contract-billed enterprise orgs remain valid:
-- 20260731030000's exemption keys on current_plan, not on this column.

update public.plans
   set stripe_price_id = 'price_1UKTwYAwEfePbhfkAS5HUuqk'
 where key = 'enterprise';
