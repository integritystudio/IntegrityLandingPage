import {
  ROUTES,
  HTTP_METHODS,
  HTTP_STATUS,
  ERROR_CODE,
  HEADER_NAMES,
  CONTENT_TYPES,
  CORS_HEADERS,
  RECEIVER_PATHS,
  SERVICE_NAME,
  EMAIL_REGEX,
  ActionSchema,
  ApiKeyTierSchema,
  DEFAULT_TIER,
  SendRequestSchema,
  CreateCheckoutSessionSchema,
  DEFAULT_APP_BASE_URL,
  type ApiKeyTier,
  type ErrorCode,
  type Env,
} from "./types.js";
import { json, errorResponse, resolveOutboundSigningKey } from "./utils.js";
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

function isOriginAllowed(origin: string, env: Env): boolean {
  return getAllowedOrigins(env).includes(origin);
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

    // Insert user first — org membership has FK on users.id
    const [jwt] = await Promise.all([
      auth0UserSignIn(
        env.AUTH0_DOMAIN, env.AUTH0_CLIENT_ID, env.AUTH0_CLIENT_SECRET,
        env.AUTH0_AUDIENCE, email, password,
      ),
      supabaseInsertUser(
        env.SUPABASE_URL, env.SUPABASE_SERVICE_ROLE_KEY, userId, auth0Sub, email,
      ),
    ]);

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
    return new Response(JSON.stringify({ error: "signup failed", code: errorCode, detail: errorDetail }), {
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
  return new Response(receiverBody, {
    status: receiverRes.status,
    headers: { [HEADER_NAMES.CONTENT_TYPE]: contentType },
  });
}

async function handleSignIn(env: Env, req: Record<string, unknown>): Promise<Response> {
  if (!env.RECEIVER) {
    return errorResponse("RECEIVER service binding not configured", ERROR_CODE.INTERNAL_ERROR, HTTP_STATUS.INTERNAL_SERVER_ERROR);
  }
  if (!env.SHARED_SECRET) {
    return errorResponse("SHARED_SECRET not configured", ERROR_CODE.INTERNAL_ERROR, HTTP_STATUS.INTERNAL_SERVER_ERROR);
  }
  if (!req.email || typeof req.email !== "string") {
    return errorResponse("invalid email", ERROR_CODE.INVALID_EMAIL, HTTP_STATUS.BAD_REQUEST);
  }
  try {
    return await forwardToReceiver(env, { action: ActionSchema.enum.sign_in, email: req.email });
  } catch (err) {
    if (err instanceof TypeError) {
      return errorResponse("receiver-worker unreachable", ERROR_CODE.INTERNAL_ERROR, HTTP_STATUS.BAD_GATEWAY);
    }
    console.error("[sign_in]", err instanceof Error ? err.message : err);
    return errorResponse("sign_in failed", ERROR_CODE.INTERNAL_ERROR, HTTP_STATUS.INTERNAL_SERVER_ERROR);
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

  const { action, jwt, name, email, tier, org_name } = parsed.data;
  try {
    return await forwardToReceiver(env, { action, email, jwt, name, tier, org_name });
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
