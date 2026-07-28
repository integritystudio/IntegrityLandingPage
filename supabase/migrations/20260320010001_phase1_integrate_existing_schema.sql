-- Phase 1 Integration: Align with existing Supabase schema
-- Handles auth migration from Auth0 -> Supabase Auth via auth_user_links

-- Verify auth_user_links has correct structure
-- (it should already exist with auth_user_id -> app_user_id mapping)

-- Add RLS to auth_user_links if not already enabled
alter table if exists public.auth_user_links enable row level security;

-- RLS Policy: Users can view their own auth_user_link
-- Postgres has no IF NOT EXISTS for CREATE POLICY; drop-then-create is the
-- idempotent form.
drop policy if exists "users_view_own_auth_link" on public.auth_user_links;
create policy "users_view_own_auth_link"
  on public.auth_user_links for select
  using (auth.uid() = auth_user_id);

-- Add auth_user_id column to public.users for reference (optional but helpful)
alter table public.users
  add column if not exists auth_user_id uuid references auth.users(id) on delete cascade;

create index if not exists idx_users_auth_user_id on public.users(auth_user_id);

-- Note: auth_user_links is the primary reference point, not users.auth_user_id
-- Keep auth_user_links as the source of truth for auth-to-app user mapping

-- Ensure existing api_keys table is properly set up
-- Phase 1 does not modify existing api_keys; Phase 2 will extend it
alter table public.api_keys enable row level security;

-- RLS Policy: Users can view their own API keys
drop policy if exists "users_view_own_api_keys" on public.api_keys;
create policy "users_view_own_api_keys"
  on public.api_keys for select
  using (
    user_id in (
      select app_user_id from public.auth_user_links
      where auth_user_id = auth.uid()
    )
  );

-- Ensure existing roles table has proper permissions setup
-- Update executive role if it exists (idempotent)
update public.roles
  set permissions = permissions || '["dashboard.read","dashboard.executive"]'::jsonb
  where name = 'executive'
    and not (permissions @> '["dashboard.read"]'::jsonb);

-- Verify user_roles has proper structure
alter table if exists public.user_roles enable row level security;

-- Summary of identity model:
-- 1. auth.users: Supabase Auth layer (OAuth, sign-in sessions)
-- 2. public.users: App user identity (canonical, from Auth0 migration)
-- 3. public.auth_user_links: Bridge between auth.users and public.users
-- 4. public.api_keys: Existing API key management (user-scoped)
-- 5. public.roles / public.user_roles: Role-based access control
-- 6. organization_memberships: New org-scoped roles (from Phase 1)
--
-- This layering supports:
-- - Auth0 -> Supabase Auth migration via auth_user_links
-- - Existing user and role management
-- - New SaaS org-scoped authorization
-- - Multiple auth methods per user
