import { z } from 'zod';

/**
 * One Auth0 log entry — the `data` of a log-stream event.
 * @see https://auth0.com/docs/logs/concepts/log-data
 */
export const Auth0LogSchema = z.object({
  log_id: z.string().optional().describe('Unique log entry identifier'),
  _id: z.string().optional().describe('Alternative log identifier field'),
  date: z.coerce.date().describe('ISO 8601 timestamp'),
  type: z.string().describe('Log type code (s=success, f=failed login, etc)'),
  name: z.string().optional().describe('Human-readable event name'),
  client_id: z.string().optional(),
  client_name: z.string().optional(),
  user_id: z.string().optional(),
  user_name: z.string().optional(),
  email: z.string().email().optional(),
  ip: z.string().optional().describe('IP address'),
  user_agent: z.string().optional(),
  scope: z.string().optional(),
  description: z.string().optional(),
  connection: z.string().optional(),
  connection_id: z.string().optional(),
  stats: z.object({
    loginsCount: z.number().int().optional(),
  }).optional(),
  details: z.record(z.string(), z.unknown()).optional().describe('Additional details object'),
}).passthrough(); // Allow additional Auth0 fields not explicitly modeled

export type Auth0Log = z.infer<typeof Auth0LogSchema>;

/**
 * One event as an Auth0 custom-webhook log stream delivers it: the entry is wrapped,
 * not flat. The route skips an event that fails this rather than rejecting its batch.
 */
export const Auth0LogStreamEventSchema = z.object({
  log_id: z.string().min(1),
  data: Auth0LogSchema,
});

export type Auth0LogStreamEvent = z.infer<typeof Auth0LogStreamEventSchema>;

/**
 * One event as an Auth0 *event stream* delivers it: a CloudEvents 1.0 envelope for user,
 * organization and group lifecycle changes (`user.created`, `organization.member.added`, …),
 * not a tenant log entry. `data.object` is the affected resource.
 */
export const Auth0CloudEventSchema = z.object({
  specversion: z.string().min(1),
  id: z.string().min(1),
  type: z.string().min(1),
  source: z.string().optional(),
  time: z.string().optional(),
  data: z.object({ object: z.record(z.string(), z.unknown()) }).passthrough().optional(),
}).passthrough();

export type Auth0CloudEvent = z.infer<typeof Auth0CloudEventSchema>;

/**
 * Request body for POST /v1/auth0-logs: log-stream events in a batch (content format
 * JSONARRAY), or a single event of either kind — an event stream posts one CloudEvent.
 */
export const IngestAuth0LogRequestSchema = z.union([
  z.array(Auth0LogStreamEventSchema),
  Auth0LogStreamEventSchema,
  Auth0CloudEventSchema,
]);
export type IngestAuth0LogRequest = z.infer<typeof IngestAuth0LogRequestSchema>;

/**
 * Response from POST /v1/auth0-logs
 * Auth0 expects a 200 or 204 on success
 */
export const IngestAuth0LogResponseSchema = z.object({
  ok: z.literal(true),
  message: z.string().optional(),
});

export type IngestAuth0LogResponse = z.infer<typeof IngestAuth0LogResponseSchema>;

/**
 * Parsed Auth0 log for insertion into auth0_logs table
 */
export interface Auth0LogRow {
  log_id: string;
  event_type: string;
  event_name: string | null;
  client_id: string | null;
  client_name: string | null;
  user_id: string | null;
  user_name: string | null;
  email: string | null;
  ip_address: string | null;
  user_agent: string | null;
  scope: string | null;
  description: string | null;
  details: Record<string, unknown>;
}
