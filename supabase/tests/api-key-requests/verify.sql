\set ON_ERROR_STOP on

-- Assertions for 20261010000000_api_key_requests.sql. Run via ./run.sh, which then runs
-- the two-session concurrency checks (T9, T10) that a single psql script cannot.
-- The functions are security invoker and only service_role may call them, so every call
-- below runs under `set role service_role`.

create or replace function public.assert_eq(label text, actual text, expected text) returns void
language plpgsql as $$
begin
  if actual is distinct from expected then
    raise exception 'FAIL %: got % expected %', label, coalesce(actual, 'NULL'), coalesce(expected, 'NULL');
  end if;
  raise notice 'PASS %', label;
end $$;

-- Passes only if `stmt` raises api_key_request_abandoned (P0001).
create or replace function public.assert_abandoned(label text, stmt text) returns void
language plpgsql as $$
begin
  begin
    execute stmt;
  exception when raise_exception then
    if sqlerrm = 'api_key_request_abandoned' then
      raise notice 'PASS %', label;
      return;
    end if;
    raise;
  end;
  raise exception 'FAIL %: the create succeeded', label;
end $$;

grant execute on function public.assert_eq(text, text, text) to service_role;
grant execute on function public.assert_abandoned(text, text) to service_role;

-- T1 shape: RLS on, no policies, so only an RLS-bypassing role reads it
select assert_eq('T1a RLS enabled on api_key_requests',
  (select relrowsecurity::text from pg_class where oid = 'public.api_key_requests'::regclass), 'true');
select assert_eq('T1b no policies on api_key_requests',
  (select count(*)::text from pg_policy where polrelid = 'public.api_key_requests'::regclass), '0');

-- T2 privileges: the hosted default grants are gone from anon and authenticated
select assert_eq('T2a anon cannot execute create_api_key_for_request',
  has_function_privilege('anon', 'public.create_api_key_for_request(uuid,uuid,uuid,text,text,text,public.api_key_tier)', 'execute')::text, 'false');
select assert_eq('T2b authenticated cannot execute create_api_key_for_request',
  has_function_privilege('authenticated', 'public.create_api_key_for_request(uuid,uuid,uuid,text,text,text,public.api_key_tier)', 'execute')::text, 'false');
select assert_eq('T2c anon cannot execute abandon_api_key_request',
  has_function_privilege('anon', 'public.abandon_api_key_request(uuid)', 'execute')::text, 'false');
select assert_eq('T2d authenticated cannot execute abandon_api_key_request',
  has_function_privilege('authenticated', 'public.abandon_api_key_request(uuid)', 'execute')::text, 'false');
select assert_eq('T2e service_role can execute both',
  (has_function_privilege('service_role', 'public.create_api_key_for_request(uuid,uuid,uuid,text,text,text,public.api_key_tier)', 'execute')
   and has_function_privilege('service_role', 'public.abandon_api_key_request(uuid)', 'execute'))::text, 'true');
select assert_eq('T2f anon has no privilege on the table',
  (has_table_privilege('anon', 'public.api_key_requests', 'select')
   or has_table_privilege('anon', 'public.api_key_requests', 'insert')
   or has_table_privilege('anon', 'public.api_key_requests', 'update')
   or has_table_privilege('anon', 'public.api_key_requests', 'delete'))::text, 'false');
select assert_eq('T2g authenticated has no privilege on the table',
  (has_table_privilege('authenticated', 'public.api_key_requests', 'select')
   or has_table_privilege('authenticated', 'public.api_key_requests', 'insert')
   or has_table_privilege('authenticated', 'public.api_key_requests', 'update')
   or has_table_privilege('authenticated', 'public.api_key_requests', 'delete'))::text, 'false');

set role service_role;

-- T3 create then abandon: abandon returns the key the create committed
select create_api_key_for_request(
  '10000000-0000-0000-0000-000000000003', '00000000-0000-0000-0000-000000000001',
  '00000000-0000-0000-0000-00000000000a', 'aaaa0003', 'hash-t3', 'key-t3', 'growth') as t3_key \gset
select assert_eq('T3a create inserted an active key with the given fields',
  (select concat_ws('|', status, tier, name, prefix, hash) from api_keys where id = :'t3_key'),
  'active|growth|key-t3|aaaa0003|hash-t3');
select assert_eq('T3b the request row points at the key',
  (select api_key_id::text from api_key_requests where request_id = '10000000-0000-0000-0000-000000000003'), :'t3_key');
select assert_eq('T3c abandon returns the created key id',
  abandon_api_key_request('10000000-0000-0000-0000-000000000003')::text, :'t3_key');

-- T4 abandon then create: the create raises and inserts nothing
select assert_eq('T4a abandon of an unclaimed request returns null',
  abandon_api_key_request('10000000-0000-0000-0000-000000000004')::text, null);
select assert_abandoned('T4b create after abandon raises api_key_request_abandoned',
  $$select create_api_key_for_request('10000000-0000-0000-0000-000000000004', '00000000-0000-0000-0000-000000000001',
    '00000000-0000-0000-0000-00000000000a', 'aaaa0004', 'hash-t4', 'key-t4', 'starter')$$);
select assert_eq('T4c no key row was inserted',
  (select count(*)::text from api_keys where hash = 'hash-t4'), '0');
select assert_eq('T4d the request row has no key',
  (select coalesce(api_key_id::text, 'none') from api_key_requests where request_id = '10000000-0000-0000-0000-000000000004'), 'none');

-- T5 abandon is idempotent: same result, first abandoned_at kept
select abandoned_at::text as t5_first from api_key_requests
  where request_id = '10000000-0000-0000-0000-000000000003' \gset
select pg_sleep(0.01);
select assert_eq('T5a a second abandon returns the same key id',
  abandon_api_key_request('10000000-0000-0000-0000-000000000003')::text, :'t3_key');
select assert_eq('T5b abandoned_at is unchanged',
  (select abandoned_at::text from api_key_requests where request_id = '10000000-0000-0000-0000-000000000003'), :'t5_first');

-- T6 two creates with distinct request ids both succeed
select create_api_key_for_request(
  '10000000-0000-0000-0000-000000000061', '00000000-0000-0000-0000-000000000001',
  '00000000-0000-0000-0000-00000000000a', 'aaaa0061', 'hash-t61', 'Default', 'starter') is not null as t61 \gset
select create_api_key_for_request(
  '10000000-0000-0000-0000-000000000062', '00000000-0000-0000-0000-000000000001',
  '00000000-0000-0000-0000-00000000000a', 'aaaa0062', 'hash-t62', 'Default', 'starter') is not null as t62 \gset
select assert_eq('T6 both same-named creates with distinct ids succeed',
  (select count(*)::text from api_keys where hash in ('hash-t61', 'hash-t62')), '2');

-- T7 replaying a create with an already-used request id raises and mints nothing new
select assert_abandoned('T7a a replayed request id raises',
  $$select create_api_key_for_request('10000000-0000-0000-0000-000000000061', '00000000-0000-0000-0000-000000000001',
    '00000000-0000-0000-0000-00000000000a', 'aaaa0071', 'hash-t71', 'Default', 'starter')$$);
select assert_eq('T7b no key row for the replay',
  (select count(*)::text from api_keys where hash = 'hash-t71'), '0');

-- T8 a create that fails on a key constraint leaves no request claimed (one transaction)
do $$
begin
  perform create_api_key_for_request('10000000-0000-0000-0000-000000000008', '00000000-0000-0000-0000-000000000001',
    '00000000-0000-0000-0000-00000000000a', 'aaaa0008', 'hash-t3', 'dup-hash', 'starter');
  raise exception 'FAIL T8: duplicate hash was accepted';
exception when unique_violation then
  raise notice 'PASS T8a duplicate hash rejected';
end $$;
select assert_eq('T8b the failed create claimed no request row',
  (select count(*)::text from api_key_requests where request_id = '10000000-0000-0000-0000-000000000008'), '0');

reset role;
