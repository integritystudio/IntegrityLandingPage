/**
 * Integrity Studio Contact Form Worker
 *
 * Receives contact form submissions and sends emails via Resend API.
 * Includes rate limiting, validation, and CORS handling.
 */

import { Resend } from 'resend';

interface Env {
  RESEND_API_KEY: string;
  RECIPIENT_EMAIL: string;
  SENDER_EMAIL: string;
  RATE_LIMIT_KV?: KVNamespace;
  RATE_LIMIT_MAX?: string;
  RATE_LIMIT_WINDOW_SECONDS?: string;
  CSRF_SECRET?: string;
  ENVIRONMENT?: string; // 'production' | 'staging' | 'development'
}

// CSRF configuration
const CSRF_TOKEN_MAX_AGE_MS = 60 * 60 * 1000; // 1 hour

// API timeout configuration - 8s to leave headroom for client's 10s timeout
const RESEND_API_TIMEOUT_MS = 8000;

// Rate limiting configuration
const DEFAULT_RATE_LIMIT_MAX = 5;
const DEFAULT_RATE_LIMIT_WINDOW_SECONDS = 60;

interface RateLimitData {
  count: number;
  resetAt: number;
}

interface RateLimitResult {
  allowed: boolean;
  remaining: number;
  resetAt: number;
  error?: string;
  degraded?: boolean;
}

// In-memory rate limit store (fallback when KV unavailable).
// Uses Worker global scope - persists across requests within an isolate.
const inMemoryRateLimit = new Map<string, RateLimitData>();

// Circuit breaker: track consecutive KV failures
let kvFailureCount = 0;
const KV_CIRCUIT_BREAKER_THRESHOLD = 3;
let kvCircuitResetAt = 0;

/**
 * In-memory rate limiting fallback.
 * Less precise than KV (per-isolate, not global) but prevents abuse.
 */
function checkInMemoryRateLimit(
  ip: string,
  maxRequests: number,
  windowSeconds: number
): RateLimitResult {
  const now = Date.now();
  const stored = inMemoryRateLimit.get(ip);

  let data: RateLimitData;
  if (!stored || stored.resetAt < now) {
    data = { count: 1, resetAt: now + windowSeconds * 1000 };
  } else {
    data = { count: stored.count + 1, resetAt: stored.resetAt };
  }

  inMemoryRateLimit.set(ip, data);

  // Periodic cleanup: remove expired entries (max 100 per check)
  if (inMemoryRateLimit.size > 1000) {
    let cleaned = 0;
    for (const [key, val] of inMemoryRateLimit) {
      if (val.resetAt < now) {
        inMemoryRateLimit.delete(key);
        if (++cleaned >= 100) break;
      }
    }
  }

  return {
    allowed: data.count <= maxRequests,
    remaining: Math.max(0, maxRequests - data.count),
    resetAt: data.resetAt,
    degraded: true,
  };
}

/**
 * Check and update rate limit for an IP address.
 *
 * Uses KV when available, falls back to in-memory rate limiting.
 * Circuit breaker trips after 3 consecutive KV failures.
 */
async function checkRateLimit(
  ip: string,
  env: Env
): Promise<RateLimitResult> {
  const maxRequests = parseInt(env.RATE_LIMIT_MAX || '') || DEFAULT_RATE_LIMIT_MAX;
  const windowSeconds = parseInt(env.RATE_LIMIT_WINDOW_SECONDS || '') || DEFAULT_RATE_LIMIT_WINDOW_SECONDS;
  const now = Date.now();

  // If KV is not configured, use in-memory fallback
  if (!env.RATE_LIMIT_KV) {
    console.error(JSON.stringify({
      level: 'error',
      event: 'rate_limit_kv_unavailable',
      environment: env.ENVIRONMENT || 'unknown',
      ip,
      timestamp: new Date().toISOString(),
      message: 'Rate limit KV not configured - using in-memory fallback',
    }));
    return checkInMemoryRateLimit(ip, maxRequests, windowSeconds);
  }

  // Circuit breaker: skip KV if too many recent failures
  if (kvFailureCount >= KV_CIRCUIT_BREAKER_THRESHOLD && now < kvCircuitResetAt) {
    return checkInMemoryRateLimit(ip, maxRequests, windowSeconds);
  }

  // Reset circuit breaker after cooldown
  if (now >= kvCircuitResetAt) {
    kvFailureCount = 0;
  }

  const key = `rate_limit:${ip}`;

  try {
    const stored = await env.RATE_LIMIT_KV.get(key, 'json') as RateLimitData | null;

    let data: RateLimitData;
    if (!stored || stored.resetAt < now) {
      data = { count: 1, resetAt: now + windowSeconds * 1000 };
    } else {
      data = { count: stored.count + 1, resetAt: stored.resetAt };
    }

    const ttl = Math.ceil((data.resetAt - now) / 1000);
    await env.RATE_LIMIT_KV.put(key, JSON.stringify(data), { expirationTtl: Math.max(ttl, 60) });

    // KV succeeded - reset failure count
    kvFailureCount = 0;

    return {
      allowed: data.count <= maxRequests,
      remaining: Math.max(0, maxRequests - data.count),
      resetAt: data.resetAt,
    };
  } catch (error) {
    kvFailureCount++;
    kvCircuitResetAt = now + 60_000; // 1 minute cooldown

    console.error(JSON.stringify({
      level: 'error',
      event: 'rate_limit_kv_error',
      environment: env.ENVIRONMENT || 'unknown',
      ip,
      error: String(error),
      kvFailureCount,
      circuitOpen: kvFailureCount >= KV_CIRCUIT_BREAKER_THRESHOLD,
      timestamp: new Date().toISOString(),
      message: 'Rate limit KV error - using in-memory fallback',
    }));

    return checkInMemoryRateLimit(ip, maxRequests, windowSeconds);
  }
}

/**
 * Get client IP from request headers (Cloudflare provides CF-Connecting-IP).
 */
function getClientIP(request: Request): string {
  return request.headers.get('CF-Connecting-IP') ||
         request.headers.get('X-Forwarded-For')?.split(',')[0].trim() ||
         'unknown';
}

/**
 * Validate CSRF token using HMAC-SHA256.
 * Token format: {timestamp}.{signature}
 * Returns null if valid, error message if invalid.
 */
async function validateCsrfToken(
  token: string | null,
  secret: string
): Promise<string | null> {
  if (!token) {
    return 'Missing CSRF token';
  }

  const parts = token.split('.');
  if (parts.length !== 2) {
    return 'Invalid CSRF token format';
  }

  const [timestampStr, signature] = parts;
  const timestamp = parseInt(timestampStr, 10);

  if (isNaN(timestamp)) {
    return 'Invalid CSRF token timestamp';
  }

  // Check token age
  const now = Date.now();
  if (now - timestamp > CSRF_TOKEN_MAX_AGE_MS) {
    return 'CSRF token expired';
  }

  // Validate signature using Web Crypto API
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
    encoder.encode(timestampStr)
  );

  const expectedSignature = btoa(String.fromCharCode(...new Uint8Array(signatureBytes)))
    .replace(/\+/g, '-')
    .replace(/\//g, '_')
    .replace(/=+$/, '');

  // Constant-time comparison
  if (signature.length !== expectedSignature.length) {
    return 'Invalid CSRF token';
  }

  let mismatch = 0;
  for (let i = 0; i < signature.length; i++) {
    mismatch |= signature.charCodeAt(i) ^ expectedSignature.charCodeAt(i);
  }

  if (mismatch !== 0) {
    return 'Invalid CSRF token';
  }

  return null;
}

interface ContactFormData {
  name: string;
  email: string;
  organization?: string;
  message?: string;
  companySize?: string;
  useCase?: string;
}

// CORS headers for Flutter web app - restricted to production domain
const ALLOWED_ORIGINS = [
  'https://integritystudio.ai',
  'https://www.integritystudio.ai',
];

/**
 * Get CORS headers for a request.
 * Returns null if the origin is not allowed (for non-preflight requests).
 */
function getCorsHeaders(request: Request): Record<string, string> | null {
  const origin = request.headers.get('Origin') || '';
  const isAllowed = ALLOWED_ORIGINS.includes(origin);

  // For non-preflight requests from disallowed origins, return null to signal rejection
  if (!isAllowed && request.method !== 'OPTIONS') {
    console.warn(JSON.stringify({
      level: 'warn',
      event: 'cors_violation',
      origin,
      method: request.method,
      timestamp: new Date().toISOString(),
      message: 'Request from unauthorized origin',
    }));
    return null;
  }

  // For preflight, use first allowed origin if Origin doesn't match
  const allowedOrigin = isAllowed ? origin : ALLOWED_ORIGINS[0];

  return {
    'Access-Control-Allow-Origin': allowedOrigin,
    'Access-Control-Allow-Methods': 'GET, POST, OPTIONS',
    'Access-Control-Allow-Headers': 'Content-Type, X-CSRF-Token, X-Idempotency-Key',
    'Vary': 'Origin',
  };
}

// Validate email format
function isValidEmail(email: string): boolean {
  return /^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email);
}

// Field length limits for security (prevent memory exhaustion, DoS)
const MAX_NAME_LENGTH = 100;
const MAX_EMAIL_LENGTH = 254;
const MAX_ORGANIZATION_LENGTH = 200;
const MAX_COMPANY_SIZE_LENGTH = 100;
const MAX_USE_CASE_LENGTH = 200;
const MAX_MESSAGE_LENGTH = 5000;

// Validate contact form data
function validateForm(data: ContactFormData): string | null {
  if (!data.name?.trim()) return 'Name is required';
  if (data.name.length > MAX_NAME_LENGTH) return `Name must be under ${MAX_NAME_LENGTH} characters`;
  if (!data.email?.trim()) return 'Email is required';
  if (data.email.length > MAX_EMAIL_LENGTH) return `Email must be under ${MAX_EMAIL_LENGTH} characters`;
  if (!isValidEmail(data.email)) return 'Invalid email format';
  if (data.organization && data.organization.length > MAX_ORGANIZATION_LENGTH) return `Organization must be under ${MAX_ORGANIZATION_LENGTH} characters`;
  if (data.companySize && data.companySize.length > MAX_COMPANY_SIZE_LENGTH) return `Company size must be under ${MAX_COMPANY_SIZE_LENGTH} characters`;
  if (data.useCase && data.useCase.length > MAX_USE_CASE_LENGTH) return `Use case must be under ${MAX_USE_CASE_LENGTH} characters`;
  if (data.message && data.message.length > MAX_MESSAGE_LENGTH) return `Message must be under ${MAX_MESSAGE_LENGTH} characters`;
  return null;
}

/**
 * Generate a signed CSRF token.
 * Token format: {timestamp}.{signature}
 */
async function generateCsrfToken(secret: string): Promise<string> {
  const timestamp = Date.now().toString();
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
    encoder.encode(timestamp)
  );

  const signature = btoa(String.fromCharCode(...new Uint8Array(signatureBytes)))
    .replace(/\+/g, '-')
    .replace(/\//g, '_')
    .replace(/=+$/, '');

  return `${timestamp}.${signature}`;
}

/** Reset in-memory rate limit state (for testing only). */
export function _resetRateLimitState(): void {
  inMemoryRateLimit.clear();
  kvFailureCount = 0;
  kvCircuitResetAt = 0;
}

export default {
  async fetch(request: Request, env: Env): Promise<Response> {
    // Handle CORS preflight (always allowed to respond)
    if (request.method === 'OPTIONS') {
      const corsHeaders = getCorsHeaders(request)!;
      return new Response(null, { headers: corsHeaders });
    }

    // Reject requests from unauthorized origins
    const corsHeaders = getCorsHeaders(request);
    if (!corsHeaders) {
      return new Response(
        JSON.stringify({ error: 'Forbidden: unauthorized origin' }),
        { status: 403, headers: { 'Content-Type': 'application/json' } }
      );
    }

    // Handle CSRF token request
    if (request.method === 'GET') {
      if (!env.CSRF_SECRET) {
        return new Response(
          JSON.stringify({ error: 'CSRF not configured' }),
          { status: 503, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
        );
      }

      const token = await generateCsrfToken(env.CSRF_SECRET);
      return new Response(
        JSON.stringify({ csrfToken: token }),
        { status: 200, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      );
    }

    // Only accept POST requests for form submission
    if (request.method !== 'POST') {
      return new Response(
        JSON.stringify({ error: 'Method not allowed' }),
        { status: 405, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      );
    }

    // Check rate limit
    const clientIP = getClientIP(request);
    const rateLimit = await checkRateLimit(clientIP, env);

    // Log if operating in degraded mode (for monitoring dashboards)
    if (rateLimit.degraded) {
      console.warn(JSON.stringify({
        level: 'warn',
        event: 'rate_limit_degraded_request',
        ip: clientIP,
        timestamp: new Date().toISOString(),
        message: 'Request processed in degraded rate limiting mode',
      }));
    }

    if (!rateLimit.allowed) {
      return new Response(
        JSON.stringify({
          error: 'Too many requests. Please try again later.',
          retryAfter: Math.ceil((rateLimit.resetAt - Date.now()) / 1000),
        }),
        {
          status: 429,
          headers: {
            ...corsHeaders,
            'Content-Type': 'application/json',
            'Retry-After': String(Math.ceil((rateLimit.resetAt - Date.now()) / 1000)),
            'X-RateLimit-Limit': String(parseInt(env.RATE_LIMIT_MAX || '') || DEFAULT_RATE_LIMIT_MAX),
            'X-RateLimit-Remaining': '0',
            'X-RateLimit-Reset': String(Math.ceil(rateLimit.resetAt / 1000)),
          },
        }
      );
    }

    // Validate CSRF token (only if secret is configured)
    if (env.CSRF_SECRET) {
      const csrfToken = request.headers.get('X-CSRF-Token');
      const csrfError = await validateCsrfToken(csrfToken, env.CSRF_SECRET);
      if (csrfError) {
        return new Response(
          JSON.stringify({ error: csrfError }),
          { status: 403, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
        );
      }
    }

    try {
      // Parse request body
      const data: ContactFormData = await request.json();

      // Validate form data
      const validationError = validateForm(data);
      if (validationError) {
        return new Response(
          JSON.stringify({ error: validationError }),
          { status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
        );
      }

      // Initialize Resend client
      const resend = new Resend(env.RESEND_API_KEY);

      // Send email via Resend with timeout protection
      let emailResult;
      let error;
      try {
        const result = await withTimeout(
          resend.emails.send({
            from: `Integrity Studio Contact <${env.SENDER_EMAIL}>`,
            to: [env.RECIPIENT_EMAIL],
            replyTo: data.email,
            subject: `New Contact Form: ${data.name}${data.organization ? ` (${data.organization})` : ''}`,
            html: `
              <h2>New Contact Form Submission</h2>
              <p><strong>Name:</strong> ${escapeHtml(data.name)}</p>
              <p><strong>Email:</strong> <a href="mailto:${encodeURIComponent(data.email)}">${escapeHtml(data.email)}</a></p>
              ${data.organization ? `<p><strong>Organization:</strong> ${escapeHtml(data.organization)}</p>` : ''}
              ${data.companySize ? `<p><strong>Company Size:</strong> ${escapeHtml(data.companySize)}</p>` : ''}
              ${data.useCase ? `<p><strong>Primary Interest:</strong> ${escapeHtml(data.useCase)}</p>` : ''}
              ${data.message ? `<h3>Message:</h3>
              <p>${escapeHtml(data.message).replace(/\n/g, '<br>')}</p>` : ''}
              <hr>
              <p style="color: #666; font-size: 12px;">
                Sent from IntegrityStudio.ai contact form at ${new Date().toISOString()}
              </p>
            `,
            text: `
New Contact Form Submission

Name: ${data.name}
Email: ${data.email}
${data.organization ? `Organization: ${data.organization}\n` : ''}${data.companySize ? `Company Size: ${data.companySize}\n` : ''}${data.useCase ? `Primary Interest: ${data.useCase}\n` : ''}${data.message ? `\nMessage:\n${data.message}` : ''}

---
Sent from IntegrityStudio.ai contact form at ${new Date().toISOString()}
            `.trim(),
          }),
          RESEND_API_TIMEOUT_MS,
          'Resend API call'
        );
        emailResult = result.data;
        error = result.error;
      } catch (timeoutError) {
        console.error('Resend timeout:', timeoutError);
        return new Response(
          JSON.stringify({ error: 'Email service timeout. Please try again.' }),
          { status: 504, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
        );
      }

      if (error) {
        console.error('Resend error:', error);
        return new Response(
          JSON.stringify({ error: 'Failed to send email. Please try again.' }),
          { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
        );
      }

      // Return success response
      return new Response(
        JSON.stringify({
          success: true,
          message: "Thank you for your message! We'll respond within 24 hours.",
          submissionId: emailResult?.id || `sub_${Date.now()}`,
        }),
        { status: 200, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      );

    } catch (err) {
      console.error('Worker error:', err);
      return new Response(
        JSON.stringify({ error: 'An unexpected error occurred. Please try again.' }),
        { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      );
    }
  },
};

/**
 * Wrap a promise with a timeout.
 * Rejects with TimeoutError if the promise doesn't resolve within the timeout.
 */
async function withTimeout<T>(promise: Promise<T>, timeoutMs: number, operation: string): Promise<T> {
  let timeoutId: ReturnType<typeof setTimeout>;
  const timeoutPromise = new Promise<never>((_, reject) => {
    timeoutId = setTimeout(() => {
      reject(new Error(`${operation} timed out after ${timeoutMs}ms`));
    }, timeoutMs);
  });

  try {
    return await Promise.race([promise, timeoutPromise]);
  } finally {
    clearTimeout(timeoutId!);
  }
}

// Escape HTML to prevent XSS in email
function escapeHtml(text: string): string {
  return text
    .replace(/&/g, '&amp;')
    .replace(/</g, '&lt;')
    .replace(/>/g, '&gt;')
    .replace(/"/g, '&quot;')
    .replace(/'/g, '&#039;');
}
