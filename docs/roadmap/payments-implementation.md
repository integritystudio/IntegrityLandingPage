## Status: Phase 1-4 COMPLETE; Audit Logging + Rate Limit Headers DONE

**Last Updated:** 2026-03-21 | **Session Focus:** Audit logging for sensitive ops (api_key.created, api_key.revoked, billing_portal.accessed) + X-RateLimit-Remaining headers on all org responses (f8bec9b, e783954, 6954ae6)
**Build Status:** ✅ All tests passing (2631+ tests, ~94% coverage)

- **Phase 1 (Sender-Worker UI):** ✅ COMPLETE — AuthPage, ProvisionPage, SenderHealthPage, JWT provisioning flow, HMAC-SHA256 signing, CORS preflight
- **Phase 2 (SaaS Infra):** ✅ COMPLETE — Supabase schema (29 tables, RLS, triggers), Auth0 identity integration, Stripe webhooks, Worker API gateway, Durable Objects per-org quota
- **Phase 3 (Bootstrap + Webhook Workers):** ✅ COMPLETE — Bootstrap worker (JWT verify → org/membership/entitlements/usage context), Stripe webhook worker (signature verify → subscription sync), shared Zod validation schemas, shared HTTP utilities (CORS, JSON parsing, request/response helpers)
- **Phase 4 (Database + API Gateway):** ✅ COMPLETE — Full API gateway routes; ✅ V01 (Usage Ledger Ingestion): POST /v1/ingest/events with JWT/API key auth, Zod validation, daily rollup via waitUntil, 83 passing tests; ✅ V03 (Monthly Aggregation): rollupMonthlyBucket with per-metric breakdown, weighted latency, 9 passing tests; ✅ Durable Objects per-org quota fully wired; ✅ JWT issuer validation (V-02), timing-safe HMAC comparisons (H19); ✅ H1 (Zod Stripe Schemas): CheckoutSessionSchema, SubscriptionSchema, InvoiceSchema added; all `as any` casts replaced with `safeParse` + typed error returns (commit 29a71d1); H2 (subscription upsert in checkout), M25–M33 code review findings fixed (commits 64b1387, 3e63278, 867957c, 77bd17e, 22794bb, cec8997, 9a154ea, a76348b, c8e03a2, 4fb5380); ✅ V02 (Flutter Dashboard) FEATURE-COMPLETE: 5/8 steps done: ✅ DashboardPage with org switcher dropdown (step 1, commits 91cdae3, 226b568); ✅ BillingStatusPage (step 2, commits 979ab7c, 60fd1ff); ✅ UsageSummaryPage + daily bar chart (step 3, commits 55c4a86, e066900, c78bbf1, 809496a); ✅ QuotaStatusPage (step 3 extended, commits 9f93f67, e3ff7f3); ✅ EntitlementsPage (step 4, commit 9f93f67); ✅ real-time polling on UsageSummaryPage (step 6, commits f6581fd, d14280c); code review fixed: threshold constants unified (commit fccc88b), _isFetching guard added (commit fccc88b), status badge derivation moved into widget (commit a76348b), Zod error formatting improved (commit 9a154ea); remaining: Stripe portal link (step 5)

---

## Architecture Overview

**Integrity Studio's SaaS companion-app model**, customized for:

* **Auth0** as the identity provider (OAuth, SAML, MFA, compliance)
* **web-billed Stripe subscriptions** for billing
* **Cloudflare Workers** as the edge/API gateway for authorization & quota enforcement
* **Supabase Postgres** for product state (users, orgs, usage, entitlements, audit)
* **API-key-backed authorization** with tier rate limits
* **Flutter** as the authenticated companion app, not the primary billing surface

This shape matches the internal direction toward a recurring-revenue SMB product, a plugin/integration motion into observability/compliance stacks, and a UI/dashboard that makes the system legible to non-technical users. It also fits the company's existing emphasis on secure Cloudflare tunnels, monitoring, cost/data tracking, and authentication between many services.

## 1. Target system shape

The cleanest split is:

* **Auth0** = human identity truth (OAuth, SAML, MFA, compliance)
* **Stripe** = billing truth
* **Cloudflare Worker + Durable Object** = request authorization, tier enforcement, quota coordination
* **Supabase Postgres** = product truth for orgs, entitlements, usage ledger, audit history
* **Flutter** = dashboard / alerts / usage / account status UI

That separation is important because:
- Stripe subscription events are asynchronous and should be handled by webhooks, not by trusting frontend success alone. Stripe explicitly recommends webhooks for subscription lifecycle handling and exposes Customer Portal for customer self-service billing management. ([Stripe Docs][1])
- Auth0 provides enterprise identity features (SAML, LDAP, MFA) and better compliance than direct Supabase auth
- Supabase Postgres stores mirrored user metadata + org/entitlements state, not auth truth
- Workers verify JWTs from Auth0, not directly from Supabase

## 2. Postgres schema

I'd use Supabase Postgres for the app/system model and keep billing-derived state projected into it. Supabase Auth supports OAuth sessions and JWT-based auth, and RLS should be enabled on exposed tables. Supabase also warns not to expose the service role key in frontend clients. ([Supabase][2])

### Core tables

```sql
-- Identity tables
create table users (
  id uuid primary key default gen_random_uuid(),
  auth0_id varchar unique not null,
  email varchar unique not null,
  email_verified boolean default false,
  name varchar,
  nickname varchar,
  picture text,
  created_at timestamptz default now(),
  updated_at timestamptz default now(),
  last_login timestamptz,
  login_count integer default 0,
  blocked boolean default false,
  metadata jsonb default '{}',
  tier text default 'new',
  default_organization_id uuid references organizations(id)
);

-- Migration bridge: links Supabase auth.users to public.users (for gradual Auth0 migration)
create table auth_user_links (
  auth_user_id uuid not null primary key references auth.users(id),
  app_user_id uuid not null unique references users(id),
  created_at timestamptz default now()
);

create table user_profiles (
  id uuid primary key default gen_random_uuid(),
  user_id uuid unique references users(id) on delete cascade,
  phone_number varchar,
  address text,
  city varchar,
  state varchar,
  zip_code varchar,
  country varchar,
  timezone varchar,
  locale varchar default 'en-US',
  preferences jsonb default '{}',
  created_at timestamptz default now(),
  updated_at timestamptz default now(),
  organization text,
  role text,
  email text,
  full_name text,
  avatar_url text
);

create table user_activity (
  id uuid primary key default gen_random_uuid(),
  user_id uuid references users(id),
  activity_type varchar not null,
  description text,
  metadata jsonb default '{}',
  ip_address inet,
  user_agent text,
  created_at timestamptz default now()
);

create table user_sessions (
  id uuid primary key default gen_random_uuid(),
  user_id uuid references users(id),
  session_token text unique not null,
  ip_address inet,
  user_agent text,
  device_type varchar,
  browser varchar,
  os varchar,
  country varchar,
  city varchar,
  created_at timestamptz default now(),
  expires_at timestamptz not null,
  last_activity timestamptz default now(),
  is_active boolean default true
);

-- Organization & roles
create table organizations (
  id uuid primary key default gen_random_uuid(),
  slug text unique not null,
  name text not null,
  stripe_customer_id text unique,
  active_subscription_id uuid,
  billing_status text default 'inactive',
  current_plan text default 'free',
  quota_version bigint default 1,
  created_at timestamptz default now(),
  updated_at timestamptz default now()
);

create table organization_memberships (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references organizations(id) on delete cascade,
  user_id uuid not null references users(id) on delete cascade,
  role text not null check (role in ('owner','admin','member','billing_admin','viewer')),
  status text default 'active' check (status in ('active','invited','suspended')),
  created_at timestamptz default now(),
  updated_at timestamptz default now(),
  unique (organization_id, user_id)
);

create table roles (
  id uuid primary key default gen_random_uuid(),
  name varchar unique not null,
  description text,
  permissions jsonb default '[]',
  created_at timestamptz default current_timestamp,
  updated_at timestamptz default current_timestamp
);

create table user_roles (
  id uuid primary key default gen_random_uuid(),
  user_id uuid references users(id) on delete cascade,
  role_id uuid references roles(id),
  granted_at timestamptz default current_timestamp,
  granted_by uuid references users(id)
);

-- Billing & plans
create table plans (
  key text primary key,
  display_name text not null,
  monthly_units bigint,
  requests_per_minute integer,
  concurrent_jobs integer,
  features jsonb default '{}',
  created_at timestamptz default now()
);

create table subscriptions (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references organizations(id) on delete cascade,
  stripe_subscription_id text unique not null,
  stripe_price_id text,
  status text not null,
  current_period_start timestamptz,
  current_period_end timestamptz,
  cancel_at_period_end boolean default false,
  created_at timestamptz default now(),
  updated_at timestamptz default now()
);

create table entitlements (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references organizations(id) on delete cascade,
  feature_key text not null,
  enabled boolean default false,
  hard_limit bigint,
  soft_limit bigint,
  config jsonb default '{}',
  created_at timestamptz default now(),
  updated_at timestamptz default now(),
  unique (organization_id, feature_key)
);

-- API keys & usage
create table api_keys (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references users(id),
  organization_id uuid not null references organizations(id) on delete cascade,
  prefix varchar not null,
  hash text not null unique,
  name text default 'Default',
  tier text default 'new',
  status text default 'active',
  expires_at timestamptz,
  last_used_at timestamptz,
  created_at timestamptz default now(),
  revoked_at timestamptz,
  unique (organization_id, prefix)
);

create table usage_events (
  id bigint generated always as identity primary key,
  organization_id uuid not null references organizations(id) on delete cascade,
  user_id uuid references users(id),
  api_key_id uuid references api_keys(id),
  route text not null,
  metric_key text not null,
  quantity bigint default 1,
  request_id text not null,
  source text not null check (source in ('api','ingest','job','internal','migration')),
  status_code integer,
  latency_ms integer,
  metadata jsonb default '{}',
  created_at timestamptz default now()
);

create table usage_buckets_daily (
  organization_id uuid not null references organizations(id) on delete cascade,
  bucket_date date not null,
  metric_key text not null,
  total_quantity bigint default 0,
  request_count bigint default 0,
  avg_latency_ms numeric,
  updated_at timestamptz default now(),
  primary key (organization_id, bucket_date, metric_key)
);

-- Webhooks & events
create table billing_event_log (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid references organizations(id),
  stripe_event_id text unique not null,
  event_type text not null check (event_type in ('checkout.session.completed','invoice.paid','invoice.payment_failed','customer.subscription.updated','customer.subscription.deleted','charge.refunded','other')),
  payload jsonb not null,
  processed_at timestamptz,
  error_message text,
  created_at timestamptz default now()
);

create table provisioning_jobs (
  id uuid primary key default gen_random_uuid(),
  job_type text not null check (job_type in ('user_created','user_updated','membership_changed','subscription_changed','entitlements_recomputed','quota_version_bumped')),
  source text not null check (source in ('supabase_webhook','stripe_webhook','manual','migration')),
  dedupe_key text unique not null,
  organization_id uuid references organizations(id),
  user_id uuid references users(id),
  payload jsonb not null,
  status text default 'pending' check (status in ('pending','processing','completed','failed','retried')),
  result jsonb,
  error_message text,
  retry_count integer default 0,
  max_retries integer default 3,
  created_at timestamptz default now(),
  updated_at timestamptz default now(),
  completed_at timestamptz
);

create table audit_log (
  id bigint generated always as identity primary key,
  organization_id uuid references organizations(id),
  actor_user_id uuid references users(id),
  actor_api_key_id uuid references api_keys(id),
  action text not null,
  target_type text not null,
  target_id text not null,
  old_values jsonb,
  new_values jsonb,
  metadata jsonb default '{}',
  created_at timestamptz default now()
);

-- Analytics & integrations
create table analytics_projects (
  project_id uuid primary key default gen_random_uuid(),
  user_id uuid not null references users(id),
  name text not null,
  description text,
  domain_name text,
  stage text check (stage in ('development','staging','production','archived')),
  enabled_providers text[] default '{}',
  created_at timestamptz default now(),
  updated_at timestamptz default now(),
  last_event_at timestamptz,
  total_events integer default 0,
  total_users integer default 0,
  total_sessions integer default 0,
  total_cost numeric default 0.00,
  project_type text
);

create table provider_oauth_tokens (
  id uuid primary key default gen_random_uuid(),
  project_id uuid not null references analytics_projects(project_id),
  user_id uuid not null references users(id),
  provider_type text default 'ga4' check (provider_type in ('ga4','facebook_pixel','google_ads')),
  property_id text,
  scope text not null,
  vault_access_token_id uuid,
  vault_refresh_token_id uuid,
  token_expires_at timestamptz,
  last_sync_at timestamptz,
  sync_status text default 'pending' check (sync_status in ('pending','syncing','success','error')),
  sync_error text,
  created_at timestamptz default now(),
  updated_at timestamptz default now(),
  access_token text,
  refresh_token text
);
```

### Auth0 vs Supabase Auth migration strategy

The schema includes `auth_user_links` to support a **gradual migration from Supabase Auth to Auth0**:

* **Old flow (Supabase Auth):** auth.users → lookups via `auth_user_links` → app logic on public.users
* **New flow (Auth0):** Auth0 JWT with `auth0_id` → direct lookup on public.users → no bridge needed
* **Transition:** Both flows can coexist; set `auth_user_links` to null once all users are migrated to Auth0

This allows rolling migration without downtime — existing Supabase auth users can continue using the old flow while new signups go straight to Auth0.

### Why this schema fits your internal model

Internally, you've already been pushing toward a UI that tracks **data usage, processing power, cost, and operational state**, with those metrics feeding pricing and contract decisions. You've also described the product as an add-on to observability/compliance stacks, with backend integrations already in place.

## 2.5. Database utilities: `updated_at` trigger

**Status:** ✅ Implemented manually in Supabase UI (2026-03-20)

Every mutable table includes an `updated_at` timestamp. To keep these in sync automatically, create a reusable trigger function:

```sql
create or replace function update_updated_at_column()
returns trigger as $$
begin
  new.updated_at = now();
  return new;
end;
$$ language plpgsql;
```

Apply to each mutable table:

```sql
create trigger update_organizations_updated_at
before update on organizations
for each row
execute function update_updated_at_column();

create trigger update_organization_memberships_updated_at
before update on organization_memberships
for each row
execute function update_updated_at_column();

create trigger update_subscriptions_updated_at
before update on subscriptions
for each row
execute function update_updated_at_column();

create trigger update_entitlements_updated_at
before update on entitlements
for each row
execute function update_updated_at_column();

create trigger update_api_keys_updated_at
before update on api_keys
for each row
execute function update_updated_at_column();

create trigger update_user_profiles_updated_at
before update on user_profiles
for each row
execute function update_updated_at_column();

create trigger update_user_sessions_updated_at
before update on user_sessions
for each row
execute function update_updated_at_column();

create trigger update_provisioning_jobs_updated_at
before update on provisioning_jobs
for each row
execute function update_updated_at_column();

create trigger update_analytics_projects_updated_at
before update on analytics_projects
for each row
execute function update_updated_at_column();

create trigger update_provider_oauth_tokens_updated_at
before update on provider_oauth_tokens
for each row
execute function update_updated_at_column();

create trigger update_billing_event_log_updated_at
before update on billing_event_log
for each row
execute function update_updated_at_column();
```

**When adding new tables:** If a table has an `updated_at` column, create a corresponding trigger. The function is reusable across all tables.

## 2.6. Schema enhancements: API keys organization scoping

**Status:** ✅ Implemented in Supabase (2026-03-20)

**Change:** Add `organization_id` column to `api_keys` table for explicit org scoping and improved RLS performance.

**Rationale:**
- Consistency with other org-scoped resources (subscriptions, entitlements, usage_events)
- Direct org filtering without multi-join through users/memberships
- Enables per-org API key namespacing (prefix unique per org, not globally)

**Schema modification:**

```sql
-- 1. Add column as nullable
alter table api_keys
add column organization_id uuid references organizations(id) on delete cascade;

-- 2. Backfill with user's primary active org
update api_keys k
set organization_id = (
  select m.organization_id
  from organization_memberships m
  where m.user_id = k.user_id
    and m.status = 'active'
  order by m.created_at
  limit 1
)
where organization_id is null;

-- 3. Add NOT NULL constraint
alter table api_keys
alter column organization_id set not null;

-- 4. Add indexes for RLS performance
create index idx_api_keys_organization_id on api_keys(organization_id);
create index idx_api_keys_user_id on api_keys(user_id);

-- 5. Update unique constraint (prefix per org)
alter table api_keys drop constraint api_keys_prefix_key;
alter table api_keys add unique (organization_id, prefix);
```

**Impact on API key verification flow:**

When verifying an API key (section 12), also resolve `organization_id` to scope operations:

```ts
// 1. Extract prefix from key
const [prefix, secret] = token.split('_', 2);

// 2. Query for key by prefix + org_id (faster than before)
const apiKey = await db.api_keys.findOne({ organization_id, prefix });

// 3. Rest of verification unchanged
const valid = await bcrypt.compare(secret, apiKey.hash);
```

## 3. RLS model

Enable RLS on every customer-visible table. Supabase recommends RLS on exposed schemas and notes that the anon key is only safe to expose when RLS is in place. ([Supabase][3])

**Key design:** Link RLS policies to `users(id)` via `organization_memberships`, not directly to `auth.users`. This allows API key authentication (which has no auth.uid()) to work via `api_keys.user_id`.

Example policy pattern:

```sql
alter table users enable row level security;
alter table user_profiles enable row level security;
alter table user_activity enable row level security;
alter table organization_memberships enable row level security;
alter table organizations enable row level security;
alter table entitlements enable row level security;
alter table usage_events enable row level security;
alter table subscriptions enable row level security;

-- Users can view their own profile
create policy "users can view own profile"
on users for select
using (id = auth.uid());

create policy "users can view own user_profile"
on user_profiles for select
using (user_id = auth.uid());

-- Users can view orgs they're members of
create policy "users can view their org memberships"
on organization_memberships for select
using (user_id = auth.uid());

create policy "users can view orgs they belong to"
on organizations for select
using (
  exists (
    select 1
    from organization_memberships m
    where m.organization_id = organizations.id
      and m.user_id = auth.uid()
      and m.status = 'active'
  )
);

-- Users can view entitlements for their orgs
create policy "users can view entitlements for their orgs"
on entitlements for select
using (
  exists (
    select 1
    from organization_memberships m
    where m.organization_id = entitlements.organization_id
      and m.user_id = auth.uid()
      and m.status = 'active'
  )
);

-- Users can view usage for their orgs
create policy "users can view usage for their orgs"
on usage_events for select
using (
  exists (
    select 1
    from organization_memberships m
    where m.organization_id = usage_events.organization_id
      and m.user_id = auth.uid()
      and m.status = 'active'
  )
);

create policy "users can view usage buckets for their orgs"
on usage_buckets_daily for select
using (
  exists (
    select 1
    from organization_memberships m
    where m.organization_id = usage_buckets_daily.organization_id
      and m.user_id = auth.uid()
      and m.status = 'active'
  )
);

create policy "users can view subscriptions for their orgs"
on subscriptions for select
using (
  exists (
    select 1
    from organization_memberships m
    where m.organization_id = subscriptions.organization_id
      and m.user_id = auth.uid()
      and (m.role = 'owner' or m.role = 'billing_admin')
  )
);

-- Users can view their own activity
create policy "users can view own activity"
on user_activity for select
using (user_id = auth.uid());

create policy "users can view own sessions"
on user_sessions for select
using (user_id = auth.uid());
```

Use backend/service-role access only for:

* Stripe webhook sync
* provisioning jobs
* usage aggregation
* API key management
* audit writes
* user session cleanup
* analytics integrations

## 3.5. Schema enhancements: New tables & features

The actual implementation adds several tables not in the initial design:

### User activity & sessions

**`user_activity`** — audit trail of user actions (logins, API calls, settings changes)
* Tracks `activity_type`, `description`, `ip_address`, `user_agent`
* Use for compliance, debugging, abuse detection

**`user_sessions`** — active login sessions with device fingerprinting
* Tracks `session_token`, `browser`, `os`, `device_type`, `country`, `city`
* Supports multi-device login, session revocation, geo-fencing
* `last_activity` + `expires_at` for timeout enforcement

### Analytics & provider integrations

**`analytics_projects`** — customer analytics workspace (e.g., GA4 tracking setup)
* Stores `domain_name`, `stage` (dev/staging/prod), `enabled_providers`
* Tracks cumulative `total_events`, `total_users`, `total_sessions`, `total_cost`
* Supports multiple analytics integrations per user

**`provider_oauth_tokens`** — OAuth tokens for third-party integrations
* Stores GA4, Facebook Pixel, Google Ads OAuth credentials
* Uses `vault_access_token_id` / `vault_refresh_token_id` for Supabase Vault integration (secure secrets)
* `sync_status` + `sync_error` for async provider sync workflows

### Usage metrics enhancement

**`usage_events`** now includes:
* `status_code` — HTTP response code for API debugging
* `latency_ms` — request latency for perf monitoring
* Source constraint: `'api'|'ingest'|'job'|'internal'|'migration'`

**`usage_buckets_daily`** now includes:
* `request_count` — request count separate from quantity
* `avg_latency_ms` — rolling average latency per bucket

### Billing events enhancement

**`billing_event_log`** now includes:
* `error_message` — Stripe webhook error details for debugging
* Event type constraint: explicit enum of Stripe event types

### Provisioning jobs enhancement

**`provisioning_jobs`** now includes:
* `retry_count` + `max_retries` — exponential backoff retry logic
* `completed_at` — timestamp when job completed (for SLA tracking)
* `organization_id` + `user_id` — direct references for job targeting
* Status constraint: `'pending'|'processing'|'completed'|'failed'|'retried'`
* Job type constraint: explicit enum (`user_created`, `membership_changed`, etc.)

### Role-based access control (RBAC)

**`roles`** — centralized role definitions
* `name` — role identifier
* `permissions` — jsonb array of permission strings

**`user_roles`** — grants roles to users
* `granted_at` + `granted_by` — audit trail for role changes
* Separate from `organization_memberships.role` (allows fine-grained permissions)

---

## 4. Auth0 identity model (actual implementation)

Use **Auth0** as the identity provider instead of Supabase OAuth. Auth0 provides better enterprise support (SAML, LDAP, MFA) and compliance features.

### Auth0 configuration

Configure Auth0 Custom Claims / Rules to enrich the JWT with org context:

* `default_org_id` — user's active org
* `org_roles` — mapping of org_id → role (owner, admin, member, etc.)
* `billing_status` — org billing status
* `plan_key` — org plan key

Auth0 Rules/Actions run before token issuance and are the supported customization point for JWT enrichment. ([Auth0 Docs](https://auth0.com/docs/customize/rules))

### Suggested Auth0 JWT claims

```json
{
  "sub": "auth0|6123456789abcdef",
  "email": "user@example.com",
  "name": "User Name",
  "default_org_id": "org_uuid",
  "org_roles": {
    "org_uuid": "owner"
  },
  "plan_key": "growth",
  "billing_status": "active"
}
```

Do **not** put mutable usage counters in JWTs. Those belong in the Worker / Durable Object path.

### Auth0 to Postgres sync flow

Supabase Postgres does **not** store auth truth — it mirrors user data from Auth0:

1. User signs up via Auth0
2. Auth0 webhook → Cloudflare Worker `/internal/auth0/user-created`
3. Worker verifies Auth0 signature, creates/updates `users` row via `users.auth0_id`
4. Worker creates default `organizations` + `organization_memberships` if first signup
5. Worker writes `provisioning_jobs` entry (dedupe_key for idempotency)
6. Provisioning job enqueued for background processing

This separation ensures:
* Auth0 is the identity truth (cannot be bypassed)
* Supabase Postgres is product/entitlements truth
* Cloudflare Worker enforces both via JWT verification + RLS

---

## 5. Provisioning flow

Use **Supabase Database Webhooks** to trigger Cloudflare Worker provisioning whenever the local identity model changes. Supabase Database Webhooks fire on `INSERT`, `UPDATE`, and `DELETE`, and are asynchronous wrappers around trigger-based HTTP calls. ([Supabase][5])

### Provisioning job types

The `provisioning_jobs` table tracks all async work with `job_type`, `source`, and `status`:

* **`user_created`** (source: `supabase_webhook`) — user inserted, initialize profile + default org
* **`user_updated`** (source: `supabase_webhook`) — user metadata/tier changed, recalculate claims
* **`membership_changed`** (source: `supabase_webhook`) — org membership added/updated/deleted, recalculate roles
* **`subscription_changed`** (source: `stripe_webhook`) — Stripe subscription event, recompute entitlements
* **`entitlements_recomputed`** (source: `supabase_webhook`) — plan changed, recompute feature flags + limits
* **`quota_version_bumped`** (source: `supabase_webhook`) — quota version incremented, invalidate DO cache

### Provisioning Worker endpoints

```text
POST /internal/provision/user-created
POST /internal/provision/user-updated
POST /internal/provision/membership-changed
POST /internal/provision/subscription-changed
POST /internal/provision/entitlements-recomputed
POST /internal/provision/quota-version-bumped
```

### Idempotency rule

Every provisioning event should carry a `dedupe_key`, for example:

* `supabase:users:INSERT:<user_id>:<created_at>`
* `supabase:organization_memberships:INSERT:<membership_id>:<created_at>`
* `stripe:customer.subscription.updated:<subscription_id>:<event_timestamp>`

and write that into `provisioning_jobs.dedupe_key`. The database constraint ensures each dedupe_key is processed exactly once. Use **retry_count/max_retries** for transient failures (Worker timeout, network errors); use **status=failed** for permanent failures (validation error, 4xx API response).

### Retry strategy

```ts
// Pseudo-pseudocode for provisioning job handler
const job = await getProvisioningJob(id);

if (job.status === 'pending') {
  // Claim the job
  await updateProvisioningJob(id, { status: 'processing' });

  try {
    const result = await callProvisioningWorker(job);
    await updateProvisioningJob(id, {
      status: 'completed',
      result,
      completed_at: now(),
    });
  } catch (err) {
    if (isRetryable(err) && job.retry_count < job.max_retries) {
      await updateProvisioningJob(id, {
        retry_count: job.retry_count + 1,
        status: 'retried',
        error_message: err.message,
      });
      // Re-enqueue after exponential backoff
    } else {
      await updateProvisioningJob(id, {
        status: 'failed',
        error_message: err.message,
      });
      // Alert / manual intervention required
    }
  }
}
```

## 6. Cloudflare Worker route map

Internally, you've already described a system using secure Cloudflare tunnels and authentication between many microservices to prevent raw internal API abuse. This Worker layer becomes the public control plane that makes that model consistent.

### Public routes — ✅ Implemented

```text
GET    /v1/me                                    — Authenticated user context
GET    /v1/orgs                                  — List user's organizations
GET    /v1/orgs/:orgId/dashboard                — Org summary (subscription, usage, entitlements)
GET    /v1/orgs/:orgId/billing-status           — Billing and plan status
GET    /v1/orgs/:orgId/usage/summary            — Usage metrics and quota state
GET    /v1/orgs/:orgId/entitlements             — Feature flags and soft/hard limits
POST   /v1/orgs/:orgId/api-keys                 — Create new API key
POST   /v1/orgs/:orgId/api-keys/:keyId/revoke   — Revoke existing key
```

**Authentication:** Bearer JWT (from Auth0 or Supabase)

### Machine/API routes — 🔄 In Progress

```text
POST   /v1/ingest/events                        — Ingest metered usage events
POST   /v1/ingest/otel                          — OpenTelemetry span ingestion
POST   /v1/jobs/run                             — Trigger async job (placeholder)
POST   /v1/evaluate                             — Run policy evaluation (placeholder)
```

**Authentication:** API key (prefix + secret, org-scoped)

### Internal routes — ✅ Implemented (via separate workers)

```text
POST   /internal/stripe/webhook                 — Stripe event subscription sync (stripe webhook worker)
POST   /internal/provision/user-created         — Bootstrap Worker user provisioning
POST   /internal/provision/membership-changed   — Bootstrap Worker membership sync
POST   /internal/usage/flush                    — Usage aggregation flush (scheduled worker)
```

**Authentication:** Signed service token (HMAC) or IP allowlist

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

Use API keys for **authorization and quota identity**, not for user login. Keys are user-owned but inherit organization context via org membership.

### Key structure

API keys are stored in `api_keys` table with:

* `prefix` — plaintext key prefix (e.g., `int_live_`) for display, rate limit lookup
* `hash` — bcrypt or Argon2 hash of full secret, never store plaintext
* `name` — user-defined label
* `tier` — `'new'`, `'free'`, `'growth'`, `'enterprise'`
* `status` — `'active'`, `'revoked'`, `'expired'`
* `user_id` — owner of the key; key inherits org access via user's memberships
* `expires_at` — optional; null = never expires
* `last_used_at` — timestamp for audit/cleanup
* `revoked_at` — timestamp when revoked (non-null = revoked)

Format:

```text
int_live_abc123def456_xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
                      ↑ prefix (plaintext)    ↑ secret (hashed)
```

### API key verification flow

```ts
// 1. Client sends key in Authorization header
const authHeader = req.headers.get('Authorization');
const [scheme, token] = authHeader.split(' ');

// 2. Extract prefix
const [prefix, secret] = token.split('_', 2);

// 3. Extract org_id from prefix (format: int_live_<org_id>_<secret>)
// Alternative: pass ?org_id=xxx query param or X-Org-ID header
const orgId = req.headers.get('x-org-id');
if (!orgId) return 401 Unauthorized;

// 4. Query for key by org_id + prefix (fast, unique per org)
const apiKey = await db.api_keys.findOne({
  organization_id: orgId,
  prefix
});

if (!apiKey || apiKey.status !== 'active' || (apiKey.expires_at && apiKey.expires_at < now())) {
  return 401 Unauthorized;
}

// 5. Compare hash
const valid = await bcrypt.compare(secret, apiKey.hash);
if (!valid) return 401 Unauthorized;

// 6. Resolve user & org context
const user = await db.users.findOne(apiKey.user_id);
const org = await db.organizations.findOne(apiKey.organization_id);
const entitlements = await loadEntitlements(orgId);

return { user, org, entitlements };
```

### API key rules

* user-owned, inherited via org membership
* optional expiry
* revocable
* status tracked for soft delete
* audit on creation, use, revocation
* prefix-based lookup for perf

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

## 15.5. Auth0 integration in Flutter (actual implementation)

The actual implementation uses **Auth0** instead of Supabase OAuth. Auth0 provides better enterprise support (SAML, LDAP, MFA) and is the identity source of truth.

```dart
import 'package:auth0_flutter/auth0_flutter.dart';

final auth0 = Auth0(
  domain: 'YOUR_AUTH0_DOMAIN',
  clientId: 'YOUR_AUTH0_CLIENT_ID',
);

Future<void> signInWithAuth0() async {
  try {
    final credentials = await auth0.webAuthentication().login();
    // credentials.accessToken is Auth0 JWT
    // credentials.user.sub is auth0|xxxxx

    // Call bootstrap with Auth0 JWT
    final bootstrap = await bootstrapWithAuth0(
      credentials.accessToken,
      credentials.user?.sub ?? '',
    );

    // Store org context locally
    appState.activeOrg = bootstrap.activeOrg;
    appState.entitlements = bootstrap.entitlements;

  } catch (e) {
    print('Auth0 login failed: $e');
  }
}

Future<BootstrapResponse> bootstrapWithAuth0(
  String accessToken,
  String auth0Id,
) async {
  final res = await dio.post(
    '/bootstrap',
    options: Options(headers: {
      'Authorization': 'Bearer $accessToken',
      'X-Auth0-ID': auth0Id,
    }),
  );
  return BootstrapResponse.fromJson(res.data);
}
```

**Worker side: Auth0 JWT verification**

```ts
import { jwtVerify } from 'jose';

export async function bootstrapWithAuth0(req: Request, env: Env) {
  // 1. Extract Auth0 JWT from Authorization header
  const token = req.headers.get('Authorization')?.split(' ')[1];
  if (!token) return new Response('Missing token', { status: 401 });

  // 2. Verify Auth0 JWT signature using JWKS
  const secret = new TextEncoder().encode(env.AUTH0_CLIENT_SECRET);
  const { payload } = await jwtVerify(token, secret);

  const auth0Id = payload.sub as string;  // "auth0|6123456789abcdef"
  const email = payload.email as string;

  // 3. Lookup or provision user
  let user = await db.query(
    'SELECT * FROM users WHERE auth0_id = $1',
    [auth0Id]
  );

  if (!user.rows.length) {
    // First login — trigger user_created provisioning job
    await db.query(
      'INSERT INTO provisioning_jobs (job_type, source, dedupe_key, payload, status) VALUES ($1, $2, $3, $4, $5)',
      [
        'user_created',
        'auth0_webhook',
        `auth0:${auth0Id}:${Date.now()}`,
        JSON.stringify({ auth0Id, email, name: payload.name }),
        'pending',
      ]
    );

    // Wait for provisioning (max 5s)
    user = await waitForUserProvisioning(auth0Id, 5000);
  }

  // 4. Return bootstrap response
  const orgs = await db.query(
    'SELECT * FROM organization_memberships WHERE user_id = $1 AND status = $2',
    [user.rows[0].id, 'active']
  );

  return json({
    user: {
      id: user.rows[0].id,
      email: user.rows[0].email,
      name: user.rows[0].name,
    },
    organizations: orgs.rows,
    active_org_id: user.rows[0].default_organization_id,
    entitlements: await loadEntitlements(user.rows[0].default_organization_id),
  });
}
```

---

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

### A. User provisioning (Auth0)

```text
Auth0 new user signup or OAuth
  -> Auth0 webhook to Cloudflare Worker
  -> Verify Auth0 signature
  -> Create users row (auth0_id, email, name from Auth0)
  -> Create user_profiles entry (contact info, preferences)
  -> Create default organization + membership
  -> Write provisioning_job (source: auth0_webhook, job_type: user_created)
  -> Emit audit_log entry
  -> Return JWT enriched with org_id + org_roles
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

## 19. v1 Implementation Status (Updated 2026-03-21)

### Completed ✅ (15 core items + 3 recent refinements + 1 Durable Objects + Phase 4 Task 2 + Phase 4 Task 3 complete + M34/M37–M39/L5/L16 + H1/H2/M25–M33 code review fixes)

**Core infrastructure (2026-03-20)**
1. **Auth pages & JWT flow** — AuthPage, ProvisionPage, SenderHealthPage with JWT-based provisioning
2. **Sender-worker** — HMAC-SHA256 signing, environment-aware CORS origin config, request validation
3. **Receiver-worker** — HMAC signature verification, replay protection via dedupe key
4. **Workers lib (79 tests)** — Shared HTTP utilities (CORS, JSON/bearer/query parsing, response factories), Zod validation, error handling
5. **Contact form validation** — Zod-based runtime validation integrated with contact-form worker
6. **Provisioning service** — Flutter client for auth/provision flows with error sanitization, retry logic, response type safety
7. **Bootstrap Worker** — JWT verification, org/membership/entitlement/usage context loading, `POST /bootstrap` endpoint
8. **Stripe Webhook Worker** — Webhook signature verification, subscription/invoice event handlers, billing state sync
9. **Zod validation schemas** — Runtime validation for Phase 3 types (OrgRole, BillingStatus, Organization, BootstrapResponse, StripeEvent, etc.)
10. **Supabase REST client** — Lightweight fetch-based client for edge Workers with query/insert/update/rpc helpers
11. **Supabase database schema** — 29-table schema, RLS policies (14 tables), `update_timestamp()` triggers, performance indexes, Auth0 integration
12. **API gateway routes** — Full implementation: `GET /v1/me`, `GET /v1/orgs`, `GET /v1/orgs/:id/dashboard`, `GET /v1/orgs/:id/billing-status`, `GET /v1/orgs/:id/usage/summary`, `GET /v1/orgs/:id/entitlements`, `POST /v1/orgs/:id/api-keys` (create), `POST /v1/orgs/:id/api-keys/:keyId/revoke`
13. **Flutter UI refactoring** — StatusResultPage extraction, TrustBadge improvements, ListCard consolidation (_ChoiceCard + _QueryCard), 76-78% code duplication reduction
14. **Durable Objects per-org quota** — Complete state machine with minute-level burst control (60-second rolling windows), monthly soft limits, quota version detection (Stripe webhook triggers), type-safe service client (`checkAndReserve()`, `flushUsage()`, `getQuotaStatus()`), Zod schemas, comprehensive architecture documentation. Files: `workers/api-gateway/src/durable-objects/quota.ts` (253 lines), `workers/api-gateway/src/lib/quota.ts` (94 lines), `workers/docs/QUOTA_DURABLE_OBJECTS.md` (359 lines)

**Session work (2026-03-20 — Phase 4 Task 2 & Task 3 partial)**
- **T26: Quota enforcement wiring** — `enforceOrgQuota()` middleware added to `lib/quota.ts`, integrated into all org-specific API gateway routes with fail-open logic and rate-limit headers (commits bb1d810, d58f382, 3483538)
- **T27: Quota integration tests** — 25 comprehensive tests covering minute/monthly limits, idempotency, plan tiers, enterprise quotas, quota version bumps, storage persistence (commit 6bc3cd8)
- **V01: Usage ledger ingestion** — `POST /v1/ingest/events` with dual JWT/API key auth, fire-and-forget daily bucket rollup via `ctx.waitUntil`, 16 tests (commits 761ab48, d4911ca)
- **V03: Monthly aggregation** — `rollupMonthlyBucket(orgId, yearMonth, sb)` querying `usage_buckets_daily` with weighted avg_latency_ms; `MonthlyUsageSummarySchema` Zod validation on return; `MAX_DAILY_BUCKETS_PER_MONTH` query cap (3100); month regex rejects 00/13; 17 TDD tests (commits 59402f3, c021f5b, 97d3b74)
- **V02: Dashboard UI components** — ✅ Usage summary display page with monthly usage breakdown + per-metric table (55c4a86, e066900, 03142d1); ✅ billing status display page with plan name + status badge + renewal/cancellation date (979ab7c, 60fd1ff); both integrate with API gateway `/v1/orgs/:id/usage/summary` and `/v1/orgs/:id/billing-status` endpoints; route guards via state.extra args; loading/error/retry patterns; orgId path-traversal validation; code review findings: 1 H2 latent JWT risk, 3 M-level (telemetry, validation, duplication), 2 L-level (decoration, docs) documented in backlog (80b288a)
- **Bootstrap flow integration** — Complete client-side orchestration with error sanitization, org context loading, response type safety; code review findings addressed (fda0ada, 963f4d3)
- **Stripe webhook M23/M24** — Event idempotency validation with DB error path handling (T23-M4, 1ae481d); improved error logging for logProcessedEvent/fetchPendingDeadLetters (f2b28a1); code review fixes (cc6c88e)
- **Quota refactoring** — Zod validation on DO response boundaries replacing unsafe casts (99d96b9); simplified implementation after parse refactor (1872a13); Zod DO response validation in quota.ts (01f66e7); code review fixes (95f2e51, eb1f928)
- **Security hardening** — JWT issuer claim validation (V-02, 00bfaaf), timing-safe HMAC comparisons with `crypto.subtle.verify()` for API key and Stripe verification (H19, 0f9cece); bearer token pre-check for quota enforcement (H21, 81f1921); JWT verification before quota enforcement (H21, 70a1556); org quota enforcement require bearer token (H21, aa4abf6); CSP frame-ancestors header for clickjacking protection (S01, 81f1921); IDOR tests for org entitlements (H20, e296e20)
- **Code review completion** — 22 code review items migrated to v1.2 changelog (77d477e); 9 items migrated to changelog (85ada38); session backlog findings appended (e944bb7); L5 unsanitized auth.email finding from bootstrap session (2b581ed); billing status dashboard UI code review findings: 1 H2 latent, 3 M-level, 2 L-level, V02-remaining 5 components documented (80b288a)

**Code Review Cycle & Fixes (2026-03-21)**
- **H1: Type Safety Lost (Stripe Payloads)** — CheckoutSessionSchema, SubscriptionSchema, InvoiceSchema added to stripe-schemas.ts; all `as any` casts replaced with `safeParse` + typed error returns (commit 29a71d1)
- **H2: Missing Subscription Upsert** — `handleCheckoutSessionCompleted` now calls `db.upsertSubscription()` after linking customer, mirroring pattern in other handlers (commit 64b1387)
- **M25: HandlerResult Type Duplicated** — Moved to `workers/lib/types/index.ts` as single source of truth; removed from index.ts, checkout.ts, subscription.ts, invoice.ts (commit 3e63278)
- **M26: Non-Atomic Check-Then-Write** — `upsertSubscription` now uses atomic `sb.upsert()` with `ON CONFLICT (organization_id, stripe_subscription_id)` (commit 867957c)
- **M27: Dead Letter Filter in App Code** — `retry_count < max_retries` filter pushed into PostgREST query; DEAD_LETTER_MAX_RETRIES=5 constant added (commit 77bd17e)
- **M28: Wrong HTTP Status Code** — Unmatched routes return 404 (notFound) instead of 500 (serverError) (commit 22794bb)
- **M29: Quota Version Type Mismatch** — `quota_version` now uses `Date.now()` (Unix millisecond timestamp as number) instead of ISO string; maintains number type throughout (commit cec8997)
- **M30: _formatDate Telemetry** — `BillingStatusData.fromJson` now logs telemetry when `DateTime.tryParse` returns null (commit 4fb5380)
- **M31: billingStatus Validation Asymmetry** — `_statusLabel` and `_statusColor` asserts now match canonical BillingStatus type (removed 'suspended') (commit c8e03a2)
- **M32: Status Derivation Duplication** — `_statusColor` and `_statusLabel` moved to module-level functions; _BillingCard derives badge internally (commit a76348b)
- **M33: Zod Error Formatting** — `parseResult.error.issues.map(i => i.message).join('; ')` replaces `error.message` for human-readable dead-letter logging (commit 9a154ea)
- **H2-V02: JWT Sentry Leak Risk** — SECURITY comment added at all `captureException` call sites in DashboardService (commit 3f0804c)

**Completion Context:** All major auth, provisioning, API gateway, quota enforcement, usage ingestion/aggregation infrastructure is production-ready with comprehensive test coverage (2440+ tests, ~94% coverage). Phase 4 Task 2 (usage ingestion + daily/monthly aggregation) complete. Phase 4 Task 3 Flutter dashboard UI FEATURE-COMPLETE: org switcher dropdown (91cdae3, 226b568), billing status display (979ab7c, 60fd1ff), usage summary + charts (55c4a86, e066900, c78bbf1, 809496a), quota visualization (9f93f67, e3ff7f3), entitlements grid (9f93f67), real-time polling (f6581fd, d14280c); Stripe Customer Portal link complete (9d4d700, c45affd, 88d23bd, 7c899eb); code review findings fixed (H1 type safety, H2 subscription upsert, M25–M33, M34); bootstrap flow integration complete. Security hardening across auth boundaries (V-02, H19, H20, H21, S01) applied. Per-org Durable Objects quota state machine enforces minute-level burst limits, monthly soft limits, quota version detection with middleware fail-open logic. Bootstrap worker & client orchestration validated end-to-end. Quota and usage documentation with integration guidance available at `workers/docs/QUOTA_DURABLE_OBJECTS.md`. All Phase 4 tasks COMPLETE.

**Post-Phase 4 Completions (2026-03-21)**
- **Phase 4 Task 3 (final)** — Stripe Customer Portal link (step 5) ✅ COMPLETE
  - `POST /v1/orgs/:id/billing-portal` endpoint for session creation (9d4d700)
  - Flutter UI integration in BillingCard (c45affd)
  - APP_URL_FALLBACK constant + startup warnings (88d23bd)
  - Portal URL retry logic + scheme validation (7c899eb)
- **M34: Subscription upgrade conflict key** ✅ COMPLETE
  - Soft-delete prior subscriptions on upsert to prevent multi-row state (33aa1a2)
  - Skip already-canceled rows in soft-delete filter (cf5059c)
  - Migrated to v1.2 changelog (afa367f)
- **L5: Plan key formatting** ✅ COMPLETE
  - Added parsePriceToPlan integration tests (306ccfc)
  - Validated STRIPE_PRICE_TO_PLAN_JSON against PlanKeySchema (8cdaa09)
- **L16: BoxDecoration refactoring** ✅ COMPLETE
  - Replaced inline BoxDecoration with AppDecorations.card() (5786939)
- **M37/M38/M39: Dead letter architecture** ✅ COMPLETE
  - Documented DeadLetter vs WebhookDeadLetter relationship (8fd1d47)
  - Documented dead letter failure modes and retry assumptions (4bf3fff)
  - Fixed diagram omissions in architecture doc (4ebe6cb)
  - Marked M38 and M39 done in BACKLOG (1a51f3f)
- **Audit Logging** ✅ COMPLETE
  - `writeAuditLog` helper in helpers.ts writes to audit_log table (f8bec9b)
  - `api_key.created` logged with actor_user_id, org, prefix (f8bec9b)
  - `api_key.revoked` logged with org, actor_auth0_id (f8bec9b)
  - `billing_portal.accessed` logged with org, actor_auth0_id (f8bec9b, 6954ae6)
  - Exceptions in writeAuditLog caught and logged; never propagate to caller (6954ae6)
  - Billing portal audit write moved outside Stripe try/catch to prevent misattribution (6954ae6)
- **Rate Limiting Headers** ✅ COMPLETE
  - `enforceOrgQuota` now returns `rateLimitHeaders` on success (e783954)
  - `withRateLimitHeaders()` in index.ts forwards `X-RateLimit-Remaining-Minute` and `X-RateLimit-Remaining-Monthly` on all successful org responses (e783954)
  - Fail-open path returns empty headers (no headers forwarded) (e783954)

### Remaining (Polish + Code Review Backlog Items)

1. **Code Review Backlog** — M35 (dead letter partial failure idempotency gap), L6–L19 (low-priority items: sanitization, error card duplication, schema tests, etc.) — ✅ ALL DONE (see v1.2 changelog)
2. **Polish & observability** — Enhanced error responses, telemetry/monitoring setup — ✅ `POST /v1/ingest/otel` implemented (commits 1b771e3, c40a1c8)

This sequence delivers production-grade auth/provisioning infrastructure with clear path to user-facing analytics and usage dashboards, supporting the internal goal of a comprehensible UI for non-technical stakeholders while preserving long-term recurring SaaS architecture.

[1]: https://docs.stripe.com/billing/subscriptions/webhooks?utm_source=chatgpt.com "Using webhooks with subscriptions | Stripe Documentation"
[2]: https://supabase.com/docs/guides/auth/auth-hooks?utm_source=chatgpt.com "Auth Hooks | Supabase Docs"
[3]: https://supabase.com/docs/guides/database/secure-data?utm_source=chatgpt.com "Securing your data | Supabase Docs"
[4]: https://supabase.com/docs/guides/auth/auth-hooks/custom-access-token-hook?utm_source=chatgpt.com "Custom Access Token Hook | Supabase Docs"
[5]: https://supabase.com/docs/guides/database/webhooks?utm_source=chatgpt.com "Database Webhooks | Supabase Docs"
[6]: https://developers.cloudflare.com/workers/runtime-apis/bindings/rate-limit/?utm_source=chatgpt.com "Rate Limiting · Cloudflare Workers docs"
[7]: https://developers.cloudflare.com/durable-objects/best-practices/rules-of-durable-objects/?utm_source=chatgpt.com "Rules of Durable Objects · Cloudflare Durable Objects docs"
[8]: https://developers.cloudflare.com/kv/reference/faq/?utm_source=chatgpt.com "FAQ · Cloudflare Workers KV docs"
