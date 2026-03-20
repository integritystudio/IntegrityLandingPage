-- Create auth_user_links bridge table for Auth0 → Supabase Auth migration
-- Links auth.users (Supabase Auth) to public.users (legacy app users)
-- Required by Phase 1 RLS policies and organization membership authorization

create table if not exists public.auth_user_links (
  auth_user_id uuid not null,
  app_user_id uuid not null unique,
  created_at timestamptz not null default now(),
  constraint auth_user_links_pkey primary key (auth_user_id),
  constraint auth_user_links_auth_user_id_fkey foreign key (auth_user_id) references auth.users(id) on delete cascade,
  constraint auth_user_links_app_user_id_fkey foreign key (app_user_id) references public.users(id) on delete cascade
);

-- Indexes for RLS policy performance (joins on these columns)
create index if not exists idx_auth_user_links_auth_user_id on public.auth_user_links(auth_user_id);
create index if not exists idx_auth_user_links_app_user_id on public.auth_user_links(app_user_id);

-- Enable RLS
alter table public.auth_user_links enable row level security;

-- Users can only see their own link
create policy "users_view_own_auth_link"
  on public.auth_user_links for select
  using (auth.uid() = auth_user_id);
