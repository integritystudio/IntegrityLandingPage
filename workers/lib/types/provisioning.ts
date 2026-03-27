import { z } from 'zod';
import { ApiKeyTierSchema } from './schemas';

/**
 * Provisioning Job Types
 * Async workflow tracking for identity and billing state changes
 */

export const ProvisioningJobTypeSchema = z.enum([
  'user_created',
  'user_updated',
  'membership_changed',
  'subscription_changed',
  'entitlements_recomputed',
  'quota_version_bumped',
]);

export type ProvisioningJobType = z.infer<typeof ProvisioningJobTypeSchema>;

export const ProvisioningJobSourceSchema = z.enum([
  'supabase_webhook',
  'stripe_webhook',
  'auth0_webhook',
  'manual',
  'migration',
]);

export type ProvisioningJobSource = z.infer<typeof ProvisioningJobSourceSchema>;

export const ProvisioningJobStatusSchema = z.enum([
  'pending',
  'processing',
  'completed',
  'failed',
  'retried',
]);

export type ProvisioningJobStatus = z.infer<typeof ProvisioningJobStatusSchema>;

export const ProvisioningJobSchema = z.object({
  id: z.string().uuid(),
  job_type: ProvisioningJobTypeSchema,
  source: ProvisioningJobSourceSchema,
  dedupe_key: z.string().min(1),
  organization_id: z.string().uuid().nullable(),
  user_id: z.string().uuid().nullable(),
  payload: z.record(z.unknown()),
  status: ProvisioningJobStatusSchema,
  result: z.record(z.unknown()).nullable(),
  error_message: z.string().nullable(),
  retry_count: z.number().int().nonnegative(),
  max_retries: z.number().int().nonnegative(),
  created_at: z.string().datetime(),
  updated_at: z.string().datetime(),
  completed_at: z.string().datetime().nullable(),
});

export type ProvisioningJob = z.infer<typeof ProvisioningJobSchema>;

// Provisioning job payloads (internal event data)

export const UserCreatedPayloadSchema = z.object({
  auth0_id: z.string(),
  email: z.string().email(),
  name: z.string().nullable().optional(),
});

export type UserCreatedPayload = z.infer<typeof UserCreatedPayloadSchema>;

export const UserUpdatedPayloadSchema = z.object({
  user_id: z.string().uuid(),
  auth0_id: z.string(),
  email: z.string().email(),
  name: z.string().nullable().optional(),
  tier: z.string().optional(),
});

export type UserUpdatedPayload = z.infer<typeof UserUpdatedPayloadSchema>;

export const MembershipChangedPayloadSchema = z.object({
  user_id: z.string().uuid(),
  organization_id: z.string().uuid(),
  role: z.enum(['owner', 'admin', 'member', 'billing_admin', 'viewer']),
  status: z.enum(['active', 'invited', 'suspended']),
  action: z.enum(['added', 'updated', 'deleted']),
});

export type MembershipChangedPayload = z.infer<typeof MembershipChangedPayloadSchema>;

export const SubscriptionChangedPayloadSchema = z.object({
  organization_id: z.string().uuid(),
  stripe_subscription_id: z.string(),
  stripe_event_id: z.string(),
  event_type: z.string(),
});

export type SubscriptionChangedPayload = z.infer<typeof SubscriptionChangedPayloadSchema>;

export const EntitlementsRecomputedPayloadSchema = z.object({
  organization_id: z.string().uuid(),
  plan_key: ApiKeyTierSchema,
  reason: z.enum(['subscription_change', 'manual_override']),
});

export type EntitlementsRecomputedPayload = z.infer<typeof EntitlementsRecomputedPayloadSchema>;

export const QuotaVersionBumpedPayloadSchema = z.object({
  organization_id: z.string().uuid(),
  old_version: z.number().int().nonnegative(),
  new_version: z.number().int().nonnegative(),
  reason: z.string(),
});

export type QuotaVersionBumpedPayload = z.infer<typeof QuotaVersionBumpedPayloadSchema>;
