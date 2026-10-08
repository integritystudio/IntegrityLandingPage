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
 * Verify the bearer JWT and return its `sub`, which is what `users.auth0_id` holds.
 *
 * Two issuers are accepted, the same two the platform's `verify_jwt` admits:
 *   - the project's own Supabase Auth (`${SUPABASE_URL}/auth/v1`, ES256 keys from its
 *     JWKS endpoint, audience `authenticated`) — what the toolkit e2e suite sends after
 *     `signInWithPassword`;
 *   - the Auth0 tenant (`https://${AUTH0_DOMAIN}/`, audience `AUTH0_AUDIENCE`), admitted
 *     through Third-Party Auth; only when both secrets are set — and, when `AUTH0_CUSTOM_DOMAIN`
 *     is also set, the same tenant under its custom domain (`https://${AUTH0_CUSTOM_DOMAIN}/`),
 *     which Auth0 stamps as `iss` on tokens obtained through that hostname; same key set (CR70).
 * The token's `iss` picks the verifier; a token from anywhere else is refused.
 *
 * This replaces the previous `atob`-based read, which decoded the payload without
 * verifying the signature and was safe only while `verify_jwt = true` made the platform
 * verify the token first — a fragile, deployment-dependent guarantee. Verifying here means
 * the function is safe regardless of how it is deployed.
 *
 * The JWKS objects are module-level so jose's key cache survives across requests in the
 * same isolate.
 */
interface Issuer {
  issuer: string;
  audience: string;
  jwks: ReturnType<typeof jose.createRemoteJWKSet>;
}

let issuers: Issuer[] | undefined;

function getIssuers(supabaseUrl: string): Issuer[] {
  if (issuers) return issuers;
  const list: Issuer[] = [{
    issuer: `${supabaseUrl}/auth/v1`,
    audience: "authenticated",
    jwks: jose.createRemoteJWKSet(new URL(`${supabaseUrl}/auth/v1/.well-known/jwks.json`)),
  }];
  const auth0Domain = Deno.env.get("AUTH0_DOMAIN");
  const auth0Audience = Deno.env.get("AUTH0_AUDIENCE");
  const auth0CustomDomain = Deno.env.get("AUTH0_CUSTOM_DOMAIN");
  if (auth0Domain && auth0Audience) {
    // One key set serves both issuers, so one remote JWKS (and one cache) is shared.
    const auth0Jwks = jose.createRemoteJWKSet(new URL(`https://${auth0Domain}/.well-known/jwks.json`));
    list.push({ issuer: `https://${auth0Domain}/`, audience: auth0Audience, jwks: auth0Jwks });
    if (auth0CustomDomain) {
      list.push({ issuer: `https://${auth0CustomDomain}/`, audience: auth0Audience, jwks: auth0Jwks });
    }
  }
  issuers = list;
  return list;
}

async function verifyAndGetSub(req: Request, supabaseUrl: string): Promise<string | null> {
  const auth = req.headers.get("authorization");
  if (!auth?.startsWith("Bearer ")) return null;
  const token = auth.slice("Bearer ".length).trim();
  try {
    // `iss` is read unverified only to choose the verifier; jwtVerify re-checks it.
    const claimedIssuer = jose.decodeJwt(token).iss;
    const match = getIssuers(supabaseUrl).find((i) => i.issuer === claimedIssuer);
    if (!match) return null;
    const { payload } = await jose.jwtVerify(token, match.jwks, {
      issuer: match.issuer,
      audience: match.audience,
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

  // Both are platform-injected on hosted projects; checked anyway so a bad deploy is loud.
  const supabaseUrl = Deno.env.get("SUPABASE_URL");
  const serviceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
  if (!supabaseUrl || !serviceRoleKey) {
    console.error("SUPABASE_URL / SUPABASE_SERVICE_ROLE_KEY not set");
    return errorResponse("Server configuration error", 500);
  }

  const sub = await verifyAndGetSub(req, supabaseUrl);
  if (!sub) {
    return errorResponse("Missing or invalid JWT", 401);
  }
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
