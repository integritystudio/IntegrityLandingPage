Absolutely. Here's a concrete v1 architecture for **Integrity Studio's SaaS companion-app model**, customized for:

* **web-billed Stripe subscriptions**
* **Cloudflare Workers** as the edge/API gateway
* **Supabase Auth + Postgres** for users, orgs, usage, and entitlements
* **API-key-backed authorization and tier rate limits**
* **Flutter** as the authenticated companion app, not the primary billing surface

This shape matches the internal direction toward a recurring-revenue SMB product, a plugin/integration motion into observability/compliance stacks, and a UI/dashboard that makes the system legible to non-technical users. It also fits the company's existing emphasis on secure Cloudflare tunnels, monitoring, cost/data tracking, and authentication between many services.

## 1. Target system shape

The cleanest split is:

* **Stripe** = billing truth
* **Supabase Auth** = human identity truth
* **Cloudflare Worker + Durable Object** = request authorization, tier enforcement, quota coordination
* **Supabase Postgres** = product truth for orgs, entitlements, usage ledger, audit history
* **Flutter** = dashboard / alerts / usage / account status UI

That separation is important because Stripe subscription events are asynchronous and should be handled by webhooks, not by trusting frontend success alone. Stripe explicitly recommends webhooks for subscription lifecycle handling and exposes Customer Portal for customer self-service billing management. ([Stripe Docs][1])

## 2. Postgres schema

I'd use Supabase Postgres for the app/system model and keep billing-derived state projected into it. Supabase Auth supports OAuth sessions and JWT-based auth, and RLS should be enabled on exposed tables. Supabase also warns not to expose the service role key in frontend clients. ([Supabase][2])

### Core tables

```sql
create table organizations (
  id uuid primary key default gen_random_uuid(),
  slug text unique not null,
  name text not null,
  stripe_customer_id text unique,
  active_subscription_id uuid,
  billing_status text not null default 'inactive',
  current_plan text not null default 'free',
  quota_version bigint not null default 1,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  email text not null,
  full_name text,
  default_organization_id uuid references organizations(id),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table organization_memberships (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references organizations(id) on delete cascade,
  user_id uuid not null references profiles(id) on delete cascade,
  role text not null check (role in ('owner','admin','member','billing_admin','viewer')),
  status text not null default 'active' check (status in ('active','invited','suspended')),
  created_at timestamptz not null default now(),
  unique (organization_id, user_id)
);

create table plans (
  key text primary key,
  display_name text not null,
  monthly_units bigint,
  requests_per_minute integer,
  concurrent_jobs integer,
  features jsonb not null default '{}',
  created_at timestamptz not null default now()
);

create table subscriptions (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references organizations(id) on delete cascade,
  stripe_subscription_id text unique not null,
  stripe_price_id text,
  status text not null,
  current_period_start timestamptz,
  current_period_end timestamptz,
  cancel_at_period_end boolean not null default false,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table entitlements (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references organizations(id) on delete cascade,
  feature_key text not null,
  enabled boolean not null default false,
  hard_limit bigint,
  soft_limit bigint,
  config jsonb not null default '{}',
  updated_at timestamptz not null default now(),
  unique (organization_id, feature_key)
);

create table api_keys (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references organizations(id) on delete cascade,
  created_by_user_id uuid references profiles(id),
  label text not null,
  key_prefix text not null,
  key_hash text not null,
  scopes jsonb not null default '[]',
  status text not null default 'active' check (status in ('active','revoked','expired')),
  last_used_at timestamptz,
  expires_at timestamptz,
  created_at timestamptz not null default now()
);

create table usage_events (
  id bigint generated always as identity primary key,
  organization_id uuid not null references organizations(id) on delete cascade,
  user_id uuid references profiles(id),
  api_key_id uuid references api_keys(id),
  route text not null,
  metric_key text not null,
  quantity bigint not null default 1,
  request_id text not null,
  source text not null,
  created_at timestamptz not null default now()
);

create table usage_buckets_daily (
  organization_id uuid not null references organizations(id) on delete cascade,
  bucket_date date not null,
  metric_key text not null,
  total_quantity bigint not null default 0,
  updated_at timestamptz not null default now(),
  primary key (organization_id, bucket_date, metric_key)
);

create table billing_event_log (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid references organizations(id),
  stripe_event_id text unique not null,
  event_type text not null,
  payload jsonb not null,
  processed_at timestamptz,
  created_at timestamptz not null default now()
);

create table provisioning_jobs (
  id uuid primary key default gen_random_uuid(),
  job_type text not null,
  source text not null,
  dedupe_key text unique not null,
  payload jsonb not null,
  status text not null default 'pending',
  error text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table audit_log (
  id bigint generated always as identity primary key,
  organization_id uuid references organizations(id),
  actor_user_id uuid references profiles(id),
  actor_api_key_id uuid references api_keys(id),
  action text not null,
  target_type text not null,
  target_id text,
  metadata jsonb not null default '{}',
  created_at timestamptz not null default now()
);
```

### Why this schema fits your internal model

Internally, you've already been pushing toward a UI that tracks **data usage, processing power, cost, and operational state**, with those metrics feeding pricing and contract decisions. You've also described the product as an add-on to observability/compliance stacks, with backend integrations already in place.

## 3. RLS model

Enable RLS on every customer-visible table. Supabase recommends RLS on exposed schemas and notes that the anon key is only safe to expose when RLS is in place. ([Supabase][3])

Example policy pattern:

```sql
alter table organizations enable row level security;
alter table organization_memberships enable row level security;
alter table entitlements enable row level security;
alter table usage_events enable row level security;
alter table usage_buckets_daily enable row level security;
alter table subscriptions enable row level security;

create policy "users can view their org memberships"
on organization_memberships
for select
using (user_id = auth.uid());

create policy "users can view orgs they belong to"
on organizations
for select
using (
  exists (
    select 1
    from organization_memberships m
    where m.organization_id = organizations.id
      and m.user_id = auth.uid()
      and m.status = 'active'
  )
);

create policy "users can view entitlements for their orgs"
on entitlements
for select
using (
  exists (
    select 1
    from organization_memberships m
    where m.organization_id = entitlements.organization_id
      and m.user_id = auth.uid()
      and m.status = 'active'
  )
);
```

Use backend/service-role access only for:

* Stripe webhook sync
* provisioning jobs
* usage aggregation
* API key management
* audit writes

## 4. Supabase auth model

Use **Supabase OAuth** for human users. Then add a **Custom Access Token Hook** so every token includes stable org claims like:

* `default_org_id`
* `org_roles`
* `billing_status`
* `plan_key`

Supabase's Custom Access Token Hook runs before token issuance and is specifically meant for adding claims. Auth Hooks are also the supported customization point for auth flows. ([Supabase][4])

### Suggested token claims

```json
{
  "default_org_id": "org_uuid",
  "org_roles": {
    "org_uuid": "owner"
  },
  "plan_key": "growth",
  "billing_status": "active"
}
```

Do **not** put mutable usage counters in JWTs. Those belong in the Worker / Durable Object path.

## 5. Provisioning flow

Use **Supabase Database Webhooks** to trigger Cloudflare Worker provisioning whenever the local identity model changes. Supabase Database Webhooks fire on `INSERT`, `UPDATE`, and `DELETE`, and are asynchronous wrappers around trigger-based HTTP calls. ([Supabase][5])

### Provisioning sources

1. `auth.users` / `profiles` insert
   → create user profile and default org membership if needed

2. `organization_memberships` insert/update
   → recalculate claims, roles, default org, audit event

3. Stripe webhook event
   → sync billing status, subscription, entitlements, quota version

### Provisioning Worker endpoints

```text
POST /internal/provision/user-created
POST /internal/provision/user-updated
POST /internal/provision/membership-changed
POST /internal/provision/subscription-changed
```

### Idempotency rule

Every provisioning event should carry a `dedupe_key`, for example:

* `supabase:profiles:INSERT:<row_id>:<updated_at>`
* `stripe:<event_id>`

and write that into `provisioning_jobs.dedupe_key`.

## 6. Cloudflare Worker route map

Internally, you've already described a system using secure Cloudflare tunnels and authentication between many microservices to prevent raw internal API abuse. This Worker layer becomes the public control plane that makes that model consistent.

### Public routes

```text
POST   /bootstrap
GET    /v1/orgs
GET    /v1/orgs/:orgId/dashboard
GET    /v1/orgs/:orgId/usage/summary
GET    /v1/orgs/:orgId/entitlements
GET    /v1/orgs/:orgId/billing-status
POST   /v1/orgs/:orgId/api-keys
POST   /v1/orgs/:orgId/api-keys/:keyId/revoke
GET    /v1/me
```

### Machine/API routes

```text
POST   /v1/ingest/events
POST   /v1/ingest/otel
POST   /v1/jobs/run
POST   /v1/evaluate
```

### Internal routes

```text
POST   /internal/stripe/webhook
POST   /internal/provision/user-created
POST   /internal/provision/user-updated
POST   /internal/provision/membership-changed
POST   /internal/usage/flush
```

## 7. Edge auth and authorization flow

I'd split auth like this:

### Human request

* Bearer Supabase JWT
* `x-org-id` header for active workspace

### Machine request

* `Authorization: Bearer <api_key>`
* optional signed service token for internal systems

### Worker pipeline

```text
1. Verify Supabase JWT or API key
2. Resolve org context
3. Load current plan / entitlements / quota version
4. Apply Cloudflare rate limiter for burst control
5. Call org Durable Object for exact quota decision
6. Proxy request or reject
7. Emit usage event asynchronously
```

Cloudflare's Worker rate limiting bindings are fast and low-latency, but Cloudflare explicitly says they are **permissive, eventually consistent, and not an accurate accounting system**. Use them for burst control only. ([Cloudflare Docs][6])

## 8. Durable Object design

Use **one Durable Object per organization**.

Cloudflare Durable Objects are globally unique, stateful, single-threaded instances with strongly consistent attached storage, which is exactly what you want for serialized quota mutations. ([Cloudflare Docs][7])

### DO responsibilities

* cache org quota/plan state
* serialize quota checks
* track current minute counters
* track monthly counter deltas before flush
* reject over-limit requests
* expose `checkAndReserve()` and `flushUsage()` methods

### DO request shape

```ts
type QuotaCheckRequest = {
  orgId: string;
  metricKey: string;       // e.g. "requests", "otel_events", "agent_runs"
  units: number;           // e.g. 1, 50, 1000
  requestId: string;
  planKey: string;
  quotaVersion: number;
};
```

### DO response shape

```ts
type QuotaCheckResponse = {
  allowed: boolean;
  reason?: "minute_limit" | "monthly_limit" | "feature_disabled";
  remainingMinute?: number;
  remainingMonthly?: number | null;
};
```

## 9. Why not KV for usage truth

Do not use Workers KV as the source of truth for quotas or billing counters. Cloudflare states KV is **eventually consistent**, and stale values can be observed in other locations for up to the cache TTL. ([Cloudflare Docs][8])

Use KV only for:

* soft cache of org metadata
* non-critical config
* short-lived derived artifacts

## 10. Stripe sync model

Use **web billing only** for Integrity Studio's SaaS subscription. Internally, the company is aiming for a sticky recurring-revenue SMB motion and a product that slots into existing observability/compliance stacks, so billing belongs on the web side with Stripe Checkout / Billing / Customer Portal.

### Stripe objects

* Customer
* Subscription
* Price
* Invoice
* Customer Portal session

### Stripe events to consume

* `checkout.session.completed`
* `invoice.paid`
* `invoice.payment_failed`
* `customer.subscription.updated`
* `customer.subscription.deleted`

Stripe documents webhooks as the correct mechanism for subscription state changes because billing events happen asynchronously. ([Stripe Docs][1])

### Sync flow

```text
Stripe webhook
  -> verify signature
  -> write billing_event_log
  -> upsert subscriptions
  -> update organizations.billing_status/current_plan
  -> recompute entitlements
  -> increment organizations.quota_version
  -> enqueue cache invalidation / DO refresh
```

## 11. Plan-to-entitlement projection

Example projection:

### free

* `usage_dashboard` = true
* `alerts` = true
* `api_keys_max` = 1
* `monthly_units` = 10000
* `requests_per_minute` = 60

### growth

* `usage_dashboard` = true
* `alerts` = true
* `compliance_summary` = true
* `api_keys_max` = 10
* `monthly_units` = 500000
* `requests_per_minute` = 600

### enterprise

* all features enabled
* custom monthly units
* custom rpm
* custom retention
* premium support flag

This matches the internal need to tie visible cost/data usage into contracts and pricing rather than only showing opaque technical metrics.

## 12. API key model

Use API keys for **authorization and quota identity**, not for user login.

### Key structure

* store prefix in plaintext
* store hash only
* show full secret once at creation

Format:

```text
int_live_org_ab12cd34_xxxxxxxxxxxxxxxxx
```

### API key scopes

```json
[
  "ingest:events",
  "read:usage",
  "run:jobs"
]
```

### API key rules

* org-scoped
* optional expiry
* optional IP allowlist later
* revocable
* audit every creation/revocation/use

## 13. `/bootstrap` contract

This is the first call the Flutter app should make after Supabase sign-in.

```json
{
  "user": {
    "id": "user_uuid",
    "email": "alyshia@integritystudio.ai",
    "full_name": "Alyshia Ledlie"
  },
  "organizations": [
    {
      "id": "org_uuid",
      "name": "Integrity Studio",
      "role": "owner",
      "plan_key": "growth",
      "billing_status": "active"
    }
  ],
  "active_org_id": "org_uuid",
  "entitlements": {
    "usage_dashboard": true,
    "alerts": true,
    "compliance_summary": true,
    "monthly_units": 500000,
    "requests_per_minute": 600
  },
  "usage_snapshot": {
    "month_to_date_units": 182044,
    "current_minute_remaining": 412
  }
}
```

## 14. Flutter bootstrap/auth sequence

### Startup sequence

```text
1. App launches
2. Check Supabase session
3. If missing, show OAuth login
4. If present, call POST /bootstrap
5. Cache org list + active org + entitlements
6. Route to dashboard
```

### Login sequence

```text
Flutter
  -> Supabase OAuth sign-in
  -> receive session
  -> call /bootstrap through Cloudflare Worker
  -> Worker verifies JWT
  -> Worker reads org/membership/plan/usage
  -> app stores active org and renders dashboard
```

### Org switch sequence

```text
1. User changes org in UI
2. App updates active org locally
3. App refetches /v1/orgs/:orgId/dashboard and /usage/summary
4. Worker enforces new org entitlements immediately
```

### Recommended Flutter folder structure

```text
lib/
  core/
    env/
    auth/
    networking/
    models/
  features/
    auth/
    bootstrap/
    organizations/
    dashboard/
    alerts/
    usage/
    billing_status/
    settings/
```

## 15. Flutter auth code shape

Use Supabase for sign-in, then treat your Worker API as the app backend.

```dart
final supabase = Supabase.instance.client;

Future<void> signInWithGoogle() async {
  await supabase.auth.signInWithOAuth(
    OAuthProvider.google,
    redirectTo: 'com.integritystudio.app://login-callback',
  );
}
```

Then:

```dart
Future<BootstrapResponse> bootstrap(String accessToken, String orgId) async {
  final res = await dio.post(
    '/bootstrap',
    options: Options(headers: {
      'Authorization': 'Bearer $accessToken',
      'x-org-id': orgId,
    }),
  );
  return BootstrapResponse.fromJson(res.data);
}
```

## 16. What the Flutter app should show

This is where the companion-app model becomes valuable for Integrity Studio.

Given the internal push for a UI that explains system behavior, monitors usage/cost, and makes the product intelligible to non-technical users, I'd keep the mobile surface focused on:

* dashboard summary
* alert inbox
* plan and billing state
* usage against quota
* integration health
* compliance-summary snapshots
* org switching
* API key management for admins later

## 17. Minimal Worker pseudocode

```ts
export default {
  async fetch(req: Request, env: Env): Promise<Response> {
    const url = new URL(req.url);

    if (url.pathname === "/bootstrap" && req.method === "POST") {
      const auth = await authenticateHuman(req, env);
      const orgId = req.headers.get("x-org-id") ?? auth.defaultOrgId;

      const org = await loadOrgContext(orgId, auth.userId, env);
      return json({
        user: auth.user,
        organizations: org.organizations,
        active_org_id: orgId,
        entitlements: org.entitlements,
        usage_snapshot: org.usageSnapshot,
      });
    }

    if (url.pathname.startsWith("/v1/")) {
      const ctx = await authenticateHumanOrApiKey(req, env);

      await applyBurstLimit(ctx, env); // Cloudflare RL binding
      await applyQuotaLimit(ctx, env); // Durable Object exact check

      const resp = await proxyToOrigin(req, ctx, env);
      ctx.waitUntil(writeUsageEvent(ctx, req, env));
      return resp;
    }

    return new Response("Not found", { status: 404 });
  }
}
```

## 18. Concrete sequence diagrams

### A. User provisioning

```text
Supabase OAuth login
  -> Auth user created / profile inserted
  -> Database Webhook
  -> Cloudflare provisioning Worker
  -> upsert profile
  -> create membership / default org if needed
  -> audit log
```

### B. Subscription update

```text
Stripe event
  -> Cloudflare billing Worker
  -> verify signature
  -> upsert subscription
  -> recalc entitlements
  -> organizations.quota_version += 1
  -> notify org Durable Object
```

### C. Metered request

```text
Flutter or API client
  -> Worker
  -> JWT/API key verification
  -> rate limiter binding
  -> org Durable Object checkAndReserve()
  -> upstream handler
  -> usage_events append
  -> daily rollup update async
```

## 19. My recommended v1 priorities

1. **Supabase OAuth + `/bootstrap`**
2. **organizations / memberships / entitlements schema**
3. **Stripe webhook sync**
4. **Cloudflare Worker auth gateway**
5. **one Durable Object per org**
6. **usage ledger + daily rollups**
7. **Flutter dashboard + billing status + usage summary**

That sequence supports the internal goal of getting a useful, comprehensible UI in front of non-technical stakeholders while preserving the long-term architecture needed for a sticky recurring SaaS product.

Next, I can turn this into actual starter code: SQL migrations, a Worker skeleton, and Flutter bootstrap models/services.

[1]: https://docs.stripe.com/billing/subscriptions/webhooks?utm_source=chatgpt.com "Using webhooks with subscriptions | Stripe Documentation"
[2]: https://supabase.com/docs/guides/auth/auth-hooks?utm_source=chatgpt.com "Auth Hooks | Supabase Docs"
[3]: https://supabase.com/docs/guides/database/secure-data?utm_source=chatgpt.com "Securing your data | Supabase Docs"
[4]: https://supabase.com/docs/guides/auth/auth-hooks/custom-access-token-hook?utm_source=chatgpt.com "Custom Access Token Hook | Supabase Docs"
[5]: https://supabase.com/docs/guides/database/webhooks?utm_source=chatgpt.com "Database Webhooks | Supabase Docs"
[6]: https://developers.cloudflare.com/workers/runtime-apis/bindings/rate-limit/?utm_source=chatgpt.com "Rate Limiting · Cloudflare Workers docs"
[7]: https://developers.cloudflare.com/durable-objects/best-practices/rules-of-durable-objects/?utm_source=chatgpt.com "Rules of Durable Objects · Cloudflare Durable Objects docs"
[8]: https://developers.cloudflare.com/kv/reference/faq/?utm_source=chatgpt.com "FAQ · Cloudflare Workers KV docs"
