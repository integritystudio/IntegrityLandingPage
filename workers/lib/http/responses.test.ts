import { describe, it, expect } from 'vitest';
import { json, text, html, ok, created, noContent, redirect } from './responses';

describe('json()', () => {
  it('sets content-type to application/json', async () => {
    const r = json({ a: 1 });
    expect(r.headers.get('content-type')).toBe('application/json; charset=utf-8');
  });

  it('serializes the body', async () => {
    const r = json({ hello: 'world' });
    expect(await r.json()).toEqual({ hello: 'world' });
  });

  it('defaults to status 200', () => {
    expect(json({}).status).toBe(200);
  });

  it('accepts a custom status', () => {
    expect(json({}, { status: 201 }).status).toBe(201);
  });

  it('does not override an existing content-type', async () => {
    const r = json({ a: 1 }, { headers: { 'content-type': 'application/vnd.api+json' } });
    expect(r.headers.get('content-type')).toBe('application/vnd.api+json');
  });
});

describe('text()', () => {
  it('sets content-type to text/plain', () => {
    expect(text('hi').headers.get('content-type')).toBe('text/plain; charset=utf-8');
  });

  it('returns the body as text', async () => {
    expect(await text('hello').text()).toBe('hello');
  });
});

describe('html()', () => {
  it('sets content-type to text/html', () => {
    expect(html('<p>hi</p>').headers.get('content-type')).toBe('text/html; charset=utf-8');
  });
});

describe('ok()', () => {
  it('returns status 200', () => {
    expect(ok({ data: 1 }).status).toBe(200);
  });

  it('serializes body as JSON', async () => {
    expect(await ok({ x: 2 }).json()).toEqual({ x: 2 });
  });
});

describe('created()', () => {
  it('returns status 201', () => {
    expect(created({ id: 1 }).status).toBe(201);
  });
});

describe('noContent()', () => {
  it('returns status 204', () => {
    expect(noContent().status).toBe(204);
  });

  it('has null body', () => {
    expect(noContent().body).toBeNull();
  });
});

describe('redirect()', () => {
  it('returns 302 by default', () => {
    expect(redirect('/login').status).toBe(302);
  });

  it('sets the location header', () => {
    expect(redirect('/login').headers.get('location')).toBe('/login');
  });

  it('accepts a custom status', () => {
    expect(redirect('/login', 301).status).toBe(301);
  });
});
