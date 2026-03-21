import { describe, it, expect, vi } from 'vitest';
import { handleMe } from './me';

const JWT_SECRET = 'test-jwt-secret-at-least-32-chars!!';

async function makeJwt(payload: Record<string, unknown>, secret: string): Promise<string> {
  const header = btoa(JSON.stringify({ alg: 'HS256', typ: 'JWT' }))
    .replace(/\+/g, '-').replace(/\//g, '_').replace(/=+$/, '');
  const body = btoa(JSON.stringify({ exp: 9999999999, ...payload }))
    .replace(/\+/g, '-').replace(/\//g, '_').replace(/=+$/, '');
  const msg = `${header}.${body}`;
  const key = await crypto.subtle.importKey(
    'raw', new TextEncoder().encode(secret),
    { name: 'HMAC', hash: 'SHA-256' }, false, ['sign'],
  );
  const sig = await crypto.subtle.sign('HMAC', key, new TextEncoder().encode(msg));
  const sigB64 = btoa(String.fromCharCode(...new Uint8Array(sig)))
    .replace(/\+/g, '-').replace(/\//g, '_').replace(/=+$/, '');
  return `${msg}.${sigB64}`;
}

function makeRequest(token?: string): Request {
  return new Request('https://api.integritystudio.ai/v1/me', {
    method: 'GET',
    headers: token ? { authorization: `Bearer ${token}` } : {},
  });
}

describe('GET /v1/me', () => {
  it('returns 401 when no bearer token', async () => {
    const res = await handleMe(makeRequest(), { jwtSecret: JWT_SECRET, supabaseUrl: '', serviceRoleKey: '' });
    expect(res.status).toBe(401);
  });

  it('returns 401 for expired jwt', async () => {
    const header = btoa(JSON.stringify({ alg: 'HS256', typ: 'JWT' }))
      .replace(/\+/g, '-').replace(/\//g, '_').replace(/=+$/, '');
    const body = btoa(JSON.stringify({ sub: 'user-1', email: 'a@b.com', exp: 1000000 }))
      .replace(/\+/g, '-').replace(/\//g, '_').replace(/=+$/, '');
    const expiredToken = `${header}.${body}.badsig`;
    const res = await handleMe(makeRequest(expiredToken), { jwtSecret: JWT_SECRET, supabaseUrl: '', serviceRoleKey: '' });
    expect(res.status).toBe(401);
  });

  it('returns 200 with user profile when jwt is valid and user exists', async () => {
    const token = await makeJwt({ sub: 'user-id-1', email: 'user@example.com' }, JWT_SECRET);
    const mockSb = {
      query: vi.fn().mockResolvedValue({
        ok: true,
        data: [{
          id: 'user-id-1',
          auth0_id: 'user-id-1',
          email: 'user@example.com',
          name: 'Test User',
          tier: 'free',
          default_organization_id: 'org-id-1',
          created_at: '2026-01-01T00:00:00Z',
        }],
      }),
      insert: vi.fn(),
      update: vi.fn(),
      rpc: vi.fn(),
    };

    const res = await handleMe(makeRequest(token), {
      jwtSecret: JWT_SECRET,
      supabaseUrl: 'https://test.supabase.co',
      serviceRoleKey: 'key',
      _sbOverride: mockSb as any,
    });

    expect(res.status).toBe(200);
    const body = await res.json() as any;
    expect(body.id).toBe('user-id-1');
    expect(body.email).toBe('user@example.com');
    expect(body.name).toBe('Test User');
  });

  it('returns 404 when user not found in db', async () => {
    const token = await makeJwt({ sub: 'ghost-user', email: 'ghost@example.com' }, JWT_SECRET);
    const mockSb = {
      query: vi.fn().mockResolvedValue({ ok: true, data: [] }),
      insert: vi.fn(),
      update: vi.fn(),
      rpc: vi.fn(),
    };

    const res = await handleMe(makeRequest(token), {
      jwtSecret: JWT_SECRET,
      supabaseUrl: 'https://test.supabase.co',
      serviceRoleKey: 'key',
      _sbOverride: mockSb as any,
    });

    expect(res.status).toBe(404);
  });
});
