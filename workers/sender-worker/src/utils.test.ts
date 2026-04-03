/**
 * Tests for utils.ts — json, errorResponse, corsPreflightResponse
 */

import { describe, it, expect } from 'vitest';
import { json, errorResponse, corsPreflightResponse } from './utils';
import { HTTP_STATUS, CONTENT_TYPES } from './types';

describe('json()', () => {
  it('serializes data as JSON with correct content-type', async () => {
    const res = json({ ok: true });
    expect(res.headers.get('content-type')).toBe(CONTENT_TYPES.JSON);
    const body = await res.json() as { ok: boolean };
    expect(body.ok).toBe(true);
  });

  it('uses 200 status by default', () => {
    const res = json({});
    expect(res.status).toBe(200);
  });

  it('accepts a custom status code via init', () => {
    const res = json({}, { status: HTTP_STATUS.CREATED });
    expect(res.status).toBe(HTTP_STATUS.CREATED);
  });

  it('merges extra headers from init without overwriting content-type', () => {
    const res = json({}, { headers: { 'x-custom': 'value' } });
    expect(res.headers.get('x-custom')).toBe('value');
    expect(res.headers.get('content-type')).toBe(CONTENT_TYPES.JSON);
  });
});

describe('errorResponse()', () => {
  it('returns a JSON response with error and code fields', async () => {
    const res = errorResponse('something broke', 'INTERNAL_ERROR', HTTP_STATUS.INTERNAL_SERVER_ERROR);
    expect(res.status).toBe(HTTP_STATUS.INTERNAL_SERVER_ERROR);
    const body = await res.json() as { error: string; code: string };
    expect(body.error).toBe('something broke');
    expect(body.code).toBe('INTERNAL_ERROR');
  });

  it('sets content-type to application/json', () => {
    const res = errorResponse('not found', 'NOT_FOUND', HTTP_STATUS.NOT_FOUND);
    expect(res.headers.get('content-type')).toBe(CONTENT_TYPES.JSON);
  });
});

describe('corsPreflightResponse()', () => {
  it('returns 204 No Content', () => {
    const res = corsPreflightResponse();
    expect(res.status).toBe(HTTP_STATUS.NO_CONTENT);
  });

  it('body is null (empty)', async () => {
    const res = corsPreflightResponse();
    const text = await res.text();
    expect(text).toBe('');
  });

  it('includes CORS allow-methods header', () => {
    const res = corsPreflightResponse();
    expect(res.headers.get('access-control-allow-methods')).toContain('POST');
  });

  it('includes CORS allow-headers header', () => {
    const res = corsPreflightResponse();
    const allowedHeaders = res.headers.get('access-control-allow-headers');
    expect(allowedHeaders).toContain('content-type');
  });
});
