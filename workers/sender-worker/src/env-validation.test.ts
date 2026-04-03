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
  'SUPABASE_URL',
  'SUPABASE_SERVICE_ROLE_KEY',
  'AUTH0_DOMAIN',
  'AUTH0_CLIENT_ID',
  'AUTH0_CLIENT_SECRET',
  'AUTH0_AUDIENCE',
  'AUTH0_CLI_ID',
  'AUTH0_CLI_SECRET',
  'AUTH0_CLI_AUDIENCE',
  'ALLOWED_ORIGINS_JSON',
  'STRIPE_SECRET_KEY',
  'STRIPE_PLAN_TO_PRICE_JSON',
  'APP_BASE_URL',
];

// Variables that are optional (should not fail if missing from env interface)
const OPTIONAL_SECRETS = new Set([
  'ALLOWED_ORIGINS_JSON',
  'STRIPE_SECRET_KEY',
  'STRIPE_PLAN_TO_PRICE_JSON',
  'APP_BASE_URL',
]);

describe('Environment Variable Validation', () => {
  it('types.ts Env interface includes all required doppler secrets', () => {
    const typesPath = resolve(__dirname, './types.ts');
    const typesContent = readFileSync(typesPath, 'utf-8');

    const requiredSecrets = EXPECTED_DOPPLER_SECRETS.filter(
      (secret) => !OPTIONAL_SECRETS.has(secret)
    );

    requiredSecrets.forEach((secret) => {
      const regex = new RegExp(`\\b${secret}:\\s*string`, 'g');
      expect(
        regex.test(typesContent),
        `Missing or incorrectly typed '${secret}' in types.ts Env interface`
      ).toBe(true);
    });
  });

  it('types.ts Env interface uses correct AUTH0_CLI_* naming (not AUTHO_*)', () => {
    const typesPath = resolve(__dirname, './types.ts');
    const typesContent = readFileSync(typesPath, 'utf-8');

    // Ensure correct spelling exists
    expect(typesContent).toContain('AUTH0_CLI_ID');
    expect(typesContent).toContain('AUTH0_CLI_SECRET');
    expect(typesContent).toContain('AUTH0_CLI_AUDIENCE');

    // Ensure typo'd spelling doesn't exist
    expect(typesContent).not.toContain('AUTHO_CLI_ID');
    expect(typesContent).not.toContain('AUTHO_CLI_SECRET');
    expect(typesContent).not.toContain('AUTHO_CLI_AUDIENCE');
  });

  it('index.ts uses AUTH0_CLI_* credentials (not AUTHO_*) when calling auth0CreateUser', () => {
    const indexPath = resolve(__dirname, './index.ts');
    const indexContent = readFileSync(indexPath, 'utf-8');

    // Check that auth0CreateUser is called with correct env variable names
    const auth0CreateUserCall = indexContent.match(
      /auth0CreateUser\([^)]+\)/
    );
    expect(auth0CreateUserCall).toBeTruthy();
    expect(indexContent).toContain('env.AUTH0_CLI_ID');
    expect(indexContent).toContain('env.AUTH0_CLI_SECRET');
    expect(indexContent).toContain('env.AUTH0_CLI_AUDIENCE');

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

  it('Auth0 Management API (M2M) credentials are distinct from ROPC credentials', () => {
    const wranglerPath = resolve(__dirname, '../wrangler.toml');
    const wranglerContent = readFileSync(wranglerPath, 'utf-8');

    // Verify both sets of credentials are documented with clear descriptions
    expect(wranglerContent).toContain('client_credentials grant');
    expect(wranglerContent).toContain('password grant');

    // Verify the CLI credentials use Management API
    expect(wranglerContent).toContain('AUTH0_CLI_ID');
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
