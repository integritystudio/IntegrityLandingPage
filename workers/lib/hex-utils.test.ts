import { describe, it, expect } from 'vitest';
import { hexToBytes } from './hex-utils';

describe('hexToBytes', () => {
  it('converts a valid hex string', () => {
    const result = hexToBytes('deadbeef');
    expect(result).toEqual(new Uint8Array([0xde, 0xad, 0xbe, 0xef]));
  });

  it('converts a 64-char HMAC-SHA256 hex string', () => {
    const hex = 'a'.repeat(64);
    const result = hexToBytes(hex);
    expect(result).toHaveLength(32);
  });

  it('returns null for empty string', () => {
    expect(hexToBytes('')).toBeNull();
  });

  it('returns null for odd-length hex', () => {
    expect(hexToBytes('abc')).toBeNull();
  });

  it('returns null for non-hex characters', () => {
    expect(hexToBytes('zz')).toBeNull();
  });

  it('returns null for uppercase hex', () => {
    expect(hexToBytes('DEADBEEF')).toBeNull();
  });

  it('returns null for hex with spaces', () => {
    expect(hexToBytes('de ad')).toBeNull();
  });
});
