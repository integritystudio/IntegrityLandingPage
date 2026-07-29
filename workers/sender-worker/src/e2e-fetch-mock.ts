/**
 * Outbound-request mock for the e2e suite.
 *
 * `@cloudflare/vitest-pool-workers` used to export a `fetchMock` (an undici
 * `MockAgent`) from `cloudflare:test`. The Vitest v4 line of the pool removed
 * it — 0.18.8 exports only `env` and `SELF` — so this reimplements the small
 * slice of that API the suite uses, on top of `vi.stubGlobal`. The pool runs
 * the `main` worker in the same isolate as the tests, so a stubbed global
 * `fetch` reaches the worker's outbound calls.
 *
 * Semantics deliberately mirror undici's `MockAgent`:
 * - interceptors are **one-shot**, consumed in registration order, so two
 *   interceptors for the same route serve two sequential calls (the suite
 *   relies on this for the management-token then ROPC `/oauth/token` pair);
 * - `assertNoPendingInterceptors()` throws if any interceptor went unused;
 * - an unmatched request throws rather than reaching the network, so a missing
 *   mock fails loudly instead of silently escaping the test environment.
 *
 * Matching is on origin + pathname + method; query strings are ignored, since
 * the suite declares bare pathnames while callers may append filters.
 */

import { vi } from 'vitest';

const DEFAULT_METHOD = 'GET';

/**
 * Reply body: either a literal string, or — as undici allows — a callback that
 * receives the intercepted request, which the suite uses to capture and assert
 * on outbound payloads. A callback's non-string return value is JSON-encoded.
 */
type ReplyBody = string | ((request: Request) => unknown | Promise<unknown>);

interface Interceptor {
  origin: string;
  path: string;
  method: string;
  status: number;
  body: ReplyBody;
  headers: Record<string, string>;
  consumed: boolean;
  /** Excluded from `assertNoPendingInterceptors()` when true. */
  optional: boolean;
}

interface ReplyOptions {
  headers?: Record<string, string>;
}

const interceptors: Interceptor[] = [];

/** Handle returned by `intercept()`, used to attach the canned response. */
class InterceptorHandle {
  constructor(private readonly interceptor: Interceptor) {}

  reply(status: number, body: ReplyBody, opts: ReplyOptions = {}): InterceptorHandle {
    this.interceptor.status = status;
    this.interceptor.body = body;
    this.interceptor.headers = opts.headers ?? {};
    return this;
  }

  /**
   * Serve this route if it is called, but do not require it. Use for
   * best-effort calls whose count is not part of the contract under test —
   * signup's compensating rollback, for instance, swallows its own failures and
   * may retry a delete through nested catch layers, so pinning an exact number
   * of calls would assert an implementation detail.
   */
  optional(): InterceptorHandle {
    this.interceptor.optional = true;
    return this;
  }
}

/** Handle returned by `get(origin)`, scoping interceptors to one origin. */
class OriginMock {
  constructor(private readonly origin: string) {}

  intercept(opts: { path: string; method?: string }): InterceptorHandle {
    const interceptor: Interceptor = {
      origin: this.origin,
      path: opts.path,
      method: (opts.method ?? DEFAULT_METHOD).toUpperCase(),
      status: 200,
      body: '',
      headers: {},
      consumed: false,
      optional: false,
    };
    interceptors.push(interceptor);
    return new InterceptorHandle(interceptor);
  }
}

function normaliseOrigin(origin: string): string {
  return new URL(origin.includes('://') ? origin : `https://${origin}`).origin;
}

function findInterceptor(method: string, url: URL): Interceptor | undefined {
  return interceptors.find(
    (i) =>
      !i.consumed &&
      i.method === method.toUpperCase() &&
      normaliseOrigin(i.origin) === url.origin &&
      i.path === url.pathname,
  );
}

async function mockedFetch(input: RequestInfo | URL, init?: RequestInit): Promise<Response> {
  const request = input instanceof Request ? input : new Request(input as string | URL, init);
  const url = new URL(request.url);
  const match = findInterceptor(request.method, url);

  if (!match) {
    throw new Error(
      `e2e fetch mock: no interceptor for ${request.method} ${url.origin}${url.pathname} — add one, or the call escaped the test environment`,
    );
  }

  match.consumed = true;

  let body: string;
  if (typeof match.body === 'function') {
    const produced = await match.body(request);
    body = typeof produced === 'string' ? produced : JSON.stringify(produced);
  } else {
    body = match.body;
  }

  return new Response(body, { status: match.status, headers: match.headers });
}

/**
 * Wrap a `Fetcher` so every request carries a distinct `CF-Connecting-IP`.
 *
 * `/signup` and `/signin` are rate limited to `AUTH_RATE_LIMIT_MAX` requests per
 * IP per window, and the in-memory counter lives in worker module scope, which
 * the pool shares across every test in a run. Without a unique IP each request
 * keys to `'unknown'`, so the suite's requests exhaust one bucket and every test
 * past the limit sees `429`. Giving each request its own IP isolates them the
 * way separate clients would be in production — the rate limiter still runs and
 * is still exercised by the tests written for it.
 */
export function withUniqueClientIp(fetcher: Fetcher): Pick<Fetcher, 'fetch'> {
  let counter = 0;
  return {
    fetch(input: RequestInfo | URL, init?: RequestInit): Promise<Response> {
      counter += 1;
      const request = input instanceof Request ? new Request(input, init) : new Request(input as string | URL, init);
      request.headers.set('CF-Connecting-IP', `203.0.113.${counter % 256}`);
      return fetcher.fetch(request);
    },
  };
}

export const fetchMock = {
  /** Install the stubbed global `fetch`. Call once per suite, in `beforeAll`. */
  activate(): void {
    vi.stubGlobal('fetch', mockedFetch);
  },

  /** Remove the stub and drop any registered interceptors. */
  deactivate(): void {
    interceptors.length = 0;
    vi.unstubAllGlobals();
  },

  /** Scope subsequent `intercept()` calls to one origin. */
  get(origin: string): OriginMock {
    return new OriginMock(origin);
  },

  /**
   * Alias of `get`. In undici's `MockAgent`, `get(origin)` selects an
   * interceptable for that origin rather than naming an HTTP verb — parts of the
   * suite call `post(origin)` as though it did, so both spellings scope by
   * origin and the method is taken from `intercept({ method })`.
   */
  post(origin: string): OriginMock {
    return new OriginMock(origin);
  },

  /**
   * Throw if any registered interceptor was never used, then clear the list so
   * one test's leftovers cannot leak into the next. Call in `afterEach`.
   */
  assertNoPendingInterceptors(): void {
    const pending = interceptors.filter((i) => !i.consumed && !i.optional);
    interceptors.length = 0;
    if (pending.length > 0) {
      const described = pending.map((i) => `${i.method} ${i.origin}${i.path}`).join(', ');
      throw new Error(`e2e fetch mock: ${pending.length} interceptor(s) never used: ${described}`);
    }
  },
};
