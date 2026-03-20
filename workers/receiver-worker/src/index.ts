import { JSON_CONTENT_TYPE } from '../../http-constants';
import { REPLAY_WINDOW_MS } from '../../constants';

interface Env {
  SHARED_SECRET: string;
}

function jsonResponse(body: unknown, status: number): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { 'content-type': JSON_CONTENT_TYPE },
  });
}

async function handleInbox(request: Request, env: Env): Promise<Response> {
  const timestampHeader = request.headers.get('x-timestamp');
  const signatureHeader = request.headers.get('x-signature');

  if (!timestampHeader || !signatureHeader) {
    return jsonResponse({ error: 'missing auth headers' }, 401);
  }

  const ts = Number(timestampHeader);
  if (isNaN(ts) || Math.abs(Date.now() - ts) > REPLAY_WINDOW_MS) {
    return jsonResponse({ error: 'stale or invalid timestamp' }, 401);
  }

  const rawBody = await request.text();

  const encoder = new TextEncoder();
  const key = await crypto.subtle.importKey(
    'raw',
    encoder.encode(env.SHARED_SECRET),
    { name: 'HMAC', hash: 'SHA-256' },
    false,
    ['sign'],
  );
  const sig = await crypto.subtle.sign('HMAC', key, encoder.encode(`${timestampHeader}.${rawBody}`));
  const expectedHex = [...new Uint8Array(sig)].map(b => b.toString(16).padStart(2, '0')).join('');

  if (signatureHeader !== expectedHex) {
    return jsonResponse({ error: 'invalid signature' }, 401);
  }

  let parsed: unknown;
  try {
    parsed = JSON.parse(rawBody);
  } catch {
    return jsonResponse({ error: 'invalid json' }, 400);
  }

  return jsonResponse({ ok: true, received: parsed }, 200);
}

export default {
  async fetch(request: Request, env: Env): Promise<Response> {
    const { pathname } = new URL(request.url);

    if (pathname === '/health' && request.method === 'GET') {
      return jsonResponse({ ok: true, service: 'receiver-worker' }, 200);
    }

    if (pathname === '/inbox' && request.method === 'POST') {
      return handleInbox(request, env);
    }

    return jsonResponse({ error: 'not found' }, 404);
  },
};
