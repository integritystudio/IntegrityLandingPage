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
  ApiKeyTierSchema,
  DEFAULT_TIER,
  SendRequestSchema,
  CreateCheckoutSessionSchema,
  type ApiKeyTier,
  type Env,
} from "./types.js";
import { json, errorResponse } from "./utils.js";
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
    const { auth0Sub } = await auth0CreateUser(
      env.AUTH0_DOMAIN, env.AUTH0_CLIENT_ID, env.AUTH0_CLIENT_SECRET,
      env.AUTH0_AUDIENCE, email, password,
    );

    const userId = crypto.randomUUID();

    const orgId = await supabaseCreatePersonalOrg(
      env.SUPABASE_URL, env.SUPABASE_SERVICE_ROLE_KEY, orgName, tier,
    );

    await supabaseInsertUser(
      env.SUPABASE_URL, env.SUPABASE_SERVICE_ROLE_KEY, userId, auth0Sub, email,
    );

    await supabaseAddOrgOwner(
      env.SUPABASE_URL, env.SUPABASE_SERVICE_ROLE_KEY, orgId, userId,
    );

    const jwt = await auth0UserSignIn(
      env.AUTH0_DOMAIN, env.AUTH0_CLIENT_ID, env.AUTH0_CLIENT_SECRET,
      env.AUTH0_AUDIENCE, email, password,
    );

    return json({ jwt, auth0Sub, userId, email }, { status: HTTP_STATUS.CREATED });
  } catch (err) {
    const msg = err instanceof Error ? err.message : String(err);
    console.error("[signup]", msg);
    return errorResponse("signup failed", ERROR_CODE.INTERNAL_ERROR, HTTP_STATUS.INTERNAL_SERVER_ERROR);
  }
}

// Sign-in is handled by Auth0 directly; this route is intentionally not implemented.
function handleSignin(_env: Env, _req: Record<string, unknown>): Response {
  return errorResponse("sign-in is handled by Auth0", ERROR_CODE.NOT_FOUND, HTTP_STATUS.NOT_FOUND);
}

async function handleSend(env: Env, req: Record<string, unknown>): Promise<Response> {
  try {
    new URL(env.RECEIVER_WORKER_URL);
  } catch {
    return errorResponse("RECEIVER_WORKER_URL not configured", ERROR_CODE.INTERNAL_ERROR, HTTP_STATUS.INTERNAL_SERVER_ERROR);
  }
  if (!env.SHARED_SECRET) {
    return errorResponse("SHARED_SECRET not configured", ERROR_CODE.INTERNAL_ERROR, HTTP_STATUS.INTERNAL_SERVER_ERROR);
  }

  const parsed = SendRequestSchema.safeParse(req);
  if (!parsed.success) {
    const field = parsed.error.issues[0]?.path[0] ?? "request";
    if (field === "action") {
      return errorResponse("unknown action", ERROR_CODE.UNKNOWN_ACTION, HTTP_STATUS.BAD_REQUEST);
    }
    if (field === "jwt") {
      return errorResponse("invalid or expired jwt", ERROR_CODE.INVALID_AUTH, HTTP_STATUS.UNAUTHORIZED);
    }
    const code = field === "email" ? ERROR_CODE.INVALID_EMAIL : ERROR_CODE.MISSING_FIELDS;
    return errorResponse(`invalid ${field}`, code, HTTP_STATUS.BAD_REQUEST);
  }

  const { action, jwt, name, email, tier, org_name } = parsed.data;
  const payload: Record<string, unknown> = { action, email, jwt, name, tier, org_name };

  try {
    const ts = Date.now().toString();
    const bodyStr = JSON.stringify(payload);
    const signature = await signMessage(env.SHARED_SECRET, `${ts}.${bodyStr}`);
    const receiverRes = await fetch(`${env.RECEIVER_WORKER_URL}${RECEIVER_PATHS.INBOX}`, {
      method: HTTP_METHODS.POST,
      headers: {
        [HEADER_NAMES.CONTENT_TYPE]: CONTENT_TYPES.JSON,
        [HEADER_NAMES.TIMESTAMP]: ts,
        [HEADER_NAMES.SIGNATURE]: signature,
      },
      body: bodyStr,
    });
    const receiverBody = await receiverRes.text();
    const contentType = receiverRes.headers.get(HEADER_NAMES.CONTENT_TYPE) ?? CONTENT_TYPES.JSON;
    return new Response(receiverBody, {
      status: receiverRes.status,
      headers: { [HEADER_NAMES.CONTENT_TYPE]: contentType },
    });
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
    const field = parsed.error.issues[0]?.path[0] ?? "request";
    const code = field === "email" ? ERROR_CODE.INVALID_EMAIL : ERROR_CODE.MISSING_FIELDS;
    return errorResponse(`invalid ${String(field)}`, code, HTTP_STATUS.BAD_REQUEST);
  }

  const { email, tier } = parsed.data;
  const planToPriceJson = env.STRIPE_PLAN_TO_PRICE_JSON ?? "{}";
  const appBaseUrl = env.APP_BASE_URL ?? "https://integritystudio.ai";

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
    let req: Record<string, unknown>;
    try {
      req = await request.json();
    } catch {
      return errorResponse("invalid json", ERROR_CODE.JSON_PARSE_ERROR, HTTP_STATUS.BAD_REQUEST);
    }
    return handleSignup(env, req);
  }

  if (request.method === HTTP_METHODS.POST && url.pathname === ROUTES.SIGNIN) {
    let req: Record<string, unknown>;
    try {
      req = await request.json();
    } catch {
      return errorResponse("invalid json", ERROR_CODE.JSON_PARSE_ERROR, HTTP_STATUS.BAD_REQUEST);
    }
    return handleSignin(env, req);
  }

  if (request.method === HTTP_METHODS.POST && url.pathname === ROUTES.SEND) {
    let req: Record<string, unknown>;
    try {
      req = await request.json();
    } catch {
      return errorResponse("invalid json", ERROR_CODE.JSON_PARSE_ERROR, HTTP_STATUS.BAD_REQUEST);
    }
    return handleSend(env, req);
  }

  if (request.method === HTTP_METHODS.POST && url.pathname === ROUTES.CREATE_CHECKOUT_SESSION) {
    let req: Record<string, unknown>;
    try {
      req = await request.json();
    } catch {
      return errorResponse("invalid json", ERROR_CODE.JSON_PARSE_ERROR, HTTP_STATUS.BAD_REQUEST);
    }
    return handleCreateCheckoutSession(env, req);
  }

  return errorResponse("not found", ERROR_CODE.NOT_FOUND, HTTP_STATUS.NOT_FOUND);
}

/** V-22: Add security headers to all API responses. */
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
      const headers = new Headers(res.headers);
      headers.set("access-control-allow-origin", origin);
      headers.set("X-Content-Type-Options", "nosniff");
      headers.set("Cache-Control", "no-store");
      return new Response(res.body, { status: res.status, headers });
    }

    return withSecurityHeaders(res);
  },
};
