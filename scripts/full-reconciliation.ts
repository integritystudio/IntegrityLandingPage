/**
 * Full Reconciliation Script — T24
 *
 * "Nuclear option": rebuilds local billing state from Stripe when the database
 * is out of sync after an extended outage, data corruption, or backup restore.
 *
 * Stripe is the source of truth for billing state. This script:
 *   1. Pages through all Stripe customers (with expanded subscriptions)
 *   2. Upserts organizations and subscriptions in Supabase
 *   3. Rebuilds entitlements from the current subscription tier
 *   4. Supports --dry-run mode to preview changes before applying
 *
 * Usage:
 *   npx ts-node scripts/full-reconciliation.ts [--dry-run]
 *
 * Required env vars:
 *   STRIPE_SECRET_KEY      — Stripe secret key (sk_live_... or sk_test_...)
 *   SUPABASE_URL           — Supabase project URL
 *   SUPABASE_SERVICE_ROLE_KEY — Supabase service-role key
 *
 * See: docs/security/DISASTER_RECOVERY_PLAN.md (Scenario E)
 */

import Stripe from 'stripe';
import { z } from 'zod';

// ---------------------------------------------------------------------------
// Types
// ---------------------------------------------------------------------------

type PlanKey = 'free' | 'growth' | 'enterprise';
type BillingStatus = 'active' | 'past_due' | 'canceled' | 'inactive';

interface ReconciliationSummary {
  customersProcessed: number;
  orgsUpserted: number;
  subscriptionsUpserted: number;
  orgEntitlementsRebuilt: number;
  errors: string[];
}

interface DbResult {
  ok: boolean;
  error?: string;
}

// ---------------------------------------------------------------------------
// Zod schemas
// ---------------------------------------------------------------------------

const EnvSchema = z.object({
  STRIPE_SECRET_KEY: z.string().regex(/^sk_(test|live)_/, 'must start with sk_test_ or sk_live_'),
  SUPABASE_URL: z.string().url(),
  SUPABASE_SERVICE_ROLE_KEY: z.string().regex(/^eyJ/, 'must be a JWT (expected to start with eyJ)'),
});

const SupabaseErrorSchema = z.object({
  message: z.string(),
  code: z.string().optional(),
});

const OrgRowSchema = z.array(z.object({ id: z.string().uuid() })).min(1);

// ---------------------------------------------------------------------------
// Price → plan mapping
// ---------------------------------------------------------------------------

/** Map Stripe price IDs to internal plan keys. Update when prices change. */
const PRICE_TO_PLAN: Record<string, PlanKey> = {
  // Replace with your actual Stripe price IDs
  price_growth_monthly: 'growth',
  price_growth_annual: 'growth',
  price_enterprise_monthly: 'enterprise',
  price_enterprise_annual: 'enterprise',
};

function mapPriceToTier(priceId: string | undefined): PlanKey {
  if (!priceId) return 'free';
  return PRICE_TO_PLAN[priceId] ?? 'free';
}

function mapStripeStatusToBillingStatus(status: Stripe.Subscription.Status): BillingStatus {
  switch (status) {
    case 'active':
    case 'trialing':
      return 'active';
    case 'past_due':
      return 'past_due';
    case 'canceled':
    case 'unpaid':
    case 'incomplete_expired':
      return 'canceled';
    default:
      return 'inactive';
  }
}

// ---------------------------------------------------------------------------
// Supabase HTTP client (minimal — avoids SDK dependency in scripts)
// ---------------------------------------------------------------------------

/** Parse response body safely, returning undefined if JSON is malformed. */
async function parseJsonSafe(resp: Response): Promise<unknown> {
  try {
    return await resp.json();
  } catch {
    return undefined;
  }
}

function supabaseHeaders(serviceRoleKey: string): Record<string, string> {
  return {
    'apikey': serviceRoleKey,
    'Authorization': `Bearer ${serviceRoleKey}`,
  };
}

async function supabaseUpsert(
  supabaseUrl: string,
  serviceRoleKey: string,
  table: string,
  record: Record<string, unknown>,
  onConflict: string,
  dryRun: boolean,
): Promise<DbResult> {
  if (dryRun) return { ok: true };

  const resp = await fetch(
    `${supabaseUrl}/rest/v1/${table}?on_conflict=${encodeURIComponent(onConflict)}`,
    {
      method: 'POST',
      headers: {
        ...supabaseHeaders(serviceRoleKey),
        'Content-Type': 'application/json',
        'Prefer': 'resolution=merge-duplicates,return=minimal',
      },
      body: JSON.stringify(record),
    },
  );

  if (!resp.ok) {
    const body = await parseJsonSafe(resp);
    const parseResult = SupabaseErrorSchema.safeParse(body);
    const message = parseResult.success
      ? parseResult.data.message
      : `HTTP ${resp.status}: ${JSON.stringify(body)}`;
    return { ok: false, error: message };
  }

  return { ok: true };
}

async function supabaseDelete(
  supabaseUrl: string,
  serviceRoleKey: string,
  table: string,
  filter: string,
  dryRun: boolean,
): Promise<DbResult> {
  if (dryRun) return { ok: true };

  const resp = await fetch(`${supabaseUrl}/rest/v1/${table}?${filter}`, {
    method: 'DELETE',
    headers: supabaseHeaders(serviceRoleKey),
  });

  if (!resp.ok) {
    const body = await parseJsonSafe(resp);
    const parseResult = SupabaseErrorSchema.safeParse(body);
    const message = parseResult.success
      ? parseResult.data.message
      : `HTTP ${resp.status}: ${JSON.stringify(body)}`;
    return { ok: false, error: message };
  }

  return { ok: true };
}

async function supabaseLookupOrgId(
  supabaseUrl: string,
  serviceRoleKey: string,
  stripeCustomerId: string,
): Promise<{ orgId: string } | { error: string }> {
  const resp = await fetch(
    `${supabaseUrl}/rest/v1/organizations?stripe_customer_id=eq.${encodeURIComponent(stripeCustomerId)}&select=id`,
    { method: 'GET', headers: supabaseHeaders(serviceRoleKey) },
  );

  if (!resp.ok) {
    const body = await parseJsonSafe(resp);
    const parseResult = SupabaseErrorSchema.safeParse(body);
    const message = parseResult.success
      ? parseResult.data.message
      : `HTTP ${resp.status}: ${JSON.stringify(body)}`;
    return { error: message };
  }

  const body = await parseJsonSafe(resp);
  const orgsResult = OrgRowSchema.safeParse(body);
  if (!orgsResult.success) {
    return { error: `Unexpected org lookup response: ${orgsResult.error.flatten().formErrors[0] ?? JSON.stringify(body)}` };
  }

  return { orgId: orgsResult.data[0].id };
}

// ---------------------------------------------------------------------------
// Entitlement provisioning
// ---------------------------------------------------------------------------

/** Default entitlements per plan. Extend when features are added. */
const PLAN_ENTITLEMENTS: Record<PlanKey, Array<{ feature_key: string; enabled: boolean; hard_limit: number | null; soft_limit: number | null }>> = {
  free: [
    { feature_key: 'api_requests', enabled: true, hard_limit: 10_000, soft_limit: 8_000 },
    { feature_key: 'team_members', enabled: true, hard_limit: 3, soft_limit: null },
    { feature_key: 'custom_dashboards', enabled: false, hard_limit: 0, soft_limit: null },
    { feature_key: 'data_retention_days', enabled: true, hard_limit: 30, soft_limit: null },
  ],
  growth: [
    { feature_key: 'api_requests', enabled: true, hard_limit: 500_000, soft_limit: 400_000 },
    { feature_key: 'team_members', enabled: true, hard_limit: 25, soft_limit: null },
    { feature_key: 'custom_dashboards', enabled: true, hard_limit: 10, soft_limit: null },
    { feature_key: 'data_retention_days', enabled: true, hard_limit: 365, soft_limit: null },
  ],
  enterprise: [
    { feature_key: 'api_requests', enabled: true, hard_limit: null, soft_limit: null },
    { feature_key: 'team_members', enabled: true, hard_limit: null, soft_limit: null },
    { feature_key: 'custom_dashboards', enabled: true, hard_limit: null, soft_limit: null },
    { feature_key: 'data_retention_days', enabled: true, hard_limit: null, soft_limit: null },
  ],
};

async function provisionEntitlements(
  supabaseUrl: string,
  serviceRoleKey: string,
  orgId: string,
  tier: PlanKey,
  dryRun: boolean,
): Promise<DbResult> {
  if (dryRun) {
    console.log(`  [dry-run] Would rebuild entitlements for org ${orgId} (tier=${tier})`);
    return { ok: true };
  }

  // Clear existing entitlements for this org and re-insert from plan definition
  const deleteResult = await supabaseDelete(
    supabaseUrl, serviceRoleKey,
    'entitlements',
    `organization_id=eq.${encodeURIComponent(orgId)}`,
    dryRun,
  );
  if (!deleteResult.ok) return deleteResult;

  const entitlements = PLAN_ENTITLEMENTS[tier] ?? PLAN_ENTITLEMENTS.free;
  for (const ent of entitlements) {
    const upsertResult = await supabaseUpsert(
      supabaseUrl, serviceRoleKey,
      'entitlements',
      { organization_id: orgId, ...ent },
      'organization_id,feature_key',
      dryRun,
    );
    if (!upsertResult.ok) return upsertResult;
  }

  return { ok: true };
}

// ---------------------------------------------------------------------------
// Per-customer processing
// ---------------------------------------------------------------------------

type CustomerProcessResult =
  | { ok: false; error: string }
  | { ok: true; subscriptions: Array<{ stripeCustomerId: string; tier: PlanKey }> };

async function processCustomer(
  supabaseUrl: string,
  serviceRoleKey: string,
  customer: Stripe.Customer,
  dryRun: boolean,
): Promise<CustomerProcessResult> {
  const now = new Date().toISOString();

  const orgRecord = {
    stripe_customer_id: customer.id,
    name: customer.name ?? customer.email ?? customer.id,
    email: customer.email,
    updated_at: now,
  };

  const orgResult = await supabaseUpsert(
    supabaseUrl, serviceRoleKey,
    'organizations', orgRecord,
    'stripe_customer_id', dryRun,
  );

  if (!orgResult.ok) {
    return { ok: false, error: `Org upsert failed for ${customer.id}: ${orgResult.error}` };
  }

  if (dryRun) {
    console.log(`  [dry-run] Would upsert org for customer ${customer.id} (${customer.email})`);
  }

  // The Stripe SDK requires a cast to access expanded `subscriptions` — guard
  // the shape at runtime so a SDK update that changes the structure fails fast.
  const expandedSubs = (customer as Stripe.Customer & { subscriptions?: Stripe.ApiList<Stripe.Subscription> }).subscriptions?.data;
  if (expandedSubs !== undefined && !Array.isArray(expandedSubs)) {
    throw new Error(`Unexpected subscriptions shape for customer ${customer.id}: expected array`);
  }
  const subs = expandedSubs ?? [];

  const entitlementTargets: Array<{ stripeCustomerId: string; tier: PlanKey }> = [];

  for (const sub of subs) {
    const tier = mapPriceToTier(sub.items.data[0]?.price.id);
    const billingStatus = mapStripeStatusToBillingStatus(sub.status);

    const subRecord = {
      stripe_subscription_id: sub.id,
      stripe_customer_id: customer.id,
      stripe_price_id: sub.items.data[0]?.price.id ?? '',
      status: sub.status,
      tier,
      billing_status: billingStatus,
      current_period_start: new Date(sub.current_period_start * 1000).toISOString(),
      current_period_end: new Date(sub.current_period_end * 1000).toISOString(),
      cancel_at_period_end: sub.cancel_at_period_end,
      updated_at: now,
    };

    const subResult = await supabaseUpsert(
      supabaseUrl, serviceRoleKey,
      'subscriptions', subRecord,
      'stripe_subscription_id', dryRun,
    );

    if (!subResult.ok) {
      return { ok: false, error: `Sub upsert failed for ${sub.id}: ${subResult.error}` };
    }

    if (dryRun) {
      console.log(`  [dry-run] Would upsert subscription ${sub.id} (tier=${tier}, status=${sub.status})`);
    }

    entitlementTargets.push({ stripeCustomerId: customer.id, tier });
  }

  return { ok: true, subscriptions: entitlementTargets };
}

// ---------------------------------------------------------------------------
// Main reconciliation
// ---------------------------------------------------------------------------

async function runFullReconciliation(dryRun: boolean): Promise<ReconciliationSummary> {
  const envResult = EnvSchema.safeParse(process.env);
  if (!envResult.success) {
    const issues = envResult.error.issues.map((i) => `${i.path.join('.')}: ${i.message}`).join('; ');
    throw new Error(`Invalid environment: ${issues}`);
  }

  const { STRIPE_SECRET_KEY: stripeKey, SUPABASE_URL: supabaseUrl, SUPABASE_SERVICE_ROLE_KEY: serviceRoleKey } = envResult.data;

  const stripe = new Stripe(stripeKey, { apiVersion: '2025-02-24.acacia' });

  const summary: ReconciliationSummary = {
    customersProcessed: 0,
    orgsUpserted: 0,
    subscriptionsUpserted: 0,
    orgEntitlementsRebuilt: 0,
    errors: [],
  };

  console.log(`[reconciliation] Starting full reconciliation${dryRun ? ' (DRY RUN — no changes will be written)' : ''}...`);

  const entitlementsToRebuild: Array<{ stripeCustomerId: string; tier: PlanKey }> = [];

  // Phase 1: page through all Stripe customers; upsert orgs + subscriptions
  let hasMore = true;
  let startingAfter: string | undefined;

  while (hasMore) {
    const page = await stripe.customers.list({
      limit: 100,
      starting_after: startingAfter,
      expand: ['data.subscriptions'],
    });

    for (const customer of page.data) {
      summary.customersProcessed++;

      try {
        const result = await processCustomer(supabaseUrl, serviceRoleKey, customer, dryRun);
        if (!result.ok) {
          summary.errors.push(`Error processing customer ${customer.id}: ${result.error}`);
          continue;
        }

        summary.orgsUpserted++;
        summary.subscriptionsUpserted += result.subscriptions.length;
        entitlementsToRebuild.push(...result.subscriptions);
      } catch (err) {
        const message = err instanceof Error ? err.message : String(err);
        summary.errors.push(`Error processing customer ${customer.id}: ${message}`);
      }
    }

    hasMore = page.has_more;
    startingAfter = page.data[page.data.length - 1]?.id;
  }

  // Phase 2: rebuild entitlements (requires org UUID lookup by stripe_customer_id)
  if (entitlementsToRebuild.length > 0) {
    console.log(`[reconciliation] Phase 2: rebuilding entitlements for ${entitlementsToRebuild.length} org(s)...`);

    for (const { stripeCustomerId, tier } of entitlementsToRebuild) {
      try {
        const lookup = await supabaseLookupOrgId(supabaseUrl, serviceRoleKey, stripeCustomerId);
        if ('error' in lookup) {
          summary.errors.push(`Failed to lookup org for ${stripeCustomerId}: ${lookup.error}`);
          continue;
        }

        const entResult = await provisionEntitlements(supabaseUrl, serviceRoleKey, lookup.orgId, tier, dryRun);
        if (!entResult.ok) {
          summary.errors.push(`Entitlement rebuild failed for org ${lookup.orgId}: ${entResult.error}`);
          continue;
        }

        summary.orgEntitlementsRebuilt++;
      } catch (err) {
        const message = err instanceof Error ? err.message : String(err);
        summary.errors.push(`Error rebuilding entitlements for ${stripeCustomerId}: ${message}`);
      }
    }
  }

  return summary;
}

// ---------------------------------------------------------------------------
// Entry point
// ---------------------------------------------------------------------------

const dryRun = process.argv.includes('--dry-run');

runFullReconciliation(dryRun)
  .then((summary) => {
    console.log('\n[reconciliation] Complete:');
    console.log(`  Customers processed:            ${summary.customersProcessed}`);
    console.log(`  Organizations upserted:         ${summary.orgsUpserted}`);
    console.log(`  Subscriptions upserted:         ${summary.subscriptionsUpserted}`);
    console.log(`  Orgs with entitlements rebuilt: ${summary.orgEntitlementsRebuilt}`);
    if (summary.errors.length > 0) {
      console.error(`  Errors (${summary.errors.length}):`);
      for (const err of summary.errors) {
        console.error(`    - ${err}`);
      }
      process.exit(1);
    }
  })
  .catch((err) => {
    console.error('[reconciliation] Fatal error:', err);
    process.exit(1);
  });
