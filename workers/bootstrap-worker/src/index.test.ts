import { describe, it, expect } from 'vitest';
import { verifySupabaseJwt, parseJwtHeader } from './auth';

describe('auth', () => {
  describe('parseJwtHeader', () => {
    it('should parse valid jwt header', () => {
      const token =
        'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9' +
        '.eyJzdWIiOiJ1c2VyLWlkIiwiZW1haWwiOiJ0ZXN0QGV4YW1wbGUuY29tIiwiaWF0IjoxNzAzMDAwMDAwLCJleHAiOjk5OTk5OTk5OTl9' +
        '.signature';

      const result = parseJwtHeader(token);

      expect(result.ok).toBe(true);
      expect(result.ok && result.payload.sub).toBe('user-id');
      expect(result.ok && result.payload.email).toBe('test@example.com');
    });

    it('should reject invalid jwt format', () => {
      const result = parseJwtHeader('not-a-jwt');

      expect(result.ok).toBe(false);
      expect(!result.ok && result.error).toContain('invalid jwt format');
    });
  });

  describe('verifySupabaseJwt', () => {
    it('should reject expired jwt', async () => {
      // exp is in the past (1603000000)
      const token =
        'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9' +
        '.eyJzdWIiOiJ1c2VyLWlkIiwiZW1haWwiOiJ0ZXN0QGV4YW1wbGUuY29tIiwiaWF0IjoxNzAzMDAwMDAwLCJleHAiOjE2MDMwMDAwMDB9' +
        '.signature';

      const result = await verifySupabaseJwt(token, 'secret');

      expect(result.ok).toBe(false);
      expect(!result.ok && result.error).toBeDefined();
    });

    it('should reject invalid signature', async () => {
      // Valid structure but bad signature
      const token =
        'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9' +
        '.eyJzdWIiOiJ1c2VyLWlkIiwiZW1haWwiOiJ0ZXN0QGV4YW1wbGUuY29tIiwiaWF0IjoxNzAzMDAwMDAwLCJleXAiOjk5OTk5OTk5OTl9' +
        '.invalidsignature';

      const result = await verifySupabaseJwt(token, 'secret');

      expect(result.ok).toBe(false);
      expect(!result.ok && result.error).toBeDefined();
    });
  });
});
