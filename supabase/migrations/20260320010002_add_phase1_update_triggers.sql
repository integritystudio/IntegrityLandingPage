-- Phase 1: Add updated_at Trigger Function and Triggers
-- Automatically updates the updated_at timestamp when records are modified

-- Create the update_timestamp function
create or replace function update_timestamp() returns trigger language plpgsql as $update_timestamp_fn$
begin
  new.updated_at = now();
  return new;
end;
$update_timestamp_fn$;

-- Apply trigger to organizations table
drop trigger if exists trigger_update_organizations_timestamp on public.organizations;
create trigger trigger_update_organizations_timestamp
  before update on public.organizations
  for each row
  execute function update_timestamp();

-- Apply trigger to subscriptions table
drop trigger if exists trigger_update_subscriptions_timestamp on public.subscriptions;
create trigger trigger_update_subscriptions_timestamp
  before update on public.subscriptions
  for each row
  execute function update_timestamp();

-- Apply trigger to organization_memberships table
drop trigger if exists trigger_update_organization_memberships_timestamp on public.organization_memberships;
create trigger trigger_update_organization_memberships_timestamp
  before update on public.organization_memberships
  for each row
  execute function update_timestamp();

-- Apply trigger to entitlements table
drop trigger if exists trigger_update_entitlements_timestamp on public.entitlements;
create trigger trigger_update_entitlements_timestamp
  before update on public.entitlements
  for each row
  execute function update_timestamp();
