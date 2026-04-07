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
  FORBIDDEN: "forbidden",
  NOT_FOUND: "NOT_FOUND",
  INTERNAL_ERROR: "INTERNAL_ERROR",
  AUTH0_UNCONFIGURED: "AUTH0_UNCONFIGURED",
  AUTH0_TOKEN_EXCHANGE_FAILED: "AUTH0_TOKEN_EXCHANGE_FAILED",
  AUTH0_USER_CREATION_FAILED: "AUTH0_USER_CREATION_FAILED",
  SUPABASE_ORG_CREATION_FAILED: "SUPABASE_ORG_CREATION_FAILED",
  SUPABASE_USER_INSERT_FAILED: "SUPABASE_USER_INSERT_FAILED",
  SUPABASE_ORG_MEMBERSHIP_FAILED: "SUPABASE_ORG_MEMBERSHIP_FAILED",
} as const;
export type ErrorCode = (typeof ERROR_CODE)[keyof typeof ERROR_CODE];

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
} as const;

export const CONTENT_TYPES = {
  JSON: "application/json; charset=utf-8",
} as const;

export const ActionSchema = z.enum(["provision_api_key"]);
export type Action = z.infer<typeof ActionSchema>;

export const ApiKeyTierSchema = z.enum(["starter", "growth", "enterprise"]);
export type ApiKeyTier = z.infer<typeof ApiKeyTierSchema>;
export const DEFAULT_TIER: ApiKeyTier = "starter";

export const EMAIL_REGEX = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;

export const SendRequestSchema = z.object({
  action: ActionSchema,
  jwt: z.string().jwt(),
  name: z.string().min(1),
  email: z.string().email(),
  tier: ApiKeyTierSchema.catch(DEFAULT_TIER),
  org_name: z.coerce.string().optional(),
}).transform((data) => ({
  ...data,
  org_name: data.org_name ?? data.email.split("@")[1],
}));

export const CreateCheckoutSessionSchema = z.object({
  email: z.string().email(),
  tier: ApiKeyTierSchema,
});
export type CreateCheckoutSession = z.infer<typeof CreateCheckoutSessionSchema>;

export const SERVICE_NAME = "api-provisioning-sender";

export const AUTH0_CONNECTION = "Username-Password-Authentication";

export const DEFAULT_APP_BASE_URL = "https://integritystudio.ai";

export interface Env {
  SHARED_SECRET: string;
  /** Service binding to api-provisioning-receiver. */
  RECEIVER: Fetcher;
  AUTH0_DOMAIN: string;
  /** Auth0 app credentials for both ROPC (password grant) and Management API (client_credentials grant). */
  AUTH0_CLIENT_ID: string;
  AUTH0_CLIENT_SECRET: string;
  /** Auth0 audience (used for both ROPC and Management API calls). */
  AUTH0_AUDIENCE: string;
  SUPABASE_URL: string;
  SUPABASE_SERVICE_ROLE_KEY: string;
  ALLOWED_ORIGINS_JSON?: string;
  STRIPE_SECRET_KEY?: string;
  STRIPE_PLAN_TO_PRICE_JSON?: string;
  APP_BASE_URL?: string;
}
