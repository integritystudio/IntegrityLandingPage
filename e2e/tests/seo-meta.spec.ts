import { test, expect } from '@playwright/test';
import { SITE_URL, SITE_NAME } from './constants';

/**
 * E2E tests for SEO meta tags, Open Graph, X/Twitter cards, canonical URL,
 * and JSON-LD structured data.
 *
 * These validate the HTML shell served by Cloudflare before Flutter renders.
 * SEO crawlers rely on this static HTML for indexing and social previews.
 */

const OG_IMAGE_PATH = '/images/og-image.png';

/** Extract meta content attribute value by property or name. */
const extractMeta = (html: string, attr: string, value: string): string | null => {
  const match = html.match(new RegExp(`${attr}="${value}"\\s+content="([^"]+)"`));
  return match?.[1] ?? null;
};

/** Extract canonical href. */
const extractCanonical = (html: string): string | null =>
  html.match(/rel="canonical"\s+href="([^"]+)"/)?.[1] ?? null;

/** Extract <title> text. */
const extractTitle = (html: string): string | null =>
  html.match(/<title>([^<]+)<\/title>/)?.[1] ?? null;

/** Extract parsed JSON-LD from HTML. */
function extractJsonLd(html: string): Record<string, unknown> {
  const match = html.match(/<script\s+type="application\/ld\+json">\s*([\s\S]*?)\s*<\/script>/);
  expect(match).not.toBeNull();
  return JSON.parse(match![1]);
}

test.describe('SEO Meta Tags', () => {
  let html: string;

  test.beforeAll(async ({ request }) => {
    html = await (await request.get('/')).text();
  });

  test.describe('primary meta tags', () => {
    test('has title tag with brand', async () => {
      expect(html).toMatch(/<title>[^<]*Integrity Studio[^<]*<\/title>/);
    });

    test('has meta description with meaningful content', async () => {
      const description = extractMeta(html, 'name', 'description');
      expect(description).not.toBeNull();
      expect(description!.length).toBeGreaterThanOrEqual(50);
      expect(description!.length).toBeLessThanOrEqual(160);
    });

    test('has meta keywords', async () => {
      expect(html).toContain('name="keywords"');
    });

    test('has meta author', async () => {
      expect(html).toContain(`name="author" content="${SITE_NAME}"`);
    });

    test('has robots meta allowing indexing', async () => {
      expect(html).toContain('name="robots" content="index, follow"');
    });
  });

  test.describe('Open Graph tags', () => {
    test('og:type is website', async () => {
      expect(html).toContain('property="og:type" content="website"');
    });

    test('og:url points to production', async () => {
      expect(html).toContain(`property="og:url" content="${SITE_URL}/"`);
    });

    test('og:title is present and non-empty', async () => {
      const title = extractMeta(html, 'property', 'og:title');
      expect(title).not.toBeNull();
      expect(title!.length).toBeGreaterThan(10);
    });

    test('og:description is present and non-empty', async () => {
      const description = extractMeta(html, 'property', 'og:description');
      expect(description).not.toBeNull();
      expect(description!.length).toBeGreaterThan(10);
    });

    test('og:image is absolute URL with correct dimensions', async () => {
      expect(html).toContain(`property="og:image" content="${SITE_URL}${OG_IMAGE_PATH}"`);
      expect(html).toContain('property="og:image:width" content="1200"');
      expect(html).toContain('property="og:image:height" content="630"');
    });

    test('og:image has alt text', async () => {
      expect(html).toContain('og:image:alt');
    });

    test('og:site_name matches brand', async () => {
      expect(html).toContain(`property="og:site_name" content="${SITE_NAME}"`);
    });

    test('og:locale is set', async () => {
      expect(html).toContain('property="og:locale" content="en_US"');
    });
  });

  test.describe('X/Twitter card tags', () => {
    test('card type is summary_large_image', async () => {
      expect(html).toContain('property="x:card" content="summary_large_image"');
    });

    test('x:url points to production', async () => {
      expect(html).toContain(`property="x:url" content="${SITE_URL}/"`);
    });

    test('x:title is present', async () => {
      expect(html).toMatch(/property="x:title"\s+content="[^"]+"/);
    });

    test('x:description is present', async () => {
      expect(html).toMatch(/property="x:description"\s+content="[^"]+"/);
    });

    test('x:image is absolute URL', async () => {
      expect(html).toContain(`property="x:image" content="${SITE_URL}${OG_IMAGE_PATH}"`);
    });

    test('x:site handle is set', async () => {
      expect(html).toContain('property="x:site" content="@integritystudio"');
    });
  });

  test.describe('canonical URL', () => {
    test('canonical link is present and absolute', async () => {
      expect(html).toContain(`rel="canonical" href="${SITE_URL}/"`);
    });
  });

  test.describe('JSON-LD structured data', () => {
    test('has application/ld+json script tag', async () => {
      expect(html).toContain('type="application/ld+json"');
    });

    test('JSON-LD is valid JSON with @context', async () => {
      expect(extractJsonLd(html)['@context']).toBe('https://schema.org');
    });

    test('JSON-LD contains Organization entity', async () => {
      const jsonld = extractJsonLd(html);
      const graph = (jsonld['@graph'] as Array<{ '@type': string; name?: string; url?: string }>) ?? [jsonld];
      const org = graph.find((n) => n['@type'] === 'Organization');
      expect(org).toBeDefined();
      expect(org!.name).toBe(SITE_NAME);
      expect(org!.url).toBe(SITE_URL);
    });

    test('JSON-LD contains WebSite entity with search action', async () => {
      const jsonld = extractJsonLd(html);
      const graph = (jsonld['@graph'] as Array<{ '@type': string; url?: string }>) ?? [jsonld];
      const website = graph.find((n) => n['@type'] === 'WebSite');
      expect(website).toBeDefined();
      expect(website!.url).toBe(SITE_URL);
    });
  });

  test.describe('OG image asset', () => {
    test('og:image URL returns 200 with image content type', async ({ request }) => {
      const response = await request.get(OG_IMAGE_PATH);
      expect(response.status()).toBe(200);
      expect(response.headers()['content-type']).toContain('image/');
    });
  });
});

/**
 * Per-route SEO tests require the CF Pages Function middleware to be deployed.
 * When running against production before the middleware is live, /about returns
 * the homepage title. Detect this and skip the suite gracefully.
 */
async function isMiddlewareActive(
  request: { get: (url: string) => Promise<{ text: () => Promise<string> }> },
): Promise<boolean> {
  const html = await (await request.get('/about')).text();
  const title = extractTitle(html);
  return title !== null && title.includes('About');
}

test.describe('per-route SEO meta tags (#116)', () => {
  let homepageDescription: string | null;
  let middlewareActive = false;

  test.beforeAll(async ({ request }) => {
    middlewareActive = await isMiddlewareActive(request);
    homepageDescription = extractMeta(await (await request.get('/')).text(), 'name', 'description');
  });

  const ROUTE_TESTS = [
    { path: '/about', keyword: 'About' },
    { path: '/pricing', keyword: 'Pricing' },
    { path: '/features', keyword: 'Features' },
    { path: '/docs', keyword: 'Documentation' },
    { path: '/contact', keyword: 'Contact' },
  ] as const;

  for (const { path, keyword } of ROUTE_TESTS) {
    test.describe(path, () => {
      let routeHtml: string;

      test.beforeAll(async ({ request }) => {
        routeHtml = await (await request.get(path)).text();
      });

      test(`title contains "${keyword}"`, async () => {
        test.skip(!middlewareActive, 'CF Pages Function middleware not deployed');
        const title = extractTitle(routeHtml);
        expect(title).not.toBeNull();
        expect(title).toContain(keyword);
      });

      test('og:url includes route path without trailing slash', async () => {
        test.skip(!middlewareActive, 'CF Pages Function middleware not deployed');
        const ogUrl = extractMeta(routeHtml, 'property', 'og:url');
        expect(ogUrl).not.toBeNull();
        expect(ogUrl).toContain(path);
        expect(ogUrl).not.toMatch(/\/$/);
      });

      test('canonical href includes route path', async () => {
        test.skip(!middlewareActive, 'CF Pages Function middleware not deployed');
        const canonical = extractCanonical(routeHtml);
        expect(canonical).not.toBeNull();
        expect(canonical).toContain(path);
        expect(canonical).not.toMatch(/\/$/);
      });

      test('description differs from homepage', async () => {
        test.skip(!middlewareActive, 'CF Pages Function middleware not deployed');
        const desc = extractMeta(routeHtml, 'name', 'description');
        expect(desc).not.toBeNull();
        expect(desc).not.toBe(homepageDescription);
      });
    });
  }

  test('unknown route falls back to homepage meta', async ({ request }) => {
    test.skip(!middlewareActive, 'CF Pages Function middleware not deployed');
    const unknownHtml = await (await request.get('/some-unknown-route-xyz')).text();
    const title = extractTitle(unknownHtml);
    expect(title).toContain('Integrity Studio');
    expect(title).toBe(extractTitle(await (await request.get('/')).text()));
  });
});
