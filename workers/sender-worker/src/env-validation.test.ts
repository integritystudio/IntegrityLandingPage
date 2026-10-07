/**
 * Environment Variable Validation Tests
 *
 * Validates that all doppler secrets referenced in wrangler.toml
 * are actually used in the code and that no undefined variables are referenced.
 * 
 * This prevents:
 * - Typos in environment variable names
 * - Unused secrets that should be removed
 * - Missing secrets that should be added
 * 
 * Run with: npm test
 */

import { describe, it, expect } from 'vitest';
import { readFileSync } from 'node:fs';
import { dirname, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';

// This suite reads source files off disk, so it is genuinely a Node test rather than a Worker
// one. `__dirname` is a CommonJS global that an ES module does not get, and the package's
// tsconfig deliberately loads only @cloudflare/workers-types — so nothing supplies it
// ambiently either. Derive it from the module URL instead of widening `types`, which would
// make `process` and friends ambiently available to the Worker source in src/.
const moduleDir = dirname(fileURLToPath(import.meta.url));

// Environment variables defined in wrangler.toml comments (expected secrets)
const EXPECTED_DOPPLER_SECRETS = [
  'SHARED_SECRET',
  'SIGNING_KEYS',
  'ACTIVE_KEY_ID',
  'SUPABASE_URL',
  'SUPABASE_SERVICE_ROLE_KEY',
  'ALLOWED_ORIGINS_JSON',
  'STRIPE_SECRET_KEY',
  'STRIPE_PLAN_TO_PRICE_JSON',
  'APP_BASE_URL',
];

/**
 * Secrets declared `name?: string` in the Env interface. This is about the TYPE, not about
 * whether a deploy needs the value — SIGNING_KEYS and ACTIVE_KEY_ID are mandatory in practice
 * (without them /send returns 500 SIGNING_KEY_UNRESOLVED and forwards nothing), but they are
 * genuinely absent from some deploys, so `resolveOutboundSigningKey` enforces them at runtime
 * rather than the type lying about what is bound. SHARED_SECRET is optional for the opposite
 * reason: nothing reads it since CR29 step 2, and step 3 unbinds it.
 */
const OPTIONAL_SECRETS = new Set([
  'SHARED_SECRET',
  'SIGNING_KEYS',
  'ACTIVE_KEY_ID',
  'ALLOWED_ORIGINS_JSON',
  'STRIPE_SECRET_KEY',
  'STRIPE_PLAN_TO_PRICE_JSON',
  'APP_BASE_URL',
]);

describe('Environment Variable Validation', () => {
  it('types.ts Env interface declares every doppler secret with the right optionality', () => {
    const typesPath = resolve(moduleDir, './types.ts');
    const typesContent = readFileSync(typesPath, 'utf-8');

    // Checked in both directions: an optional secret has to appear as `name?: string`, so
    // dropping the `?` from a required one (or adding it to an optional one) fails here rather
    // than being skipped. The old version only asserted the required set and ignored the rest.
    EXPECTED_DOPPLER_SECRETS.forEach((secret) => {
      const optional = OPTIONAL_SECRETS.has(secret);
      const regex = new RegExp(`\\b${secret}${optional ? '\\?' : ''}:\\s*string`);
      expect(
        regex.test(typesContent),
        `'${secret}' should be declared ${optional ? 'optional' : 'required'} in the types.ts Env interface`
      ).toBe(true);
    });
  });

  it('wrangler.toml comments document all required secrets with correct names', () => {
    const wranglerPath = resolve(moduleDir, '../wrangler.toml');
    const wranglerContent = readFileSync(wranglerPath, 'utf-8');

    // Simply verify each expected secret name appears in the wrangler.toml comments
    // (all are documented in the Secrets section)
    EXPECTED_DOPPLER_SECRETS.forEach((secret) => {
      expect(
        wranglerContent.includes(secret),
        `Secret '${secret}' is not documented in wrangler.toml`
      ).toBe(true);
    });
  });
});
