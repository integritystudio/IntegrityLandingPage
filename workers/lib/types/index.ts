// ============================================================================
// Core Types
// ============================================================================

export type HandlerResult = { ok: true } | { ok: false; error: string };

export type OrgRole = 'owner' | 'admin' | 'member' | 'billing_admin' | 'viewer';
export type BillingStatus = 'inactive' | 'active' | 'past_due' | 'canceled';
export type PlanKey = 'free' | 'growth' | 'enterprise';
export type OrgMembershipStatus = 'active' | 'invited' | 'suspended';
export type ApiKeyStatus = 'active' | 'revoked' | 'expired';
export type ApiKeyTier = 'new' | 'free' | 'growth' | 'enterprise';

export interface Organization {
  id: string;
  slug: string;
  name: string;
  billing_status: BillingStatus;
  current_plan: PlanKey;
  quota_version: number;
}

export interface OrgMembership extends Record<string, unknown> {
  organization_id: string;
  user_id: string;
  role: OrgRole;
  status: OrgMembershipStatus;
}

export interface Entitlement extends Record<string, unknown> {
  organization_id: string;
  feature_key: string;
  enabled: boolean;
  hard_limit: number | null;
  soft_limit: number | null;
}

export interface BootstrapResponse {
  user: {
    id: string;
    email: string;
  };
  organizations: Array<Organization & { role: OrgRole }>;
  active_org_id: string;
  entitlements: Record<string, boolean | number | null>;
  usage_snapshot: {
    month_to_date_units: number;
    current_minute_remaining: number | null;
  };
}

export interface ApiKey extends Record<string, unknown> {
  id: string;
  user_id: string;
  organization_id: string;
  prefix: string;
  hash: string;
  name: string;
  tier: ApiKeyTier;
  status: ApiKeyStatus;
  expires_at: string | null;
  last_used_at: string | null;
  created_at: string;
  revoked_at: string | null;
}

export interface StripeEvent {
  id: string;
  type: string;
  created: number;
  data: {
    object: Record<string, unknown>;
    previous_attributes?: Record<string, unknown>;
  };
}

export interface JwtPayload {
  sub: string;
  email: string;
  iat: number;
  exp: number;
  [key: string]: unknown;
}

export interface UserRow {
  id: string;
  auth0_id: string;
  email: string;
  name: string | null;
  tier: string;
  default_organization_id: string | null;
  created_at: string;
}

export interface UsageBucket {
  organization_id: string;
  bucket_date: string;
  metric_key: string;
  total_quantity: number;
  request_count: number;
  avg_latency_ms: number | null;
}

// ============================================================================
// Re-exports from Zod schema files for convenience
// ============================================================================

// Provisioning
export type {
  ProvisioningJob,
  ProvisioningJobType,
  ProvisioningJobSource,
  ProvisioningJobStatus,
  UserCreatedPayload,
  UserUpdatedPayload,
  MembershipChangedPayload,
  SubscriptionChangedPayload,
  EntitlementsRecomputedPayload,
  QuotaVersionBumpedPayload,
} from './provisioning';

// Usage
export type {
  UsageEvent,
  UsageEventSource,
  UsageEventIngestion,
  IngestEventRequest,
  IngestEventResponse,
  OtelSpan,
  IngestOtelRequest,
  IngestOtelMetadata,
  IngestOtelResponse,
  MonthlyUsageSummary,
  UsageQueryResponse,
  UsageFlushResult,
} from './usage';

// Supabase
export type {
  SupabaseRow,
  SupabaseQueryResult,
  SupabaseRpcResult,
  QueryFilter,
  QueryOptions,
  InsertOptions,
  UpdateOptions,
  RpcOptions,
  FilterOperator,
} from './supabase';

// Audit & Compliance
export type {
  AuditLog,
  AuditAction,
  UserActivity,
  UserSession,
  UserSessionsResponse,
  BillingEventLog,
  BillingEventType,
  DeviceType,
} from './audit';
