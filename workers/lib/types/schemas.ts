import { z } from 'zod';

export const OrgRoleSchema = z.enum(['owner', 'admin', 'member', 'billing_admin', 'viewer']);

export const BillingStatusSchema = z.enum(['inactive', 'active', 'past_due', 'canceled']);

export const PlanKeySchema = z.enum(['free', 'growth', 'enterprise']);

export const OrgMembershipStatusSchema = z.enum(['active', 'invited', 'suspended']);

export const OrganizationSchema = z.object({
  id: z.string(),
  slug: z.string(),
  name: z.string(),
  billing_status: BillingStatusSchema,
  current_plan: PlanKeySchema,
  quota_version: z.number(),
});

export const OrgMembershipSchema = z.object({
  organization_id: z.string(),
  user_id: z.string(),
  role: OrgRoleSchema,
  status: OrgMembershipStatusSchema,
});

export const EntitlementSchema = z.object({
  organization_id: z.string(),
  feature_key: z.string(),
  enabled: z.boolean(),
  hard_limit: z.number().nullable(),
  soft_limit: z.number().nullable(),
});

export const BootstrapResponseSchema = z.object({
  user: z.object({
    id: z.string(),
    email: z.string(),
  }),
  organizations: z.array(OrganizationSchema.extend({ role: OrgRoleSchema })),
  active_org_id: z.string(),
  entitlements: z.record(z.union([z.boolean(), z.number(), z.null()])),
  usage_snapshot: z.object({
    month_to_date_units: z.number(),
    current_minute_remaining: z.number().nullable(),
  }),
});

export const StripeEventSchema = z.object({
  id: z.string(),
  type: z.string(),
  created: z.number(),
  data: z.object({
    object: z.record(z.unknown()),
    previous_attributes: z.record(z.unknown()).optional(),
  }),
});
