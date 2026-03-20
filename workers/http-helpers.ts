// HTTP Protocol-related constants

// Response content type
export const JSON_CONTENT_TYPE = 'application/json; charset=utf-8';

// Default CORS origins (production only)
// Override via ALLOWED_ORIGINS_JSON environment variable
const DEFAULT_ALLOWED_ORIGINS = [
  'https://integritystudio.ai',
  'https://www.integritystudio.ai',
];

// CORS headers for Flutter web app - restricted to configured origins
// Use DEFAULT_ALLOWED_ORIGINS if env var not set
export const ALLOWED_ORIGINS = DEFAULT_ALLOWED_ORIGINS;

/**
 * Get allowed origins from environment, falling back to defaults.
 * Supports both hardcoded defaults and environment-based configuration.
 *
 * @param env - Environment object with optional ALLOWED_ORIGINS_JSON
 * @returns Array of allowed origins
 * @throws SyntaxError if ALLOWED_ORIGINS_JSON is invalid JSON
 */
export function getAllowedOrigins(env?: { ALLOWED_ORIGINS_JSON?: string }): string[] {
  if (env?.ALLOWED_ORIGINS_JSON) {
    try {
      const origins = JSON.parse(env.ALLOWED_ORIGINS_JSON);
      if (!Array.isArray(origins)) {
        return DEFAULT_ALLOWED_ORIGINS;
      }
      return origins;
    } catch {
      // Invalid JSON, fall back to defaults
      return DEFAULT_ALLOWED_ORIGINS;
    }
  }
  return DEFAULT_ALLOWED_ORIGINS;
}
