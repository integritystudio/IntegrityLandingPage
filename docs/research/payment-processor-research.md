# Payment Processor & Billing Architecture Research

> **Research record — implemented.** The Stripe/Auth0/Supabase B2B billing architecture proposed here shipped across the API provisioning workers and the service-binding architecture (see changelog 1.2/1.3). Condensed from the original proposal; see [changelog 1.3](../changelog/1.3/CHANGELOG.md) "Superseded Design-Doc Reconciliation".

**Original date:** 2026-07-12 (pre-implementation) · **Domain:** Billing architecture

---

## Recommendation

For Integrity Studio as a B2B SaaS, shape the product as a **web-billed subscription with a companion Flutter app**, not a store-native (App Store/Play) subscription. The product is a recurring-revenue, SMB-focused observability/compliance layer added into an existing stack — this favors Stripe web billing over mobile IAP.

## High-level architecture

```text
Flutter app
  ├─ Supabase OAuth sign-in
  ├─ Session handling
  ├─ Companion dashboard / alerts / usage / billing status
  └─ Calls Integrity API with short-lived app session + org-scoped API key metadata

Web billing
  ├─ Stripe Checkout / Billing / Customer Portal
  └─ Subscription lifecycle via Stripe webhooks

Cloudflare edge
  ├─ API gateway Worker
  ├─ Rate limit bindings by tier
  ├─ API key verification / JWT verification
  ├─ Durable Object for strong-consistency quota mutations
  └─ Routing to internal services

Core backend
  ├─ Provisioning Worker / service
  ├─ Entitlements service
  ├─ Usage ingest service
  ├─ Billing sync service
  └─ Admin/reporting APIs

Supabase
  ├─ Auth (OAuth), Postgres (users/orgs/usage/entitlements mirror)
  ├─ RLS policies
  └─ Database Webhooks / Auth Hooks

Stripe
  ├─ Customers, Subscriptions, Prices, Customer Portal, Webhooks
```

## Core design decision: two auth layers

1. **Human identity layer — Supabase OAuth session.** Answers "who is the person?" Uses OAuth + JWT sessions, RLS for row-level Postgres access.
2. **Machine access layer — org-scoped API keys.** Answers "what client/app/integration is calling the API?" Cloudflare Worker rate limiting is keyed on stable identifiers (API key / user ID / tenant ID), not IPs.

The Flutter app authenticates the user via Supabase, then fetches an **org-scoped capability token/API key reference** from the backend for the active workspace. This gives plan-backed limits, per-org usage metering, clean revocation, and consistent edge enforcement — cleaner than a single "auth backed by API key" model:

- **User authentication:** Supabase OAuth session
- **Request authorization + rate-limit identity:** API key / capability token
- **Billing authority:** Stripe
- **Usage authority:** Durable Object + Supabase ledger

## Data model

Stripe is the source of truth for billing events; Supabase/Postgres is the source of truth for app entitlements, usage, and authorization.

```sql
organizations, users, organization_memberships, plans,
subscriptions, subscription_items, entitlements,
api_keys, api_key_rollups, usage_events, usage_buckets_daily,
provisioning_jobs, billing_event_log, audit_log
```

Key fields:
- `organizations`: `stripe_customer_id`, `active_subscription_id`, `billing_status`, `current_plan`, `quota_version`
- `subscriptions`: `stripe_subscription_id`, `organization_id`, `status`, `current_period_end`, `cancel_at_period_end`
- `entitlements`: `organization_id`, `feature_key`, `enabled`, `hard_limit`, `soft_limit`
- `api_keys`: `id`, `organization_id`, `key_prefix`, `key_hash`, `status`, `scopes`, `last_used_at`, `created_by_user_id`
- `usage_events`: `organization_id`, `user_id?`, `api_key_id?`, `metric_key`, `quantity`, `source`, `request_id`, `created_at`

This split matters because Stripe only answers "is the customer entitled to service" — the product needs app-specific concepts (seats, metrics, quotas, feature flags) driven off webhooks (`invoice.paid`, `invoice.payment_failed`, `customer.subscription.updated`).

## Auth and provisioning flow

**Sign-in:** Flutter → Supabase OAuth → JWT session → `POST /bootstrap` → backend resolves user profile, org memberships, plan, entitlements, usage snapshot, API key metadata for the selected org.

**Provisioning:** Use Supabase Database Webhooks / Auth Hooks (async, fire on INSERT/UPDATE/DELETE) to trigger a Cloudflare Worker provisioning endpoint on first user/profile insert. That Worker creates the org-user mapping if missing, default entitlements for new orgs, an initial API key record, and audit logs.

**JWT customization:** Use a Supabase Custom Access Token Hook to add compact, stable claims (`org_ids`, `default_org_id`, `plan`, `role`, `billing_status`). Do **not** put mutable quota counters into the JWT — anything dynamic (remaining credits, current-minute usage) is checked server-side.

## API key strategy

Two key classes:
1. **Interactive mobile capability key** — short-lived, minted by backend after Supabase auth, used by Flutter for companion-app calls.
2. **Long-lived org integration keys** — used by customer systems/agents; revocable, scoped, rotated, tied to org + quota policy.

Store `key_prefix` in plaintext, `key_hash` in DB, never the full key after creation. Format: `int_live_org_abcd1234_xxxxxxxxx`.

At the Worker edge: parse prefix → lookup key record → verify hash → attach org context → apply rate-limit binding for plan tier → forward only normalized identity headers internally.

## Rate limiting and quota enforcement

The most important edge design choice — three tiers of enforcement, each fit to what it's good at:

- **Cloudflare rate limiting** — fast edge throttling for per-minute bursts and tier request ceilings. Fast and local, but scoped to a single Cloudflare location and **not an accurate accounting system**.
- **Durable Objects** — strong-consistency quota mutation (monthly counters, exact seat increments, serialized writes, plan-change cutovers). One DO **per organization** since quotas, plan changes, and API keys are all org-scoped; DOs maintain `quota_version`, short-lived in-memory counters, persist authoritative counters to storage, reject over-quota calls, and periodically flush rollups to Supabase.
- **Workers KV — not used as source of truth for usage.** KV is eventually consistent (writes can take ~60s+ to propagate).

Request path:
```text
Request enters Worker
  -> verify JWT and/or API key
  -> apply Cloudflare tier rate limiter
  -> call org Durable Object for precise quota check/reservation
  -> if allowed, proxy request
  -> async write usage event to Supabase
```

Suggested tiers: `free` (60 rpm / 1 concurrent job / 10k monthly units), `growth` (600 rpm / 5 / 500k), `enterprise` (3000 rpm / 25 / custom).

## Billing and entitlement sync

Web billing uses Stripe Checkout + Subscriptions + Customer Portal. Events consumed: `checkout.session.completed`, `invoice.paid`, `invoice.payment_failed`, `customer.subscription.updated`, `customer.subscription.deleted` — driven by webhooks since billing state changes asynchronously.

```text
Stripe webhook -> Billing sync Worker
  -> verify event
  -> upsert subscription state
  -> recompute plan + entitlements
  -> bump organization.quota_version
  -> notify Durable Object / cache invalidation
  -> write audit + billing event log
```

Keep a materialized `entitlements` table in Supabase so Flutter can render plan state without querying Stripe directly.

## Supabase storage model and RLS

Enable RLS on all exposed schemas — tables in `public` without RLS are accessible to the public role. Keep customer-visible app tables in `public` with strict RLS; keep sensitive service tables in a restricted schema; use service-role access only from Workers/backends.

Example: users can read usage for orgs they belong to via an `organization_memberships` membership check keyed on `auth.uid()`. JWT claims (`default_org_id`, `plan`) can inform policies, but the DB membership table remains the final authority.

## Provisioning architecture (Cloudflare Workers)

Provisioning Worker endpoints: `POST /internal/provision/user-created`, `POST /internal/provision/user-updated`, `POST /internal/provision/subscription-updated`. Triggered by Supabase Database Webhooks (`profiles`/`organization_memberships`) and Stripe webhooks. Worker responsibilities: idempotent upsert, create missing org profile, assign default role, create/revoke API key grants, refresh entitlement projection, update `quota_version`, emit audit event.

## Flutter app scope

Dashboard, org switcher, usage summaries, alerts/incidents, compliance status summaries, billing status with "manage billing on web" (no in-app billing management).

Flow: Supabase OAuth sign-in → session JWT → `POST /bootstrap` via Worker → Worker verifies JWT → backend returns orgs/entitlements/usage snapshot → app stores active org → app calls APIs with Bearer JWT + org header → Worker resolves org, attaches capability context, enforces limits. The app should not depend on a raw long-lived API key stored on device — the Worker mints short-lived org capability tokens as needed.

## Security rules

- Supabase OAuth for user auth, not custom password auth.
- RLS enabled on all exposed Supabase tables.
- API keys are capability credentials only, never user identity.
- Only stable claims in JWTs (via Supabase hooks) — no mutable counters.
- Cloudflare Rate Limiting for fast throttling only, not billing-grade accounting (local/permissive).
- Durable Objects, not KV, for authoritative counters (KV is eventually consistent).
- Entitlements driven from Stripe webhooks (billing state is asynchronous).
- Log every request with `request_id`, `org_id`, `user_id`, `api_key_id`, route, rate-limit result, quota result, units charged, upstream latency, `stripe_subscription_id` snapshot, `quota_version` for billing-grade auditability.

## Delivery sequencing (as originally scoped)

1. **Foundational:** Stripe web billing, Supabase OAuth, Cloudflare Worker gateway, one Durable Object per org, Supabase usage + entitlement tables, Flutter companion app (dashboard/alerts/billing status).
2. **Self-service:** org API key self-service, Customer Portal deep links from web, richer per-feature quota families, provisioning from Supabase DB webhooks.
3. **Scale-out:** seat billing, usage-based add-ons, enterprise SSO/SCIM, per-integration API key policies.
