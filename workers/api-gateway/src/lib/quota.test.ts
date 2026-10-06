// TS04: tests for enforceOrgQuota fail-open path and 429 mapping.
// The existing index.test.ts "fail-open when quota DO is unavailable" test mocks
// enforceOrgQuota itself (it tests the mock). This file drives quota.ts directly
// with a DO namespace stub so removing the catch block fails a test.

import { describe, it, expect, vi, afterEach } from 'vitest';
import {
  enforceOrgQuota,
  secondsToMonthReset,
  buildRateLimitPolicyHeader,
  buildRateLimitHeader,
} from './quota';
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

/** One quota-DO reply: a Response is returned, an Error is thrown (the DO is unavailable). */
type QuotaDOReply = () => Response | Error;

const reply = (body: Record<string, unknown>, status = 200): QuotaDOReply => () =>
  new Response(JSON.stringify(body), { status, headers: { 'Content-Type': 'application/json' } });

/** Quota DO namespace stub that records every check-and-reserve body it is sent. */
function fakeQuotaDO(answer: QuotaDOReply = reply({ allowed: true })): {
  ns: DurableObjectNamespace;
  bodies: Record<string, unknown>[];
} {
  const bodies: Record<string, unknown>[] = [];
  const ns = {
    idFromName: vi.fn().mockReturnValue('do-id'),
    get: vi.fn().mockReturnValue({
      fetch: vi.fn(async (req: Request) => {
        bodies.push((await req.json()) as Record<string, unknown>);
        const result = answer();
        if (result instanceof Error) throw result;
        return result;
      }),
    }),
  } as unknown as DurableObjectNamespace;
  return { ns, bodies };
}

const minuteLimited = (remainingMonthly: number) =>
  reply({ allowed: false, reason: 'minute_limit', remainingMinute: 0, remainingMonthly }, 429);

afterEach(() => {
  vi.unstubAllGlobals();
  vi.restoreAllMocks();
});

describe('enforceOrgQuota — fail-open (TS04)', () => {
  it('returns ok with empty headers when the quota DO throws (fail-open)', async () => {
    stubOrgFetch();
    const { ns } = fakeQuotaDO(() => new Error('DO unavailable'));

    const result = await enforceOrgQuota(ORG_ID, makeOpts(ns));

    expect(result.ok).toBe(true);
    if (result.ok) {
      expect(result.rateLimitHeaders).toEqual({});
    }
  });
});

describe('enforceOrgQuota — 429 mapping (TS04)', () => {
  it('returns ok:false with a 429 Response when quota is exceeded', async () => {
    stubOrgFetch();
    const { ns } = fakeQuotaDO(minuteLimited(100));

    const result = await enforceOrgQuota(ORG_ID, makeOpts(ns));

    expect(result.ok).toBe(false);
    if (!result.ok) {
      expect(result.response.status).toBe(429);
      const body = await result.response.json() as { error: { reason: string } };
      expect(body.error.reason).toBe('minute_limit');
    }
  });

  it('sets X-RateLimit-Remaining-Minute header on 429 when the DO supplies it', async () => {
    stubOrgFetch();
    const { ns } = fakeQuotaDO(minuteLimited(50));

    const result = await enforceOrgQuota(ORG_ID, makeOpts(ns));

    expect(result.ok).toBe(false);
    if (!result.ok) {
      expect(result.response.headers.get('X-RateLimit-Remaining-Minute')).toBe('0');
      expect(result.response.headers.get('X-RateLimit-Remaining-Monthly')).toBe('50');
    }
  });
});

describe('enforceOrgQuota — billing gate (CR37)', () => {
  it.each([
    ['growth', 'active', 'growth'],
    ['growth', 'trialing', 'growth'],
    ['enterprise', 'inactive', 'starter'],
    ['growth', 'past_due', 'starter'],
    ['growth', 'canceled', 'starter'],
  ])('current_plan %s with billing_status %s enforces %s', async (plan, status, expected) => {
    stubOrgFetch(plan, status);
    const { ns, bodies } = fakeQuotaDO();
    await enforceOrgQuota(ORG_ID, makeOpts(ns));
    expect(bodies.map((b) => b.planKey)).toEqual([expected]);
  });
});

describe('enforceOrgQuota — monthly charge (CR58)', () => {
  it('charges the month by default and forwards an explicit false', async () => {
    stubOrgFetch();
    const { ns, bodies } = fakeQuotaDO();
    await enforceOrgQuota(ORG_ID, makeOpts(ns));
    await enforceOrgQuota(ORG_ID, makeOpts(ns), { chargeMonthly: false });
    expect(bodies.map((b) => b.chargeMonthly)).toEqual([true, false]);
  });
});

// CR59: IETF draft-ietf-httpapi-ratelimit-headers helper unit tests.

describe('secondsToMonthReset (CR59)', () => {
  it('returns seconds to the 1st of next month from a mid-month timestamp', () => {
    // 2026-10-15T12:00:00Z — next reset is 2026-11-01T00:00:00Z
    // Oct has 31 days; remaining = (31 - 15) days + 12 h = 16 days + 12 h = 16.5 * 86400
    const midMonth = Date.UTC(2026, 9, 15, 12, 0, 0); // month index 9 = October
    const s = secondsToMonthReset(midMonth);
    expect(s).toBe(16.5 * 86_400);
  });

  it('returns the full next-month length when called at exactly the 1st midnight', () => {
    // At the reset moment the new month has just started, so the next reset is a full month away.
    const nov1 = Date.UTC(2026, 10, 1, 0, 0, 0); // month index 10 = November
    expect(secondsToMonthReset(nov1)).toBe(30 * 86_400); // November has 30 days
  });

  it('wraps December → January correctly', () => {
    const dec = Date.UTC(2026, 11, 31, 23, 59, 59); // 2026-12-31T23:59:59Z
    const s = secondsToMonthReset(dec);
    expect(s).toBe(1); // 1 second to 2027-01-01T00:00:00Z
  });
});

describe('buildRateLimitPolicyHeader (CR59)', () => {
  it('emits both items when both limits are present', () => {
    expect(buildRateLimitPolicyHeader(60, 10000)).toBe('"minute";q=60;w=60, "month";q=10000');
  });

  it('omits the month item for enterprise (null monthlyLimit)', () => {
    expect(buildRateLimitPolicyHeader(6000, null)).toBe('"minute";q=6000;w=60');
  });

  it('returns empty string when no limits are available', () => {
    expect(buildRateLimitPolicyHeader(null, null)).toBe('');
    expect(buildRateLimitPolicyHeader(undefined, undefined)).toBe('');
  });
});

describe('buildRateLimitHeader (CR59)', () => {
  // Fix a reference "now" so the month-reset time is deterministic.
  const now = Date.UTC(2026, 9, 15, 12, 0, 0); // 2026-10-15T12:00:00Z
  const monthT = secondsToMonthReset(now); // 1_339_200

  it('emits both items with correct r= and t=', () => {
    const h = buildRateLimitHeader(48, 40, 9000, 10000, now);
    expect(h).toBe(`"minute";r=48;t=40, "month";r=9000;t=${monthT}`);
  });

  it('falls back to t=60 when minuteWindowResetsIn is absent', () => {
    const h = buildRateLimitHeader(48, undefined, null, null, now);
    expect(h).toBe('"minute";r=48;t=60');
  });

  it('omits the month item for enterprise (remainingMonthly null)', () => {
    const h = buildRateLimitHeader(48, 40, null, null, now);
    expect(h).toBe('"minute";r=48;t=40');
  });

  it('returns empty string when remainingMinute is absent', () => {
    expect(buildRateLimitHeader(null, null, null, null, now)).toBe('');
    expect(buildRateLimitHeader(undefined, undefined, undefined, undefined, now)).toBe('');
  });
});

describe('enforceOrgQuota — IETF draft headers (CR59)', () => {
  const quotaData = {
    allowed: true,
    remainingMinute: 48,
    remainingMonthly: 9000,
    minuteLimit: 60,
    monthlyLimit: 10000,
    minuteWindowResetsIn: 40,
  };

  it('includes RateLimit-Policy and RateLimit headers on an allowed response', async () => {
    stubOrgFetch();
    const { ns } = fakeQuotaDO(reply(quotaData));

    const result = await enforceOrgQuota(ORG_ID, makeOpts(ns));

    expect(result.ok).toBe(true);
    if (result.ok) {
      expect(result.rateLimitHeaders['RateLimit-Policy']).toBe('"minute";q=60;w=60, "month";q=10000');
      expect(result.rateLimitHeaders['RateLimit']).toMatch(/^"minute";r=48;t=40, "month";r=9000;t=\d+$/);
    }
  });

  it('includes Retry-After on a minute_limit 429', async () => {
    stubOrgFetch();
    const { ns } = fakeQuotaDO(reply(
      { allowed: false, reason: 'minute_limit', remainingMinute: 0, remainingMonthly: 9000,
        minuteLimit: 60, monthlyLimit: 10000, minuteWindowResetsIn: 35 },
      429,
    ));

    const result = await enforceOrgQuota(ORG_ID, makeOpts(ns));

    expect(result.ok).toBe(false);
    if (!result.ok) {
      expect(result.response.headers.get('Retry-After')).toBe('35');
    }
  });

  it('includes a positive Retry-After on a monthly_limit 429', async () => {
    stubOrgFetch();
    const { ns } = fakeQuotaDO(reply(
      { allowed: false, reason: 'monthly_limit', remainingMinute: 48, remainingMonthly: 0,
        minuteLimit: 60, monthlyLimit: 10000, minuteWindowResetsIn: 40 },
      429,
    ));

    const result = await enforceOrgQuota(ORG_ID, makeOpts(ns));

    expect(result.ok).toBe(false);
    if (!result.ok) {
      const retryAfter = Number(result.response.headers.get('Retry-After'));
      expect(retryAfter).toBeGreaterThan(0);
    }
  });
});
