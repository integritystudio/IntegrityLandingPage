import { z } from 'zod';

// ============================================================================
// JWT & Authentication (Two-Layer Architecture)
// ============================================================================

export const JWTPayloadSchema = z.object({
  sub: z.string().uuid('Supabase auth user ID'),
  email: z.string().email(),
  iss: z.string().url('JWT issuer URL'),
  aud: z.literal('authenticated'),
  iat: z.number().int().positive('Issued at timestamp'),
  exp: z.number().int().positive('Expiration timestamp'),
  org_ids: z.array(z.string().uuid('Organization ID')),
  default_org_id: z.string().uuid(),
  default_org_plan: z.enum(['free', 'growth', 'enterprise']),
  default_org_role: z.enum(['owner', 'admin', 'member', 'billing_admin', 'viewer']),
  default_org_billing_status: z.enum(['active', 'past_due', 'cancelled']),
});

export type JWTPayload = z.infer<typeof JWTPayloadSchema>;

export const APIKeySchema = z.object({
  id: z.string().uuid(),
  organization_id: z.string().uuid(),
  user_id: z.string().uuid(),
  prefix: z.string().regex(/^int_live_org_[a-z0-9]{8}$/),
  hash: z.string().length(64, 'SHA-256 hash must be 64 hex chars'),
  name: z.string().min(1).max(255),
  tier: z.enum(['new', 'free', 'growth', 'enterprise']),
  status: z.enum(['active', 'revoked', 'rotated']),
  expires_at: z.string().datetime().nullable(),
  created_at: z.string().datetime(),
  revoked_at: z.string().datetime().nullable(),
  last_used_at: z.string().datetime().nullable(),
});

export type APIKey = z.infer<typeof APIKeySchema>;

// ============================================================================
// Billing & Subscriptions (Stripe Integration)
// ============================================================================

export const BillingStatusSchema = z.enum(['active', 'past_due', 'cancelled', 'inactive']);
export type BillingStatus = z.infer<typeof BillingStatusSchema>;

export const PlanKeySchema = z.enum(['free', 'growth', 'enterprise']);
export type PlanKey = z.infer<typeof PlanKeySchema>;

export const SubscriptionSchema = z.object({
  id: z.string().uuid(),
  organization_id: z.string().uuid(),
  stripe_subscription_id: z.string(),
  stripe_price_id: z.string(),
  status: z.enum(['active', 'trialing', 'past_due', 'canceled', 'unpaid', 'incomplete']),
  tier: z.string().optional(),
  current_period_start: z.string().datetime(),
  current_period_end: z.string().datetime(),
  cancel_at_period_end: z.boolean().default(false),
  created_at: z.string().datetime(),
  updated_at: z.string().datetime(),
});

export type Subscription = z.infer<typeof SubscriptionSchema>;

export const EntitlementDefSchema = z.object({
  feature_key: z.string(),
  enabled: z.boolean(),
  hard_limit: z.number().int().positive().nullable(),
  soft_limit: z.number().int().positive().nullable(),
});

export type EntitlementDef = z.infer<typeof EntitlementDefSchema>;

export const EntitlementSchema = z.object({
  id: z.string().uuid(),
  organization_id: z.string().uuid(),
  feature_key: z.string(),
  enabled: z.boolean(),
  hard_limit: z.number().int().positive().nullable(),
  soft_limit: z.number().int().positive().nullable(),
  created_at: z.string().datetime(),
  updated_at: z.string().datetime(),
});

export type Entitlement = z.infer<typeof EntitlementSchema>;

// ============================================================================
// Stripe Webhook Events
// ============================================================================

export const StripeObjectSchema = z.record(z.unknown());

export const StripeEventSchema = z.object({
  id: z.string(),
  object: z.literal('event'),
  api_version: z.string().optional(),
  created: z.number().int(),
  data: z.object({
    object: StripeObjectSchema,
    previous_attributes: z.record(z.unknown()).optional(),
  }),
  livemode: z.boolean(),
  pending_webhooks: z.number().int(),
  request: z.object({
    id: z.string().nullable(),
    idempotency_key: z.string().nullable(),
  }).optional(),
  type: z.string(),
});

export type StripeEvent = z.infer<typeof StripeEventSchema>;

export const StripeEventRecordSchema = z.object({
  id: z.string(),
  event_type: z.string(),
  processed_at: z.string().datetime(),
});

export type StripeEventRecord = z.infer<typeof StripeEventRecordSchema>;

// ============================================================================
// Quota & Rate Limiting (Durable Objects)
// ============================================================================

export const QuotaMetricSchema = z.enum(['api_requests', 'data_retention_days', 'team_members', 'custom_dashboards']);
export type QuotaMetric = z.infer<typeof QuotaMetricSchema>;

export const QuotaCheckRequestSchema = z.object({
  org_id: z.string().uuid(),
  metric_key: QuotaMetricSchema,
  quantity: z.number().int().positive(),
  plan: PlanKeySchema,
  quota_version: z.number().int().non_negative(),
});

export type QuotaCheckRequest = z.infer<typeof QuotaCheckRequestSchema>;

export const QuotaCheckResponseSchema = z.object({
  ok: z.boolean(),
  remaining: z.number().int().non_negative(),
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
      used: z.number().int().non_negative(),
      limit: z.number().int().positive(),
      soft_limit: z.number().int().positive().optional(),
      reset_at: z.string().datetime(),
    })
  ),
  plan: PlanKeySchema,
  quota_version: z.number().int().non_negative(),
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

export const WebhookDeadLetterSchema = z.object({
  id: z.string().uuid(),
  stripe_event_id: z.string(),
  event_type: z.string(),
  payload: z.record(z.unknown()),
  error_message: z.string().nullable(),
  retry_count: z.number().int().non_negative(),
  max_retries: z.number().int().positive(),
  next_retry_at: z.string().datetime().nullable(),
  status: z.enum(['pending', 'processing', 'resolved', 'abandoned']),
  created_at: z.string().datetime(),
  resolved_at: z.string().datetime().nullable(),
});

export type WebhookDeadLetter = z.infer<typeof WebhookDeadLetterSchema>;

// ============================================================================
// Security & Compliance
// ============================================================================

export const SecurityFindingSchema = z.object({
  id: z.string(),
  title: z.string(),
  severity: z.enum(['CRITICAL', 'HIGH', 'MEDIUM', 'LOW']),
  category: z.string(),
  description: z.string(),
  impact: z.string(),
  mitigation: z.string(),
  code_example: z.string().optional(),
  references: z.array(z.string().url()).optional(),
  sprint: z.number().int().positive().optional(),
});

export type SecurityFinding = z.infer<typeof SecurityFindingSchema>;

export const VulnerabilityReportSchema = z.object({
  generated_at: z.string().datetime(),
  findings: z.array(SecurityFindingSchema),
  summary: z.object({
    critical: z.number().int().non_negative(),
    high: z.number().int().non_negative(),
    medium: z.number().int().non_negative(),
    low: z.number().int().non_negative(),
  }),
  remediation_path: z.object({
    sprint_1_hours: z.number().positive(),
    sprint_1_items: z.array(z.string()),
    phases: z.array(z.object({
      phase: z.number().int().positive(),
      title: z.string(),
      items: z.array(z.string()),
    })),
  }),
});

export type VulnerabilityReport = z.infer<typeof VulnerabilityReportSchema>;

// ============================================================================
// Request/Response Wrappers
// ============================================================================

export const SuccessResponseSchema = <T extends z.ZodTypeAny>(dataSchema: T) =>
  z.object({
    ok: z.literal(true),
    data: dataSchema,
    timestamp: z.string().datetime().optional(),
  });

export const ErrorResponseSchema = z.object({
  ok: z.literal(false),
  error: z.string(),
  code: z.string().optional(),
  details: z.record(z.unknown()).optional(),
  timestamp: z.string().datetime().optional(),
});

export const PaginatedResponseSchema = <T extends z.ZodTypeAny>(itemSchema: T) =>
  z.object({
    ok: z.literal(true),
    data: z.array(itemSchema),
    pagination: z.object({
      limit: z.number().int().positive(),
      offset: z.number().int().non_negative(),
      total: z.number().int().non_negative(),
      has_more: z.boolean(),
    }),
    timestamp: z.string().datetime().optional(),
  });

// ============================================================================
// Organization & User
// ============================================================================

export const OrganizationSchema = z.object({
  id: z.string().uuid(),
  stripe_customer_id: z.string().nullable(),
  name: z.string().min(1).max(255),
  email: z.string().email(),
  slug: z.string().regex(/^[a-z0-9-]+$/).min(3).max(50),
  current_plan: PlanKeySchema,
  billing_status: BillingStatusSchema,
  quota_version: z.number().int().non_negative(),
  created_at: z.string().datetime(),
  updated_at: z.string().datetime(),
});

export type Organization = z.infer<typeof OrganizationSchema>;

export const OrganizationMembershipSchema = z.object({
  id: z.string().uuid(),
  organization_id: z.string().uuid(),
  user_id: z.string().uuid(),
  role: z.enum(['owner', 'admin', 'member', 'billing_admin', 'viewer']),
  created_at: z.string().datetime(),
  updated_at: z.string().datetime(),
});

export type OrganizationMembership = z.infer<typeof OrganizationMembershipSchema>;

// ============================================================================
// Exports for convenience
// ============================================================================

export const AllSchemas = {
  JWTPayload: JWTPayloadSchema,
  APIKey: APIKeySchema,
  Subscription: SubscriptionSchema,
  Entitlement: EntitlementSchema,
  EntitlementDef: EntitlementDefSchema,
  StripeEvent: StripeEventSchema,
  StripeEventRecord: StripeEventRecordSchema,
  QuotaCheckRequest: QuotaCheckRequestSchema,
  QuotaCheckResponse: QuotaCheckResponseSchema,
  QuotaCommitRequest: QuotaCommitRequestSchema,
  QuotaState: QuotaStateSchema,
  HealthCheckResponse: HealthCheckResponseSchema,
  WebhookDeadLetter: WebhookDeadLetterSchema,
  SecurityFinding: SecurityFindingSchema,
  VulnerabilityReport: VulnerabilityReportSchema,
  Organization: OrganizationSchema,
  OrganizationMembership: OrganizationMembershipSchema,
};
