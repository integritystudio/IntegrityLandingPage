import { badRequest, methodNotAllowed, unauthorized } from './errors';

export function isJsonRequest(request: Request): boolean {
  return (request.headers.get('content-type') ?? '').toLowerCase().includes('application/json');
}

export async function safeParseJson<T>(
  request: Request,
): Promise<{ ok: true; data: T } | { ok: false; error: Response }> {
  try {
    return { ok: true, data: (await request.json()) as T };
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
  return safeParseJson<T>(request);
}

export function getHeader(request: Request, name: string): string | null {
  return request.headers.get(name);
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

export function getQueryParam(request: Request, key: string): string | null {
  return new URL(request.url).searchParams.get(key);
}

export function getRequiredQueryParam(
  request: Request,
  key: string,
): { ok: true; value: string } | { ok: false; error: Response } {
  const value = getQueryParam(request, key);
  if (!value) return { ok: false, error: badRequest(`Missing required query parameter: ${key}`) };
  return { ok: true, value };
}

export function getPathname(request: Request): string {
  return new URL(request.url).pathname;
}

export function assertMethod(request: Request, allowedMethods: string[]): Response | null {
  if (allowedMethods.includes(request.method.toUpperCase())) return null;
  return methodNotAllowed(allowedMethods);
}
