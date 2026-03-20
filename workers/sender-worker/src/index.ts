import { ALLOWED_ORIGINS, JSON_CONTENT_TYPE } from '../../constants';

interface Env {
  SHARED_SECRET: string;
  RECEIVER_WORKER_URL: string;
}

function jsonResponse(body: unknown, status: number, extra: Record<string, string> = {}): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { 'content-type': JSON_CONTENT_TYPE, ...extra },
  });
}

/**
 * Returns CORS headers for allowed origins, null for disallowed browser origins.
 * Requests without an Origin header (non-browser / internal calls) pass through
 * with no CORS headers and no rejection.
 */
function getCorsHeaders(origin: string | null): Record<string, string> | null {
  if (!origin) return {};
  if (!ALLOWED_ORIGINS.includes(origin)) return null;
  return {
    'Access-Control-Allow-Origin': origin,
    'Access-Control-Allow-Methods': 'POST, OPTIONS',
    'Access-Control-Allow-Headers': 'Content-Type',
    'Vary': 'Origin',
  };
}

async function computeSignature(
  body: string,
  secret: string,
  timestamp: string,
): Promise<string> {
  const encoder = new TextEncoder();
  const key = await crypto.subtle.importKey(
    'raw',
    encoder.encode(secret),
    { name: 'HMAC', hash: 'SHA-256' },
    false,
    ['sign'],
  );
  const sig = await crypto.subtle.sign(
    'HMAC',
    key,
    encoder.encode(`${timestamp}.${body}`),
  );
  return [...new Uint8Array(sig)].map(b => b.toString(16).padStart(2, '0')).join('');
}

async function handleSend(
  request: Request,
  env: Env,
  corsHeaders: Record<string, string>,
): Promise<Response> {
  // Validate configuration
  if (!env.RECEIVER_WORKER_URL || !env.SHARED_SECRET) {
    return jsonResponse(
      { error: 'Receiver-worker or shared secret not configured' },
      500,
      corsHeaders,
    );
  }

  // Get request body
  const body = await request.text();

  // Validate JSON
  try {
    JSON.parse(body);
  } catch {
    return jsonResponse({ error: 'invalid json' }, 400, corsHeaders);
  }

  // Create timestamp and compute signature
  const timestamp = Date.now().toString();
  const signature = await computeSignature(body, env.SHARED_SECRET, timestamp);

  // Forward signed request to receiver-worker
  try {
    const response = await fetch(`${env.RECEIVER_WORKER_URL}/inbox`, {
      method: 'POST',
      headers: {
        'content-type': 'application/json',
        'x-timestamp': timestamp,
        'x-signature': signature,
      },
      body,
    });

    // Pass through the response
    const responseBody = await response.text();
    return new Response(responseBody, {
      status: response.status,
      headers: { 'content-type': JSON_CONTENT_TYPE, ...corsHeaders },
    });
  } catch {
    return jsonResponse({ error: 'receiver-worker unreachable' }, 502, corsHeaders);
  }
}

export default {
  async fetch(request: Request, env: Env): Promise<Response> {
    const { pathname } = new URL(request.url);
    const origin = request.headers.get('Origin');

    // Handle CORS preflight
    if (request.method === 'OPTIONS') {
      const corsHeaders = origin && ALLOWED_ORIGINS.includes(origin)
        ? getCorsHeaders(origin)!
        : {};
      return new Response(null, { status: 204, headers: corsHeaders });
    }

    const corsHeaders = getCorsHeaders(origin);
    if (corsHeaders === null) {
      return jsonResponse({ error: 'forbidden' }, 403);
    }

    if (pathname === '/send' && request.method === 'POST') {
      return handleSend(request, env, corsHeaders);
    }

    return jsonResponse({ error: 'not found' }, 404, corsHeaders);
  },
};
