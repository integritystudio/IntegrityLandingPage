import type { RouteMeta } from './route-meta';

/** Escape HTML attribute special characters to prevent XSS (C1). */
const escapeHtmlAttr = (str: string): string =>
  str
    .replace(/&/g, '&amp;')
    .replace(/"/g, '&quot;')
    .replace(/'/g, '&#x27;')
    .replace(/</g, '&lt;')
    .replace(/>/g, '&gt;');

/** Regex patterns for targeted meta tag replacement. */
const TAG_PATTERNS = {
  title: /(<title>)(.*?)(<\/title>)/,
  metaTitle: /(name="title"\s+content=")(.*?)(")/,
  metaDescription: /(name="description"\s+content=")(.*?)(")/,
  metaRobots: /(name="robots"\s+content=")(.*?)(")/,
  ogTitle: /(property="og:title"\s+content=")(.*?)(")/,
  ogDescription: /(property="og:description"\s+content=")(.*?)(")/,
  ogUrl: /(property="og:url"\s+content=")(.*?)(")/,
  ogImage: /(property="og:image"\s+content=")(.*?)(")/,
  xTitle: /(property="x:title"\s+content=")(.*?)(")/,
  xDescription: /(property="x:description"\s+content=")(.*?)(")/,
  xUrl: /(property="x:url"\s+content=")(.*?)(")/,
  xImage: /(property="x:image"\s+content=")(.*?)(")/,
  canonical: /(rel="canonical"\s+href=")(.*?)(")/,
} as const;

/**
 * Replace meta tags in HTML string with route-specific values.
 *
 * Contract: `meta` values come from the static ROUTE_META map, never external input.
 * The escapeHtmlAttr defense is belt-and-suspenders (C1).
 *
 * Returns HTML unchanged when meta is undefined.
 */
export const injectRouteMeta = (
  html: string,
  meta: RouteMeta | undefined,
  _baseUrl: string,
): string => {
  if (!meta) return html;

  const title = escapeHtmlAttr(meta.title);
  const ogTitle = escapeHtmlAttr(meta.ogTitle ?? meta.title);
  const description = escapeHtmlAttr(meta.description);
  const canonical = escapeHtmlAttr(meta.canonical);

  let result = html;

  // Title tag (inner text, not attribute)
  result = result.replace(TAG_PATTERNS.title, `$1${title}$3`);

  // Primary meta tags
  result = result.replace(TAG_PATTERNS.metaTitle, `$1${title}$3`);
  result = result.replace(TAG_PATTERNS.metaDescription, `$1${description}$3`);

  // Robots
  const robots = meta.noindex ? 'noindex, nofollow' : 'index, follow';
  result = result.replace(TAG_PATTERNS.metaRobots, `$1${robots}$3`);

  // Open Graph
  result = result.replace(TAG_PATTERNS.ogTitle, `$1${ogTitle}$3`);
  result = result.replace(TAG_PATTERNS.ogDescription, `$1${description}$3`);
  result = result.replace(TAG_PATTERNS.ogUrl, `$1${canonical}$3`);

  // X/Twitter
  result = result.replace(TAG_PATTERNS.xTitle, `$1${ogTitle}$3`);
  result = result.replace(TAG_PATTERNS.xDescription, `$1${description}$3`);
  result = result.replace(TAG_PATTERNS.xUrl, `$1${canonical}$3`);

  // OG/X image — only replace when ogImage is explicitly provided (M1)
  if (meta.ogImage) {
    const ogImage = escapeHtmlAttr(meta.ogImage);
    result = result.replace(TAG_PATTERNS.ogImage, `$1${ogImage}$3`);
    result = result.replace(TAG_PATTERNS.xImage, `$1${ogImage}$3`);
  }

  // Canonical URL
  result = result.replace(TAG_PATTERNS.canonical, `$1${canonical}$3`);

  return result;
};
