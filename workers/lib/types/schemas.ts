import { z } from 'zod';

// Stripe's eight subscription statuses verbatim, plus `inactive` for "no subscription
// exists" — see the BillingStatus doc comment in ./index.ts. Keep the two in sync.
// https://docs.stripe.com/api/subscriptions/object#subscription_object-status
export const BillingStatusSchema = z.enum([
  'inactive',
  'incomplete',
  'incomplete_expired',
  'trialing',
  'active',
  'past_due',
  'canceled',
  'unpaid',
  'paused',
]);

export const ApiKeyTierSchema = z.enum(['starter', 'growth', 'enterprise']);

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
