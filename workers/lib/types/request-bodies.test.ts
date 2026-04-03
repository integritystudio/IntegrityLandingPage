import { describe, it, expect } from 'vitest';
import {
  CreateApiKeyBodySchema,
  OrgIdParamSchema,
  ApiKeyIdParamSchema,
  PaginationParamsSchema,
  StripeEventBodySchema,
} from './request-bodies';

const ORG_UUID = '00000000-0000-0000-0000-000000000001';
const KEY_UUID = '00000000-0000-0000-0000-000000000002';

describe('CreateApiKeyBodySchema', () => {
  it('accepts empty body (all fields optional)', () => {
    expect(CreateApiKeyBodySchema.safeParse({}).success).toBe(true);
  });

  it('accepts body with name only', () => {
    expect(CreateApiKeyBodySchema.safeParse({ name: 'My API Key' }).success).toBe(true);
  });

  it('accepts body with name and expires_at', () => {
    expect(CreateApiKeyBodySchema.safeParse({
      name: 'My Key',
      expires_at: '2025-01-01T00:00:00.000Z',
    }).success).toBe(true);
  });

  it('rejects empty name string', () => {
    expect(CreateApiKeyBodySchema.safeParse({ name: '' }).success).toBe(false);
  });

  it('rejects name longer than 255 chars', () => {
    expect(CreateApiKeyBodySchema.safeParse({ name: 'a'.repeat(256) }).success).toBe(false);
  });

  it('rejects invalid expires_at format', () => {
    expect(CreateApiKeyBodySchema.safeParse({ expires_at: '2025-01-01' }).success).toBe(false);
  });

  it('rejects unknown extra fields (strict)', () => {
    expect(CreateApiKeyBodySchema.safeParse({ name: 'Key', tier: 'starter' }).success).toBe(false);
  });
});

describe('OrgIdParamSchema', () => {
  it('accepts a valid UUID', () => {
    expect(OrgIdParamSchema.safeParse({ orgId: ORG_UUID }).success).toBe(true);
  });

  it('rejects non-uuid orgId', () => {
    expect(OrgIdParamSchema.safeParse({ orgId: 'not-a-uuid' }).success).toBe(false);
  });

  it('rejects missing orgId', () => {
    expect(OrgIdParamSchema.safeParse({}).success).toBe(false);
  });
});

describe('ApiKeyIdParamSchema', () => {
  it('accepts valid orgId and keyId', () => {
    expect(ApiKeyIdParamSchema.safeParse({ orgId: ORG_UUID, keyId: KEY_UUID }).success).toBe(true);
  });

  it('rejects non-uuid orgId', () => {
    expect(ApiKeyIdParamSchema.safeParse({ orgId: 'bad-org', keyId: KEY_UUID }).success).toBe(false);
  });

  it('rejects non-uuid keyId', () => {
    expect(ApiKeyIdParamSchema.safeParse({ orgId: ORG_UUID, keyId: 'bad-key' }).success).toBe(false);
  });

  it('rejects missing keyId', () => {
    expect(ApiKeyIdParamSchema.safeParse({ orgId: ORG_UUID }).success).toBe(false);
  });
});

describe('PaginationParamsSchema', () => {
  it('defaults limit to 50 and offset to 0', () => {
    const r = PaginationParamsSchema.safeParse({});
    expect(r.success).toBe(true);
    if (r.success) {
      expect(r.data.limit).toBe(50);
      expect(r.data.offset).toBe(0);
    }
  });

  it('accepts custom limit and offset', () => {
    const r = PaginationParamsSchema.safeParse({ limit: '10', offset: '20' });
    expect(r.success).toBe(true);
    if (r.success) {
      expect(r.data.limit).toBe(10);
      expect(r.data.offset).toBe(20);
    }
  });

  it('coerces string numbers', () => {
    const r = PaginationParamsSchema.safeParse({ limit: '100' });
    expect(r.success).toBe(true);
    if (r.success) expect(r.data.limit).toBe(100);
  });

  it('rejects limit above 1000', () => {
    expect(PaginationParamsSchema.safeParse({ limit: 1001 }).success).toBe(false);
  });

  it('rejects negative offset', () => {
    expect(PaginationParamsSchema.safeParse({ offset: -1 }).success).toBe(false);
  });

  it('rejects zero limit', () => {
    expect(PaginationParamsSchema.safeParse({ limit: 0 }).success).toBe(false);
  });
});

describe('StripeEventBodySchema', () => {
  const valid = {
    id: 'evt_1ABC',
    type: 'invoice.paid',
    created: 1700000000,
    data: { object: { id: 'in_1ABC', amount: 2000 } },
  };

  it('accepts a valid Stripe event body', () => {
    expect(StripeEventBodySchema.safeParse(valid).success).toBe(true);
  });

  it('accepts event with previous_attributes', () => {
    expect(StripeEventBodySchema.safeParse({
      ...valid,
      data: {
        object: { id: 'sub_1' },
        previous_attributes: { status: 'active' },
      },
    }).success).toBe(true);
  });

  it('rejects missing id', () => {
    const { id: _id, ...noId } = valid;
    expect(StripeEventBodySchema.safeParse(noId).success).toBe(false);
  });

  it('rejects missing data.object', () => {
    expect(StripeEventBodySchema.safeParse({ ...valid, data: {} }).success).toBe(false);
  });

  it('rejects non-number created', () => {
    expect(StripeEventBodySchema.safeParse({ ...valid, created: '2024-01-01' }).success).toBe(false);
  });
});
