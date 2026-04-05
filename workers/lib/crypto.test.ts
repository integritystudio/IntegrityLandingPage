import { describe, it, expect } from 'vitest';
import { hmacSign, hmacSignHex, hmacVerify } from './crypto';

const SECRET = 'test-secret-key';
const MESSAGE = 'hello.world';

describe('hmacSign', () => {
  it('returns an ArrayBuffer', async () => {
    const buf = await hmacSign(SECRET, MESSAGE);
    expect(buf).toBeInstanceOf(ArrayBuffer);
    expect(buf.byteLength).toBe(32); // SHA-256 = 32 bytes
  });

  it('is deterministic for the same inputs', async () => {
    const a = await hmacSign(SECRET, MESSAGE);
    const b = await hmacSign(SECRET, MESSAGE);
    expect(new Uint8Array(a)).toEqual(new Uint8Array(b));
  });

  it('produces different output for different secrets', async () => {
    const a = await hmacSign('secret-a', MESSAGE);
    const b = await hmacSign('secret-b', MESSAGE);
    expect(new Uint8Array(a)).not.toEqual(new Uint8Array(b));
  });
});

describe('hmacSignHex', () => {
  it('returns a 64-char lowercase hex string', async () => {
    const hex = await hmacSignHex(SECRET, MESSAGE);
    expect(hex).toMatch(/^[0-9a-f]{64}$/);
  });

  it('is deterministic', async () => {
    const a = await hmacSignHex(SECRET, MESSAGE);
    const b = await hmacSignHex(SECRET, MESSAGE);
    expect(a).toBe(b);
  });
});

describe('hmacVerify', () => {
  it('returns true for a valid signature', async () => {
    const buf = await hmacSign(SECRET, MESSAGE);
    const result = await hmacVerify(SECRET, new Uint8Array(buf), MESSAGE);
    expect(result).toBe(true);
  });

  it('returns false for a wrong secret', async () => {
    const buf = await hmacSign(SECRET, MESSAGE);
    const result = await hmacVerify('wrong-secret', new Uint8Array(buf), MESSAGE);
    expect(result).toBe(false);
  });

  it('returns false for a tampered message', async () => {
    const buf = await hmacSign(SECRET, MESSAGE);
    const result = await hmacVerify(SECRET, new Uint8Array(buf), 'tampered.message');
    expect(result).toBe(false);
  });

  it('returns false for a zero-length signature', async () => {
    const result = await hmacVerify(SECRET, new Uint8Array(0), MESSAGE);
    expect(result).toBe(false);
  });
});
