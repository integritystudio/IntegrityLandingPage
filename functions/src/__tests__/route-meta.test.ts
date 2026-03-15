import { describe, it, expect } from 'vitest';
import { getRouteMeta, ROUTE_META, type RouteMeta } from '../route-meta';
import { BASE_URL } from '../constants';

describe('getRouteMeta', () => {
  it('returns correct RouteMeta for /about', () => {
    const meta = getRouteMeta('/about');
    expect(meta).toBeDefined();
    expect(meta!.title).toContain('About');
    expect(meta!.canonical).toBe(`${BASE_URL}/about`);
  });

  it('returns undefined for unknown route', () => {
    expect(getRouteMeta('/unknown-page-xyz')).toBeUndefined();
  });

  it('returns RouteMeta for homepage /', () => {
    const meta = getRouteMeta('/');
    expect(meta).toBeDefined();
    expect(meta!.canonical).toBe(`${BASE_URL}/`);
  });
});

describe('ROUTE_META entries', () => {
  const TIER_1_ROUTES = [
    '/', '/about', '/features', '/pricing', '/contact',
    '/docs', '/compliance', '/eu-ai-act', '/security', '/blog', '/careers',
  ];

  const NOINDEX_ROUTES = [
    '/signup', '/request_success', '/request_failure', '/oauth/callback',
  ];

  it('has entries for all Tier 1 routes', () => {
    for (const route of TIER_1_ROUTES) {
      expect(ROUTE_META[route], `missing entry for ${route}`).toBeDefined();
    }
  });

  it('has entries for all noindex routes', () => {
    for (const route of NOINDEX_ROUTES) {
      expect(ROUTE_META[route], `missing entry for ${route}`).toBeDefined();
    }
  });

  it('title length is 30-70 chars for all entries', () => {
    for (const [path, meta] of Object.entries(ROUTE_META)) {
      expect(meta.title.length, `${path} title too short`).toBeGreaterThanOrEqual(30);
      expect(meta.title.length, `${path} title too long`).toBeLessThanOrEqual(70);
    }
  });

  it('description length is 50-160 chars for all entries', () => {
    for (const [path, meta] of Object.entries(ROUTE_META)) {
      expect(meta.description.length, `${path} desc too short`).toBeGreaterThanOrEqual(50);
      expect(meta.description.length, `${path} desc too long`).toBeLessThanOrEqual(160);
    }
  });

  it('has no duplicate canonical paths', () => {
    const canonicals = Object.values(ROUTE_META).map((m) => m.canonical);
    expect(new Set(canonicals).size).toBe(canonicals.length);
  });

  it('noindex routes have noindex: true', () => {
    for (const route of NOINDEX_ROUTES) {
      expect(ROUTE_META[route].noindex, `${route} should be noindex`).toBe(true);
    }
  });

  it('Tier 1 routes do not have noindex', () => {
    for (const route of TIER_1_ROUTES) {
      expect(ROUTE_META[route].noindex).toBeFalsy();
    }
  });

  it('canonical URLs use no trailing slash (except homepage)', () => {
    for (const [path, meta] of Object.entries(ROUTE_META)) {
      if (path === '/') {
        expect(meta.canonical, 'homepage should have trailing slash').toMatch(/\/$/);
      } else {
        expect(meta.canonical, `${path} should not have trailing slash`).not.toMatch(/\/$/);
      }
    }
  });

  it('BASE_URL has no trailing slash', () => {
    expect(BASE_URL).not.toMatch(/\/$/);
  });
});
