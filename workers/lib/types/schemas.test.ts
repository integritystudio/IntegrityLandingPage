import { describe, it, expect } from 'vitest';
import {
  OrgRoleSchema,
  BillingStatusSchema,
  OrgMembershipStatusSchema,
  ApiKeyStatusSchema,
  ApiKeyTierSchema,
  OrganizationSchema,
  OrgMembershipSchema,
  EntitlementSchema,
  BootstrapResponseSchema,
  StripeEventSchema,
  JwtPayloadSchema,
  UserRowSchema,
  MeResponseSchema,
  ListOrgsResponseSchema,
  OrgDashboardResponseSchema,
  OrgBillingStatusResponseSchema,
  UsageBucketSchema,
  UsageSummaryResponseSchema,
  OrgEntitlementsResponseSchema,
  ApiKeySchema,
  CreateApiKeyResponseSchema,
  RevokeApiKeyResponseSchema,
  QuotaCheckRequestSchema,
  QuotaCheckResponseSchema,
  QuotaFlushResultSchema,
  OrgPlanRowSchema,
  QuotaStatusResponseSchema,
} from './schemas';

describe('OrgRoleSchema', () => {
  it('accepts all valid roles', () => {
    for (const role of ['owner', 'admin', 'member', 'billing_admin', 'viewer']) {
      expect(OrgRoleSchema.safeParse(role).success).toBe(true);
    }
  });

  it('rejects unknown role', () => {
    expect(OrgRoleSchema.safeParse('superadmin').success).toBe(false);
  });
});

describe('BillingStatusSchema', () => {
  it('accepts all valid statuses', () => {
    for (const s of ['inactive', 'active', 'past_due', 'canceled']) {
      expect(BillingStatusSchema.safeParse(s).success).toBe(true);
    }
  });

  it('rejects unknown status', () => {
    expect(BillingStatusSchema.safeParse('suspended').success).toBe(false);
  });
});

describe('OrgMembershipStatusSchema', () => {
  it('accepts active, invited, suspended', () => {
    for (const s of ['active', 'invited', 'suspended']) {
      expect(OrgMembershipStatusSchema.safeParse(s).success).toBe(true);
    }
  });

  it('rejects unknown value', () => {
    expect(OrgMembershipStatusSchema.safeParse('pending').success).toBe(false);
  });
});

describe('ApiKeyStatusSchema', () => {
  it('accepts active, revoked, expired', () => {
    for (const s of ['active', 'revoked', 'expired']) {
      expect(ApiKeyStatusSchema.safeParse(s).success).toBe(true);
    }
  });

  it('rejects unknown value', () => {
    expect(ApiKeyStatusSchema.safeParse('disabled').success).toBe(false);
  });
});

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

describe('OrganizationSchema', () => {
  const valid = {
    id: 'org-1',
    slug: 'my-org',
    name: 'My Org',
    billing_status: 'active',
    current_plan: 'starter',
    quota_version: 1,
  };

  it('accepts a valid organization', () => {
    expect(OrganizationSchema.safeParse(valid).success).toBe(true);
  });

  it('rejects invalid billing_status', () => {
    expect(OrganizationSchema.safeParse({ ...valid, billing_status: 'unknown' }).success).toBe(false);
  });

  it('rejects invalid current_plan', () => {
    expect(OrganizationSchema.safeParse({ ...valid, current_plan: 'free' }).success).toBe(false);
  });

  it('rejects missing required fields', () => {
    const { id: _id, ...noId } = valid;
    expect(OrganizationSchema.safeParse(noId).success).toBe(false);
  });
});

describe('OrgMembershipSchema', () => {
  const valid = {
    organization_id: 'org-1',
    user_id: 'user-1',
    role: 'admin',
    status: 'active',
  };

  it('accepts a valid membership', () => {
    expect(OrgMembershipSchema.safeParse(valid).success).toBe(true);
  });

  it('rejects invalid role', () => {
    expect(OrgMembershipSchema.safeParse({ ...valid, role: 'god' }).success).toBe(false);
  });

  it('rejects invalid status', () => {
    expect(OrgMembershipSchema.safeParse({ ...valid, status: 'banned' }).success).toBe(false);
  });
});

describe('EntitlementSchema', () => {
  it('accepts valid entitlement with null limits', () => {
    expect(EntitlementSchema.safeParse({
      organization_id: 'org-1',
      feature_key: 'feature_x',
      enabled: true,
      hard_limit: null,
      soft_limit: null,
    }).success).toBe(true);
  });

  it('accepts numeric limits', () => {
    expect(EntitlementSchema.safeParse({
      organization_id: 'org-1',
      feature_key: 'feature_x',
      enabled: false,
      hard_limit: 100,
      soft_limit: 80,
    }).success).toBe(true);
  });

  it('rejects non-boolean enabled', () => {
    expect(EntitlementSchema.safeParse({
      organization_id: 'org-1',
      feature_key: 'feature_x',
      enabled: 'yes',
      hard_limit: null,
      soft_limit: null,
    }).success).toBe(false);
  });
});

describe('BootstrapResponseSchema', () => {
  const valid = {
    user: { id: 'user-1', email: 'a@b.com' },
    organizations: [{ id: 'org-1', slug: 'o', name: 'O', billing_status: 'active', current_plan: 'starter', quota_version: 1, role: 'owner' }],
    active_org_id: 'org-1',
    entitlements: { feature_x: true },
    usage_snapshot: { month_to_date_units: 0 },
  };

  it('accepts a valid bootstrap response', () => {
    expect(BootstrapResponseSchema.safeParse(valid).success).toBe(true);
  });

  it('rejects missing user id', () => {
    expect(BootstrapResponseSchema.safeParse({ ...valid, user: { email: 'a@b.com' } }).success).toBe(false);
  });

  it('accepts entitlements with numeric and null values', () => {
    const r = BootstrapResponseSchema.safeParse({ ...valid, entitlements: { quota: 100, flag: null } });
    expect(r.success).toBe(true);
  });
});

describe('StripeEventSchema', () => {
  const valid = {
    id: 'evt_1',
    type: 'customer.subscription.updated',
    created: 1700000000,
    data: { object: { id: 'sub_1' } },
  };

  it('accepts a valid Stripe event', () => {
    expect(StripeEventSchema.safeParse(valid).success).toBe(true);
  });

  it('accepts event with previous_attributes', () => {
    expect(StripeEventSchema.safeParse({
      ...valid,
      data: { object: { id: 'sub_1' }, previous_attributes: { status: 'active' } },
    }).success).toBe(true);
  });

  it('rejects missing id', () => {
    const { id: _id, ...noId } = valid;
    expect(StripeEventSchema.safeParse(noId).success).toBe(false);
  });
});

describe('JwtPayloadSchema', () => {
  const valid = {
    sub: 'user-123',
    email: 'user@example.com',
    iat: 1700000000,
    exp: 1700003600,
  };

  it('accepts a valid JWT payload', () => {
    expect(JwtPayloadSchema.safeParse(valid).success).toBe(true);
  });

  it('accepts extra passthrough fields', () => {
    const r = JwtPayloadSchema.safeParse({ ...valid, custom_claim: 'value' });
    expect(r.success).toBe(true);
    if (r.success) expect((r.data as any).custom_claim).toBe('value');
  });

  it('rejects invalid email', () => {
    expect(JwtPayloadSchema.safeParse({ ...valid, email: 'not-an-email' }).success).toBe(false);
  });
});

describe('UserRowSchema', () => {
  const valid = {
    id: '550e8400-e29b-41d4-a716-446655440001',
    auth0_id: 'auth0|abc',
    email: 'user@example.com',
    name: 'Alice',
    tier: 'starter',
    created_at: '2024-01-01T00:00:00.000Z',
  };

  it('accepts a valid user row', () => {
    expect(UserRowSchema.safeParse(valid).success).toBe(true);
  });

  it('accepts null name', () => {
    expect(UserRowSchema.safeParse({ ...valid, name: null }).success).toBe(true);
  });

  it('rejects non-uuid id', () => {
    expect(UserRowSchema.safeParse({ ...valid, id: 'not-uuid' }).success).toBe(false);
  });

  it('rejects invalid email', () => {
    expect(UserRowSchema.safeParse({ ...valid, email: 'bad' }).success).toBe(false);
  });
});

describe('MeResponseSchema', () => {
  const valid = {
    id: '550e8400-e29b-41d4-a716-446655440001',
    email: 'user@example.com',
    name: 'Alice',
    tier: 'starter',
    created_at: '2024-01-01T00:00:00.000Z',
  };

  it('accepts valid response', () => {
    expect(MeResponseSchema.safeParse(valid).success).toBe(true);
  });

  it('accepts null name', () => {
    expect(MeResponseSchema.safeParse({ ...valid, name: null }).success).toBe(true);
  });
});

describe('ListOrgsResponseSchema', () => {
  it('accepts valid list', () => {
    expect(ListOrgsResponseSchema.safeParse({
      organizations: [{ id: 'org-1', slug: 'o', name: 'O', billing_status: 'active', current_plan: 'starter', quota_version: 1, role: 'owner' }],
    }).success).toBe(true);
  });

  it('accepts empty list', () => {
    expect(ListOrgsResponseSchema.safeParse({ organizations: [] }).success).toBe(true);
  });
});

describe('OrgDashboardResponseSchema', () => {
  it('accepts valid dashboard response', () => {
    expect(OrgDashboardResponseSchema.safeParse({
      org: { id: 'org-1', slug: 'o', name: 'O', billing_status: 'active', current_plan: 'starter', quota_version: 1 },
      role: 'admin',
      entitlements: { feature_x: true },
    }).success).toBe(true);
  });
});

describe('OrgBillingStatusResponseSchema', () => {
  it('accepts valid billing status response', () => {
    expect(OrgBillingStatusResponseSchema.safeParse({
      org_id: '550e8400-e29b-41d4-a716-446655440001',
      billing_status: 'active',
      current_plan: 'growth',
      quota_version: 2,
      role: 'owner',
    }).success).toBe(true);
  });
});

describe('UsageBucketSchema (schemas.ts)', () => {
  const valid = {
    organization_id: '550e8400-e29b-41d4-a716-446655440001',
    bucket_date: '2024-01-15',
    metric_key: 'api_calls',
    total_quantity: 500,
    request_count: 500,
    avg_latency_ms: 120.5,
  };

  it('accepts a valid bucket', () => {
    expect(UsageBucketSchema.safeParse(valid).success).toBe(true);
  });

  it('accepts null avg_latency_ms', () => {
    expect(UsageBucketSchema.safeParse({ ...valid, avg_latency_ms: null }).success).toBe(true);
  });
});

describe('UsageSummaryResponseSchema', () => {
  it('accepts valid usage summary', () => {
    expect(UsageSummaryResponseSchema.safeParse({
      org_id: '550e8400-e29b-41d4-a716-446655440001',
      period_start: '2024-01-01',
      buckets: [],
    }).success).toBe(true);
  });
});

describe('OrgEntitlementsResponseSchema', () => {
  it('accepts valid entitlements response', () => {
    expect(OrgEntitlementsResponseSchema.safeParse({
      org_id: '550e8400-e29b-41d4-a716-446655440001',
      entitlements: { feature_x: true, quota: 100, flag: null },
    }).success).toBe(true);
  });
});

describe('ApiKeySchema', () => {
  const valid = {
    id: '550e8400-e29b-41d4-a716-446655440001',
    user_id: '550e8400-e29b-41d4-a716-446655440002',
    organization_id: '550e8400-e29b-41d4-a716-446655440003',
    prefix: 'sk_live_abc',
    hash: 'sha256hash',
    name: 'My Key',
    tier: 'starter',
    status: 'active',
    expires_at: null,
    last_used_at: null,
    created_at: '2024-01-01T00:00:00.000Z',
    revoked_at: null,
  };

  it('accepts a valid API key', () => {
    expect(ApiKeySchema.safeParse(valid).success).toBe(true);
  });

  it('rejects invalid tier', () => {
    expect(ApiKeySchema.safeParse({ ...valid, tier: 'free' }).success).toBe(false);
  });

  it('rejects invalid status', () => {
    expect(ApiKeySchema.safeParse({ ...valid, status: 'deleted' }).success).toBe(false);
  });
});

describe('CreateApiKeyResponseSchema', () => {
  const valid = {
    id: '550e8400-e29b-41d4-a716-446655440001',
    name: 'My Key',
    prefix: 'sk_live_abc',
    tier: 'starter',
    status: 'active',
    expires_at: null,
    created_at: '2024-01-01T00:00:00.000Z',
    token: 'sk_live_abc_secretpart',
  };

  it('accepts a valid create key response', () => {
    expect(CreateApiKeyResponseSchema.safeParse(valid).success).toBe(true);
  });

  it('requires token field', () => {
    const { token: _t, ...noToken } = valid;
    expect(CreateApiKeyResponseSchema.safeParse(noToken).success).toBe(false);
  });
});

describe('RevokeApiKeyResponseSchema', () => {
  it('accepts valid revoke response', () => {
    expect(RevokeApiKeyResponseSchema.safeParse({
      id: '550e8400-e29b-41d4-a716-446655440001',
      status: 'revoked',
      revoked_at: '2024-01-01T00:00:00.000Z',
    }).success).toBe(true);
  });

  it('rejects status other than "revoked"', () => {
    expect(RevokeApiKeyResponseSchema.safeParse({
      id: '550e8400-e29b-41d4-a716-446655440001',
      status: 'active',
      revoked_at: '2024-01-01T00:00:00.000Z',
    }).success).toBe(false);
  });
});

describe('QuotaCheckRequestSchema', () => {
  const valid = {
    orgId: '550e8400-e29b-41d4-a716-446655440001',
    metricKey: 'api_calls',
    units: 1,
    requestId: 'req-123',
    planKey: 'starter',
    quotaVersion: 1,
  };

  it('accepts valid quota check request', () => {
    expect(QuotaCheckRequestSchema.safeParse(valid).success).toBe(true);
  });

  it('rejects zero units', () => {
    expect(QuotaCheckRequestSchema.safeParse({ ...valid, units: 0 }).success).toBe(false);
  });

  it('rejects invalid planKey', () => {
    expect(QuotaCheckRequestSchema.safeParse({ ...valid, planKey: 'free' }).success).toBe(false);
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

describe('QuotaFlushResultSchema', () => {
  it('accepts valid flush result', () => {
    expect(QuotaFlushResultSchema.safeParse({
      orgId: '550e8400-e29b-41d4-a716-446655440001',
      monthlyUsedSinceLastFlush: 50,
      flushedAt: '2024-01-01T00:00:00.000Z',
    }).success).toBe(true);
  });
});

describe('OrgPlanRowSchema', () => {
  it('accepts valid plan row', () => {
    expect(OrgPlanRowSchema.safeParse({ current_plan: 'growth', quota_version: 3 }).success).toBe(true);
  });

  it('rejects negative quota_version', () => {
    expect(OrgPlanRowSchema.safeParse({ current_plan: 'growth', quota_version: -1 }).success).toBe(false);
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
