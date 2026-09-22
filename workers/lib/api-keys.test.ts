import { describe, it, expect, vi, beforeEach } from 'vitest';
import {
  API_KEY_PREFIX,
  API_KEY_REGEX,
  parseApiKey,
  hashApiKeyToken,
  hashApiKeySecret,
  verifyApiKeyHash,
  verifyApiKey,
  generateApiKey,
} from './api-keys';
import type { ApiKey } from './types';

const TEST_HMAC_SECRET = 'test-hmac-secret-32-chars-minimum';

describe('api-keys', () => {
  describe('parseApiKey', () => {
    it('parses a valid api key', () => {
      const result = parseApiKey('int_live_abc12345_supersecretvalue32chars00');
      expect(result).toEqual({
        ok: true,
        format: 'legacy',
        prefix: 'abc12345',
        secret: 'supersecretvalue32chars00',
      });
    });

    it('rejects a key missing the int_live_ prefix', () => {
      const result = parseApiKey('bad_abc12345_secret');
      expect(result.ok).toBe(false);
    });

    it('rejects a key with no separator', () => {
      const result = parseApiKey('int_live_nosecret');
      expect(result.ok).toBe(false);
    });

    it('rejects an empty string', () => {
      const result = parseApiKey('');
      expect(result.ok).toBe(false);
    });
  });

  describe('hashApiKeySecret', () => {
    it('produces a hex string for a given secret', async () => {
      const hash = await hashApiKeySecret('mysecret', TEST_HMAC_SECRET);
      expect(hash).toMatch(/^[0-9a-f]{64}$/);
    });

    it('produces the same hash for the same inputs', async () => {
      const a = await hashApiKeySecret('mysecret', TEST_HMAC_SECRET);
      const b = await hashApiKeySecret('mysecret', TEST_HMAC_SECRET);
      expect(a).toBe(b);
    });

    it('produces different hashes for different secrets', async () => {
      const a = await hashApiKeySecret('secret1', TEST_HMAC_SECRET);
      const b = await hashApiKeySecret('secret2', TEST_HMAC_SECRET);
      expect(a).not.toBe(b);
    });

    it('produces different hashes for different hmac secrets', async () => {
      const a = await hashApiKeySecret('mysecret', 'hmac-key-a');
      const b = await hashApiKeySecret('mysecret', 'hmac-key-b');
      expect(a).not.toBe(b);
    });
  });

  describe('verifyApiKeyHash', () => {
    it('returns true when secret matches stored hash', async () => {
      const secret = 'correct-secret-value';
      const storedHash = await hashApiKeySecret(secret, TEST_HMAC_SECRET);
      const result = await verifyApiKeyHash(secret, storedHash, TEST_HMAC_SECRET);
      expect(result).toBe(true);
    });

    it('returns false when secret does not match', async () => {
      const storedHash = await hashApiKeySecret('correct-secret', TEST_HMAC_SECRET);
      const result = await verifyApiKeyHash('wrong-secret', storedHash, TEST_HMAC_SECRET);
      expect(result).toBe(false);
    });
  });

  describe('verifyApiKey', () => {
    const makeApiKey = (overrides: Partial<ApiKey> = {}): ApiKey => ({
      id: 'key-id-1',
      user_id: 'user-id-1',
      organization_id: 'org-id-1',
      prefix: 'abc12345',
      hash: '',
      name: 'Default',
      tier: 'starter',
      status: 'active',
      expires_at: null,
      last_used_at: null,
      created_at: '2026-01-01T00:00:00Z',
      revoked_at: null,
      ...overrides,
    });

    it('returns ok when token is valid and active', async () => {
      const secret = 'validsecret32charsminimum00000000';
      const hash = await hashApiKeySecret(secret, TEST_HMAC_SECRET);
      const apiKey = makeApiKey({ hash });

      const mockSb = {
        query: vi.fn().mockResolvedValue({ ok: true, data: [apiKey] }),
        insert: vi.fn(),
        update: vi.fn(),
        rpc: vi.fn(),
      };

      const result = await verifyApiKey(
        `int_live_abc12345_${secret}`,
        TEST_HMAC_SECRET,
        mockSb as any,
      );

      expect(result.ok).toBe(true);
      if (result.ok) {
        expect(result.userId).toBe('user-id-1');
        expect(result.organizationId).toBe('org-id-1');
        expect(result.apiKey.id).toBe('key-id-1');
      }
    });

    it('returns error for invalid key format', async () => {
      const mockSb = { query: vi.fn(), insert: vi.fn(), update: vi.fn(), rpc: vi.fn() };
      const result = await verifyApiKey('badtoken', TEST_HMAC_SECRET, mockSb as any);
      expect(result.ok).toBe(false);
    });

    it('returns error when key not found in db', async () => {
      const mockSb = {
        query: vi.fn().mockResolvedValue({ ok: true, data: [] }),
        insert: vi.fn(),
        update: vi.fn(),
        rpc: vi.fn(),
      };
      const result = await verifyApiKey(
        'int_live_notfound_secret32charsminimum000',
        TEST_HMAC_SECRET,
        mockSb as any,
      );
      expect(result.ok).toBe(false);
    });

    it('returns error when key is revoked', async () => {
      const secret = 'validsecret32charsminimum00000000';
      const hash = await hashApiKeySecret(secret, TEST_HMAC_SECRET);
      const apiKey = makeApiKey({ hash, status: 'revoked', revoked_at: '2026-01-01T00:00:00Z' });

      const mockSb = {
        query: vi.fn().mockResolvedValue({ ok: true, data: [apiKey] }),
        insert: vi.fn(),
        update: vi.fn(),
        rpc: vi.fn(),
      };

      const result = await verifyApiKey(
        `int_live_abc12345_${secret}`,
        TEST_HMAC_SECRET,
        mockSb as any,
      );
      expect(result.ok).toBe(false);
    });

    it('returns error when key is expired', async () => {
      const secret = 'validsecret32charsminimum00000000';
      const hash = await hashApiKeySecret(secret, TEST_HMAC_SECRET);
      const apiKey = makeApiKey({ hash, expires_at: '2020-01-01T00:00:00Z' });

      const mockSb = {
        query: vi.fn().mockResolvedValue({ ok: true, data: [apiKey] }),
        insert: vi.fn(),
        update: vi.fn(),
        rpc: vi.fn(),
      };

      const result = await verifyApiKey(
        `int_live_abc12345_${secret}`,
        TEST_HMAC_SECRET,
        mockSb as any,
      );
      expect(result.ok).toBe(false);
    });

    it('returns error when secret hash does not match', async () => {
      const apiKey = makeApiKey({ hash: 'deadbeef' });

      const mockSb = {
        query: vi.fn().mockResolvedValue({ ok: true, data: [apiKey] }),
        insert: vi.fn(),
        update: vi.fn(),
        rpc: vi.fn(),
      };

      const result = await verifyApiKey(
        'int_live_abc12345_wrongsecret32charsminimum',
        TEST_HMAC_SECRET,
        mockSb as any,
      );
      expect(result.ok).toBe(false);
    });
  });

  // ── obtk_: the format every live key uses (BACKLOG UA07) ────────────────────
  describe('obtk_ tokens', () => {
    // Fixed vector: sha256 over the WHOLE token, as api-keys-create stores it.
    const OBTOOL_TOKEN = `obtk_a3b04102${'f'.repeat(56)}`;
    const OBTOOL_HASH = '3bb195d74926d133a50e5c56264cebb627ed4d415c5cc749e6f5774a7ab947d2';

    const makeObtoolKey = (overrides: Partial<ApiKey> = {}): ApiKey => ({
      id: 'key-id-1',
      user_id: 'user-id-1',
      organization_id: 'org-id-1',
      prefix: 'a3b04102',
      hash: OBTOOL_HASH,
      name: 'inventoryai-growth',
      tier: 'growth',
      status: 'active',
      expires_at: null,
      last_used_at: null,
      created_at: '2026-01-01T00:00:00Z',
      revoked_at: null,
      ...overrides,
    });

    const mockSbReturning = (data: ApiKey[]) => ({
      query: vi.fn().mockResolvedValue({ ok: true, data }),
      insert: vi.fn(),
      update: vi.fn(),
      rpc: vi.fn(),
    });

    it('parses as the obtool format, prefix being the first 8 hex of the body', () => {
      const result = parseApiKey(OBTOOL_TOKEN);
      expect(result).toEqual({ ok: true, format: 'obtool', prefix: 'a3b04102' });
    });

    it.each([
      ['too short a body', `obtk_${'a'.repeat(63)}`],
      ['too long a body', `obtk_${'a'.repeat(65)}`],
      ['uppercase hex', `obtk_${'A'.repeat(64)}`],
      ['non-hex body', `obtk_${'g'.repeat(64)}`],
      ['no body', 'obtk_'],
      ['wrong scheme', `obtool_${'a'.repeat(64)}`],
    ])('rejects %s', (_label, token) => {
      expect(parseApiKey(token)).toEqual({ ok: false });
    });

    it('hashes the whole token, not the body', async () => {
      expect(await hashApiKeyToken(OBTOOL_TOKEN)).toBe(OBTOOL_HASH);
      expect(await hashApiKeyToken(OBTOOL_TOKEN.slice('obtk_'.length))).not.toBe(OBTOOL_HASH);
    });

    it('verifies by digest, looking the row up on the unique hash column', async () => {
      const mockSb = mockSbReturning([makeObtoolKey()]);

      const result = await verifyApiKey(OBTOOL_TOKEN, TEST_HMAC_SECRET, mockSb as any);

      expect(result.ok).toBe(true);
      if (result.ok) {
        expect(result.userId).toBe('user-id-1');
        expect(result.organizationId).toBe('org-id-1');
      }
      // Not by prefix: `(organization_id, prefix)` is unique per org, `hash` globally.
      expect(mockSb.query).toHaveBeenCalledWith('api_keys', expect.objectContaining({
        filters: [{ column: 'hash', operator: 'eq', value: OBTOOL_HASH }],
        limit: 1,
      }));
    });

    // The digest keys on nothing, so a gateway without API_KEY_HMAC_SECRET — or with
    // a rotated one — must still accept a valid obtk_ key.
    it('does not consult the HMAC secret', async () => {
      const mockSb = mockSbReturning([makeObtoolKey()]);
      const result = await verifyApiKey(OBTOOL_TOKEN, 'a-completely-unrelated-secret', mockSb as any);
      expect(result.ok).toBe(true);
    });

    it('rejects a token whose digest matches no row', async () => {
      const mockSb = { query: vi.fn().mockResolvedValue({ ok: true, data: [] }), insert: vi.fn(), update: vi.fn(), rpc: vi.fn() };
      const result = await verifyApiKey(OBTOOL_TOKEN, TEST_HMAC_SECRET, mockSb as any);
      expect(result.ok).toBe(false);
      if (!result.ok) expect(result.error.status).toBe(401);
    });

    it.each([
      ['revoked', { status: 'revoked' as const, revoked_at: '2026-09-20T00:00:00Z' }],
      ['expired', { expires_at: '2020-01-01T00:00:00Z' }],
    ])('rejects a %s key even though the digest matched', async (_label, overrides) => {
      const mockSb = mockSbReturning([makeObtoolKey(overrides)]);
      const result = await verifyApiKey(OBTOOL_TOKEN, TEST_HMAC_SECRET, mockSb as any);
      expect(result.ok).toBe(false);
      if (!result.ok) expect(result.error.status).toBe(401);
    });
  });

  describe('generateApiKey', () => {
    it('generates a key matching the expected format', () => {
      const { token, prefix, secret } = generateApiKey();
      expect(token).toMatch(API_KEY_REGEX);
      expect(token.startsWith(API_KEY_PREFIX)).toBe(true);
      expect(token).toContain(prefix);
      expect(token).toContain(secret);
    });

    it('generates unique keys on each call', () => {
      const a = generateApiKey();
      const b = generateApiKey();
      expect(a.token).not.toBe(b.token);
    });
  });
});
