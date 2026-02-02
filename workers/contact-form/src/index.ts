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
  error?: string; // Present if rate limiting infrastructure failed
}

/**
 * Check if running in production environment.
 */
function isProduction(env: Env): boolean {
  return env.ENVIRONMENT === 'production';
}

/**
 * Check and update rate limit for an IP address.
 *
 * Security: In production, this function FAILS CLOSED - if KV is unavailable,
 * requests are denied (returns error). In development, it fails open to avoid
 * blocking local testing.
 */
async function checkRateLimit(
  ip: string,
  env: Env
): Promise<RateLimitResult> {
  const maxRequests = parseInt(env.RATE_LIMIT_MAX || '') || DEFAULT_RATE_LIMIT_MAX;
  const windowSeconds = parseInt(env.RATE_LIMIT_WINDOW_SECONDS || '') || DEFAULT_RATE_LIMIT_WINDOW_SECONDS;
  const now = Date.now();
  const key = `rate_limit:${ip}`;

  // If KV is not configured
  if (!env.RATE_LIMIT_KV) {
    if (isProduction(env)) {
      // FAIL CLOSED in production - deny request if rate limiting unavailable
      console.error('Rate limit KV not configured in production environment');
      return {
        allowed: false,
        remaining: 0,
        resetAt: now + windowSeconds * 1000,
        error: 'Rate limiting service unavailable',
      };
    }
    // Fail open for development
    return { allowed: true, remaining: maxRequests, resetAt: now + windowSeconds * 1000 };
  }

  try {
    const stored = await env.RATE_LIMIT_KV.get(key, 'json') as RateLimitData | null;

    let data: RateLimitData;
    if (!stored || stored.resetAt < now) {
      // Start new window
      data = { count: 1, resetAt: now + windowSeconds * 1000 };
    } else {
      // Increment existing window
      data = { count: stored.count + 1, resetAt: stored.resetAt };
    }

    // Store updated count with TTL
    const ttl = Math.ceil((data.resetAt - now) / 1000);
    await env.RATE_LIMIT_KV.put(key, JSON.stringify(data), { expirationTtl: Math.max(ttl, 60) });

    return {
      allowed: data.count <= maxRequests,
      remaining: Math.max(0, maxRequests - data.count),
      resetAt: data.resetAt,
    };
  } catch (error) {
    console.error('Rate limit error:', error);
    if (isProduction(env)) {
      // FAIL CLOSED in production - deny request on KV errors
      return {
        allowed: false,
        remaining: 0,
        resetAt: now + windowSeconds * 1000,
        error: 'Rate limiting service error',
      };
    }
    // Fail open for development
    return { allowed: true, remaining: maxRequests, resetAt: now + windowSeconds * 1000 };
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
  message: string;
}

// CORS headers for Flutter web app - restricted to production domain
const ALLOWED_ORIGINS = [
  'https://integritystudio.ai',
  'https://www.integritystudio.ai',
];

function getCorsHeaders(request: Request): Record<string, string> {
  const origin = request.headers.get('Origin') || '';
  const allowedOrigin = ALLOWED_ORIGINS.includes(origin) ? origin : ALLOWED_ORIGINS[0];

  return {
    'Access-Control-Allow-Origin': allowedOrigin,
    'Access-Control-Allow-Methods': 'GET, POST, OPTIONS',
    'Access-Control-Allow-Headers': 'Content-Type, X-CSRF-Token',
    'Vary': 'Origin',
  };
}

// Validate email format
function isValidEmail(email: string): boolean {
  return /^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email);
}

// Validate contact form data
function validateForm(data: ContactFormData): string | null {
  if (!data.name?.trim()) return 'Name is required';
  if (!data.email?.trim()) return 'Email is required';
  if (!isValidEmail(data.email)) return 'Invalid email format';
  if (!data.message?.trim()) return 'Message is required';
  if (data.message.trim().length < 10) return 'Message must be at least 10 characters';
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

export default {
  async fetch(request: Request, env: Env): Promise<Response> {
    const corsHeaders = getCorsHeaders(request);

    // Handle CORS preflight
    if (request.method === 'OPTIONS') {
      return new Response(null, { headers: corsHeaders });
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

    // Handle rate limiting infrastructure failure (503 Service Unavailable)
    if (rateLimit.error) {
      return new Response(
        JSON.stringify({
          error: 'Service temporarily unavailable. Please try again later.',
        }),
        {
          status: 503,
          headers: {
            ...corsHeaders,
            'Content-Type': 'application/json',
            'Retry-After': '60',
          },
        }
      );
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

      // Send email via Resend
      const { data: emailResult, error } = await resend.emails.send({
        from: `Integrity Studio Contact <${env.SENDER_EMAIL}>`,
        to: [env.RECIPIENT_EMAIL],
        replyTo: data.email,
        subject: `New Contact Form: ${data.name}${data.organization ? ` (${data.organization})` : ''}`,
        html: `
          <h2>New Contact Form Submission</h2>
          <p><strong>Name:</strong> ${escapeHtml(data.name)}</p>
          <p><strong>Email:</strong> <a href="mailto:${escapeHtml(data.email)}">${escapeHtml(data.email)}</a></p>
          ${data.organization ? `<p><strong>Organization:</strong> ${escapeHtml(data.organization)}</p>` : ''}
          <h3>Message:</h3>
          <p>${escapeHtml(data.message).replace(/\n/g, '<br>')}</p>
          <hr>
          <p style="color: #666; font-size: 12px;">
            Sent from IntegrityStudio.ai contact form at ${new Date().toISOString()}
          </p>
        `,
        text: `
New Contact Form Submission

Name: ${data.name}
Email: ${data.email}
${data.organization ? `Organization: ${data.organization}\n` : ''}
Message:
${data.message}

---
Sent from IntegrityStudio.ai contact form at ${new Date().toISOString()}
        `.trim(),
      });

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

// Escape HTML to prevent XSS in email
function escapeHtml(text: string): string {
  return text
    .replace(/&/g, '&amp;')
    .replace(/</g, '&lt;')
    .replace(/>/g, '&gt;')
    .replace(/"/g, '&quot;')
    .replace(/'/g, '&#039;');
}
