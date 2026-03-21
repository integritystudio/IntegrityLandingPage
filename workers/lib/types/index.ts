export type OrgRole = 'owner' | 'admin' | 'member' | 'billing_admin' | 'viewer';
export type BillingStatus = 'inactive' | 'active' | 'past_due' | 'canceled';
export type PlanKey = 'free' | 'growth' | 'enterprise';
export type OrgMembershipStatus = 'active' | 'invited' | 'suspended';

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

export type ApiKeyStatus = 'active' | 'revoked' | 'expired';
export type ApiKeyTier = 'new' | 'free' | 'growth' | 'enterprise';

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
