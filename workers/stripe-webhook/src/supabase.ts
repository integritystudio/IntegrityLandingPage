import { createSupabaseClient } from '../../lib/supabase';
import type { BillingStatus, PlanKey } from '../../lib/types';

type OkVoid = { ok: true };
type Err = { ok: false; error: string };
type VoidResult = OkVoid | Err;

function toVoidResult(result: { ok: boolean; error?: string }): VoidResult {
  return result.ok ? { ok: true } : { ok: false, error: result.error ?? 'Unknown error' };
}

export function createSupabaseAdmin(supabaseUrl: string, serviceRoleKey: string) {
  const sb = createSupabaseClient(supabaseUrl, serviceRoleKey);

  /**
   * Link Stripe customer to organization.
   */
  async function linkStripeCustomer(orgId: string, stripeCustomerId: string): Promise<VoidResult> {
    const result = await sb.update(
      'organizations',
      { stripe_customer_id: stripeCustomerId },
      [{ column: 'id', operator: 'eq', value: orgId }],
    );
    return toVoidResult(result);
  }

  /**
   * Create or update subscription.
   */
  async function upsertSubscription(
    orgId: string,
    stripeSubscriptionId: string,
    stripePriceId: string,
    status: string,
  ): Promise<VoidResult> {
    const queryResult = await sb.query('subscriptions', {
      filters: [
        { column: 'organization_id', operator: 'eq', value: orgId },
        { column: 'stripe_subscription_id', operator: 'eq', value: stripeSubscriptionId },
      ],
      single: true,
    });

    if (!queryResult.ok) {
      return { ok: false, error: queryResult.error };
    }

    if (queryResult.data) {
      const result = await sb.update(
        'subscriptions',
        { stripe_price_id: stripePriceId, status, updated_at: new Date().toISOString() },
        [{ column: 'stripe_subscription_id', operator: 'eq', value: stripeSubscriptionId }],
      );
      return toVoidResult(result);
    }

    const result = await sb.insert('subscriptions', {
      organization_id: orgId,
      stripe_subscription_id: stripeSubscriptionId,
      stripe_price_id: stripePriceId,
      status,
      created_at: new Date().toISOString(),
      updated_at: new Date().toISOString(),
    });
    return toVoidResult(result);
  }

  /**
   * Update org billing status and plan.
   */
  async function updateOrgBillingStatus(
    orgId: string,
    billingStatus: BillingStatus,
    planKey?: PlanKey,
    bumpQuotaVersion?: boolean,
  ): Promise<VoidResult> {
    const updates: Record<string, unknown> = { billing_status: billingStatus };

    if (planKey) {
      updates.current_plan = planKey;
    }

    if (bumpQuotaVersion) {
      updates.quota_version = null;
    }

    const result = await sb.update(
      'organizations',
      updates,
      [{ column: 'id', operator: 'eq', value: orgId }],
    );
    return toVoidResult(result);
  }

  /**
   * Find organization by Stripe customer ID.
   */
  async function findOrgByStripeCustomerId(
    stripeCustomerId: string,
  ): Promise<{ ok: true; orgId: string | null } | Err> {
    const result = await sb.query('organizations', {
      select: 'id',
      filters: [{ column: 'stripe_customer_id', operator: 'eq', value: stripeCustomerId }],
      limit: 1,
      single: true,
    });

    if (!result.ok) {
      return { ok: false, error: result.error };
    }

    const org = result.data as { id: string } | null;
    return { ok: true, orgId: org?.id ?? null };
  }

  return {
    linkStripeCustomer,
    upsertSubscription,
    updateOrgBillingStatus,
    findOrgByStripeCustomerId,
  };
}

export type SupabaseAdmin = ReturnType<typeof createSupabaseAdmin>;
