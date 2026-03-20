import { describe, it, expect, vi } from 'vitest';
import {
  errorResponse,
  badRequest,
  unauthorized,
  forbidden,
  notFound,
  methodNotAllowed,
  conflict,
  unprocessableEntity,
  tooManyRequests,
  serverError,
  withErrorHandling,
} from './errors';

describe('errorResponse()', () => {
  it('sets the correct status code', () => {
    expect(errorResponse(422, 'invalid').status).toBe(422);
  });

  it('wraps message under error.message', async () => {
    const body = await errorResponse(400, 'oops').json() as { error: { message: string } };
    expect(body.error.message).toBe('oops');
  });

  it('includes details when provided', async () => {
    const body = await errorResponse(400, 'bad', { field: 'email' }).json() as any;
    expect(body.error.details).toEqual({ field: 'email' });
  });

  it('omits details key when undefined', async () => {
    const body = await errorResponse(400, 'bad').json() as any;
    expect(body.error).not.toHaveProperty('details');
  });

  it('sets content-type to application/json', () => {
    expect(errorResponse(400, 'bad').headers.get('content-type')).toBe('application/json; charset=utf-8');
  });
});

describe('HTTP error helpers', () => {
  it('badRequest returns 400', () => expect(badRequest().status).toBe(400));
  it('unauthorized returns 401', () => expect(unauthorized().status).toBe(401));
  it('forbidden returns 403', () => expect(forbidden().status).toBe(403));
  it('notFound returns 404', () => expect(notFound().status).toBe(404));
  it('conflict returns 409', () => expect(conflict().status).toBe(409));
  it('unprocessableEntity returns 422', () => expect(unprocessableEntity().status).toBe(422));
  it('tooManyRequests returns 429', () => expect(tooManyRequests().status).toBe(429));
  it('serverError returns 500', () => expect(serverError().status).toBe(500));
});

describe('methodNotAllowed()', () => {
  it('returns 405', () => {
    expect(methodNotAllowed(['GET', 'POST']).status).toBe(405);
  });

  it('sets Allow header', () => {
    expect(methodNotAllowed(['GET', 'POST']).headers.get('allow')).toBe('GET, POST');
  });

  it('includes allowedMethods in details', async () => {
    const body = await methodNotAllowed(['GET']).json() as any;
    expect(body.error.details.allowedMethods).toEqual(['GET']);
  });
});

describe('withErrorHandling()', () => {
  it('passes through successful response', async () => {
    const handler = withErrorHandling(() => new Response('ok', { status: 200 }));
    const r = await handler(new Request('http://test/'));
    expect(r.status).toBe(200);
  });

  it('returns 500 on unhandled error', async () => {
    const handler = withErrorHandling(() => { throw new Error('boom'); });
    const r = await handler(new Request('http://test/'));
    expect(r.status).toBe(500);
  });

  it('uses custom error handler when provided', async () => {
    const onError = () => new Response('custom', { status: 418 });
    const handler = withErrorHandling(() => { throw new Error('boom'); }, onError);
    const r = await handler(new Request('http://test/'));
    expect(r.status).toBe(418);
  });
});
