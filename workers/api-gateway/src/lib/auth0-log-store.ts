import type { Auth0Log, Auth0LogRow } from '../../../lib/types';

/** Upsert on the UNIQUE `log_id`, so an entry delivered or fetched twice is stored once. */
const INSERT_PATH = '/rest/v1/auth0_logs?on_conflict=log_id';

export interface Auth0LogStoreEnv {
  supabaseUrl: string;
  serviceRoleKey: string;
}

export type InsertResult = { ok: true } | { ok: false; error: string };

export function toAuth0LogRow(logId: string, entry: Auth0Log): Auth0LogRow {
  return {
    log_id: logId,
    event_type: entry.type,
    event_name: entry.name || null,
    client_id: entry.client_id || null,
    client_name: entry.client_name || null,
    user_id: entry.user_id || null,
    user_name: entry.user_name || null,
    email: entry.email || null,
    ip_address: entry.ip || null,
    user_agent: entry.user_agent || null,
    scope: entry.scope || null,
    description: entry.description || null,
    details: { ...entry }, // Store full entry for audit/debugging
  };
}

/** Insert rows into `auth0_logs`, ignoring any `log_id` already stored. Never throws. */
export async function insertAuth0LogRows(env: Auth0LogStoreEnv, rows: Auth0LogRow[]): Promise<InsertResult> {
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
      return { ok: false, error: `Supabase insert failed: ${response.status} ${await response.text()}` };
    }
    return { ok: true };
  } catch (e) {
    return { ok: false, error: `Insert error: ${e instanceof Error ? e.message : String(e)}` };
  }
}
