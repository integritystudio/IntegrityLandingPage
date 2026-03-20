export type JsonValue =
  | string
  | number
  | boolean
  | null
  | JsonValue[]
  | { [key: string]: JsonValue };

export type JsonObject = Record<string, JsonValue>;

const JSON_CONTENT_TYPE = 'application/json; charset=utf-8';

export function json(data: JsonValue | JsonObject, init: ResponseInit = {}): Response {
  const headers = new Headers(init.headers);
  if (!headers.has('content-type')) {
    headers.set('content-type', JSON_CONTENT_TYPE);
  }
  return new Response(JSON.stringify(data), { ...init, headers });
}

export function text(body: string, init: ResponseInit = {}): Response {
  const headers = new Headers(init.headers);
  if (!headers.has('content-type')) {
    headers.set('content-type', 'text/plain; charset=utf-8');
  }
  return new Response(body, { ...init, headers });
}

export function html(body: string, init: ResponseInit = {}): Response {
  const headers = new Headers(init.headers);
  if (!headers.has('content-type')) {
    headers.set('content-type', 'text/html; charset=utf-8');
  }
  return new Response(body, { ...init, headers });
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

export function redirect(location: string, status = 302): Response {
  return new Response(null, { status, headers: { location } });
}
