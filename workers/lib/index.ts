// Re-export crypto primitives
export { hmacSign, hmacSignHex, hmacVerify, sha256Hex, arrayBufferToBase64Url } from './crypto';

// Re-export billing status helpers
export { isEntitled, effectivePlan, UNPAID_PLAN, PLAN_MIN_SEATS, DEFAULT_CHECKOUT_SEATS, toBillingStatus, STRIPE_SUBSCRIPTION_STATUSES } from './billing';
export { buildEntitlementMap, projectPlanEntitlements, PLAN_LIMIT_KEYS, PLAN_SELECT } from './entitlements';
export type { EntitlementMap, PlanRow } from './entitlements';
export type { StripeSubscriptionStatus } from './billing';

// Re-export all types
export * from './types/index';
export * from './types/handler-options';

// Re-export constants
export * from './constants';

// Re-export schemas still consumed at runtime
export {
  BillingStatusSchema,
  ApiKeyTierSchema,
  QuotaCheckRequestSchema,
  QuotaCheckResponseSchema,
  OrgPlanRowSchema,
  OrgQuotaMiddlewareOptionsSchema,
  QuotaStatusResponseSchema,
  type QuotaCheckRequest,
  type QuotaCheckResponse,
  type OrgPlanRow,
  type OrgQuotaMiddlewareOptions,
  type QuotaStatusResponse,
} from './types/schemas';

// Re-export request body schemas and types
export {
  CreateApiKeyBodySchema,
  OrgIdParamSchema,
  ApiKeyIdParamSchema,
  PaginationParamsSchema,
  StripeEventBodySchema,
  type CreateApiKeyBody,
  type OrgIdParam,
  type ApiKeyIdParam,
  type PaginationParams,
  type StripeEventBody,
} from './types/request-bodies';

// Re-export usage schemas
export {
  UsageEventSourceSchema,
  UsageEventSchema,
  UsageEventIngestionSchema,
  IngestEventRequestSchema,
  IngestEventResponseSchema,
  OtelSpanSchema,
  IngestOtelRequestSchema,
  IngestOtelMetadataSchema,
  IngestOtelResponseSchema,
  UsageBucketSchema as UsageBucketDetailSchema,
  MonthlyUsageSummarySchema,
  UsageQueryResponseSchema,
  UsageFlushResultSchema,
} from './types/usage';

// Re-export Supabase schemas
export {
  SupabaseRowSchema,
  SupabaseQueryResultSchema,
  SupabaseRpcResultSchema,
  QueryFilterSchema,
  QueryOptionsSchema,
  InsertOptionsSchema,
  UpdateOptionsSchema,
  RpcOptionsSchema,
  FilterOperatorSchema,
} from './types/supabase';

// Re-export audit/compliance schemas
export {
  AuditActionSchema,
  AuditLogSchema,
  UserActivitySchema,
  DeviceTypeSchema,
  UserSessionSchema,
  UserSessionsResponseSchema,
  BillingEventTypeSchema,
  BillingEventLogSchema,
} from './types/audit';
