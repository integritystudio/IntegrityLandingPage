import {
  ROUTES,
  HTTP_METHODS,
  HTTP_STATUS,
  ERROR_CODE,
  ERROR_DESCRIPTIONS,
  HEADER_NAMES,
  CONTENT_TYPES,
  CORS_ALLOW_METHODS,
  CORS_ALLOW_HEADERS,
  RECEIVER_PATHS,
  SERVICE_NAME,
  SendRequestSchema,
  CreateCheckoutSessionSchema,
  DEFAULT_APP_BASE_URL,
  type ErrorCode,
  type Env,
} from "./types.js";
import { json } from "../../lib/http/responses.js";
import { buildCors } from "../../lib/http/cors.js";
import { errorResponse, resolveOutboundSigningKey, getClientIp } from "./utils.js";
import { signMessage } from "./crypto.js";
import { supabaseFindOrgIdByEmail } from "./supabase.js";
import { createStripeCheckoutSession } from "./stripe.js";
import { VERSION } from "./version.js";


// Cloudflare Pages preview deployments for the integritystudio-ai project are served at
// https://<deploy-hash>.integritystudio-ai-c1a.pages.dev (and named-branch aliases). These
// hostnames are owned exclusively by this account's Pages project, so matching the suffix is
// safe and lets preview builds exercise the live sender without per-deploy ALLOWED_ORIGINS_JSON
// edits. The shared helper anchors on the leading dot (the bare alias and lookalike hosts such
// as `…pages.dev.attacker.com` do not match) and accepts only https origins.
const PAGES_PREVIEW_HOST_SUFFIX = ".integritystudio-ai-c1a.pages.dev";

/** CORS decision for this Worker: the shared allowlist plus Pages previews; an unlisted origin gets no Allow-Origin. */
function senderCors(origin: string | null, env: Env) {
  return buildCors(origin, {
    allowedOriginsJson: env.ALLOWED_ORIGINS_JSON,
    previewHostSuffix: PAGES_PREVIEW_HOST_SUFFIX,
    allowMethods: CORS_ALLOW_METHODS,
    allowHeaders: CORS_ALLOW_HEADERS,
  });
}

// Key rotation deployment sequence (deploy receiver FIRST):
// 1. Add new key to receiver's SIGNING_KEYS (e.g. { v2: "new-secret" }) and deploy receiver
// 2. Add same key to sender's SIGNING_KEYS and set ACTIVE_KEY_ID="v2", then deploy sender
// 3. Once rotation is verified, remove the old key from both workers' SIGNING_KEYS
//
// If sender is deployed before receiver, the receiver gets an x-key-id it doesn't recognise and
// rejects it with 401 INVALID_SIGNATURE — from `auth.key_unresolved` in the receiver's audit log,
// which is the event that distinguishes a rejected key id from a genuine signature mismatch (the
// two 401s are byte-identical by design, so key ids cannot be enumerated by diffing responses).
//
// This sender never signs with a key the operator did not choose, and never signs keylessly:
// any ACTIVE_KEY_ID/SIGNING_KEYS configuration that does not resolve fails with a 500 instead of
// downgrading to SHARED_SECRET. See resolveOutboundSigningKey and BACKLOG.md CR29.
async function forwardToReceiver(
  env: Env,
  payload: Record<string, unknown>,
  clientIp?: string,
): Promise<Response> {
  const key = resolveOutboundSigningKey(env);
  if (key.secret === null) {
    // The miss reason is logged by the resolver, not returned: a caller learns only that the
    // worker is misconfigured, never which key id the operator meant to use.
    return errorResponse(
      "Signing key unavailable",
      ERROR_CODE.SIGNING_KEY_UNRESOLVED,
      HTTP_STATUS.INTERNAL_SERVER_ERROR,
    );
  }
  const { secret, keyId } = key;
  const ts = Date.now().toString();
  const bodyStr = JSON.stringify(payload);
  const signature = await signMessage(secret, `${ts}.${bodyStr}`);
  const headers: Record<string, string> = {
    [HEADER_NAMES.CONTENT_TYPE]: CONTENT_TYPES.JSON,
    [HEADER_NAMES.TIMESTAMP]: ts,
    [HEADER_NAMES.SIGNATURE]: signature,
  };
  // Unconditional: a resolved key always has an id, and the receiver rejects a request without
  // one (CR29 step 2). The old `if (keyId)` guard was the sender half of the keyless path.
  headers[HEADER_NAMES.KEY_ID] = keyId;
  // Service-binding subrequests don't inherit the client's CF-Connecting-IP;
  // forward it so the receiver's per-IP metrics see the real caller, not "unknown".
  if (clientIp) headers[HEADER_NAMES.X_FORWARDED_FOR] = clientIp;
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

async function handleSend(env: Env, req: Record<string, unknown>, clientIp?: string): Promise<Response> {
  if (!env.RECEIVER) {
    return errorResponse("RECEIVER service binding not configured", ERROR_CODE.INTERNAL_ERROR, HTTP_STATUS.INTERNAL_SERVER_ERROR);
  }
  // No signing-credential pre-flight here on purpose. It used to check
  // `!env.SHARED_SECRET && !env.ACTIVE_KEY_ID`, which after CR29 step 2 is the wrong question
  // twice over: SHARED_SECRET is no longer read at all, and ACTIVE_KEY_ID being *present* says
  // nothing about whether it resolves. forwardToReceiver is the single authority — it fails
  // closed with SIGNING_KEY_UNRESOLVED, a code that names the actual fault, where this returned
  // a misleading "SHARED_SECRET not configured". Two 500s for one condition is worse than one.
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
          org_name: data.org_name,
        };
    return await forwardToReceiver(env, outbound, clientIp);
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

  // Attribute the checkout to an org so stripe-webhook can link the Stripe
  // customer on checkout.session.completed. Best-effort by design: a lookup
  // failure or an unknown email must not block a sale, so we log and continue
  // with an unattributed session rather than returning an error.
  let orgId: string | null = null;
  try {
    orgId = await supabaseFindOrgIdByEmail(env.SUPABASE_URL, env.SUPABASE_SERVICE_ROLE_KEY, email);
    if (!orgId) {
      console.warn("[checkout] no org resolved for", email, "— subscription will not be linked to an organization");
    }
  } catch (err) {
    console.error("[checkout] org lookup failed:", err instanceof Error ? err.message : err);
  }

  let result: Awaited<ReturnType<typeof createStripeCheckoutSession>>;
  try {
    result = await createStripeCheckoutSession(
      env.STRIPE_SECRET_KEY,
      planToPriceJson,
      appBaseUrl,
      email,
      tier,
      orgId,
    );
  } catch (err) {
    console.error("[checkout] Stripe network error:", err instanceof Error ? err.message : err);
    return errorResponse("checkout service unavailable", ERROR_CODE.INTERNAL_ERROR, HTTP_STATUS.INTERNAL_SERVER_ERROR);
  }

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

  if (request.method === HTTP_METHODS.POST && url.pathname === ROUTES.SEND) {
    const body = await parseJsonBody(request);
    if (body instanceof Response) return body;
    body.jwt = extractJwt(request, body);
    return handleSend(env, body, getClientIp(request));
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
    const cors = senderCors(origin, env);

    if (request.method === HTTP_METHODS.OPTIONS) {
      return new Response(null, { status: HTTP_STATUS.NO_CONTENT, headers: cors.headers });
    }

    if (origin !== null && !cors.allowed) {
      return withSecurityHeaders(errorResponse("forbidden", ERROR_CODE.FORBIDDEN, HTTP_STATUS.FORBIDDEN));
    }

    const res = await routeRequest(request, env);

    if (cors.allowed) {
      const secured = withSecurityHeaders(res);
      const headers = new Headers(secured.headers);
      for (const [name, value] of Object.entries(cors.headers)) headers.set(name, value);
      return new Response(secured.body, { status: secured.status, statusText: secured.statusText, headers });
    }

    return withSecurityHeaders(res);
  },
};
