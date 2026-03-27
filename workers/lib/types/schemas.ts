import { z } from 'zod';

export const OrgRoleSchema = z.enum(['owner', 'admin', 'member', 'billing_admin', 'viewer']);

export const BillingStatusSchema = z.enum(['inactive', 'active', 'past_due', 'canceled']);

export const OrgMembershipStatusSchema = z.enum(['active', 'invited', 'suspended']);

export const OrganizationSchema = z.object({
  id: z.string(),
  slug: z.string(),
  name: z.string(),
  billing_status: BillingStatusSchema,
  current_plan: ApiKeyTierSchema,
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

// JWT & Authentication
export const JwtPayloadSchema = z.object({
  sub: z.string(),
  email: z.string().email(),
  iat: z.number(),
  exp: z.number(),
}).passthrough();

export const UserRowSchema = z.object({
  id: z.string().uuid(),
  auth0_id: z.string(),
  email: z.string().email(),
  name: z.string().nullable(),
  tier: z.string(),
  default_organization_id: z.string().uuid().nullable(),
  created_at: z.string().datetime(),
});

// API Response Bodies
export const MeResponseSchema = z.object({
  id: z.string().uuid(),
  email: z.string().email(),
  name: z.string().nullable(),
  tier: z.string(),
  default_organization_id: z.string().uuid().nullable(),
  created_at: z.string().datetime(),
});

export const ListOrgsResponseSchema = z.object({
  organizations: z.array(
    OrganizationSchema.extend({ role: OrgRoleSchema }),
  ),
});

export const OrgDashboardResponseSchema = z.object({
  org: OrganizationSchema,
  role: OrgRoleSchema,
  entitlements: z.record(z.union([z.boolean(), z.number(), z.null()])),
});

export const OrgBillingStatusResponseSchema = z.object({
  org_id: z.string().uuid(),
  billing_status: BillingStatusSchema,
  current_plan: ApiKeyTierSchema,
  quota_version: z.number(),
  role: OrgRoleSchema,
});

// Usage & Buckets
export const UsageBucketSchema = z.object({
  organization_id: z.string().uuid(),
  bucket_date: z.string(),
  metric_key: z.string(),
  total_quantity: z.number(),
  request_count: z.number(),
  avg_latency_ms: z.number().nullable(),
});

export const UsageSummaryResponseSchema = z.object({
  org_id: z.string().uuid(),
  period_start: z.string(),
  buckets: z.array(UsageBucketSchema),
});

export const OrgEntitlementsResponseSchema = z.object({
  org_id: z.string().uuid(),
  entitlements: z.record(z.union([z.boolean(), z.number(), z.null()])),
});

// API Keys
export const ApiKeyStatusSchema = z.enum(['active', 'revoked', 'expired']);
export const ApiKeyTierSchema = z.enum(['starter', 'growth', 'enterprise']);

export const ApiKeySchema = z.object({
  id: z.string().uuid(),
  user_id: z.string().uuid(),
  organization_id: z.string().uuid(),
  prefix: z.string(),
  hash: z.string(),
  name: z.string(),
  tier: ApiKeyTierSchema,
  status: ApiKeyStatusSchema,
  expires_at: z.string().datetime().nullable(),
  last_used_at: z.string().datetime().nullable(),
  created_at: z.string().datetime(),
  revoked_at: z.string().datetime().nullable(),
});

export const CreateApiKeyResponseSchema = z.object({
  id: z.string().uuid(),
  name: z.string(),
  prefix: z.string(),
  tier: ApiKeyTierSchema,
  status: ApiKeyStatusSchema,
  expires_at: z.string().datetime().nullable(),
  created_at: z.string().datetime(),
  token: z.string(),
});

export const RevokeApiKeyResponseSchema = z.object({
  id: z.string().uuid(),
  status: z.literal('revoked'),
  revoked_at: z.string().datetime(),
});

// Quota Check
export const QuotaCheckRequestSchema = z.object({
  orgId: z.string().uuid(),
  metricKey: z.string(),
  units: z.number().int().positive(),
  requestId: z.string(),
  planKey: ApiKeyTierSchema,
  quotaVersion: z.number().int(),
});

export const QuotaCheckResponseSchema = z.object({
  allowed: z.boolean(),
  reason: z.enum(['minute_limit', 'monthly_limit', 'feature_disabled']).optional(),
  remainingMinute: z.number().int().nullable().optional(),
  remainingMonthly: z.number().int().nullable().optional(),
});

export const QuotaFlushResultSchema = z.object({
  orgId: z.string().uuid(),
  monthlyUsedSinceLastFlush: z.number().int(),
  flushedAt: z.string().datetime(),
});

// Org plan data fetched from database
export const OrgPlanRowSchema = z.object({
  current_plan: ApiKeyTierSchema,
  quota_version: z.number().int().nonnegative(),
});

// Middleware options for quota enforcement
export const OrgQuotaMiddlewareOptionsSchema = z.object({
  doNamespace: z.instanceof(Object), // DurableObjectNamespace is non-serializable
  supabaseUrl: z.string().url(),
  serviceRoleKey: z.string().min(1),
});

// Quota Durable Object /status endpoint response
// Returned by handleStatus() in quota.ts and consumed by getQuotaStatus() in lib/quota.ts.
const QuotaStatusInitializedSchema = z.object({
  orgId: z.string(),
  planKey: z.string(),
  quotaVersion: z.number().int().nonnegative(),
  minuteLimit: z.number().int().nonnegative(),
  monthlyLimit: z.number().int().nonnegative().nullable(),
  minuteUsed: z.number().int().nonnegative(),
  monthlyUsed: z.number().int().nonnegative(),
  minuteWindowExpiresIn: z.number().int(),
});

const QuotaStatusUninitializedSchema = z.object({
  status: z.literal('uninitialized'),
});

export const QuotaStatusResponseSchema = z.union([
  QuotaStatusInitializedSchema,
  QuotaStatusUninitializedSchema,
]);

export type QuotaStatusResponse = z.infer<typeof QuotaStatusResponseSchema>;

// Type inference for quota types
export type QuotaCheckRequest = z.infer<typeof QuotaCheckRequestSchema>;
export type QuotaCheckResponse = z.infer<typeof QuotaCheckResponseSchema>;
export type QuotaFlushResult = z.infer<typeof QuotaFlushResultSchema>;
export type OrgPlanRow = z.infer<typeof OrgPlanRowSchema>;
export type OrgQuotaMiddlewareOptions = z.infer<typeof OrgQuotaMiddlewareOptionsSchema>;
