/**
 * E2E test constants.
 *
 * Centralized named constants for timeout durations, viewport coordinates,
 * and scroll values used across e2e test specs.
 */

// ---------------------------------------------------------------------------
// Timeout durations (milliseconds)
// ---------------------------------------------------------------------------

/**
 * Maximum time for Flutter to fully initialize after navigation.
 *
 * Set to 120s to accommodate slower production CDN loads. Local dev server
 * is typically <10s; production CanvasKit routes can take 60-90s on cold
 * requests (#78).
 */
export const FLUTTER_INIT_TIMEOUT_MS = 120_000;

/** Maximum time for a route change (URL update) to complete. */
export const ROUTE_CHANGE_TIMEOUT_MS = 10_000;

/**
 * Maximum time for Flutter to re-render after a route change.
 *
 * Note: this is a separate guard applied after the URL-change guard
 * (`ROUTE_CHANGE_TIMEOUT_MS`). It intentionally has a longer ceiling to
 * account for slow CanvasKit paint after navigation, and is independent
 * of any caller-supplied timeout passed to `waitForRoute`.
 */
export const ROUTE_RENDER_TIMEOUT_MS = 30_000;

/**
 * Global per-test timeout budget.
 *
 * Must exceed FLUTTER_INIT_TIMEOUT_MS by enough to run the test body.
 * 180s = 120s max Flutter init + 60s headroom (#78).
 */
export const TEST_TIMEOUT_MS = 180_000;

/** Timeout for expect() assertions. */
export const EXPECT_TIMEOUT_MS = 15_000;

/** Maximum time for a single Playwright action (click, fill, etc.). */
export const ACTION_TIMEOUT_MS = 30_000;

/** Maximum time for page.goto() and other navigation calls. */
export const NAVIGATION_TIMEOUT_MS = 60_000;

/** Maximum time for the local Flutter dev server to start. */
export const WEB_SERVER_STARTUP_TIMEOUT_MS = 120_000;

/** Settle time after a mouse click before taking assertions. */
export const CLICK_SETTLE_MS = 3_000;

/** Settle time after a keypress before taking assertions. */
export const KEY_SETTLE_MS = 500;

/** Settle time after a scroll action before taking assertions. */
export const SCROLL_SETTLE_MS = 2_000;

/** Maximum time for Flutter semantics tree to attach after enablement. */
export const SEMANTICS_TIMEOUT_MS = 30_000;

// ---------------------------------------------------------------------------
// Navigation bar pixel coordinates
// (desktop 1280×720 viewport, Flutter CanvasKit rendering)
// ---------------------------------------------------------------------------

/** Y coordinate of the navigation bar hit area (top ~25px). */
export const NAV_Y = 25;

/** X coordinate of the Pricing navigation link. */
export const NAV_PRICING_X = 500;

/** X coordinate of the "Get Started" CTA button in the nav bar. */
export const NAV_CTA_X = 610;

// ---------------------------------------------------------------------------
// Scroll
// ---------------------------------------------------------------------------

/** Pixel distance for a standard programmatic scroll. */
export const SCROLL_DELTA_PX = 500;

// ---------------------------------------------------------------------------
// Screenshot output paths
// ---------------------------------------------------------------------------

export const SCREENSHOT_LANDING = 'screenshots/01-landing.png';
export const SCREENSHOT_CONTENT = 'screenshots/02-content.png';
export const SCREENSHOT_BEFORE_NAV_CLICK = 'screenshots/03-before-click.png';
export const SCREENSHOT_AFTER_NAV_CLICK = 'screenshots/03-after-click.png';
export const SCREENSHOT_BEFORE_CTA_CLICK = 'screenshots/04-before-cta.png';
export const SCREENSHOT_AFTER_CTA_CLICK = 'screenshots/04-after-cta.png';
export const SCREENSHOT_KEYBOARD_NAV = 'screenshots/05-keyboard-nav.png';
export const SCREENSHOT_BEFORE_SCROLL = 'screenshots/06-before-scroll.png';
export const SCREENSHOT_AFTER_SCROLL = 'screenshots/06-after-scroll.png';

// ---------------------------------------------------------------------------
// Site identity (env-overridable to support staging/dev runs)
// ---------------------------------------------------------------------------

/**
 * Canonical production site URL.
 *
 * Override via BASE_URL env var when running against staging/dev so that
 * SEO canonical/og:url assertions reflect the correct origin.
 */
export const SITE_URL = process.env['BASE_URL'] ?? 'https://integritystudio.ai';

/** Human-readable site name used in og:site_name and author meta. */
export const SITE_NAME = process.env['SITE_NAME'] ?? 'Integrity Studio';

/**
 * Contact form Cloudflare Worker URL.
 *
 * Override via CONTACT_WORKER_URL env var in CI or local runs that target
 * a staging worker instead of the production endpoint.
 */
export const CONTACT_WORKER_URL =
  process.env['CONTACT_WORKER_URL'] ??
  'https://integrity-studio-contact.alyshia-b38.workers.dev';

// ---------------------------------------------------------------------------
// Consent / Tracking (must match Dart-side values)
// ---------------------------------------------------------------------------

/** localStorage key for ConsentManager (consent_manager.dart `_storageKey`). */
export const CONSENT_STORAGE_KEY = 'integrity_cookie_consent';

/** GTM container ID (tracking_web.dart `gtmContainerId`). */
export const GTM_CONTAINER_ID = 'GTM-NLLQ5ZM3';

/** Facebook Pixel ID (tracking_web.dart `fbPixelId`). */
export const FB_PIXEL_ID = '2038045626963282';

/** Settle time for GTM script injection after consent-triggered reload. */
export const GTM_INJECT_SETTLE_MS = 5_000;

// ---------------------------------------------------------------------------
// HTTP status codes
// ---------------------------------------------------------------------------

export const HTTP_OK = 200;
export const HTTP_BAD_REQUEST = 400;
export const HTTP_FORBIDDEN = 403;
export const HTTP_METHOD_NOT_ALLOWED = 405;
export const HTTP_UNPROCESSABLE_ENTITY = 422;
export const HTTP_TOO_MANY_REQUESTS = 429;
export const HTTP_SERVICE_UNAVAILABLE = 503;

// ---------------------------------------------------------------------------
// HTTP header names and content types
// (lowercase — HTTP is case-insensitive; Playwright normalizes response headers)
// ---------------------------------------------------------------------------

/** MIME type for JSON request bodies and responses. */
export const CONTENT_TYPE_JSON = 'application/json';

export const HEADER_CONTENT_TYPE = 'content-type';
export const HEADER_ORIGIN = 'origin';
export const HEADER_ALLOW_ORIGIN = 'access-control-allow-origin';
export const HEADER_ALLOW_METHODS = 'access-control-allow-methods';
export const HEADER_REQUEST_METHOD = 'access-control-request-method';
export const HEADER_REQUEST_HEADERS = 'access-control-request-headers';
export const HEADER_CSRF_TOKEN = 'x-csrf-token';

// ---------------------------------------------------------------------------
// Origin gating test fixtures
// ---------------------------------------------------------------------------

/** Unauthorized origin used in origin-gating and CORS rejection tests. */
export const MALICIOUS_ORIGIN = 'https://malicious.example.com';
