import { describe, it, expect } from 'vitest';
import { chargesMonthlyQuota, matchOrgRoute } from './org-routes';

describe('chargesMonthlyQuota', () => {
  it.each([
    ['GET', '/usage/summary', false],
    ['GET', '/quota/status', false],
    // The method is part of the match: only the reads are exempt.
    ['POST', '/usage/summary', true],
    // An exact match, not a prefix: a trailing slash is another (unrouted) path.
    ['GET', '/usage/summary/', true],
    ['GET', '/dashboard', true],
    // The bare org path routes nowhere, and is charged like any unrouted path.
    ['GET', '', true],
  ])('%s %j is charged: %s', (method, subPath, charged) => {
    expect(chargesMonthlyQuota(method, subPath)).toBe(charged);
  });
});

describe('matchOrgRoute', () => {
  it.each([
    ['GET', '/dashboard', 'dashboard'],
    ['POST', '/checkout-session', 'checkoutSession'],
    ['GET', '/checkout-session', undefined],
    ['POST', '/api-keys/key-1/revoke', undefined],
  ])('%s %s -> %s', (method, subPath, name) => {
    expect(matchOrgRoute(method, subPath)).toBe(name);
  });
});
