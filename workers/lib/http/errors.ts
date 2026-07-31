import { json, type JsonValue, type JsonObject } from './responses';

export function errorResponse(
  status: number,
  message: string,
  details?: JsonValue,
  init: ResponseInit = {},
): Response {
  const body: JsonObject = {
    error: {
      message,
      ...(details !== undefined ? { details } : {}),
    },
  };
  return json(body, { ...init, status });
}

export function badRequest(message = 'Bad Request', details?: JsonValue): Response {
  return errorResponse(400, message, details);
}

export function unauthorized(message = 'Unauthorized', details?: JsonValue): Response {
  return errorResponse(401, message, details);
}

export function forbidden(message = 'Forbidden', details?: JsonValue): Response {
  return errorResponse(403, message, details);
}

export function notFound(message = 'Not Found', details?: JsonValue): Response {
  return errorResponse(404, message, details);
}

export function methodNotAllowed(allowedMethods: string[], message = 'Method Not Allowed'): Response {
  return errorResponse(405, message, { allowedMethods }, {
    headers: { allow: allowedMethods.join(', ') },
  });
}

export function conflict(message = 'Conflict', details?: JsonValue): Response {
  return errorResponse(409, message, details);
}

export function unprocessableEntity(message = 'Unprocessable Entity', details?: JsonValue): Response {
  return errorResponse(422, message, details);
}

export function tooManyRequests(message = 'Too Many Requests', details?: JsonValue): Response {
  return errorResponse(429, message, details);
}

export function serverError(message = 'Internal Server Error', details?: JsonValue): Response {
  return errorResponse(500, message, details);
}

export function serviceUnavailable(message = 'Service Unavailable', details?: JsonValue): Response {
  return errorResponse(503, message, details);
}

export function withErrorHandling(
  handler: (request: Request) => Promise<Response> | Response,
  onError?: (error: unknown) => Response,
) {
  return async (request: Request): Promise<Response> => {
    try {
      return await Promise.resolve(handler(request));
    } catch (error) {
      if (onError) return onError(error);
      console.error('Unhandled request error', error);
      return serverError();
    }
  };
}
