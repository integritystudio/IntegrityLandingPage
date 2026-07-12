-- WARNING: This schema is for context only and is not meant to be run.
-- Table order and constraints may not be valid for execution.

CREATE TABLE public.analytics_projects (
  project_id uuid NOT NULL DEFAULT uuid_generate_v4(),
  user_id uuid NOT NULL,
  name text NOT NULL,
  description text,
  domain_name text CHECK (domain_name IS NULL OR length(domain_name) >= 1 AND length(domain_name) <= 253 AND domain_name ~ '\.'::text AND domain_name ~ '^([a-z0-9]([a-z0-9-]{0,61}[a-z0-9])?\.)+[a-z]{2,}$'::text),
  stage text NOT NULL CHECK (stage = ANY (ARRAY['development'::text, 'staging'::text, 'production'::text, 'archived'::text])),
  enabled_providers ARRAY DEFAULT '{}'::text[],
  created_at timestamp with time zone DEFAULT now(),
  updated_at timestamp with time zone DEFAULT now(),
  last_event_at timestamp with time zone,
  total_events integer DEFAULT 0,
  total_users integer DEFAULT 0,
  total_sessions integer DEFAULT 0,
  total_cost numeric DEFAULT 0.00,
  project_type text,
  CONSTRAINT analytics_projects_pkey PRIMARY KEY (project_id),
  CONSTRAINT analytics_projects_user_id_fkey FOREIGN KEY (user_id) REFERENCES auth.users(id)
);

CREATE TABLE public.api_keys (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL,
  prefix character NOT NULL,
  hash text NOT NULL UNIQUE,
  name text NOT NULL DEFAULT 'Default'::text,
  tier USER-DEFINED NOT NULL DEFAULT 'starter'::api_key_tier,
  status USER-DEFINED NOT NULL DEFAULT 'active'::api_key_status,
  expires_at timestamp with time zone,
  last_used_at timestamp with time zone,
  created_at timestamp with time zone NOT NULL DEFAULT now(),
  revoked_at timestamp with time zone,
  organization_id uuid NOT NULL,
  CONSTRAINT api_keys_pkey PRIMARY KEY (id),
  CONSTRAINT api_keys_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.users(id),
  CONSTRAINT api_keys_organization_id_fkey FOREIGN KEY (organization_id) REFERENCES public.organizations(id)
);

CREATE TABLE public.audit_log (
  id bigint GENERATED ALWAYS AS IDENTITY NOT NULL,
  organization_id uuid,
  actor_user_id uuid,
  actor_api_key_id uuid,
  action text NOT NULL,
  target_type text NOT NULL,
  target_id text NOT NULL,
  old_values jsonb,
  new_values jsonb,
  metadata jsonb NOT NULL DEFAULT '{}'::jsonb,
  created_at timestamp with time zone NOT NULL DEFAULT now(),
  CONSTRAINT audit_log_pkey PRIMARY KEY (id),
  CONSTRAINT audit_log_organization_id_fkey FOREIGN KEY (organization_id) REFERENCES public.organizations(id),
  CONSTRAINT audit_log_actor_user_id_fkey FOREIGN KEY (actor_user_id) REFERENCES public.users(id),
  CONSTRAINT audit_log_actor_api_key_id_fkey FOREIGN KEY (actor_api_key_id) REFERENCES public.api_keys(id)
);

CREATE TABLE public.auth_user_links (
  auth_user_id uuid NOT NULL,
  app_user_id uuid NOT NULL UNIQUE,
  created_at timestamp with time zone NOT NULL DEFAULT now(),
  CONSTRAINT auth_user_links_pkey PRIMARY KEY (auth_user_id),
  CONSTRAINT auth_user_links_auth_user_id_fkey FOREIGN KEY (auth_user_id) REFERENCES auth.users(id),
  CONSTRAINT auth_user_links_app_user_id_fkey FOREIGN KEY (app_user_id) REFERENCES public.users(id)
);

CREATE TABLE public.billing_event_log (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  organization_id uuid,
  stripe_event_id text NOT NULL UNIQUE,
  event_type text NOT NULL CHECK (event_type = ANY (ARRAY['checkout.session.completed'::text, 'invoice.paid'::text, 'invoice.payment_failed'::text, 'customer.subscription.updated'::text, 'customer.subscription.deleted'::text, 'charge.refunded'::text, 'other'::text])),
  payload jsonb NOT NULL,
  processed_at timestamp with time zone,
  error_message text,
  created_at timestamp with time zone NOT NULL DEFAULT now(),
  CONSTRAINT billing_event_log_pkey PRIMARY KEY (id),
  CONSTRAINT billing_event_log_organization_id_fkey FOREIGN KEY (organization_id) REFERENCES public.organizations(id)
);

CREATE TABLE public.entitlements (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  organization_id uuid NOT NULL,
  feature_key text NOT NULL,
  enabled boolean NOT NULL DEFAULT false,
  hard_limit bigint,
  soft_limit bigint,
  config jsonb NOT NULL DEFAULT '{}'::jsonb,
  updated_at timestamp with time zone NOT NULL DEFAULT now(),
  CONSTRAINT entitlements_pkey PRIMARY KEY (id),
  CONSTRAINT entitlements_organization_id_fkey FOREIGN KEY (organization_id) REFERENCES public.organizations(id)
);

CREATE TABLE public.organization_memberships (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  organization_id uuid NOT NULL,
  user_id uuid NOT NULL,
  role text NOT NULL CHECK (role = ANY (ARRAY['owner'::text, 'admin'::text, 'member'::text, 'billing_admin'::text, 'viewer'::text])),
  status text NOT NULL DEFAULT 'active'::text CHECK (status = ANY (ARRAY['active'::text, 'invited'::text, 'suspended'::text])),
  created_at timestamp with time zone NOT NULL DEFAULT now(),
  updated_at timestamp with time zone NOT NULL DEFAULT now(),
  CONSTRAINT organization_memberships_pkey PRIMARY KEY (id),
  CONSTRAINT organization_memberships_organization_id_fkey FOREIGN KEY (organization_id) REFERENCES public.organizations(id),
  CONSTRAINT organization_memberships_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.users(id)
);

CREATE TABLE public.organizations (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  slug text NOT NULL UNIQUE,
  name text NOT NULL,
  type text,
  stripe_customer_id text UNIQUE,
  active_subscription_id uuid,
  billing_status text NOT NULL DEFAULT 'inactive'::text,
  current_plan text NOT NULL DEFAULT 'free'::text,
  quota_version bigint NOT NULL DEFAULT 1,
  created_at timestamp with time zone NOT NULL DEFAULT now(),
  updated_at timestamp with time zone NOT NULL DEFAULT now(),
  CONSTRAINT organizations_pkey PRIMARY KEY (id),
  CONSTRAINT fk_organizations_active_subscription_id FOREIGN KEY (active_subscription_id) REFERENCES public.subscriptions(id)
);

CREATE TABLE public.plans (
  key text NOT NULL,
  display_name text NOT NULL,
  monthly_units bigint,
  requests_per_minute integer,
  concurrent_jobs integer,
  features jsonb NOT NULL DEFAULT '{}'::jsonb,
  created_at timestamp with time zone NOT NULL DEFAULT now(),
  CONSTRAINT plans_pkey PRIMARY KEY (key)
);

CREATE TABLE public.provider_oauth_tokens (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  project_id uuid NOT NULL,
  user_id uuid NOT NULL,
  provider_type text NOT NULL DEFAULT 'ga4'::text CHECK (provider_type = ANY (ARRAY['ga4'::text, 'facebook_pixel'::text, 'google_ads'::text])),
  property_id text,
  scope text NOT NULL,
  vault_access_token_id uuid,
  vault_refresh_token_id uuid,
  token_expires_at timestamp with time zone,
  last_sync_at timestamp with time zone,
  sync_status text DEFAULT 'pending'::text CHECK (sync_status = ANY (ARRAY['pending'::text, 'syncing'::text, 'success'::text, 'error'::text])),
  sync_error text,
  created_at timestamp with time zone DEFAULT now(),
  updated_at timestamp with time zone DEFAULT now(),
  access_token text,
  refresh_token text,
  CONSTRAINT provider_oauth_tokens_pkey PRIMARY KEY (id),
  CONSTRAINT provider_oauth_tokens_project_id_fkey FOREIGN KEY (project_id) REFERENCES public.analytics_projects(project_id),
  CONSTRAINT provider_oauth_tokens_user_id_fkey FOREIGN KEY (user_id) REFERENCES auth.users(id)
);

CREATE TABLE public.provisioning_jobs (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  job_type text NOT NULL CHECK (job_type = ANY (ARRAY['user_created'::text, 'user_updated'::text, 'membership_changed'::text, 'subscription_changed'::text, 'entitlements_recomputed'::text, 'quota_version_bumped'::text])),
  source text NOT NULL CHECK (source = ANY (ARRAY['supabase_webhook'::text, 'stripe_webhook'::text, 'auth0_webhook'::text, 'manual'::text, 'migration'::text])),
  dedupe_key text NOT NULL UNIQUE,
  organization_id uuid,
  user_id uuid,
  payload jsonb NOT NULL,
  status text NOT NULL DEFAULT 'pending'::text CHECK (status = ANY (ARRAY['pending'::text, 'processing'::text, 'completed'::text, 'failed'::text, 'retried'::text])),
  result jsonb,
  error_message text,
  retry_count integer NOT NULL DEFAULT 0,
  max_retries integer NOT NULL DEFAULT 3,
  created_at timestamp with time zone NOT NULL DEFAULT now(),
  updated_at timestamp with time zone NOT NULL DEFAULT now(),
  completed_at timestamp with time zone,
  CONSTRAINT provisioning_jobs_pkey PRIMARY KEY (id),
  CONSTRAINT provisioning_jobs_organization_id_fkey FOREIGN KEY (organization_id) REFERENCES public.organizations(id),
  CONSTRAINT provisioning_jobs_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.users(id)
);

CREATE TABLE public.roles (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  name character varying NOT NULL UNIQUE,
  description text,
  permissions jsonb DEFAULT '[]'::jsonb,
  created_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP,
  updated_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP,
  CONSTRAINT roles_pkey PRIMARY KEY (id)
);

CREATE TABLE public.subscriptions (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  organization_id uuid NOT NULL,
  stripe_subscription_id text NOT NULL UNIQUE,
  stripe_price_id text,
  status text NOT NULL,
  current_period_start timestamp with time zone,
  current_period_end timestamp with time zone,
  cancel_at_period_end boolean NOT NULL DEFAULT false,
  created_at timestamp with time zone NOT NULL DEFAULT now(),
  updated_at timestamp with time zone NOT NULL DEFAULT now(),
  CONSTRAINT subscriptions_pkey PRIMARY KEY (id),
  CONSTRAINT subscriptions_organization_id_fkey FOREIGN KEY (organization_id) REFERENCES public.organizations(id)
);

CREATE TABLE public.usage_buckets_daily (
  organization_id uuid NOT NULL,
  bucket_date date NOT NULL,
  metric_key text NOT NULL,
  total_quantity bigint NOT NULL DEFAULT 0,
  request_count bigint NOT NULL DEFAULT 0,
  avg_latency_ms numeric,
  updated_at timestamp with time zone NOT NULL DEFAULT now(),
  CONSTRAINT usage_buckets_daily_pkey PRIMARY KEY (organization_id, bucket_date, metric_key),
  CONSTRAINT usage_buckets_daily_organization_id_fkey FOREIGN KEY (organization_id) REFERENCES public.organizations(id)
);

CREATE TABLE public.usage_events (
  id bigint GENERATED ALWAYS AS IDENTITY NOT NULL,
  organization_id uuid NOT NULL,
  user_id uuid,
  api_key_id uuid,
  route text NOT NULL,
  metric_key text NOT NULL,
  quantity bigint NOT NULL DEFAULT 1,
  request_id text NOT NULL,
  source text NOT NULL CHECK (source = ANY (ARRAY['api'::text, 'ingest'::text, 'job'::text, 'internal'::text, 'migration'::text])),
  status_code integer,
  latency_ms integer,
  metadata jsonb NOT NULL DEFAULT '{}'::jsonb,
  created_at timestamp with time zone NOT NULL DEFAULT now(),
  CONSTRAINT usage_events_pkey PRIMARY KEY (id),
  CONSTRAINT usage_events_organization_id_fkey FOREIGN KEY (organization_id) REFERENCES public.organizations(id),
  CONSTRAINT usage_events_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.users(id),
  CONSTRAINT usage_events_api_key_id_fkey FOREIGN KEY (api_key_id) REFERENCES public.api_keys(id)
);

CREATE TABLE public.user_activity (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  user_id uuid,
  activity_type character varying NOT NULL,
  description text,
  metadata jsonb DEFAULT '{}'::jsonb,
  ip_address inet,
  user_agent text,
  created_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP,
  CONSTRAINT user_activity_pkey PRIMARY KEY (id),
  CONSTRAINT user_activity_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.users(id)
);

CREATE TABLE public.user_profiles (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  user_id uuid UNIQUE,
  phone_number character varying,
  address text,
  city character varying,
  state character varying,
  zip_code character varying,
  country character varying,
  timezone character varying,
  locale character varying DEFAULT 'en-US'::character varying,
  preferences jsonb DEFAULT '{}'::jsonb,
  created_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP,
  updated_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP,
  organization text,
  role text,
  email text,
  full_name text,
  avatar_url text,
  CONSTRAINT user_profiles_pkey PRIMARY KEY (id),
  CONSTRAINT user_profiles_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.users(id)
);

CREATE TABLE public.user_roles (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  user_id uuid,
  role_id uuid,
  granted_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP,
  granted_by uuid,
  CONSTRAINT user_roles_pkey PRIMARY KEY (id),
  CONSTRAINT user_roles_granted_by_fkey FOREIGN KEY (granted_by) REFERENCES public.users(id),
  CONSTRAINT user_roles_role_id_fkey FOREIGN KEY (role_id) REFERENCES public.roles(id),
  CONSTRAINT user_roles_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.users(id)
);

CREATE TABLE public.user_sessions (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  user_id uuid,
  session_token text NOT NULL UNIQUE,
  ip_address inet,
  user_agent text,
  device_type character varying,
  browser character varying,
  os character varying,
  country character varying,
  city character varying,
  created_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP,
  expires_at timestamp with time zone NOT NULL,
  last_activity timestamp with time zone DEFAULT CURRENT_TIMESTAMP,
  is_active boolean DEFAULT true,
  CONSTRAINT user_sessions_pkey PRIMARY KEY (id),
  CONSTRAINT user_sessions_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.users(id)
);

CREATE TABLE public.users (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  auth0_id character varying NOT NULL UNIQUE,
  email character varying NOT NULL UNIQUE,
  email_verified boolean DEFAULT false,
  name character varying,
  nickname character varying,
  picture text,
  created_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP,
  updated_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP,
  last_login timestamp with time zone,
  login_count integer DEFAULT 0,
  blocked boolean DEFAULT false,
  metadata jsonb DEFAULT '{}'::jsonb,
  tier USER-DEFINED NOT NULL DEFAULT 'starter'::api_key_tier,
  default_organization_id uuid,
  CONSTRAINT users_pkey PRIMARY KEY (id),
  CONSTRAINT users_default_organization_id_fkey FOREIGN KEY (default_organization_id) REFERENCES public.organizations(id)
);
