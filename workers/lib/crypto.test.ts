import { describe, it, expect } from 'vitest';
import { hmacSign, hmacSignHex, hmacVerify, secretsEqual, sha256Hex } from './crypto';

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

describe('sha256Hex', () => {
  it('returns a 64-char lowercase hex string', async () => {
    const hex = await sha256Hex('obtk_test_key');
    expect(hex).toMatch(/^[0-9a-f]{64}$/);
  });

  it('is deterministic for the same input', async () => {
    const a = await sha256Hex('obtk_test_key');
    const b = await sha256Hex('obtk_test_key');
    expect(a).toBe(b);
  });

  it('produces a different digest for different inputs', async () => {
    const a = await sha256Hex('obtk_key_one');
    const b = await sha256Hex('obtk_key_two');
    expect(a).not.toBe(b);
  });

  it('differs from hmacSignHex for the same input — it has no key', async () => {
    // sha256Hex is a plain digest; hmacSignHex is a keyed HMAC. They must not collide.
    const digest = await sha256Hex(MESSAGE);
    const hmac = await hmacSignHex('any-key', MESSAGE);
    expect(digest).not.toBe(hmac);
  });
});

describe('secretsEqual', () => {
  it('accepts the expected secret', async () => {
    expect(await secretsEqual(SECRET, SECRET)).toBe(true);
  });

  it('rejects a secret differing in one character', async () => {
    expect(await secretsEqual(SECRET, 'test-secret-kez')).toBe(false);
  });

  it('rejects a prefix of the secret and the secret with a suffix', async () => {
    expect(await secretsEqual(SECRET, SECRET.slice(0, -1))).toBe(false);
    expect(await secretsEqual(SECRET, `${SECRET}x`)).toBe(false);
  });

  it('rejects an empty presented secret', async () => {
    expect(await secretsEqual(SECRET, '')).toBe(false);
  });
});
