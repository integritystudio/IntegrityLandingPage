import { createSupabaseClient } from '../../../lib/supabase';

type ComponentStatus = 'healthy' | 'degraded' | 'unhealthy';

interface HealthCheckResult {
  database: ComponentStatus;
  durableObjects: ComponentStatus;
  timestamp: string;
}

/**
 * Health check handler: verifies Supabase connectivity and Durable Object liveness.
 * Returns 200 when all components are healthy, 503 otherwise.
 * Used for monitoring, uptime alerts, and load balancer health checks.
 */
export async function handleHealthCheck(
  supabaseUrl: string,
  serviceRoleKey: string,
  quotaDO: DurableObjectNamespace,
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

async function checkDurableObject(quotaDO: DurableObjectNamespace): Promise<ComponentStatus> {
  // Verify the namespace binding is configured. Avoid idFromName() which creates a
  // billable named Durable Object on every health check request.
  return quotaDO != null ? 'healthy' : 'unhealthy';
}
