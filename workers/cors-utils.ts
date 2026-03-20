import { ALLOWED_ORIGINS } from './http-helpers';

/**
 * Build CORS response headers for a given origin.
 * Credentials are enabled only for allowed origins.
 *
 * @param origin - The Origin header value
 * @param methods - Comma-separated allowed methods (default: 'POST, OPTIONS')
 * @param headers - Comma-separated allowed headers (default: 'Content-Type')
 */
export function buildCorsHeaders(
  origin: string,
  methods: string = 'POST, OPTIONS',
  headers: string = 'Content-Type',
): Record<string, string> {
  const result: Record<string, string> = {
    'access-control-allow-origin': origin,
    'access-control-allow-methods': methods,
    'access-control-allow-headers': headers,
    'access-control-max-age': '86400',
  };

  // Only allow credentials for origins in the allowlist
  if (isOriginAllowed(origin)) {
    result['access-control-allow-credentials'] = 'true';
  }

  return result;
}

/**
 * Check if an origin is in the allowed origins list.
 */
export function isOriginAllowed(origin: string | null): boolean {
  return origin ? ALLOWED_ORIGINS.includes(origin) : false;
}
