import { ok, badRequest, unauthorized, serviceUnavailable, getBearerToken } from '../../../lib/http';
import { secretsEqual } from '../../../lib/crypto';
import { Auth0LogStreamEventSchema, type Auth0LogRow } from '../../../lib/types';
import { insertAuth0LogRows, toAuth0LogRow, type Auth0LogStoreEnv } from '../lib/auth0-log-store';

const LOG_PREFIX = '[auth0-logs]';

interface Auth0LogsEnv extends Auth0LogStoreEnv {
  /** Shared secret the stream sends as `Authorization: Bearer <token>` (AUTH0_LOG_STREAM_TOKEN). */
  streamToken?: string;
}

/**
 * POST /v1/auth0-logs — receiver for the Auth0 custom-webhook log stream (CR33, CR40).
 *
 * No stream feeds it today: the tenant's plan refuses log streams (`409` on create,
 * 2026-09-28), so logs arrive through the scheduled poller in `lib/auth0-log-poller.ts`.
 * The route is kept for a plan upgrade, and shares its row mapping with the poller.
 *
 * Authentication: the stream's `httpAuthorization` is `Bearer <AUTH0_LOG_STREAM_TOKEN>`,
 * and Auth0 sends it on every delivery. The token is checked in constant time before the
 * body is read. The insert below runs with the service-role key, which bypasses RLS, so
 * this check is the route's only gate: an unbound secret answers 503 to everyone rather
 * than reopening the route, and a missing or wrong token answers 401.
 *
 * Body: a JSON array of `{ log_id, data }` events (content format JSONARRAY); a single
 * event is taken as a batch of one. An event that fails validation is skipped and logged,
 * but a batch in which none validate is a 400. That keeps a format mismatch visible as
 * failed deliveries in Auth0. CR33's receiver expected a flat entry, which Auth0 never
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
    const parsed = Auth0LogStreamEventSchema.safeParse(event);
    if (parsed.success) {
      rows.push(toAuth0LogRow(parsed.data.log_id, parsed.data.data));
    } else {
      console.warn(`${LOG_PREFIX} Skipping invalid event:`, parsed.error.issues);
    }
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
