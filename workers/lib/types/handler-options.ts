import { z } from 'zod';

// Base route options shared across handlers
export const BaseRouteOptionsSchema = z.object({
  /**
   * Legacy HS256 shared secret, optional since 2026-07-29. Supabase projects
   * migrated to ES256 signing keys have no such secret, and `verifyJwt` derives
   * the project's JWKS URL from `supabaseUrl` instead — so `supabaseUrl` is the
   * field verification actually depends on. Supply this only to keep verifying
   * tokens minted before a project's migration, until they expire.
   */
  jwtSecret: z.string().optional(),
  supabaseUrl: z.string().url(),
  serviceRoleKey: z.string(),
  /** Expected JWT issuer URL. When set, tokens from other issuers are rejected (V-02). */
  jwtIssuerUrl: z.string().url().optional(),
});

export type BaseRouteOptions = z.infer<typeof BaseRouteOptionsSchema>;

// Options with HMAC secret (for API key verification)
export const MachineRouteOptionsSchema = BaseRouteOptionsSchema.extend({
  hmacSecret: z.string(),
});

export type MachineRouteOptions = z.infer<typeof MachineRouteOptionsSchema>;

// Environment variables for Cloudflare Worker.
//
// Kept in step with api-gateway's `Env` by hand — nothing imports this schema, so a drift here
// is silent. It previously still described `SUPABASE_JWT_SECRET` and `SUPABASE_JWT_ISSUER`
// long after browser tokens moved to Auth0, i.e. it documented a contract that no longer
// existed. If it drifts again it should be deleted rather than left to mislead.
export const EnvSchema = z.object({
  /** Database access only; the service role key bypasses RLS. Not a token issuer. */
  SUPABASE_URL: z.string().url(),
  SUPABASE_SERVICE_ROLE_KEY: z.string(),
  API_KEY_HMAC_SECRET: z.string(),
  /** Auth0 tenant issuing browser tokens; the JWKS URL and expected `iss` derive from it. */
  AUTH0_DOMAIN: z.string(),
  /** Auth0 API identifier the token must be scoped to. Absent means `aud` is not validated. */
  AUTH0_AUDIENCE: z.string().optional(),
});

export type Env = z.infer<typeof EnvSchema>;

// Auth resolution result for dual JWT/API key auth
export type AuthResult =
  | { ok: true; type: 'jwt'; sub: string; userId: string }
  | { ok: true; type: 'api_key'; userId: string; organizationId: string }
  | { ok: false; error: Response };

export const AuthResultSchema = z.union([
  z.object({ ok: z.literal(true), type: z.literal('jwt'), sub: z.string(), userId: z.string().uuid() }),
  z.object({
    ok: z.literal(true),
    type: z.literal('api_key'),
    userId: z.string().uuid(),
    organizationId: z.string().uuid(),
  }),
  z.object({ ok: z.literal(false), error: z.instanceof(Response) }),
]);
