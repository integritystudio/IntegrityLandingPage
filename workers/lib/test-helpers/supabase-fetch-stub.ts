/**
 * Fetch stub for driving a real `createSupabaseClient` in tests.
 *
 * Tests that mock the Supabase client itself cannot see bugs inside the client
 * — filter serialization, Prefer headers, status handling — so route and admin
 * tests build a real client and stub the transport underneath it instead.
 *
 * Routes are keyed `"<METHOD> <table>"`, e.g. `"GET organization_memberships"`
 * or `"POST rpc/increment_usage"`. An unstubbed request is recorded in
 * `unexpected` and answered with 501 so the failure names the missing route
 * rather than surfacing as a generic error.
 */

export const TEST_SUPABASE_URL = 'https://test.supabase.co';
export const TEST_SERVICE_ROLE_KEY = 'test-service-role-key';

const REST_PREFIX = '/rest/v1/';
const UNSTUBBED_STATUS = 501;

export interface RecordedRequest {
  method: string;
  table: string;
  url: URL;
  headers: Record<string, string>;
  /** Parsed JSON body, or undefined for bodyless requests. */
  body: unknown;
}

/** A canned Response, or a factory invoked per matching request. */
export type RouteResponder = Response | ((request: RecordedRequest) => Response);

export interface SupabaseFetchStub {
  fetch: typeof fetch;
  /** Every request the client issued, in order. */
  requests: RecordedRequest[];
  /** Requests with no matching route — assert this is empty when it matters. */
  unexpected: RecordedRequest[];
  /** First recorded request for a method/table pair. */
  find(method: string, table: string): RecordedRequest | undefined;
  /** All recorded requests for a method/table pair. */
  findAll(method: string, table: string): RecordedRequest[];
}

/** 200 with a JSON array — the shape PostgREST returns for a select. */
export function okRows(rows: unknown[]): RouteResponder {
  return () => jsonResponse(rows, 200);
}

/** 201 with the inserted rows, as returned under Prefer: return=representation. */
export function createdRows(rows: unknown[]): RouteResponder {
  return () => jsonResponse(rows, 201);
}

/** 200 with the updated rows, as returned under Prefer: return=representation. */
export function updatedRows(rows: unknown[]): RouteResponder {
  return () => jsonResponse(rows, 200);
}

/** 204, the PostgREST response when no representation is requested. */
export function noContent(): RouteResponder {
  return () => new Response(null, { status: 204 });
}

/** A non-2xx response, for exercising error paths. */
export function httpError(status: number, message = 'stubbed failure'): RouteResponder {
  return () => new Response(message, { status });
}

function jsonResponse(payload: unknown, status: number): Response {
  return new Response(JSON.stringify(payload), {
    status,
    headers: { 'content-type': 'application/json' },
  });
}

function routeKey(method: string, table: string): string {
  return `${method.toUpperCase()} ${table}`;
}

function tableFromUrl(url: URL): string {
  const path = url.pathname.startsWith(REST_PREFIX)
    ? url.pathname.slice(REST_PREFIX.length)
    : url.pathname;
  return decodeURIComponent(path);
}

function headersToObject(init?: RequestInit): Record<string, string> {
  const raw = init?.headers;
  if (!raw) return {};
  return raw instanceof Headers
    ? Object.fromEntries(raw.entries())
    : { ...(raw as Record<string, string>) };
}

function parseBody(init?: RequestInit): unknown {
  if (typeof init?.body !== 'string') return undefined;
  try {
    return JSON.parse(init.body);
  } catch {
    return init.body;
  }
}

export function createSupabaseFetchStub(
  routes: Record<string, RouteResponder> = {},
): SupabaseFetchStub {
  const requests: RecordedRequest[] = [];
  const unexpected: RecordedRequest[] = [];

  const stubFetch = (async (input: URL | RequestInfo, init?: RequestInit) => {
    const url = new URL(String(input));
    const recorded: RecordedRequest = {
      method: (init?.method ?? 'GET').toUpperCase(),
      table: tableFromUrl(url),
      url,
      headers: headersToObject(init),
      body: parseBody(init),
    };
    requests.push(recorded);

    const responder = routes[routeKey(recorded.method, recorded.table)];
    if (!responder) {
      unexpected.push(recorded);
      const key = routeKey(recorded.method, recorded.table);
      console.error(`[supabase-fetch-stub] no route for "${key}" (${url})`);
      return new Response(`no stub for "${key}"`, { status: UNSTUBBED_STATUS });
    }

    return typeof responder === 'function' ? responder(recorded) : responder.clone();
  }) as typeof fetch;

  return {
    fetch: stubFetch,
    requests,
    unexpected,
    find: (method, table) =>
      requests.find(r => r.method === method.toUpperCase() && r.table === table),
    findAll: (method, table) =>
      requests.filter(r => r.method === method.toUpperCase() && r.table === table),
  };
}
