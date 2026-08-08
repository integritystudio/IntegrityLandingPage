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

  // Look up user
  const { data: user, error: userError } = await supabase
    .from("users")
    .select("id")
    .eq("auth0_id", sub)
    .single();
  if (userError || !user) return errorResponse("User not found", 404);

  // Resolve organization from membership
  const { data: membership } = await supabase
    .from("organization_memberships")
    .select("organization_id")
    .eq("user_id", user.id)
    .limit(1)
    .single();
  if (!membership?.organization_id) {
    return errorResponse("User has no organization. Contact support.", 403);
  }

  // Fetch old key details
  const { data: oldKey, error: oldKeyError } = await supabase
    .from("api_keys")
    .select("id, hash, name, tier")
    .eq("id", keyId)
    .eq("user_id", user.id)
    .eq("status", "active")
    .single();
  if (oldKeyError || !oldKey) {
    return errorResponse("Key not found or already revoked", 404);
  }

  const cfAccountId = Deno.env.get("CLOUDFLARE_ACCOUNT_ID");
  const cfApiToken = Deno.env.get("CLOUDFLARE_API_TOKEN");
  const kvNamespaceId = Deno.env.get("KV_NAMESPACE_ID");
  if (!cfAccountId || !cfApiToken || !kvNamespaceId) {
    return errorResponse("Server misconfigured: missing Cloudflare credentials", 500);
  }

  // Revoke old key in DB
  await supabase
    .from("api_keys")
    .update({ status: "revoked", revoked_at: new Date().toISOString() })
    .eq("id", oldKey.id)
    .eq("user_id", user.id);

  // Delete old key from KV
  const oldKvKey = `apikey:${oldKey.hash}`;
  const oldKvUrl = `https://api.cloudflare.com/client/v4/accounts/${cfAccountId}/storage/kv/namespaces/${kvNamespaceId}/values/${oldKvKey}`;
  await fetch(oldKvUrl, {
    method: "DELETE",
    headers: { Authorization: `Bearer ${cfApiToken}` },
  });

  // Create new key with same name/tier
  const token = generateToken();
  const hash = await sha256Hex(token);
  const prefix = token.slice(5, 13); // 8 hex chars after "obtk_"

  const { data: newKey, error: newKeyError } = await supabase
    .from("api_keys")
    .insert({
      user_id: user.id,
      organization_id: membership.organization_id,
      prefix,
      hash,
      name: oldKey.name,
      tier: oldKey.tier,
      status: "active",
    })
    .select("id")
    .single();
  if (newKeyError || !newKey) {
    return errorResponse(`Failed to create replacement key: ${newKeyError?.message}`, 500);
  }

  // Sync new key to KV
  const kvKey = `apikey:${hash}`;
  const kvValue = JSON.stringify({
    tier: oldKey.tier,
    status: "active",
    userId: user.id,
    keyId: newKey.id,
    prefix,
  });
  const kvUrl = `https://api.cloudflare.com/client/v4/accounts/${cfAccountId}/storage/kv/namespaces/${kvNamespaceId}/values/${kvKey}`;
  const kvRes = await fetch(kvUrl, {
    method: "PUT",
    headers: { Authorization: `Bearer ${cfApiToken}`, "Content-Type": "text/plain" },
    body: kvValue,
  });

  if (!kvRes.ok) {
    console.error(`KV sync failed for new key: ${await kvRes.text()}`);
    return jsonResponse({
      token,
      keyId: newKey.id,
      previousKeyId: oldKey.id,
      prefix,
      tier: oldKey.tier,
      warning: "Key rotated but KV sync failed. New key may not work immediately.",
    }, 201);
  }

  return jsonResponse({
    token,
    keyId: newKey.id,
    previousKeyId: oldKey.id,
    prefix,
    tier: oldKey.tier,
  }, 201);
});
