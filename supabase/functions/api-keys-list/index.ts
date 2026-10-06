import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { createClient } from "jsr:@supabase/supabase-js@2";
import * as jose from "npm:jose@5";

const CORS_HEADERS = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "GET, OPTIONS",
};

function jsonResponse(body: Record<string, unknown>, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { "Content-Type": "application/json", ...CORS_HEADERS },
  });
}

function errorResponse(message: string, status: number): Response {
  return jsonResponse({ error: message }, status);
}

/**
 * Verify the bearer JWT against the Auth0 tenant's JWKS and return its `sub`.
 *
 * Callers present Auth0 access tokens (RS256, issued by AUTH0_DOMAIN for
 * AUTH0_AUDIENCE) and `sub` is the Auth0 subject stored in `users.auth0_id`;
 * Supabase accepts them through Third-Party Auth, so the project's own JWT
 * secret never signs them. This replaces the previous `atob`-based read, which
 * decoded the payload without verifying the signature and was safe only while
 * `verify_jwt = true` made the platform verify the token first — a fragile,
 * deployment-dependent guarantee. Verifying here means the function is safe
 * regardless of how it is deployed.
 *
 * The JWKS object is module-level so jose's key cache survives across requests
 * in the same isolate.
 */
let jwks: ReturnType<typeof jose.createRemoteJWKSet> | undefined;

function getJwks(domain: string): ReturnType<typeof jose.createRemoteJWKSet> {
  jwks ??= jose.createRemoteJWKSet(new URL(`https://${domain}/.well-known/jwks.json`));
  return jwks;
}

async function verifyAndGetSub(
  req: Request,
  auth0: { domain: string; audience: string },
): Promise<string | null> {
  const auth = req.headers.get("authorization");
  if (!auth?.startsWith("Bearer ")) return null;
  const token = auth.slice("Bearer ".length).trim();
  try {
    const { payload } = await jose.jwtVerify(token, getJwks(auth0.domain), {
      issuer: `https://${auth0.domain}/`,
      audience: auth0.audience,
    });
    return typeof payload.sub === "string" ? payload.sub : null;
  } catch {
    return null;
  }
}

Deno.serve(async (req: Request) => {
  if (req.method === "OPTIONS") {
    return new Response(null, { status: 204, headers: CORS_HEADERS });
  }
  if (req.method !== "GET") {
    return errorResponse("Method not allowed", 405);
  }

  // Per-project secrets: the dev project names the dev tenant, production the
  // production tenant. Fail closed when unset so a deploy without them is loud.
  const auth0Domain = Deno.env.get("AUTH0_DOMAIN");
  const auth0Audience = Deno.env.get("AUTH0_AUDIENCE");
  if (!auth0Domain || !auth0Audience) {
    console.error("AUTH0_DOMAIN / AUTH0_AUDIENCE not set");
    return errorResponse("Server configuration error", 500);
  }

  const sub = await verifyAndGetSub(req, { domain: auth0Domain, audience: auth0Audience });
  if (!sub) {
    return errorResponse("Missing or invalid JWT", 401);
  }

  const supabaseUrl = Deno.env.get("SUPABASE_URL")!;
  const serviceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
  const supabase = createClient(supabaseUrl, serviceRoleKey);

  // Look up user by auth0_id
  const { data: user, error: userError } = await supabase
    .from("users")
    .select("id")
    .eq("auth0_id", sub)
    .single();

  if (userError || !user) {
    return errorResponse("User not found", 404);
  }

  // Fetch keys — never expose hash
  const { data: keys, error: keysError } = await supabase
    .from("api_keys")
    .select("id, prefix, name, tier, status, expires_at, last_used_at, created_at, revoked_at")
    .eq("user_id", user.id)
    .order("created_at", { ascending: false });

  if (keysError) {
    return errorResponse(`Failed to fetch keys: ${keysError.message}`, 500);
  }

  return jsonResponse({ keys: keys ?? [] });
});
