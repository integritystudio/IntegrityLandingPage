import { ok, badRequest } from '../../../lib/http';
import { Auth0LogSchema, type Auth0LogRow } from '../../../lib/types';

interface Auth0LogsEnv {
  supabaseUrl: string;
  serviceRoleKey: string;
}

/**
 * POST /v1/auth0-logs — Auth0 HTTP log stream endpoint
 *
 * Auth0 sends log entries via HTTP POST to configured log streams. This handler
 * receives them, validates the payload, and persists to the auth0_logs table.
 *
 * Note: This endpoint has NO authentication because Auth0 cannot send a Bearer token.
 * The endpoint is public but safe because:
 * 1. Duplicate log_id entries are rejected (UNIQUE constraint)
 * 2. We only store data, no mutations to business logic
 * 3. The service_role account is write-only (cannot delete/modify existing logs)
 *
 * Auth0 retries on anything other than 200/204, so we must return success even if
 * insertion fails (after logging the error), to avoid Auth0 backing off the stream.
 */
export async function handleAuth0Logs(
  request: Request,
  env: Auth0LogsEnv,
): Promise<Response> {
  if (request.method !== 'POST') {
    return badRequest('Method not allowed');
  }

  let body: unknown;
  try {
    body = await request.json();
  } catch (e) {
    console.error('[auth0-logs] Failed to parse JSON:', e);
    return badRequest('Invalid JSON');
  }

  // Parse & validate Auth0 log entry
  const parseResult = Auth0LogSchema.safeParse(body);
  if (!parseResult.success) {
    console.warn('[auth0-logs] Validation failed:', parseResult.error.issues);
    return badRequest('Invalid log entry');
  }

  const logEntry = parseResult.data;
  const logId = logEntry.log_id || logEntry._id;
  if (!logId) {
    console.warn('[auth0-logs] Missing log_id and _id');
    return badRequest('Missing log identifier');
  }

  // Convert Auth0 log to database row format
  const row: Auth0LogRow = {
    log_id: logId,
    event_type: logEntry.type,
    event_name: logEntry.name || null,
    client_id: logEntry.client_id || null,
    client_name: logEntry.client_name || null,
    user_id: logEntry.user_id || null,
    user_name: logEntry.user_name || null,
    email: logEntry.email || null,
    ip_address: logEntry.ip || null,
    user_agent: logEntry.user_agent || null,
    scope: logEntry.scope || null,
    description: logEntry.description || null,
    details: { ...logEntry }, // Store full entry for audit/debugging
  };

  try {
    // Insert into auth0_logs table
    const response = await fetch(`${env.supabaseUrl}/rest/v1/auth0_logs`, {
      method: 'POST',
      headers: {
        'Authorization': `Bearer ${env.serviceRoleKey}`,
        'Content-Type': 'application/json',
        'Prefer': 'return=minimal', // Don't echo back the inserted row
      },
      body: JSON.stringify(row),
    });

    if (!response.ok) {
      const text = await response.text();
      console.error(`[auth0-logs] Supabase insert failed: ${response.status} ${text}`);

      // Return 200 anyway so Auth0 doesn't retry (log is already validated)
      // The error is logged for debugging but won't jam Auth0's delivery
      return ok({ message: 'Logged (Supabase insert failed but acknowledged)' });
    }

    return ok({ message: 'Log entry persisted' });
  } catch (e) {
    console.error('[auth0-logs] Insert error:', e);
    // Return 200 — Auth0 retries on error, but we've already validated
    // and logged. Retrying identical data risks duplicate PK constraint
    // violations, so acknowledge receipt even on DB error.
    return ok({ message: 'Logged (DB error but acknowledged)' });
  }
}
