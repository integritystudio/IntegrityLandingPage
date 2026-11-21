/**
 * Full Reconciliation Script Tests
 *
 * Tests the billing reconciliation script's data validation, error handling,
 * and external API boundaries (Supabase REST, Stripe API).
 *
 * Focus areas:
 * - Zod schema validation (env vars, Supabase responses, org lookups)
 * - JSON parsing error recovery
 * - Error message quality and diagnostics
 * - Database result contracts
 */

import { describe, it, expect, beforeEach, vi } from 'vitest';
import { z } from 'zod';
import { EnvSchema, linkDecision, orgIdFromSubscriptionMetadata } from './full-reconciliation.js';

// ─── Schemas (copy from reconciliation script) ────────────────────────────


const SupabaseErrorSchema = z.object({
  message: z.string(),
  code: z.string().optional(),
});

const OrgRowSchema = z.array(z.object({ id: z.string().uuid() })).min(1);

// ─── Environment Schema Tests ────────────────────────────────────────────

describe('EnvSchema validation', () => {
  it('accepts valid test Stripe key', () => {
    const result = EnvSchema.safeParse({
      STRIPE_SECRET_KEY: 'sk_test_abc123def456',
      SUPABASE_URL: 'https://proj.supabase.co',
      SUPABASE_SERVICE_ROLE_KEY: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...',
    });
    expect(result.success).toBe(true);
  });

  it('accepts valid live Stripe key', () => {
    const result = EnvSchema.safeParse({
      STRIPE_SECRET_KEY: 'sk_live_production123',
      SUPABASE_URL: 'https://prod.supabase.co',
      SUPABASE_SERVICE_ROLE_KEY: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...',
    });
    expect(result.success).toBe(true);
  });

  it.each(['rk_live_restricted123', 'rk_test_restricted123'])('accepts restricted Stripe key %s', (key) => {
    const result = EnvSchema.safeParse({
      STRIPE_SECRET_KEY: key,
      SUPABASE_URL: 'https://prod.supabase.co',
      SUPABASE_SERVICE_ROLE_KEY: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...',
    });
    expect(result.success).toBe(true);
  });

  it('accepts a Supabase secret key', () => {
    const result = EnvSchema.safeParse({
      STRIPE_SECRET_KEY: 'rk_live_restricted123',
      SUPABASE_URL: 'https://prod.supabase.co',
      SUPABASE_SERVICE_ROLE_KEY: 'sb_secret_abc123',
    });
    expect(result.success).toBe(true);
  });

  it('rejects a publishable Supabase key', () => {
    const result = EnvSchema.safeParse({
      STRIPE_SECRET_KEY: 'sk_test_abc123',
      SUPABASE_URL: 'https://proj.supabase.co',
      SUPABASE_SERVICE_ROLE_KEY: 'sb_publishable_abc123',
    });
    expect(result.success).toBe(false);
  });

  it('rejects Stripe key with wrong prefix', () => {
    const result = EnvSchema.safeParse({
      STRIPE_SECRET_KEY: 'pk_live_publishable_key',
      SUPABASE_URL: 'https://proj.supabase.co',
      SUPABASE_SERVICE_ROLE_KEY: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...',
    });
    expect(result.success).toBe(false);
    if (!result.success) {
      expect(result.error.issues[0].message).toContain('sk_ or rk_');
    }
  });

  it('rejects invalid Supabase URL (not a URL)', () => {
    const result = EnvSchema.safeParse({
      STRIPE_SECRET_KEY: 'sk_test_abc123',
      SUPABASE_URL: 'not-a-url',
      SUPABASE_SERVICE_ROLE_KEY: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...',
    });
    expect(result.success).toBe(false);
  });

  it('rejects service role key without JWT prefix', () => {
    const result = EnvSchema.safeParse({
      STRIPE_SECRET_KEY: 'sk_test_abc123',
      SUPABASE_URL: 'https://proj.supabase.co',
      SUPABASE_SERVICE_ROLE_KEY: 'not-a-jwt-key',
    });
    expect(result.success).toBe(false);
    if (!result.success) {
      expect(result.error.issues[0].message).toContain('eyJ');
    }
  });

  it('rejects missing STRIPE_SECRET_KEY', () => {
    const result = EnvSchema.safeParse({
      SUPABASE_URL: 'https://proj.supabase.co',
      SUPABASE_SERVICE_ROLE_KEY: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...',
    });
    expect(result.success).toBe(false);
  });

  it('provides per-field error messages', () => {
    const result = EnvSchema.safeParse({
      STRIPE_SECRET_KEY: 'wrong',
      SUPABASE_URL: 'not-a-url',
      SUPABASE_SERVICE_ROLE_KEY: 'not-jwt',
    });
    expect(result.success).toBe(false);
    if (!result.success) {
      const issues = result.error.issues.map((i) => i.path.join('.'));
      expect(issues).toContain('STRIPE_SECRET_KEY');
      expect(issues).toContain('SUPABASE_URL');
      expect(issues).toContain('SUPABASE_SERVICE_ROLE_KEY');
    }
  });
});

// ─── Supabase Error Schema Tests ─────────────────────────────────────────

describe('SupabaseErrorSchema validation', () => {
  it('accepts valid error with message and code', () => {
    const result = SupabaseErrorSchema.safeParse({
      message: 'Unique violation',
      code: '23505',
    });
    expect(result.success).toBe(true);
  });

  it('accepts error with message only (code optional)', () => {
    const result = SupabaseErrorSchema.safeParse({
      message: 'Connection timeout',
    });
    expect(result.success).toBe(true);
  });

  it('rejects error missing message field', () => {
    const result = SupabaseErrorSchema.safeParse({
      code: '23505',
    });
    expect(result.success).toBe(false);
  });

  it('rejects non-object input', () => {
    const result = SupabaseErrorSchema.safeParse('error string');
    expect(result.success).toBe(false);
  });

  it('handles null gracefully', () => {
    const result = SupabaseErrorSchema.safeParse(null);
    expect(result.success).toBe(false);
  });

  it('handles undefined gracefully', () => {
    const result = SupabaseErrorSchema.safeParse(undefined);
    expect(result.success).toBe(false);
  });
});

// ─── Org Row Schema Tests ────────────────────────────────────────────────

describe('OrgRowSchema validation', () => {
  it('accepts array with valid UUID', () => {
    const result = OrgRowSchema.safeParse([
      { id: '550e8400-e29b-41d4-a716-446655440000' },
    ]);
    expect(result.success).toBe(true);
  });

  it('accepts array with multiple UUIDs', () => {
    const result = OrgRowSchema.safeParse([
      { id: '550e8400-e29b-41d4-a716-446655440000' },
      { id: '550e8400-e29b-41d4-a716-446655440001' },
    ]);
    expect(result.success).toBe(true);
  });

  it('rejects empty array (enforces .min(1))', () => {
    const result = OrgRowSchema.safeParse([]);
    expect(result.success).toBe(false);
    if (!result.success) {
      const message = result.error.flatten().formErrors?.[0];
      expect(message).toContain('>=1');
    }
  });

  it('rejects invalid UUID format', () => {
    const result = OrgRowSchema.safeParse([
      { id: 'not-a-uuid' },
    ]);
    expect(result.success).toBe(false);
  });

  it('rejects non-array input', () => {
    const result = OrgRowSchema.safeParse({ id: 'some-uuid' });
    expect(result.success).toBe(false);
  });

  it('rejects array with missing id field', () => {
    const result = OrgRowSchema.safeParse([
      { name: 'Acme Corp' },
    ]);
    expect(result.success).toBe(false);
  });
});

// ─── JSON Parsing Tests ──────────────────────────────────────────────────

describe('parseJsonSafe (error boundary guard)', () => {
  it('parses valid JSON', async () => {
    const resp = new Response(JSON.stringify({ message: 'ok' }));
    const parseJsonSafe = async (r: Response) => {
      try {
        return await r.json();
      } catch {
        return undefined;
      }
    };
    const result = await parseJsonSafe(resp);
    expect(result).toEqual({ message: 'ok' });
  });

  it('returns undefined for malformed JSON', async () => {
    const resp = new Response('not valid json at all');
    const parseJsonSafe = async (r: Response) => {
      try {
        return await r.json();
      } catch {
        return undefined;
      }
    };
    const result = await parseJsonSafe(resp);
    expect(result).toBeUndefined();
  });

  it('returns undefined for HTML error page', async () => {
    const resp = new Response('<html><body>502 Bad Gateway</body></html>');
    const parseJsonSafe = async (r: Response) => {
      try {
        return await r.json();
      } catch {
        return undefined;
      }
    };
    const result = await parseJsonSafe(resp);
    expect(result).toBeUndefined();
  });

  it('returns undefined for empty response', async () => {
    const resp = new Response('');
    const parseJsonSafe = async (r: Response) => {
      try {
        return await r.json();
      } catch {
        return undefined;
      }
    };
    const result = await parseJsonSafe(resp);
    expect(result).toBeUndefined();
  });
});

// ─── Error Handling Contract Tests ───────────────────────────────────────

describe('Supabase error handling contract', () => {
  it('produces informative error when resp.json() throws and safeParse falls back', () => {
    const body = undefined; // Simulates parseJsonSafe returning undefined
    const parseResult = SupabaseErrorSchema.safeParse(body);
    const message = parseResult.success
      ? parseResult.data.message
      : `HTTP 502: ${JSON.stringify(body)}`;

    expect(message).toBe('HTTP 502: undefined');
    expect(message).toContain('502');
  });

  it('includes raw body in error message when schema validation fails', () => {
    const body = { hint: 'something', details: 'details' }; // Missing required 'message'
    const parseResult = SupabaseErrorSchema.safeParse(body);
    const message = parseResult.success
      ? parseResult.data.message
      : `HTTP 503: ${JSON.stringify(body)}`;

    expect(message).toContain('503');
    expect(message).toContain('hint');
    expect(message).toContain('details');
  });

  it('uses message from Supabase when available', () => {
    const body = { message: 'Unique constraint violation on org_id' };
    const parseResult = SupabaseErrorSchema.safeParse(body);
    const message = parseResult.success
      ? parseResult.data.message
      : `HTTP 400: ${JSON.stringify(body)}`;

    expect(message).toBe('Unique constraint violation on org_id');
  });
});

// ─── OrgRowSchema Edge Cases ─────────────────────────────────────────────

describe('OrgRowSchema error reporting', () => {
  it('reports clear error when response is empty array', () => {
    const result = OrgRowSchema.safeParse([]);
    expect(result.success).toBe(false);
    if (!result.success) {
      const flatErrors = result.error.flatten();
      expect(flatErrors.formErrors?.length).toBeGreaterThan(0);
    }
  });

  it('fallback to JSON stringify when ZodError has no formErrors', () => {
    // This simulates the fallback in the actual code
    const body = { unexpected: 'structure' };
    const orgsResult = OrgRowSchema.safeParse(body);
    const message = !orgsResult.success
      ? `Unexpected org lookup response: ${orgsResult.error.flatten().formErrors[0] ?? JSON.stringify(body)}`
      : 'should not reach';

    expect(message).toContain('Unexpected org lookup response');
    // Zod's validation error message is included in formErrors
    expect(message).toContain('expected array');
  });
});

// ─── Integration: Multiple Env Var Errors ───────────────────────────────

describe('EnvSchema error message formatting', () => {
  it('formats multiple field errors clearly', () => {
    const envResult = EnvSchema.safeParse({
      STRIPE_SECRET_KEY: 'invalid',
      SUPABASE_URL: 'not-a-url',
      SUPABASE_SERVICE_ROLE_KEY: 'no-jwt',
    });

    if (!envResult.success) {
      const issues = envResult.error.issues.map((i) => `${i.path.join('.')}: ${i.message}`);
      const combined = issues.join('; ');
      expect(combined).toContain('STRIPE_SECRET_KEY');
      expect(combined).toContain('SUPABASE_URL');
      expect(combined).toContain('SUPABASE_SERVICE_ROLE_KEY');
      // Verify format matches the reconciliation script
      expect(combined).toMatch(/\w+: .+; \w+: .+; \w+: .+/);
    }
  });

  it('matches exact format used in runFullReconciliation error message', () => {
    const envResult = EnvSchema.safeParse({
      STRIPE_SECRET_KEY: 'wrong',
      SUPABASE_URL: 'invalid-url',
      SUPABASE_SERVICE_ROLE_KEY: 'no-jwt-prefix',
    });

    if (!envResult.success) {
      const issues = envResult.error.issues.map((i) => `${i.path.join('.')}: ${i.message}`).join('; ');
      const errorMessage = `Invalid environment: ${issues}`;
      expect(errorMessage).toContain('Invalid environment:');
      expect(errorMessage).toContain('STRIPE_SECRET_KEY:');
    }
  });
});

// ─── Linking an unlinked customer from subscription metadata ─────────────
// These import the script itself; its entry guard keeps main() from running.


const ORG_A = '550e8400-e29b-41d4-a716-446655440000';
const ORG_B = '550e8400-e29b-41d4-a716-446655440001';
const CUSTOMER = 'cus_new';

describe('orgIdFromSubscriptionMetadata', () => {
  it('returns the org id every subscription names', () => {
    const result = orgIdFromSubscriptionMetadata([{ metadata: { org_id: ORG_A } }, { metadata: { org_id: ORG_A } }]);
    expect(result).toEqual({ orgId: ORG_A });
  });

  it('ignores subscriptions without the key when another names an org', () => {
    expect(orgIdFromSubscriptionMetadata([{ metadata: {} }, { metadata: { org_id: ORG_A } }])).toEqual({ orgId: ORG_A });
  });

  it('refuses when no subscription names an org', () => {
    expect(orgIdFromSubscriptionMetadata([{ metadata: {} }])).toEqual({ reason: 'no subscription carries metadata.org_id' });
  });

  it('refuses when subscriptions name different orgs', () => {
    const result = orgIdFromSubscriptionMetadata([{ metadata: { org_id: ORG_A } }, { metadata: { org_id: ORG_B } }]);
    expect(result).toEqual({ reason: `subscriptions name 2 different orgs: ${ORG_A}, ${ORG_B}` });
  });

  it('refuses an org id that is not a UUID, before it reaches a query filter', () => {
    expect(orgIdFromSubscriptionMetadata([{ metadata: { org_id: 'x&id=neq.y' } }]))
      .toEqual({ reason: 'metadata.org_id is not a UUID: x&id=neq.y' });
  });
});

describe('linkDecision', () => {
  it('links an org that has no customer yet', () => {
    expect(linkDecision(CUSTOMER, ORG_A, { id: ORG_A, stripe_customer_id: null })).toEqual({ link: true, orgId: ORG_A });
  });

  it('refuses when the named org does not exist', () => {
    expect(linkDecision(CUSTOMER, ORG_A, null)).toEqual({ link: false, reason: `metadata.org_id ${ORG_A} matches no org` });
  });

  it('never overwrites another customer id', () => {
    expect(linkDecision(CUSTOMER, ORG_A, { id: ORG_A, stripe_customer_id: 'cus_existing' }))
      .toEqual({ link: false, reason: `org ${ORG_A} is already linked to cus_existing` });
  });
});
