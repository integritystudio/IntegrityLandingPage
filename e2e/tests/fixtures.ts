import { test as base } from '@playwright/test';
import { ANALYTICS_HOST_SUFFIXES, GOOGLE_TAG_GATEWAY_PATH } from './constants';

export { expect } from '@playwright/test';

function isAnalyticsUrl(url: URL): boolean {
  return (
    url.pathname.startsWith(GOOGLE_TAG_GATEWAY_PATH) ||
    ANALYTICS_HOST_SUFFIXES.some((h) => url.hostname === h || url.hostname.endsWith(`.${h}`))
  );
}

/**
 * Specs run against production, so unblocked analytics would report every run as
 * real visitors. Requests are aborted rather than fulfilled empty: the Cloudflare
 * beacon is SRI-pinned and an empty body logs a digest error, whereas
 * `Failed to load resource` is already in every console-error allowlist.
 * `page.on('request')` still observes blocked requests, so consent-gating specs
 * keep their meaning.
 */
export const test = base.extend({
  context: async ({ context }, use) => {
    await context.route(isAnalyticsUrl, (route) => route.abort('blockedbyclient'));
    await use(context);
  },
});
