-- Per-attempt request ids for api-keys-create, so a caller that loses the response can
-- abandon the attempt without leaving a live key behind.
--
-- The provisioning receiver (observability-toolkit services/api-provisioning-receiver)
-- times api-keys-create out after 10 s. When the response is lost the key row may already
-- exist while its plaintext token went with the response: a live KV credential and a quota
-- slot nobody can use, and a retry mints a second key. The receiver now sends a fresh
-- requestId per attempt; api-keys-create creates through create_api_key_for_request, and
-- on a lost response the receiver calls abandon_api_key_request and revokes the key it
-- returns.
--
-- Both functions claim the same api_key_requests primary key, so whichever commits first
-- wins and a concurrent claim waits on the in-flight one: abandon either returns the id of
-- a committed key or makes a create that has not committed yet fail. The name/created_at
-- lookup this replaces could do neither: it missed a create that committed after it ran,
-- and it matched a concurrent same-named key from another attempt.
--
-- Deploy order: apply this migration -> deploy api-keys-create -> deploy the receiver.
--
-- Hosted default privileges grant EXECUTE on every new function in public to anon and
-- authenticated (20261007010000), and table privileges likewise, so both are revoked from
-- those roles explicitly, not only from PUBLIC.

create table public.api_key_requests (
  request_id uuid primary key,
  api_key_id uuid references public.api_keys(id) on delete set null,
  abandoned_at timestamptz,
  created_at timestamptz not null default now()
);

alter table public.api_key_requests enable row level security;
revoke all on table public.api_key_requests from anon, authenticated;
grant select, insert, update on table public.api_key_requests to service_role;

-- Claim the request id, then insert the key exactly as api-keys-create's direct path does.
-- A request id already claimed (by abandon_api_key_request, or a replayed create) raises.
create function public.create_api_key_for_request(
  p_request_id uuid,
  p_user_id uuid,
  p_organization_id uuid,
  p_prefix text,
  p_hash text,
  p_name text,
  p_tier public.api_key_tier
) returns uuid
language plpgsql
security invoker
set search_path = public
as $$
declare
  v_claimed uuid;
  v_key_id uuid;
begin
  insert into api_key_requests (request_id) values (p_request_id)
    on conflict (request_id) do nothing
    returning request_id into v_claimed;
  if v_claimed is null then
    raise exception 'api_key_request_abandoned' using errcode = 'P0001';
  end if;

  insert into api_keys (user_id, organization_id, prefix, hash, name, tier, status)
    values (p_user_id, p_organization_id, p_prefix, p_hash, p_name, p_tier, 'active')
    returning id into v_key_id;

  update api_key_requests set api_key_id = v_key_id where request_id = p_request_id;
  return v_key_id;
end $$;

-- Mark the request abandoned and return the key it created, or null when no create has
-- committed (one that has not yet will then fail). Repeat calls keep the first abandoned_at.
create function public.abandon_api_key_request(p_request_id uuid) returns uuid
language sql
security invoker
set search_path = public
as $$
  insert into api_key_requests (request_id, abandoned_at) values (p_request_id, now())
  on conflict (request_id) do update
    set abandoned_at = coalesce(api_key_requests.abandoned_at, excluded.abandoned_at)
  returning api_key_id;
$$;

revoke execute on function public.create_api_key_for_request(uuid, uuid, uuid, text, text, text, public.api_key_tier)
  from public, anon, authenticated;
revoke execute on function public.abandon_api_key_request(uuid) from public, anon, authenticated;
grant execute on function public.create_api_key_for_request(uuid, uuid, uuid, text, text, text, public.api_key_tier)
  to service_role;
grant execute on function public.abandon_api_key_request(uuid) to service_role;
