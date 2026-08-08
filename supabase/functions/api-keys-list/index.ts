import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { createClient } from "jsr:@supabase/supabase-js@2";

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

Deno.serve(async (req: Request) => {
  if (req.method === "OPTIONS") {
    return new Response(null, { status: 204, headers: CORS_HEADERS });
  }
  if (req.method !== "GET") {
    return errorResponse("Method not allowed", 405);
  }

  const sub = getJwtSub(req);
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
