import type { ZodType, ZodError } from 'zod';
import { badRequest, unprocessableEntity } from '../http/errors';
import { isJsonRequest } from '../http/request';

export type ValidResult<T> = { ok: true; data: T } | { ok: false; error: Response };

function formatZodPath(path: (string | number)[]): string {
  if (path.length === 0) return 'root';
  const parts: string[] = [];
  for (const part of path) {
    if (typeof part === 'number') {
      parts.push(`[${part}]`);
    } else if (parts.length === 0) {
      parts.push(part);
    } else {
      parts.push(`.${part}`);
    }
  }
  return parts.join('');
}

export function zodValidationError(error: ZodError): Response {
  return unprocessableEntity('Validation failed', {
    issues: error.issues.map((issue) => ({
      path: formatZodPath(issue.path),
      message: issue.message,
    })),
  });
}

export async function requireValidJson<T>(
  request: Request,
  schema: ZodType<T>,
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
