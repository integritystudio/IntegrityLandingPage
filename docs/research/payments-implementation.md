# SaaS Auth/Billing/Provisioning — Design Record

> **Research record — implemented.** The V02 dashboard + Stripe Customer Portal work shipped (`POST /v1/orgs/:id/billing-portal`, 7 tests). Condensed from the original; see [changelog 1.3](../changelog/1.3/CHANGELOG.md) "Superseded Design-Doc Reconciliation".

**Original date:** 2026-03-21 · **Domain:** Payments / SaaS provisioning architecture

---

## What shipped

This document designed, and the implementation delivered, Integrity Studio's SaaS companion-app model:

- **Sender-Worker UI** — AuthPage, ProvisionPage, SenderHealthPage; JWT-based provisioning flow with HMAC-SHA256 signing and environment-aware CORS.
- **Bootstrap + Stripe-webhook workers** — JWT verification → org/membership/entitlement/usage context; Stripe signature verification → subscription/invoice sync; shared Zod schemas and HTTP utilities (`workers/lib/`).
- **API gateway** — full `/v1/*` route set (below), per-org Durable Object quota enforcement, usage ingestion + daily/monthly rollups.
- **Flutter dashboard (V02)** — org switcher, billing status, usage summary + charts, quota/entitlements views, real-time polling, and a Stripe Customer Portal deep link (`POST /v1/orgs/:id/billing-portal`).
- **Audit logging** — `api_key.created`, `api_key.revoked`, `billing_portal.accessed` written to `audit_log`, with failures caught and never propagated to the caller.
- **Rate-limit visibility** — `X-RateLimit-Remaining-Minute` / `-Monthly` headers forwarded on successful org responses; fail-open path omits headers rather than blocking.

## Architecture overview

**System shape:**

* **Auth0** = human identity truth (OAuth, SAML, MFA, compliance)
* **Stripe** = billing truth, synced via webhooks (never trust frontend checkout success alone)
* **Cloudflare Worker + Durable Object** = request authorization, tier enforcement, quota coordination
* **Supabase Postgres** = product truth (orgs, entitlements, usage ledger, audit history) — mirrors Auth0, is not auth truth itself
* **Flutter** = dashboard/alerts/usage/account-status UI, not the primary billing surface

Rationale: Stripe subscription events are asynchronous and must be handled by webhooks; Auth0 provides enterprise identity features (SAML/LDAP/MFA) that Supabase Auth alone doesn't; Workers verify JWTs from Auth0 rather than trusting Supabase directly.

## Postgres schema (Supabase)

Core entity groups, all with RLS enabled:

- **Identity**: `users` (mirrors Auth0 via `auth0_id`), `user_profiles`, `user_activity` (audit trail), `user_sessions` (device/geo fingerprinting), `auth_user_links` (bridge table for gradual Supabase Auth → Auth0 migration — set to null once migration completes).
- **Organization**: `organizations` (billing_status, current_plan, quota_version), `organization_memberships` (role: owner/admin/member/billing_admin/viewer), `roles` + `user_roles` for finer-grained RBAC than membership role alone.
- **Billing**: `plans`, `subscriptions` (mirrors Stripe subscription), `entitlements` (feature flags + hard/soft limits per org), `billing_event_log` (raw Stripe webhook payloads, deduped by `stripe_event_id`).
- **API/usage**: `api_keys` (bcrypt/Argon2 hash, org-scoped prefix uniqueness), `usage_events` (per-request ledger), `usage_buckets_daily` (rollup).
- **Async work**: `provisioning_jobs` — tracks all cross-system side effects (`user_created`, `membership_changed`, `subscription_changed`, `entitlements_recomputed`, `quota_version_bumped`) with `dedupe_key`, `retry_count`/`max_retries`, and `status`.
- **Audit**: `audit_log` — actor (user or API key), action, target, old/new values.
- **Analytics integrations**: `analytics_projects`, `provider_oauth_tokens` (GA4/Facebook Pixel/Google Ads OAuth via Supabase Vault).

Key design notes:
- Every mutable table gets a shared `update_updated_at_column()` trigger.
- `api_keys.organization_id` is denormalized onto the key row (not resolved via `users`→`memberships`) for RLS performance and per-org prefix uniqueness — verification becomes a single indexed lookup by `(organization_id, prefix)`.
- RLS policies link to `users(id)` via `organization_memberships`, **not** directly to `auth.users`, so API-key auth (no `auth.uid()`) still works through `api_keys.user_id`. Service-role access is reserved for Stripe webhook sync, provisioning jobs, usage aggregation, API key management, audit writes, and analytics integrations.

## Auth0 identity model

Auth0 Actions enrich the JWT before issuance with `default_org_id`, `org_roles` (map of org_id → role), `plan_key`, `billing_status`. **Mutable usage counters must never go in JWTs** — those live in the Worker/Durable Object path only (see the JWT compliance research record for the fuller claims analysis).

Sync flow: Auth0 signup → Auth0 webhook → Worker verifies signature → creates/updates `users` row by `auth0_id` → creates default org + membership on first signup → writes a `provisioning_jobs` entry (deduped) for background processing. This keeps Auth0 as identity truth, Supabase as product truth, and the Worker enforcing both via JWT verification + RLS.

## Provisioning flow

Supabase Database Webhooks (fire on INSERT/UPDATE/DELETE) trigger Worker provisioning. Every event carries a `dedupe_key` (e.g. `supabase:users:INSERT:<user_id>:<created_at>`, `stripe:customer.subscription.updated:<subscription_id>:<event_timestamp>`) so the DB unique constraint guarantees exactly-once processing. Transient failures increment `retry_count` (exponential backoff, capped by `max_retries`); permanent failures (validation error, 4xx) go straight to `status=failed` for manual intervention.

## Worker route map

```text
# Human-authenticated (Bearer JWT)
GET    /v1/me
GET    /v1/orgs
GET    /v1/orgs/:orgId/dashboard
GET    /v1/orgs/:orgId/billing-status
GET    /v1/orgs/:orgId/usage/summary
GET    /v1/orgs/:orgId/entitlements
POST   /v1/orgs/:orgId/api-keys
POST   /v1/orgs/:orgId/api-keys/:keyId/revoke
POST   /v1/orgs/:orgId/billing-portal

# Machine-authenticated (API key, org-scoped)
POST   /v1/ingest/events
POST   /v1/ingest/otel

# Internal (HMAC-signed service token or IP allowlist)
POST   /internal/stripe/webhook
POST   /internal/provision/user-created
POST   /internal/provision/membership-changed
POST   /internal/usage/flush
```

Edge pipeline: verify JWT/API key → resolve org context → load plan/entitlements/quota version → Cloudflare rate limiter for burst control → org Durable Object for the exact quota decision → proxy or reject → emit usage event via `waitUntil`.

## Durable Object design

**One Durable Object per organization** — DOs are strongly-consistent, single-threaded, globally-unique instances, which is what serialized quota mutations need. Responsibilities: cache org quota/plan state, serialize quota checks, track current-minute and monthly counters, reject over-limit requests, expose `checkAndReserve()` / `flushUsage()`.

```ts
type QuotaCheckRequest = { orgId: string; metricKey: string; units: number; requestId: string; planKey: string; quotaVersion: number };
type QuotaCheckResponse = { allowed: boolean; reason?: "minute_limit" | "monthly_limit" | "feature_disabled"; remainingMinute?: number; remainingMonthly?: number | null };
```

**Cloudflare rate-limiter bindings are burst control only** — Cloudflare documents them as permissive and eventually consistent, not accurate accounting. **Workers KV is never the source of truth for quota/billing** — KV is eventually consistent (stale reads possible for up to the cache TTL); use it only for soft metadata cache, non-critical config, short-lived derived artifacts.

## Stripe sync model

Web billing only (Checkout / Billing / Customer Portal) — matches a recurring-revenue SMB motion and keeps billing on the web side. Events consumed: `checkout.session.completed`, `invoice.paid`, `invoice.payment_failed`, `customer.subscription.updated`, `customer.subscription.deleted`. Stripe recommends webhooks over trusting frontend success for exactly this reason (async state).

```text
Stripe webhook -> verify signature -> write billing_event_log -> upsert subscriptions
  -> update organizations.billing_status/current_plan -> recompute entitlements
  -> increment organizations.quota_version -> enqueue cache invalidation / DO refresh
```

## Plan → entitlement projection

| Plan | usage_dashboard | alerts | compliance_summary | api_keys_max | monthly_units | requests_per_minute |
|---|---|---|---|---|---|---|
| free | ✓ | ✓ | — | 1 | 10,000 | 60 |
| growth | ✓ | ✓ | ✓ | 10 | 500,000 | 600 |
| enterprise | ✓ (all features) | ✓ | ✓ | custom | custom | custom |

Ties visible cost/data usage back into pricing and contract decisions rather than exposing opaque technical metrics.

## API key model

Keys are for **authorization + quota identity**, not login. User-owned, inherit org context via membership.

- Format: `int_live_<prefix>_<secret>` — `prefix` plaintext (display + lookup), `secret` bcrypt/Argon2-hashed (never stored plaintext).
- Fields: `tier`, `status` (`active`/`revoked`/`expired`), `expires_at` (nullable), `last_used_at`, `revoked_at`.
- Verification: extract prefix from token → look up by `(organization_id, prefix)` (org id from `X-Org-ID` header, fast indexed lookup) → compare secret hash → resolve user/org/entitlements.
- Rules: revocable, optional expiry, soft-deleted via status, audited on create/use/revoke.

## `/bootstrap` contract

First call the Flutter app makes after sign-in. Returns user identity, all orgs (with role/plan/billing_status per org), the active org id, resolved entitlements, and a usage snapshot (month-to-date units, current-minute remaining). Flutter startup sequence: check session → if present, `POST /bootstrap` → cache org list + active org + entitlements → route to dashboard. Org switch refetches `/v1/orgs/:orgId/dashboard` and `/usage/summary` so the Worker enforces the newly-selected org's entitlements immediately.

Auth0 variant: Flutter obtains an Auth0 JWT via `auth0_flutter`, calls `/bootstrap` with `Authorization: Bearer <jwt>` + `X-Auth0-ID`; the Worker verifies the JWT (JWKS), looks up (or provisions, via a `user_created` job) the `users` row by `auth0_id`, and returns the same bootstrap shape.

## Sequence summaries

- **User provisioning**: Auth0 signup/OAuth → webhook to Worker → verify signature → create `users`/`user_profiles`/default org+membership → write `provisioning_jobs` entry → audit log entry → return JWT enriched with org_id + org_roles.
- **Subscription update**: Stripe event → Worker verifies signature → upsert subscription → recalc entitlements → `organizations.quota_version += 1` → notify org Durable Object.
- **Metered request**: client → Worker → JWT/API-key verification → rate-limiter binding → DO `checkAndReserve()` → upstream handler → append `usage_events` → async daily rollup.

## What the Flutter app shows

Dashboard summary, alert inbox, plan/billing state, usage-against-quota, integration health, compliance-summary snapshots, org switching, and (for admins) API key management — the surface area that makes system behavior legible to non-technical stakeholders, per the internal push for a comprehensible usage/cost UI.
