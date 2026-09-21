import { describe, it, expect } from 'vitest';
import { buildEntitlementMap, projectPlanEntitlements, PLAN_LIMIT_KEYS, type PlanRow } from './entitlements';
import type { Entitlement } from './types/index';

const ORG_ID = 'org-1';

// Mirrors the live `plans` rows read 2026-09-18.
const GROWTH: PlanRow = {
  key: 'growth',
  monthly_units: 500_000,
  requests_per_minute: 600,
  concurrent_jobs: 5,
  features: { alerts: true, usage_dashboard: true, compliance_summary: true },
};
const ENTERPRISE: PlanRow = {
  key: 'enterprise',
  monthly_units: null,
  requests_per_minute: null,
  concurrent_jobs: null,
  features: { alerts: true, premium_support: true, usage_dashboard: true, compliance_summary: true },
};

const row = (feature_key: string, overrides: Partial<Entitlement> = {}): Entitlement => ({
  organization_id: ORG_ID,
  feature_key,
  enabled: true,
  hard_limit: null,
  soft_limit: null,
  ...overrides,
});

describe('projectPlanEntitlements', () => {
  it('projects feature flags as booleans and limits as numbers', () => {
    expect(projectPlanEntitlements(GROWTH)).toEqual({
      alerts: true,
      usage_dashboard: true,
      compliance_summary: true,
      monthly_units: 500_000,
      requests_per_minute: 600,
      concurrent_jobs: 5,
    });
  });

  // Enterprise stores its limits as NULL; the wire keeps that as "unlimited" rather
  // than inventing a number.
  it('projects null limits as null', () => {
    const map = projectPlanEntitlements(ENTERPRISE);
    for (const key of PLAN_LIMIT_KEYS) expect(map[key]).toBeNull();
    expect(map.premium_support).toBe(true);
  });

  it.each([null, undefined])('projects nothing for a missing plan (%s)', (plan) => {
    expect(projectPlanEntitlements(plan)).toEqual({});
  });

  it('ignores non-boolean feature values', () => {
    const map = projectPlanEntitlements({ ...GROWTH, features: { alerts: 'yes', seats: 3, usage_dashboard: true } });
    expect(map).not.toHaveProperty('alerts');
    expect(map).not.toHaveProperty('seats');
    expect(map.usage_dashboard).toBe(true);
  });

  it('tolerates a null features column', () => {
    expect(projectPlanEntitlements({ ...GROWTH, features: null })).toEqual({
      monthly_units: 500_000,
      requests_per_minute: 600,
      concurrent_jobs: 5,
    });
  });
});

describe('buildEntitlementMap', () => {
  it('keeps the pre-UA01 row semantics when there is no plan', () => {
    const rows = [
      row('usage_dashboard'),
      row('monthly_units', { hard_limit: 1_000 }),
      row('seats', { soft_limit: 3 }),
      row('alerts', { enabled: false, hard_limit: 99 }),
    ];
    expect(buildEntitlementMap(rows)).toEqual({ usage_dashboard: true, monthly_units: 1_000, seats: 3, alerts: false });
  });

  it('starts from the plan projection', () => {
    expect(buildEntitlementMap([], GROWTH)).toEqual(projectPlanEntitlements(GROWTH));
  });

  it('lets a row override the plan for the same key', () => {
    const map = buildEntitlementMap(
      [row('monthly_units', { hard_limit: 1_000 }), row('compliance_summary', { enabled: false })],
      GROWTH,
    );
    expect(map.monthly_units).toBe(1_000);
    expect(map.compliance_summary).toBe(false);
    // Untouched plan keys survive.
    expect(map.requests_per_minute).toBe(600);
    expect(map.alerts).toBe(true);
  });

  it('adds row-only keys the plan does not know', () => {
    expect(buildEntitlementMap([row('api_keys_max', { hard_limit: 10 })], GROWTH).api_keys_max).toBe(10);
  });
});
