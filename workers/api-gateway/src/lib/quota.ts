/**
 * Quota service: Client for Durable Object quota checks
 */

import { createSupabaseClient } from '../../../lib/supabase';
import { effectivePlan } from '../../../lib/billing';
import {
  QuotaCheckResponseSchema,
  QuotaStatusResponseSchema,
} from '../../../lib/types/schemas';
import type {
  OrgPlanRow,
  OrgQuotaMiddlewareOptions,
  QuotaCheckRequest,
  QuotaCheckResponse,
  QuotaStatusResponse,
} from '../../../lib/types/schemas';

// Re-export for backward compatibility
export type {
  OrgPlanRow,
  OrgQuotaMiddlewareOptions,
  QuotaCheckRequest,
  QuotaCheckResponse,
  QuotaStatusResponse,
};

function extractErrorMessage(raw: unknown, fallback: string): string {
  if (raw !== null && typeof raw === 'object' && 'error' in raw) {
    return String((raw as { error: unknown }).error);
  }
  return fallback;
}

export async function checkAndReserve(
  doNamespace: DurableObjectNamespace,
  request: QuotaCheckRequest,
): Promise<QuotaCheckResponse> {
  const id = doNamespace.idFromName(request.orgId);
  const obj = doNamespace.get(id);

  const response = await obj.fetch(
    new Request('http://quota.local/check-and-reserve', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify(request),
    }),
  );

  const raw = await response.json();

  if (!response.ok && response.status !== 429) {
    // 429 falls through to parse: the DO always returns a full QuotaCheckResponse body
    // on rate-limit rejections (allowed: false, reason, remainingMinute/remainingMonthly).
    throw new Error(`Quota check failed: ${extractErrorMessage(raw, response.statusText)}`);
  }

  return QuotaCheckResponseSchema.parse(raw);
}

export async function getQuotaStatus(
  doNamespace: DurableObjectNamespace,
  orgId: string,
): Promise<QuotaStatusResponse> {
  const id = doNamespace.idFromName(orgId);
  const obj = doNamespace.get(id);

  const response = await obj.fetch(
    new Request('http://quota.local/status', {
      method: 'GET',
    }),
  );

  if (!response.ok) {
    throw new Error(`Status check failed: ${response.statusText}`);
  }

  return QuotaStatusResponseSchema.parse(await response.json());
}

/**
 * Seconds from `now` until midnight UTC on the first day of the next calendar month.
 * Used for the monthly `Retry-After` value and the IETF RateLimit `t=` field.
 */
export function secondsToMonthReset(now: number = Date.now()): number {
  const d = new Date(now);
  const nextMonth = d.getUTCMonth() === 11 ? 0 : d.getUTCMonth() + 1;
  const nextYear = d.getUTCMonth() === 11 ? d.getUTCFullYear() + 1 : d.getUTCFullYear();
  const reset = Date.UTC(nextYear, nextMonth, 1, 0, 0, 0, 0);
  return Math.max(0, Math.ceil((reset - now) / 1_000));
}

/**
 * IETF draft-ietf-httpapi-ratelimit-headers-11 `RateLimit-Policy` header value.
 * Enterprise (monthlyLimit null) has no "month" item because there is no limit to declare.
 * Returns an empty string when no limit information is available.
 */
export function buildRateLimitPolicyHeader(
  minuteLimit: number | null | undefined,
  monthlyLimit: number | null | undefined,
): string {
  const parts: string[] = [];
  if (minuteLimit != null) parts.push(`"minute";q=${minuteLimit};w=60`);
  if (monthlyLimit != null) parts.push(`"month";q=${monthlyLimit}`);
  return parts.join(', ');
}

/**
 * IETF draft-ietf-httpapi-ratelimit-headers-11 `RateLimit` header value.
 * `t=` is the time-to-reset in seconds for each window.
 * Returns an empty string when no remaining information is available.
 */
export function buildRateLimitHeader(
  remainingMinute: number | null | undefined,
  minuteWindowResetsIn: number | null | undefined,
  remainingMonthly: number | null | undefined,
  monthlyLimit: number | null | undefined,
  now: number = Date.now(),
): string {
  const parts: string[] = [];
  if (remainingMinute != null) {
    const t = minuteWindowResetsIn ?? 60;
    parts.push(`"minute";r=${remainingMinute};t=${t}`);
  }
  // Include month item only when we have tracking (remainingMonthly not null = limited plan).
  if (remainingMonthly != null && monthlyLimit != null) {
    parts.push(`"month";r=${remainingMonthly};t=${secondsToMonthReset(now)}`);
  }
  return parts.join(', ');
}

/**
 * Middleware helper: fetch org plan from DB, run quota check, return 429 if exceeded.
 * If the quota DO is unavailable, allows the request through (fail-open).
 * `chargeMonthly: false` (CR58) counts the request toward the minute window only.
 */
export async function enforceOrgQuota(
  orgId: string,
  opts: OrgQuotaMiddlewareOptions,
  { chargeMonthly = true }: { chargeMonthly?: boolean } = {},
): Promise<{ ok: true; rateLimitHeaders: Record<string, string> } | { ok: false; response: Response }> {
  const sb = createSupabaseClient(opts.supabaseUrl, opts.serviceRoleKey);

  const orgResult = await sb.query<OrgPlanRow>('organizations', {
    select: 'current_plan, quota_version, billing_status',
    filters: [{ column: 'id', operator: 'eq', value: orgId }],
    limit: 1,
  });

  const org =
    orgResult.ok && orgResult.data.length > 0
      ? orgResult.data[0]
      : null;

  // CR37: a stored paid plan counts only while billing is in good standing.
  const planKey = effectivePlan(org?.current_plan, org?.billing_status);
  const quotaVersion: number = org?.quota_version ?? 0;
  const requestId = crypto.randomUUID();

  let quota: QuotaCheckResponse;
  try {
    quota = await checkAndReserve(opts.doNamespace as DurableObjectNamespace, {
      orgId,
      metricKey: 'requests',
      units: 1,
      requestId,
      planKey,
      quotaVersion,
      chargeMonthly,
    });
  } catch {
    // Fail-open: if DO is unavailable, allow request through with no rate limit headers
    return { ok: true, rateLimitHeaders: {} };
  }

  const rateLimitHeaders: Record<string, string> = {};

  // Legacy X-RateLimit-* headers (kept until callers migrate to the IETF draft fields).
  if (quota.remainingMinute != null) {
    rateLimitHeaders['X-RateLimit-Remaining-Minute'] = String(quota.remainingMinute);
  }
  if (quota.remainingMonthly != null) {
    rateLimitHeaders['X-RateLimit-Remaining-Monthly'] = String(quota.remainingMonthly);
  }

  // IETF draft-ietf-httpapi-ratelimit-headers-11 fields.
  const policy = buildRateLimitPolicyHeader(quota.minuteLimit, quota.monthlyLimit);
  if (policy) rateLimitHeaders['RateLimit-Policy'] = policy;
  const rl = buildRateLimitHeader(
    quota.remainingMinute,
    quota.minuteWindowResetsIn,
    quota.remainingMonthly,
    quota.monthlyLimit,
  );
  if (rl) rateLimitHeaders['RateLimit'] = rl;

  if (!quota.allowed) {
    const retryAfter = quota.reason === 'minute_limit'
      ? (quota.minuteWindowResetsIn ?? 60)
      : secondsToMonthReset();
    return {
      ok: false,
      response: new Response(
        JSON.stringify({ error: { message: 'Too Many Requests', reason: quota.reason } }),
        {
          status: 429,
          headers: {
            'Content-Type': 'application/json',
            'Retry-After': String(retryAfter),
            ...rateLimitHeaders,
          },
        },
      ),
    };
  }

  return { ok: true, rateLimitHeaders };
}
