-- Correct organizations whose billing_status claims a subscription that does not exist,
-- then prevent the state from recurring.
--
-- Found 2026-07-31 from a user-reported 404: the billing page for "InventoryAI" displayed
-- "active / starter" while the row held stripe_customer_id = null, active_subscription_id
-- = null, and zero rows in subscriptions. Per CR28, 'inactive' is our own value for "no
-- Stripe subscription exists" — Stripe cannot express it, because a status presupposes a
-- subscription object.
--
-- Enterprise is deliberately exempt, and the exemption is load-bearing rather than
-- defensive. plans.stripe_price_id is null for 'enterprise' (custom pricing, no Stripe
-- product), so an enterprise organization is legitimately active while billed by invoice
-- with no Stripe customer at all. "Integrity Studio AI" is in exactly that state; a
-- constraint without this branch would reject it, and the accompanying UPDATE would
-- silently downgrade a real paying customer to 'inactive'.
--
-- The constraint is safe against every write path in stripe-webhook, checked rather than
-- assumed: checkout.session.completed calls linkStripeCustomer (which sets
-- stripe_customer_id) before any status write, and every billing_status update in
-- handlers/invoice.ts and handlers/subscription.ts resolves its organization through
-- findOrgByStripeCustomerId. A non-inactive status can therefore only ever be written to
-- a row that already carries a customer id. Neither bad row came from the webhook — both
-- predate any real Stripe traffic on this account.
--
-- billing_status and current_plan are both NOT NULL (20260320000000), so the predicate
-- has no three-valued-logic hole where a NULL would pass the check unevaluated.

update public.organizations
   set billing_status = 'inactive',
       updated_at = now()
 where stripe_customer_id is null
   and active_subscription_id is null
   and billing_status <> 'inactive'
   and current_plan <> 'enterprise';

alter table public.organizations
  add constraint organizations_billing_status_requires_customer
  check (
    billing_status = 'inactive'
    or stripe_customer_id is not null
    or current_plan = 'enterprise'
  );
