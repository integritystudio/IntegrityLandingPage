// ============================================================================
// Core Types
// ============================================================================

export type HandlerResult = { ok: true } | { ok: false; error: string };

export type OrgRole = 'owner' | 'admin' | 'member' | 'billing_admin' | 'viewer';
/**
 * Mirrors Stripe's subscription lifecycle verbatim, plus `inactive`.
 *
 * @see https://docs.stripe.com/api/subscriptions/object#subscription_object-status
 *
 * Storing Stripe's own vocabulary means the webhook needs no translation layer — and a
 * lossy translation is exactly what silently filed `trialing` as unentitled for four
 * months (CR27). A status Stripe adds later flows through rather than collapsing.
 *
 * `inactive` is not a Stripe status. It is our value for "no Stripe subscription exists",
 * which Stripe cannot express because a status presupposes a subscription object; it is
 * the column default and covers most organizations.
 *
 * Several of these grant access. Use `isEntitled` from `../billing` rather than comparing
 * to `'active'` — that comparison silently excludes trial users.
 */
export type BillingStatus =
  | 'inactive'
  | 'incomplete'
  | 'incomplete_expired'
  | 'trialing'
  | 'active'
  | 'past_due'
  | 'canceled'
  | 'unpaid'
  | 'paused';
export type OrgMembershipStatus = 'active' | 'invited' | 'suspended';
export type ApiKeyStatus = 'active' | 'revoked' | 'expired';
export type ApiKeyTier = 'starter' | 'growth' | 'enterprise';

export interface Organization extends Record<string, unknown> {
  id: string;
  slug: string;
  name: string;
  billing_status: BillingStatus;
  current_plan: ApiKeyTier;
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
    /**
     * Set when the usage aggregate could not be read, so a consumer can tell "no usage yet"
     * from "we do not know". Absent on success. The numeric fields still carry safe defaults
     * rather than null, because the field is decoration on the post-signup screen and failing
     * the whole bootstrap over it would be worse than serving the rest of the payload.
     */
    unavailable?: true;
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
