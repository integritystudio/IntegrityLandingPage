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
const AUTH_ADMIN_USERS = '/auth/v1/admin/users';
const KV_PATH = /^\/client\/v4\/accounts\/([^/]+)\/storage\/kv\/namespaces\/([^/]+)\/values\/(.+)$/;

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
  private readonly failures = new Map<string, Failure>();
  private nextId = 1;

  constructor(options: FakeBackendOptions) {
    this.serviceKeys = new Set(options.serviceKeys);
    this.cloudflareToken = options.cloudflareToken;
    for (const [table, rows] of Object.entries(options.tables ?? {})) {
      this.tables.set(table, rows.map((row) => ({ ...row })));
    }
  }

  /**
   * Make one kind of request fail from now on. Targets: `auth`, `kv`, `select:<table>`,
   * `insert:<table>`.
   */
  fail(target: string, failure: Failure): void {
    this.failures.set(target, failure);
  }

  rows(table: string): Row[] {
    return this.tables.get(table) ?? [];
  }

  kvEntry(accountId: string, namespaceId: string, key: string): KvEntry | undefined {
    return this.kv.get(`${accountId}/${namespaceId}/${key}`);
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
    throw new Error(`fake backend: unexpected request ${request.method} ${request.url}`);
  };

  /** GoTrue admin API: 200 only when the caller presents a service-level key. */
  private handleAuthAdmin(request: Request): Response {
    const failure = this.failures.get('auth');
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
    const wantsObject = (request.headers.get('Accept') ?? '').includes(OBJECT_MEDIA_TYPE);

    if (request.method === 'GET') {
      const failure = this.failures.get(`select:${table}`);
      if (failure) return respondWithFailure(failure, `select:${table}`);
      return this.respondWithRows(this.select(table, url.searchParams), url.searchParams, wantsObject);
    }

    if (request.method === 'POST') {
      const failure = this.failures.get(`insert:${table}`);
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

    throw new Error(`fake backend: unsupported PostgREST method ${request.method} on ${table}`);
  }

  /** Apply the `eq` filters, `order` and `limit` a PostgREST GET carries. */
  private select(table: string, params: URLSearchParams): Row[] {
    let rows = [...this.rows(table)];
    for (const [key, value] of params) {
      if (key === 'select' || key === 'limit' || key === 'order') continue;
      const eq = value.match(/^eq\.(.*)$/);
      if (!eq) throw new Error(`fake backend: unsupported filter ${key}=${value}`);
      rows = rows.filter((row) => String(row[key]) === eq[1]);
    }
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

  /** Cloudflare KV "write key-value pair": requires the account's API token. */
  private async handleKv(request: Request, accountId: string, namespaceId: string, key: string): Promise<Response> {
    const failure = this.failures.get('kv');
    if (failure) return respondWithFailure(failure, 'kv');
    if (request.method !== 'PUT') throw new Error(`fake backend: unsupported KV method ${request.method}`);
    if (request.headers.get('Authorization') !== `Bearer ${this.cloudflareToken}`) {
      return json(403, { success: false, errors: [{ code: 10000, message: 'Authentication error' }] });
    }
    this.kv.set(`${accountId}/${namespaceId}/${key}`, {
      value: await request.text(),
      contentType: request.headers.get('Content-Type'),
    });
    return json(200, { success: true, errors: [], messages: [], result: null });
  }
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
