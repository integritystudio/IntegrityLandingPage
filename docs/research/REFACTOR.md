# Cloudflare Workers Refactoring: Replace Custom Validation with Zod

> **Research record — implemented.** The shared Zod validation layer proposed here shipped in `workers/lib/http/*` and `workers/lib/validation/*` (Zod v4). Condensed from the original proposal; see [changelog 1.3](../changelog/1.3/CHANGELOG.md) "Superseded Design-Doc Reconciliation".

**Original date:** 2026-07-12 · **Domain:** Worker validation

## Problem

The contact-form, sender-worker, and receiver-worker each duplicated validation logic:
- Hand-written regex patterns for email and length checks
- Manual error message formatting
- No type inference from validation rules

Zod addresses all three: type-safe schemas with automatic TypeScript inference, composable/reusable validators, standardized error formatting, and less code to maintain.

## Target Module Structure

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
  contact-form/src/index.ts
  sender-worker/src/index.ts
  receiver-worker/src/index.ts
```

## Core Pieces

**`http/`** owns only transport concerns — response/error factories (`json`, `ok`, `created`, `badRequest`...`serverError`, `withErrorHandling`), request parsing (`isJsonRequest`, `parseJson`, `safeParseJson`, `requireJson`, bearer-token and query-param helpers, `assertMethod`), and CORS (`corsHeaders`, `withCors`, `handleOptions`). No validation-library coupling — portable to other projects.

**`validation/`** owns Zod: schema definitions live in one file (`schemas.ts`), and `parse.ts` converts Zod errors into API responses:

```ts
export async function requireValidJson<T>(
  request: Request,
  schema: ZodSchema<T>,
): Promise<{ ok: true; data: T } | { ok: false; error: Response }> {
  if (!isJsonRequest(request)) {
    return { ok: false, error: badRequest("Expected content-type: application/json") };
  }
  let raw: unknown;
  try {
    raw = await request.json();
  } catch {
    return { ok: false, error: badRequest("Request body must be valid JSON") };
  }
  const result = schema.safeParse(raw);
  if (!result.success) {
    return { ok: false, error: zodValidationError(result.error) };
  }
  return { ok: true, data: result.data };
}
```

`zodValidationError` reshapes Zod's `issues` array into a stable `{ path, message, code }` list rather than leaking raw Zod internals through the API.

## Example: Contact Form (Before/After Shape)

```ts
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

Route handler becomes a single call:

```ts
const parsed = await requireValidJson(request, contactFormSchema);
if (!parsed.ok) return parsed.error;
const body = parsed.data; // fully typed
```

## Key Improvements

| Aspect | Before | After |
|--------|--------|-------|
| **Validation** | Hand-written regex + checks | Zod schemas |
| **Type safety** | Manual `interface`s | Automatic `z.infer<>` |
| **Error format** | Custom strings | Standardized Zod errors |
| **Reuse** | Copy-paste patterns | Import schema, use everywhere |
| **Maintenance** | Bug-prone regexes | Single source of truth |

## Why This Split Is Better

Keeping `http/` free of validation-library coupling means it stays reusable across all routes and portable to other projects. Keeping `validation/` as the sole owner of Zod means errors are converted to API responses in one place, schemas have one home, and the library is easy to replace or expand later. This keeps route handlers thin and boring — which is exactly what's wanted in Workers, where every extra branch is code that has to be re-verified per request path.

## Zod API Note

Use the chained form for cross-version compatibility:

```ts
z.string().trim().email()   // works across Zod versions
```

not the newer top-level form (`z.email().trim()`), which only works in newer Zod releases.
