import { z } from 'zod';
import type { SupabaseClient } from '../supabase';

// Base route options shared across handlers
export const BaseRouteOptionsSchema = z.object({
  jwtSecret: z.string(),
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

// Environment variables for Cloudflare Worker
export const EnvSchema = z.object({
  SUPABASE_URL: z.string().url(),
  SUPABASE_SERVICE_ROLE_KEY: z.string(),
  SUPABASE_JWT_SECRET: z.string(),
  API_KEY_HMAC_SECRET: z.string(),
  /** JWT issuer URL for `iss` claim validation. Set to Supabase project auth URL. */
  SUPABASE_JWT_ISSUER: z.string().url().optional(),
});

export type Env = z.infer<typeof EnvSchema>;

// Request/Response handling types
export interface RequestOptions extends BaseRouteOptions {
  _sbOverride?: SupabaseClient;
}

export interface MachineRequestOptions extends MachineRouteOptions {
  _sbOverride?: SupabaseClient;
}

// Auth resolution result for dual JWT/API key auth
export type AuthResult =
  | { ok: true; type: 'jwt'; sub: string }
  | { ok: true; type: 'api_key'; userId: string; organizationId: string }
  | { ok: false; error: Response };

export const AuthResultSchema = z.union([
  z.object({ ok: z.literal(true), type: z.literal('jwt'), sub: z.string() }),
  z.object({
    ok: z.literal(true),
    type: z.literal('api_key'),
    userId: z.string().uuid(),
    organizationId: z.string().uuid(),
  }),
  z.object({ ok: z.literal(false), error: z.instanceof(Response) }),
]);
