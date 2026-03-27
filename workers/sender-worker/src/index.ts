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
  ACTIONS,
  VALID_TIERS,
  DEFAULT_TIER,
  type ApiKeyTier,
  type Env,
} from "./types.js";
import { json, errorResponse } from "./utils.js";
import { signMessage } from "./crypto.js";
import {
  auth0CreateUser,
  supabaseCreatePersonalOrg,
  supabaseAddOrgOwner,
  supabaseInsertUser,
} from "./supabase.js";
import { VERSION } from "./version.js";

const EMAIL_REGEX = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;

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
  try {
    const { auth0Sub } = await auth0CreateUser(
      env.AUTH0_DOMAIN,
      env.AUTH0_CLIENT_ID,
      env.AUTH0_CLIENT_SECRET,
      env.AUTH0_AUDIENCE,
      req.email as string,
      req.password as string,
    );
    // Generate a UUID for the Supabase users.id column (separate from the Auth0 sub)
    const userId = crypto.randomUUID();
    const { organizationId } = await supabaseCreatePersonalOrg(
      env.SUPABASE_URL,
      env.SUPABASE_SERVICE_ROLE_KEY,
      userId,
      req.email as string,
    );
    await supabaseInsertUser(
      env.SUPABASE_URL,
      env.SUPABASE_SERVICE_ROLE_KEY,
      userId,
      auth0Sub,
      req.email as string,
      organizationId,
    );
    await supabaseAddOrgOwner(
      env.SUPABASE_URL,
      env.SUPABASE_SERVICE_ROLE_KEY,
      organizationId,
      userId,
    );
    return json(
      { auth0Sub, userId, email: req.email },
      { status: HTTP_STATUS.CREATED },
    );
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
  if (!env.RECEIVER_WORKER_URL) {
    return errorResponse("RECEIVER_WORKER_URL not configured", ERROR_CODE.INTERNAL_ERROR, HTTP_STATUS.INTERNAL_SERVER_ERROR);
  }
  if (!env.SHARED_SECRET) {
    return errorResponse("SHARED_SECRET not configured", ERROR_CODE.INTERNAL_ERROR, HTTP_STATUS.INTERNAL_SERVER_ERROR);
  }

  // Validate action
  if (req.action !== ACTIONS.PROVISION_API_KEY) {
    return errorResponse(`unknown action: ${req.action}`, ERROR_CODE.UNKNOWN_ACTION, HTTP_STATUS.BAD_REQUEST);
  }

  // Validate provision_api_key required fields
  if (!req.jwt || typeof req.jwt !== "string") {
    return errorResponse("missing or invalid jwt", ERROR_CODE.INVALID_AUTH, HTTP_STATUS.BAD_REQUEST);
  }
  if (!req.name || typeof req.name !== "string") {
    return errorResponse("missing name", ERROR_CODE.MISSING_FIELDS, HTTP_STATUS.BAD_REQUEST);
  }
  if (!req.email || typeof req.email !== "string") {
    return errorResponse("missing email", ERROR_CODE.MISSING_FIELDS, HTTP_STATUS.BAD_REQUEST);
  }
  if (!EMAIL_REGEX.test(req.email)) {
    return errorResponse("invalid email format", ERROR_CODE.INVALID_EMAIL, HTTP_STATUS.BAD_REQUEST);
  }

  // Normalize tier: default to starter if absent or invalid
  const tier: ApiKeyTier = (VALID_TIERS as readonly string[]).includes(req.tier as string)
    ? (req.tier as ApiKeyTier)
    : DEFAULT_TIER;

  // Build the normalized payload the receiver expects
  const payload: Record<string, unknown> = {
    action: req.action,
    email: req.email,
    jwt: req.jwt,
    name: req.name,
    tier,
  };
  if (req.org_name && typeof req.org_name === "string") {
    payload["org_name"] = req.org_name;
  }

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
    return new Response(receiverBody, {
      status: receiverRes.status,
      headers: { [HEADER_NAMES.CONTENT_TYPE]: CONTENT_TYPES.JSON },
    });
  } catch (err) {
    if (err instanceof TypeError) {
      return errorResponse("receiver-worker unreachable", ERROR_CODE.INTERNAL_ERROR, HTTP_STATUS.BAD_GATEWAY);
    }
    console.error("[send]", err instanceof Error ? err.message : err);
    return errorResponse("send failed", ERROR_CODE.INTERNAL_ERROR, HTTP_STATUS.INTERNAL_SERVER_ERROR);
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

  return errorResponse("not found", ERROR_CODE.NOT_FOUND, HTTP_STATUS.NOT_FOUND);
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
      return errorResponse("forbidden", ERROR_CODE.FORBIDDEN, HTTP_STATUS.FORBIDDEN);
    }

    const res = await routeRequest(request, env);

    if (originAllowed) {
      const headers = new Headers(res.headers);
      headers.set("access-control-allow-origin", origin);
      return new Response(res.body, { status: res.status, headers });
    }

    return res;
  },
};
