import { ALLOWED_ORIGINS } from './constants';

/**
 * Build CORS response headers for a given origin.
 * Caller is responsible for origin validation.
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
  return {
    'Access-Control-Allow-Origin': origin,
    'Access-Control-Allow-Methods': methods,
    'Access-Control-Allow-Headers': headers,
    'Vary': 'Origin',
  };
}

/**
 * Check if an origin is in the allowed origins list.
 */
export function isOriginAllowed(origin: string | null): boolean {
  return origin ? ALLOWED_ORIGINS.includes(origin) : false;
}
