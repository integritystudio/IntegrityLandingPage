import { describe, it, expect } from 'vitest';
import {
  BaseRouteOptionsSchema,
  MachineRouteOptionsSchema,
  EnvSchema,
  AuthResultSchema,
} from './handler-options';

describe('BaseRouteOptionsSchema', () => {
  const valid = {
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

  // Ported from 'accepts options with no jwtSecret', which documented the field as
  // optional. The field is gone entirely as of 2026-07-31; this asserts a supplied
  // one is dropped rather than silently carried into a route's options, so nothing
  // can start depending on it again without failing here first.
  it('drops a supplied jwtSecret — the HS256 path it fed was removed', () => {
    const parsed = BaseRouteOptionsSchema.safeParse({ ...valid, jwtSecret: 'legacy-secret' });
    expect(parsed.success).toBe(true);
    if (parsed.success) expect(parsed.data).not.toHaveProperty('jwtSecret');
  });

  it('still requires supabaseUrl, which is what the JWKS URL derives from', () => {
    const { supabaseUrl: _u, ...noUrl } = valid;
    expect(BaseRouteOptionsSchema.safeParse(noUrl).success).toBe(false);
  });
});

describe('MachineRouteOptionsSchema', () => {
  const valid = {
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
    API_KEY_HMAC_SECRET: 'hmac-secret-abc',
    AUTH0_DOMAIN: 'tenant.us.auth0.com',
  };

  it('accepts valid env vars', () => {
    expect(EnvSchema.safeParse(valid).success).toBe(true);
  });

  it('accepts an optional AUTH0_AUDIENCE', () => {
    expect(EnvSchema.safeParse({ ...valid, AUTH0_AUDIENCE: 'https://api.example.com' }).success).toBe(true);
  });

  it('rejects invalid SUPABASE_URL', () => {
    expect(EnvSchema.safeParse({ ...valid, SUPABASE_URL: 'not-a-url' }).success).toBe(false);
  });

  // Without a tenant there is no JWKS URL and no expected issuer, so every JWT-authenticated
  // route 401s. It is required, not optional.
  it('rejects env with no AUTH0_DOMAIN', () => {
    const { AUTH0_DOMAIN: _d, ...noDomain } = valid;
    expect(EnvSchema.safeParse(noDomain).success).toBe(false);
  });

  // The two Supabase JWT fields were removed when browser tokens moved to Auth0. Supabase is
  // reached with the service role key and issues no token here, so a config still carrying
  // them is stale rather than invalid — extra keys are ignored, not rejected.
  it('ignores the retired SUPABASE_JWT_SECRET and SUPABASE_JWT_ISSUER keys', () => {
    const result = EnvSchema.safeParse({
      ...valid,
      SUPABASE_JWT_SECRET: 'jwt-secret-xyz',
      SUPABASE_JWT_ISSUER: 'https://project.supabase.co/auth/v1',
    });
    expect(result.success).toBe(true);
    expect(result.success && 'SUPABASE_JWT_SECRET' in result.data).toBe(false);
  });

  it('still rejects missing SUPABASE_URL, the database endpoint', () => {
    const { SUPABASE_URL: _u, ...noUrl } = valid;
    expect(EnvSchema.safeParse(noUrl).success).toBe(false);
  });
});

describe('AuthResultSchema', () => {
  it('accepts JWT success result', () => {
    expect(AuthResultSchema.safeParse({
      ok: true,
      type: 'jwt',
      sub: 'auth0|user-123',
      userId: '550e8400-e29b-41d4-a716-446655440001',
    }).success).toBe(true);
  });

  // The JWT sub identifies the caller to Auth0; userId is the internal users.id that
  // foreign keys reference. A jwt result carrying only the sub is what produced the
  // empty-dashboard bug, so the schema now requires both.
  it('rejects a JWT success result missing the internal userId', () => {
    expect(AuthResultSchema.safeParse({ ok: true, type: 'jwt', sub: 'auth0|user-123' }).success).toBe(false);
  });

  it('accepts API key success result', () => {
    expect(AuthResultSchema.safeParse({
      ok: true,
      type: 'api_key',
      userId: '550e8400-e29b-41d4-a716-446655440001',
      organizationId: '550e8400-e29b-41d4-a716-446655440002',
    }).success).toBe(true);
  });

  it('rejects api_key result with non-uuid userId', () => {
    expect(AuthResultSchema.safeParse({
      ok: true,
      type: 'api_key',
      userId: 'not-a-uuid',
      organizationId: '550e8400-e29b-41d4-a716-446655440002',
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
