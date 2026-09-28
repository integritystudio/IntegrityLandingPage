import { Auth0LogSchema, type Auth0LogRow } from '../../../lib/types';
import { insertAuth0LogRows, toAuth0LogRow, type Auth0LogStoreEnv } from './auth0-log-store';

/**
 * Scheduled pull of the Auth0 tenant log into `auth0_logs` (BACKLOG.md CR40).
 *
 * Why a poller: the tenant's plan refuses log streams (`409` on create, 2026-09-28), and
 * the Management API's `GET /api/v2/logs` is available on every plan. Retention on this
 * plan is about a day, so the cron (every 15 minutes) has wide margin.
 *
 * Paging, as measured against the tenant: without `from`, the endpoint returns the newest
 * entries first; with `from=<log_id>` it returns the entries after that id, oldest first,
 * excluding the id itself; a `from` that is not a log id is a 400. So the run keeps a
 * checkpoint — the newest log_id already stored — and pages forward from it. A run with no
 * checkpoint (the first, or after a reset) takes the newest page and checkpoints its head.
 *
 * The checkpoint advances only after the rows before it are stored, so a failed insert is
 * retried by the next run rather than skipped. An entry that fails validation is still
 * passed by the checkpoint, so one malformed entry cannot stall the poller.
 *
 * Credentials: a dedicated M2M client granted `read:logs` only. Its token lives 24 hours
 * and is cached in KV, because every mint counts against the plan's M2M token quota and
 * writes a `seccft` entry to the very log being read.
 */

const LOG_PREFIX = '[auth0-log-poller]';
/** Auth0's maximum page size for checkpoint pagination. */
export const LOGS_PAGE_SIZE = 100;
/** Bounds one run's subrequests; a backlog larger than this drains over later runs. */
export const MAX_PAGES_PER_RUN = 10;
const KV_PREFIX = 'auth0_logs:';
export const CHECKPOINT_KEY = `${KV_PREFIX}checkpoint`;
export const TOKEN_KEY = `${KV_PREFIX}mgmt_token`;
/** Re-mint this long before the token's own expiry. */
const TOKEN_EXPIRY_MARGIN_SECONDS = 300;
/** Workers KV rejects an `expirationTtl` below 60 seconds. */
const KV_MIN_TTL_SECONDS = 60;
const HTTP_BAD_REQUEST = 400;
const HTTP_UNAUTHORIZED = 401;

export interface Auth0LogPollerEnv extends Auth0LogStoreEnv {
  /** Tenant domain, e.g. `tenant.us.auth0.com` — the same AUTH0_DOMAIN JWTs verify against. */
  auth0Domain: string;
  clientId?: string;
  clientSecret?: string;
  kv?: KVNamespace;
}

export type PollResult =
  | { status: 'ok'; inserted: number; pages: number }
  | { status: 'failed'; inserted: number; pages: number; reason: string };

type Page = { ok: true; entries: unknown[] } | { ok: false; status: number; reason: string };

export async function pollAuth0Logs(env: Auth0LogPollerEnv): Promise<PollResult> {
  let inserted = 0;
  let pages = 0;
  const fail = (reason: string): PollResult => ({ status: 'failed', inserted, pages, reason });

  if (!env.clientId || !env.clientSecret) return fail('AUTH0_LOG_READER_CLIENT_ID/SECRET not bound');
  if (!env.kv) return fail('RATE_LIMIT_KV not bound; the checkpoint has nowhere to live');
  const kv = env.kv;

  const token = await getManagementToken(env, kv);
  if (!token.ok) return fail(token.reason);

  let checkpoint = await kv.get(CHECKPOINT_KEY);
  while (pages < MAX_PAGES_PER_RUN) {
    const page = await fetchLogPage(env.auth0Domain, token.value, checkpoint);
    pages += 1;

    if (!page.ok) {
      if (page.status === HTTP_BAD_REQUEST && checkpoint) {
        console.error(`${LOG_PREFIX} checkpoint ${checkpoint} rejected (${page.reason}); restarting from the newest page`);
        await kv.delete(CHECKPOINT_KEY);
        checkpoint = null;
        continue;
      }
      if (page.status === HTTP_UNAUTHORIZED) await kv.delete(TOKEN_KEY);
      return fail(page.reason);
    }

    const { entries } = page;
    if (entries.length === 0) break;

    const rows = toRows(entries);
    if (rows.length > 0) {
      const result = await insertAuth0LogRows(env, rows);
      if (!result.ok) return fail(result.error);
      inserted += rows.length;
    }

    // With a checkpoint the page runs oldest → newest; without one it runs newest → oldest.
    const newest = checkpoint ? entries[entries.length - 1] : entries[0];
    const newestId = logIdOf(newest);
    if (!newestId) return fail('page has no log_id to checkpoint');
    await kv.put(CHECKPOINT_KEY, newestId);

    const wasBootstrap = checkpoint === null;
    checkpoint = newestId;
    if (wasBootstrap || entries.length < LOGS_PAGE_SIZE) break;
  }

  return { status: 'ok', inserted, pages };
}

function toRows(entries: unknown[]): Auth0LogRow[] {
  const rows: Auth0LogRow[] = [];
  for (const entry of entries) {
    const parsed = Auth0LogSchema.safeParse(entry);
    const logId = parsed.success ? parsed.data.log_id || parsed.data._id : undefined;
    if (parsed.success && logId) {
      rows.push(toAuth0LogRow(logId, parsed.data));
    } else {
      console.warn(`${LOG_PREFIX} Skipping invalid entry ${logIdOf(entry) ?? '(no log_id)'}`);
    }
  }
  return rows;
}

function logIdOf(entry: unknown): string | undefined {
  const id = (entry as { log_id?: unknown } | null)?.log_id;
  return typeof id === 'string' && id.length > 0 ? id : undefined;
}

async function fetchLogPage(domain: string, token: string, checkpoint: string | null): Promise<Page> {
  const params = new URLSearchParams({ take: String(LOGS_PAGE_SIZE) });
  if (checkpoint) params.set('from', checkpoint);
  try {
    const res = await fetch(`https://${domain}/api/v2/logs?${params}`, {
      headers: { Authorization: `Bearer ${token}` },
    });
    if (!res.ok) return { ok: false, status: res.status, reason: `GET /api/v2/logs ${res.status}: ${await res.text()}` };
    const body: unknown = await res.json();
    if (!Array.isArray(body)) return { ok: false, status: res.status, reason: 'GET /api/v2/logs did not return an array' };
    return { ok: true, entries: body };
  } catch (e) {
    return { ok: false, status: 0, reason: `GET /api/v2/logs failed: ${e instanceof Error ? e.message : String(e)}` };
  }
}

async function getManagementToken(
  env: Auth0LogPollerEnv,
  kv: KVNamespace,
): Promise<{ ok: true; value: string } | { ok: false; reason: string }> {
  const cached = await kv.get(TOKEN_KEY);
  if (cached) return { ok: true, value: cached };

  try {
    const res = await fetch(`https://${env.auth0Domain}/oauth/token`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        grant_type: 'client_credentials',
        client_id: env.clientId,
        client_secret: env.clientSecret,
        audience: `https://${env.auth0Domain}/api/v2/`,
      }),
    });
    if (!res.ok) return { ok: false, reason: `token request ${res.status}: ${await res.text()}` };
    const body = await res.json() as { access_token?: unknown; expires_in?: unknown };
    if (typeof body.access_token !== 'string' || typeof body.expires_in !== 'number') {
      return { ok: false, reason: 'token response missing access_token or expires_in' };
    }
    const ttl = body.expires_in - TOKEN_EXPIRY_MARGIN_SECONDS;
    if (ttl >= KV_MIN_TTL_SECONDS) await kv.put(TOKEN_KEY, body.access_token, { expirationTtl: ttl });
    return { ok: true, value: body.access_token };
  } catch (e) {
    return { ok: false, reason: `token request failed: ${e instanceof Error ? e.message : String(e)}` };
  }
}
