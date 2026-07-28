-- Enable RLS on the three server-only webhook tables.
--
-- 20260321000000 omitted RLS on webhook_dead_letters and webhook_events_log on
-- the grounds that only the service-role key touches them. That reasoning does
-- not hold: PostgREST exposes every table in the public schema, so RLS-off means
-- the publishable anon key can read them. Verified against production — an anon
-- GET on all three returned HTTP 200. webhook_dead_letters stores the complete
-- Stripe event payload, so this is a disclosure path for customer billing data
-- as soon as the webhook processes its first event.
--
-- No policies are defined, deliberately. RLS enabled with zero policies denies
-- anon and authenticated everything, while service_role bypasses RLS and is
-- unaffected. The only readers are workers/stripe-webhook/src/{index,supabase}.ts,
-- which authenticate with the service-role key.

alter table public.webhook_dead_letters enable row level security;
alter table public.webhook_events_log enable row level security;
alter table public.stripe_events enable row level security;
