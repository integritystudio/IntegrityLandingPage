import { describe, it, expect, vi } from 'vitest';
import { resolveOrgId } from './resolve-org';
import type { SupabaseAdmin } from '../supabase';

const ORG_ID = '550e8400-e29b-41d4-a716-446655440000';
const CUSTOMER_ID = 'cus_1';

type OrgLookups = Pick<SupabaseAdmin, 'findOrgByStripeCustomerId' | 'linkStripeCustomerIfUnlinked'>;

function makeDb(overrides: Partial<OrgLookups> = {}): SupabaseAdmin {
  const lookups: OrgLookups = {
    findOrgByStripeCustomerId: vi.fn().mockResolvedValue({ ok: true, orgId: null }),
    linkStripeCustomerIfUnlinked: vi.fn().mockResolvedValue({ ok: true, linked: true }),
    ...overrides,
  };
  return lookups as SupabaseAdmin;
}

describe('resolveOrgId', () => {
  it('returns the linked org without touching the link', async () => {
    const db = makeDb({ findOrgByStripeCustomerId: vi.fn().mockResolvedValue({ ok: true, orgId: 'org-linked' }) });

    expect(await resolveOrgId(CUSTOMER_ID, db, ORG_ID)).toEqual({ ok: true, orgId: 'org-linked' });
    expect(db.linkStripeCustomerIfUnlinked).not.toHaveBeenCalled();
  });

  it('links an unlinked customer to the org its metadata names', async () => {
    const db = makeDb();

    expect(await resolveOrgId(CUSTOMER_ID, db, ORG_ID)).toEqual({ ok: true, orgId: ORG_ID });
    expect(db.linkStripeCustomerIfUnlinked).toHaveBeenCalledWith(ORG_ID, CUSTOMER_ID);
  });

  it.each([undefined, null, ''])('fails without linking when metadata names no org (%s)', async (metadataOrgId) => {
    const db = makeDb();

    expect(await resolveOrgId(CUSTOMER_ID, db, metadataOrgId)).toEqual({ ok: false, error: `No org found for Stripe customer ${CUSTOMER_ID}` });
    expect(db.linkStripeCustomerIfUnlinked).not.toHaveBeenCalled();
  });

  it('refuses a metadata org id that is not a UUID before it reaches a query', async () => {
    const db = makeDb();

    const result = await resolveOrgId(CUSTOMER_ID, db, 'x&id=neq.y');

    expect(result).toEqual({ ok: false, error: `No org found for Stripe customer ${CUSTOMER_ID}: metadata.org_id is not a UUID` });
    expect(db.linkStripeCustomerIfUnlinked).not.toHaveBeenCalled();
  });

  it('fails when the named org is missing or already linked to another customer', async () => {
    const db = makeDb({ linkStripeCustomerIfUnlinked: vi.fn().mockResolvedValue({ ok: true, linked: false }) });

    expect(await resolveOrgId(CUSTOMER_ID, db, ORG_ID)).toEqual({
      ok: false,
      error: `No org found for Stripe customer ${CUSTOMER_ID}: org ${ORG_ID} from metadata.org_id is missing or linked to another customer`,
    });
  });

  it('propagates a lookup failure', async () => {
    const db = makeDb({ findOrgByStripeCustomerId: vi.fn().mockResolvedValue({ ok: false, error: 'HTTP 500: timeout' }) });

    expect(await resolveOrgId(CUSTOMER_ID, db, ORG_ID)).toEqual({ ok: false, error: 'Failed to find org: HTTP 500: timeout' });
  });

  it('propagates a link failure', async () => {
    const db = makeDb({ linkStripeCustomerIfUnlinked: vi.fn().mockResolvedValue({ ok: false, error: 'HTTP 500: timeout' }) });

    expect(await resolveOrgId(CUSTOMER_ID, db, ORG_ID)).toEqual({ ok: false, error: 'Failed to link Stripe customer: HTTP 500: timeout' });
  });
});
