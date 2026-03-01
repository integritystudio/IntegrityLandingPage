/**
 * E2E test constants.
 *
 * Centralized named constants for timeout durations, viewport coordinates,
 * and scroll values used across e2e test specs.
 */

// ---------------------------------------------------------------------------
// Timeout durations (milliseconds)
// ---------------------------------------------------------------------------

/** Maximum time for Flutter to fully initialize after navigation. */
export const FLUTTER_INIT_TIMEOUT_MS = 90_000;

/** Maximum time for a route change to complete. */
export const ROUTE_CHANGE_TIMEOUT_MS = 10_000;

/** Maximum time for Flutter to re-render after a route change. */
export const ROUTE_RENDER_TIMEOUT_MS = 30_000;

/** Settle time after a mouse click before taking assertions. */
export const CLICK_SETTLE_MS = 3_000;

/** Settle time after a keypress before taking assertions. */
export const KEY_SETTLE_MS = 500;

/** Settle time after a scroll action before taking assertions. */
export const SCROLL_SETTLE_MS = 2_000;

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
