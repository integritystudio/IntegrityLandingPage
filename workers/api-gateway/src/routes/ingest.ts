import { forbidden, unauthorized, unprocessableEntity, serverError, json } from '../../../lib/http';
import { requireBearerToken, safeParseJson } from '../../../lib/http/request';
import { verifyJwt } from '../../../lib/auth';
import { verifyApiKey, parseApiKey } from '../../../lib/api-keys';
import { createSupabaseClient, type SupabaseClient } from '../../../lib/supabase';
import type { OrgMembership } from '../../../lib/types';
import { IngestEventRequestSchema, IngestOtelRequestSchema, type IngestEventRequest } from '../../../lib/types/usage';
import { enforceOrgQuota } from '../lib/quota';
import { rollupDailyBucket } from '../aggregation';

type IngestAuth =
  | { ok: true; type: 'jwt'; sub: string; keyId: null }
  | { ok: true; type: 'api_key'; userId: string; organizationId: string; keyId: string }
  | { ok: false; error: Response };

interface IngestHandlerOptions {
  jwtSecret: string;
  hmacSecret: string;
  supabaseUrl: string;
  serviceRoleKey: string;
  jwtIssuerUrl?: string;
  /** Durable Object namespace for quota enforcement. Required for /v1/ingest/otel. */
  doNamespace?: DurableObjectNamespace;
  _sbOverride?: SupabaseClient;
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

  const parsed = IngestEventRequestSchema.safeParse(bodyResult.data);
  if (!parsed.success) {
    const errors = parsed.error.flatten().fieldErrors;
    return unprocessableEntity('Validation failed', errors);
  }

  const body = parsed.data;
  const access = await assertOrgAccess(auth, body.org_id, sb);
  if (!access.ok) return access.error;

  const requestId = crypto.randomUUID();
  const now = new Date().toISOString();
  // Derive bucket date from created_at, not server wall-clock, so that a
  // waitUntil rollup scheduled near midnight still targets the correct day.
  const bucketDate = now.slice(0, 10); // YYYY-MM-DD UTC

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

const OTEL_INGEST_ROUTE = '/v1/ingest/otel';
const OTEL_METRIC_KEY = 'otel_events';
const OTEL_MAX_SPANS = 1_000;

/**
 * POST /v1/ingest/otel — OpenTelemetry span ingestion (API key auth only)
 *
 * Accepts a batch of simplified OTLP-compatible spans, writes a usage event
 * with metric_key='otel_events' and quantity=spans.length for quota tracking,
 * and stores span data in metadata. Fire-and-forget daily rollup via waitUntil.
 */
export async function handleIngestOtel(
  request: Request,
  opts: IngestHandlerOptions,
  waitUntil?: (p: Promise<unknown>) => void,
): Promise<Response> {
  const tokenResult = requireBearerToken(request);
  if (!tokenResult.ok) return tokenResult.error;

  const parsedKey = parseApiKey(tokenResult.token);
  if (!parsedKey.ok) return unauthorized('OTEL ingest requires API key authentication');

  const sb = opts._sbOverride ?? createSupabaseClient(opts.supabaseUrl, opts.serviceRoleKey);
  const keyResult = await verifyApiKey(tokenResult.token, opts.hmacSecret, sb);
  if (!keyResult.ok) return keyResult.error;

  const bodyResult = await safeParseJson(request);
  if (!bodyResult.ok) return bodyResult.error;

  const parsed = IngestOtelRequestSchema.safeParse(bodyResult.data);
  if (!parsed.success) {
    return unprocessableEntity('Validation failed', parsed.error.flatten().fieldErrors);
  }

  const { spans } = parsed.data;
  const orgId = keyResult.organizationId;

  // Enforce org quota before writing. Fail-open when doNamespace is absent (e.g., tests).
  let rateLimitHeaders: Record<string, string> = {};
  if (opts.doNamespace) {
    const quota = await enforceOrgQuota(orgId, {
      doNamespace: opts.doNamespace,
      supabaseUrl: opts.supabaseUrl,
      serviceRoleKey: opts.serviceRoleKey,
    });
    if (!quota.ok) return quota.response;
    rateLimitHeaders = quota.rateLimitHeaders;
  }

  const requestId = crypto.randomUUID();
  const now = new Date().toISOString();
  const bucketDate = now.slice(0, 10);

  const insertResult = await sb.insert('usage_events', {
    organization_id: orgId,
    user_id: null,
    api_key_id: keyResult.apiKey.id,
    metric_key: OTEL_METRIC_KEY,
    quantity: spans.length,
    route: OTEL_INGEST_ROUTE,
    request_id: requestId,
    source: 'ingest',
    status_code: null,
    latency_ms: null,
    metadata: { span_count: spans.length, spans },
    created_at: now,
  });

  if (!insertResult.ok) {
    return serverError('Failed to store OTEL spans');
  }

  if (waitUntil) {
    waitUntil(
      rollupDailyBucket(orgId, bucketDate, sb)
        .catch(err => console.error('[ingest/otel] rollup failed', err)),
    );
  }

  const response = json({ ok: true, request_id: requestId, span_count: spans.length }, { status: 202 });
  if (Object.keys(rateLimitHeaders).length === 0) return response;
  const headers = new Headers(response.headers);
  for (const [k, v] of Object.entries(rateLimitHeaders)) headers.set(k, v);
  return new Response(response.body, { status: 202, headers });
}
