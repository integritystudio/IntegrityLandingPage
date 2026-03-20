# Cloudflare Workers Refactoring: Replace Custom Validation with Zod

## Overview

At this point, the clean move is to **stop reimplementing validation** and just use real **Zod**.

The current approach (contact-form, sender-worker, receiver-worker) duplicates validation logic:
- Hand-written regex patterns for email, length checks
- Manual error message formatting
- No type inference from validation rules

Zod provides:
- Type-safe schemas with automatic TypeScript inference
- Composable, reusable validators
- Standardized error formatting
- Less code to maintain

---

## Proposed File Structure

```txt
workers/
  lib/
    http/
      responses.ts      # json(), ok(), created(), etc.
      request.ts        # parseJson(), requireJson(), getHeader(), etc.
      cors.ts           # corsHeaders(), withCors(), handleOptions()
      errors.ts         # badRequest(), unauthorized(), serverError(), etc.
      index.ts          # Re-exports
    validation/
      schemas.ts        # All Zod schema definitions
      parse.ts          # zodValidationError(), requireValidJson()
      index.ts          # Re-exports
  cors-utils.ts         # CORS utilities (existing)
  http-helpers.ts       # HTTP constants (existing)
  constants.ts          # Service constants (existing)
  contact-form/src/
    index.ts
  sender-worker/src/
    index.ts
  receiver-worker/src/
    index.ts
```

---

## `src/lib/http/responses.ts`

```ts
export type JsonValue =
  | string
  | number
  | boolean
  | JsonValue[]
  | { [key: string]: JsonValue };

export type JsonObject = Record<string, JsonValue>;

const JSON_CONTENT_TYPE = "application/json; charset=utf-8";

export function json(data: JsonValue | JsonObject, init: ResponseInit = {}): Response {
  const headers = new Headers(init.headers);

  if (!headers.has("content-type")) {
    headers.set("content-type", JSON_CONTENT_TYPE);
  }

  return new Response(JSON.stringify(data), {
    ...init,
    headers,
  });
}

export function text(body: string, init: ResponseInit = {}): Response {
  const headers = new Headers(init.headers);

  if (!headers.has("content-type")) {
    headers.set("content-type", "text/plain; charset=utf-8");
  }

  return new Response(body, {
    ...init,
    headers,
  });
}

export function html(body: string, init: ResponseInit = {}): Response {
  const headers = new Headers(init.headers);

  if (!headers.has("content-type")) {
    headers.set("content-type", "text/html; charset=utf-8");
  }

  return new Response(body, {
    ...init,
    headers,
  });
}

export function ok(data: JsonValue | JsonObject, init: ResponseInit = {}): Response {
  return json(data, {
    ...init,
    status: init.status ?? 200,
  });
}

export function created(data: JsonValue | JsonObject, init: ResponseInit = {}): Response {
  return json(data, {
    ...init,
    status: init.status ?? 201,
  });
}

export function noContent(init: ResponseInit = {}): Response {
  return new Response(null, {
    ...init,
    status: init.status ?? 204,
  });
}

export function redirect(location: string, status = 302): Response {
  return new Response(null, {
    status,
    headers: { location },
  });
}
```

---

## `src/lib/http/errors.ts`

```ts
import { json, type JsonValue, type JsonObject } from "./responses";

const DEFAULT_JSON_HEADERS = {
  "content-type": "application/json; charset=utf-8",
};

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

  return json(body, {
    ...init,
    status,
    headers: {
      ...DEFAULT_JSON_HEADERS,
      ...(init.headers ?? {}),
    },
  });
}

export function badRequest(message = "Bad Request", details?: JsonValue): Response {
  return errorResponse(400, message, details);
}

export function unauthorized(message = "Unauthorized", details?: JsonValue): Response {
  return errorResponse(401, message, details);
}

export function forbidden(message = "Forbidden", details?: JsonValue): Response {
  return errorResponse(403, message, details);
}

export function notFound(message = "Not Found", details?: JsonValue): Response {
  return errorResponse(404, message, details);
}

export function methodNotAllowed(
  allowedMethods: string[],
  message = "Method Not Allowed",
): Response {
  return errorResponse(
    405,
    message,
    { allowedMethods },
    {
      headers: {
        allow: allowedMethods.join(", "),
      },
    },
  );
}

export function conflict(message = "Conflict", details?: JsonValue): Response {
  return errorResponse(409, message, details);
}

export function unprocessableEntity(
  message = "Unprocessable Entity",
  details?: JsonValue,
): Response {
  return errorResponse(422, message, details);
}

export function tooManyRequests(
  message = "Too Many Requests",
  details?: JsonValue,
): Response {
  return errorResponse(429, message, details);
}

export function serverError(
  message = "Internal Server Error",
  details?: JsonValue,
): Response {
  return errorResponse(500, message, details);
}

export function withErrorHandling(
  handler: (request: Request) => Promise<Response> | Response,
  onError?: (error: unknown) => Response,
) {
  return async (request: Request): Promise<Response> => {
    try {
      return await handler(request);
    } catch (error) {
      if (onError) {
        return onError(error);
      }

      console.error("Unhandled request error", error);
      return serverError();
    }
  };
}
```

---

## `src/lib/http/request.ts`

```ts
import { badRequest, methodNotAllowed, unauthorized } from "./errors";

export function isJsonRequest(request: Request): boolean {
  const contentType = request.headers.get("content-type") ?? "";
  return contentType.toLowerCase().includes("application/json");
}

export async function parseJson<T>(request: Request): Promise<T> {
  return (await request.json()) as T;
}

export async function safeParseJson<T>(
  request: Request,
): Promise<{ ok: true; data: T } | { ok: false; error: Response }> {
  try {
    const data = (await request.json()) as T;
    return { ok: true, data };
  } catch {
    return {
      ok: false,
      error: badRequest("Request body must be valid JSON"),
    };
  }
}

export async function requireJson<T>(
  request: Request,
): Promise<{ ok: true; data: T } | { ok: false; error: Response }> {
  if (!isJsonRequest(request)) {
    return {
      ok: false,
      error: badRequest("Expected content-type: application/json"),
    };
  }

  return safeParseJson<T>(request);
}

export function getHeader(request: Request, name: string): string | null {
  return request.headers.get(name);
}

export function getBearerToken(request: Request): string | null {
  const auth = request.headers.get("authorization");
  if (!auth) return null;

  const match = auth.match(/^Bearer\s+(.+)$/i);
  return match?.[1] ?? null;
}

export function requireBearerToken(
  request: Request,
): { ok: true; token: string } | { ok: false; error: Response } {
  const token = getBearerToken(request);

  if (!token) {
    return {
      ok: false,
      error: unauthorized("Missing or invalid Bearer token"),
    };
  }

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

  if (!value) {
    return {
      ok: false,
      error: badRequest(`Missing required query parameter: ${key}`),
    };
  }

  return { ok: true, value };
}

export function getPathname(request: Request): string {
  return new URL(request.url).pathname;
}

export function assertMethod(
  request: Request,
  allowedMethods: string[],
): Response | null {
  if (allowedMethods.includes(request.method.toUpperCase())) {
    return null;
  }

  return methodNotAllowed(allowedMethods);
}
```

---

## `src/lib/http/cors.ts`

```ts
export type CorsOptions = {
  origin?: string;
  methods?: string[];
  headers?: string[];
  credentials?: boolean;
  maxAge?: number;
};

export function corsHeaders(options: CorsOptions = {}): Headers {
  const {
    origin = "*",
    methods = ["GET", "POST", "PUT", "PATCH", "DELETE", "OPTIONS"],
    headers = ["content-type", "authorization"],
    credentials = false,
    maxAge = 86400,
  } = options;

  const result = new Headers();
  result.set("access-control-allow-origin", origin);
  result.set("access-control-allow-methods", methods.join(", "));
  result.set("access-control-allow-headers", headers.join(", "));
  result.set("access-control-max-age", String(maxAge));

  if (credentials) {
    result.set("access-control-allow-credentials", "true");
  }

  return result;
}

export function withCors(response: Response, options: CorsOptions = {}): Response {
  const headers = new Headers(response.headers);
  const cors = corsHeaders(options);

  cors.forEach((value, key) => {
    headers.set(key, value);
  });

  return new Response(response.body, {
    status: response.status,
    statusText: response.statusText,
    headers,
  });
}

export function handleOptions(request: Request, options: CorsOptions = {}): Response | null {
  if (request.method.toUpperCase() !== "OPTIONS") {
    return null;
  }

  return new Response(null, {
    status: 204,
    headers: corsHeaders(options),
  });
}
```

---

## `src/lib/http/index.ts`

```ts
export * from "./responses";
export * from "./errors";
export * from "./request";
export * from "./cors";
```

---

## `src/lib/validation/schemas.ts`

```ts
import { z } from "zod";

export { z };

// Place all schema definitions here
// Example:
// export const contactFormSchema = z.object({
//   name: z.string().trim().min(1).max(100),
//   email: z.string().trim().email(),
//   message: z.string().trim().min(1).max(5000),
// });
```

---

## `src/lib/validation/parse.ts`

```ts
import type { ZodSchema, ZodTypeAny } from "zod";
import { badRequest, unprocessableEntity } from "../http/errors";
import { isJsonRequest } from "../http/request";

type ValidResult<T> =
  | { ok: true; data: T }
  | { ok: false; error: Response };

export function zodValidationError(error: {
  issues: Array<{
    path: Array<string | number>;
    message: string;
    code?: string;
  }>;
}): Response {
  return unprocessableEntity("Validation failed", {
    issues: error.issues.map((issue) => ({
      path:
        issue.path.length === 0
          ? "root"
          : issue.path
              .map((part) => (typeof part === "number" ? `[${part}]` : part))
              .join(".")
              .replace(".[", "["),
      message: issue.message,
      code: issue.code ?? "custom",
    })),
  });
}

export async function requireValidJson<T>(
  request: Request,
  schema: ZodSchema<T>,
): Promise<ValidResult<T>> {
  if (!isJsonRequest(request)) {
    return {
      ok: false,
      error: badRequest("Expected content-type: application/json"),
    };
  }

  let raw: unknown;

  try {
    raw = await request.json();
  } catch {
    return {
      ok: false,
      error: badRequest("Request body must be valid JSON"),
    };
  }

  const result = schema.safeParse(raw);

  if (!result.success) {
    return {
      ok: false,
      error: zodValidationError(result.error),
    };
  }

  return {
    ok: true,
    data: result.data,
  };
}

export function validate<T>(schema: ZodSchema<T>, input: unknown): T {
  return schema.parse(input);
}

export type Infer<TSchema extends ZodTypeAny> = TSchema["_output"];
```

---

## `src/lib/validation/index.ts`

```ts
export * from "./schemas";
export * from "./parse";
```

---

## Example: Refactored Contact Form

### `src/lib/validation/schemas.ts` (add)

```ts
import { z } from "zod";

export const contactFormSchema = z
  .object({
    name: z.string().trim().min(1).max(100),
    email: z.string().trim().email(),
    organization: z.string().trim().max(200).optional(),
    companySize: z.string().trim().max(100).optional(),
    useCase: z.string().trim().max(200).optional(),
    message: z.string().trim().max(5000).optional(),
  })
  .strict();

export type ContactFormInput = z.infer<typeof contactFormSchema>;
```

### `src/index.ts` (contact-form)

```ts
import { ok, withErrorHandling } from "./lib/http";
import { requireValidJson, contactFormSchema } from "./lib/validation";

export default {
  async fetch(request: Request, env: Env): Promise<Response> {
    const parsed = await requireValidJson(request, contactFormSchema);

    if (!parsed.ok) {
      return parsed.error;
    }

    const body = parsed.data;

    // Send email with body...
    return ok({
      success: true,
      message: "Thank you for your message! We'll respond within 24 hours.",
    });
  },
};
```

---

## Key Improvements

| Aspect | Before | After |
|--------|--------|-------|
| **Validation** | Hand-written regex + checks | Zod schemas |
| **Type safety** | Manual `interface`s | Automatic `z.infer<>` |
| **Error format** | Custom strings | Standardized Zod errors |
| **Reuse** | Copy-paste patterns | Import schema, use everywhere |
| **Maintenance** | Bug-prone regexes | Single source of truth |

---

## Installation

Add to `package.json`:

```bash
npm install zod
```

---

## Important Zod Note

Use this form for universal compatibility:

```ts
z.string().trim().email()
```

NOT this (only works in newer Zod):

```ts
z.email().trim()
```

---

## Why This Split is Better

**`http/`** — Only transport concerns
- Reusable across all routes
- No validation library coupling
- Portable to other projects

**`validation/`** — Owns Zod
- Converts Zod errors into API responses
- Easy to replace or expand later
- Single place to define all schemas

This keeps route handlers thin and boring, which is ideal for Workers.

---

## Next Steps

1. Create `workers/lib/http/` structure with response, error, request, CORS utilities
2. Create `workers/lib/validation/` structure with Zod schemas and parse helpers
3. Refactor `contact-form` to use `requireValidJson()`
4. Refactor `sender-worker` to use `requireValidJson()`
5. Add type inference throughout with `z.infer<>`
