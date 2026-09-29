import { ok, badRequest, unauthorized, serviceUnavailable, getBearerToken } from '../../../lib/http';
import { secretsEqual } from '../../../lib/crypto';
import { Auth0CloudEventSchema, Auth0LogStreamEventSchema, type Auth0LogRow } from '../../../lib/types';
import {
  cloudEventToAuth0LogRow,
  insertAuth0LogRows,
  toAuth0LogRow,
  type Auth0LogStoreEnv,
} from '../lib/auth0-log-store';

const LOG_PREFIX = '[auth0-logs]';

interface Auth0LogsEnv extends Auth0LogStoreEnv {
  /** Shared secret the stream sends as `Authorization: Bearer <token>` (AUTH0_LOG_STREAM_TOKEN). */
  streamToken?: string;
}

/**
 * POST /v1/auth0-logs — receiver for the Auth0 custom-webhook log stream (CR33, CR40).
 *
 * Two senders, two formats, one table:
 * - the event stream `est_uRZqNG2BECcHmc1G2nrXpn` posts one CloudEvent per delivery for
 *   user/organization/group lifecycle changes, stored with `log_id` = the event id;
 * - a log stream would post `{log_id, data}` batches. The tenant's plan refuses log streams
 *   (`409`, 2026-09-28), so the tenant log arrives through the scheduled poller in
 *   `lib/auth0-log-poller.ts` instead; that branch is kept for a plan upgrade.
 *
 * Authentication: every delivery carries `Authorization: Bearer <AUTH0_LOG_STREAM_TOKEN>`,
 * set as the event stream's `webhook_authorization` (a log stream's `httpAuthorization`). The token is checked in constant time before the
 * body is read. The insert below runs with the service-role key, which bypasses RLS, so
 * this check is the route's only gate: an unbound secret answers 503 to everyone rather
 * than reopening the route, and a missing or wrong token answers 401.
 *
 * Body: one event, or a JSON array of them; each is read as a log-stream event, else as a
 * CloudEvent. An event that is neither is skipped and logged, but a batch in which none
 * validate is a 400. That keeps a format mismatch visible as failed deliveries in Auth0. CR33's receiver expected a flat entry, which Auth0 never
 * sends, and stored no real event from 2026-08-17 until this change.
 *
 * A failed insert still answers 200, so a database outage cannot get the stream
 * suspended; the error is logged instead.
 */
export async function handleAuth0Logs(
  request: Request,
  env: Auth0LogsEnv,
): Promise<Response> {
  if (!env.streamToken) {
    console.error(`${LOG_PREFIX} AUTH0_LOG_STREAM_TOKEN is not bound; rejecting delivery`);
    return serviceUnavailable('Log stream receiver is not configured');
  }
  const presented = getBearerToken(request);
  if (!presented || !(await secretsEqual(env.streamToken, presented))) {
    return unauthorized('Invalid log stream token');
  }

  let body: unknown;
  try {
    body = await request.json();
  } catch (e) {
    console.error(`${LOG_PREFIX} Failed to parse JSON:`, e);
    return badRequest('Invalid JSON');
  }

  const events = Array.isArray(body) ? body : [body];
  const rows: Auth0LogRow[] = [];
  for (const event of events) {
    const row = toRow(event);
    if (row) rows.push(row);
  }
  if (rows.length === 0) {
    return badRequest('No valid log events');
  }

  const result = await insertAuth0LogRows(env, rows);
  if (!result.ok) {
    console.error(`${LOG_PREFIX} ${result.error}`);
    return ok({ message: 'Logged (insert failed but acknowledged)' });
  }
  return ok({ message: 'Log events persisted' });
}

/** A log-stream event or an event-stream CloudEvent as a row; null (logged) for anything else. */
function toRow(event: unknown): Auth0LogRow | null {
  const logEvent = Auth0LogStreamEventSchema.safeParse(event);
  if (logEvent.success) return toAuth0LogRow(logEvent.data.log_id, logEvent.data.data);
  const cloudEvent = Auth0CloudEventSchema.safeParse(event);
  if (cloudEvent.success) return cloudEventToAuth0LogRow(cloudEvent.data);
  console.warn(`${LOG_PREFIX} Skipping event that is neither a log-stream event nor a CloudEvent:`, logEvent.error.issues);
  return null;
}
