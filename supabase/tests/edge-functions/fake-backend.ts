/**
 * In-memory stand-in for everything an Edge Function reaches over HTTP: PostgREST,
 * the Auth admin API, and the Cloudflare KV REST API.
 *
 * It is a fake, not a mock. It keeps real state (tables, KV entries), answers with the
 * status codes and error shapes the real services use, and is driven by the real
 * supabase-js client, so a test asserts on what ended up stored — never on which calls
 * were made. It implements only the protocol subset the functions use and throws on
 * anything else, so a handler that starts making a new kind of request fails loudly
 * here instead of being answered with something plausible.
 *
 * The harness lives outside supabase/functions so nothing Node-specific sits in the tree
 * the Supabase CLI bundles. To type-check a function under Deno from inside this repo, pass
 * `--node-modules-dir=none`: the repo-root package.json otherwise switches Deno to npm
 * resolution and the edge-runtime types fail to resolve.
 */

export type Row = Record<string, unknown>;

export const FAKE_SUPABASE_URL = 'https://fake-project.supabase.test';
const CLOUDFLARE_ORIGIN = 'https://api.cloudflare.com';

const OBJECT_MEDIA_TYPE = 'application/vnd.pgrst.object+json';
const REST_PREFIX = '/rest/v1/';
const RPC_PREFIX = 'rpc/';
const AUTH_ADMIN_USERS = '/auth/v1/admin/users';
const KV_PATH = /^\/client\/v4\/accounts\/([^/]+)\/storage\/kv\/namespaces\/([^/]+)\/values\/(.+)$/;
const KV_LIST_PATH = /^\/client\/v4\/accounts\/([^/]+)\/storage\/kv\/namespaces\/([^/]+)\/keys$/;
const DEFAULT_KV_LIST_PAGE = 1000;

export interface KvEntry {
  value: string;
  contentType: string | null;
}

export interface FakeBackendOptions {
  /** Keys the project treats as service-level: they pass the Auth admin check and bypass RLS. */
  serviceKeys: string[];
  /** The one Cloudflare API token that may write to KV. */
  cloudflareToken: string;
  tables?: Record<string, Row[]>;
  /** Keys per page when listing KV, so a test can make pagination happen. */
  kvListPageSize?: number;
}

/** A way for one kind of request to fail, set per test. */
export type Failure =
  | { kind: 'network' }
  | { kind: 'http'; status: number; body: unknown };

const NETWORK_ERROR = (target: string) => new TypeError(`fake backend: network failure reaching ${target}`);

function json(status: number, body: unknown, headers: Record<string, string> = {}): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { 'Content-Type': 'application/json', ...headers },
  });
}

function respondWithFailure(failure: Failure, target: string): Response {
  if (failure.kind === 'network') throw NETWORK_ERROR(target);
  return json(failure.status, failure.body);
}

export class FakeBackend {
  readonly tables = new Map<string, Row[]>();
  /** KV entries keyed `<accountId>/<namespaceId>/<key>`. */
  readonly kv = new Map<string, KvEntry>();

  private readonly serviceKeys: Set<string>;
  private readonly cloudflareToken: string;
  private readonly kvListPageSize: number;
  private readonly failures = new Map<string, { failure: Failure; remaining: number }>();
  private nextId = 1;

  /**
   * Runs after every successful KV write, with the written key, so a test can change the
   * world between a function's KV PUT and whatever it does next (e.g. revoke the key).
   */
  onKvPut: ((key: string) => void) | null = null;

  constructor(options: FakeBackendOptions) {
    this.serviceKeys = new Set(options.serviceKeys);
    this.cloudflareToken = options.cloudflareToken;
    this.kvListPageSize = options.kvListPageSize ?? DEFAULT_KV_LIST_PAGE;
    for (const [table, rows] of Object.entries(options.tables ?? {})) {
      this.tables.set(table, rows.map((row) => ({ ...row })));
    }
  }

  /**
   * Make one kind of request fail from now on, or only the next `times` of them. Targets:
   * `auth`, `kv` (writes), `kv-read`, `kv-delete`, `kv-list`, `select:<table>`,
   * `insert:<table>`, `update:<table>`, `delete:<table>`, `rpc:<function>`.
   */
  fail(target: string, failure: Failure, times = Infinity): void {
    this.failures.set(target, { failure, remaining: times });
  }

  private takeFailure(target: string): Failure | undefined {
    const entry = this.failures.get(target);
    if (!entry) return undefined;
    entry.remaining -= 1;
    if (entry.remaining <= 0) this.failures.delete(target);
    return entry.failure;
  }

  rows(table: string): Row[] {
    return this.tables.get(table) ?? [];
  }

  kvEntry(accountId: string, namespaceId: string, key: string): KvEntry | undefined {
    return this.kv.get(`${accountId}/${namespaceId}/${key}`);
  }

  /** Put a KV entry in place before the code under test runs. */
  seedKv(accountId: string, namespaceId: string, key: string, value: string): void {
    this.kv.set(`${accountId}/${namespaceId}/${key}`, { value, contentType: 'text/plain' });
  }

  /** A `fetch` that routes to this backend. Pass it wherever the code under test takes one. */
  readonly fetch: typeof fetch = async (input, init) => {
    const request = new Request(input, init);
    const url = new URL(request.url);

    if (url.origin === FAKE_SUPABASE_URL && url.pathname === AUTH_ADMIN_USERS) {
      return this.handleAuthAdmin(request);
    }
    if (url.origin === FAKE_SUPABASE_URL && url.pathname.startsWith(REST_PREFIX)) {
      return this.handleRest(request, url);
    }
    const kvMatch = url.origin === CLOUDFLARE_ORIGIN ? url.pathname.match(KV_PATH) : null;
    if (kvMatch) {
      return this.handleKv(request, kvMatch[1], kvMatch[2], decodeURIComponent(kvMatch[3]));
    }
    const kvListMatch = url.origin === CLOUDFLARE_ORIGIN ? url.pathname.match(KV_LIST_PATH) : null;
    if (kvListMatch) {
      return this.handleKvList(request, url, kvListMatch[1], kvListMatch[2]);
    }
    throw new Error(`fake backend: unexpected request ${request.method} ${request.url}`);
  };

  /** GoTrue admin API: 200 only when the caller presents a service-level key. */
  private handleAuthAdmin(request: Request): Response {
    const failure = this.takeFailure('auth');
    if (failure) return respondWithFailure(failure, 'auth');
    if (request.method !== 'GET') throw new Error(`fake backend: unsupported auth admin method ${request.method}`);

    const apikey = request.headers.get('apikey');
    const bearer = request.headers.get('Authorization')?.replace(/^Bearer /, '');
    if (!apikey || apikey !== bearer || !this.serviceKeys.has(apikey)) {
      return json(401, { code: 401, error_code: 'no_authorization', msg: 'This endpoint requires a valid Bearer token' });
    }
    return json(200, { users: [], aud: 'authenticated' });
  }

  private async handleRest(request: Request, url: URL): Promise<Response> {
    const apikey = request.headers.get('apikey');
    if (!apikey || !this.serviceKeys.has(apikey)) {
      return json(401, { message: 'Invalid API key', hint: 'Double check your Supabase `anon` or `service_role` API key.' });
    }

    const table = url.pathname.slice(REST_PREFIX.length);
    if (table.startsWith(RPC_PREFIX)) return this.handleRpc(request, table.slice(RPC_PREFIX.length));
    const wantsObject = (request.headers.get('Accept') ?? '').includes(OBJECT_MEDIA_TYPE);

    if (request.method === 'GET') {
      const failure = this.takeFailure(`select:${table}`);
      if (failure) return respondWithFailure(failure, `select:${table}`);
      return this.respondWithRows(this.select(table, url.searchParams), url.searchParams, wantsObject);
    }

    if (request.method === 'POST') {
      const failure = this.takeFailure(`insert:${table}`);
      if (failure) return respondWithFailure(failure, `insert:${table}`);
      const payload = (await request.json()) as Row | Row[];
      const inserted = (Array.isArray(payload) ? payload : [payload]).map((row) => ({
        id: `${table}-${this.nextId++}`,
        created_at: new Date().toISOString(),
        ...row,
      }));
      this.tables.set(table, [...this.rows(table), ...inserted]);
      const wantsRepresentation = (request.headers.get('Prefer') ?? '').includes('return=representation');
      if (!wantsRepresentation) return new Response(null, { status: 201 });
      return this.respondWithRows(inserted, url.searchParams, wantsObject, 201);
    }

    if (request.method === 'PATCH') {
      const failure = this.takeFailure(`update:${table}`);
      if (failure) return respondWithFailure(failure, `update:${table}`);
      const changes = (await request.json()) as Row;
      const updated = this.rows(table).filter((row) => matches(row, url.searchParams));
      for (const row of updated) Object.assign(row, changes);
      const wantsRepresentation = (request.headers.get('Prefer') ?? '').includes('return=representation');
      if (!wantsRepresentation) return new Response(null, { status: 204 });
      return this.respondWithRows(updated, url.searchParams, wantsObject);
    }

    if (request.method === 'DELETE') {
      const failure = this.takeFailure(`delete:${table}`);
      if (failure) return respondWithFailure(failure, `delete:${table}`);
      const kept = this.rows(table).filter((row) => !matches(row, url.searchParams));
      this.tables.set(table, kept);
      return new Response(null, { status: 204 });
    }

    throw new Error(`fake backend: unsupported PostgREST method ${request.method} on ${table}`);
  }

  /**
   * PostgREST `POST /rpc/<fn>` for the SQL functions the edge functions call, with the
   * semantics their migrations define (20261010000000_api_key_requests). A scalar result
   * is answered as bare JSON; a `raise exception` as PostgREST's 400 with code P0001.
   */
  private async handleRpc(request: Request, fn: string): Promise<Response> {
    const failure = this.takeFailure(`rpc:${fn}`);
    if (failure) return respondWithFailure(failure, `rpc:${fn}`);
    if (request.method !== 'POST') throw new Error(`fake backend: unsupported RPC method ${request.method} on ${fn}`);
    const args = (await request.json()) as Row;
    const requests = this.rows('api_key_requests');
    const claim = requests.find((row) => row.request_id === args.p_request_id);

    if (fn === 'create_api_key_for_request') {
      if (claim) {
        return json(400, { code: 'P0001', details: null, hint: null, message: 'api_key_request_abandoned' });
      }
      const keyId = `api_keys-${this.nextId++}`;
      this.tables.set('api_keys', [...this.rows('api_keys'), {
        id: keyId,
        created_at: new Date().toISOString(),
        user_id: args.p_user_id,
        organization_id: args.p_organization_id,
        prefix: args.p_prefix,
        hash: args.p_hash,
        name: args.p_name,
        tier: args.p_tier,
        status: 'active',
      }]);
      this.tables.set('api_key_requests', [...requests, { request_id: args.p_request_id, api_key_id: keyId, abandoned_at: null }]);
      return json(200, keyId);
    }

    if (fn === 'abandon_api_key_request') {
      if (claim) {
        claim.abandoned_at ??= new Date().toISOString();
        return json(200, claim.api_key_id ?? null);
      }
      this.tables.set('api_key_requests', [...requests, { request_id: args.p_request_id, api_key_id: null, abandoned_at: new Date().toISOString() }]);
      return json(200, null);
    }

    throw new Error(`fake backend: unsupported RPC ${fn}`);
  }

  /** Apply the `eq` filters, `order` and `limit` a PostgREST GET carries. */
  private select(table: string, params: URLSearchParams): Row[] {
    let rows = this.rows(table).filter((row) => matches(row, params));
    const order = params.get('order');
    if (order) {
      const [column, direction] = order.split('.');
      rows.sort((a, b) => String(a[column]).localeCompare(String(b[column])) * (direction === 'desc' ? -1 : 1));
    }
    const limit = params.get('limit');
    return limit === null ? rows : rows.slice(0, Number(limit));
  }

  private respondWithRows(rows: Row[], params: URLSearchParams, wantsObject: boolean, status = 200): Response {
    const projected = rows.map((row) => project(row, params.get('select')));
    if (!wantsObject) return json(status, projected);
    if (projected.length !== 1) {
      return json(406, {
        code: 'PGRST116',
        details: `The result contains ${projected.length} rows`,
        hint: null,
        message: 'JSON object requested, multiple (or no) rows returned',
      });
    }
    return json(status, projected[0]);
  }

  private unauthorizedForKv(request: Request): Response | null {
    if (request.headers.get('Authorization') === `Bearer ${this.cloudflareToken}`) return null;
    return json(403, { success: false, errors: [{ code: 10000, message: 'Authentication error' }] });
  }

  /**
   * Cloudflare KV "read key-value pair" (GET, raw value or 404), "write key-value pair"
   * (PUT) and "delete key-value pair" (DELETE, 200 whether or not the key existed). All
   * require the account's API token.
   */
  private async handleKv(request: Request, accountId: string, namespaceId: string, key: string): Promise<Response> {
    if (request.method === 'GET') {
      const failure = this.takeFailure('kv-read');
      if (failure) return respondWithFailure(failure, 'kv-read');
      const denied = this.unauthorizedForKv(request);
      if (denied) return denied;
      const entry = this.kvEntry(accountId, namespaceId, key);
      if (!entry) return json(404, { success: false, errors: [{ code: 10009, message: "get: 'key not found'" }] });
      return new Response(entry.value, { status: 200, headers: { 'Content-Type': 'application/octet-stream' } });
    }
    if (request.method === 'DELETE') {
      const failure = this.takeFailure('kv-delete');
      if (failure) return respondWithFailure(failure, 'kv-delete');
      const denied = this.unauthorizedForKv(request);
      if (denied) return denied;
      this.kv.delete(`${accountId}/${namespaceId}/${key}`);
      return json(200, { success: true, errors: [], messages: [], result: null });
    }
    const failure = this.takeFailure('kv');
    if (failure) return respondWithFailure(failure, 'kv');
    if (request.method !== 'PUT') throw new Error(`fake backend: unsupported KV method ${request.method}`);
    const denied = this.unauthorizedForKv(request);
    if (denied) return denied;
    this.kv.set(`${accountId}/${namespaceId}/${key}`, {
      value: await request.text(),
      contentType: request.headers.get('Content-Type'),
    });
    this.onKvPut?.(key);
    return json(200, { success: true, errors: [], messages: [], result: null });
  }

  /** Cloudflare KV "list keys": names only, `prefix` filter, cursor pagination. */
  private handleKvList(request: Request, url: URL, accountId: string, namespaceId: string): Response {
    const failure = this.takeFailure('kv-list');
    if (failure) return respondWithFailure(failure, 'kv-list');
    if (request.method !== 'GET') throw new Error(`fake backend: unsupported KV list method ${request.method}`);
    const denied = this.unauthorizedForKv(request);
    if (denied) return denied;
    const scope = `${accountId}/${namespaceId}/`;
    const prefix = url.searchParams.get('prefix') ?? '';
    const names = [...this.kv.keys()]
      .filter((k) => k.startsWith(scope))
      .map((k) => k.slice(scope.length))
      .filter((name) => name.startsWith(prefix))
      .sort();
    const start = Number(url.searchParams.get('cursor') ?? 0);
    const page = names.slice(start, start + this.kvListPageSize);
    const next = start + page.length;
    return json(200, {
      success: true,
      errors: [],
      messages: [],
      result: page.map((name) => ({ name })),
      result_info: { count: page.length, cursor: next < names.length ? String(next) : '' },
    });
  }
}

/** The `eq` filters a PostgREST request carries; `select`, `limit` and `order` are not filters. */
function matches(row: Row, params: URLSearchParams): boolean {
  for (const [key, value] of params) {
    if (key === 'select' || key === 'limit' || key === 'order') continue;
    const eq = value.match(/^eq\.(.*)$/);
    if (!eq) throw new Error(`fake backend: unsupported filter ${key}=${value}`);
    if (String(row[key]) !== eq[1]) return false;
  }
  return true;
}

/** PostgREST column projection for a flat `select=a,b,c` (or `*`). */
function project(row: Row, select: string | null): Row {
  if (!select || select === '*') return { ...row };
  const columns = select.split(',').map((column) => column.trim());
  for (const column of columns) {
    if (!/^[a-z_][a-z0-9_]*$/.test(column)) throw new Error(`fake backend: unsupported select ${select}`);
  }
  return Object.fromEntries(columns.filter((column) => column in row).map((column) => [column, row[column]]));
}
