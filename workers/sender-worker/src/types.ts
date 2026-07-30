import { z } from "zod";

export const ROUTES = {
  HEALTH: "/health",
  SIGNUP: "/signup",
  SIGNIN: "/signin",
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
  CREATED: 201,
  NO_CONTENT: 204,
  BAD_REQUEST: 400,
  UNAUTHORIZED: 401,
  FORBIDDEN: 403,
  NOT_FOUND: 404,
  TOO_MANY_REQUESTS: 429,
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
  INVALID_CREDENTIALS: "INVALID_CREDENTIALS",
  AUTH0_UNCONFIGURED: "AUTH0_UNCONFIGURED",
  AUTH0_TOKEN_EXCHANGE_FAILED: "AUTH0_TOKEN_EXCHANGE_FAILED",
  AUTH0_USER_CREATION_FAILED: "AUTH0_USER_CREATION_FAILED",
  SUPABASE_ORG_CREATION_FAILED: "SUPABASE_ORG_CREATION_FAILED",
  SUPABASE_USER_INSERT_FAILED: "SUPABASE_USER_INSERT_FAILED",
  SUPABASE_ORG_MEMBERSHIP_FAILED: "SUPABASE_ORG_MEMBERSHIP_FAILED",
  RATE_LIMITED: "RATE_LIMITED",
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
    "JWT is missing, malformed, or expired. Re-authenticate via /signin to obtain a fresh token.",
  [ERROR_CODE.JSON_PARSE_ERROR]:
    "Request body is not valid JSON. Ensure content-type: application/json and a well-formed body.",
  [ERROR_CODE.UNKNOWN_ACTION]:
    "The action field does not match a supported discriminant. Supported values: provision_api_key, sign_in.",
  [ERROR_CODE.RECEIVER_ERROR]:
    "Receiver worker returned a non-2xx response that could not be classified further. Check receiver logs.",
  [ERROR_CODE.FORBIDDEN]:
    "Request origin is not in the allowed origins list. Configure ALLOWED_ORIGINS_JSON on the worker if this origin should be permitted.",
  [ERROR_CODE.NOT_FOUND]:
    "No route matches the request method and path. Supported routes: GET /health, POST /signup, POST /signin, POST /send, POST /create-checkout-session.",
  [ERROR_CODE.INTERNAL_ERROR]:
    "Unclassified server error. Check worker logs for the underlying cause (missing env var, upstream timeout, or unhandled exception).",
  [ERROR_CODE.INVALID_CREDENTIALS]:
    "Email or password is incorrect, or no account exists for that email. Deliberately does not distinguish between those cases, to avoid user enumeration.",
  [ERROR_CODE.AUTH0_UNCONFIGURED]:
    "Auth0 environment variables are missing on the worker. Required: AUTH0_DOMAIN, AUTH0_CLIENT_ID, AUTH0_CLIENT_SECRET, AUTH0_AUDIENCE, AUTH0_CLI_ID, AUTH0_CLI_SECRET.",
  [ERROR_CODE.AUTH0_TOKEN_EXCHANGE_FAILED]:
    "Auth0 /oauth/token rejected the credentials. Likely causes: invalid email/password, disabled user, or ROPC grant not enabled on the Auth0 application.",
  [ERROR_CODE.AUTH0_USER_CREATION_FAILED]:
    "Auth0 rejected user creation. Likely causes: password policy violation, email already registered, or connection misconfiguration.",
  [ERROR_CODE.SUPABASE_ORG_CREATION_FAILED]:
    "Supabase rejected personal organization creation. Likely causes: duplicate email on an existing personal org, or service role key misconfiguration.",
  [ERROR_CODE.SUPABASE_USER_INSERT_FAILED]:
    "Supabase rejected the users row insert. Likely causes: auth0_id unique conflict, FK constraint violation, or RLS/service role key misconfiguration.",
  [ERROR_CODE.SUPABASE_ORG_MEMBERSHIP_FAILED]:
    "Supabase rejected the organization_memberships insert. Likely causes: missing org or user row (partial-failure upstream), or duplicate (user_id, org_id) pair.",
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

export const CORS_HEADERS = {
  "access-control-allow-methods": "GET, POST, OPTIONS",
  "access-control-allow-headers": "content-type, authorization, x-session-data",
  "access-control-max-age": "86400",
} as const;

export const AUTH0_PATHS = {
  TOKEN: "/oauth/token",
  USERS: "/api/v2/users",
} as const;

export const RECEIVER_PATHS = {
  INBOX: "/inbox",
} as const;

export const SUPABASE_PATHS = {
  ORGANIZATIONS: "/rest/v1/organizations",
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
export const DEFAULT_TIER: ApiKeyTier = "starter";

export const EMAIL_REGEX = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;

export const ProvisionApiKeyRequestSchema = z.object({
  action: z.literal("provision_api_key"),
  jwt: z.string().jwt(),
  name: z.string().min(1),
  email: z.string().email(),
  tier: ApiKeyTierSchema.catch(DEFAULT_TIER),
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

export const AUTH0_CONNECTION = "Username-Password-Authentication";

export const ORG_TYPES = {
  PERSONAL: "personal",
} as const;

export const MEMBERSHIP_ROLES = {
  OWNER: "owner",
} as const;

export const DEFAULT_APP_BASE_URL = "https://integritystudio.ai";

/** Maximum auth requests (signup/signin) per IP per rate-limit window. */
export const AUTH_RATE_LIMIT_MAX = 10;
/** Auth rate-limit window length in seconds (10 minutes). */
export const AUTH_RATE_LIMIT_WINDOW_SECONDS = 600;

export interface Env {
  SHARED_SECRET: string;
  /** JSON-encoded Record<string, string> mapping keyId → secret; enables x-key-id rotation. */
  SIGNING_KEYS?: string;
  /** The key ID to use from SIGNING_KEYS when sending signed requests. Omit to use SHARED_SECRET. */
  ACTIVE_KEY_ID?: string;
  /** Service binding to api-provisioning-receiver. */
  RECEIVER: Fetcher;
  AUTH0_DOMAIN: string;
  /** Auth0 Regular Web App credentials — password grant (ROPC), used to sign users in after creation. */
  AUTH0_CLIENT_ID: string;
  AUTH0_CLIENT_SECRET: string;
  /** Auth0 M2M app credentials — client_credentials grant only, used to obtain a Management API token for user creation. */
  AUTH0_CLI_ID: string;
  AUTH0_CLI_SECRET: string;
  /** Auth0 audience for ROPC tokens. */
  AUTH0_AUDIENCE: string;
  SUPABASE_URL: string;
  SUPABASE_SERVICE_ROLE_KEY: string;
  ALLOWED_ORIGINS_JSON?: string;
  /** Optional KV namespace for cross-DC rate limiting on auth endpoints. Falls back to in-memory if absent. */
  RATE_LIMIT_KV?: KVNamespace;
  STRIPE_SECRET_KEY?: string;
  STRIPE_PLAN_TO_PRICE_JSON?: string;
  APP_BASE_URL?: string;
}
