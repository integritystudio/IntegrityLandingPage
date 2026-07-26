import { describe, it, expect, vi, beforeEach, afterEach } from 'vitest';
import { createSupabaseClient } from './supabase';

const SUPABASE_URL = 'https://project.supabase.co';
const SERVICE_ROLE_KEY = 'test-service-role-key';
const PREFER_HEADER = 'prefer';
const RETURN_REPRESENTATION = 'return=representation';
const RETURN_MINIMAL = 'return=minimal';

function lastRequest(fetchMock: ReturnType<typeof vi.fn>) {
  const [url, init] = fetchMock.mock.calls[0] as [URL, RequestInit];
  return { url: new URL(url), headers: (init.headers ?? {}) as Record<string, string> };
}

describe('supabase client write paths', () => {
  let fetchMock: ReturnType<typeof vi.fn>;

  beforeEach(() => {
    fetchMock = vi.fn();
    vi.stubGlobal('fetch', fetchMock);
  });

  afterEach(() => {
    vi.unstubAllGlobals();
  });

  describe('insert', () => {
    it('requests the representation via the Prefer header, not a query param', async () => {
      fetchMock.mockResolvedValue(
        new Response(JSON.stringify([{ id: 'row-1' }]), { status: 201 }),
      );
      const sb = createSupabaseClient(SUPABASE_URL, SERVICE_ROLE_KEY);

      const result = await sb.insert('api_keys', { name: 'Default' });

      const { url, headers } = lastRequest(fetchMock);
      expect(headers[PREFER_HEADER]).toBe(RETURN_REPRESENTATION);
      expect(url.searchParams.has('returning')).toBe(false);
      expect(result).toEqual({ ok: true, data: [{ id: 'row-1' }] });
    });

    it('asks for a minimal return and does not parse the empty body', async () => {
      fetchMock.mockResolvedValue(new Response(null, { status: 201 }));
      const sb = createSupabaseClient(SUPABASE_URL, SERVICE_ROLE_KEY);

      const result = await sb.insert('audit_log', { action: 'test' }, { returning: 'minimal' });

      expect(lastRequest(fetchMock).headers[PREFER_HEADER]).toBe(RETURN_MINIMAL);
      expect(result).toEqual({ ok: true, data: null });
    });

    it('reports the HTTP error body when the insert fails', async () => {
      fetchMock.mockResolvedValue(new Response('duplicate key', { status: 409 }));
      const sb = createSupabaseClient(SUPABASE_URL, SERVICE_ROLE_KEY);

      const result = await sb.insert('api_keys', { name: 'Default' });

      expect(result).toEqual({ ok: false, error: 'HTTP 409: duplicate key' });
    });
  });

  describe('update', () => {
    it('requests the representation via the Prefer header and returns the updated rows', async () => {
      fetchMock.mockResolvedValue(
        new Response(JSON.stringify([{ id: 'row-1', status: 'revoked' }]), { status: 200 }),
      );
      const sb = createSupabaseClient(SUPABASE_URL, SERVICE_ROLE_KEY);

      const result = await sb.update(
        'api_keys',
        { status: 'revoked' },
        [{ column: 'id', operator: 'eq', value: 'row-1' }],
      );

      const { url, headers } = lastRequest(fetchMock);
      expect(headers[PREFER_HEADER]).toBe(RETURN_REPRESENTATION);
      expect(url.searchParams.has('returning')).toBe(false);
      expect(url.searchParams.get('id')).toBe('eq.row-1');
      expect(result).toEqual({ ok: true, data: [{ id: 'row-1', status: 'revoked' }] });
    });

    it('asks for a minimal return and handles the 204 response', async () => {
      fetchMock.mockResolvedValue(new Response(null, { status: 204 }));
      const sb = createSupabaseClient(SUPABASE_URL, SERVICE_ROLE_KEY);

      const result = await sb.update(
        'api_keys',
        { status: 'revoked' },
        [{ column: 'id', operator: 'eq', value: 'row-1' }],
        { returning: 'minimal' },
      );

      expect(lastRequest(fetchMock).headers[PREFER_HEADER]).toBe(RETURN_MINIMAL);
      expect(result).toEqual({ ok: true, data: null });
    });
  });
});
