/**
 * Quota service: Client for Durable Object quota checks
 */

import { createSupabaseClient } from '../../../lib/supabase';
import type {
  OrgPlanRow,
  OrgQuotaMiddlewareOptions,
  QuotaCheckRequest,
  QuotaCheckResponse,
  QuotaFlushResult,
} from '../../../lib/types/schemas';

// Re-export for backward compatibility
export type {
  OrgPlanRow,
  OrgQuotaMiddlewareOptions,
  QuotaCheckRequest,
  QuotaCheckResponse,
  QuotaFlushResult,
};

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

  const data = (await response.json()) as QuotaCheckResponse | { error: string };

  if (!response.ok && response.status !== 429) {
    const msg = 'error' in data ? data.error : response.statusText;
    throw new Error(`Quota check failed: ${msg}`);
  }

  return data as QuotaCheckResponse;
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

  if (!response.ok) {
    const data = (await response.json()) as { error?: string };
    throw new Error(`Flush failed: ${data.error || response.statusText}`);
  }

  return (await response.json()) as QuotaFlushResult;
}

export async function getQuotaStatus(
  doNamespace: DurableObjectNamespace,
  orgId: string,
): Promise<Record<string, unknown>> {
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

  return (await response.json()) as Record<string, unknown>;
}

/**
 * Middleware helper: fetch org plan from DB, run quota check, return 429 if exceeded.
 * If the quota DO is unavailable, allows the request through (fail-open).
 */
export async function enforceOrgQuota(
  orgId: string,
  opts: OrgQuotaMiddlewareOptions,
): Promise<{ ok: true } | { ok: false; response: Response }> {
  const sb = createSupabaseClient(opts.supabaseUrl, opts.serviceRoleKey);

  const orgResult = await sb.query<OrgPlanRow>('organizations', {
    select: 'current_plan, quota_version',
    filters: [{ column: 'id', operator: 'eq', value: orgId }],
    limit: 1,
  });

  const org =
    orgResult.ok && Array.isArray(orgResult.data) && orgResult.data.length > 0
      ? orgResult.data[0]
      : null;

  const planKey: string = org?.current_plan ?? 'free';
  const quotaVersion: number = org?.quota_version ?? 0;
  const requestId = crypto.randomUUID();

  let quota: QuotaCheckResponse;
  try {
    quota = await checkAndReserve(opts.doNamespace, {
      orgId,
      metricKey: 'requests',
      units: 1,
      requestId,
      planKey,
      quotaVersion,
    });
  } catch {
    // Fail-open: if DO is unavailable, allow request through
    return { ok: true };
  }

  if (!quota.allowed) {
    const headers: HeadersInit = { 'Content-Type': 'application/json' };
    if (quota.remainingMinute !== undefined) {
      (headers as Record<string, string>)['X-RateLimit-Remaining-Minute'] = String(quota.remainingMinute);
    }
    if (quota.remainingMonthly !== null && quota.remainingMonthly !== undefined) {
      (headers as Record<string, string>)['X-RateLimit-Remaining-Monthly'] = String(quota.remainingMonthly);
    }
    return {
      ok: false,
      response: new Response(
        JSON.stringify({ error: { message: 'Too Many Requests', reason: quota.reason } }),
        { status: 429, headers },
      ),
    };
  }

  return { ok: true };
}
