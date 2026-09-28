import { describe, it, expect, vi, afterEach } from 'vitest';
import { handleAuth0Logs } from './auth0-logs';
import {
  createSupabaseFetchStub,
  createdRows,
  httpError,
  TEST_SERVICE_ROLE_KEY,
  TEST_SUPABASE_URL,
} from '../../../lib/test-helpers/supabase-fetch-stub';

const STREAM_TOKEN = 'stream-token-0123456789abcdef';
const TABLE = 'auth0_logs';
const ENV = { supabaseUrl: TEST_SUPABASE_URL, serviceRoleKey: TEST_SERVICE_ROLE_KEY, streamToken: STREAM_TOKEN };

/** An event as an Auth0 custom-webhook log stream delivers it. */
const streamEvent = (logId: string, type = 's') => ({
  log_id: logId,
  data: {
    log_id: logId,
    date: '2026-09-28T12:00:00.000Z',
    type,
    description: 'Successful login',
    client_id: 'client-1',
    user_id: 'auth0|user-1',
    ip: '203.0.113.7',
  },
});

function post(body: unknown, authorization: string | null = `Bearer ${STREAM_TOKEN}`): Request {
  const headers: Record<string, string> = { 'Content-Type': 'application/json' };
  if (authorization !== null) headers.Authorization = authorization;
  return new Request('https://api.integritystudio.dev/v1/auth0-logs', {
    method: 'POST',
    headers,
    body: typeof body === 'string' ? body : JSON.stringify(body),
  });
}

function stubInsert(responder = createdRows([])) {
  const stub = createSupabaseFetchStub({ [`POST ${TABLE}`]: responder });
  vi.stubGlobal('fetch', stub.fetch);
  return stub;
}

afterEach(() => {
  vi.unstubAllGlobals();
});

describe('handleAuth0Logs — authentication (CR40)', () => {
  it('answers 503 and writes nothing while the token is unbound', async () => {
    const stub = stubInsert();

    const res = await handleAuth0Logs(post([streamEvent('log-1')]), { ...ENV, streamToken: undefined });

    expect(res.status).toBe(503);
    expect(stub.requests).toHaveLength(0);
  });

  it.each([
    ['no Authorization header', null],
    ['a wrong token', 'Bearer not-the-stream-token'],
    ['the token without the Bearer scheme', STREAM_TOKEN],
  ])('answers 401 and writes nothing for %s', async (_label, authorization) => {
    const stub = stubInsert();

    const res = await handleAuth0Logs(post([streamEvent('log-1')], authorization), ENV);

    expect(res.status).toBe(401);
    expect(stub.requests).toHaveLength(0);
  });
});

describe('handleAuth0Logs — stream payload', () => {
  it('inserts a batch as rows keyed on log_id, ignoring duplicates on retry', async () => {
    const stub = stubInsert();

    const res = await handleAuth0Logs(post([streamEvent('log-1'), streamEvent('log-2', 'f')]), ENV);

    expect(res.status).toBe(200);
    const insert = stub.find('POST', TABLE);
    expect(insert?.url.searchParams.get('on_conflict')).toBe('log_id');
    expect(insert?.headers.Prefer).toContain('resolution=ignore-duplicates');
    expect(insert?.body).toEqual([
      expect.objectContaining({ log_id: 'log-1', event_type: 's', user_id: 'auth0|user-1', ip_address: '203.0.113.7' }),
      expect.objectContaining({ log_id: 'log-2', event_type: 'f' }),
    ]);
  });

  it('takes a single event as a batch of one', async () => {
    const stub = stubInsert();

    const res = await handleAuth0Logs(post(streamEvent('log-1')), ENV);

    expect(res.status).toBe(200);
    expect(stub.find('POST', TABLE)?.body).toEqual([expect.objectContaining({ log_id: 'log-1' })]);
  });

  it('skips an invalid event and inserts the rest of its batch', async () => {
    const stub = stubInsert();

    const res = await handleAuth0Logs(post([{ log_id: 'bad' }, streamEvent('log-2')]), ENV);

    expect(res.status).toBe(200);
    expect(stub.find('POST', TABLE)?.body).toEqual([expect.objectContaining({ log_id: 'log-2' })]);
  });

  it.each([
    // The shape CR33's receiver expected; Auth0 never sends it.
    ['a flat log entry', [{ log_id: 'log-1', date: '2026-09-28T12:00:00.000Z', type: 's' }]],
    // What the event stream est_uRZqNG2BECcHmc1G2nrXpn delivered, 36 times, all rejected.
    ['a CloudEvent', [{ specversion: '1.0', id: 'evt-1', type: 'user.updated', data: { object: {} } }]],
    ['an empty batch', []],
  ])('answers 400 and writes nothing for %s', async (_label, body) => {
    const stub = stubInsert();

    const res = await handleAuth0Logs(post(body), ENV);

    expect(res.status).toBe(400);
    expect(stub.requests).toHaveLength(0);
  });

  it('answers 400 for a body that is not JSON', async () => {
    const stub = stubInsert();

    const res = await handleAuth0Logs(post('not json'), ENV);

    expect(res.status).toBe(400);
    expect(stub.requests).toHaveLength(0);
  });

  it('acknowledges a batch whose insert fails, so the stream is not suspended', async () => {
    stubInsert(httpError(500));

    const res = await handleAuth0Logs(post([streamEvent('log-1')]), ENV);

    expect(res.status).toBe(200);
  });
});
