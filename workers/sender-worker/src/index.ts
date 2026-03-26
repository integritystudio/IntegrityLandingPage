import {
  ROUTES,
  HTTP_METHODS,
  HTTP_STATUS,
  ERROR_CODE,
  HEADER_NAMES,
  CONTENT_TYPES,
  RECEIVER_PATHS,
  SERVICE_NAME,
  type Env,
} from "./types.js";
import { json, errorResponse, corsPreflightResponse } from "./utils.js";
import { signMessage } from "./crypto.js";
import {
  supabaseAdminCreateUser,
  supabaseCreatePersonalOrg,
  supabaseInsertUser,
  supabaseSignIn,
} from "./supabase.js";
import { VERSION } from "./version.js";

const EMAIL_REGEX = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;

async function handleSignup(env: Env, req: Record<string, unknown>): Promise<Response> {
  if (!req.email || !req.password) {
    return errorResponse("missing email or password", ERROR_CODE.MISSING_FIELDS, HTTP_STATUS.BAD_REQUEST);
  }
  if (!EMAIL_REGEX.test(req.email as string)) {
    return errorResponse("invalid email format", ERROR_CODE.MISSING_FIELDS, HTTP_STATUS.BAD_REQUEST);
  }
  try {
    const { userId } = await supabaseAdminCreateUser(
      env.SUPABASE_URL,
      env.SUPABASE_SERVICE_ROLE_KEY,
      req.email as string,
      req.password as string,
    );
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
      req.email as string,
      organizationId,
    );
    const signInResult = await supabaseSignIn(
      env.SUPABASE_URL,
      env.SUPABASE_ANON_KEY,
      req.email as string,
      req.password as string,
    );
    return json(
      { jwt: signInResult.jwt, userId: signInResult.userId, email: req.email },
      { status: HTTP_STATUS.CREATED },
    );
  } catch (err) {
    const msg = err instanceof Error ? err.message : String(err);
    console.error("[signup]", msg);
    return errorResponse(`signup failed: ${msg}`, ERROR_CODE.INTERNAL_ERROR, HTTP_STATUS.INTERNAL_SERVER_ERROR);
  }
}

async function handleSignin(env: Env, req: Record<string, unknown>): Promise<Response> {
  if (!req.email || !req.password) {
    return errorResponse("missing email or password", ERROR_CODE.MISSING_FIELDS, HTTP_STATUS.BAD_REQUEST);
  }
  if (!EMAIL_REGEX.test(req.email as string)) {
    return errorResponse("invalid email format", ERROR_CODE.MISSING_FIELDS, HTTP_STATUS.BAD_REQUEST);
  }
  try {
    const result = await supabaseSignIn(
      env.SUPABASE_URL,
      env.SUPABASE_ANON_KEY,
      req.email as string,
      req.password as string,
    );
    return json({ jwt: result.jwt, userId: result.userId, email: req.email });
  } catch (err) {
    console.error("[signin]", err instanceof Error ? err.message : err);
    return errorResponse("signin failed", ERROR_CODE.INTERNAL_ERROR, HTTP_STATUS.INTERNAL_SERVER_ERROR);
  }
}

async function handleSend(env: Env, req: Record<string, unknown>): Promise<Response> {
  if (!req.action || !req.jwt) {
    return errorResponse("missing action or jwt", ERROR_CODE.MISSING_FIELDS, HTTP_STATUS.BAD_REQUEST);
  }
  try {
    const ts = Date.now().toString();
    const bodyStr = JSON.stringify(req);
    const message = `${ts}.${bodyStr}`;
    const signature = await signMessage(env.SHARED_SECRET, message);
    const receiverRes = await env.PROVISIONING_RECEIVER.fetch(
      new Request(`https://internal${RECEIVER_PATHS.INBOX}`, {
        method: HTTP_METHODS.POST,
        headers: {
          [HEADER_NAMES.CONTENT_TYPE]: CONTENT_TYPES.JSON,
          [HEADER_NAMES.TIMESTAMP]: ts,
          [HEADER_NAMES.SIGNATURE]: signature,
        },
        body: bodyStr,
      }),
    );
    if (!receiverRes.ok) {
      const errorMsg = `Receiver returned ${receiverRes.status}`;
      return errorResponse(errorMsg, ERROR_CODE.RECEIVER_ERROR, HTTP_STATUS.INTERNAL_SERVER_ERROR);
    }
    const receiverBody = await receiverRes.json();
    return json({ ok: true, ...(receiverBody as object) });
  } catch (err) {
    console.error("[send]", err instanceof Error ? err.message : err);
    return errorResponse("send failed", ERROR_CODE.INTERNAL_ERROR, HTTP_STATUS.INTERNAL_SERVER_ERROR);
  }
}

async function routeRequest(request: Request, env: Env): Promise<Response> {
  const url = new URL(request.url);

  if (request.method === HTTP_METHODS.OPTIONS) {
    return corsPreflightResponse();
  }

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
    const res = await routeRequest(request, env);
    if (!env.CORS_ORIGIN) return res;
    const headers = new Headers(res.headers);
    headers.set("access-control-allow-origin", env.CORS_ORIGIN);
    return new Response(res.body, { status: res.status, headers });
  },
};
