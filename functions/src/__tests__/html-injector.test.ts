import { describe, it, expect, beforeAll } from 'vitest';
import { readFileSync } from 'node:fs';
import { resolve } from 'node:path';
import { injectRouteMeta } from '../html-injector';
import { getRouteMeta, ROUTE_META } from '../route-meta';
import { BASE_URL } from '../constants';

/**
 * Uses actual web/index.html as fixture (C2).
 * CI catches flutter SDK-induced format changes.
 */
let indexHtml: string;

beforeAll(() => {
  indexHtml = readFileSync(
    resolve(__dirname, '../../../web/index.html'),
    'utf-8',
  );
});

describe('injectRouteMeta', () => {
  it('replaces <title> inner text', () => {
    const meta = getRouteMeta('/about')!;
    const result = injectRouteMeta(indexHtml, meta, BASE_URL);
    expect(result).toContain(`<title>${meta.title}</title>`);
  });

  it('replaces meta[name="title"] content', () => {
    const meta = getRouteMeta('/about')!;
    const result = injectRouteMeta(indexHtml, meta, BASE_URL);
    expect(result).toContain(`name="title" content="${meta.title}"`);
  });

  it('replaces meta[name="description"] content', () => {
    const meta = getRouteMeta('/about')!;
    const result = injectRouteMeta(indexHtml, meta, BASE_URL);
    expect(result).toContain(`name="description" content="${meta.description}"`);
  });

  it('replaces og:title content', () => {
    const meta = getRouteMeta('/about')!;
    const result = injectRouteMeta(indexHtml, meta, BASE_URL);
    expect(result).toContain(`property="og:title" content="${meta.title}"`);
  });

  it('replaces og:description content', () => {
    const meta = getRouteMeta('/about')!;
    const result = injectRouteMeta(indexHtml, meta, BASE_URL);
    expect(result).toContain(`property="og:description" content="${meta.description}"`);
  });

  it('replaces og:url content', () => {
    const meta = getRouteMeta('/about')!;
    const result = injectRouteMeta(indexHtml, meta, BASE_URL);
    expect(result).toContain(`property="og:url" content="${meta.canonical}"`);
  });

  it('replaces x:title content', () => {
    const meta = getRouteMeta('/about')!;
    const result = injectRouteMeta(indexHtml, meta, BASE_URL);
    expect(result).toContain(`property="x:title" content="${meta.title}"`);
  });

  it('replaces x:description content', () => {
    const meta = getRouteMeta('/about')!;
    const result = injectRouteMeta(indexHtml, meta, BASE_URL);
    expect(result).toContain(`property="x:description" content="${meta.description}"`);
  });

  it('replaces x:url content', () => {
    const meta = getRouteMeta('/about')!;
    const result = injectRouteMeta(indexHtml, meta, BASE_URL);
    expect(result).toContain(`property="x:url" content="${meta.canonical}"`);
  });

  it('replaces canonical href', () => {
    const meta = getRouteMeta('/about')!;
    const result = injectRouteMeta(indexHtml, meta, BASE_URL);
    expect(result).toContain(`rel="canonical" href="${meta.canonical}"`);
  });

  it('replaces robots to noindex,nofollow when noindex: true', () => {
    const meta = getRouteMeta('/signup')!;
    const result = injectRouteMeta(indexHtml, meta, BASE_URL);
    expect(result).toContain('name="robots" content="noindex, nofollow"');
  });

  it('keeps robots as index,follow when noindex is falsy', () => {
    const meta = getRouteMeta('/about')!;
    const result = injectRouteMeta(indexHtml, meta, BASE_URL);
    expect(result).toContain('name="robots" content="index, follow"');
  });

  it('returns HTML unchanged when meta is undefined', () => {
    const result = injectRouteMeta(indexHtml, undefined, BASE_URL);
    expect(result).toBe(indexHtml);
  });

  it('escapes & " < > \' in attribute values (C1)', () => {
    const xssMeta = {
      title: 'Test & "Title" <script>',
      description: "Desc with ' and <tag>",
      canonical: `${BASE_URL}/test`,
    };
    const result = injectRouteMeta(indexHtml, xssMeta, BASE_URL);
    expect(result).not.toContain('<script>');
    expect(result).toContain('&amp;');
    expect(result).toContain('&quot;');
    expect(result).toContain('&lt;');
    expect(result).toContain('&gt;');
  });

  it('preserves og:image when ogImage is undefined (M1)', () => {
    const meta = getRouteMeta('/about')!;
    expect(meta.ogImage).toBeUndefined();
    const result = injectRouteMeta(indexHtml, meta, BASE_URL);
    // Original og:image should remain
    expect(result).toContain('property="og:image" content="https://integritystudio.ai/images/og-image.png"');
    expect(result).toContain('property="x:image" content="https://integritystudio.ai/images/og-image.png"');
  });

  it('replaces og:image and x:image when ogImage is provided', () => {
    const meta = {
      ...getRouteMeta('/about')!,
      ogImage: `${BASE_URL}/images/about-og.png`,
    };
    const result = injectRouteMeta(indexHtml, meta, BASE_URL);
    expect(result).toContain(`property="og:image" content="${meta.ogImage}"`);
    expect(result).toContain(`property="x:image" content="${meta.ogImage}"`);
  });

  it('homepage meta produces identical output (F8)', () => {
    const meta = getRouteMeta('/')!;
    const result = injectRouteMeta(indexHtml, meta, BASE_URL);
    expect(result).toBe(indexHtml);
  });
});
