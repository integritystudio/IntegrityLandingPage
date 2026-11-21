import { z } from 'zod';
import type { SupabaseAdmin } from '../supabase';

const OrgIdSchema = z.string().uuid();

export type ResolvedOrg = { ok: true; orgId: string } | { ok: false; error: string };

/**
 * The org a Stripe customer belongs to. An unlinked customer is linked here when the
 * event names its org in `metadata.org_id` (both checkout paths copy it onto the
 * subscription), which covers a subscription created outside Checkout and an event that
 * arrives before `checkout.session.completed`.
 *
 * A failure is retryable: the caller dead-letters the event, and the link may exist by
 * the next attempt.
 */
export async function resolveOrgId(
  customerId: string,
  db: SupabaseAdmin,
  metadataOrgId?: string | null,
): Promise<ResolvedOrg> {
  const findResult = await db.findOrgByStripeCustomerId(customerId);
  if (!findResult.ok) {
    return { ok: false, error: `Failed to find org: ${findResult.error}` };
  }
  if (findResult.orgId) return { ok: true, orgId: findResult.orgId };

  const noOrg = `No org found for Stripe customer ${customerId}`;
  if (!metadataOrgId) return { ok: false, error: noOrg };
  if (!OrgIdSchema.safeParse(metadataOrgId).success) {
    return { ok: false, error: `${noOrg}: metadata.org_id is not a UUID` };
  }

  const linkResult = await db.linkStripeCustomerIfUnlinked(metadataOrgId, customerId);
  if (!linkResult.ok) {
    return { ok: false, error: `Failed to link Stripe customer: ${linkResult.error}` };
  }
  if (!linkResult.linked) {
    return { ok: false, error: `${noOrg}: org ${metadataOrgId} from metadata.org_id is missing or linked to another customer` };
  }
  return { ok: true, orgId: metadataOrgId };
}
