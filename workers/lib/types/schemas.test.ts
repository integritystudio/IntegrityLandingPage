import { describe, it, expect } from 'vitest';
import {
  ApiKeyTierSchema,
  QuotaCheckResponseSchema,
  QuotaStatusResponseSchema,
} from './schemas';

describe('ApiKeyTierSchema', () => {
  it('accepts starter, growth, enterprise', () => {
    for (const t of ['starter', 'growth', 'enterprise']) {
      expect(ApiKeyTierSchema.safeParse(t).success).toBe(true);
    }
  });

  it('rejects unknown tier', () => {
    expect(ApiKeyTierSchema.safeParse('free').success).toBe(false);
  });
});

describe('QuotaCheckResponseSchema', () => {
  it('accepts allowed response', () => {
    expect(QuotaCheckResponseSchema.safeParse({ allowed: true }).success).toBe(true);
  });

  it('accepts denied response with reason', () => {
    expect(QuotaCheckResponseSchema.safeParse({
      allowed: false,
      reason: 'monthly_limit',
      remainingMinute: null,
      remainingMonthly: 0,
    }).success).toBe(true);
  });

  it('rejects invalid reason', () => {
    expect(QuotaCheckResponseSchema.safeParse({ allowed: false, reason: 'bad_reason' }).success).toBe(false);
  });
});

describe('QuotaStatusResponseSchema', () => {
  it('accepts initialized status', () => {
    expect(QuotaStatusResponseSchema.safeParse({
      orgId: 'org-1',
      planKey: 'starter',
      quotaVersion: 1,
      minuteLimit: 100,
      monthlyLimit: null,
      minuteUsed: 5,
      monthlyUsed: 50,
      minuteWindowExpiresIn: 30000,
    }).success).toBe(true);
  });

  it('accepts uninitialized status', () => {
    expect(QuotaStatusResponseSchema.safeParse({ status: 'uninitialized' }).success).toBe(true);
  });

  it('rejects unknown shape', () => {
    expect(QuotaStatusResponseSchema.safeParse({ foo: 'bar' }).success).toBe(false);
  });
});
