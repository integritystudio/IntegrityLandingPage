import { describe, it, expect } from 'vitest';
import {
  ProvisioningJobTypeSchema,
  ProvisioningJobSourceSchema,
  ProvisioningJobStatusSchema,
  ProvisioningJobSchema,
  UserCreatedPayloadSchema,
  UserUpdatedPayloadSchema,
  MembershipChangedPayloadSchema,
  SubscriptionChangedPayloadSchema,
  EntitlementsRecomputedPayloadSchema,
  QuotaVersionBumpedPayloadSchema,
} from './provisioning';

const JOB_UUID = '00000000-0000-0000-0000-000000000001';
const ORG_UUID = '00000000-0000-0000-0000-000000000002';
const USER_UUID = '00000000-0000-0000-0000-000000000003';

describe('ProvisioningJobTypeSchema', () => {
  const validTypes = [
    'user_created', 'user_updated', 'membership_changed',
    'subscription_changed', 'entitlements_recomputed', 'quota_version_bumped',
  ];

  it('accepts all valid job types', () => {
    for (const t of validTypes) {
      expect(ProvisioningJobTypeSchema.safeParse(t).success).toBe(true);
    }
  });

  it('rejects unknown job type', () => {
    expect(ProvisioningJobTypeSchema.safeParse('org_deleted').success).toBe(false);
  });
});

describe('ProvisioningJobSourceSchema', () => {
  const validSources = ['supabase_webhook', 'stripe_webhook', 'auth0_webhook', 'manual', 'migration'];

  it('accepts all valid sources', () => {
    for (const s of validSources) {
      expect(ProvisioningJobSourceSchema.safeParse(s).success).toBe(true);
    }
  });

  it('rejects unknown source', () => {
    expect(ProvisioningJobSourceSchema.safeParse('api_request').success).toBe(false);
  });
});

describe('ProvisioningJobStatusSchema', () => {
  const validStatuses = ['pending', 'processing', 'completed', 'failed', 'retried'];

  it('accepts all valid statuses', () => {
    for (const s of validStatuses) {
      expect(ProvisioningJobStatusSchema.safeParse(s).success).toBe(true);
    }
  });

  it('rejects unknown status', () => {
    expect(ProvisioningJobStatusSchema.safeParse('cancelled').success).toBe(false);
  });
});

describe('ProvisioningJobSchema', () => {
  const valid = {
    id: JOB_UUID,
    job_type: 'user_created',
    source: 'auth0_webhook',
    dedupe_key: 'auth0|abc123::user_created',
    organization_id: null,
    user_id: USER_UUID,
    payload: { auth0_id: 'auth0|abc', email: 'user@example.com' },
    status: 'pending',
    result: null,
    error_message: null,
    retry_count: 0,
    max_retries: 3,
    created_at: '2024-01-01T00:00:00.000Z',
    updated_at: '2024-01-01T00:00:00.000Z',
    completed_at: null,
  };

  it('accepts a valid provisioning job', () => {
    expect(ProvisioningJobSchema.safeParse(valid).success).toBe(true);
  });

  it('rejects non-uuid id', () => {
    expect(ProvisioningJobSchema.safeParse({ ...valid, id: 'not-uuid' }).success).toBe(false);
  });

  it('rejects empty dedupe_key', () => {
    expect(ProvisioningJobSchema.safeParse({ ...valid, dedupe_key: '' }).success).toBe(false);
  });

  it('rejects negative retry_count', () => {
    expect(ProvisioningJobSchema.safeParse({ ...valid, retry_count: -1 }).success).toBe(false);
  });

  it('accepts completed_at as a datetime', () => {
    expect(ProvisioningJobSchema.safeParse({
      ...valid,
      status: 'completed',
      completed_at: '2024-01-01T01:00:00.000Z',
    }).success).toBe(true);
  });

  it('accepts result as a record', () => {
    expect(ProvisioningJobSchema.safeParse({ ...valid, result: { user_id: USER_UUID } }).success).toBe(true);
  });
});

describe('UserCreatedPayloadSchema', () => {
  it('accepts valid payload', () => {
    expect(UserCreatedPayloadSchema.safeParse({
      auth0_id: 'auth0|abc',
      email: 'user@example.com',
    }).success).toBe(true);
  });

  it('accepts null name', () => {
    expect(UserCreatedPayloadSchema.safeParse({
      auth0_id: 'auth0|abc',
      email: 'user@example.com',
      name: null,
    }).success).toBe(true);
  });

  it('rejects invalid email', () => {
    expect(UserCreatedPayloadSchema.safeParse({
      auth0_id: 'auth0|abc',
      email: 'not-an-email',
    }).success).toBe(false);
  });

  it('rejects missing auth0_id', () => {
    expect(UserCreatedPayloadSchema.safeParse({ email: 'user@example.com' }).success).toBe(false);
  });
});

describe('UserUpdatedPayloadSchema', () => {
  const valid = {
    user_id: USER_UUID,
    auth0_id: 'auth0|abc',
    email: 'user@example.com',
  };

  it('accepts valid payload', () => {
    expect(UserUpdatedPayloadSchema.safeParse(valid).success).toBe(true);
  });

  it('accepts optional tier and name', () => {
    expect(UserUpdatedPayloadSchema.safeParse({ ...valid, tier: 'growth', name: 'Alice' }).success).toBe(true);
  });

  it('rejects non-uuid user_id', () => {
    expect(UserUpdatedPayloadSchema.safeParse({ ...valid, user_id: 'not-uuid' }).success).toBe(false);
  });
});

describe('MembershipChangedPayloadSchema', () => {
  const valid = {
    user_id: USER_UUID,
    organization_id: ORG_UUID,
    role: 'member',
    status: 'active',
    action: 'added',
  };

  it('accepts valid payload', () => {
    expect(MembershipChangedPayloadSchema.safeParse(valid).success).toBe(true);
  });

  it('accepts all valid roles', () => {
    for (const role of ['owner', 'admin', 'member', 'billing_admin', 'viewer']) {
      expect(MembershipChangedPayloadSchema.safeParse({ ...valid, role }).success).toBe(true);
    }
  });

  it('accepts all valid statuses', () => {
    for (const status of ['active', 'invited', 'suspended']) {
      expect(MembershipChangedPayloadSchema.safeParse({ ...valid, status }).success).toBe(true);
    }
  });

  it('accepts all valid actions', () => {
    for (const action of ['added', 'updated', 'deleted']) {
      expect(MembershipChangedPayloadSchema.safeParse({ ...valid, action }).success).toBe(true);
    }
  });

  it('rejects unknown role', () => {
    expect(MembershipChangedPayloadSchema.safeParse({ ...valid, role: 'superadmin' }).success).toBe(false);
  });

  it('rejects unknown action', () => {
    expect(MembershipChangedPayloadSchema.safeParse({ ...valid, action: 'created' }).success).toBe(false);
  });
});

describe('SubscriptionChangedPayloadSchema', () => {
  it('accepts valid payload', () => {
    expect(SubscriptionChangedPayloadSchema.safeParse({
      organization_id: ORG_UUID,
      stripe_subscription_id: 'sub_abc123',
      stripe_event_id: 'evt_abc123',
      event_type: 'customer.subscription.updated',
    }).success).toBe(true);
  });

  it('rejects non-uuid organization_id', () => {
    expect(SubscriptionChangedPayloadSchema.safeParse({
      organization_id: 'not-uuid',
      stripe_subscription_id: 'sub_abc',
      stripe_event_id: 'evt_abc',
      event_type: 'customer.subscription.updated',
    }).success).toBe(false);
  });
});

describe('EntitlementsRecomputedPayloadSchema', () => {
  it('accepts valid payload with subscription_change reason', () => {
    expect(EntitlementsRecomputedPayloadSchema.safeParse({
      organization_id: ORG_UUID,
      plan_key: 'growth',
      reason: 'subscription_change',
    }).success).toBe(true);
  });

  it('accepts manual_override reason', () => {
    expect(EntitlementsRecomputedPayloadSchema.safeParse({
      organization_id: ORG_UUID,
      plan_key: 'enterprise',
      reason: 'manual_override',
    }).success).toBe(true);
  });

  it('rejects invalid plan_key', () => {
    expect(EntitlementsRecomputedPayloadSchema.safeParse({
      organization_id: ORG_UUID,
      plan_key: 'free',
      reason: 'subscription_change',
    }).success).toBe(false);
  });

  it('rejects unknown reason', () => {
    expect(EntitlementsRecomputedPayloadSchema.safeParse({
      organization_id: ORG_UUID,
      plan_key: 'starter',
      reason: 'admin_action',
    }).success).toBe(false);
  });
});

describe('QuotaVersionBumpedPayloadSchema', () => {
  it('accepts valid payload', () => {
    expect(QuotaVersionBumpedPayloadSchema.safeParse({
      organization_id: ORG_UUID,
      old_version: 1,
      new_version: 2,
      reason: 'plan upgrade',
    }).success).toBe(true);
  });

  it('accepts version 0', () => {
    expect(QuotaVersionBumpedPayloadSchema.safeParse({
      organization_id: ORG_UUID,
      old_version: 0,
      new_version: 1,
      reason: 'initial',
    }).success).toBe(true);
  });

  it('rejects negative old_version', () => {
    expect(QuotaVersionBumpedPayloadSchema.safeParse({
      organization_id: ORG_UUID,
      old_version: -1,
      new_version: 0,
      reason: 'reset',
    }).success).toBe(false);
  });
});
