import { ALLOWED_ORIGINS, getAllowedOrigins } from './http-helpers';

/**
 * Build CORS response headers for a given origin.
 * Credentials are enabled only for allowed origins.
 *
 * @param origin - The Origin header value
 * @param methods - Comma-separated allowed methods (default: 'POST, OPTIONS')
 * @param headers - Comma-separated allowed headers (default: 'Content-Type')
 * @param env - Optional environment with ALLOWED_ORIGINS_JSON; when supplied the
 *   credentials flag respects the env-configured allowlist instead of the defaults
 */
export function buildCorsHeaders(
  origin: string,
  methods: string = 'POST, OPTIONS',
  headers: string = 'Content-Type',
  env?: { ALLOWED_ORIGINS_JSON?: string },
): Record<string, string> {
  const allowedOrigins = getAllowedOrigins(env);
  // Only reflect the caller's origin if it is in the allowlist; otherwise fall
  // back to the first allowed origin. This prevents unknown origins from
  // receiving an Access-Control-Allow-Origin that echoes their own value.
  const safeOrigin: string | undefined = allowedOrigins.includes(origin) ? origin : allowedOrigins[0];

  const result: Record<string, string> = {
    'access-control-allow-methods': methods,
    'access-control-allow-headers': headers,
    'access-control-max-age': '86400',
    // Vary: Origin so caches don't serve a response for origin-A to origin-B.
    Vary: 'Origin',
  };

  // An explicitly empty allowlist (`ALLOWED_ORIGINS_JSON = "[]"`) leaves nothing
  // to advertise: it is a valid JSON array, so it survives getAllowedOrigins'
  // parse guards, and `[0]` is then undefined. Omit the header rather than let
  // `undefined` reach a Response constructor as a header value. Omitting it
  // denies CORS, which is what an empty allowlist means.
  if (safeOrigin !== undefined) {
    result['access-control-allow-origin'] = safeOrigin;

    // Credentials are allowed only for origins that matched the allowlist.
    if (safeOrigin === origin) {
      result['access-control-allow-credentials'] = 'true';
    }
  }

  return result;
}

/**
 * Check if an origin is in the allowed origins list (using defaults).
 * For environment-aware checking, use isOriginAllowedWithEnv() instead.
 */
export function isOriginAllowed(origin: string | null): boolean {
  return origin ? ALLOWED_ORIGINS.includes(origin) : false;
}

/**
 * Check if an origin is in the allowed origins list, respecting environment config.
 * Supports ALLOWED_ORIGINS_JSON environment variable for dynamic origin configuration.
 *
 * @param origin - The Origin header value (typically from request headers)
 * @param env - Environment object with optional ALLOWED_ORIGINS_JSON
 * @returns true if origin is allowed, false otherwise
 */
export function isOriginAllowedWithEnv(
  origin: string | null,
  env?: { ALLOWED_ORIGINS_JSON?: string },
): boolean {
  if (!origin) return false;
  const allowedOrigins = getAllowedOrigins(env);
  return allowedOrigins.includes(origin);
}
