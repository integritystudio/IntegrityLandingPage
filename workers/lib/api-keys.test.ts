import { describe, it, expect, vi, beforeEach } from 'vitest';
import {
  API_KEY_PREFIX,
  API_KEY_REGEX,
  parseApiKey,
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
      expect(result.ok).toBe(true);
      if (result.ok) {
        expect(result.prefix).toBe('abc12345');
        expect(result.secret).toBe('supersecretvalue32chars00');
      }
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
