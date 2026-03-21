import { forbidden, unauthorized, unprocessableEntity, serverError, json } from '../../../lib/http';
import { requireBearerToken, safeParseJson } from '../../../lib/http/request';
import { verifyJwt } from '../../../lib/auth';
import { verifyApiKey, parseApiKey } from '../../../lib/api-keys';
import { createSupabaseClient, type SupabaseClient } from '../../../lib/supabase';
import type { OrgMembership } from '../../../lib/types';
import { rollupDailyBucket } from '../aggregation';

const UUID_RE = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;
const VALID_SOURCES = ['api', 'ingest', 'job', 'internal', 'migration'] as const;
const METRIC_KEY_MAX_LENGTH = 128;
const LATENCY_MS_MAX = 300_000; // 5 minutes ceiling
type EventSource = typeof VALID_SOURCES[number];

type IngestAuth =
  | { ok: true; type: 'jwt'; sub: string; keyId: null }
  | { ok: true; type: 'api_key'; userId: string; organizationId: string; keyId: string }
  | { ok: false; error: Response };

interface IngestEventBody {
  org_id: string;
  metric_key: string;
  quantity: number;
  source: EventSource;
  route?: string;
  status_code?: number;
  latency_ms?: number;
  metadata?: Record<string, unknown>;
}

interface IngestHandlerOptions {
  jwtSecret: string;
  hmacSecret: string;
  supabaseUrl: string;
  serviceRoleKey: string;
  jwtIssuerUrl?: string;
  _sbOverride?: SupabaseClient;
}

function validateBody(data: unknown): { ok: true; value: IngestEventBody } | { ok: false; error: string } {
  if (!data || typeof data !== 'object' || Array.isArray(data)) {
    return { ok: false, error: 'Body must be a JSON object' };
  }
  const d = data as Record<string, unknown>;

  if (typeof d.org_id !== 'string' || !UUID_RE.test(d.org_id)) {
    return { ok: false, error: 'org_id must be a valid UUID' };
  }
  if (typeof d.metric_key !== 'string' || d.metric_key.length === 0 || d.metric_key.length > METRIC_KEY_MAX_LENGTH) {
    return { ok: false, error: `metric_key is required and must be <= ${METRIC_KEY_MAX_LENGTH} chars` };
  }
  const quantity = d.quantity ?? 1;
  if (typeof quantity !== 'number' || !Number.isInteger(quantity) || quantity < 1) {
    return { ok: false, error: 'quantity must be a positive integer' };
  }
  const source = d.source ?? 'api';
  if (!VALID_SOURCES.includes(source as EventSource)) {
    return { ok: false, error: `source must be one of: ${VALID_SOURCES.join(', ')}` };
  }
  if (d.status_code !== undefined && (typeof d.status_code !== 'number' || d.status_code < 100 || d.status_code > 599)) {
    return { ok: false, error: 'status_code must be 100–599' };
  }
  if (d.latency_ms !== undefined && (typeof d.latency_ms !== 'number' || d.latency_ms < 0 || d.latency_ms > LATENCY_MS_MAX)) {
    return { ok: false, error: `latency_ms must be 0–${LATENCY_MS_MAX}` };
  }

  return {
    ok: true,
    value: {
      org_id: d.org_id,
      metric_key: d.metric_key,
      quantity,
      source: source as EventSource,
      route: d.route as string | undefined,
      status_code: d.status_code as number | undefined,
      latency_ms: d.latency_ms as number | undefined,
      metadata: d.metadata && typeof d.metadata === 'object' && !Array.isArray(d.metadata)
        ? d.metadata as Record<string, unknown>
        : undefined,
    },
  };
}

async function resolveAuth(
  request: Request,
  opts: IngestHandlerOptions,
  sb: SupabaseClient,
): Promise<IngestAuth> {
  const tokenResult = requireBearerToken(request);
  if (!tokenResult.ok) return tokenResult;

  const { token } = tokenResult;

  const parsedKey = parseApiKey(token);
  if (parsedKey.ok) {
    const keyResult = await verifyApiKey(token, opts.hmacSecret, sb);
    if (!keyResult.ok) return keyResult;
    return { ok: true, type: 'api_key', userId: keyResult.userId, organizationId: keyResult.organizationId, keyId: keyResult.apiKey.id };
  }

  const jwtResult = await verifyJwt(token, opts.jwtSecret, { issuerUrl: opts.jwtIssuerUrl });
  if (!jwtResult.ok) return jwtResult;
  if (!jwtResult.payload.sub) return { ok: false, error: unauthorized('JWT missing sub claim') };
  return { ok: true, type: 'jwt', sub: jwtResult.payload.sub, keyId: null };
}

async function assertOrgAccess(
  auth: IngestAuth & { ok: true },
  orgId: string,
  sb: SupabaseClient,
): Promise<{ ok: true } | { ok: false; error: Response }> {
  if (auth.type === 'api_key') {
    return auth.organizationId === orgId
      ? { ok: true }
      : { ok: false, error: forbidden('API key does not belong to this organization') };
  }

  const result = await sb.query<OrgMembership>('organization_memberships', {
    select: 'organization_id, user_id, role, status',
    filters: [
      { column: 'user_id', operator: 'eq', value: auth.sub },
      { column: 'organization_id', operator: 'eq', value: orgId },
      { column: 'status', operator: 'eq', value: 'active' },
    ],
    limit: 1,
  });

  if (!result.ok || !Array.isArray(result.data) || result.data.length === 0) {
    return { ok: false, error: forbidden('Not a member of this organization') };
  }

  return { ok: true };
}

export async function handleIngestEvent(
  request: Request,
  opts: IngestHandlerOptions,
  waitUntil?: (p: Promise<unknown>) => void,
): Promise<Response> {
  const sb = opts._sbOverride ?? createSupabaseClient(opts.supabaseUrl, opts.serviceRoleKey);

  const auth = await resolveAuth(request, opts, sb);
  if (!auth.ok) return auth.error;

  const bodyResult = await safeParseJson(request);
  if (!bodyResult.ok) return bodyResult.error;

  const validation = validateBody(bodyResult.data);
  if (!validation.ok) {
    return unprocessableEntity(validation.error);
  }

  const body = validation.value;
  const access = await assertOrgAccess(auth, body.org_id, sb);
  if (!access.ok) return access.error;

  const requestId = crypto.randomUUID();
  const now = new Date().toISOString();
  const bucketDate = now.slice(0, 10);

  const insertResult = await sb.insert('usage_events', {
    organization_id: body.org_id,
    user_id: auth.type === 'jwt' ? auth.sub : null,
    api_key_id: auth.keyId,
    metric_key: body.metric_key,
    quantity: body.quantity,
    route: body.route ?? null,
    request_id: requestId,
    source: body.source,
    status_code: body.status_code ?? null,
    latency_ms: body.latency_ms ?? null,
    metadata: body.metadata ?? {},
    created_at: now,
  });

  if (!insertResult.ok) {
    return serverError('Failed to store usage event');
  }

  if (waitUntil) {
    waitUntil(
      rollupDailyBucket(body.org_id, bucketDate, sb)
        .catch(err => console.error('[ingest] rollup failed', err)),
    );
  }

  return json({ ok: true, request_id: requestId }, { status: 202 });
}
