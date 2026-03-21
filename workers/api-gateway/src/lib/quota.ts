/**
 * Quota service: Client for Durable Object quota checks
 */

export interface QuotaCheckRequest {
  orgId: string;
  metricKey: string;
  units: number;
  requestId: string;
  planKey: string;
  quotaVersion: number;
}

export interface QuotaCheckResponse {
  allowed: boolean;
  reason?: "minute_limit" | "monthly_limit" | "feature_disabled";
  remainingMinute?: number;
  remainingMonthly?: number | null;
}

export interface QuotaFlushResult {
  orgId: string;
  monthlyUsedSinceLastFlush: number;
  flushedAt: string;
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

  const data = (await response.json()) as QuotaCheckResponse | { error: string };

  if (!response.ok) {
    if ('error' in data) {
      throw new Error(`Quota check failed: ${data.error}`);
    }
    // 429 is expected for over-quota, return the response
    return data as QuotaCheckResponse;
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
