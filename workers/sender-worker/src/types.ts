export const ROUTES = {
  HEALTH: "/health",
  SIGNUP: "/signup",
  SIGNIN: "/signin",
  SEND: "/send",
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
  INTERNAL_SERVER_ERROR: 500,
  BAD_GATEWAY: 502,
} as const;

export const ERROR_CODE = {
  MISSING_FIELDS: "MISSING_FIELDS",
  JSON_PARSE_ERROR: "JSON_PARSE_ERROR",
  SUPABASE_SIGNUP_ERROR: "SUPABASE_SIGNUP_ERROR",
  SUPABASE_CONFIRM_ERROR: "SUPABASE_CONFIRM_ERROR",
  SUPABASE_INSERT_ERROR: "SUPABASE_INSERT_ERROR",
  SUPABASE_SIGNIN_ERROR: "SUPABASE_SIGNIN_ERROR",
  UNKNOWN_ACTION: "UNKNOWN_ACTION",
  RECEIVER_ERROR: "RECEIVER_ERROR",
  FORBIDDEN: "forbidden",
  NOT_FOUND: "NOT_FOUND",
  INTERNAL_ERROR: "INTERNAL_ERROR",
} as const;

export const CORS_HEADERS = {
  "access-control-allow-methods": "GET, POST, OPTIONS",
  "access-control-allow-headers": "content-type, authorization",
  "access-control-max-age": "86400",
} as const;

export const SUPABASE_PATHS = {
  SIGNUP: "/auth/v1/signup",
  SIGNIN_PASSWORD: "/auth/v1/token?grant_type=password",
  ADMIN_USERS: "/auth/v1/admin/users",
  TABLE_USERS: "/rest/v1/users",
  TABLE_ORGANIZATIONS: "/rest/v1/organizations",
  TABLE_ORG_MEMBERSHIPS: "/rest/v1/organization_memberships",
} as const;

/** Slug prefix that identifies a personal (single-user) default organization. */
export const PERSONAL_ORG_SLUG_PREFIX = "personal-" as const;

/** Default plan and billing state for auto-created personal organizations. */
export const PERSONAL_ORG_DEFAULTS = {
  current_plan: "free",
  billing_status: "inactive",
} as const;

export const SUPABASE_HEADER_NAMES = {
  API_KEY: "apikey",
  PREFER: "prefer",
} as const;

export const SUPABASE_PREFER = {
  RETURN_MINIMAL: "return=minimal",
} as const;

export const RECEIVER_PATHS = {
  INBOX: "/inbox",
} as const;

export const HEADER_NAMES = {
  CONTENT_TYPE: "content-type",
  AUTHORIZATION: "authorization",
  TIMESTAMP: "x-timestamp",
  SIGNATURE: "x-signature",
} as const;

export const CONTENT_TYPES = {
  JSON: "application/json; charset=utf-8",
} as const;

export const SERVICE_NAME = "api-provisioning-sender";

export interface Env {
  SHARED_SECRET: string;
  RECEIVER_WORKER_URL: string;
  SUPABASE_URL: string;
  SUPABASE_ANON_KEY: string;
  SUPABASE_SERVICE_ROLE_KEY: string;
  ALLOWED_ORIGINS_JSON?: string;
}
