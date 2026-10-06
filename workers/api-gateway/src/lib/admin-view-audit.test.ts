import { describe, it, expect, vi, afterEach, beforeEach } from 'vitest';
import { recordAdminOrgView, resetAdminViewAudit, ADMIN_VIEW_AUDIT_WINDOW_SECONDS } from './admin-view-audit';
import { createSupabaseClient } from '../../../lib/supabase';
import { createSupabaseFetchStub, createdRows, TEST_SERVICE_ROLE_KEY, TEST_SUPABASE_URL } from '../../../lib/test-helpers/supabase-fetch-stub';

const VIEW = { userId: 'user-1', sub: 'auth0|user-1', orgId: 'org-1', route: 'GET /v1/admin/orgs/:id/usage/summary' };
const MS_PER_SECOND = 1000;

/** KV over a Map, recording expirationTtl and optionally failing every call. */
function mapKv(store = new Map<string, string>(), { failing = false } = {}) {
  const ttls: number[] = [];
  const kv = {
    get: async (key: string) => {
      if (failing) throw new Error('kv down');
      return store.get(key) ?? null;
    },
    put: async (key: string, value: string, options?: { expirationTtl?: number }) => {
      if (failing) throw new Error('kv down');
      store.set(key, value);
      if (options?.expirationTtl !== undefined) ttls.push(options.expirationTtl);
    },
  } as unknown as KVNamespace;
  return { kv, store, ttls };
}

let auditWrites: () => number;

beforeEach(() => {
  vi.useFakeTimers();
  vi.setSystemTime(new Date('2026-10-06T12:00:00Z'));
  const stub = createSupabaseFetchStub({ 'POST audit_log': createdRows([]) });
  vi.stubGlobal('fetch', stub.fetch);
  auditWrites = () => stub.findAll('POST', 'audit_log').length;
});

afterEach(() => {
  resetAdminViewAudit();
  vi.unstubAllGlobals();
  vi.useRealTimers();
  vi.restoreAllMocks();
});

const sb = () => createSupabaseClient(TEST_SUPABASE_URL, TEST_SERVICE_ROLE_KEY);

describe('recordAdminOrgView', () => {
  it('writes on the first view and not again within the window, without KV', async () => {
    await recordAdminOrgView(sb(), undefined, VIEW);
    await recordAdminOrgView(sb(), undefined, VIEW);
    expect(auditWrites()).toBe(1);
  });

  it('writes again once the window has passed', async () => {
    await recordAdminOrgView(sb(), undefined, VIEW);
    vi.setSystemTime(Date.now() + ADMIN_VIEW_AUDIT_WINDOW_SECONDS * MS_PER_SECOND + 1);
    await recordAdminOrgView(sb(), undefined, VIEW);
    expect(auditWrites()).toBe(2);
  });

  it('keys the window on the user and the org together', async () => {
    await recordAdminOrgView(sb(), undefined, VIEW);
    await recordAdminOrgView(sb(), undefined, { ...VIEW, orgId: 'org-2' });
    await recordAdminOrgView(sb(), undefined, { ...VIEW, userId: 'user-2', sub: 'auth0|user-2' });
    expect(auditWrites()).toBe(3);
  });

  it('records the view in KV with the window as its TTL', async () => {
    const { kv, store, ttls } = mapKv();
    await recordAdminOrgView(sb(), kv, VIEW);
    expect([...store.keys()]).toEqual([`gw_admin_view:${VIEW.userId}:${VIEW.orgId}`]);
    expect(ttls).toEqual([ADMIN_VIEW_AUDIT_WINDOW_SECONDS]);
  });

  it('skips the write when another isolate already recorded the view in KV', async () => {
    const { kv, store } = mapKv();
    await recordAdminOrgView(sb(), kv, VIEW);
    resetAdminViewAudit(); // a fresh isolate: its in-memory map is empty, KV is not
    await recordAdminOrgView(sb(), kv, VIEW);
    expect(store.size).toBe(1);
    expect(auditWrites()).toBe(1);
  });

  it('falls back to the in-memory window when KV fails, so a row is never lost', async () => {
    const errorSpy = vi.spyOn(console, 'error').mockImplementation(() => {});
    const { kv } = mapKv(new Map(), { failing: true });
    await recordAdminOrgView(sb(), kv, VIEW);
    await recordAdminOrgView(sb(), kv, VIEW);
    expect(auditWrites()).toBe(1);
    expect(errorSpy).toHaveBeenCalledWith(expect.stringContaining('[admin-view-audit]'));
  });
});
