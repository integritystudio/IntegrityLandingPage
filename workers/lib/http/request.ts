import { badRequest, methodNotAllowed, unauthorized } from './errors';

export function isJsonRequest(request: Request): boolean {
  return (request.headers.get('content-type') ?? '').toLowerCase().includes('application/json');
}

/**
 * Parse the request body as JSON with no schema validation.
 * Returns data as `unknown` — caller must validate the shape.
 * Prefer `requireValidJson` from `lib/validation` for schema-validated payloads.
 */
export async function safeParseJson(
  request: Request,
): Promise<{ ok: true; data: unknown } | { ok: false; error: Response }> {
  try {
    return { ok: true, data: await request.json() };
  } catch {
    return { ok: false, error: badRequest('Request body must be valid JSON') };
  }
}

export async function requireJson<T>(
  request: Request,
): Promise<{ ok: true; data: T } | { ok: false; error: Response }> {
  if (!isJsonRequest(request)) {
    return { ok: false, error: badRequest('Expected content-type: application/json') };
  }
  const result = await safeParseJson(request);
  if (!result.ok) return result;
  return { ok: true, data: result.data as T };
}

export function getBearerToken(request: Request): string | null {
  const auth = request.headers.get('authorization');
  return auth?.match(/^Bearer\s+(.+)$/i)?.[1] ?? null;
}

export function requireBearerToken(
  request: Request,
): { ok: true; token: string } | { ok: false; error: Response } {
  const token = getBearerToken(request);
  if (!token) return { ok: false, error: unauthorized('Missing or invalid Bearer token') };
  return { ok: true, token };
}

export function getSearchParams(request: Request): URLSearchParams {
  return new URL(request.url).searchParams;
}

export function getQueryParam(request: Request, key: string): string | null {
  return getSearchParams(request).get(key);
}

export function getRequiredQueryParam(
  request: Request,
  key: string,
): { ok: true; value: string } | { ok: false; error: Response } {
  const value = getQueryParam(request, key);
  if (value === null) return { ok: false, error: badRequest(`Missing required query parameter: ${key}`) };
  return { ok: true, value };
}

export function getPathname(request: Request): string {
  return new URL(request.url).pathname;
}

export function assertMethod(request: Request, allowedMethods: string[]): Response | null {
  const method = request.method.toUpperCase();
  if (allowedMethods.includes(method)) return null;
  return methodNotAllowed(allowedMethods);
}
