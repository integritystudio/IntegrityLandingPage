import {
  ROUTES,
  HTTP_METHODS,
  HTTP_STATUS,
  ERROR_CODE,
  ERROR_DESCRIPTIONS,
  HEADER_NAMES,
  CONTENT_TYPES,
  CORS_HEADERS,
  RECEIVER_PATHS,
  SERVICE_NAME,
  EMAIL_REGEX,
  ApiKeyTierSchema,
  DEFAULT_TIER,
  SendRequestSchema,
  CreateCheckoutSessionSchema,
  DEFAULT_APP_BASE_URL,
  type ApiKeyTier,
  type ErrorCode,
  type Env,
} from "./types.js";
import { json } from "../../lib/http/responses.js";
import { errorResponse, resolveOutboundSigningKey } from "./utils.js";
import { signMessage } from "./crypto.js";
import {
  auth0CreateUser,
  auth0UserSignIn,
  supabaseCreatePersonalOrg,
  supabaseInsertUser,
  supabaseAddOrgOwner,
} from "./supabase.js";
import { createStripeCheckoutSession } from "./stripe.js";
import { VERSION } from "./version.js";


const HARDCODED_ALLOWED_ORIGINS = [
  "https://integritystudio.ai",
  "https://www.integritystudio.ai",
];

// Cloudflare Pages preview deployments for the integritystudio-ai project are served at
// https://<deploy-hash>.integritystudio-ai-c1a.pages.dev (and named-branch aliases). These
// hostnames are owned exclusively by this account's Pages project, so matching the suffix is
// safe and lets preview builds exercise the live sender without per-deploy ALLOWED_ORIGINS_JSON
// edits. The leading dot enforces a subdomain boundary (the bare alias and lookalike hosts such
// as `…pages.dev.attacker.com` do not match), and only https origins are accepted.
const PAGES_PREVIEW_HOST_SUFFIX = ".integritystudio-ai-c1a.pages.dev";

function getAllowedOrigins(env: Env): string[] {
  if (env.ALLOWED_ORIGINS_JSON) {
    try {
      return JSON.parse(env.ALLOWED_ORIGINS_JSON) as string[];
    } catch {
      return HARDCODED_ALLOWED_ORIGINS;
    }
  }
  return HARDCODED_ALLOWED_ORIGINS;
}

function isPagesPreviewOrigin(origin: string): boolean {
  let url: URL;
  try {
    url = new URL(origin);
  } catch {
    return false;
  }
  return url.protocol === "https:" && url.hostname.endsWith(PAGES_PREVIEW_HOST_SUFFIX);
}

function isOriginAllowed(origin: string, env: Env): boolean {
  return getAllowedOrigins(env).includes(origin) || isPagesPreviewOrigin(origin);
}

async function handleSignup(env: Env, req: Record<string, unknown>): Promise<Response> {
  if (!req.email || !req.password) {
    return errorResponse("missing email or password", ERROR_CODE.MISSING_FIELDS, HTTP_STATUS.BAD_REQUEST);
  }
  if (!EMAIL_REGEX.test(req.email as string)) {
    return errorResponse("invalid email format", ERROR_CODE.INVALID_EMAIL, HTTP_STATUS.BAD_REQUEST);
  }

  const email = req.email as string;
  const password = req.password as string;
  const providedName = typeof req.name === "string" && req.name.trim() ? req.name.trim() : null;
  const tierParsed = ApiKeyTierSchema.safeParse(req.tier);
  const tier: ApiKeyTier = tierParsed.success ? tierParsed.data : DEFAULT_TIER;
  const orgName = providedName ?? `${email.split("@")[0]} (personal)`;

  try {
    if (!env.AUTH0_DOMAIN || !env.AUTH0_CLIENT_ID || !env.AUTH0_CLIENT_SECRET || !env.AUTH0_AUDIENCE || !env.AUTH0_CLI_ID || !env.AUTH0_CLI_SECRET) {
      return errorResponse("Auth0 not configured", ERROR_CODE.AUTH0_UNCONFIGURED, HTTP_STATUS.INTERNAL_SERVER_ERROR);
    }

    const userId = crypto.randomUUID();

    const [{ auth0Sub }, orgId] = await Promise.all([
      auth0CreateUser(
        env.AUTH0_DOMAIN, env.AUTH0_CLI_ID, env.AUTH0_CLI_SECRET,
        env.AUTH0_AUDIENCE, email, password,
      ),
      supabaseCreatePersonalOrg(
        env.SUPABASE_URL, env.SUPABASE_SERVICE_ROLE_KEY, orgName, tier, email,
      ),
    ]);

    // supabaseInsertUser must complete before auth0UserSignIn: org membership has FK on users.id,
    // and if sign-in fails after insert the user record exists and can recover via /signin.
    await supabaseInsertUser(
      env.SUPABASE_URL, env.SUPABASE_SERVICE_ROLE_KEY, userId, auth0Sub, email,
    );
    const jwt = await auth0UserSignIn(
      env.AUTH0_DOMAIN, env.AUTH0_CLIENT_ID, env.AUTH0_CLIENT_SECRET,
      env.AUTH0_AUDIENCE, email, password,
    );

    await supabaseAddOrgOwner(
      env.SUPABASE_URL, env.SUPABASE_SERVICE_ROLE_KEY, orgId, userId,
    );

    return json({ jwt, auth0Sub, userId, email }, { status: HTTP_STATUS.CREATED });
  } catch (err) {
    const msg = err instanceof Error ? err.message : String(err);
    console.error("[signup]", msg);

    let errorCode: ErrorCode = ERROR_CODE.INTERNAL_ERROR;
    if (msg.includes("Auth0 token exchange failed")) {
      errorCode = ERROR_CODE.AUTH0_TOKEN_EXCHANGE_FAILED;
    } else if (msg.includes("Auth0 createUser failed")) {
      errorCode = ERROR_CODE.AUTH0_USER_CREATION_FAILED;
    } else if (msg.includes("Supabase org creation failed")) {
      errorCode = ERROR_CODE.SUPABASE_ORG_CREATION_FAILED;
    } else if (msg.includes("Supabase user insert failed")) {
      errorCode = ERROR_CODE.SUPABASE_USER_INSERT_FAILED;
    } else if (msg.includes("Supabase org membership")) {
      errorCode = ERROR_CODE.SUPABASE_ORG_MEMBERSHIP_FAILED;
    }

    const errorDetail = msg.substring(0, 200);
    const description = ERROR_DESCRIPTIONS[errorCode];
    const responseBody: Record<string, unknown> = { error: "signup failed", code: errorCode, detail: errorDetail };
    if (description) responseBody.description = description;
    return new Response(JSON.stringify(responseBody), {
      status: HTTP_STATUS.INTERNAL_SERVER_ERROR,
      headers: { [HEADER_NAMES.CONTENT_TYPE]: CONTENT_TYPES.JSON },
    });
  }
}

// Key rotation deployment sequence (deploy receiver FIRST):
// 1. Add new key to receiver's SIGNING_KEYS (e.g. { v2: "new-secret" }) and deploy receiver
// 2. Add same key to sender's SIGNING_KEYS and set ACTIVE_KEY_ID="v2", then deploy sender
// 3. Once rotation is verified, remove the old key from both workers' SIGNING_KEYS
//
// If sender is deployed before receiver, the receiver gets an x-key-id it doesn't recognise.
// resolveSigningKey() returns null in three cases (all cause 401 INVALID_SIGNATURE):
//   a) x-key-id present but SIGNING_KEYS env is absent on receiver
//   b) x-key-id present but SIGNING_KEYS JSON is malformed
//   c) x-key-id present but key ID not found in the SIGNING_KEYS map
async function forwardToReceiver(env: Env, payload: Record<string, unknown>): Promise<Response> {
  const ts = Date.now().toString();
  const bodyStr = JSON.stringify(payload);
  const { secret, keyId } = resolveOutboundSigningKey(env);
  const signature = await signMessage(secret, `${ts}.${bodyStr}`);
  const headers: Record<string, string> = {
    [HEADER_NAMES.CONTENT_TYPE]: CONTENT_TYPES.JSON,
    [HEADER_NAMES.TIMESTAMP]: ts,
    [HEADER_NAMES.SIGNATURE]: signature,
  };
  if (keyId) headers[HEADER_NAMES.KEY_ID] = keyId;
  const receiverRes = await env.RECEIVER.fetch(`https://receiver${RECEIVER_PATHS.INBOX}`, {
    method: HTTP_METHODS.POST,
    headers,
    body: bodyStr,
  });
  const receiverBody = await receiverRes.text();
  const contentType = receiverRes.headers.get(HEADER_NAMES.CONTENT_TYPE) ?? CONTENT_TYPES.JSON;
  const enrichedBody = enrichReceiverErrorBody(receiverRes.status, receiverBody, contentType);
  return new Response(enrichedBody, {
    status: receiverRes.status,
    headers: { [HEADER_NAMES.CONTENT_TYPE]: contentType },
  });
}

/**
 * On non-2xx JSON responses from the receiver, attach an ERROR_DESCRIPTIONS entry when the
 * receiver's `code` matches a known value. Leaves the body untouched if parsing fails, the
 * status is 2xx, the code is absent/unknown, or a description is already present.
 */
function enrichReceiverErrorBody(status: number, body: string, contentType: string): string {
  if (status < HTTP_STATUS.BAD_REQUEST) return body;
  if (!contentType.includes("application/json")) return body;
  let parsed: unknown;
  try {
    parsed = JSON.parse(body);
  } catch {
    return body;
  }
  if (typeof parsed !== "object" || parsed === null || Array.isArray(parsed)) return body;
  const obj = parsed as Record<string, unknown>;
  if (typeof obj.code !== "string" || obj.description !== undefined) return body;
  const description = ERROR_DESCRIPTIONS[obj.code as ErrorCode];
  if (!description) return body;
  obj.description = description;
  return JSON.stringify(obj);
}

async function handleSignIn(env: Env, req: Record<string, unknown>): Promise<Response> {
  if (!env.AUTH0_DOMAIN || !env.AUTH0_CLIENT_ID || !env.AUTH0_CLIENT_SECRET || !env.AUTH0_AUDIENCE) {
    return errorResponse("Auth0 not configured", ERROR_CODE.AUTH0_UNCONFIGURED, HTTP_STATUS.INTERNAL_SERVER_ERROR);
  }
  if (!req.email || !req.password) {
    return errorResponse("missing email or password", ERROR_CODE.MISSING_FIELDS, HTTP_STATUS.BAD_REQUEST);
  }
  if (!EMAIL_REGEX.test(req.email as string)) {
    return errorResponse("invalid email format", ERROR_CODE.INVALID_EMAIL, HTTP_STATUS.BAD_REQUEST);
  }
  try {
    const jwt = await auth0UserSignIn(
      env.AUTH0_DOMAIN, env.AUTH0_CLIENT_ID, env.AUTH0_CLIENT_SECRET,
      env.AUTH0_AUDIENCE, req.email as string, req.password as string,
    );
    return json({ jwt, email: req.email });
  } catch (err) {
    const msg = err instanceof Error ? err.message : String(err);
    console.error("[signin]", msg);
    return errorResponse("signin failed", ERROR_CODE.INTERNAL_ERROR, HTTP_STATUS.INTERNAL_SERVER_ERROR);
  }
}

async function handleSend(env: Env, req: Record<string, unknown>): Promise<Response> {
  if (!env.RECEIVER) {
    return errorResponse("RECEIVER service binding not configured", ERROR_CODE.INTERNAL_ERROR, HTTP_STATUS.INTERNAL_SERVER_ERROR);
  }
  if (!env.SHARED_SECRET) {
    return errorResponse("SHARED_SECRET not configured", ERROR_CODE.INTERNAL_ERROR, HTTP_STATUS.INTERNAL_SERVER_ERROR);
  }

  const parsed = SendRequestSchema.safeParse(req);
  if (!parsed.success) {
    const field = parsed.error.issues[0].path[0];
    if (field === "action") {
      return errorResponse("unknown action", ERROR_CODE.UNKNOWN_ACTION, HTTP_STATUS.BAD_REQUEST);
    }
    if (field === "jwt") {
      return errorResponse("invalid or expired jwt", ERROR_CODE.INVALID_AUTH, HTTP_STATUS.UNAUTHORIZED);
    }
    const code = field === "email" ? ERROR_CODE.INVALID_EMAIL : ERROR_CODE.MISSING_FIELDS;
    return errorResponse(`invalid ${String(field)}`, code, HTTP_STATUS.BAD_REQUEST);
  }

  const data = parsed.data;
  try {
    const outbound: Record<string, unknown> = data.action === "sign_in"
      ? { action: data.action, jwt: data.jwt, email: data.email }
      : {
          action: data.action,
          jwt: data.jwt,
          name: data.name,
          email: data.email,
          tier: data.tier,
          org_name: data.org_name,
        };
    return await forwardToReceiver(env, outbound);
  } catch (err) {
    if (err instanceof TypeError) {
      return errorResponse("receiver-worker unreachable", ERROR_CODE.INTERNAL_ERROR, HTTP_STATUS.BAD_GATEWAY);
    }
    console.error("[send]", err instanceof Error ? err.message : err);
    return errorResponse("send failed", ERROR_CODE.INTERNAL_ERROR, HTTP_STATUS.INTERNAL_SERVER_ERROR);
  }
}

async function handleCreateCheckoutSession(env: Env, req: Record<string, unknown>): Promise<Response> {
  if (!env.STRIPE_SECRET_KEY) {
    return errorResponse("Stripe not configured", ERROR_CODE.INTERNAL_ERROR, HTTP_STATUS.INTERNAL_SERVER_ERROR);
  }

  const parsed = CreateCheckoutSessionSchema.safeParse(req);
  if (!parsed.success) {
    const field = parsed.error.issues[0].path[0];
    const code = field === "email" ? ERROR_CODE.INVALID_EMAIL : ERROR_CODE.MISSING_FIELDS;
    return errorResponse(`invalid ${String(field)}`, code, HTTP_STATUS.BAD_REQUEST);
  }

  const { email, tier } = parsed.data;
  const planToPriceJson = env.STRIPE_PLAN_TO_PRICE_JSON ?? "{}";
  const appBaseUrl = env.APP_BASE_URL ?? DEFAULT_APP_BASE_URL;

  const result = await createStripeCheckoutSession(
    env.STRIPE_SECRET_KEY,
    planToPriceJson,
    appBaseUrl,
    email,
    tier,
  );

  if (!result.ok) {
    return errorResponse(result.error, ERROR_CODE.INTERNAL_ERROR, HTTP_STATUS.INTERNAL_SERVER_ERROR);
  }

  return json({ checkoutUrl: result.checkoutUrl });
}

// x-session-data is base64-wrapped to avoid WAF JWT pattern matching on the header value.
function extractJwt(request: Request, body: Record<string, unknown>): string | undefined {
  const sessionData = request.headers.get("x-session-data");
  if (sessionData) {
    try { return atob(sessionData); } catch { return sessionData; }
  }
  if (body.jwt) return body.jwt as string;
  const authHeader = request.headers.get(HEADER_NAMES.AUTHORIZATION);
  if (authHeader?.startsWith("Bearer ")) return authHeader.slice(7);
  return undefined;
}

async function parseJsonBody(request: Request): Promise<Record<string, unknown> | Response> {
  try {
    return await request.json() as Record<string, unknown>;
  } catch {
    return errorResponse("invalid json", ERROR_CODE.JSON_PARSE_ERROR, HTTP_STATUS.BAD_REQUEST);
  }
}

async function routeRequest(request: Request, env: Env): Promise<Response> {
  const url = new URL(request.url);

  if (request.method === HTTP_METHODS.GET && url.pathname === ROUTES.HEALTH) {
    return json({
      ok: true,
      service: SERVICE_NAME,
      version: VERSION,
      timestamp: new Date().toISOString(),
    });
  }

  if (request.method === HTTP_METHODS.POST && url.pathname === ROUTES.SIGNUP) {
    const body = await parseJsonBody(request);
    if (body instanceof Response) return body;
    return handleSignup(env, body);
  }

  if (request.method === HTTP_METHODS.POST && url.pathname === ROUTES.SIGNIN) {
    const body = await parseJsonBody(request);
    if (body instanceof Response) return body;
    return handleSignIn(env, body);
  }

  if (request.method === HTTP_METHODS.POST && url.pathname === ROUTES.SEND) {
    const body = await parseJsonBody(request);
    if (body instanceof Response) return body;
    body.jwt = extractJwt(request, body);
    return handleSend(env, body);
  }

  if (request.method === HTTP_METHODS.POST && url.pathname === ROUTES.CREATE_CHECKOUT_SESSION) {
    const body = await parseJsonBody(request);
    if (body instanceof Response) return body;
    return handleCreateCheckoutSession(env, body);
  }

  return errorResponse("not found", ERROR_CODE.NOT_FOUND, HTTP_STATUS.NOT_FOUND);
}

function withSecurityHeaders(res: Response): Response {
  const headers = new Headers(res.headers);
  headers.set("X-Content-Type-Options", "nosniff");
  headers.set("Cache-Control", "no-store");
  return new Response(res.body, { status: res.status, statusText: res.statusText, headers });
}

export default {
  async fetch(request: Request, env: Env): Promise<Response> {
    const origin = request.headers.get("origin");
    const originAllowed = origin !== null && isOriginAllowed(origin, env);

    if (request.method === HTTP_METHODS.OPTIONS) {
      const headers: Record<string, string> = { ...CORS_HEADERS };
      if (originAllowed) {
        headers["access-control-allow-origin"] = origin;
      }
      return new Response(null, { status: HTTP_STATUS.NO_CONTENT, headers });
    }

    if (origin !== null && !originAllowed) {
      return withSecurityHeaders(errorResponse("forbidden", ERROR_CODE.FORBIDDEN, HTTP_STATUS.FORBIDDEN));
    }

    const res = await routeRequest(request, env);

    if (originAllowed) {
      const secured = withSecurityHeaders(res);
      const headers = new Headers(secured.headers);
      headers.set("access-control-allow-origin", origin);
      return new Response(secured.body, { status: secured.status, statusText: secured.statusText, headers });
    }

    return withSecurityHeaders(res);
  },
};
