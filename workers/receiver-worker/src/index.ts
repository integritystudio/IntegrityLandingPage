import { REPLAY_WINDOW_MS } from '../../constants';
import { hmacVerify } from '../../lib/crypto';
import { hexToBytes } from '../../lib/hex-utils';
import { json } from '../../lib/http/responses';

interface Env {
  SHARED_SECRET: string;
}

async function handleInbox(request: Request, env: Env): Promise<Response> {
  const timestampHeader = request.headers.get('x-timestamp');
  const signatureHeader = request.headers.get('x-signature');

  if (!timestampHeader || !signatureHeader) {
    return json({ error: 'missing auth headers' }, { status: 401 });
  }

  const ts = Number(timestampHeader);
  if (isNaN(ts) || Math.abs(Date.now() - ts) > REPLAY_WINDOW_MS) {
    return json({ error: 'stale or invalid timestamp' }, { status: 401 });
  }

  const rawBody = await request.text();

  const sigBytes = hexToBytes(signatureHeader);
  if (!sigBytes || !await hmacVerify(env.SHARED_SECRET, sigBytes, `${timestampHeader}.${rawBody}`)) {
    return json({ error: 'invalid signature' }, { status: 401 });
  }

  let parsed: unknown;
  try {
    parsed = JSON.parse(rawBody);
  } catch {
    return json({ error: 'invalid json' }, { status: 400 });
  }

  const apiKey = `sk-${crypto.randomUUID().replace(/-/g, '')}`;
  return json({ ok: true, apiKey, received: parsed });
}

export default {
  async fetch(request: Request, env: Env): Promise<Response> {
    const { pathname } = new URL(request.url);

    if (pathname === '/health' && request.method === 'GET') {
      return json({ ok: true, service: 'receiver-worker' });
    }

    if (pathname === '/inbox' && request.method === 'POST') {
      return handleInbox(request, env);
    }

    return json({ error: 'not found' }, { status: 404 });
  },
};
