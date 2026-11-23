-- Enforce the per-org API-key quota inside create_api_key_for_request.
--
-- The provisioning receiver counted an org's keys and then called api-keys-create, so N
-- concurrent provisions for one org (team members signing up together, or one user's
-- double submit) all read the same count and all minted past the limit. The count now
-- runs in the creating transaction, under a per-org transaction advisory lock, so
-- concurrent creates for one org queue and each sees the keys the previous one committed.
--
-- The limit itself stays where it is decided: the receiver's QUOTA_LIMITS and effective
-- plan. It passes the number through api-keys-create as p_key_limit; null means unlimited
-- (enterprise, and every caller that predates this migration, so applying it changes
-- nothing until the edge function and the receiver send a limit).
--
-- Active and inactive keys hold a slot, revoked ones do not: the same rule as the
-- receiver's checkOrgKeyQuota. api-keys-rotate inserts directly, not through this function,
-- so a rotation at the limit still succeeds.
--
-- Deploy order: apply this migration -> deploy api-keys-create -> deploy the receiver.

drop function public.create_api_key_for_request(uuid, uuid, uuid, text, text, text, public.api_key_tier);

create function public.create_api_key_for_request(
  p_request_id uuid,
  p_user_id uuid,
  p_organization_id uuid,
  p_prefix text,
  p_hash text,
  p_name text,
  p_tier public.api_key_tier,
  p_key_limit integer default null
) returns uuid
language plpgsql
security invoker
set search_path = public
as $$
declare
  v_claimed uuid;
  v_key_id uuid;
  v_key_count integer;
begin
  insert into api_key_requests (request_id) values (p_request_id)
    on conflict (request_id) do nothing
    returning request_id into v_claimed;
  if v_claimed is null then
    raise exception 'api_key_request_abandoned' using errcode = 'P0001';
  end if;

  if p_key_limit is not null then
    perform pg_advisory_xact_lock(hashtextextended(p_organization_id::text, 0));
    select count(*) into v_key_count
      from api_keys
      where organization_id = p_organization_id and status in ('active', 'inactive');
    if v_key_count >= p_key_limit then
      raise exception 'api_key_quota_exceeded'
        using errcode = 'P0001', detail = format('%s of %s keys in use', v_key_count, p_key_limit);
    end if;
  end if;

  insert into api_keys (user_id, organization_id, prefix, hash, name, tier, status)
    values (p_user_id, p_organization_id, p_prefix, p_hash, p_name, p_tier, 'active')
    returning id into v_key_id;

  update api_key_requests set api_key_id = v_key_id where request_id = p_request_id;
  return v_key_id;
end $$;

revoke execute on function public.create_api_key_for_request(uuid, uuid, uuid, text, text, text, public.api_key_tier, integer)
  from public, anon, authenticated;
grant execute on function public.create_api_key_for_request(uuid, uuid, uuid, text, text, text, public.api_key_tier, integer)
  to service_role;
