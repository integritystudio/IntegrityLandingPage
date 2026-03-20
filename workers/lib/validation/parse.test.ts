import { describe, it, expect } from 'vitest';
import { z } from 'zod';
import { zodValidationError, requireValidJson } from './parse';

const testSchema = z.object({
  name: z.string().min(1),
  age: z.number().int().min(0),
});

describe('zodValidationError()', () => {
  it('returns 422', () => {
    const result = testSchema.safeParse({ name: '', age: -1 });
    expect(result.success).toBe(false);
    if (!result.success) {
      expect(zodValidationError(result.error).status).toBe(422);
    }
  });

  it('includes issues in body', async () => {
    const result = testSchema.safeParse({ name: '', age: 'bad' });
    if (!result.success) {
      const body = await zodValidationError(result.error).json() as any;
      expect(body.error.details.issues).toBeInstanceOf(Array);
      expect(body.error.details.issues.length).toBeGreaterThan(0);
    }
  });

  it('formats nested path correctly', async () => {
    const nested = z.object({ user: z.object({ email: z.string().email() }) });
    const result = nested.safeParse({ user: { email: 'bad' } });
    if (!result.success) {
      const body = await zodValidationError(result.error).json() as any;
      const issue = body.error.details.issues[0];
      expect(issue.path).toBe('user.email');
    }
  });

  it('formats root-level path as "root"', async () => {
    const schema = z.string();
    const result = schema.safeParse(123);
    if (!result.success) {
      const body = await zodValidationError(result.error).json() as any;
      expect(body.error.details.issues[0].path).toBe('root');
    }
  });
});

describe('requireValidJson()', () => {
  it('returns ok: false + 400 when content-type is wrong', async () => {
    const r = new Request('http://t/', {
      method: 'POST',
      headers: { 'content-type': 'text/plain' },
      body: '{"name":"Bob","age":30}',
    });
    const result = await requireValidJson(r, testSchema);
    expect(result.ok).toBe(false);
    if (!result.ok) expect(result.error.status).toBe(400);
  });

  it('returns ok: false + 400 for invalid JSON syntax', async () => {
    const r = new Request('http://t/', {
      method: 'POST',
      headers: { 'content-type': 'application/json' },
      body: 'not json',
    });
    const result = await requireValidJson(r, testSchema);
    expect(result.ok).toBe(false);
    if (!result.ok) expect(result.error.status).toBe(400);
  });

  it('returns ok: false + 422 for schema violations', async () => {
    const r = new Request('http://t/', {
      method: 'POST',
      headers: { 'content-type': 'application/json' },
      body: JSON.stringify({ name: '', age: -5 }),
    });
    const result = await requireValidJson(r, testSchema);
    expect(result.ok).toBe(false);
    if (!result.ok) expect(result.error.status).toBe(422);
  });

  it('returns ok: true with typed data for valid input', async () => {
    const r = new Request('http://t/', {
      method: 'POST',
      headers: { 'content-type': 'application/json' },
      body: JSON.stringify({ name: 'Alice', age: 30 }),
    });
    const result = await requireValidJson(r, testSchema);
    expect(result).toEqual({ ok: true, data: { name: 'Alice', age: 30 } });
  });
});
