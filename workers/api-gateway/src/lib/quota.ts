/**
 * Quota service: Client for Durable Object quota checks
 */

import { createSupabaseClient } from '../../../lib/supabase';
import {
  QuotaCheckResponseSchema,
  QuotaFlushResultSchema,
  QuotaStatusResponseSchema,
} from '../../../lib/types/schemas';
import type {
  OrgPlanRow,
  OrgQuotaMiddlewareOptions,
  QuotaCheckRequest,
  QuotaCheckResponse,
  QuotaFlushResult,
  QuotaStatusResponse,
} from '../../../lib/types/schemas';

// Re-export for backward compatibility
export type {
  OrgPlanRow,
  OrgQuotaMiddlewareOptions,
  QuotaCheckRequest,
  QuotaCheckResponse,
  QuotaFlushResult,
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

export async function flushUsage(
  doNamespace: DurableObjectNamespace,
  orgId: string,
): Promise<QuotaFlushResult> {
  const id = doNamespace.idFromName(orgId);
  const obj = doNamespace.get(id);

  const response = await obj.fetch(
    new Request('http://quota.local/flush-usage', {
      method: 'POST',
    }),
  );

  const raw = await response.json();

  if (!response.ok) {
    throw new Error(`Flush failed: ${extractErrorMessage(raw, response.statusText)}`);
  }

  return QuotaFlushResultSchema.parse(raw);
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
 * Middleware helper: fetch org plan from DB, run quota check, return 429 if exceeded.
 * If the quota DO is unavailable, allows the request through (fail-open).
 */
export async function enforceOrgQuota(
  orgId: string,
  opts: OrgQuotaMiddlewareOptions,
): Promise<{ ok: true; rateLimitHeaders: Record<string, string> } | { ok: false; response: Response }> {
  const sb = createSupabaseClient(opts.supabaseUrl, opts.serviceRoleKey);

  const orgResult = await sb.query<OrgPlanRow>('organizations', {
    select: 'current_plan, quota_version',
    filters: [{ column: 'id', operator: 'eq', value: orgId }],
    limit: 1,
  });

  const org =
    orgResult.ok && orgResult.data.length > 0
      ? orgResult.data[0]
      : null;

  const planKey = (org?.current_plan ?? 'starter') as 'starter' | 'growth' | 'enterprise';
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
    });
  } catch {
    // Fail-open: if DO is unavailable, allow request through with no rate limit headers
    return { ok: true, rateLimitHeaders: {} };
  }

  const rateLimitHeaders: Record<string, string> = {};
  if (quota.remainingMinute != null) {
    rateLimitHeaders['X-RateLimit-Remaining-Minute'] = String(quota.remainingMinute);
  }
  if (quota.remainingMonthly != null) {
    rateLimitHeaders['X-RateLimit-Remaining-Monthly'] = String(quota.remainingMonthly);
  }

  if (!quota.allowed) {
    return {
      ok: false,
      response: new Response(
        JSON.stringify({ error: { message: 'Too Many Requests', reason: quota.reason } }),
        { status: 429, headers: { 'Content-Type': 'application/json', ...rateLimitHeaders } },
      ),
    };
  }

  return { ok: true, rateLimitHeaders };
}
