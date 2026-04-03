import { describe, it, expect } from 'vitest';
import {
  BaseRouteOptionsSchema,
  MachineRouteOptionsSchema,
  EnvSchema,
  AuthResultSchema,
} from './handler-options';

describe('BaseRouteOptionsSchema', () => {
  const valid = {
    jwtSecret: 'supersecret',
    supabaseUrl: 'https://project.supabase.co',
    serviceRoleKey: 'service-role-key-123',
  };

  it('accepts valid base route options', () => {
    expect(BaseRouteOptionsSchema.safeParse(valid).success).toBe(true);
  });

  it('accepts optional jwtIssuerUrl', () => {
    expect(BaseRouteOptionsSchema.safeParse({
      ...valid,
      jwtIssuerUrl: 'https://project.supabase.co/auth/v1',
    }).success).toBe(true);
  });

  it('rejects invalid supabaseUrl', () => {
    expect(BaseRouteOptionsSchema.safeParse({ ...valid, supabaseUrl: 'not-a-url' }).success).toBe(false);
  });

  it('rejects invalid jwtIssuerUrl', () => {
    expect(BaseRouteOptionsSchema.safeParse({ ...valid, jwtIssuerUrl: 'not-a-url' }).success).toBe(false);
  });

  it('rejects missing jwtSecret', () => {
    const { jwtSecret: _j, ...noSecret } = valid;
    expect(BaseRouteOptionsSchema.safeParse(noSecret).success).toBe(false);
  });
});

describe('MachineRouteOptionsSchema', () => {
  const valid = {
    jwtSecret: 'supersecret',
    supabaseUrl: 'https://project.supabase.co',
    serviceRoleKey: 'service-role-key-123',
    hmacSecret: 'hmac-secret-value',
  };

  it('accepts valid machine route options', () => {
    expect(MachineRouteOptionsSchema.safeParse(valid).success).toBe(true);
  });

  it('rejects missing hmacSecret', () => {
    const { hmacSecret: _h, ...noHmac } = valid;
    expect(MachineRouteOptionsSchema.safeParse(noHmac).success).toBe(false);
  });

  it('inherits base options validation', () => {
    expect(MachineRouteOptionsSchema.safeParse({ ...valid, supabaseUrl: 'bad-url' }).success).toBe(false);
  });
});

describe('EnvSchema', () => {
  const valid = {
    SUPABASE_URL: 'https://project.supabase.co',
    SUPABASE_SERVICE_ROLE_KEY: 'service-key-abc',
    SUPABASE_JWT_SECRET: 'jwt-secret-xyz',
    API_KEY_HMAC_SECRET: 'hmac-secret-abc',
  };

  it('accepts valid env vars', () => {
    expect(EnvSchema.safeParse(valid).success).toBe(true);
  });

  it('accepts optional SUPABASE_JWT_ISSUER', () => {
    expect(EnvSchema.safeParse({
      ...valid,
      SUPABASE_JWT_ISSUER: 'https://project.supabase.co/auth/v1',
    }).success).toBe(true);
  });

  it('rejects invalid SUPABASE_URL', () => {
    expect(EnvSchema.safeParse({ ...valid, SUPABASE_URL: 'not-a-url' }).success).toBe(false);
  });

  it('rejects invalid SUPABASE_JWT_ISSUER', () => {
    expect(EnvSchema.safeParse({ ...valid, SUPABASE_JWT_ISSUER: 'not-a-url' }).success).toBe(false);
  });

  it('rejects missing required fields', () => {
    const { SUPABASE_JWT_SECRET: _s, ...noSecret } = valid;
    expect(EnvSchema.safeParse(noSecret).success).toBe(false);
  });
});

describe('AuthResultSchema', () => {
  it('accepts JWT success result', () => {
    expect(AuthResultSchema.safeParse({ ok: true, type: 'jwt', sub: 'user-123' }).success).toBe(true);
  });

  it('accepts API key success result', () => {
    expect(AuthResultSchema.safeParse({
      ok: true,
      type: 'api_key',
      userId: '00000000-0000-0000-0000-000000000001',
      organizationId: '00000000-0000-0000-0000-000000000002',
    }).success).toBe(true);
  });

  it('rejects api_key result with non-uuid userId', () => {
    expect(AuthResultSchema.safeParse({
      ok: true,
      type: 'api_key',
      userId: 'not-a-uuid',
      organizationId: '00000000-0000-0000-0000-000000000002',
    }).success).toBe(false);
  });

  it('accepts failure result with Response error', () => {
    expect(AuthResultSchema.safeParse({
      ok: false,
      error: new Response('Unauthorized', { status: 401 }),
    }).success).toBe(true);
  });

  it('rejects failure result with non-Response error', () => {
    expect(AuthResultSchema.safeParse({
      ok: false,
      error: 'Unauthorized',
    }).success).toBe(false);
  });

  it('rejects unknown type', () => {
    expect(AuthResultSchema.safeParse({ ok: true, type: 'session', sub: 'x' }).success).toBe(false);
  });
});
