export type JsonValue =
  | string
  | number
  | boolean
  | null
  | JsonValue[]
  | { [key: string]: JsonValue };

export type JsonObject = Record<string, JsonValue>;

const CONTENT_TYPES = {
  json: 'application/json; charset=utf-8',
  text: 'text/plain; charset=utf-8',
  html: 'text/html; charset=utf-8',
} as const;

function withContentType(init: ResponseInit, contentType: string): Headers {
  const headers = new Headers(init.headers);
  if (!headers.has('content-type')) headers.set('content-type', contentType);
  return headers;
}

export function json(data: JsonValue | JsonObject, init: ResponseInit = {}): Response {
  return new Response(JSON.stringify(data), {
    ...init,
    headers: withContentType(init, CONTENT_TYPES.json),
  });
}

export function text(body: string, init: ResponseInit = {}): Response {
  return new Response(body, { ...init, headers: withContentType(init, CONTENT_TYPES.text) });
}

export function html(body: string, init: ResponseInit = {}): Response {
  return new Response(body, { ...init, headers: withContentType(init, CONTENT_TYPES.html) });
}

export function ok(data: JsonValue | JsonObject, init: ResponseInit = {}): Response {
  return json(data, { ...init, status: 200 });
}

export function created(data: JsonValue | JsonObject, init: ResponseInit = {}): Response {
  return json(data, { ...init, status: 201 });
}

export function noContent(init: ResponseInit = {}): Response {
  return new Response(null, { ...init, status: 204 });
}

/**
 * Redirect response.
 * IMPORTANT: location MUST NOT contain user-controlled input.
 * Validate with URL/path parsing before passing.
 */
export function redirect(location: string, status = 302): Response {
  if (/^[a-z][a-z0-9+.-]*:/i.test(location) && !location.startsWith('/')) {
    throw new Error('redirect: absolute URLs not allowed, use relative paths only');
  }
  return new Response(null, { status, headers: { location } });
}
