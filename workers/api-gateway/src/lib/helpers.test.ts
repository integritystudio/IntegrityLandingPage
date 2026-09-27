import { describe, it, expect, vi, afterEach } from 'vitest';
import { writeAuditLog, type AuditLogEntry } from './helpers';
import { createSupabaseClient } from '../../../lib/supabase';
import {
  createSupabaseFetchStub,
  createdRows,
  TEST_SERVICE_ROLE_KEY,
  TEST_SUPABASE_URL,
} from '../../../lib/test-helpers/supabase-fetch-stub';

const ENTRY: AuditLogEntry = {
  organization_id: 'org-id-1',
  actor_user_id: 'user-id-1',
  action: 'api_key.created',
  target_type: 'api_key',
  target_id: 'key-id-1',
};

function setUp() {
  const stub = createSupabaseFetchStub({ 'POST audit_log': createdRows([]) });
  vi.stubGlobal('fetch', stub.fetch);
  const errorSpy = vi.spyOn(console, 'error').mockImplementation(() => {});
  const sb = createSupabaseClient(TEST_SUPABASE_URL, TEST_SERVICE_ROLE_KEY);
  return { stub, errorSpy, sb };
}

afterEach(() => {
  vi.unstubAllGlobals();
  vi.restoreAllMocks();
});

describe('writeAuditLog', () => {
  it('inserts an entry whose action is in the audit vocabulary', async () => {
    const { stub, errorSpy, sb } = setUp();

    await writeAuditLog(sb, ENTRY);

    expect(stub.find('POST', 'audit_log')!.body).toEqual([
      expect.objectContaining({ action: 'api_key.created', target_id: 'key-id-1' }),
    ]);
    expect(errorSpy).not.toHaveBeenCalled();
  });

  it('refuses an action outside the vocabulary, writes nothing, and logs the value', async () => {
    const { stub, errorSpy, sb } = setUp();
    const unknownAction = { ...ENTRY, action: 'api_key_created' } as unknown as AuditLogEntry;

    await writeAuditLog(sb, unknownAction);

    expect(stub.find('POST', 'audit_log')).toBeUndefined();
    expect(errorSpy).toHaveBeenCalledWith(
      '[audit] Refusing to write unknown audit action',
      'api_key_created',
    );
  });
});
