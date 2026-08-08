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
    headers: { "Content-Type": "application/json", ...CORS_HEADERS },
  });
}

function errorResponse(message: string, status: number): Response {
  return jsonResponse({ error: message }, status);
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

  const sub = getJwtSub(req);
  if (!sub) return errorResponse("Missing or invalid JWT", 401);

  let keyId: string | undefined;
  try {
    const body = await req.json();
    keyId = body.keyId;
  } catch {
    return errorResponse("Invalid JSON body", 400);
  }
  if (!keyId || typeof keyId !== "string") {
    return errorResponse("keyId is required", 400);
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
  if (userError || !user) return errorResponse("User not found", 404);

  // Fetch key — must belong to this user and be active
  const { data: key, error: keyError } = await supabase
    .from("api_keys")
    .select("id, hash")
    .eq("id", keyId)
    .eq("user_id", user.id)
    .eq("status", "active")
    .single();
  if (keyError || !key) {
    return errorResponse("Key not found or already revoked", 404);
  }

  // Revoke in DB
  const { error: updateError } = await supabase
    .from("api_keys")
    .update({ status: "revoked", revoked_at: new Date().toISOString() })
    .eq("id", key.id)
    .eq("user_id", user.id);
  if (updateError) {
    return errorResponse("Failed to revoke key", 500);
  }

  // Delete from Cloudflare KV
  const cfAccountId = Deno.env.get("CLOUDFLARE_ACCOUNT_ID");
  const cfApiToken = Deno.env.get("CLOUDFLARE_API_TOKEN");
  const kvNamespaceId = Deno.env.get("KV_NAMESPACE_ID");
  if (cfAccountId && cfApiToken && kvNamespaceId) {
    const kvKey = `apikey:${key.hash}`;
    const kvUrl = `https://api.cloudflare.com/client/v4/accounts/${cfAccountId}/storage/kv/namespaces/${kvNamespaceId}/values/${kvKey}`;
    const kvRes = await fetch(kvUrl, {
      method: "DELETE",
      headers: { Authorization: `Bearer ${cfApiToken}` },
    });
    if (!kvRes.ok) {
      console.error(`KV delete failed for revoked key: ${await kvRes.text()}`);
      return jsonResponse({
        revoked: true,
        keyId: key.id,
        warning: "Key revoked in DB but KV delete failed. Key may still work briefly.",
      });
    }
  }

  return jsonResponse({ revoked: true, keyId: key.id });
});
