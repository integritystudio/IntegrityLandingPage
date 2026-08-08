import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { createClient } from "jsr:@supabase/supabase-js@2";

const CORS_HEADERS = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

function jsonResponse(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: {
      "Content-Type": "application/json",
      ...CORS_HEADERS,
    },
  });
}

function errorResponse(message: string, status: number): Response {
  return jsonResponse({ error: message }, status);
}

async function sha256Hex(input: string): Promise<string> {
  const data = new TextEncoder().encode(input);
  const hash = await crypto.subtle.digest("SHA-256", data);
  return Array.from(new Uint8Array(hash))
    .map((b) => b.toString(16).padStart(2, "0"))
    .join("");
}

function generateToken(): string {
  const bytes = new Uint8Array(32);
  crypto.getRandomValues(bytes);
  const hex = Array.from(bytes)
    .map((b) => b.toString(16).padStart(2, "0"))
    .join("");
  return `obtk_${hex}`;
}

function getJwtSub(req: Request): string | null {
  const auth = req.headers.get("authorization");
  if (!auth?.startsWith("Bearer ")) return null;
  try {
    const payload = JSON.parse(atob(auth.split(".")[1]));
    return payload.sub ?? null;
  } catch {
    return null;
  }
}

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response(null, { status: 204, headers: CORS_HEADERS });
  }
  if (req.method !== "POST") {
    return errorResponse("Method not allowed", 405);
  }

  // Parse body
  let name = "Default";
  let organizationId: string | null = null;
  let bodyUserId: string | null = null;
  let bodyTier: string | null = null;
  try {
    const body = await req.json();
    if (body.name && typeof body.name === "string") {
      name = body.name.trim().slice(0, 100);
    }
    if (body.organizationId && typeof body.organizationId === "string") {
      organizationId = body.organizationId;
    }
    if (body.userId && typeof body.userId === "string") {
      bodyUserId = body.userId;
    }
    if (body.tier && typeof body.tier === "string") {
      bodyTier = body.tier;
    }
  } catch {
    // Empty body is fine — use defaults
  }

  const supabaseUrl = Deno.env.get("SUPABASE_URL")!;
  const serviceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
  const supabase = createClient(supabaseUrl, serviceRoleKey);

  let userId: string;
  let userTier: string;

  if (bodyUserId) {
    // Server-to-server call: userId provided by the receiver (already Auth0-validated upstream).
    const { data: user, error: userError } = await supabase
      .from("users")
      .select("id, tier")
      .eq("id", bodyUserId)
      .single();
    if (userError || !user) {
      return errorResponse("User not found.", 404);
    }
    userId = user.id;
    userTier = bodyTier ?? user.tier;
  } else {
    // Direct user call: look up by JWT sub (auth0_id).
    const sub = getJwtSub(req);
    if (!sub) return errorResponse("Missing or invalid JWT", 401);
    const { data: user, error: userError } = await supabase
      .from("users")
      .select("id, tier")
      .eq("auth0_id", sub)
      .single();
    if (userError || !user) {
      return errorResponse("User not found. Complete registration first.", 404);
    }
    userId = user.id;
    userTier = bodyTier ?? user.tier;
  }

  // Resolve organization: prefer body param, else look up from membership
  if (!organizationId) {
    const { data: membership } = await supabase
      .from("organization_memberships")
      .select("organization_id")
      .eq("user_id", userId)
      .limit(1)
      .single();
    organizationId = membership?.organization_id ?? null;
  }
  if (!organizationId) {
    return errorResponse("User has no organization. Contact support.", 403);
  }

  // Cloudflare KV config
  const cfAccountId = Deno.env.get("CLOUDFLARE_ACCOUNT_ID");
  const cfApiToken = Deno.env.get("CLOUDFLARE_API_TOKEN");
  const kvNamespaceId = Deno.env.get("KV_NAMESPACE_ID");
  if (!cfAccountId || !cfApiToken || !kvNamespaceId) {
    return errorResponse("Server misconfigured: missing Cloudflare credentials", 500);
  }

  // Generate token and hash
  const token = generateToken();
  const hash = await sha256Hex(token);
  const prefix = token.slice(5, 13); // 8 hex chars after "obtk_"

  // Insert API key
  const { data: apiKey, error: keyError } = await supabase
    .from("api_keys")
    .insert({
      user_id: userId,
      organization_id: organizationId,
      prefix,
      hash,
      name,
      tier: userTier,
      status: "active",
    })
    .select("id")
    .single();
  if (keyError) {
    return errorResponse(`Failed to create API key: ${keyError.message}`, 500);
  }

  // Sync to Cloudflare KV
  const kvKey = `apikey:${hash}`;
  const kvValue = JSON.stringify({
    tier: userTier,
    status: "active",
    userId,
    keyId: apiKey.id,
    prefix,
    // Org-scoped multi-tenancy P3: obtool-ingest resolves the telemetry
    // keyspace (org/<orgId>/...) from this field. Values without it
    // grace-map to the home org until backfilled/rotated.
    organizationId,
  });
  const kvUrl = `https://api.cloudflare.com/client/v4/accounts/${cfAccountId}/storage/kv/namespaces/${kvNamespaceId}/values/${kvKey}`;
  const kvRes = await fetch(kvUrl, {
    method: "PUT",
    headers: {
      Authorization: `Bearer ${cfApiToken}`,
      "Content-Type": "text/plain",
    },
    body: kvValue,
  });

  if (!kvRes.ok) {
    console.error(`KV sync failed: ${await kvRes.text()}`);
    return jsonResponse({
      token,
      keyId: apiKey.id,
      prefix,
      tier: userTier,
      name,
      warning: "API key created but KV sync failed. Key may not work immediately.",
    }, 201);
  }

  return jsonResponse({ token, keyId: apiKey.id, prefix, tier: userTier, name }, 201);
});
