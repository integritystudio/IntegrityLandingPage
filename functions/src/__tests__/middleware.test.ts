import { describe, it, expect } from 'vitest';
import { readFileSync } from 'node:fs';
import { resolve } from 'node:path';
import { handleRequest } from '../middleware';
import { CACHE_CONTROL_NO_CACHE, CONTENT_TYPE_HTML, X_ROBOTS_NOINDEX } from '../constants';

const INDEX_HTML = readFileSync(
  resolve(__dirname, '../../../web/index.html'),
  'utf-8',
);

/** Helper: create a Request for a given path. */
const makeRequest = (path: string): Request =>
  new Request(`https://integritystudio.ai${path}`);

/** Helper: create an upstream HTML 200 response. */
const makeHtmlResponse = (html: string = INDEX_HTML, status = 200): Response =>
  new Response(html, {
    status,
    headers: { 'content-type': `${CONTENT_TYPE_HTML}; charset=utf-8` },
  });

/** Helper: create a non-HTML response. */
const makeAssetResponse = (): Response =>
  new Response('console.log("hi")', {
    status: 200,
    headers: { 'content-type': 'application/javascript' },
  });

describe('handleRequest', () => {
  it('injects route-specific title for /about', async () => {
    const result = await handleRequest(makeRequest('/about'), makeHtmlResponse());
    const body = await result.text();
    expect(body).toContain('<title>About Integrity Studio');
  });

  it('passes non-HTML responses through unmodified', async () => {
    const upstream = makeAssetResponse();
    const result = await handleRequest(makeRequest('/about'), upstream);
    expect(result).toBe(upstream);
  });

  it('returns HTML unchanged for unknown routes', async () => {
    const result = await handleRequest(makeRequest('/unknown-xyz'), makeHtmlResponse());
    const body = await result.text();
    expect(body).toBe(INDEX_HTML);
  });

  it('passes non-200 responses through unmodified (M3)', async () => {
    const upstream = makeHtmlResponse(INDEX_HTML, 404);
    const result = await handleRequest(makeRequest('/about'), upstream);
    expect(result).toBe(upstream);
  });

  it('extracts pathname from URL with query string (H3)', async () => {
    const result = await handleRequest(
      makeRequest('/docs?q=foo'),
      makeHtmlResponse(),
    );
    const body = await result.text();
    expect(body).toContain('<title>Documentation | Integrity Studio');
  });

  it('sets Cache-Control: no-cache on modified responses (H1)', async () => {
    const result = await handleRequest(makeRequest('/about'), makeHtmlResponse());
    expect(result.headers.get('cache-control')).toBe(CACHE_CONTROL_NO_CACHE);
  });

  it('sets X-Robots-Tag for noindex routes (M2)', async () => {
    const result = await handleRequest(makeRequest('/signup'), makeHtmlResponse());
    expect(result.headers.get('x-robots-tag')).toBe(X_ROBOTS_NOINDEX);
  });

  it('does not set X-Robots-Tag for index routes', async () => {
    const result = await handleRequest(makeRequest('/about'), makeHtmlResponse());
    expect(result.headers.get('x-robots-tag')).toBeNull();
  });

  it('does not set Cache-Control on unmodified responses', async () => {
    const result = await handleRequest(makeRequest('/unknown-xyz'), makeHtmlResponse());
    expect(result.headers.get('cache-control')).toBeNull();
  });
});
