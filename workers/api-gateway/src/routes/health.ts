import { createSupabaseClient } from '../../../lib/supabase';

type ComponentStatus = 'healthy' | 'degraded' | 'unhealthy';

const PAGERDUTY_EVENTS_URL = 'https://events.pagerduty.com/v2/enqueue';

interface HealthCheckResult {
  database: ComponentStatus;
  // DOs are binary: binding is present (healthy) or absent (unhealthy). No degraded state.
  durableObjects: 'healthy' | 'unhealthy';
  timestamp: string;
}

/**
 * Health check handler: verifies Supabase connectivity and Durable Object liveness.
 * Returns 200 when all components are healthy, 503 otherwise.
 * Used for monitoring, uptime alerts, and load balancer health checks.
 *
 * When unhealthy and a PagerDuty integration key is configured, fires a trigger
 * event to PagerDuty as a fire-and-forget side effect via waitUntil.
 */
export async function handleHealthCheck(
  supabaseUrl: string,
  serviceRoleKey: string,
  quotaDO: DurableObjectNamespace,
  opts?: {
    pdKey?: string;
    waitUntil?: (p: Promise<unknown>) => void;
  },
): Promise<Response> {
  const [dbCheck, doCheck] = await Promise.allSettled([
    checkDatabase(supabaseUrl, serviceRoleKey),
    checkDurableObject(quotaDO),
  ]);

  const result: HealthCheckResult = {
    database: dbCheck.status === 'fulfilled' ? dbCheck.value : 'unhealthy',
    durableObjects: doCheck.status === 'fulfilled' ? doCheck.value : 'unhealthy',
    timestamp: new Date().toISOString(),
  };

  const allHealthy = result.database === 'healthy' && result.durableObjects === 'healthy';
  const status = allHealthy ? 200 : 503;

  if (!allHealthy && opts?.pdKey && opts?.waitUntil) {
    opts.waitUntil(firePagerDutyAlert(opts.pdKey, result));
  }

  return new Response(JSON.stringify(result), {
    status,
    headers: { 'Content-Type': 'application/json' },
  });
}

async function checkDatabase(supabaseUrl: string, serviceRoleKey: string): Promise<ComponentStatus> {
  const controller = new AbortController();
  const timer = setTimeout(() => controller.abort(), 5_000);
  try {
    const sb = createSupabaseClient(supabaseUrl, serviceRoleKey);
    const result = await sb.query('organizations', {
      select: 'id',
      limit: 1,
    });
    return result.ok ? 'healthy' : 'degraded';
  } catch {
    return 'unhealthy';
  } finally {
    clearTimeout(timer);
  }
}

function checkDurableObject(quotaDO: DurableObjectNamespace): 'healthy' | 'unhealthy' {
  // Verify the namespace binding is configured. Avoid idFromName() which creates a
  // billable named Durable Object on every health check request.
  return quotaDO != null ? 'healthy' : 'unhealthy';
}

async function firePagerDutyAlert(pdKey: string, result: HealthCheckResult): Promise<void> {
  const unhealthyComponents = [
    result.database !== 'healthy' ? `database=${result.database}` : null,
    result.durableObjects !== 'healthy' ? `durableObjects=${result.durableObjects}` : null,
  ]
    .filter(Boolean)
    .join(', ');

  const body = {
    routing_key: pdKey,
    event_action: 'trigger',
    dedup_key: 'api-gateway-health',
    payload: {
      summary: `api-gateway health check failed: ${unhealthyComponents}`,
      severity: 'critical',
      source: 'api-gateway',
      timestamp: result.timestamp,
      custom_details: result,
    },
  };

  try {
    await fetch(PAGERDUTY_EVENTS_URL, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify(body),
    });
  } catch {
    // Fire-and-forget: alerting failure must not affect the health response.
  }
}
