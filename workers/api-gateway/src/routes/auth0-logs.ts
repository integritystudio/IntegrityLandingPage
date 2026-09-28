import { ok, badRequest, unauthorized, serviceUnavailable, getBearerToken } from '../../../lib/http';
import { secretsEqual } from '../../../lib/crypto';
import { Auth0LogStreamEventSchema, type Auth0LogRow, type Auth0LogStreamEvent } from '../../../lib/types';

const LOG_PREFIX = '[auth0-logs]';
/** Upsert on the UNIQUE `log_id`, so a batch Auth0 retries inserts nothing twice. */
const INSERT_PATH = '/rest/v1/auth0_logs?on_conflict=log_id';

interface Auth0LogsEnv {
  supabaseUrl: string;
  serviceRoleKey: string;
  /** Shared secret the stream sends as `Authorization: Bearer <token>` (AUTH0_LOG_STREAM_TOKEN). */
  streamToken?: string;
}

/**
 * POST /v1/auth0-logs — receiver for the Auth0 custom-webhook log stream (CR33, CR40).
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
      rows.push(toRow(parsed.data));
    } else {
      console.warn(`${LOG_PREFIX} Skipping invalid event:`, parsed.error.issues);
    }
  }
  if (rows.length === 0) {
    return badRequest('No valid log events');
  }

  try {
    const response = await fetch(`${env.supabaseUrl}${INSERT_PATH}`, {
      method: 'POST',
      headers: {
        'Authorization': `Bearer ${env.serviceRoleKey}`,
        'apikey': env.serviceRoleKey, // Supabase REST API requires apikey header
        'Content-Type': 'application/json',
        'Prefer': 'resolution=ignore-duplicates,return=minimal',
      },
      body: JSON.stringify(rows),
    });

    if (!response.ok) {
      const text = await response.text();
      console.error(`${LOG_PREFIX} Supabase insert failed: ${response.status} ${text}`);
      return ok({ message: 'Logged (Supabase insert failed but acknowledged)' });
    }

    return ok({ message: 'Log events persisted' });
  } catch (e) {
    console.error(`${LOG_PREFIX} Insert error:`, e);
    return ok({ message: 'Logged (DB error but acknowledged)' });
  }
}

function toRow({ log_id, data }: Auth0LogStreamEvent): Auth0LogRow {
  return {
    log_id,
    event_type: data.type,
    event_name: data.name || null,
    client_id: data.client_id || null,
    client_name: data.client_name || null,
    user_id: data.user_id || null,
    user_name: data.user_name || null,
    email: data.email || null,
    ip_address: data.ip || null,
    user_agent: data.user_agent || null,
    scope: data.scope || null,
    description: data.description || null,
    details: { ...data }, // Store full entry for audit/debugging
  };
}
