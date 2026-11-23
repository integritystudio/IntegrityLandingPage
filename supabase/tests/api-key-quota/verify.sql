\set ON_ERROR_STOP on

-- Assertions for 20261122010000_api_key_quota_in_create.sql. Run via ./run.sh, which then
-- runs the two-session check (Q6) that a single psql script cannot.

create or replace function public.assert_eq(label text, actual text, expected text) returns void
language plpgsql as $$
begin
  if actual is distinct from expected then
    raise exception 'FAIL %: got % expected %', label, coalesce(actual, 'NULL'), coalesce(expected, 'NULL');
  end if;
  raise notice 'PASS %', label;
end $$;

-- Passes only if `stmt` raises api_key_quota_exceeded (P0001).
create or replace function public.assert_quota_exceeded(label text, stmt text) returns void
language plpgsql as $$
begin
  begin
    execute stmt;
  exception when raise_exception then
    if sqlerrm = 'api_key_quota_exceeded' then
      raise notice 'PASS %', label;
      return;
    end if;
    raise;
  end;
  raise exception 'FAIL %: the create succeeded', label;
end $$;

grant execute on function public.assert_eq(text, text, text) to service_role;
grant execute on function public.assert_quota_exceeded(text, text) to service_role;

-- Q1 privileges carry over to the new signature, and the old one is gone
select assert_eq('Q1a anon cannot execute the new signature',
  has_function_privilege('anon', 'public.create_api_key_for_request(uuid,uuid,uuid,text,text,text,public.api_key_tier,integer)', 'execute')::text, 'false');
select assert_eq('Q1b authenticated cannot execute the new signature',
  has_function_privilege('authenticated', 'public.create_api_key_for_request(uuid,uuid,uuid,text,text,text,public.api_key_tier,integer)', 'execute')::text, 'false');
select assert_eq('Q1c service_role can execute the new signature',
  has_function_privilege('service_role', 'public.create_api_key_for_request(uuid,uuid,uuid,text,text,text,public.api_key_tier,integer)', 'execute')::text, 'true');
select assert_eq('Q1d exactly one create_api_key_for_request remains',
  (select count(*)::text from pg_proc where proname = 'create_api_key_for_request'), '1');

set role service_role;

-- Q2 a call without a limit, as an edge function that predates this migration makes, is unlimited
select create_api_key_for_request('20000000-0000-0000-0000-000000000021', '00000000-0000-0000-0000-000000000001',
  '00000000-0000-0000-0000-00000000000a', 'bbbb0021', 'hash-q21', 'q2', 'starter') is not null as q21 \gset
select create_api_key_for_request('20000000-0000-0000-0000-000000000022', '00000000-0000-0000-0000-000000000001',
  '00000000-0000-0000-0000-00000000000a', 'bbbb0022', 'hash-q22', 'q2', 'starter') is not null as q22 \gset
select assert_eq('Q2 two creates with no limit both succeed',
  (select count(*)::text from api_keys where hash in ('hash-q21', 'hash-q22')), '2');

-- Q3 under the limit a create succeeds (2 keys held, limit 3)
select create_api_key_for_request('20000000-0000-0000-0000-000000000031', '00000000-0000-0000-0000-000000000001',
  '00000000-0000-0000-0000-00000000000a', 'bbbb0031', 'hash-q31', 'q3', 'starter', 3) is not null as q31 \gset
select assert_eq('Q3 a create under the limit inserted its key',
  (select count(*)::text from api_keys where hash = 'hash-q31'), '1');

-- Q4 at the limit a create raises, inserts nothing and claims no request
select assert_quota_exceeded('Q4a a create at the limit raises api_key_quota_exceeded',
  $$select create_api_key_for_request('20000000-0000-0000-0000-000000000041', '00000000-0000-0000-0000-000000000001',
    '00000000-0000-0000-0000-00000000000a', 'bbbb0041', 'hash-q41', 'q4', 'starter', 3)$$);
select assert_eq('Q4b no key row was inserted',
  (select count(*)::text from api_keys where hash = 'hash-q41'), '0');
select assert_eq('Q4c the refused create claimed no request row',
  (select count(*)::text from api_key_requests where request_id = '20000000-0000-0000-0000-000000000041'), '0');

-- Q5 a revoked key frees its slot; an inactive one keeps it
reset role;
update api_keys set status = 'revoked', revoked_at = now() where hash = 'hash-q21';
update api_keys set status = 'inactive' where hash = 'hash-q22';
set role service_role;
select create_api_key_for_request('20000000-0000-0000-0000-000000000051', '00000000-0000-0000-0000-000000000001',
  '00000000-0000-0000-0000-00000000000a', 'bbbb0051', 'hash-q51', 'q5', 'starter', 3) is not null as q51 \gset
select assert_eq('Q5a a revoked key frees a slot',
  (select count(*)::text from api_keys where hash = 'hash-q51'), '1');
select assert_quota_exceeded('Q5b an inactive key still holds its slot',
  $$select create_api_key_for_request('20000000-0000-0000-0000-000000000052', '00000000-0000-0000-0000-000000000001',
    '00000000-0000-0000-0000-00000000000a', 'bbbb0052', 'hash-q52', 'q5', 'starter', 3)$$);

reset role;
-- Leave the org one slot short of the run.sh concurrency check's limit.
update api_keys set status = 'revoked', revoked_at = now() where status <> 'revoked';
