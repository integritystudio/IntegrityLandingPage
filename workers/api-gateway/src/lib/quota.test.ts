// TS04: tests for enforceOrgQuota fail-open path and 429 mapping.
// The existing index.test.ts "fail-open when quota DO is unavailable" test mocks
// enforceOrgQuota itself (it tests the mock). This file drives quota.ts directly
// with a DO namespace stub so removing the catch block fails a test.

import { describe, it, expect, vi, afterEach } from 'vitest';
import { enforceOrgQuota } from './quota';
import {
  createSupabaseFetchStub,
  okRows,
  TEST_SUPABASE_URL,
  TEST_SERVICE_ROLE_KEY,
} from '../../../lib/test-helpers/supabase-fetch-stub';
import type { OrgQuotaMiddlewareOptions } from '../../../lib/types/schemas';

const ORG_ID = 'org-ts04';

function makeOpts(doNamespace: DurableObjectNamespace): OrgQuotaMiddlewareOptions {
  return {
    supabaseUrl: TEST_SUPABASE_URL,
    serviceRoleKey: TEST_SERVICE_ROLE_KEY,
    doNamespace,
  };
}

/** Stub that returns a single org row so the plan lookup succeeds. */
function stubOrgFetch(plan = 'starter'): void {
  const stub = createSupabaseFetchStub({
    'GET organizations': okRows([{ id: ORG_ID, current_plan: plan, quota_version: 0 }]),
  });
  vi.stubGlobal('fetch', stub.fetch);
}

afterEach(() => {
  vi.unstubAllGlobals();
  vi.restoreAllMocks();
});

describe('enforceOrgQuota — fail-open (TS04)', () => {
  it('returns ok with empty headers when the quota DO throws (fail-open)', async () => {
    stubOrgFetch();
    const mockDO = {
      idFromName: vi.fn().mockReturnValue('do-id'),
      get: vi.fn().mockReturnValue({
        fetch: vi.fn().mockRejectedValue(new Error('DO unavailable')),
      }),
    } as unknown as DurableObjectNamespace;

    const result = await enforceOrgQuota(ORG_ID, makeOpts(mockDO));

    expect(result.ok).toBe(true);
    if (result.ok) {
      expect(result.rateLimitHeaders).toEqual({});
    }
  });
});

describe('enforceOrgQuota — 429 mapping (TS04)', () => {
  it('returns ok:false with a 429 Response when quota is exceeded', async () => {
    stubOrgFetch();
    const mockDO = {
      idFromName: vi.fn().mockReturnValue('do-id'),
      get: vi.fn().mockReturnValue({
        fetch: vi.fn().mockResolvedValue(
          new Response(
            JSON.stringify({
              allowed: false,
              reason: 'minute_limit',
              remainingMinute: 0,
              remainingMonthly: 100,
            }),
            { status: 429, headers: { 'Content-Type': 'application/json' } },
          ),
        ),
      }),
    } as unknown as DurableObjectNamespace;

    const result = await enforceOrgQuota(ORG_ID, makeOpts(mockDO));

    expect(result.ok).toBe(false);
    if (!result.ok) {
      expect(result.response.status).toBe(429);
      const body = await result.response.json() as { error: { reason: string } };
      expect(body.error.reason).toBe('minute_limit');
    }
  });

  it('sets X-RateLimit-Remaining-Minute header on 429 when the DO supplies it', async () => {
    stubOrgFetch();
    const mockDO = {
      idFromName: vi.fn().mockReturnValue('do-id'),
      get: vi.fn().mockReturnValue({
        fetch: vi.fn().mockResolvedValue(
          new Response(
            JSON.stringify({
              allowed: false,
              reason: 'minute_limit',
              remainingMinute: 0,
              remainingMonthly: 50,
            }),
            { status: 429, headers: { 'Content-Type': 'application/json' } },
          ),
        ),
      }),
    } as unknown as DurableObjectNamespace;

    const result = await enforceOrgQuota(ORG_ID, makeOpts(mockDO));

    expect(result.ok).toBe(false);
    if (!result.ok) {
      expect(result.response.headers.get('X-RateLimit-Remaining-Minute')).toBe('0');
      expect(result.response.headers.get('X-RateLimit-Remaining-Monthly')).toBe('50');
    }
  });
});
