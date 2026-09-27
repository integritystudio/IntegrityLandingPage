import { z } from 'zod';

/**
 * Audit Logging and Compliance
 * Track all meaningful changes for compliance and debugging
 */

/**
 * Every action written to `audit_log`. `writeAuditLog` (api-gateway/src/lib/helpers.ts) is
 * the table's only writer — the `create_audit_log_entry` SQL function has no callers — and
 * `audit_log.action` is unconstrained text, so this enum is the whole vocabulary. Add a
 * name here before emitting it; the `AuditLogEntry.action` type makes that a compile error.
 */
export const AuditActionSchema = z.enum([
  'api_key.created',
  'api_key.revoked',
  'billing_portal.accessed',
  'checkout_session.created',
]);

export type AuditAction = z.infer<typeof AuditActionSchema>;

export const AuditLogSchema = z.object({
  id: z.number().int().positive(),
  organization_id: z.string().uuid().nullable(),
  actor_user_id: z.string().uuid().nullable(),
  actor_api_key_id: z.string().uuid().nullable(),
  action: AuditActionSchema,
  target_type: z.string().min(1), // e.g., 'user', 'organization', 'api_key'
  target_id: z.string().min(1),
  old_values: z.record(z.string(), z.unknown()).nullable(),
  new_values: z.record(z.string(), z.unknown()).nullable(),
  ip_address: z.union([z.ipv4(), z.ipv6()]).nullable(),
  user_agent: z.string().nullable(),
  metadata: z.record(z.string(), z.unknown()).default({}),
  created_at: z.string().datetime(),
});

export type AuditLog = z.infer<typeof AuditLogSchema>;

/**
 * Activity record (user-centric view of actions)
 * Lighter than full audit logs, used for user activity feeds
 */
export const UserActivitySchema = z.object({
  id: z.string().uuid(),
  user_id: z.string().uuid(),
  activity_type: z.string().min(1),
  description: z.string(),
  ip_address: z.union([z.ipv4(), z.ipv6()]).nullable(),
  user_agent: z.string().nullable(),
  metadata: z.record(z.string(), z.unknown()).default({}),
  created_at: z.string().datetime(),
});

export type UserActivity = z.infer<typeof UserActivitySchema>;

/**
 * User session tracking (for multi-device login support)
 */
export const DeviceTypeSchema = z.enum(['mobile', 'tablet', 'desktop', 'unknown']);
export type DeviceType = z.infer<typeof DeviceTypeSchema>;

export const UserSessionSchema = z.object({
  id: z.string().uuid(),
  user_id: z.string().uuid(),
  session_token: z.string().min(1),
  ip_address: z.union([z.ipv4(), z.ipv6()]).nullable(),
  user_agent: z.string().nullable(),
  device_type: DeviceTypeSchema,
  browser: z.string().nullable(),
  os: z.string().nullable(),
  country: z.string().nullable(),
  city: z.string().nullable(),
  last_activity: z.string().datetime(),
  expires_at: z.string().datetime(),
  is_active: z.boolean(),
  created_at: z.string().datetime(),
});

export type UserSession = z.infer<typeof UserSessionSchema>;

/**
 * Session query response for user account settings
 */
export const UserSessionsResponseSchema = z.object({
  user_id: z.string().uuid(),
  sessions: z.array(
    UserSessionSchema.pick({
      id: true,
      device_type: true,
      browser: true,
      os: true,
      country: true,
      is_active: true,
      last_activity: true,
      created_at: true,
    })
  ),
  current_session_id: z.string().uuid(),
});

export type UserSessionsResponse = z.infer<typeof UserSessionsResponseSchema>;

/**
 * Billing event log (Stripe webhook events)
 */
export const BillingEventTypeSchema = z.enum([
  'checkout.session.completed',
  'invoice.paid',
  'invoice.payment_failed',
  'customer.subscription.updated',
  'customer.subscription.deleted',
  'charge.refunded',
  'other',
]);

export type BillingEventType = z.infer<typeof BillingEventTypeSchema>;

export const BillingEventLogSchema = z.object({
  id: z.string().uuid(),
  organization_id: z.string().uuid().nullable(),
  stripe_event_id: z.string().min(1),
  event_type: BillingEventTypeSchema,
  payload: z.record(z.string(), z.unknown()),
  processed_at: z.string().datetime().nullable(),
  error_message: z.string().nullable(),
  created_at: z.string().datetime(),
});

export type BillingEventLog = z.infer<typeof BillingEventLogSchema>;
