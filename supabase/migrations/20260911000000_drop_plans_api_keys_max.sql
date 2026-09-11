-- AUTH-PER-USER-QUOTAS gap 5 (observability-toolkit backlog): the per-tier API
-- key limit was declared in two places that disagreed, and only one was read.
--
--   plans.features.api_keys_max          starter 1, growth 10, enterprise null
--   api-provisioning-receiver QUOTA_LIMITS starter 3, growth 10, enterprise unlimited
--
-- The receiver's table is the one enforced (checkOrgKeyQuota, unit- and
-- integration-tested) and is what production reflects: on 2026-09-11 two starter
-- orgs each held 2 active keys, which the seed's "1" would have forbidden. Nothing
-- in this repo, the receiver, or the dashboard reads features.api_keys_max.
--
-- Remove the unread number so the JSON cannot contradict the enforced limit.
-- QUOTA_LIMITS in services/api-provisioning-receiver/src/types.ts (observability-
-- toolkit) is now the single home; change it there and nowhere else.
--
-- Row-keyed, not tier-keyed, on purpose: the phase-1 seed inserted the first tier
-- as 'free' and production holds it as 'starter' with no migration recording the
-- rename, so a replayed database and production disagree on that key. This strips
-- the field from whichever row exists.

update public.plans
   set features = features - 'api_keys_max'
 where features ? 'api_keys_max';

comment on column public.plans.features is
  'Feature flags per plan. Does NOT carry the API key quota — that is QUOTA_LIMITS in api-provisioning-receiver (observability-toolkit repo), removed from here 2026-09-11.';
