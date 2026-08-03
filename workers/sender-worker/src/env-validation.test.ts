/**
 * Environment Variable Validation Tests
 *
 * Validates that all doppler secrets referenced in wrangler.toml
 * are actually used in the code and that no undefined variables are referenced.
 * 
 * This prevents:
 * - Typos in environment variable names (like AUTHO_CLI_* vs AUTH0_CLI_*)
 * - Unused secrets that should be removed
 * - Missing secrets that should be added
 * 
 * Run with: npm test
 */

import { describe, it, expect } from 'vitest';
import { readFileSync } from 'fs';
import { resolve } from 'path';

// Environment variables defined in wrangler.toml comments (expected secrets)
const EXPECTED_DOPPLER_SECRETS = [
  'SHARED_SECRET',
  'SIGNING_KEYS',
  'ACTIVE_KEY_ID',
  'SUPABASE_URL',
  'SUPABASE_SERVICE_ROLE_KEY',
  'AUTH0_DOMAIN',
  'AUTH0_CLIENT_ID',
  'AUTH0_CLIENT_SECRET',
  'AUTH0_CLI_ID',
  'AUTH0_CLI_SECRET',
  'AUTH0_AUDIENCE',
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
    const typesPath = resolve(__dirname, './types.ts');
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

  it('types.ts Env interface defines both Regular Web App (ROPC) and M2M (CLI) credentials', () => {
    const typesPath = resolve(__dirname, './types.ts');
    const typesContent = readFileSync(typesPath, 'utf-8');

    expect(typesContent).toContain('AUTH0_CLIENT_ID');
    expect(typesContent).toContain('AUTH0_CLIENT_SECRET');
    expect(typesContent).toContain('AUTH0_CLI_ID');
    expect(typesContent).toContain('AUTH0_CLI_SECRET');
    expect(typesContent).toContain('AUTH0_AUDIENCE');

    // Ensure typo'd spelling doesn't exist
    expect(typesContent).not.toContain('AUTHO_CLI_ID');
    expect(typesContent).not.toContain('AUTHO_CLI_SECRET');
    expect(typesContent).not.toContain('AUTHO_CLI_AUDIENCE');
  });

  it('index.ts uses AUTH0_CLI_ID/SECRET for auth0CreateUser and AUTH0_CLIENT_ID/SECRET for ROPC', () => {
    const indexPath = resolve(__dirname, './index.ts');
    const indexContent = readFileSync(indexPath, 'utf-8');

    expect(indexContent).toContain('env.AUTH0_CLI_ID');
    expect(indexContent).toContain('env.AUTH0_CLI_SECRET');
    expect(indexContent).toContain('env.AUTH0_CLIENT_ID');
    expect(indexContent).toContain('env.AUTH0_CLIENT_SECRET');
    expect(indexContent).toContain('env.AUTH0_AUDIENCE');

    // Ensure typo'd names aren't used
    expect(indexContent).not.toContain('env.AUTHO_CLI_ID');
    expect(indexContent).not.toContain('env.AUTHO_CLI_SECRET');
    expect(indexContent).not.toContain('env.AUTHO_CLI_AUDIENCE');
  });

  it('wrangler.toml comments document all required secrets with correct names', () => {
    const wranglerPath = resolve(__dirname, '../wrangler.toml');
    const wranglerContent = readFileSync(wranglerPath, 'utf-8');

    // Simply verify each expected secret name appears in the wrangler.toml comments
    // (all are documented in the Secrets section)
    EXPECTED_DOPPLER_SECRETS.forEach((secret) => {
      expect(
        wranglerContent.includes(secret),
        `Secret '${secret}' is not documented in wrangler.toml`
      ).toBe(true);
    });

    // Ensure no typo'd secrets are documented
    expect(wranglerContent).not.toContain('AUTHO_CLI_ID');
    expect(wranglerContent).not.toContain('AUTHO_CLI_SECRET');
    expect(wranglerContent).not.toContain('AUTHO_CLI_AUDIENCE');
  });

  it('wrangler.toml documents both ROPC and M2M auth flows', () => {
    const wranglerPath = resolve(__dirname, '../wrangler.toml');
    const wranglerContent = readFileSync(wranglerPath, 'utf-8');

    expect(wranglerContent).toContain('AUTH0_CLIENT_ID');
    expect(wranglerContent).toContain('AUTH0_CLIENT_SECRET');
    expect(wranglerContent).toContain('AUTH0_CLI_ID');
    expect(wranglerContent).toContain('AUTH0_CLI_SECRET');
    expect(wranglerContent).toContain('AUTH0_AUDIENCE');
    expect(wranglerContent).toContain('client_credentials grant');
    expect(wranglerContent).toContain('password grant');
    expect(wranglerContent).toContain('/api/v2/');
  });

  it('no deprecated AUTHO_CLI_* variable names appear anywhere in codebase', () => {
    const typesPath = resolve(__dirname, './types.ts');
    const indexPath = resolve(__dirname, './index.ts');
    const wranglerPath = resolve(__dirname, '../wrangler.toml');

    const files = [
      { path: typesPath, name: 'types.ts' },
      { path: indexPath, name: 'index.ts' },
      { path: wranglerPath, name: 'wrangler.toml' },
    ];

    const deprecatedPattern = /AUTHO_CLI_[A-Z_]+/g;

    files.forEach(({ path, name }) => {
      const content = readFileSync(path, 'utf-8');
      const matches = content.match(deprecatedPattern) || [];

      expect(
        matches.length,
        `File '${name}' contains deprecated AUTHO_CLI_* variables: ${matches.join(', ')}`
      ).toBe(0);
    });
  });
});
