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

import { describe, it, expect, beforeAll, afterAll, beforeEach, vi } from 'vitest';
import { z } from 'zod';
import * as Sentry from '@sentry/node';
import { createServer, type Server } from 'node:http';
import type { AddressInfo } from 'node:net';
import type Stripe from 'stripe';
import {
  EnvSchema,
  isTerminalSubscriptionStatus,
  linkDecision,
  orgIdFromSubscriptionMetadata,
  processCustomer,
  recordError,
  toBillingStatus,
} from './full-reconciliation.js';
import {
  STRIPE_SUBSCRIPTION_STATUSES,
  isTerminalSubscriptionStatus as webhookIsTerminalSubscriptionStatus,
  toBillingStatus as webhookToBillingStatus,
} from '../workers/lib/billing.js';

// ─── Schemas (copy from reconciliation script) ────────────────────────────


const SupabaseErrorSchema = z.object({
  message: z.string(),
  code: z.string().optional(),
});

const OrgRowSchema = z.array(z.object({ id: z.string().uuid() })).min(1);

// ─── Environment Schema Tests ────────────────────────────────────────────

const VALID_ENV = {
  STRIPE_SECRET_KEY: 'sk_test_abc123def456',
  SUPABASE_URL: 'https://proj.supabase.co',
  SUPABASE_SERVICE_ROLE_KEY: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...',
};

describe('EnvSchema validation', () => {
  it.each(['sk_test_abc123', 'sk_live_production123', 'rk_live_restricted123', 'a-format-not-invented-yet'])(
    'accepts any non-empty Stripe key (%s)',
    (key) => {
      expect(EnvSchema.safeParse({ ...VALID_ENV, STRIPE_SECRET_KEY: key }).success).toBe(true);
    },
  );

  it.each(['eyJhbGciOiJIUzI1NiJ9...', 'sb_secret_abc123', 'a-format-not-invented-yet'])(
    'accepts any non-empty Supabase key (%s)',
    (key) => {
      expect(EnvSchema.safeParse({ ...VALID_ENV, SUPABASE_SERVICE_ROLE_KEY: key }).success).toBe(true);
    },
  );

  it.each(['STRIPE_SECRET_KEY', 'SUPABASE_SERVICE_ROLE_KEY'] as const)('rejects an empty %s', (field) => {
    const result = EnvSchema.safeParse({ ...VALID_ENV, [field]: '' });
    expect(result.success).toBe(false);
    if (!result.success) {
      expect(result.error.issues.map((i) => `${i.path.join('.')}: ${i.message}`)).toEqual([`${field}: is required`]);
    }
  });

  it.each(['STRIPE_SECRET_KEY', 'SUPABASE_URL', 'SUPABASE_SERVICE_ROLE_KEY'] as const)('rejects a missing %s', (field) => {
    const { [field]: _omitted, ...rest } = VALID_ENV;
    const result = EnvSchema.safeParse(rest);
    expect(result.success).toBe(false);
    if (!result.success) expect(result.error.issues.map((i) => i.path.join('.'))).toEqual([field]);
  });

  it('rejects invalid Supabase URL (not a URL)', () => {
    expect(EnvSchema.safeParse({ ...VALID_ENV, SUPABASE_URL: 'not-a-url' }).success).toBe(false);
  });

  it('reports every bad field, in the format runFullReconciliation prints', () => {
    const result = EnvSchema.safeParse({ STRIPE_SECRET_KEY: '', SUPABASE_URL: 'not-a-url', SUPABASE_SERVICE_ROLE_KEY: '' });
    expect(result.success).toBe(false);
    if (!result.success) {
      const issues = result.error.issues.map((i) => `${i.path.join('.')}: ${i.message}`).join('; ');
      expect(issues).toMatch(/^STRIPE_SECRET_KEY: is required; SUPABASE_URL: .+; SUPABASE_SERVICE_ROLE_KEY: is required$/);
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

describe('isTerminalSubscriptionStatus', () => {
  it.each(STRIPE_SUBSCRIPTION_STATUSES)('agrees with stripe-webhook on %s', (status) => {
    expect(isTerminalSubscriptionStatus(status)).toBe(webhookIsTerminalSubscriptionStatus(status));
  });

  it('clears the pointer only for canceled and incomplete_expired', () => {
    expect(STRIPE_SUBSCRIPTION_STATUSES.filter((status) => isTerminalSubscriptionStatus(status)))
      .toEqual(['incomplete_expired', 'canceled']);
  });
});

describe('toBillingStatus', () => {
  it.each(STRIPE_SUBSCRIPTION_STATUSES)('stores %s unchanged, as stripe-webhook does', (status) => {
    expect(toBillingStatus(status)).toBe(status);
    expect(toBillingStatus(status)).toBe(webhookToBillingStatus(status));
  });

  it('falls back to inactive for a status Stripe has not defined, as stripe-webhook does', () => {
    expect(toBillingStatus('a_future_status')).toBe('inactive');
    expect(toBillingStatus('a_future_status')).toBe(webhookToBillingStatus('a_future_status'));
  });
});

describe('recordError', () => {
  // The real SDK with delivery cut off in beforeSend: nothing leaves the process.
  const events: Sentry.ErrorEvent[] = [];
  Sentry.init({
    dsn: 'https://publickey@sentry.invalid/1',
    beforeSend: (event) => {
      events.push(event);
      return null;
    },
  });

  beforeEach(() => {
    events.length = 0;
  });

  // Event processing is asynchronous; beforeSend has run once the queue drains.
  const FLUSH_TIMEOUT_MS = 2_000;
  const delivered = () => Sentry.flush(FLUSH_TIMEOUT_MS);

  it('adds the message to the summary and groups the event by phase and kind', async () => {
    const summary = { errors: [] as string[] };
    recordError(summary, 'customers', 'unmapped-price', 'Customer cus_1: Unmapped Stripe price price_x');
    await delivered();

    expect(summary.errors).toEqual(['Customer cus_1: Unmapped Stripe price price_x']);
    expect(events).toHaveLength(1);
    expect(events[0].fingerprint).toEqual(['full-reconciliation', 'customers', 'unmapped-price']);
    expect(events[0].tags).toMatchObject({ phase: 'customers', kind: 'unmapped-price' });
  });

  it('keeps two kinds of the same phase in separate Sentry issues', async () => {
    const summary = { errors: [] as string[] };
    recordError(summary, 'customers', 'org-lookup', 'lookup failed');
    recordError(summary, 'customers', 'subscription-upsert', 'upsert failed');
    await delivered();

    expect(events.map((event) => event.fingerprint)).toEqual([
      ['full-reconciliation', 'customers', 'org-lookup'],
      ['full-reconciliation', 'customers', 'subscription-upsert'],
    ]);
  });

  it('reports the thrown error itself when one is given', async () => {
    recordError({ errors: [] }, 'entitlements', 'unexpected', 'wrapped message', new TypeError('fetch failed'));
    await delivered();

    expect(events[0].exception?.values?.[0]).toMatchObject({ type: 'TypeError', value: 'fetch failed' });
    expect(events[0].extra).toMatchObject({ reconciliation_error: 'wrapped message' });
  });
});

// ─── processCustomer against a local stand-in for Supabase's REST API ─────

describe('processCustomer', () => {
  const SUBSCRIPTION_ROW = '550e8400-e29b-41d4-a716-446655440099';
  const GROWTH_PRICE = 'price_growth';
  const SERVICE_KEY = 'service-key';
  const PRICE_TO_PLAN = { [GROWTH_PRICE]: 'growth' } as const;

  type Recorded = { method: string; path: string; body: Record<string, unknown> | null };
  const requests: Recorded[] = [];
  let server: Server;
  let supabaseUrl: string;

  beforeAll(async () => {
    server = createServer((req, res) => {
      let raw = '';
      req.on('data', (chunk) => { raw += chunk; });
      req.on('end', () => {
        const path = decodeURIComponent(req.url ?? '');
        requests.push({ method: req.method ?? '', path, body: raw ? JSON.parse(raw) : null });
        const rows = req.method !== 'GET' ? null
          : path.startsWith('/rest/v1/organizations') ? [{ id: ORG_A, stripe_customer_id: CUSTOMER }]
          : [{ id: SUBSCRIPTION_ROW }];
        res.setHeader('Content-Type', 'application/json');
        res.end(rows ? JSON.stringify(rows) : '');
      });
    });
    await new Promise<void>((resolve) => server.listen(0, '127.0.0.1', resolve));
    supabaseUrl = `http://127.0.0.1:${(server.address() as AddressInfo).port}`;
  });

  afterAll(() => new Promise<void>((resolve) => { server.close(() => resolve()); }));

  beforeEach(() => {
    requests.length = 0;
  });

  const customerWith = (status: Stripe.Subscription.Status, priceId: string) => ({
    id: CUSTOMER,
    subscriptions: {
      data: [{
        id: 'sub_1',
        status,
        metadata: {},
        cancel_at_period_end: false,
        items: { data: [{ price: { id: priceId }, current_period_start: 1_700_000_000, current_period_end: 1_702_592_000 }] },
      }],
    },
  }) as unknown as Stripe.Customer;

  const writes = () => requests.filter((request) => request.method !== 'GET');
  const orgPatch = () => requests.find((request) => request.method === 'PATCH')?.body;

  it('writes the subscription with the table columns, one row per org', async () => {
    await processCustomer(supabaseUrl, SERVICE_KEY, customerWith('active', GROWTH_PRICE), PRICE_TO_PLAN, false);

    const upsert = requests.find((request) => request.method === 'POST');
    expect(upsert?.path).toBe('/rest/v1/subscriptions?on_conflict=organization_id');
    expect(Object.keys(upsert?.body ?? {}).sort()).toEqual([
      'cancel_at_period_end', 'current_period_end', 'current_period_start', 'organization_id',
      'status', 'stripe_price_id', 'stripe_subscription_id', 'updated_at',
    ]);
    expect(upsert?.body).toMatchObject({ organization_id: ORG_A, stripe_subscription_id: 'sub_1', stripe_price_id: GROWTH_PRICE, status: 'active' });
  });

  it('points the org at its subscription row, sets the plan and bumps quota_version', async () => {
    const before = Date.now();
    const result = await processCustomer(supabaseUrl, SERVICE_KEY, customerWith('active', GROWTH_PRICE), PRICE_TO_PLAN, false);

    expect(result).toEqual({ ok: true, linked: false, targets: [{ orgId: ORG_A, tier: 'growth' }], issues: [] });
    expect(orgPatch()).toMatchObject({ billing_status: 'active', current_plan: 'growth', active_subscription_id: SUBSCRIPTION_ROW });
    expect(orgPatch()?.quota_version).toBeGreaterThanOrEqual(before);
  });

  it('clears the pointer for a terminal subscription without looking the row up', async () => {
    await processCustomer(supabaseUrl, SERVICE_KEY, customerWith('canceled', GROWTH_PRICE), PRICE_TO_PLAN, false);

    expect(orgPatch()).toMatchObject({ billing_status: 'canceled', active_subscription_id: null });
    expect(requests.some((request) => request.method === 'GET' && request.path.startsWith('/rest/v1/subscriptions'))).toBe(false);
  });

  it.each(['trialing', 'unpaid', 'paused'] as const)('writes a %s subscription with that billing status and keeps the pointer', async (status) => {
    await processCustomer(supabaseUrl, SERVICE_KEY, customerWith(status, GROWTH_PRICE), PRICE_TO_PLAN, false);

    expect(orgPatch()).toMatchObject({ billing_status: status, active_subscription_id: SUBSCRIPTION_ROW });
  });

  it('reports an unmapped price, leaves current_plan alone and rebuilds at the default plan', async () => {
    const result = await processCustomer(supabaseUrl, SERVICE_KEY, customerWith('active', 'price_unknown'), PRICE_TO_PLAN, false);

    expect(result).toMatchObject({ ok: true, targets: [{ orgId: ORG_A, tier: 'starter' }] });
    expect(result.ok && result.issues).toEqual([{
      kind: 'unmapped-price',
      error: 'Unmapped Stripe price price_unknown on subscription sub_1: entitlements rebuilt at starter, current_plan left alone',
    }]);
    expect(orgPatch()).not.toHaveProperty('current_plan');
  });

  it('writes nothing in a dry run', async () => {
    const result = await processCustomer(supabaseUrl, SERVICE_KEY, customerWith('active', GROWTH_PRICE), PRICE_TO_PLAN, true);

    expect(result).toMatchObject({ ok: true, targets: [{ orgId: ORG_A, tier: 'growth' }] });
    expect(writes()).toEqual([]);
  });
});
