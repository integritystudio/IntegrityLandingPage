import { z } from "zod";

export const ROUTES = {
  HEALTH: "/health",
  SEND: "/send",
  CREATE_CHECKOUT_SESSION: "/create-checkout-session",
} as const;

export const HTTP_METHODS = {
  GET: "GET",
  POST: "POST",
  OPTIONS: "OPTIONS",
} as const;

export const HTTP_STATUS = {
  OK: 200,
  NO_CONTENT: 204,
  BAD_REQUEST: 400,
  UNAUTHORIZED: 401,
  FORBIDDEN: 403,
  NOT_FOUND: 404,
  INTERNAL_SERVER_ERROR: 500,
  BAD_GATEWAY: 502,
} as const;

export const ERROR_CODE = {
  MISSING_FIELDS: "MISSING_FIELDS",
  INVALID_EMAIL: "INVALID_EMAIL",
  INVALID_AUTH: "INVALID_AUTH",
  JSON_PARSE_ERROR: "JSON_PARSE_ERROR",
  UNKNOWN_ACTION: "UNKNOWN_ACTION",
  RECEIVER_ERROR: "RECEIVER_ERROR",
  FORBIDDEN: "FORBIDDEN",
  NOT_FOUND: "NOT_FOUND",
  INTERNAL_ERROR: "INTERNAL_ERROR",
  SIGNING_KEY_UNRESOLVED: "SIGNING_KEY_UNRESOLVED",
  // Receiver-specific codes — proxied verbatim in error responses
  RECEIVER_QUOTA_EXCEEDED: "QUOTA_EXCEEDED",
  RECEIVER_RATE_LIMITED: "RATE_LIMITED",
  RECEIVER_REPLAY_DETECTED: "REPLAY_DETECTED",
  RECEIVER_INVALID_EMAIL_DOMAIN: "INVALID_EMAIL_DOMAIN",
  RECEIVER_NOT_IMPLEMENTED: "NOT_IMPLEMENTED",
} as const;
export type ErrorCode = (typeof ERROR_CODE)[keyof typeof ERROR_CODE];

export const ERROR_DESCRIPTIONS: Partial<Record<ErrorCode, string>> = {
  [ERROR_CODE.MISSING_FIELDS]:
    "Request body is missing one or more required fields. Check the endpoint contract for the expected schema.",
  [ERROR_CODE.INVALID_EMAIL]:
    "Email field failed format validation. Must match a standard local@domain.tld pattern with no whitespace.",
  [ERROR_CODE.INVALID_AUTH]:
    "JWT is missing, malformed, or expired. Sign in again (Auth0 Universal Login) to obtain a fresh token.",
  [ERROR_CODE.JSON_PARSE_ERROR]:
    "Request body is not valid JSON. Ensure content-type: application/json and a well-formed body.",
  [ERROR_CODE.UNKNOWN_ACTION]:
    "The action field does not match a supported discriminant. Supported values: provision_api_key, sign_in.",
  [ERROR_CODE.RECEIVER_ERROR]:
    "Receiver worker returned a non-2xx response that could not be classified further. Check receiver logs.",
  [ERROR_CODE.FORBIDDEN]:
    "Request origin is not in the allowed origins list. Configure ALLOWED_ORIGINS_JSON on the worker if this origin should be permitted.",
  [ERROR_CODE.NOT_FOUND]:
    "No route matches the request method and path. Supported routes: GET /health, POST /send, POST /create-checkout-session.",
  [ERROR_CODE.INTERNAL_ERROR]:
    "Unclassified server error. Check worker logs for the underlying cause (missing env var, upstream timeout, or unhandled exception).",
  [ERROR_CODE.SIGNING_KEY_UNRESOLVED]:
    "No usable signing key could be resolved from ACTIVE_KEY_ID + SIGNING_KEYS, so the request was not signed and not sent. Deliberately fails closed rather than downgrading to SHARED_SECRET — see BACKLOG.md CR29. Check the worker logs for which of the four causes fired (ACTIVE_KEY_ID unset, or SIGNING_KEYS unbound, malformed, or missing that key id), then correct the binding.",
  [ERROR_CODE.RECEIVER_QUOTA_EXCEEDED]:
    "Tier quota reached for API key provisioning. Starter=3, Growth=10, Enterprise=unlimited. Upgrade tier or revoke unused keys to proceed.",
  [ERROR_CODE.RECEIVER_RATE_LIMITED]:
    "Receiver rate limiter rejected the request. Retry after the configured window expires; check Retry-After header if present.",
  [ERROR_CODE.RECEIVER_REPLAY_DETECTED]:
    "Receiver detected a replayed HMAC signature (nonce already seen within the replay window). Generate a fresh timestamp and re-sign the request.",
  [ERROR_CODE.RECEIVER_INVALID_EMAIL_DOMAIN]:
    "Receiver rejected the email domain. Likely causes: disposable/blocklisted domain, failed MX lookup, or domain not in the allowlist.",
  [ERROR_CODE.RECEIVER_NOT_IMPLEMENTED]:
    "Receiver does not implement the requested action. Verify the action field matches a supported value (provision_api_key, sign_in).",
} as const;

export const CORS_ALLOW_METHODS = "GET, POST, OPTIONS";
export const CORS_ALLOW_HEADERS = "content-type, authorization, x-session-data";

export const RECEIVER_PATHS = {
  INBOX: "/inbox",
} as const;

export const SUPABASE_PATHS = {
  USERS: "/rest/v1/users",
  ORG_MEMBERSHIPS: "/rest/v1/organization_memberships",
} as const;

export const HEADER_NAMES = {
  CONTENT_TYPE: "content-type",
  AUTHORIZATION: "authorization",
  TIMESTAMP: "x-timestamp",
  SIGNATURE: "x-signature",
  KEY_ID: "x-key-id",
  // Client IP: read from the inbound request, forwarded to the receiver so its
  // Analytics Engine metrics can index by real client IP (per-IP 401 monitoring).
  CF_CONNECTING_IP: "CF-Connecting-IP",
  X_FORWARDED_FOR: "X-Forwarded-For",
} as const;

export const CONTENT_TYPES = {
  JSON: "application/json; charset=utf-8",
} as const;

export const ApiKeyTierSchema = z.enum(["starter", "growth", "enterprise"]);
export type ApiKeyTier = z.infer<typeof ApiKeyTierSchema>;

/** Seats a checkout opens at when the plan sets no minimum. */
export const DEFAULT_CHECKOUT_SEATS = 1;

// The fewest seats a plan can be bought with: enterprise is $50 per user per month with a
// 6-user minimum. The Stripe price bills the minimum by itself (graduated tiers); checkout
// opens here so the seat quantity matches. Mirrors PLAN_MIN_SEATS in workers/lib/billing.ts.
export const PLAN_MIN_SEATS: Partial<Record<ApiKeyTier, number>> = { enterprise: 6 };

export const ProvisionApiKeyRequestSchema = z.object({
  action: z.literal("provision_api_key"),
  jwt: z.string().jwt(),
  name: z.string().min(1),
  email: z.string().email(),
  // No `tier` (CR37): the receiver used to write it as a new org's current_plan and pick the
  // membership role from it. The plan is server-side state; a request carrying `tier` (the
  // Flutter app still sends one) is accepted and the field is stripped.
  // org_name is optional — when absent, the receiver derives the team org name from the
  // registrable domain (emailToRegistrableDomainSchema / tldts getDomain). Passing a raw
  // email suffix here would produce incorrect names for subdomain addresses (e.g.
  // "mail.company.co.uk" instead of "company.co.uk"), breaking org deduplication.
  org_name: z.string().min(1).optional(),
});

export const SignInRequestSchema = z.object({
  action: z.literal("sign_in"),
  jwt: z.string().jwt(),
  email: z.string().email(),
});

export const SendRequestSchema = z.discriminatedUnion("action", [
  ProvisionApiKeyRequestSchema,
  SignInRequestSchema,
]);

export const CreateCheckoutSessionSchema = z.object({
  email: z.string().email(),
  tier: ApiKeyTierSchema,
});
export type CreateCheckoutSession = z.infer<typeof CreateCheckoutSessionSchema>;

export const SERVICE_NAME = "api-provisioning-sender";

export const DEFAULT_APP_BASE_URL = "https://integritystudio.ai";

export interface Env {
  /**
   * Retired — SIGNING_KEYS + ACTIVE_KEY_ID are the only outbound credential (CR29, closed
   * 2026-08-03). Unbound from production and deleted from Doppler; nothing reads it. Still
   * declared, and still set in the test fixtures with a value different from the active key,
   * so the tests prove that signing does not fall back to it while it is present. Do not
   * remove the declaration or the fixture value — that turns "unreachable" into "absent".
   */
  SHARED_SECRET?: string;
  /** JSON-encoded Record<string, string> mapping keyId → secret. Required to sign anything. */
  SIGNING_KEYS?: string;
  /**
   * The key ID to use from SIGNING_KEYS, sent as x-key-id. Required: with this unset the worker
   * cannot sign, because the receiver rejects a request that carries no key id.
   */
  ACTIVE_KEY_ID?: string;
  /** Service binding to api-provisioning-receiver. */
  RECEIVER: Fetcher;
  SUPABASE_URL: string;
  SUPABASE_SERVICE_ROLE_KEY: string;
  ALLOWED_ORIGINS_JSON?: string;
  STRIPE_SECRET_KEY?: string;
  STRIPE_PLAN_TO_PRICE_JSON?: string;
  APP_BASE_URL?: string;
}
