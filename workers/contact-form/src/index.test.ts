/**
 * Tests for Integrity Studio Contact Form Worker
 *
 * Tests email submission triggers, validation, and Resend integration.
 * Run with: npm test
 */

import { describe, it, expect, vi, beforeEach } from 'vitest';

// API response types
interface ErrorResponse {
  error: string;
}

interface SuccessResponse {
  success: boolean;
  submissionId: string;
  message: string;
}

type ApiResponse = ErrorResponse | SuccessResponse;

// Mock Resend
vi.mock('resend', () => ({
  Resend: vi.fn(function() {
    return {
      emails: {
        send: vi.fn(),
      },
    };
  }),
}));

import { Resend } from 'resend';

// Import the worker handler and test utilities
import worker, { _resetRateLimitState } from './index';
import {
  CSRF_TOKEN_MAX_AGE_MS,
  KV_CIRCUIT_BREAKER_THRESHOLD,
  KV_CIRCUIT_RESET_COOLDOWN_MS,
  KV_CIRCUIT_RESET_JITTER_MS,
  MAX_COMPANY_SIZE_LENGTH,
  MAX_MESSAGE_LENGTH,
  MAX_NAME_LENGTH,
  MAX_USE_CASE_LENGTH,
} from '../../constants';

// Mock environment
const mockEnv = {
  RESEND_API_KEY: 'test_resend_api_key',
  RECIPIENT_EMAIL: 'test@integritystudio.ai',
  SENDER_EMAIL: 'contact@integritystudio.ai',
};

// Mock environment with CSRF enabled
const mockEnvWithCsrf = {
  ...mockEnv,
  CSRF_SECRET: 'test_csrf_secret_key_12345',
};

// Helper to create mock Request with default allowed Origin
function createRequest(
  method: string,
  body?: object,
  headers?: Record<string, string>
): Request {
  return new Request('https://worker.test/', {
    method,
    headers: {
      'Content-Type': 'application/json',
      'Origin': 'https://integritystudio.ai',
      ...headers,
    },
    body: body ? JSON.stringify(body) : undefined,
  });
}

// Helper to generate a valid CSRF token for testing
async function generateTestCsrfToken(secret: string, timestamp?: number): Promise<string> {
  const ts = (timestamp ?? Date.now()).toString();
  const encoder = new TextEncoder();

  const key = await crypto.subtle.importKey(
    'raw',
    encoder.encode(secret),
    { name: 'HMAC', hash: 'SHA-256' },
    false,
    ['sign']
  );

  const signatureBytes = await crypto.subtle.sign(
    'HMAC',
    key,
    encoder.encode(ts)
  );

  const signature = btoa(String.fromCharCode(...new Uint8Array(signatureBytes)))
    .replace(/\+/g, '-')
    .replace(/\//g, '_')
    .replace(/=+$/, '');

  return `${ts}.${signature}`;
}

describe('Contact Form Worker', () => {
  let mockResendInstance: { emails: { send: ReturnType<typeof vi.fn> } };

  beforeEach(() => {
    vi.clearAllMocks();
    _resetRateLimitState();
    mockResendInstance = {
      emails: {
        send: vi.fn(),
      },
    };
    (Resend as unknown as ReturnType<typeof vi.fn>).mockImplementation(
      function() {
        return mockResendInstance;
      }
    );
  });

  describe('HTTP Methods', () => {
    it('handles OPTIONS preflight requests', async () => {
      const request = createRequest('OPTIONS');
      const response = await worker.fetch(request, mockEnv);

      expect(response.status).toBe(200);
      expect(response.headers.get('Access-Control-Allow-Origin')).toBe('https://integritystudio.ai');
      expect(response.headers.get('Access-Control-Allow-Methods')).toContain('POST');
    });

    it('handles GET requests for CSRF token (503 when not configured)', async () => {
      const request = createRequest('GET');
      const response = await worker.fetch(request, mockEnv);

      // GET is now used for CSRF token retrieval
      // Returns 503 when CSRF_SECRET is not configured
      expect(response.status).toBe(503);
      const data = await response.json() as ErrorResponse;
      expect(data.error).toContain('Service temporarily unavailable');
    });

    it('rejects PUT requests with 405', async () => {
      const request = createRequest('PUT');
      const response = await worker.fetch(request, mockEnv);

      expect(response.status).toBe(405);
    });

    it('rejects DELETE requests with 405', async () => {
      const request = createRequest('DELETE');
      const response = await worker.fetch(request, mockEnv);

      expect(response.status).toBe(405);
    });
  });

  describe('Form Validation', () => {
    it('returns 400 for missing name', async () => {
      const request = createRequest('POST', {
        email: 'test@example.com',
        message: 'This is a test message.',
      });

      const response = await worker.fetch(request, mockEnv);

      expect(response.status).toBe(400);
      const data = await response.json() as ErrorResponse;
      expect(data.error).toContain('Name');
    });

    it('returns 400 for empty name', async () => {
      const request = createRequest('POST', {
        name: '',
        email: 'test@example.com',
        message: 'This is a test message.',
      });

      const response = await worker.fetch(request, mockEnv);

      expect(response.status).toBe(400);
      const data = await response.json() as ErrorResponse;
      expect(data.error).toContain('Name');
    });

    it('returns 400 for whitespace-only name', async () => {
      const request = createRequest('POST', {
        name: '   ',
        email: 'test@example.com',
        message: 'This is a test message.',
      });

      const response = await worker.fetch(request, mockEnv);

      expect(response.status).toBe(400);
    });

    it('returns 400 for missing email', async () => {
      const request = createRequest('POST', {
        name: 'John Doe',
        message: 'This is a test message.',
      });

      const response = await worker.fetch(request, mockEnv);

      expect(response.status).toBe(400);
      const data = await response.json() as ErrorResponse;
      expect(data.error).toContain('Email');
    });

    it('returns 400 for invalid email format', async () => {
      const request = createRequest('POST', {
        name: 'John Doe',
        email: 'invalid-email',
        message: 'This is a test message.',
      });

      const response = await worker.fetch(request, mockEnv);

      expect(response.status).toBe(400);
      const data = await response.json() as ErrorResponse;
      expect(data.error).toContain('email');
    });

    it('accepts missing message (optional field)', async () => {
      mockResendInstance.emails.send.mockResolvedValue({
        data: { id: 'email_123' },
        error: null,
      });

      const request = createRequest('POST', {
        name: 'John Doe',
        email: 'test@example.com',
      });

      const response = await worker.fetch(request, mockEnv);

      expect(response.status).toBe(200);
    });

    it('accepts short message (no minimum length)', async () => {
      mockResendInstance.emails.send.mockResolvedValue({
        data: { id: 'email_123' },
        error: null,
      });

      const request = createRequest('POST', {
        name: 'John Doe',
        email: 'test@example.com',
        message: 'Short',
      });

      const response = await worker.fetch(request, mockEnv);

      expect(response.status).toBe(200);
    });

    it('accepts valid form data', async () => {
      mockResendInstance.emails.send.mockResolvedValue({
        data: { id: 'email_123' },
        error: null,
      });

      const request = createRequest('POST', {
        name: 'John Doe',
        email: 'john@example.com',
        message: 'This is a valid message for testing.',
      });

      const response = await worker.fetch(request, mockEnv);

      expect(response.status).toBe(200);
    });

    it('returns 400 for name exceeding max length', async () => {
      const request = createRequest('POST', {
        name: 'A'.repeat(MAX_NAME_LENGTH + 1),
        email: 'test@example.com',
        message: 'This is a valid message.',
      });

      const response = await worker.fetch(request, mockEnv);

      expect(response.status).toBe(400);
      const data = await response.json() as ErrorResponse;
      expect(data.error).toContain('100');
    });

    it('returns 400 for companySize exceeding max length', async () => {
      const request = createRequest('POST', {
        name: 'John Doe',
        email: 'test@example.com',
        message: 'This is a valid message.',
        companySize: 'A'.repeat(MAX_COMPANY_SIZE_LENGTH + 1),
      });

      const response = await worker.fetch(request, mockEnv);

      expect(response.status).toBe(400);
      const data = await response.json() as ErrorResponse;
      expect(data.error).toContain('100');
    });

    it('returns 400 for useCase exceeding max length', async () => {
      const request = createRequest('POST', {
        name: 'John Doe',
        email: 'test@example.com',
        message: 'This is a valid message.',
        useCase: 'A'.repeat(MAX_USE_CASE_LENGTH + 1),
      });

      const response = await worker.fetch(request, mockEnv);

      expect(response.status).toBe(400);
      const data = await response.json() as ErrorResponse;
      expect(data.error).toContain('200');
    });

    it('returns 400 for message exceeding max length', async () => {
      const request = createRequest('POST', {
        name: 'John Doe',
        email: 'test@example.com',
        message: 'A'.repeat(MAX_MESSAGE_LENGTH + 1),
      });

      const response = await worker.fetch(request, mockEnv);

      expect(response.status).toBe(400);
      const data = await response.json() as ErrorResponse;
      expect(data.error).toContain('5000');
    });

    it('accepts optional organization field', async () => {
      mockResendInstance.emails.send.mockResolvedValue({
        data: { id: 'email_123' },
        error: null,
      });

      const request = createRequest('POST', {
        name: 'John Doe',
        email: 'john@example.com',
        organization: 'ACME Corp',
        message: 'This is a valid message for testing.',
      });

      const response = await worker.fetch(request, mockEnv);

      expect(response.status).toBe(200);
    });
  });

  describe('Email Submission Triggers', () => {
    it('sends email via Resend on valid submission', async () => {
      mockResendInstance.emails.send.mockResolvedValue({
        data: { id: 'email_123' },
        error: null,
      });

      const request = createRequest('POST', {
        name: 'John Doe',
        email: 'john@example.com',
        message: 'I would like to learn more about your platform.',
      });

      await worker.fetch(request, mockEnv);

      expect(mockResendInstance.emails.send).toHaveBeenCalledTimes(1);
      expect(mockResendInstance.emails.send).toHaveBeenCalledWith(
        expect.objectContaining({
          from: expect.stringContaining(mockEnv.SENDER_EMAIL),
          to: [mockEnv.RECIPIENT_EMAIL],
          replyTo: 'john@example.com',
          subject: expect.stringContaining('John Doe'),
        })
      );
    });

    it('includes organization in subject when provided', async () => {
      mockResendInstance.emails.send.mockResolvedValue({
        data: { id: 'email_123' },
        error: null,
      });

      const request = createRequest('POST', {
        name: 'Jane Doe',
        email: 'jane@company.com',
        organization: 'ACME Corp',
        message: 'Enterprise inquiry about AI observability.',
      });

      await worker.fetch(request, mockEnv);

      expect(mockResendInstance.emails.send).toHaveBeenCalledWith(
        expect.objectContaining({
          subject: expect.stringContaining('ACME Corp'),
        })
      );
    });

    it('includes message content in email body', async () => {
      mockResendInstance.emails.send.mockResolvedValue({
        data: { id: 'email_123' },
        error: null,
      });

      const testMessage = 'This is my specific test message content.';
      const request = createRequest('POST', {
        name: 'John Doe',
        email: 'john@example.com',
        message: testMessage,
      });

      await worker.fetch(request, mockEnv);

      expect(mockResendInstance.emails.send).toHaveBeenCalledWith(
        expect.objectContaining({
          html: expect.stringContaining(testMessage),
          text: expect.stringContaining(testMessage),
        })
      );
    });

    it('returns success response with submission ID', async () => {
      mockResendInstance.emails.send.mockResolvedValue({
        data: { id: 'resend_email_abc123' },
        error: null,
      });

      const request = createRequest('POST', {
        name: 'John Doe',
        email: 'john@example.com',
        message: 'This is a valid message for testing.',
      });

      const response = await worker.fetch(request, mockEnv);
      const data = await response.json() as SuccessResponse;

      expect(response.status).toBe(200);
      expect(data.success).toBe(true);
      expect(data.submissionId).toBe('resend_email_abc123');
      expect(data.message).toContain('Thank you');
    });

    it('returns success with fallback ID when Resend returns no ID', async () => {
      mockResendInstance.emails.send.mockResolvedValue({
        data: {},
        error: null,
      });

      const request = createRequest('POST', {
        name: 'John Doe',
        email: 'john@example.com',
        message: 'This is a valid message for testing.',
      });

      const response = await worker.fetch(request, mockEnv);
      const data = await response.json() as SuccessResponse;

      expect(response.status).toBe(200);
      expect(data.success).toBe(true);
      expect(data.submissionId).toMatch(/^sub_\d+$/);
    });
  });

  describe('Error Handling', () => {
    it('returns 500 when Resend API fails', async () => {
      mockResendInstance.emails.send.mockResolvedValue({
        data: null,
        error: { message: 'Rate limit exceeded' },
      });

      const request = createRequest('POST', {
        name: 'John Doe',
        email: 'john@example.com',
        message: 'This is a valid message for testing.',
      });

      const response = await worker.fetch(request, mockEnv);
      const data = await response.json() as ErrorResponse;

      expect(response.status).toBe(500);
      expect(data.error).toContain('Failed to send email');
    });

    it('returns 504 on network timeout', async () => {
      mockResendInstance.emails.send.mockRejectedValue(
        new Error('Network error')
      );

      const request = createRequest('POST', {
        name: 'John Doe',
        email: 'john@example.com',
        message: 'This is a valid message for testing.',
      });

      const response = await worker.fetch(request, mockEnv);
      const data = await response.json() as ErrorResponse;

      expect(response.status).toBe(504);
      expect(data.error).toContain('timeout');
    });

    it('returns 500 for invalid JSON body', async () => {
      const request = new Request('https://worker.test/', {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'Origin': 'https://integritystudio.ai',
        },
        body: 'invalid json {',
      });

      const response = await worker.fetch(request, mockEnv);

      expect(response.status).toBe(500);
    });
  });

  describe('CORS Headers', () => {
    it('includes CORS headers on success response from allowed origin', async () => {
      mockResendInstance.emails.send.mockResolvedValue({
        data: { id: 'email_123' },
        error: null,
      });

      const request = new Request('https://worker.test/', {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'Origin': 'https://integritystudio.ai',
        },
        body: JSON.stringify({
          name: 'John Doe',
          email: 'john@example.com',
          message: 'This is a valid message for testing.',
        }),
      });

      const response = await worker.fetch(request, mockEnv);

      expect(response.headers.get('Access-Control-Allow-Origin')).toBe('https://integritystudio.ai');
    });

    it('includes CORS headers on error response from allowed origin', async () => {
      const request = new Request('https://worker.test/', {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'Origin': 'https://integritystudio.ai',
        },
        body: JSON.stringify({
          name: '',
          email: 'invalid',
          message: '',
        }),
      });

      const response = await worker.fetch(request, mockEnv);

      expect(response.headers.get('Access-Control-Allow-Origin')).toBe('https://integritystudio.ai');
    });

    it('returns 403 for POST from unauthorized origin', async () => {
      const request = new Request('https://worker.test/', {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'Origin': 'https://evil.example.com',
        },
        body: JSON.stringify({
          name: 'John Doe',
          email: 'john@example.com',
          message: 'This is a valid message for testing.',
        }),
      });

      const response = await worker.fetch(request, mockEnv);

      expect(response.status).toBe(403);
      const data = await response.json() as ErrorResponse;
      expect(data.error).toContain('unauthorized origin');
    });

    it('returns 403 for GET from unauthorized origin', async () => {
      const request = new Request('https://worker.test/', {
        method: 'GET',
        headers: {
          'Origin': 'https://evil.example.com',
        },
      });

      const response = await worker.fetch(request, mockEnvWithCsrf);

      expect(response.status).toBe(403);
    });

    it('allows OPTIONS preflight from any origin', async () => {
      const request = new Request('https://worker.test/', {
        method: 'OPTIONS',
        headers: {
          'Origin': 'https://evil.example.com',
        },
      });

      const response = await worker.fetch(request, mockEnv);

      expect(response.status).toBe(200);
      expect(response.headers.get('Access-Control-Allow-Origin')).toBeDefined();
    });

    it('allows an origin configured via ALLOWED_ORIGINS_JSON (e.g. localhost dev)', async () => {
      mockResendInstance.emails.send.mockResolvedValue({
        data: { id: 'email_123' },
        error: null,
      });

      const env = { ...mockEnv, ALLOWED_ORIGINS_JSON: '["http://localhost:8080"]' };
      const request = new Request('https://worker.test/', {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'Origin': 'http://localhost:8080',
        },
        body: JSON.stringify({
          name: 'John Doe',
          email: 'john@example.com',
          message: 'This is a valid message for testing.',
        }),
      });

      const response = await worker.fetch(request, env);

      expect(response.status).toBe(200);
      expect(response.headers.get('Access-Control-Allow-Origin')).toBe('http://localhost:8080');
      expect(response.headers.get('Access-Control-Allow-Credentials')).toBe('true');
    });

    it('rejects an origin absent from ALLOWED_ORIGINS_JSON', async () => {
      const env = { ...mockEnv, ALLOWED_ORIGINS_JSON: '["http://localhost:8080"]' };
      const request = new Request('https://worker.test/', {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'Origin': 'http://localhost:9999',
        },
        body: JSON.stringify({
          name: 'John Doe',
          email: 'john@example.com',
          message: 'This is a valid message for testing.',
        }),
      });

      const response = await worker.fetch(request, env);

      expect(response.status).toBe(403);
      const data = await response.json() as ErrorResponse;
      expect(data.error).toContain('unauthorized origin');
    });

    it('rejects the prod origin when ALLOWED_ORIGINS_JSON overrides to dev-only', async () => {
      const env = { ...mockEnv, ALLOWED_ORIGINS_JSON: '["http://localhost:8080"]' };
      const request = new Request('https://worker.test/', {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'Origin': 'https://integritystudio.ai',
        },
        body: JSON.stringify({
          name: 'John Doe',
          email: 'john@example.com',
          message: 'This is a valid message for testing.',
        }),
      });

      const response = await worker.fetch(request, env);

      expect(response.status).toBe(403);
    });
  });

  describe('Email Routing Verification', () => {
    it('sends to hello@integritystudio.ai for general contact', async () => {
      const envWithHello = {
        ...mockEnv,
        RECIPIENT_EMAIL: 'hello@integritystudio.ai',
      };

      mockResendInstance.emails.send.mockResolvedValue({
        data: { id: 'email_123' },
        error: null,
      });

      const request = createRequest('POST', {
        name: 'John Doe',
        email: 'john@example.com',
        message: 'General inquiry about your platform.',
      });

      await worker.fetch(request, envWithHello);

      expect(mockResendInstance.emails.send).toHaveBeenCalledWith(
        expect.objectContaining({
          to: ['hello@integritystudio.ai'],
        })
      );
    });

    it('sends to sales@integritystudio.ai when configured', async () => {
      const envWithSales = {
        ...mockEnv,
        RECIPIENT_EMAIL: 'sales@integritystudio.ai',
      };

      mockResendInstance.emails.send.mockResolvedValue({
        data: { id: 'email_123' },
        error: null,
      });

      const request = createRequest('POST', {
        name: 'Jane Smith',
        email: 'jane@enterprise.com',
        organization: 'Enterprise Corp',
        message: 'Interested in enterprise pricing.',
      });

      await worker.fetch(request, envWithSales);

      expect(mockResendInstance.emails.send).toHaveBeenCalledWith(
        expect.objectContaining({
          to: ['sales@integritystudio.ai'],
        })
      );
    });

    it('sends to security@integritystudio.ai when configured', async () => {
      const envWithSecurity = {
        ...mockEnv,
        RECIPIENT_EMAIL: 'security@integritystudio.ai',
      };

      mockResendInstance.emails.send.mockResolvedValue({
        data: { id: 'email_123' },
        error: null,
      });

      const request = createRequest('POST', {
        name: 'Security Researcher',
        email: 'researcher@security.org',
        message: 'Security vulnerability disclosure.',
      });

      await worker.fetch(request, envWithSecurity);

      expect(mockResendInstance.emails.send).toHaveBeenCalledWith(
        expect.objectContaining({
          to: ['security@integritystudio.ai'],
        })
      );
    });

    it('sends to help@integritystudio.ai when configured', async () => {
      const envWithHelp = {
        ...mockEnv,
        RECIPIENT_EMAIL: 'help@integritystudio.ai',
      };

      mockResendInstance.emails.send.mockResolvedValue({
        data: { id: 'email_123' },
        error: null,
      });

      const request = createRequest('POST', {
        name: 'Customer',
        email: 'customer@company.com',
        message: 'Need help with my account setup.',
      });

      await worker.fetch(request, envWithHelp);

      expect(mockResendInstance.emails.send).toHaveBeenCalledWith(
        expect.objectContaining({
          to: ['help@integritystudio.ai'],
        })
      );
    });

    it('uses correct sender email (contact@integritystudio.ai)', async () => {
      const envWithSender = {
        ...mockEnv,
        SENDER_EMAIL: 'contact@integritystudio.ai',
      };

      mockResendInstance.emails.send.mockResolvedValue({
        data: { id: 'email_123' },
        error: null,
      });

      const request = createRequest('POST', {
        name: 'John Doe',
        email: 'john@example.com',
        message: 'Testing sender email address.',
      });

      await worker.fetch(request, envWithSender);

      expect(mockResendInstance.emails.send).toHaveBeenCalledWith(
        expect.objectContaining({
          from: expect.stringContaining('contact@integritystudio.ai'),
        })
      );
    });

    it('sets replyTo to submitter email', async () => {
      mockResendInstance.emails.send.mockResolvedValue({
        data: { id: 'email_123' },
        error: null,
      });

      const request = createRequest('POST', {
        name: 'Reply Test',
        email: 'replyto@testdomain.com',
        message: 'Testing reply-to functionality.',
      });

      await worker.fetch(request, mockEnv);

      expect(mockResendInstance.emails.send).toHaveBeenCalledWith(
        expect.objectContaining({
          replyTo: 'replyto@testdomain.com',
        })
      );
    });
  });

  describe('XSS Prevention', () => {
    it('escapes HTML in name field', async () => {
      mockResendInstance.emails.send.mockResolvedValue({
        data: { id: 'email_123' },
        error: null,
      });

      const request = createRequest('POST', {
        name: '<script>alert("xss")</script>',
        email: 'test@example.com',
        message: 'This is a valid message for testing.',
      });

      await worker.fetch(request, mockEnv);

      expect(mockResendInstance.emails.send).toHaveBeenCalledWith(
        expect.objectContaining({
          html: expect.not.stringContaining('<script>'),
        })
      );
    });

    it('escapes HTML in message field', async () => {
      mockResendInstance.emails.send.mockResolvedValue({
        data: { id: 'email_123' },
        error: null,
      });

      const request = createRequest('POST', {
        name: 'John Doe',
        email: 'test@example.com',
        message: '<img src=x onerror=alert("xss")>Test message',
      });

      await worker.fetch(request, mockEnv);

      expect(mockResendInstance.emails.send).toHaveBeenCalledWith(
        expect.objectContaining({
          html: expect.not.stringContaining('<img'),
        })
      );
    });

    it('escapes HTML in companySize field', async () => {
      mockResendInstance.emails.send.mockResolvedValue({
        data: { id: 'email_123' },
        error: null,
      });

      const request = createRequest('POST', {
        name: 'John Doe',
        email: 'test@example.com',
        message: 'This is a valid message for testing.',
        companySize: '<script>alert("xss")</script>',
      });

      await worker.fetch(request, mockEnv);

      expect(mockResendInstance.emails.send).toHaveBeenCalledWith(
        expect.objectContaining({
          html: expect.not.stringContaining('<script>'),
        })
      );
    });

    it('escapes HTML in useCase field', async () => {
      mockResendInstance.emails.send.mockResolvedValue({
        data: { id: 'email_123' },
        error: null,
      });

      const request = createRequest('POST', {
        name: 'John Doe',
        email: 'test@example.com',
        message: 'This is a valid message for testing.',
        useCase: '<img src=x onerror=alert("xss")>',
      });

      await worker.fetch(request, mockEnv);

      expect(mockResendInstance.emails.send).toHaveBeenCalledWith(
        expect.objectContaining({
          html: expect.not.stringContaining('<img'),
        })
      );
    });

    it('rejects email with parameter injection characters at validation', async () => {
      const request = createRequest('POST', {
        name: 'John Doe',
        email: 'test@example.com?subject=injected&body=malicious',
        message: 'This is a valid message for testing.',
      });

      const response = await worker.fetch(request, mockEnv);
      expect(response.status).toBe(400);
      const data = await response.json() as ErrorResponse;
      expect(data.error).toContain('Invalid email');
      expect(mockResendInstance.emails.send).not.toHaveBeenCalled();
    });
  });

  describe('Rate Limiting', () => {
    // Mock KV store
    const createMockKV = () => {
      const store: Record<string, string> = {};
      return {
        get: vi.fn(async (key: string) => {
          const value = store[key];
          return value ? JSON.parse(value) : null;
        }),
        put: vi.fn(async (key: string, value: string) => {
          store[key] = value;
        }),
        _store: store,
      };
    };

    it('allows requests within rate limit', async () => {
      const mockKV = createMockKV();
      const envWithKV = {
        ...mockEnv,
        RATE_LIMIT_KV: mockKV as unknown as KVNamespace,
        RATE_LIMIT_MAX: '5',
        RATE_LIMIT_WINDOW_SECONDS: '60',
      };

      mockResendInstance.emails.send.mockResolvedValue({
        data: { id: 'email_123' },
        error: null,
      });

      const request = new Request('https://worker.test/', {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'Origin': 'https://integritystudio.ai',
          'CF-Connecting-IP': '192.168.1.1',
        },
        body: JSON.stringify({
          name: 'John Doe',
          email: 'john@example.com',
          message: 'This is a valid message.',
        }),
      });

      const response = await worker.fetch(request, envWithKV);

      expect(response.status).toBe(200);
      expect(mockKV.put).toHaveBeenCalled();
    });

    it('blocks requests exceeding rate limit', async () => {
      const mockKV = createMockKV();
      // Pre-populate with 5 requests (at limit)
      mockKV._store['rate_limit:192.168.1.100'] = JSON.stringify({
        count: 5,
        resetAt: Date.now() + 60000,
      });

      const envWithKV = {
        ...mockEnv,
        RATE_LIMIT_KV: mockKV as unknown as KVNamespace,
        RATE_LIMIT_MAX: '5',
        RATE_LIMIT_WINDOW_SECONDS: '60',
      };

      const request = new Request('https://worker.test/', {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'Origin': 'https://integritystudio.ai',
          'CF-Connecting-IP': '192.168.1.100',
        },
        body: JSON.stringify({
          name: 'John Doe',
          email: 'john@example.com',
          message: 'This is a valid message.',
        }),
      });

      const response = await worker.fetch(request, envWithKV);

      expect(response.status).toBe(429);
      const data = await response.json() as ErrorResponse;
      expect(data.error).toContain('Too many requests');
      expect(response.headers.get('Retry-After')).toBeTruthy();
      expect(response.headers.get('X-RateLimit-Remaining')).toBe('0');
    });

    it('resets rate limit after window expires', async () => {
      const mockKV = createMockKV();
      // Pre-populate with expired window
      mockKV._store['rate_limit:192.168.1.200'] = JSON.stringify({
        count: 10,
        resetAt: Date.now() - 1000, // Expired
      });

      const envWithKV = {
        ...mockEnv,
        RATE_LIMIT_KV: mockKV as unknown as KVNamespace,
        RATE_LIMIT_MAX: '5',
        RATE_LIMIT_WINDOW_SECONDS: '60',
      };

      mockResendInstance.emails.send.mockResolvedValue({
        data: { id: 'email_123' },
        error: null,
      });

      const request = new Request('https://worker.test/', {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'Origin': 'https://integritystudio.ai',
          'CF-Connecting-IP': '192.168.1.200',
        },
        body: JSON.stringify({
          name: 'John Doe',
          email: 'john@example.com',
          message: 'This is a valid message.',
        }),
      });

      const response = await worker.fetch(request, envWithKV);

      expect(response.status).toBe(200);
    });

    it('uses in-memory fallback when KV is not configured', async () => {
      // mockEnv doesn't have RATE_LIMIT_KV
      mockResendInstance.emails.send.mockResolvedValue({
        data: { id: 'email_123' },
        error: null,
      });

      const request = createRequest('POST', {
        name: 'John Doe',
        email: 'john@example.com',
        message: 'This is a valid message.',
      });

      const response = await worker.fetch(request, mockEnv);

      // Should still succeed using in-memory fallback
      expect(response.status).toBe(200);
    });

    it('uses in-memory fallback on KV error', async () => {
      const failingKV = {
        get: vi.fn().mockRejectedValue(new Error('KV unavailable')),
        put: vi.fn().mockRejectedValue(new Error('KV unavailable')),
      };

      const envWithFailingKV = {
        ...mockEnv,
        RATE_LIMIT_KV: failingKV as unknown as KVNamespace,
        RATE_LIMIT_MAX: '5',
      };

      mockResendInstance.emails.send.mockResolvedValue({
        data: { id: 'email_123' },
        error: null,
      });

      const request = new Request('https://worker.test/', {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'Origin': 'https://integritystudio.ai',
          'CF-Connecting-IP': '10.0.0.1',
        },
        body: JSON.stringify({
          name: 'John Doe',
          email: 'john@example.com',
          message: 'This is a valid message.',
        }),
      });

      // First request should succeed via in-memory fallback
      const response = await worker.fetch(request, envWithFailingKV);
      expect(response.status).toBe(200);
    });
  });

  describe('Idempotency', () => {
    it('returns cached response for duplicate idempotency key', async () => {
      const store: Record<string, string> = {};
      const mockKV = {
        get: vi.fn(async (key: string, format?: string) => {
          const value = store[key] ?? null;
          if (value && format === 'json') return JSON.parse(value);
          return value;
        }),
        put: vi.fn(async (key: string, value: string) => {
          store[key] = value;
        }),
      };

      mockResendInstance.emails.send.mockResolvedValue({
        data: { id: 'email_first' },
        error: null,
      });

      const envWithKV = {
        ...mockEnv,
        RATE_LIMIT_KV: mockKV as unknown as KVNamespace,
      };

      const request1 = new Request('https://worker.test/', {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'Origin': 'https://integritystudio.ai',
          'X-Idempotency-Key': 'test-key-123',
        },
        body: JSON.stringify({
          name: 'John Doe',
          email: 'john@example.com',
          message: 'This is a valid message.',
        }),
      });

      const response1 = await worker.fetch(request1, envWithKV);
      expect(response1.status).toBe(200);

      // Second request with same key - should return cached response
      const request2 = new Request('https://worker.test/', {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'Origin': 'https://integritystudio.ai',
          'X-Idempotency-Key': 'test-key-123',
        },
        body: JSON.stringify({
          name: 'John Doe',
          email: 'john@example.com',
          message: 'This is a valid message.',
        }),
      });

      const response2 = await worker.fetch(request2, envWithKV);
      expect(response2.status).toBe(200);

      // Email should only be sent once
      expect(mockResendInstance.emails.send).toHaveBeenCalledTimes(1);
    });

    it('proceeds without dedup when no idempotency key', async () => {
      mockResendInstance.emails.send.mockResolvedValue({
        data: { id: 'email_123' },
        error: null,
      });

      const request = createRequest('POST', {
        name: 'John Doe',
        email: 'john@example.com',
        message: 'This is a valid message.',
      });

      const response = await worker.fetch(request, mockEnv);
      expect(response.status).toBe(200);
    });
  });

  describe('Origin Validation Edge Cases', () => {
    it('returns 403 for POST with missing Origin header', async () => {
      const request = new Request('https://worker.test/', {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
        },
        body: JSON.stringify({
          name: 'John Doe',
          email: 'john@example.com',
          message: 'Test message.',
        }),
      });

      const response = await worker.fetch(request, mockEnv);

      expect(response.status).toBe(403);
      const data = await response.json() as ErrorResponse;
      expect(data.error).toContain('unauthorized origin');
    });

    it('returns 403 for case-variant Origin header', async () => {
      const request = new Request('https://worker.test/', {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'Origin': 'https://IntegrityStudio.AI',
        },
        body: JSON.stringify({
          name: 'John Doe',
          email: 'john@example.com',
          message: 'Test message.',
        }),
      });

      const response = await worker.fetch(request, mockEnv);

      expect(response.status).toBe(403);
    });

    it('returns 403 for Origin with trailing slash', async () => {
      const request = new Request('https://worker.test/', {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'Origin': 'https://integritystudio.ai/',
        },
        body: JSON.stringify({
          name: 'John Doe',
          email: 'john@example.com',
          message: 'Test message.',
        }),
      });

      const response = await worker.fetch(request, mockEnv);

      expect(response.status).toBe(403);
    });
  });

  describe('Unicode and Special Characters', () => {
    it('accepts Unicode characters in name field', async () => {
      mockResendInstance.emails.send.mockResolvedValue({
        data: { id: 'email_unicode' },
        error: null,
      });

      const request = createRequest('POST', {
        name: 'Müller Straße',
        email: 'test@example.com',
        message: 'Test with Unicode name.',
      });

      const response = await worker.fetch(request, mockEnv);

      expect(response.status).toBe(200);
    });

    it('accepts emoji in message field', async () => {
      mockResendInstance.emails.send.mockResolvedValue({
        data: { id: 'email_emoji' },
        error: null,
      });

      const request = createRequest('POST', {
        name: 'John Doe',
        email: 'test@example.com',
        message: 'Great product! 🚀🎉 Looking forward to using it.',
      });

      const response = await worker.fetch(request, mockEnv);

      expect(response.status).toBe(200);
    });

    it('accepts CJK characters in organization field', async () => {
      mockResendInstance.emails.send.mockResolvedValue({
        data: { id: 'email_cjk' },
        error: null,
      });

      const request = createRequest('POST', {
        name: 'John Doe',
        email: 'test@example.com',
        organization: '株式会社テスト',
        message: 'Test with CJK organization.',
      });

      const response = await worker.fetch(request, mockEnv);

      expect(response.status).toBe(200);
    });
  });

  describe('Distributed Tracing', () => {
    it('returns X-Request-ID header in response', async () => {
      mockResendInstance.emails.send.mockResolvedValue({
        data: { id: 'email_123' },
        error: null,
      });

      const request = createRequest('POST', {
        name: 'John Doe',
        email: 'john@example.com',
        message: 'Test tracing.',
      });

      const response = await worker.fetch(request, mockEnv);

      expect(response.headers.get('X-Request-ID')).toBeTruthy();
    });

    it('echoes client-provided X-Request-ID', async () => {
      mockResendInstance.emails.send.mockResolvedValue({
        data: { id: 'email_123' },
        error: null,
      });

      const request = new Request('https://worker.test/', {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'Origin': 'https://integritystudio.ai',
          'X-Request-ID': 'client-trace-abc-123',
        },
        body: JSON.stringify({
          name: 'John Doe',
          email: 'john@example.com',
          message: 'Test tracing.',
        }),
      });

      const response = await worker.fetch(request, mockEnv);

      expect(response.headers.get('X-Request-ID')).toBe('client-trace-abc-123');
    });

    it('generates X-Request-ID when not provided by client', async () => {
      const request = createRequest('OPTIONS');

      const response = await worker.fetch(request, mockEnv);

      const requestId = response.headers.get('X-Request-ID');
      expect(requestId).toBeTruthy();
      // Should be a valid UUID format
      expect(requestId).toMatch(
        /^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/
      );
    });

    it('includes X-Request-ID in error responses', async () => {
      const request = new Request('https://worker.test/', {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'Origin': 'https://evil.example.com',
          'X-Request-ID': 'trace-for-error',
        },
        body: JSON.stringify({
          name: 'John Doe',
          email: 'john@example.com',
          message: 'Test.',
        }),
      });

      const response = await worker.fetch(request, mockEnv);

      expect(response.status).toBe(403);
      expect(response.headers.get('X-Request-ID')).toBe('trace-for-error');
    });
  });

  describe('Circuit Breaker (#22)', () => {
    it('trips after KV_CIRCUIT_BREAKER_THRESHOLD consecutive failures', async () => {
      const failingKV = {
        get: vi.fn().mockRejectedValue(new Error('KV unavailable')),
        put: vi.fn().mockRejectedValue(new Error('KV unavailable')),
      };

      const envWithFailingKV = {
        ...mockEnv,
        RATE_LIMIT_KV: failingKV as unknown as KVNamespace,
        RATE_LIMIT_MAX: '100', // high limit so in-memory won't block
      };

      mockResendInstance.emails.send.mockResolvedValue({
        data: { id: 'email_123' },
        error: null,
      });

      // Send requests to trip circuit breaker
      for (let i = 0; i < KV_CIRCUIT_BREAKER_THRESHOLD; i++) {
        const request = new Request('https://worker.test/', {
          method: 'POST',
          headers: {
            'Content-Type': 'application/json',
            'Origin': 'https://integritystudio.ai',
            'CF-Connecting-IP': `circuit-test-${i}`,
          },
          body: JSON.stringify({
            name: 'John Doe',
            email: 'john@example.com',
            message: 'Circuit breaker test.',
          }),
        });

        await worker.fetch(request, envWithFailingKV);
      }

      // After 10 failures, circuit should be open — KV.get should not be called again
      failingKV.get.mockClear();

      const request = new Request('https://worker.test/', {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'Origin': 'https://integritystudio.ai',
          'CF-Connecting-IP': 'circuit-test-after',
        },
        body: JSON.stringify({
          name: 'John Doe',
          email: 'john@example.com',
          message: 'After circuit open.',
        }),
      });

      const response = await worker.fetch(request, envWithFailingKV);
      // Should still succeed via in-memory fallback
      expect(response.status).toBe(200);
      // KV should NOT be called when circuit is open
      expect(failingKV.get).not.toHaveBeenCalled();
    });

    it('resets circuit breaker after cooldown expires', async () => {
      const failingKV = {
        get: vi.fn().mockRejectedValue(new Error('KV unavailable')),
        put: vi.fn().mockRejectedValue(new Error('KV unavailable')),
      };

      const envWithFailingKV = {
        ...mockEnv,
        RATE_LIMIT_KV: failingKV as unknown as KVNamespace,
        RATE_LIMIT_MAX: '100',
      };

      mockResendInstance.emails.send.mockResolvedValue({
        data: { id: 'email_123' },
        error: null,
      });

      // Trip the circuit breaker
      for (let i = 0; i < KV_CIRCUIT_BREAKER_THRESHOLD; i++) {
        const request = new Request('https://worker.test/', {
          method: 'POST',
          headers: {
            'Content-Type': 'application/json',
            'Origin': 'https://integritystudio.ai',
            'CF-Connecting-IP': `cooldown-test-${i}`,
          },
          body: JSON.stringify({
            name: 'John Doe',
            email: 'john@example.com',
            message: 'Trip circuit.',
          }),
        });

        await worker.fetch(request, envWithFailingKV);
      }

      // Advance time past cooldown + max jitter
      vi.useFakeTimers();
      vi.setSystemTime(Date.now() + KV_CIRCUIT_RESET_COOLDOWN_MS + KV_CIRCUIT_RESET_JITTER_MS + 1000);

      failingKV.get.mockClear();

      const request = new Request('https://worker.test/', {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'Origin': 'https://integritystudio.ai',
          'CF-Connecting-IP': 'cooldown-test-after',
        },
        body: JSON.stringify({
          name: 'John Doe',
          email: 'john@example.com',
          message: 'After cooldown.',
        }),
      });

      await worker.fetch(request, envWithFailingKV);
      // KV should be retried after cooldown
      expect(failingKV.get).toHaveBeenCalled();

      vi.useRealTimers();
    });
  });

  describe('Request Size Limit (#25)', () => {
    it('returns 413 for request exceeding 10KB Content-Length', async () => {
      const request = new Request('https://worker.test/', {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'Origin': 'https://integritystudio.ai',
          'Content-Length': '20000',
        },
        body: JSON.stringify({
          name: 'John Doe',
          email: 'john@example.com',
          message: 'x'.repeat(15000),
        }),
      });

      const response = await worker.fetch(request, mockEnv);

      expect(response.status).toBe(413);
      const data = await response.json() as ErrorResponse;
      expect(data.error).toContain('Request body too large');
    });

    it('accepts request within 10KB Content-Length', async () => {
      mockResendInstance.emails.send.mockResolvedValue({
        data: { id: 'email_123' },
        error: null,
      });

      const request = new Request('https://worker.test/', {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'Origin': 'https://integritystudio.ai',
          'Content-Length': '200',
        },
        body: JSON.stringify({
          name: 'John Doe',
          email: 'john@example.com',
          message: 'Short message.',
        }),
      });

      const response = await worker.fetch(request, mockEnv);

      expect(response.status).toBe(200);
    });
  });

  describe('CSRF Protection', () => {
    it('returns CSRF token on GET request', async () => {
      const request = createRequest('GET');
      const response = await worker.fetch(request, mockEnvWithCsrf);

      expect(response.status).toBe(200);
      const data = await response.json() as { csrfToken: string };
      expect(data.csrfToken).toBeDefined();
      expect(data.csrfToken).toMatch(/^\d+\..+$/);
    });

    it('returns 503 when CSRF secret not configured for GET', async () => {
      const request = createRequest('GET');
      const response = await worker.fetch(request, mockEnv);

      expect(response.status).toBe(503);
      const data = await response.json() as ErrorResponse;
      expect(data.error).toContain('Service temporarily unavailable');
    });

    it('accepts valid CSRF token', async () => {
      mockResendInstance.emails.send.mockResolvedValue({
        data: { id: 'email_123' },
        error: null,
      });

      const csrfToken = await generateTestCsrfToken(mockEnvWithCsrf.CSRF_SECRET);
      const request = createRequest(
        'POST',
        {
          name: 'John Doe',
          email: 'john@example.com',
          message: 'This is a valid message for testing.',
        },
        { 'X-CSRF-Token': csrfToken }
      );

      const response = await worker.fetch(request, mockEnvWithCsrf);

      expect(response.status).toBe(200);
    });

    it('rejects missing CSRF token when CSRF is enabled', async () => {
      const request = createRequest('POST', {
        name: 'John Doe',
        email: 'john@example.com',
        message: 'This is a valid message for testing.',
      });

      const response = await worker.fetch(request, mockEnvWithCsrf);

      expect(response.status).toBe(403);
      const data = await response.json() as ErrorResponse;
      expect(data.error).toContain('CSRF');
    });

    it('rejects invalid CSRF token format', async () => {
      const request = createRequest(
        'POST',
        {
          name: 'John Doe',
          email: 'john@example.com',
          message: 'This is a valid message for testing.',
        },
        { 'X-CSRF-Token': 'invalid-token-format' }
      );

      const response = await worker.fetch(request, mockEnvWithCsrf);

      expect(response.status).toBe(403);
      const data = await response.json() as ErrorResponse;
      expect(data.error).toContain('CSRF');
    });

    it('rejects expired CSRF token', async () => {
      // Create a token from 2x max age ago (beyond max age)
      const expiredTimestamp = Date.now() - 2 * CSRF_TOKEN_MAX_AGE_MS;
      const csrfToken = await generateTestCsrfToken(mockEnvWithCsrf.CSRF_SECRET, expiredTimestamp);
      const request = createRequest(
        'POST',
        {
          name: 'John Doe',
          email: 'john@example.com',
          message: 'This is a valid message for testing.',
        },
        { 'X-CSRF-Token': csrfToken }
      );

      const response = await worker.fetch(request, mockEnvWithCsrf);

      expect(response.status).toBe(403);
      const data = await response.json() as ErrorResponse;
      expect(data.error).toContain('expired');
    });

    it('rejects token with invalid signature', async () => {
      const timestamp = Date.now();
      const invalidToken = `${timestamp}.invalidSignature123`;
      const request = createRequest(
        'POST',
        {
          name: 'John Doe',
          email: 'john@example.com',
          message: 'This is a valid message for testing.',
        },
        { 'X-CSRF-Token': invalidToken }
      );

      const response = await worker.fetch(request, mockEnvWithCsrf);

      expect(response.status).toBe(403);
      const data = await response.json() as ErrorResponse;
      expect(data.error).toContain('Invalid CSRF');
    });

    it('allows requests without CSRF when secret not configured', async () => {
      // mockEnv doesn't have CSRF_SECRET, so CSRF validation is skipped
      mockResendInstance.emails.send.mockResolvedValue({
        data: { id: 'email_123' },
        error: null,
      });

      const request = createRequest('POST', {
        name: 'John Doe',
        email: 'john@example.com',
        message: 'This is a valid message for testing.',
      });

      const response = await worker.fetch(request, mockEnv);

      expect(response.status).toBe(200);
    });

    it('includes X-CSRF-Token in CORS allowed headers', async () => {
      const request = createRequest('OPTIONS');
      const response = await worker.fetch(request, mockEnvWithCsrf);

      expect(response.headers.get('Access-Control-Allow-Headers')).toContain('X-CSRF-Token');
    });
  });
});
