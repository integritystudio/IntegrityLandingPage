/**
 * CORS for every Worker (BACKLOG.md CR46): one allowlist rule, one header builder.
 *
 * Rules that hold for every caller:
 * - Never `*`, and never the caller's own origin unless it is allowed.
 * - The allowlist is env-driven (`ALLOWED_ORIGINS_JSON`), so dev and production origin
 *   sets differ; the defaults below are production's.
 * - A preview-host rule matches https only, on a `.`-anchored hostname suffix, so
 *   `…pages.dev.attacker.com` and the bare alias do not match.
 * - `Vary: Origin` always, so a cache cannot serve origin A's response to origin B.
 */

// integritystudio.ai stays first: it is the "first allowed" origin sent to unlisted callers.
export const DEFAULT_ALLOWED_ORIGINS: readonly string[] = [
  'https://integritystudio.ai',
  'https://www.integritystudio.ai',
  'https://integritystudio.dev',
  'https://www.integritystudio.dev',
];

const CORS_MAX_AGE_SECONDS = '86400';
const HTTPS_PROTOCOL = 'https:';
const SUBDOMAIN_BOUNDARY = '.';
const WILDCARD = '*';

export interface CorsPolicy {
  /** The Worker's `ALLOWED_ORIGINS_JSON`: a JSON array of exact origins. */
  allowedOriginsJson?: string;
  /** Hostname suffix admitting preview deploys; must start with `.` or it matches nothing. */
  previewHostSuffix?: string;
  allowMethods: string;
  allowHeaders: string;
  /** Send `Access-Control-Allow-Credentials: true` to an allowed origin (cookie-based callers). */
  allowCredentials?: boolean;
  /**
   * Comma-separated list of response-header names the browser JS may read from this origin.
   * Mapped to `Access-Control-Expose-Headers`. Omit when no extra headers need exposing.
   */
  exposeHeaders?: string;
  /**
   * `Access-Control-Allow-Origin` for a caller that is not allowed: the first allowlisted
   * origin (a real value the browser will not match) or no header. Never the caller's own.
   */
  disallowedOriginHeader?: 'first-allowed' | 'omit';
}

export interface CorsDecision {
  /** The caller's origin is on the allowlist or matches the preview rule. */
  allowed: boolean;
  headers: Record<string, string>;
}

/**
 * The allowlist from `ALLOWED_ORIGINS_JSON`, or the production defaults when it is unset
 * or malformed. An explicit `[]` is honoured: it allows no exact origin. A `"*"` entry is
 * dropped, so a wildcard cannot be configured in (a caller sending `Origin: *` would
 * otherwise have it reflected).
 */
export function parseAllowedOrigins(allowedOriginsJson?: string): string[] {
  if (!allowedOriginsJson) return [...DEFAULT_ALLOWED_ORIGINS];
  try {
    const parsed: unknown = JSON.parse(allowedOriginsJson);
    if (Array.isArray(parsed) && parsed.every((v) => typeof v === 'string')) {
      const origins = parsed.filter((origin) => origin !== WILDCARD);
      if (origins.length !== parsed.length) console.error('[cors] ignoring "*" in ALLOWED_ORIGINS_JSON');
      return origins;
    }
    console.error('[cors] ALLOWED_ORIGINS_JSON must be a JSON array of strings; using defaults');
  } catch {
    console.error('[cors] ALLOWED_ORIGINS_JSON is not valid JSON; using defaults');
  }
  return [...DEFAULT_ALLOWED_ORIGINS];
}

function isPreviewOrigin(origin: string, suffix: string | undefined): boolean {
  if (!suffix?.startsWith(SUBDOMAIN_BOUNDARY)) return false;
  let url: URL;
  try {
    url = new URL(origin);
  } catch {
    return false;
  }
  return url.protocol === HTTPS_PROTOCOL && url.hostname.endsWith(suffix);
}

export function isOriginAllowed(
  origin: string | null,
  policy: Pick<CorsPolicy, 'allowedOriginsJson' | 'previewHostSuffix'>,
): boolean {
  if (!origin) return false;
  return parseAllowedOrigins(policy.allowedOriginsJson).includes(origin)
    || isPreviewOrigin(origin, policy.previewHostSuffix);
}

export function buildCors(origin: string | null, policy: CorsPolicy): CorsDecision {
  const allowed = isOriginAllowed(origin, policy);
  const headers: Record<string, string> = {
    'Access-Control-Allow-Methods': policy.allowMethods,
    'Access-Control-Allow-Headers': policy.allowHeaders,
    'Access-Control-Max-Age': CORS_MAX_AGE_SECONDS,
    Vary: 'Origin',
  };

  const allowOrigin = allowed
    ? origin
    : policy.disallowedOriginHeader === 'first-allowed'
      ? parseAllowedOrigins(policy.allowedOriginsJson)[0]
      : undefined;
  // An explicit `[]` leaves no first-allowed origin; omitting the header denies CORS,
  // which is what an empty allowlist means.
  if (allowOrigin) headers['Access-Control-Allow-Origin'] = allowOrigin;
  if (allowed && policy.allowCredentials) headers['Access-Control-Allow-Credentials'] = 'true';
  if (policy.exposeHeaders) headers['Access-Control-Expose-Headers'] = policy.exposeHeaders;

  return { allowed, headers };
}
