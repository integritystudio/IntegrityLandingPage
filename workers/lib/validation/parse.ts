import type { ZodSchema, ZodTypeAny, ZodError } from 'zod';
import { badRequest, unprocessableEntity } from '../http/errors';
import { isJsonRequest } from '../http/request';

export type ValidResult<T> = { ok: true; data: T } | { ok: false; error: Response };

export type Infer<TSchema extends ZodTypeAny> = TSchema['_output'];

export function zodValidationError(error: ZodError): Response {
  return unprocessableEntity('Validation failed', {
    issues: error.issues.map((issue) => ({
      path:
        issue.path.length === 0
          ? 'root'
          : issue.path
              .map((part) => (typeof part === 'number' ? `[${part}]` : part))
              .join('.')
              .replace('.[', '['),
      message: issue.message,
      code: issue.code,
    })),
  });
}

export async function requireValidJson<T>(
  request: Request,
  schema: ZodSchema<T>,
): Promise<ValidResult<T>> {
  if (!isJsonRequest(request)) {
    return { ok: false, error: badRequest('Expected content-type: application/json') };
  }

  let raw: unknown;
  try {
    raw = await request.json();
  } catch {
    return { ok: false, error: badRequest('Request body must be valid JSON') };
  }

  const result = schema.safeParse(raw);
  if (!result.success) {
    return { ok: false, error: zodValidationError(result.error) };
  }
  return { ok: true, data: result.data };
}
