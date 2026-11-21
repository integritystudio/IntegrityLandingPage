/**
 * Full Reconciliation Script — T24
 *
 * "Nuclear option": rebuilds local billing state from Stripe when the database
 * is out of sync after an extended outage, data corruption, or backup restore.
 *
 * WARNING: Do NOT run concurrently with production traffic. `provisionEntitlements`
 * deletes all org entitlements then re-inserts — if the script crashes between
 * the delete and the insert, the org is left with zero entitlements. Run during
 * a maintenance window or against a quiesced environment only.
 *
 * Stripe is the source of truth for billing state. This script:
 *   1. Pages through all Stripe customers (with expanded subscriptions)
 *   2. Matches each customer to its organization and upserts its subscriptions
 *   3. Rebuilds entitlements from the current subscription tier
 *   4. Supports --dry-run mode to preview changes before applying
 *
 * Usage:
 *   npx ts-node scripts/full-reconciliation.ts [--dry-run]
 *
 * Required env vars:
 *   STRIPE_SECRET_KEY      — Stripe secret or restricted key
 *   SUPABASE_URL           — Supabase project URL
 *   SUPABASE_SERVICE_ROLE_KEY — Supabase service-role or secret key
 *
 * Optional:
 *   SENTRY_OBTOOL_DASHBOARD_DSN — reports each failure and any fatal error to the
 *                            `integritystudio-ai` Sentry project, the one the provisioning
 *                            receiver and sender-worker use; Doppler supplies it
 *
 * See: docs/security/DISASTER_RECOVERY_PLAN.md (Scenario E)
 */

import * as Sentry from '@sentry/node';
import Stripe from 'stripe';
import { z } from 'zod';
import { pathToFileURL } from 'node:url';

// ---------------------------------------------------------------------------
// Types
// ---------------------------------------------------------------------------

const PlanKeySchema = z.enum(['starter', 'growth', 'enterprise']);
type PlanKey = z.infer<typeof PlanKeySchema>;
/** Stripe price id → plan key, loaded from the `plans` table at startup. */
type PriceToPlan = Readonly<Record<string, PlanKey>>;
type ReconciliationPhase = 'customers' | 'entitlements';
/** What failed; with the phase, it is the Sentry grouping key. */
type ErrorKind =
  | 'org-lookup'
  | 'unlinked-customer'
  | 'customer-link'
  | 'subscription-upsert'
  | 'subscription-row-lookup'
  | 'org-update'
  | 'unmapped-price'
  | 'entitlement-rebuild'
  | 'unexpected';
type ReconciliationError = { kind: ErrorKind; error: string };

/** The plan an unmapped or missing price falls back to. */
const DEFAULT_PLAN: PlanKey = 'starter';

interface ReconciliationSummary {
  customersProcessed: number;
  orgsMatched: number;
  customersLinked: number;
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

const REQUIRED_MESSAGE = 'is required';

/** Presence only: key formats change (rk_, sb_secret_), and a bad key fails the first request anyway. */
export const EnvSchema = z.object({
  STRIPE_SECRET_KEY: z.string().min(1, REQUIRED_MESSAGE),
  SUPABASE_URL: z.string().url(),
  SUPABASE_SERVICE_ROLE_KEY: z.string().min(1, REQUIRED_MESSAGE),
});

const SupabaseErrorSchema = z.object({
  message: z.string(),
  code: z.string().optional(),
});

const OrgMatchRowsSchema = z.array(z.object({ id: z.string().uuid(), stripe_customer_id: z.string().nullable() }));
type OrgMatch = z.infer<typeof OrgMatchRowsSchema>[number];

/** Both checkout paths copy the org id here; it outlives the 24h checkout session. */
const SubscriptionOrgIdSchema = z.string().uuid();

const SentryDsnSchema = z.string().url();

const SubscriptionRowsSchema = z.array(z.object({ id: z.string().uuid() }));

const PlanRowsSchema = z.array(z.object({ key: PlanKeySchema, stripe_price_id: z.string().nullable() }));

// ---------------------------------------------------------------------------
// Stripe statuses
// ---------------------------------------------------------------------------

/** Stripe's subscription statuses, which `organizations.billing_status` stores unchanged. */
const STRIPE_SUBSCRIPTION_STATUSES: ReadonlySet<string> = new Set([
  'incomplete', 'incomplete_expired', 'trialing', 'active', 'past_due', 'canceled', 'unpaid', 'paused',
]);
const CANCELED_STATUS = 'canceled';
/** Our own value for "no Stripe subscription exists"; also the safe fallback, since it grants nothing. */
const NO_SUBSCRIPTION_STATUS = 'inactive';

/**
 * A Stripe status as our `billing_status`: a pass-through, never a mapping, so a trial or
 * an unpaid subscription stays what Stripe says it is. Mirrors workers/lib/billing.ts,
 * which this script cannot import; the tests pin the two.
 */
export function toBillingStatus(stripeStatus: string): string {
  if (STRIPE_SUBSCRIPTION_STATUSES.has(stripeStatus)) return stripeStatus;
  console.warn(`[reconciliation] Unrecognized Stripe subscription status '${stripeStatus}'; storing '${NO_SUBSCRIPTION_STATUS}'`);
  return NO_SUBSCRIPTION_STATUS;
}

/**
 * Whether Stripe can never move the subscription out of this status, so the org stops
 * pointing at it. Unpaid, past-due and paused subscriptions are still the org's own.
 * Mirrors workers/lib/billing.ts, which this script cannot import; the tests pin the two.
 */
export function isTerminalSubscriptionStatus(status: string): boolean {
  return status === CANCELED_STATUS || status === 'incomplete_expired';
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

/** Supabase's error message, or the status and raw body when the response is not its error shape. */
function supabaseErrorMessage(resp: Response, body: unknown): string {
  const parsed = SupabaseErrorSchema.safeParse(body);
  return parsed.success ? parsed.data.message : `HTTP ${resp.status}: ${JSON.stringify(body)}`;
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

  if (!resp.ok) return { ok: false, error: supabaseErrorMessage(resp, await parseJsonSafe(resp)) };

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

  if (!resp.ok) return { ok: false, error: supabaseErrorMessage(resp, await parseJsonSafe(resp)) };

  return { ok: true };
}

async function supabaseUpdate(
  supabaseUrl: string,
  serviceRoleKey: string,
  table: string,
  updates: Record<string, unknown>,
  filter: string,
  dryRun: boolean,
): Promise<DbResult> {
  if (dryRun) return { ok: true };

  const resp = await fetch(`${supabaseUrl}/rest/v1/${table}?${filter}`, {
    method: 'PATCH',
    headers: {
      ...supabaseHeaders(serviceRoleKey),
      'Content-Type': 'application/json',
      'Prefer': 'return=minimal',
    },
    body: JSON.stringify(updates),
  });

  if (!resp.ok) return { ok: false, error: supabaseErrorMessage(resp, await parseJsonSafe(resp)) };

  return { ok: true };
}

/** GET rows from `pathAndQuery` and validate their shape. */
async function supabaseSelect<Row>(
  supabaseUrl: string,
  serviceRoleKey: string,
  pathAndQuery: string,
  rowsSchema: z.ZodType<Row[]>,
): Promise<{ rows: Row[] } | { error: string }> {
  const resp = await fetch(`${supabaseUrl}/rest/v1/${pathAndQuery}`, { method: 'GET', headers: supabaseHeaders(serviceRoleKey) });
  const body = await parseJsonSafe(resp);
  if (!resp.ok) return { error: supabaseErrorMessage(resp, body) };

  const rowsResult = rowsSchema.safeParse(body);
  if (!rowsResult.success) {
    return { error: `unexpected response shape: ${rowsResult.error.issues.map((i) => i.message).join('; ')}` };
  }
  return { rows: rowsResult.data };
}

/**
 * Read the price → plan mapping from `plans`, the table api-gateway's checkout prices from.
 * Throws rather than run on an empty or unreadable table, where every price would
 * fall back to the default plan.
 */
async function loadPriceToPlan(supabaseUrl: string, serviceRoleKey: string): Promise<PriceToPlan> {
  const plans = await supabaseSelect(supabaseUrl, serviceRoleKey, 'plans?select=key,stripe_price_id', PlanRowsSchema);
  if ('error' in plans) throw new Error(`Failed to read plans: ${plans.error}`);

  const priceToPlan: Record<string, PlanKey> = {};
  for (const { key, stripe_price_id: priceId } of plans.rows) {
    if (priceId) priceToPlan[priceId] = key;
  }
  if (Object.keys(priceToPlan).length === 0) {
    throw new Error(`plans table has no stripe_price_id; refusing to map every price to ${DEFAULT_PLAN}`);
  }
  return priceToPlan;
}

/** The org matching `filter`, or null when none does. Both filters used are on unique columns. */
async function supabaseFindOrg(
  supabaseUrl: string,
  serviceRoleKey: string,
  filter: string,
): Promise<{ org: OrgMatch | null } | { error: string }> {
  const orgs = await supabaseSelect(supabaseUrl, serviceRoleKey, `organizations?${filter}&select=id,stripe_customer_id&limit=1`, OrgMatchRowsSchema);
  if ('error' in orgs) return orgs;
  return { org: orgs.rows[0] ?? null };
}

// ---------------------------------------------------------------------------
// Entitlement provisioning
// ---------------------------------------------------------------------------

/** Default entitlements per plan. Extend when features are added. */
const PLAN_ENTITLEMENTS: Record<PlanKey, Array<{ feature_key: string; enabled: boolean; hard_limit: number | null; soft_limit: number | null }>> = {
  starter: [
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

  // Non-atomic: deletes all entitlements then re-inserts from plan definition.
  // A crash between delete and insert leaves the org with zero entitlements.
  // See script-level WARNING — run during a maintenance window only.
  const deleteResult = await supabaseDelete(
    supabaseUrl, serviceRoleKey,
    'entitlements',
    `organization_id=eq.${encodeURIComponent(orgId)}`,
    dryRun,
  );
  if (!deleteResult.ok) return deleteResult;

  const entitlements = PLAN_ENTITLEMENTS[tier] ?? PLAN_ENTITLEMENTS[DEFAULT_PLAN];
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

type EntitlementTarget = { orgId: string; tier: PlanKey };

type CustomerProcessResult =
  | ({ ok: false } & ReconciliationError)
  /** `issues` are reported without stopping the customer: its writes still happened. */
  | { ok: true; linked: boolean; targets: EntitlementTarget[]; issues: ReconciliationError[] };

/** The one org a customer's subscriptions name in `metadata.org_id`, or why there is none. */
export function orgIdFromSubscriptionMetadata(
  subs: ReadonlyArray<Pick<Stripe.Subscription, 'metadata'>>,
): { orgId: string } | { reason: string } {
  const named = [...new Set(subs.map((sub) => sub.metadata?.org_id).filter((id): id is string => Boolean(id)))];
  if (named.length === 0) return { reason: 'no subscription carries metadata.org_id' };
  if (named.length > 1) return { reason: `subscriptions name ${named.length} different orgs: ${named.join(', ')}` };
  if (!SubscriptionOrgIdSchema.safeParse(named[0]).success) return { reason: `metadata.org_id is not a UUID: ${named[0]}` };
  return { orgId: named[0] };
}

/**
 * Whether to link a customer to the org its subscription metadata names. Never
 * overwrites another customer id: that orphans the org's original subscription,
 * which keeps billing with no org row reaching it (api-gateway refuses the same).
 */
export function linkDecision(
  customerId: string,
  metadataOrgId: string,
  org: OrgMatch | null,
): { link: true; orgId: string } | { link: false; reason: string } {
  if (!org) return { link: false, reason: `metadata.org_id ${metadataOrgId} matches no org` };
  if (org.stripe_customer_id && org.stripe_customer_id !== customerId) {
    return { link: false, reason: `org ${org.id} is already linked to ${org.stripe_customer_id}` };
  }
  return { link: true, orgId: org.id };
}

/**
 * Find the customer's org, linking it from subscription metadata when stripe-webhook
 * could not (a signup checkout whose email resolved to no org). Never creates an org.
 */
async function resolveCustomerOrg(
  supabaseUrl: string,
  serviceRoleKey: string,
  customer: Stripe.Customer,
  subs: readonly Stripe.Subscription[],
  now: string,
  dryRun: boolean,
): Promise<{ orgId: string; linked: boolean } | ReconciliationError> {
  const byCustomer = await supabaseFindOrg(supabaseUrl, serviceRoleKey, `stripe_customer_id=eq.${encodeURIComponent(customer.id)}`);
  if ('error' in byCustomer) return { kind: 'org-lookup', error: `Org lookup failed for ${customer.id}: ${byCustomer.error}` };
  if (byCustomer.org) return { orgId: byCustomer.org.id, linked: false };

  const unlinked = (reason: string) => ({ kind: 'unlinked-customer' as const, error: `Unlinked Stripe customer ${customer.id}: ${reason}` });
  const fromMetadata = orgIdFromSubscriptionMetadata(subs);
  if ('reason' in fromMetadata) return unlinked(fromMetadata.reason);

  const byId = await supabaseFindOrg(supabaseUrl, serviceRoleKey, `id=eq.${encodeURIComponent(fromMetadata.orgId)}`);
  if ('error' in byId) return { kind: 'org-lookup', error: `Org lookup failed for ${fromMetadata.orgId}: ${byId.error}` };
  const decision = linkDecision(customer.id, fromMetadata.orgId, byId.org);
  if (!decision.link) return unlinked(decision.reason);

  // The is.null filter keeps a concurrent stripe-webhook link from being overwritten.
  const linkResult = await supabaseUpdate(
    supabaseUrl, serviceRoleKey,
    'organizations', { stripe_customer_id: customer.id, updated_at: now },
    `id=eq.${encodeURIComponent(decision.orgId)}&stripe_customer_id=is.null`, dryRun,
  );
  if (!linkResult.ok) return { kind: 'customer-link', error: `Linking ${customer.id} to org ${decision.orgId} failed: ${linkResult.error}` };
  console.log(`  ${dryRun ? '[dry-run] Would link' : 'Linked'} customer ${customer.id} to org ${decision.orgId} from subscription metadata`);
  return { orgId: decision.orgId, linked: true };
}

/** The org already linked to a customer, without linking one: a cancellation never links. */
async function findLinkedOrg(
  supabaseUrl: string,
  serviceRoleKey: string,
  customerId: string,
): Promise<{ orgId: string | null; linked: false } | ReconciliationError> {
  const byCustomer = await supabaseFindOrg(supabaseUrl, serviceRoleKey, `stripe_customer_id=eq.${encodeURIComponent(customerId)}`);
  if ('error' in byCustomer) return { kind: 'org-lookup', error: `Org lookup failed for ${customerId}: ${byCustomer.error}` };
  return { orgId: byCustomer.org?.id ?? null, linked: false };
}

/**
 * The value for `organizations.active_subscription_id`: the org's subscription row, or
 * null once the subscription is terminal. A dry run has written no row to point at.
 */
async function activeSubscriptionPointer(
  supabaseUrl: string,
  serviceRoleKey: string,
  orgId: string,
  status: string,
  dryRun: boolean,
): Promise<{ id: string | null } | { error: string }> {
  if (dryRun || isTerminalSubscriptionStatus(status)) return { id: null };

  const subscriptions = await supabaseSelect(
    supabaseUrl, serviceRoleKey,
    `subscriptions?organization_id=eq.${encodeURIComponent(orgId)}&select=id&limit=1`, SubscriptionRowsSchema,
  );
  if ('error' in subscriptions) return subscriptions;
  const row = subscriptions.rows[0];
  return row ? { id: row.id } : { error: `no subscriptions row for org ${orgId} after its upsert` };
}

/**
 * The one subscription written for a customer: the most recently created that Stripe can
 * still change, else the most recently created. `subscriptions` holds one row per org,
 * so writing each in turn would leave whichever Stripe happened to list last.
 */
export function subscriptionToReconcile<Sub extends Pick<Stripe.Subscription, 'status' | 'created'>>(subs: readonly Sub[]): Sub {
  const newestFirst = [...subs].sort((a, b) => b.created - a.created);
  return newestFirst.find((sub) => !isTerminalSubscriptionStatus(sub.status)) ?? newestFirst[0];
}

/**
 * The customer's most recently canceled subscription, or null if it never had one.
 * Stripe leaves canceled subscriptions out of the customer list this script pages through.
 */
export type CanceledSubscriptionLookup = (customerId: string) => Promise<Stripe.Subscription | null>;

export async function processCustomer(
  supabaseUrl: string,
  serviceRoleKey: string,
  customer: Stripe.Customer,
  priceToPlan: PriceToPlan,
  dryRun: boolean,
  latestCanceledSubscription: CanceledSubscriptionLookup = async () => null,
): Promise<CustomerProcessResult> {
  const now = new Date().toISOString();

  // The Stripe SDK requires a cast to access expanded `subscriptions` — guard
  // the shape at runtime so a SDK update that changes the structure fails fast.
  const expandedSubs = (customer as Stripe.Customer & { subscriptions?: Stripe.ApiList<Stripe.Subscription> }).subscriptions?.data;
  if (expandedSubs !== undefined && !Array.isArray(expandedSubs)) {
    throw new Error(`Unexpected subscriptions shape for customer ${customer.id}: expected array`);
  }
  const liveSubs = expandedSubs ?? [];

  const targets: EntitlementTarget[] = [];
  const issues: ReconciliationError[] = [];

  // With no live subscription, the last canceled one decides: stripe-webhook downgrades
  // the org on customer.subscription.deleted, and a missed event leaves it on a paid plan.
  const canceledSub = liveSubs.length === 0 ? await latestCanceledSubscription(customer.id) : null;
  const subs = canceledSub ? [canceledSub] : liveSubs;
  // Never subscribed: nothing billed to reconcile, and no metadata to link from.
  if (subs.length === 0) return { ok: true, linked: false, targets, issues };

  // subscriptions has no customer column: it links to the org by id, one row per org.
  const resolved = canceledSub
    ? await findLinkedOrg(supabaseUrl, serviceRoleKey, customer.id)
    : await resolveCustomerOrg(supabaseUrl, serviceRoleKey, customer, subs, now, dryRun);
  if ('error' in resolved) return { ok: false, ...resolved };
  // A canceled subscription whose customer no org points at has nothing to downgrade.
  if (resolved.orgId === null) return { ok: true, linked: false, targets, issues };
  const { orgId, linked } = resolved;
  const orgFilter = `id=eq.${encodeURIComponent(orgId)}`;

  // One row per org: where a customer has several subscriptions, only the newest is
  // written, as stripe-webhook's latest event overwrites the row.
  const sub = subscriptionToReconcile(subs);
  if (subs.length > 1) {
    console.warn(`  Customer ${customer.id} has ${subs.length} subscriptions; reconciling the newest, ${sub.id}`);
  }
  const priceId = sub.items.data[0]?.price.id;
  // A canceled subscription always downgrades to the default plan, as the webhook does.
  const canceled = sub.status === CANCELED_STATUS;
  const mappedPlan = canceled ? DEFAULT_PLAN : priceId ? priceToPlan[priceId] : undefined;
  const tier = mappedPlan ?? DEFAULT_PLAN;
  if (!mappedPlan) {
    issues.push({
      kind: 'unmapped-price',
      error: `Unmapped Stripe price ${priceId ?? '(none)'} on subscription ${sub.id}: entitlements rebuilt at ${DEFAULT_PLAN}, current_plan left alone`,
    });
  }

  const subRecord = {
    organization_id: orgId,
    stripe_subscription_id: sub.id,
    stripe_price_id: priceId ?? null,
    status: sub.status,
    current_period_start: new Date((sub.items.data[0]?.current_period_start ?? 0) * 1000).toISOString(),
    current_period_end: new Date((sub.items.data[0]?.current_period_end ?? 0) * 1000).toISOString(),
    cancel_at_period_end: sub.cancel_at_period_end,
    updated_at: now,
  };

  const subResult = await supabaseUpsert(
    supabaseUrl, serviceRoleKey,
    'subscriptions', subRecord,
    'organization_id', dryRun,
  );

  if (!subResult.ok) {
    return { ok: false, kind: 'subscription-upsert', error: `Sub upsert failed for ${sub.id}: ${subResult.error}` };
  }

  const pointer = await activeSubscriptionPointer(supabaseUrl, serviceRoleKey, orgId, sub.status, dryRun);
  if ('error' in pointer) {
    return { ok: false, kind: 'subscription-row-lookup', error: `Subscription row lookup failed for ${sub.id}: ${pointer.error}` };
  }

  // Plan, billing status and the subscription pointer live on the org, as stripe-webhook
  // writes them; a new quota_version makes api-gateway re-read the org's limits. An
  // unmapped price leaves current_plan alone rather than downgrading the org.
  const orgUpdates = {
    billing_status: toBillingStatus(sub.status),
    ...(mappedPlan ? { current_plan: mappedPlan } : {}),
    active_subscription_id: pointer.id,
    quota_version: Date.now(),
    updated_at: now,
  };
  const orgUpdateResult = await supabaseUpdate(
    supabaseUrl, serviceRoleKey,
    'organizations', orgUpdates,
    orgFilter, dryRun,
  );

  if (!orgUpdateResult.ok) {
    return { ok: false, kind: 'org-update', error: `Org billing update failed for ${customer.id}: ${orgUpdateResult.error}` };
  }

  if (dryRun) {
    console.log(`  [dry-run] Would upsert subscription ${sub.id} (tier=${tier}, status=${sub.status})`);
  }

  targets.push({ orgId, tier });

  return { ok: true, linked, targets, issues };
}

// ---------------------------------------------------------------------------
// Error reporting (Sentry)
// ---------------------------------------------------------------------------

const SENTRY_FLUSH_TIMEOUT_MS = 5_000;
const SENTRY_SCRIPT_TAG = 'full-reconciliation';
const SENTRY_PHASE_TAG = 'phase';
const SENTRY_KIND_TAG = 'kind';
const SENTRY_FATAL_PHASE = 'fatal';

/** Stripe marks every live-mode key, of any type, this way. */
const STRIPE_LIVE_KEY_MARKER = '_live_';

function isLiveStripeKey(key: string | undefined): boolean {
  return key?.includes(STRIPE_LIVE_KEY_MARKER) ?? false;
}

/**
 * The `integritystudio-ai` project's DSN. Not SENTRY_DSN: in Doppler that name holds an
 * unrelated project's DSN, and `doppler run` would send billing errors there.
 */
const SENTRY_DSN_ENV = 'SENTRY_OBTOOL_DASHBOARD_DSN';

/** Before env validation, so a bad env is reported too. */
function initSentry(dryRun: boolean): void {
  const dsn = process.env[SENTRY_DSN_ENV];
  if (!dsn || !SentryDsnSchema.safeParse(dsn).success) {
    console.warn(`[reconciliation] ${SENTRY_DSN_ENV} ${dsn ? 'is not a URL' : 'unset'}; errors will not be reported to Sentry`);
    return;
  }
  Sentry.init({
    dsn,
    environment: isLiveStripeKey(process.env.STRIPE_SECRET_KEY) ? 'production' : 'test',
    initialScope: { tags: { script: SENTRY_SCRIPT_TAG, dry_run: String(dryRun) } },
  });
}

/** Record a failure in the summary and report it, one Sentry issue per phase and kind. */
export function recordError(
  summary: Pick<ReconciliationSummary, 'errors'>,
  phase: ReconciliationPhase,
  kind: ErrorKind,
  message: string,
  cause?: unknown,
): void {
  summary.errors.push(message);
  Sentry.withScope((scope) => {
    scope.setTag(SENTRY_PHASE_TAG, phase);
    scope.setTag(SENTRY_KIND_TAG, kind);
    scope.setFingerprint([SENTRY_SCRIPT_TAG, phase, kind]);
    scope.setExtra('reconciliation_error', message);
    Sentry.captureException(cause instanceof Error ? cause : new Error(message));
  });
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

  const stripe = new Stripe(stripeKey, { apiVersion: '2026-03-25.dahlia' });
  const priceToPlan = await loadPriceToPlan(supabaseUrl, serviceRoleKey);

  const summary: ReconciliationSummary = {
    customersProcessed: 0,
    orgsMatched: 0,
    customersLinked: 0,
    subscriptionsUpserted: 0,
    orgEntitlementsRebuilt: 0,
    errors: [],
  };

  console.log(`[reconciliation] Starting full reconciliation${dryRun ? ' (DRY RUN — no changes will be written)' : ''}...`);

  // Stripe lists subscriptions newest first.
  const latestCanceledSubscription: CanceledSubscriptionLookup = async (customerId) => {
    const canceled = await stripe.subscriptions.list({ customer: customerId, status: CANCELED_STATUS, limit: 1 });
    return canceled.data[0] ?? null;
  };

  // One rebuild per org: a later subscription's tier replaces an earlier one's.
  const tierByOrg = new Map<string, PlanKey>();

  // Phase 1: page through all Stripe customers; match orgs and upsert subscriptions
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
        const result = await processCustomer(supabaseUrl, serviceRoleKey, customer, priceToPlan, dryRun, latestCanceledSubscription);
        if (!result.ok) {
          recordError(summary, 'customers', result.kind, `Error processing customer ${customer.id}: ${result.error}`);
          continue;
        }

        for (const issue of result.issues) {
          recordError(summary, 'customers', issue.kind, `Customer ${customer.id}: ${issue.error}`);
        }

        if (result.targets.length > 0) summary.orgsMatched++;
        if (result.linked) summary.customersLinked++;
        summary.subscriptionsUpserted += result.targets.length;
        for (const { orgId, tier } of result.targets) tierByOrg.set(orgId, tier);
      } catch (err) {
        const message = err instanceof Error ? err.message : String(err);
        recordError(summary, 'customers', 'unexpected', `Error processing customer ${customer.id}: ${message}`, err);
      }
    }

    hasMore = page.has_more;
    startingAfter = page.data[page.data.length - 1]?.id;
  }

  // Phase 2: rebuild entitlements for the orgs phase 1 resolved
  if (tierByOrg.size > 0) {
    console.log(`[reconciliation] Phase 2: rebuilding entitlements for ${tierByOrg.size} org(s)...`);

    for (const [orgId, tier] of tierByOrg) {
      try {
        const entResult = await provisionEntitlements(supabaseUrl, serviceRoleKey, orgId, tier, dryRun);
        if (!entResult.ok) {
          recordError(summary, 'entitlements', 'entitlement-rebuild', `Entitlement rebuild failed for org ${orgId}: ${entResult.error}`);
          continue;
        }

        summary.orgEntitlementsRebuilt++;
      } catch (err) {
        const message = err instanceof Error ? err.message : String(err);
        recordError(summary, 'entitlements', 'unexpected', `Error rebuilding entitlements for org ${orgId}: ${message}`, err);
      }
    }
  }

  return summary;
}

// ---------------------------------------------------------------------------
// Entry point
// ---------------------------------------------------------------------------

async function main(): Promise<void> {
  const dryRun = process.argv.includes('--dry-run');
  initSentry(dryRun);

  let failed = false;
  try {
    const summary = await runFullReconciliation(dryRun);
    console.log('\n[reconciliation] Complete:');
    console.log(`  Customers processed:            ${summary.customersProcessed}`);
    console.log(`  Organizations matched:          ${summary.orgsMatched}`);
    console.log(`  Customers linked from metadata: ${summary.customersLinked}`);
    console.log(`  Subscriptions upserted:         ${summary.subscriptionsUpserted}`);
    console.log(`  Orgs with entitlements rebuilt: ${summary.orgEntitlementsRebuilt}`);
    if (summary.errors.length > 0) {
      console.error(`  Errors (${summary.errors.length}):`);
      for (const err of summary.errors) {
        console.error(`    - ${err}`);
      }
      failed = true;
    }
  } catch (err) {
    console.error('[reconciliation] Fatal error:', err);
    Sentry.withScope((scope) => {
      scope.setTag(SENTRY_PHASE_TAG, SENTRY_FATAL_PHASE);
      Sentry.captureException(err);
    });
    failed = true;
  }

  // process.exit would drop queued Sentry events.
  await Sentry.flush(SENTRY_FLUSH_TIMEOUT_MS);
  if (failed) process.exit(1);
}

// Run only when executed, so tests can import the exported helpers.
if (process.argv[1] && import.meta.url === pathToFileURL(process.argv[1]).href) void main();
