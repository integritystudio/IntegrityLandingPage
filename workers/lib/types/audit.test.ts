import { describe, it, expect } from 'vitest';
import {
  AuditActionSchema,
  AuditLogSchema,
  UserActivitySchema,
  DeviceTypeSchema,
  UserSessionSchema,
  UserSessionsResponseSchema,
  BillingEventTypeSchema,
  BillingEventLogSchema,
} from './audit';

const ORG_UUID = '550e8400-e29b-41d4-a716-446655440001';
const USER_UUID = '550e8400-e29b-41d4-a716-446655440002';
const KEY_UUID = '550e8400-e29b-41d4-a716-446655440003';
const SESSION_UUID = '550e8400-e29b-41d4-a716-446655440004';
const BILLING_UUID = '550e8400-e29b-41d4-a716-446655440005';

describe('AuditActionSchema', () => {
  const validActions = [
    'user_signup', 'user_login', 'user_logout', 'user_profile_update',
    'org_created', 'org_updated', 'membership_added', 'membership_removed',
    'membership_role_changed', 'api_key_created', 'api_key_revoked',
    'subscription_changed', 'entitlements_recomputed', 'quota_exceeded',
    'quota_reset', 'settings_updated', 'security_event',
  ];

  it('accepts all valid audit actions', () => {
    for (const action of validActions) {
      expect(AuditActionSchema.safeParse(action).success).toBe(true);
    }
  });

  it('rejects unknown action', () => {
    expect(AuditActionSchema.safeParse('data_exported').success).toBe(false);
  });
});

describe('AuditLogSchema', () => {
  const valid = {
    id: 1,
    organization_id: ORG_UUID,
    actor_user_id: USER_UUID,
    actor_api_key_id: null,
    action: 'user_login',
    target_type: 'user',
    target_id: 'user-abc',
    old_values: null,
    new_values: null,
    ip_address: '192.168.1.1',
    user_agent: 'Mozilla/5.0',
    metadata: {},
    created_at: '2024-01-01T00:00:00.000Z',
  };

  it('accepts a valid audit log', () => {
    expect(AuditLogSchema.safeParse(valid).success).toBe(true);
  });

  it('accepts null organization_id', () => {
    expect(AuditLogSchema.safeParse({ ...valid, organization_id: null }).success).toBe(true);
  });

  it('accepts null ip_address', () => {
    expect(AuditLogSchema.safeParse({ ...valid, ip_address: null }).success).toBe(true);
  });

  it('rejects invalid ip_address', () => {
    expect(AuditLogSchema.safeParse({ ...valid, ip_address: 'not-an-ip' }).success).toBe(false);
  });

  it('rejects id of 0', () => {
    expect(AuditLogSchema.safeParse({ ...valid, id: 0 }).success).toBe(false);
  });

  it('rejects empty target_type', () => {
    expect(AuditLogSchema.safeParse({ ...valid, target_type: '' }).success).toBe(false);
  });

  it('accepts old_values and new_values as records', () => {
    expect(AuditLogSchema.safeParse({
      ...valid,
      old_values: { status: 'active' },
      new_values: { status: 'suspended' },
    }).success).toBe(true);
  });

  it('defaults metadata to {}', () => {
    const { metadata: _m, ...noMeta } = valid;
    const r = AuditLogSchema.safeParse(noMeta);
    expect(r.success).toBe(true);
    if (r.success) expect(r.data.metadata).toEqual({});
  });

  it('accepts an IPv6 address', () => {
    expect(AuditLogSchema.safeParse({ ...valid, ip_address: '::1' }).success).toBe(true);
  });
});

describe('UserActivitySchema', () => {
  const valid = {
    id: USER_UUID,
    user_id: ORG_UUID,
    activity_type: 'login',
    description: 'User logged in',
    ip_address: '10.0.0.1',
    user_agent: 'Chrome/100',
    metadata: {},
    created_at: '2024-01-01T00:00:00.000Z',
  };

  it('accepts a valid user activity', () => {
    expect(UserActivitySchema.safeParse(valid).success).toBe(true);
  });

  it('accepts null ip_address and user_agent', () => {
    expect(UserActivitySchema.safeParse({ ...valid, ip_address: null, user_agent: null }).success).toBe(true);
  });

  it('rejects empty activity_type', () => {
    expect(UserActivitySchema.safeParse({ ...valid, activity_type: '' }).success).toBe(false);
  });

  it('defaults metadata to {}', () => {
    const { metadata: _m, ...noMeta } = valid;
    const r = UserActivitySchema.safeParse(noMeta);
    expect(r.success).toBe(true);
    if (r.success) expect(r.data.metadata).toEqual({});
  });
});

describe('DeviceTypeSchema', () => {
  it('accepts all valid device types', () => {
    for (const t of ['mobile', 'tablet', 'desktop', 'unknown']) {
      expect(DeviceTypeSchema.safeParse(t).success).toBe(true);
    }
  });

  it('rejects unknown device type', () => {
    expect(DeviceTypeSchema.safeParse('watch').success).toBe(false);
  });
});

describe('UserSessionSchema', () => {
  const valid = {
    id: SESSION_UUID,
    user_id: USER_UUID,
    session_token: 'tok_abc123',
    ip_address: '192.168.0.1',
    user_agent: 'Firefox/100',
    device_type: 'desktop',
    browser: 'Firefox',
    os: 'macOS',
    country: 'US',
    city: 'New York',
    last_activity: '2024-01-01T12:00:00.000Z',
    expires_at: '2024-02-01T00:00:00.000Z',
    is_active: true,
    created_at: '2024-01-01T00:00:00.000Z',
  };

  it('accepts a valid user session', () => {
    expect(UserSessionSchema.safeParse(valid).success).toBe(true);
  });

  it('accepts null optional string fields', () => {
    expect(UserSessionSchema.safeParse({
      ...valid,
      ip_address: null,
      user_agent: null,
      browser: null,
      os: null,
      country: null,
      city: null,
    }).success).toBe(true);
  });

  it('rejects invalid device_type', () => {
    expect(UserSessionSchema.safeParse({ ...valid, device_type: 'tv' }).success).toBe(false);
  });

  it('rejects empty session_token', () => {
    expect(UserSessionSchema.safeParse({ ...valid, session_token: '' }).success).toBe(false);
  });

  it('rejects non-boolean is_active', () => {
    expect(UserSessionSchema.safeParse({ ...valid, is_active: 1 }).success).toBe(false);
  });
});

describe('UserSessionsResponseSchema', () => {
  it('accepts a valid sessions response', () => {
    expect(UserSessionsResponseSchema.safeParse({
      user_id: USER_UUID,
      sessions: [{
        id: SESSION_UUID,
        device_type: 'mobile',
        browser: 'Safari',
        os: 'iOS',
        country: 'US',
        is_active: true,
        last_activity: '2024-01-01T12:00:00.000Z',
        created_at: '2024-01-01T00:00:00.000Z',
      }],
      current_session_id: SESSION_UUID,
    }).success).toBe(true);
  });

  it('accepts empty sessions array', () => {
    expect(UserSessionsResponseSchema.safeParse({
      user_id: USER_UUID,
      sessions: [],
      current_session_id: SESSION_UUID,
    }).success).toBe(true);
  });

  it('rejects non-uuid user_id', () => {
    expect(UserSessionsResponseSchema.safeParse({
      user_id: 'not-a-uuid',
      sessions: [],
      current_session_id: SESSION_UUID,
    }).success).toBe(false);
  });
});

describe('BillingEventTypeSchema', () => {
  const validTypes = [
    'checkout.session.completed',
    'invoice.paid',
    'invoice.payment_failed',
    'customer.subscription.updated',
    'customer.subscription.deleted',
    'charge.refunded',
    'other',
  ];

  it('accepts all valid billing event types', () => {
    for (const t of validTypes) {
      expect(BillingEventTypeSchema.safeParse(t).success).toBe(true);
    }
  });

  it('rejects unknown billing event type', () => {
    expect(BillingEventTypeSchema.safeParse('payment.created').success).toBe(false);
  });
});

describe('BillingEventLogSchema', () => {
  const valid = {
    id: BILLING_UUID,
    organization_id: ORG_UUID,
    stripe_event_id: 'evt_1ABC',
    event_type: 'invoice.paid',
    payload: { amount: 1000 },
    processed_at: '2024-01-01T00:00:00.000Z',
    error_message: null,
    created_at: '2024-01-01T00:00:00.000Z',
  };

  it('accepts a valid billing event log', () => {
    expect(BillingEventLogSchema.safeParse(valid).success).toBe(true);
  });

  it('accepts null organization_id', () => {
    expect(BillingEventLogSchema.safeParse({ ...valid, organization_id: null }).success).toBe(true);
  });

  it('accepts null processed_at', () => {
    expect(BillingEventLogSchema.safeParse({ ...valid, processed_at: null }).success).toBe(true);
  });

  it('accepts error_message string', () => {
    expect(BillingEventLogSchema.safeParse({ ...valid, error_message: 'Stripe timeout' }).success).toBe(true);
  });

  it('rejects empty stripe_event_id', () => {
    expect(BillingEventLogSchema.safeParse({ ...valid, stripe_event_id: '' }).success).toBe(false);
  });

  it('rejects invalid event_type', () => {
    expect(BillingEventLogSchema.safeParse({ ...valid, event_type: 'unknown.event' }).success).toBe(false);
  });
});
