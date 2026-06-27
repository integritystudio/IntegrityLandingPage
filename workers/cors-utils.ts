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
  const result: Record<string, string> = {
    'access-control-allow-origin': origin,
    'access-control-allow-methods': methods,
    'access-control-allow-headers': headers,
    'access-control-max-age': '86400',
  };

  // Only allow credentials for origins in the (env-aware) allowlist
  if (isOriginAllowedWithEnv(origin, env)) {
    result['access-control-allow-credentials'] = 'true';
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
