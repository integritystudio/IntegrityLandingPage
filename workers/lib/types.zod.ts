import { z } from 'zod';
import {
  BillingStatusSchema,
  PlanKeySchema,
  OrgRoleSchema,
  EntitlementSchema as CanonicalEntitlementSchema,
} from './types/schemas';

// Re-export canonical schemas to consolidate access
export {
  BillingStatusSchema,
  PlanKeySchema,
  OrgRoleSchema,
  EntitlementSchema as CanonicalEntitlementSchema,
} from './types/schemas';

export type BillingStatus = z.infer<typeof BillingStatusSchema>;
export type PlanKey = z.infer<typeof PlanKeySchema>;

// ============================================================================
// JWT & Authentication (Two-Layer Architecture)
// ============================================================================

/**
 * Enriched JWT from Supabase with custom org claims.
 * Accepts additional unknown claims via .passthrough() to avoid breaking on
 * new Supabase claims added during token evolution.
 * Custom org claims (default_org_*) are optional to handle rollout gracefully.
 */
export const JWTPayloadSchema = z.object({
  sub: z.string().uuid('Supabase auth user ID'),
  email: z.string().email(),
  iss: z.string().url('JWT issuer URL'),
  aud: z.literal('authenticated'),
  iat: z.number().int().positive('Issued at timestamp'),
  exp: z.number().int().positive('Expiration timestamp'),
  org_ids: z.array(z.string().uuid('Organization ID')).optional(),
  default_org_id: z.string().uuid().optional(),
  // default_org_plan and default_org_billing_status intentionally omitted:
  // both are mutable state that must be queried server-side, not read from JWT
  // (M18 V-01: billing/plan staleness up to 3600s violates SOC 2 CC6.1).
  // Tokens issued before the Supabase hook update may still include these
  // fields; .passthrough() ensures they are accepted without failing validation.
  default_org_role: z.enum(['owner', 'admin', 'member', 'billing_admin', 'viewer']).optional(),
}).passthrough();

export type JWTPayload = z.infer<typeof JWTPayloadSchema>;

// ============================================================================
// Billing & Subscriptions (Stripe Integration)
// ============================================================================

export const SubscriptionSchema = z.object({
  id: z.string().uuid(),
  organization_id: z.string().uuid(),
  stripe_subscription_id: z.string(),
  stripe_price_id: z.string(),
  status: z.enum(['active', 'trialing', 'past_due', 'canceled', 'unpaid', 'incomplete']),
  tier: PlanKeySchema.optional(), // Use canonical PlanKeySchema, not raw string
  current_period_start: z.string().datetime(),
  current_period_end: z.string().datetime(),
  cancel_at_period_end: z.boolean().default(false),
  created_at: z.string().datetime(),
  updated_at: z.string().datetime(),
});

export type Subscription = z.infer<typeof SubscriptionSchema>;

/**
 * Entitlement definition: static configuration of a feature's limits per plan.
 * Allows zero limits for features that are conditionally disabled.
 */
export const EntitlementDefSchema = z.object({
  feature_key: z.string().min(1),
  enabled: z.boolean(),
  hard_limit: z.number().int().nonnegative().nullable(), // Zero is valid (disabled)
  soft_limit: z.number().int().nonnegative().nullable(),
});

export type EntitlementDef = z.infer<typeof EntitlementDefSchema>;

// Entitlement runtime state — use canonical CanonicalEntitlementSchema from schemas.ts
export type Entitlement = z.infer<typeof CanonicalEntitlementSchema>;

// ============================================================================
// Stripe Webhook Events
// ============================================================================

export const StripeObjectSchema = z.record(z.unknown());

/**
 * Enhanced Stripe event schema with stricter validation.
 * Uses canonical StripeEventSchema from schemas.ts for basic structure,
 * but validates critical fields more strictly for webhook processing.
 */
export const EnrichedStripeEventSchema = z.object({
  id: z.string().min(1, 'Event ID cannot be empty'), // evt_[a-z0-9]+
  object: z.literal('event'),
  api_version: z.string().optional(),
  created: z.number().int().min(1_000_000_000, 'Event timestamp must be valid Unix time (>= 2001)'),
  data: z.object({
    object: StripeObjectSchema,
    previous_attributes: z.record(z.unknown()).optional(),
  }),
  livemode: z.boolean(),
  pending_webhooks: z.number().int().nonnegative(),
  request: z.object({
    id: z.string().nullable(),
    idempotency_key: z.string().nullable(),
  }).optional(),
  type: z.string().min(1, 'Event type cannot be empty'),
});

export type EnrichedStripeEvent = z.infer<typeof EnrichedStripeEventSchema>;

export const StripeEventRecordSchema = z.object({
  id: z.string(),
  event_type: z.string().min(1),
  processed_at: z.string().datetime(),
});

export type StripeEventRecord = z.infer<typeof StripeEventRecordSchema>;

// ============================================================================
// Quota & Rate Limiting (Durable Objects)
// ============================================================================

export const QuotaMetricSchema = z.enum(['api_requests', 'data_retention_days', 'team_members', 'custom_dashboards']);
export type QuotaMetric = z.infer<typeof QuotaMetricSchema>;

/**
 * Request to check quota availability. Quantity can be positive or zero,
 * but not negative (use separate adjustment endpoint for decrements).
 */
export const QuotaCheckRequestSchema = z.object({
  org_id: z.string().uuid(),
  metric_key: QuotaMetricSchema,
  quantity: z.number().int().nonnegative(), // Zero is valid (dry-run check)
  plan: PlanKeySchema,
  quota_version: z.number().int().nonnegative(),
});

export type QuotaCheckRequest = z.infer<typeof QuotaCheckRequestSchema>;

export const QuotaCheckResponseSchema = z.object({
  ok: z.boolean(),
  remaining: z.number().int().nonnegative(),
  limit: z.number().int().positive(),
  soft_limit: z.number().int().positive().optional(),
  approaching_limit: z.boolean(),
  error: z.string().optional(),
});

export type QuotaCheckResponse = z.infer<typeof QuotaCheckResponseSchema>;

export const QuotaCommitRequestSchema = z.object({
  org_id: z.string().uuid(),
  metric_key: QuotaMetricSchema,
  quantity: z.number().int().positive(),
  success: z.boolean(),
});

export type QuotaCommitRequest = z.infer<typeof QuotaCommitRequestSchema>;

export const QuotaStateSchema = z.object({
  org_id: z.string().uuid(),
  metrics: z.record(
    QuotaMetricSchema,
    z.object({
      used: z.number().int().nonnegative(),
      limit: z.number().int().positive(),
      soft_limit: z.number().int().positive().optional(),
      reset_at: z.string().datetime(),
    })
  ),
  plan: PlanKeySchema,
  quota_version: z.number().int().nonnegative(),
  updated_at: z.string().datetime(),
});

export type QuotaState = z.infer<typeof QuotaStateSchema>;

// ============================================================================
// Disaster Recovery & Monitoring
// ============================================================================

export const HealthCheckResponseSchema = z.object({
  database: z.enum(['healthy', 'degraded', 'unhealthy']),
  stripe: z.enum(['healthy', 'degraded', 'unhealthy']),
  durableObjects: z.enum(['healthy', 'degraded', 'unhealthy']),
  timestamp: z.string().datetime(),
});

export type HealthCheckResponse = z.infer<typeof HealthCheckResponseSchema>;

/**
 * Webhook dead letter: failed event for retry or manual investigation.
 * Constraint: retry_count must never exceed max_retries; max_retries can be zero
 * for events that should not be retried (abandon immediately).
 *
 * This is the canonical full-row schema. `stripe-webhook/src/supabase.ts`
 * defines `DeadLetter`, a 6-field projection for DB queries that selects only
 * the fields needed at retry time. Use `WebhookDeadLetter` for validation and
 * API responses; use `DeadLetter` for internal retry-loop processing.
 */
export const WebhookDeadLetterSchema = z.object({
  id: z.string().uuid(),
  stripe_event_id: z.string().min(1),
  event_type: z.string().min(1),
  payload: z.record(z.unknown()),
  error_message: z.string().nullable(),
  retry_count: z.number().int().nonnegative(),
  max_retries: z.number().int().nonnegative(), // Zero = don't retry
  next_retry_at: z.string().datetime().nullable(),
  status: z.enum(['pending', 'resolved', 'abandoned']),
  created_at: z.string().datetime(),
  resolved_at: z.string().datetime().nullable(),
});

export type WebhookDeadLetter = z.infer<typeof WebhookDeadLetterSchema>;

// ============================================================================
// Security & Compliance (Tooling/Reports — not runtime)
// ============================================================================

/**
 * NOTE: SecurityFindingSchema and VulnerabilityReportSchema are for security
 * audit reports and tooling — NOT runtime worker data. Move to separate package
 * if bundling becomes an issue.
 */

export const SecurityFindingSchema = z.object({
  id: z.string().min(1),
  title: z.string().min(1),
  severity: z.enum(['CRITICAL', 'HIGH', 'MEDIUM', 'LOW']),
  category: z.string().min(1),
  description: z.string().min(1),
  impact: z.string().min(1),
  mitigation: z.string().min(1),
  code_example: z.string().optional(),
  references: z.array(z.string().url()).optional(),
  sprint: z.number().int().positive().optional(),
});

export type SecurityFinding = z.infer<typeof SecurityFindingSchema>;

export const VulnerabilityReportSchema = z.object({
  generated_at: z.string().datetime(),
  findings: z.array(SecurityFindingSchema),
  summary: z.object({
    critical: z.number().int().nonnegative(),
    high: z.number().int().nonnegative(),
    medium: z.number().int().nonnegative(),
    low: z.number().int().nonnegative(),
  }),
  remediation_path: z.object({
    sprint_1_hours: z.number().positive(),
    sprint_1_items: z.array(z.string()),
    phases: z.array(z.object({
      phase: z.number().int().positive(),
      title: z.string().min(1),
      items: z.array(z.string()),
    })),
  }),
});

export type VulnerabilityReport = z.infer<typeof VulnerabilityReportSchema>;

// ============================================================================
// Request/Response Wrappers (Generic Factories)
// ============================================================================

export const SuccessResponseSchema = <T extends z.ZodTypeAny>(dataSchema: T) =>
  z.object({
    ok: z.literal(true),
    data: dataSchema,
    timestamp: z.string().datetime().optional(),
  });

export const ErrorResponseSchema = z.object({
  ok: z.literal(false),
  error: z.string().min(1),
  code: z.string().min(1).max(50).optional(), // Machine-consumable error code
  details: z.record(z.unknown()).optional(),
  timestamp: z.string().datetime().optional(),
});

export const PaginatedResponseSchema = <T extends z.ZodTypeAny>(itemSchema: T) =>
  z.object({
    ok: z.literal(true),
    data: z.array(itemSchema),
    pagination: z.object({
      limit: z.number().int().positive(),
      offset: z.number().int().nonnegative(),
      total: z.number().int().nonnegative(),
      has_more: z.boolean(),
    }),
    timestamp: z.string().datetime().optional(),
  });

// ============================================================================
// Summary
// ============================================================================
// Canonical schemas imported from ./schemas (BillingStatusSchema, PlanKeySchema, OrgRoleSchema)
// New schemas defined in this file (JWT with org claims, Subscriptions, Quota, Webhooks, etc.)
// Generic response factories (SuccessResponseSchema, ErrorResponseSchema, PaginatedResponseSchema)
// All types exported via z.infer<> for full type safety
