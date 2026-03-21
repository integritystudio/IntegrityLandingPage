import { describe, it, expect, vi } from 'vitest';
import { handleCreateApiKey, handleRevokeApiKey } from './api-keys';
import { hashApiKeySecret, API_KEY_REGEX } from '../../../lib/api-keys';

const JWT_SECRET = 'test-jwt-secret-at-least-32-chars!!';
const HMAC_SECRET = 'test-hmac-secret-at-least-32-chars!';

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

const makeOpts = (sbOverride: any) => ({
  jwtSecret: JWT_SECRET,
  hmacSecret: HMAC_SECRET,
  supabaseUrl: 'https://test.supabase.co',
  serviceRoleKey: 'key',
  _sbOverride: sbOverride,
});

const makeMembership = (orgId = 'org-id-1', role = 'owner') => ({
  organization_id: orgId,
  user_id: 'user-id-1',
  role,
  status: 'active',
});

const makeUser = () => ({
  id: 'user-id-1',
  auth0_id: 'user-id-1',
  email: 'user@test.com',
});

describe('POST /v1/orgs/:orgId/api-keys', () => {
  it('returns 401 when no bearer token', async () => {
    const req = new Request('https://api.test/v1/orgs/org-id-1/api-keys', { method: 'POST' });
    const res = await handleCreateApiKey(req, 'org-id-1', makeOpts(null));
    expect(res.status).toBe(401);
  });

  it('returns 403 when user is not a member', async () => {
    const token = await makeJwt({ sub: 'user-id-1', email: 'u@test.com' }, JWT_SECRET);
    const mockSb = {
      query: vi.fn().mockResolvedValueOnce({ ok: true, data: [] }),
      insert: vi.fn(), update: vi.fn(), rpc: vi.fn(),
    };
    const req = new Request('https://api.test/v1/orgs/org-id-1/api-keys', {
      method: 'POST',
      headers: { authorization: `Bearer ${token}`, 'content-type': 'application/json' },
      body: JSON.stringify({ name: 'My Key' }),
    });
    const res = await handleCreateApiKey(req, 'org-id-1', makeOpts(mockSb));
    expect(res.status).toBe(403);
  });

  it('creates an API key for an org member and returns the token once', async () => {
    const token = await makeJwt({ sub: 'user-id-1', email: 'u@test.com' }, JWT_SECRET);
    const insertedKey = {
      id: 'new-key-id',
      prefix: 'WILLBESET',
      user_id: 'user-id-1',
      organization_id: 'org-id-1',
    };

    const mockSb = {
      query: vi.fn()
        .mockResolvedValueOnce({ ok: true, data: [makeMembership()] })
        .mockResolvedValueOnce({ ok: true, data: [makeUser()] }),
      insert: vi.fn().mockResolvedValue({ ok: true, data: [insertedKey] }),
      update: vi.fn(), rpc: vi.fn(),
    };

    const req = new Request('https://api.test/v1/orgs/org-id-1/api-keys', {
      method: 'POST',
      headers: { authorization: `Bearer ${token}`, 'content-type': 'application/json' },
      body: JSON.stringify({ name: 'CI Key' }),
    });

    const res = await handleCreateApiKey(req, 'org-id-1', makeOpts(mockSb));
    expect(res.status).toBe(201);
    const body = await res.json() as any;
    // Token must match the API key format
    expect(body.token).toMatch(API_KEY_REGEX);
    expect(body.id).toBe('new-key-id');
    expect(body.name).toBe('CI Key');
    // Hash is NOT returned — only the token (shown once)
    expect(body.hash).toBeUndefined();
    // Audit log written: first call is membership check, second is user lookup, third is audit_log insert
    expect(mockSb.insert).toHaveBeenCalledWith(
      'audit_log',
      expect.objectContaining({ action: 'api_key.created', target_type: 'api_key', actor_user_id: 'user-id-1' }),
    );
  });

  it('writes audit log even when audit insert fails, and still returns 201', async () => {
    const token = await makeJwt({ sub: 'user-id-1', email: 'u@test.com' }, JWT_SECRET);
    const insertedKey = { id: 'new-key-id', prefix: 'WILLBESET', user_id: 'user-id-1', organization_id: 'org-id-1' };

    const mockSb = {
      query: vi.fn()
        .mockResolvedValueOnce({ ok: true, data: [makeMembership()] })
        .mockResolvedValueOnce({ ok: true, data: [makeUser()] }),
      insert: vi.fn()
        .mockResolvedValueOnce({ ok: true, data: [insertedKey] })
        .mockResolvedValueOnce({ ok: false, error: 'db error' }),
      update: vi.fn(), rpc: vi.fn(),
    };

    const req = new Request('https://api.test/v1/orgs/org-id-1/api-keys', {
      method: 'POST',
      headers: { authorization: `Bearer ${token}`, 'content-type': 'application/json' },
      body: JSON.stringify({ name: 'CI Key' }),
    });

    const res = await handleCreateApiKey(req, 'org-id-1', makeOpts(mockSb));
    expect(res.status).toBe(201);
  });

  it('accepts optional expires_at for key creation', async () => {
    const token = await makeJwt({ sub: 'user-id-1', email: 'u@test.com' }, JWT_SECRET);
    const mockSb = {
      query: vi.fn()
        .mockResolvedValueOnce({ ok: true, data: [makeMembership()] })
        .mockResolvedValueOnce({ ok: true, data: [makeUser()] }),
      insert: vi.fn().mockResolvedValue({ ok: true, data: [{ id: 'key-id', prefix: 'abc', user_id: 'user-id-1', organization_id: 'org-id-1' }] }),
      update: vi.fn(), rpc: vi.fn(),
    };
    const req = new Request('https://api.test/v1/orgs/org-id-1/api-keys', {
      method: 'POST',
      headers: { authorization: `Bearer ${token}`, 'content-type': 'application/json' },
      body: JSON.stringify({ name: 'Expiring Key', expires_at: '2027-01-01T00:00:00Z' }),
    });
    const res = await handleCreateApiKey(req, 'org-id-1', makeOpts(mockSb));
    expect(res.status).toBe(201);
    // Verify insert was called with expires_at
    expect(mockSb.insert).toHaveBeenCalledWith(
      'api_keys',
      expect.objectContaining({ expires_at: '2027-01-01T00:00:00Z' }),
      expect.anything(),
    );
  });
});

describe('POST /v1/orgs/:orgId/api-keys/:keyId/revoke', () => {
  it('returns 401 when no bearer token', async () => {
    const req = new Request('https://api.test/v1/orgs/org-id-1/api-keys/key-id/revoke', { method: 'POST' });
    const res = await handleRevokeApiKey(req, 'org-id-1', 'key-id', makeOpts(null));
    expect(res.status).toBe(401);
  });

  it('returns 403 when user is not a member', async () => {
    const token = await makeJwt({ sub: 'user-id-1', email: 'u@test.com' }, JWT_SECRET);
    const mockSb = {
      query: vi.fn().mockResolvedValueOnce({ ok: true, data: [] }),
      insert: vi.fn(), update: vi.fn(), rpc: vi.fn(),
    };
    const req = new Request('https://api.test/v1/orgs/org-id-1/api-keys/key-id/revoke', {
      method: 'POST',
      headers: { authorization: `Bearer ${token}` },
    });
    const res = await handleRevokeApiKey(req, 'org-id-1', 'key-id', makeOpts(mockSb));
    expect(res.status).toBe(403);
  });

  it('returns 404 when key does not belong to the org', async () => {
    const token = await makeJwt({ sub: 'user-id-1', email: 'u@test.com' }, JWT_SECRET);
    const mockSb = {
      query: vi.fn()
        .mockResolvedValueOnce({ ok: true, data: [makeMembership()] })
        .mockResolvedValueOnce({ ok: true, data: [] }),
      insert: vi.fn(), update: vi.fn(), rpc: vi.fn(),
    };
    const req = new Request('https://api.test/v1/orgs/org-id-1/api-keys/key-id/revoke', {
      method: 'POST',
      headers: { authorization: `Bearer ${token}` },
    });
    const res = await handleRevokeApiKey(req, 'org-id-1', 'key-id', makeOpts(mockSb));
    expect(res.status).toBe(404);
  });

  it('revokes the key and returns 200', async () => {
    const token = await makeJwt({ sub: 'user-id-1', email: 'u@test.com' }, JWT_SECRET);
    const existingKey = {
      id: 'key-id',
      organization_id: 'org-id-1',
      user_id: 'user-id-1',
      status: 'active',
      revoked_at: null,
    };

    const mockSb = {
      query: vi.fn()
        .mockResolvedValueOnce({ ok: true, data: [makeMembership()] })
        .mockResolvedValueOnce({ ok: true, data: [existingKey] }),
      insert: vi.fn().mockResolvedValue({ ok: true, data: [] }),
      update: vi.fn().mockResolvedValue({ ok: true, data: [{ ...existingKey, status: 'revoked', revoked_at: '2026-03-20T00:00:00Z' }] }),
      rpc: vi.fn(),
    };

    const req = new Request('https://api.test/v1/orgs/org-id-1/api-keys/key-id/revoke', {
      method: 'POST',
      headers: { authorization: `Bearer ${token}` },
    });

    const res = await handleRevokeApiKey(req, 'org-id-1', 'key-id', makeOpts(mockSb));
    expect(res.status).toBe(200);
    const body = await res.json() as any;
    expect(body.id).toBe('key-id');
    expect(body.status).toBe('revoked');
    expect(mockSb.update).toHaveBeenCalledWith(
      'api_keys',
      expect.objectContaining({ status: 'revoked' }),
      expect.any(Array),
      expect.anything(),
    );
    // Audit log written for revoke
    expect(mockSb.insert).toHaveBeenCalledWith(
      'audit_log',
      expect.objectContaining({ action: 'api_key.revoked', target_type: 'api_key', target_id: 'key-id' }),
    );
  });
});
