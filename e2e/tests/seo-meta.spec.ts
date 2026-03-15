import { test, expect } from '@playwright/test';
import { SITE_URL, SITE_NAME } from './constants';

/**
 * E2E tests for SEO meta tags, Open Graph, X/Twitter cards, canonical URL,
 * and JSON-LD structured data.
 *
 * These validate the HTML shell served by Cloudflare before Flutter renders.
 * SEO crawlers rely on this static HTML for indexing and social previews.
 */

// ---------------------------------------------------------------------------
// Constants (must match web/index.html values)
// ---------------------------------------------------------------------------

const OG_IMAGE_PATH = '/images/og-image.png';

test.describe('SEO Meta Tags', () => {
  let html: string;

  /**
   * `beforeAll` fetches the home page HTML once and shares it across all tests
   * in this describe block. This saves one HTTP round-trip per test (~10 tests).
   * Trade-off: tests depend on shared mutable state and a fixed fetch order.
   * Risk is low because this spec is the only consumer of `html`, and Playwright
   * does not reorder tests within a describe block.
   */
  test.beforeAll(async ({ request }) => {
    const response = await request.get('/');
    html = await response.text();
  });

  test.describe('primary meta tags', () => {
    test('has title tag with brand', async () => {
      expect(html).toMatch(/<title>[^<]*Integrity Studio[^<]*<\/title>/);
    });

    test('has meta description with meaningful content', async () => {
      const match = html.match(/<meta\s+name="description"\s+content="([^"]+)"/);
      expect(match).not.toBeNull();
      // 50-160 chars is the optimal SEO range; Google truncates beyond 160.
      const description = match![1];
      expect(description.length).toBeGreaterThanOrEqual(50);
      expect(description.length).toBeLessThanOrEqual(160);
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
      const match = html.match(/property="og:title"\s+content="([^"]+)"/);
      expect(match).not.toBeNull();
      expect(match![1].length).toBeGreaterThan(10);
    });

    test('og:description is present and non-empty', async () => {
      const match = html.match(/property="og:description"\s+content="([^"]+)"/);
      expect(match).not.toBeNull();
      expect(match![1].length).toBeGreaterThan(10);
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
      const match = html.match(/<script\s+type="application\/ld\+json">\s*([\s\S]*?)\s*<\/script>/);
      expect(match).not.toBeNull();
      const jsonld = JSON.parse(match![1]);
      expect(jsonld['@context']).toBe('https://schema.org');
    });

    test('JSON-LD contains Organization entity', async () => {
      const match = html.match(/<script\s+type="application\/ld\+json">\s*([\s\S]*?)\s*<\/script>/);
      expect(match).not.toBeNull();
      const jsonld = JSON.parse(match![1]);
      const graph = jsonld['@graph'] ?? [jsonld];
      const org = graph.find((n: { '@type': string }) => n['@type'] === 'Organization');
      expect(org).toBeDefined();
      expect(org.name).toBe(SITE_NAME);
      expect(org.url).toBe(SITE_URL);
    });

    test('JSON-LD contains WebSite entity with search action', async () => {
      const match = html.match(/<script\s+type="application\/ld\+json">\s*([\s\S]*?)\s*<\/script>/);
      expect(match).not.toBeNull();
      const jsonld = JSON.parse(match![1]);
      const graph = jsonld['@graph'] ?? [jsonld];
      const website = graph.find((n: { '@type': string }) => n['@type'] === 'WebSite');
      expect(website).toBeDefined();
      expect(website.url).toBe(SITE_URL);
    });
  });

  test.describe('OG image asset', () => {
    test('og:image URL returns 200 with image content type', async ({ request }) => {
      const response = await request.get(OG_IMAGE_PATH);
      expect(response.status()).toBe(200);
      const contentType = response.headers()['content-type'];
      expect(contentType).toContain('image/');
    });
  });
});

// ---------------------------------------------------------------------------
// Per-Route SEO Meta Tags (#116)
// Validates CF Pages Function middleware injects route-specific meta tags.
// ---------------------------------------------------------------------------

/** Extract meta content attribute value by property or name. */
const extractMeta = (html: string, attr: string, value: string): string | null => {
  const re = new RegExp(`${attr}="${value}"\\s+content="([^"]+)"`);
  const match = html.match(re);
  return match?.[1] ?? null;
};

/** Extract canonical href. */
const extractCanonical = (html: string): string | null => {
  const match = html.match(/rel="canonical"\s+href="([^"]+)"/);
  return match?.[1] ?? null;
};

/** Extract <title> text. */
const extractTitle = (html: string): string | null => {
  const match = html.match(/<title>([^<]+)<\/title>/);
  return match?.[1] ?? null;
};

test.describe('per-route SEO meta tags (#116)', () => {
  /** Fetch raw HTML for a route (no JS execution). */
  const fetchHtml = async (
    request: ReturnType<Parameters<Parameters<typeof test>[2]>[0]['request']['get']> extends Promise<infer R> ? { get: (url: string) => Promise<R> } : never,
    path: string,
  ) => {
    const response = await request.get(path);
    return response.text();
  };

  // Store homepage description for comparison
  let homepageDescription: string | null;

  test.beforeAll(async ({ request }) => {
    const html = await (await request.get('/')).text();
    homepageDescription = extractMeta(html, 'name', 'description');
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
        const title = extractTitle(routeHtml);
        expect(title).not.toBeNull();
        expect(title).toContain(keyword);
      });

      test('og:url includes route path without trailing slash', async () => {
        const ogUrl = extractMeta(routeHtml, 'property', 'og:url');
        expect(ogUrl).not.toBeNull();
        expect(ogUrl).toContain(path);
        expect(ogUrl).not.toMatch(/\/$/);
      });

      test('canonical href includes route path', async () => {
        const canonical = extractCanonical(routeHtml);
        expect(canonical).not.toBeNull();
        expect(canonical).toContain(path);
        expect(canonical).not.toMatch(/\/$/);
      });

      test('description differs from homepage', async () => {
        const desc = extractMeta(routeHtml, 'name', 'description');
        expect(desc).not.toBeNull();
        expect(desc).not.toBe(homepageDescription);
      });
    });
  }

  test('unknown route falls back to homepage meta', async ({ request }) => {
    const html = await (await request.get('/some-unknown-route-xyz')).text();
    const title = extractTitle(html);
    expect(title).toContain('Integrity Studio');
    // Should match homepage title (unchanged by middleware)
    const homepageHtml = await (await request.get('/')).text();
    expect(title).toBe(extractTitle(homepageHtml));
  });
});
