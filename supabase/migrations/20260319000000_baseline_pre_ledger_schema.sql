-- CR30 baseline: the 10 pre-ledger tables, reconstructed from production.
--
-- Until 2026-08-03 the migration ledger could not build this schema: it
-- creates 13 tables but foreign-keys into `users` and `api_keys`, which
-- nothing created. `db push` onto an empty project failed at statement 18
-- of 20260320000000. `migration list` never caught it because it compares
-- against production, which has had these tables since before the ledger.
--
-- Idempotent by construction so this is a no-op against production.

create extension if not exists "uuid-ossp" with schema extensions;

do $$ begin
  if not exists (select 1 from pg_type t join pg_namespace n on n.oid = t.typnamespace
                 where t.typname = 'api_key_status' and n.nspname = 'public') then
    create type public.api_key_status as enum ('active', 'revoked', 'expired');
  end if;
end $$;

do $$ begin
  if not exists (select 1 from pg_type t join pg_namespace n on n.oid = t.typnamespace
                 where t.typname = 'api_key_tier' and n.nspname = 'public') then
    create type public.api_key_tier as enum ('starter', 'growth', 'enterprise');
  end if;
end $$;

do $$ begin
  if not exists (select 1 from pg_type t join pg_namespace n on n.oid = t.typnamespace
                 where t.typname = 'organization_type' and n.nspname = 'public') then
    create type public.organization_type as enum ('personal', 'team', 'organization', 'parent-organization');
  end if;
end $$;

create table if not exists public.roles (
  id uuid default gen_random_uuid() not null,
  name character varying(100) not null,
  description text,
  permissions jsonb default '[]'::jsonb,
  created_at timestamp with time zone default CURRENT_TIMESTAMP,
  updated_at timestamp with time zone default CURRENT_TIMESTAMP,
  constraint "roles_pkey" PRIMARY KEY (id),
  constraint "roles_name_key" UNIQUE (name)
);

create table if not exists public.stripe_events (
  id text not null,
  event_type text not null,
  processed_at timestamp with time zone default now() not null,
  constraint "stripe_events_pkey" PRIMARY KEY (id)
);

create table if not exists public.users (
  id uuid default gen_random_uuid() not null,
  auth0_id character varying(255) not null,
  email character varying(255) not null,
  email_verified boolean default false,
  name character varying(255),
  nickname character varying(255),
  picture text,
  created_at timestamp with time zone default CURRENT_TIMESTAMP,
  updated_at timestamp with time zone default CURRENT_TIMESTAMP,
  last_login timestamp with time zone,
  login_count integer default 0,
  blocked boolean default false,
  metadata jsonb default '{}'::jsonb,
  tier api_key_tier default 'starter'::api_key_tier not null,
  default_organization_id uuid,
  auth_user_id uuid,
  constraint "users_pkey" PRIMARY KEY (id),
  constraint "users_auth0_id_key" UNIQUE (auth0_id),
  constraint "users_email_key" UNIQUE (email),
  constraint "users_auth_user_id_fkey" FOREIGN KEY (auth_user_id) REFERENCES auth.users(id) ON DELETE CASCADE
);

create table if not exists public.user_profiles (
  id uuid default gen_random_uuid() not null,
  user_id uuid,
  phone_number character varying(50),
  address text,
  city character varying(100),
  state character varying(100),
  zip_code character varying(20),
  country character varying(100),
  timezone character varying(50),
  locale character varying(10) default 'en-US'::character varying,
  preferences jsonb default '{}'::jsonb,
  created_at timestamp with time zone default CURRENT_TIMESTAMP,
  updated_at timestamp with time zone default CURRENT_TIMESTAMP,
  organization text,
  email text,
  full_name text,
  avatar_url text,
  constraint "user_profiles_pkey" PRIMARY KEY (id),
  constraint "user_profiles_user_id_key" UNIQUE (user_id),
  constraint "user_profiles_user_id_fkey" FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
);

create table if not exists public.user_activity (
  id uuid default gen_random_uuid() not null,
  user_id uuid,
  activity_type character varying(100) not null,
  description text,
  metadata jsonb default '{}'::jsonb,
  ip_address inet,
  user_agent text,
  created_at timestamp with time zone default CURRENT_TIMESTAMP,
  constraint "user_activity_pkey" PRIMARY KEY (id),
  constraint "user_activity_user_id_fkey" FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
);

create table if not exists public.user_roles (
  id uuid default gen_random_uuid() not null,
  user_id uuid not null,
  role_id uuid not null,
  granted_at timestamp with time zone default CURRENT_TIMESTAMP,
  granted_by uuid,
  constraint "user_roles_pkey" PRIMARY KEY (id),
  constraint "user_roles_user_id_role_id_key" UNIQUE (user_id, role_id),
  constraint "user_roles_granted_by_fkey" FOREIGN KEY (granted_by) REFERENCES users(id),
  constraint "user_roles_role_id_fkey" FOREIGN KEY (role_id) REFERENCES roles(id) ON DELETE CASCADE,
  constraint "user_roles_user_id_fkey" FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
);

create table if not exists public.user_sessions (
  id uuid default gen_random_uuid() not null,
  user_id uuid,
  session_token text not null,
  ip_address inet,
  user_agent text,
  device_type character varying(50),
  browser character varying(50),
  os character varying(50),
  country character varying(100),
  city character varying(100),
  created_at timestamp with time zone default CURRENT_TIMESTAMP,
  expires_at timestamp with time zone not null,
  last_activity timestamp with time zone default CURRENT_TIMESTAMP,
  is_active boolean default true,
  constraint "user_sessions_pkey" PRIMARY KEY (id),
  constraint "user_sessions_session_token_key" UNIQUE (session_token),
  constraint "user_sessions_user_id_fkey" FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
);

create table if not exists public.analytics_projects (
  project_id uuid default uuid_generate_v4() not null,
  user_id uuid not null,
  name text not null,
  description text,
  domain_name text,
  stage text not null,
  enabled_providers text[] default '{}'::text[],
  created_at timestamp with time zone default now(),
  updated_at timestamp with time zone default now(),
  last_event_at timestamp with time zone,
  total_events integer default 0,
  total_users integer default 0,
  total_sessions integer default 0,
  total_cost numeric(10,2) default 0.00,
  project_type text,
  constraint "analytics_projects_pkey" PRIMARY KEY (project_id),
  constraint "analytics_projects_user_id_fkey" FOREIGN KEY (user_id) REFERENCES auth.users(id),
  constraint "analytics_projects_stage_check" CHECK ((stage = ANY (ARRAY['development'::text, 'staging'::text, 'production'::text, 'archived'::text]))),
  constraint "valid_domain_name" CHECK (((domain_name IS NULL) OR ((length(domain_name) >= 1) AND (length(domain_name) <= 253) AND (domain_name ~ '\.'::text) AND (domain_name ~ '^([a-z0-9]([a-z0-9-]{0,61}[a-z0-9])?\.)+[a-z]{2,}$'::text))))
);

create table if not exists public.provider_oauth_tokens (
  id uuid default gen_random_uuid() not null,
  project_id uuid not null,
  user_id uuid not null,
  provider_type text default 'ga4'::text not null,
  property_id text,
  scope text not null,
  vault_access_token_id uuid,
  vault_refresh_token_id uuid,
  token_expires_at timestamp with time zone,
  last_sync_at timestamp with time zone,
  sync_status text default 'pending'::text,
  sync_error text,
  created_at timestamp with time zone default now(),
  updated_at timestamp with time zone default now(),
  access_token text,
  refresh_token text,
  constraint "provider_oauth_tokens_pkey" PRIMARY KEY (id),
  constraint "provider_oauth_tokens_project_id_provider_type_key" UNIQUE (project_id, provider_type),
  constraint "provider_oauth_tokens_project_id_fkey" FOREIGN KEY (project_id) REFERENCES analytics_projects(project_id) ON DELETE CASCADE,
  constraint "provider_oauth_tokens_user_id_fkey" FOREIGN KEY (user_id) REFERENCES auth.users(id) ON DELETE CASCADE,
  constraint "provider_oauth_tokens_provider_type_check" CHECK ((provider_type = ANY (ARRAY['ga4'::text, 'facebook_pixel'::text, 'google_ads'::text]))),
  constraint "provider_oauth_tokens_sync_status_check" CHECK ((sync_status = ANY (ARRAY['pending'::text, 'syncing'::text, 'success'::text, 'error'::text])))
);

create table if not exists public.api_keys (
  id uuid default gen_random_uuid() not null,
  user_id uuid not null,
  prefix character(8) not null,
  hash text not null,
  name text default 'Default'::text not null,
  tier api_key_tier default 'starter'::api_key_tier not null,
  status api_key_status default 'active'::api_key_status not null,
  expires_at timestamp with time zone,
  last_used_at timestamp with time zone,
  created_at timestamp with time zone default now() not null,
  revoked_at timestamp with time zone,
  organization_id uuid not null,
  updated_at timestamp with time zone default now() not null,
  constraint "api_keys_pkey" PRIMARY KEY (id),
  constraint "api_keys_hash_key" UNIQUE (hash),
  constraint "api_keys_organization_id_prefix_key" UNIQUE (organization_id, prefix),
  constraint "api_keys_user_id_fkey" FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
  constraint "revoked_has_timestamp" CHECK (((status <> 'revoked'::api_key_status) OR (revoked_at IS NOT NULL)))
);

create index if not exists idx_users_auth0_id ON public.users USING btree (auth0_id);
create index if not exists idx_users_auth_user_id ON public.users USING btree (auth_user_id);
create index if not exists idx_users_created_at ON public.users USING btree (created_at);
create index if not exists idx_users_default_organization_id ON public.users USING btree (default_organization_id);
create index if not exists idx_users_email ON public.users USING btree (email);
create index if not exists idx_user_profiles_user_id ON public.user_profiles USING btree (user_id);
create index if not exists idx_user_activity_created_at ON public.user_activity USING btree (created_at);
create index if not exists idx_user_activity_user_id ON public.user_activity USING btree (user_id);
create index if not exists idx_user_activity_user_id_created_at ON public.user_activity USING btree (user_id, created_at DESC);
create index if not exists idx_user_roles_role_id ON public.user_roles USING btree (role_id);
create index if not exists idx_user_roles_user_id ON public.user_roles USING btree (user_id);
create index if not exists idx_user_sessions_expires_at ON public.user_sessions USING btree (expires_at);
create index if not exists idx_user_sessions_token ON public.user_sessions USING btree (session_token);
create index if not exists idx_user_sessions_user_id ON public.user_sessions USING btree (user_id);
create index if not exists idx_user_sessions_user_id_created_at ON public.user_sessions USING btree (user_id, created_at DESC);
create index if not exists idx_projects_domain_name ON public.analytics_projects USING btree (domain_name) WHERE (domain_name IS NOT NULL);
create index if not exists idx_projects_stage ON public.analytics_projects USING btree (stage);
create index if not exists idx_projects_user_id ON public.analytics_projects USING btree (user_id);
create index if not exists idx_oauth_tokens_project_id ON public.provider_oauth_tokens USING btree (project_id);
create index if not exists idx_oauth_tokens_provider_type ON public.provider_oauth_tokens USING btree (provider_type);
create index if not exists idx_oauth_tokens_user_id ON public.provider_oauth_tokens USING btree (user_id);
create index if not exists idx_api_keys_hash ON public.api_keys USING btree (hash);
create index if not exists idx_api_keys_organization_id ON public.api_keys USING btree (organization_id);
create index if not exists idx_api_keys_status ON public.api_keys USING btree (status) WHERE (status = 'active'::api_key_status);
create index if not exists idx_api_keys_user_id ON public.api_keys USING btree (user_id);

alter table public.roles enable row level security;
alter table public.stripe_events enable row level security;
alter table public.users enable row level security;
alter table public.user_profiles enable row level security;
alter table public.user_activity enable row level security;
alter table public.user_roles enable row level security;
alter table public.user_sessions enable row level security;
alter table public.analytics_projects enable row level security;
alter table public.provider_oauth_tokens enable row level security;
alter table public.api_keys enable row level security;

drop policy if exists "Anyone can view roles" on public.roles;
create policy "Anyone can view roles" on public.roles
  as permissive
  for select
  to public
  using (true);

drop policy if exists "Users can insert their own data" on public.users;
create policy "Users can insert their own data" on public.users
  as permissive
  for insert
  to public
  with check ((auth.uid() = id));

drop policy if exists "Users can read their own data" on public.users;
create policy "Users can read their own data" on public.users
  as permissive
  for select
  to public
  using ((auth.uid() = id));

drop policy if exists "Users can update own data" on public.users;
create policy "Users can update own data" on public.users
  as permissive
  for update
  to public
  using (((auth.uid())::text = (auth0_id)::text));

drop policy if exists "Users can view own data" on public.users;
create policy "Users can view own data" on public.users
  as permissive
  for select
  to public
  using (((auth.uid())::text = (auth0_id)::text));

drop policy if exists "users can view own profile" on public.users;
create policy "users can view own profile" on public.users
  as permissive
  for select
  to public
  using ((id = auth.uid()));

drop policy if exists "Users can insert own profile" on public.user_profiles;
create policy "Users can insert own profile" on public.user_profiles
  as permissive
  for insert
  to public
  with check ((auth.uid() = id));

drop policy if exists "Users can update own profile" on public.user_profiles;
create policy "Users can update own profile" on public.user_profiles
  as permissive
  for update
  to public
  using ((user_id IN ( SELECT users.id
   FROM users
  WHERE ((users.auth0_id)::text = (auth.uid())::text))));

drop policy if exists "Users can view own profile" on public.user_profiles;
create policy "Users can view own profile" on public.user_profiles
  as permissive
  for select
  to public
  using ((user_id IN ( SELECT users.id
   FROM users
  WHERE ((users.auth0_id)::text = (auth.uid())::text))));

drop policy if exists "users can view own user_profile" on public.user_profiles;
create policy "users can view own user_profile" on public.user_profiles
  as permissive
  for select
  to public
  using ((user_id = auth.uid()));

drop policy if exists "Users can view own activity" on public.user_activity;
create policy "Users can view own activity" on public.user_activity
  as permissive
  for select
  to public
  using ((user_id IN ( SELECT users.id
   FROM users
  WHERE ((users.auth0_id)::text = (auth.uid())::text))));

drop policy if exists "users can view own activity" on public.user_activity;
create policy "users can view own activity" on public.user_activity
  as permissive
  for select
  to public
  using ((user_id = auth.uid()));

drop policy if exists "Users can view own roles" on public.user_roles;
create policy "Users can view own roles" on public.user_roles
  as permissive
  for select
  to public
  using ((user_id IN ( SELECT users.id
   FROM users
  WHERE ((users.auth0_id)::text = (auth.uid())::text))));

drop policy if exists "Users can view own sessions" on public.user_sessions;
create policy "Users can view own sessions" on public.user_sessions
  as permissive
  for select
  to public
  using ((user_id IN ( SELECT users.id
   FROM users
  WHERE ((users.auth0_id)::text = (auth.uid())::text))));

drop policy if exists "users can view own sessions" on public.user_sessions;
create policy "users can view own sessions" on public.user_sessions
  as permissive
  for select
  to public
  using ((user_id = auth.uid()));

drop policy if exists "Users can create projects" on public.analytics_projects;
create policy "Users can create projects" on public.analytics_projects
  as permissive
  for insert
  to public
  with check ((auth.uid() = user_id));

drop policy if exists "Users can delete own projects" on public.analytics_projects;
create policy "Users can delete own projects" on public.analytics_projects
  as permissive
  for delete
  to public
  using ((auth.uid() = user_id));

drop policy if exists "Users can update own projects" on public.analytics_projects;
create policy "Users can update own projects" on public.analytics_projects
  as permissive
  for update
  to public
  using ((auth.uid() = user_id));

drop policy if exists "Users can view own projects" on public.analytics_projects;
create policy "Users can view own projects" on public.analytics_projects
  as permissive
  for select
  to public
  using ((auth.uid() = user_id));

drop policy if exists "Users can create OAuth tokens" on public.provider_oauth_tokens;
create policy "Users can create OAuth tokens" on public.provider_oauth_tokens
  as permissive
  for insert
  to public
  with check ((auth.uid() = user_id));

drop policy if exists "Users can delete own OAuth tokens" on public.provider_oauth_tokens;
create policy "Users can delete own OAuth tokens" on public.provider_oauth_tokens
  as permissive
  for delete
  to public
  using ((auth.uid() = user_id));

drop policy if exists "Users can update own OAuth tokens" on public.provider_oauth_tokens;
create policy "Users can update own OAuth tokens" on public.provider_oauth_tokens
  as permissive
  for update
  to public
  using ((auth.uid() = user_id));

drop policy if exists "Users can view own OAuth tokens" on public.provider_oauth_tokens;
create policy "Users can view own OAuth tokens" on public.provider_oauth_tokens
  as permissive
  for select
  to public
  using ((auth.uid() = user_id));

drop policy if exists "service_role_full_access" on public.api_keys;
create policy "service_role_full_access" on public.api_keys
  as permissive
  for all
  to public
  using ((auth.role() = 'service_role'::text));

drop policy if exists "users_insert_own_keys" on public.api_keys;
create policy "users_insert_own_keys" on public.api_keys
  as permissive
  for insert
  to public
  with check ((user_id IN ( SELECT users.id
   FROM users
  WHERE ((users.auth0_id)::text = (auth.jwt() ->> 'sub'::text)))));

drop policy if exists "users_read_own_keys" on public.api_keys;
create policy "users_read_own_keys" on public.api_keys
  as permissive
  for select
  to public
  using ((user_id IN ( SELECT users.id
   FROM users
  WHERE ((users.auth0_id)::text = (auth.jwt() ->> 'sub'::text)))));

drop policy if exists "users_update_own_keys" on public.api_keys;
create policy "users_update_own_keys" on public.api_keys
  as permissive
  for update
  to public
  using ((user_id IN ( SELECT users.id
   FROM users
  WHERE ((users.auth0_id)::text = (auth.jwt() ->> 'sub'::text)))));

