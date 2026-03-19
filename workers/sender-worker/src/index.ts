import { JSON_CONTENT_TYPE } from '../../constants';

interface Env {
  SHARED_SECRET: string;
  RECEIVER_WORKER_URL: string;
}

function jsonResponse(body: unknown, status: number): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { 'content-type': JSON_CONTENT_TYPE },
  });
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

async function handleSend(request: Request, env: Env): Promise<Response> {
  // Validate configuration
  if (!env.RECEIVER_WORKER_URL || !env.SHARED_SECRET) {
    return jsonResponse(
      { error: 'Receiver-worker or shared secret not configured' },
      500,
    );
  }

  // Get request body
  const body = await request.text();

  // Validate JSON
  try {
    JSON.parse(body);
  } catch {
    return jsonResponse({ error: 'invalid json' }, 400);
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
      headers: { 'content-type': JSON_CONTENT_TYPE },
    });
  } catch {
    return jsonResponse({ error: 'receiver-worker unreachable' }, 502);
  }
}

export default {
  async fetch(request: Request, env: Env): Promise<Response> {
    const { pathname } = new URL(request.url);

    if (pathname === '/send' && request.method === 'POST') {
      return handleSend(request, env);
    }

    return jsonResponse({ error: 'not found' }, 404);
  },
};
