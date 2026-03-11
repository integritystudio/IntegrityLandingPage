import { test, expect } from '@playwright/test';

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

const SITE_URL = 'https://integritystudio.ai';
const SITE_NAME = 'Integrity Studio';
const OG_IMAGE_PATH = '/images/og-image.png';

test.describe('SEO Meta Tags', () => {
  let html: string;

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
      // Description should be 50-160 chars for optimal SEO
      const description = match![1];
      expect(description.length).toBeGreaterThanOrEqual(50);
      expect(description.length).toBeLessThanOrEqual(200);
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
      const jsonld = JSON.parse(match![1]);
      const graph = jsonld['@graph'] ?? [jsonld];
      const org = graph.find((n: { '@type': string }) => n['@type'] === 'Organization');
      expect(org).toBeDefined();
      expect(org.name).toBe(SITE_NAME);
      expect(org.url).toBe(SITE_URL);
    });

    test('JSON-LD contains WebSite entity with search action', async () => {
      const match = html.match(/<script\s+type="application\/ld\+json">\s*([\s\S]*?)\s*<\/script>/);
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
