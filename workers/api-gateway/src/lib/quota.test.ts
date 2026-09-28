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
function stubOrgFetch(plan = 'starter', billingStatus = 'inactive'): void {
  const stub = createSupabaseFetchStub({
    'GET organizations': okRows([{ id: ORG_ID, current_plan: plan, quota_version: 0, billing_status: billingStatus }]),
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

describe('enforceOrgQuota — billing gate (CR37)', () => {
  /** DO stub that records the planKey it was asked to enforce. */
  function recordingDO(): { ns: DurableObjectNamespace; planKeys: string[] } {
    const planKeys: string[] = [];
    const ns = {
      idFromName: vi.fn().mockReturnValue('do-id'),
      get: vi.fn().mockReturnValue({
        fetch: vi.fn(async (req: Request) => {
          planKeys.push(((await req.json()) as { planKey: string }).planKey);
          return new Response(JSON.stringify({ allowed: true }), { status: 200 });
        }),
      }),
    } as unknown as DurableObjectNamespace;
    return { ns, planKeys };
  }

  it.each([
    ['growth', 'active', 'growth'],
    ['growth', 'trialing', 'growth'],
    ['enterprise', 'inactive', 'starter'],
    ['growth', 'past_due', 'starter'],
    ['growth', 'canceled', 'starter'],
  ])('current_plan %s with billing_status %s enforces %s', async (plan, status, expected) => {
    stubOrgFetch(plan, status);
    const { ns, planKeys } = recordingDO();
    await enforceOrgQuota(ORG_ID, makeOpts(ns));
    expect(planKeys).toEqual([expected]);
  });
});
