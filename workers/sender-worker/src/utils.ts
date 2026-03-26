import { HEADER_NAMES, CONTENT_TYPES, CORS_HEADERS, HTTP_STATUS } from "./types.js";

export function json(data: unknown, init: ResponseInit = {}): Response {
  return new Response(JSON.stringify(data), {
    ...init,
    headers: {
      [HEADER_NAMES.CONTENT_TYPE]: CONTENT_TYPES.JSON,
      ...CORS_HEADERS,
      ...(init.headers as Record<string, string> ?? {}),
    },
  });
}

export function errorResponse(error: string, code: string, status: number): Response {
  return json({ error, code }, { status });
}

export function corsPreflightResponse(): Response {
  return new Response(null, {
    status: HTTP_STATUS.NO_CONTENT,
    headers: CORS_HEADERS,
  });
}
