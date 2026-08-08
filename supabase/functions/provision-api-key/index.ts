import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { createClient } from "jsr:@supabase/supabase-js@2";

const CORS_HEADERS = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

const VALID_TIERS = ["new", "trusted", "pro"] as const;
type Tier = typeof VALID_TIERS[number];

function jsonResponse(body: Record<string, unknown>, status = 200): Response {
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

interface ProvisionRequest {
  email: string;
  name?: string;
  tier?: string;
}

Deno.serve(async (req: Request) => {
  if (req.method === "OPTIONS") {
    return new Response(null, { status: 204, headers: CORS_HEADERS });
  }

  if (req.method !== "POST") {
    return errorResponse("Method not allowed", 405);
  }

  let body: ProvisionRequest;
  try {
    body = await req.json();
  } catch {
    return errorResponse("Invalid JSON body", 400);
  }

  if (!body.email || typeof body.email !== "string") {
    return errorResponse("email is required", 400);
  }

  const email = body.email.trim().toLowerCase();
  if (!/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email)) {
    return errorResponse("Invalid email format", 400);
  }

  // Validate tier if provided, default to "new"
  const tier: Tier = (body.tier && VALID_TIERS.includes(body.tier as Tier))
    ? body.tier as Tier
    : "new";

  const supabaseUrl = Deno.env.get("SUPABASE_URL")!;
  const serviceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
  const supabase = createClient(supabaseUrl, serviceRoleKey);

  const cfAccountId = Deno.env.get("CLOUDFLARE_ACCOUNT_ID");
  const cfApiToken = Deno.env.get("CLOUDFLARE_API_TOKEN");
  const kvNamespaceId = Deno.env.get("KV_NAMESPACE_ID");

  if (!cfAccountId || !cfApiToken || !kvNamespaceId) {
    return errorResponse("Server misconfigured: missing Cloudflare credentials", 500);
  }

  const token = generateToken();
  const hash = await sha256Hex(token);
  const prefix = token.slice(5, 13);

  const { data: user, error: userError } = await supabase
    .from("users")
    .upsert(
      {
        email,
        name: body.name || null,
        auth0_id: `obtool:${crypto.randomUUID()}`,
        tier,
      },
      { onConflict: "email", ignoreDuplicates: false }
    )
    .select("id, tier")
    .single();

  if (userError) {
    if (userError.code === "23505") {
      const { data: existingUser, error: fetchError } = await supabase
        .from("users")
        .select("id, tier")
        .eq("email", email)
        .single();
      if (fetchError || !existingUser) {
        return errorResponse(`Failed to fetch existing user: ${fetchError?.message}`, 500);
      }
      // Use requested tier for the key even if user already exists
      return await insertKeyAndSync(
        supabase, existingUser.id, tier,
        prefix, hash, token,
        cfAccountId, cfApiToken, kvNamespaceId, email
      );
    }
    return errorResponse(`Failed to create user: ${userError.message}`, 500);
  }

  return await insertKeyAndSync(
    supabase, user.id, tier,
    prefix, hash, token,
    cfAccountId, cfApiToken, kvNamespaceId, email
  );
});

async function insertKeyAndSync(
  // deno-lint-ignore no-explicit-any
  supabase: any,
  userId: string,
  tier: string,
  prefix: string,
  hash: string,
  token: string,
  cfAccountId: string,
  cfApiToken: string,
  kvNamespaceId: string,
  email: string
): Promise<Response> {
  const { data: existingKeys } = await supabase
    .from("api_keys")
    .select("id, prefix")
    .eq("user_id", userId)
    .eq("status", "active")
    .limit(1);

  if (existingKeys && existingKeys.length > 0) {
    return errorResponse(
      `User ${email} already has an active API key (prefix: ${existingKeys[0].prefix}). Revoke it first or use the existing key.`,
      409
    );
  }

  const { data: apiKey, error: keyError } = await supabase
    .from("api_keys")
    .insert({
      user_id: userId,
      prefix,
      hash,
      name: "Default",
      tier,
      status: "active",
    })
    .select("id")
    .single();

  if (keyError) {
    return errorResponse(`Failed to create API key: ${keyError.message}`, 500);
  }

  const kvKey = `apikey:${hash}`;
  const kvValue = JSON.stringify({
    tier,
    status: "active",
    userId,
    keyId: apiKey.id,
    prefix,
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
    const kvErr = await kvRes.text();
    console.error(`KV sync failed (${kvRes.status}): ${kvErr}`);
    return jsonResponse({
      token,
      userId,
      keyId: apiKey.id,
      prefix,
      tier,
      warning: "API key created but KV sync failed. Key may not work immediately.",
    }, 201);
  }

  return jsonResponse({
    token,
    userId,
    keyId: apiKey.id,
    prefix,
    tier,
  }, 201);
}
