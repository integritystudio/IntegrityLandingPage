import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { createClient } from "jsr:@supabase/supabase-js@2";

const CORS_HEADERS = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
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
  if (req.method !== "POST") {
    return errorResponse("Method not allowed", 405);
  }

  const sub = getJwtSub(req);
  if (!sub) {
    return errorResponse("Missing or invalid JWT", 401);
  }

  let tokenId: string;
  let propertyId: string;
  try {
    const body = await req.json();
    tokenId = body.tokenId;
    propertyId = body.propertyId;
  } catch {
    return errorResponse("Invalid JSON body", 400);
  }

  if (!tokenId || typeof tokenId !== "string") {
    return errorResponse("tokenId is required", 400);
  }
  if (!propertyId || typeof propertyId !== "string") {
    return errorResponse("propertyId is required", 400);
  }

  const supabaseUrl = Deno.env.get("SUPABASE_URL")!;
  const serviceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
  const supabase = createClient(supabaseUrl, serviceRoleKey);

  // Update property_id — verify token belongs to user
  const { data: updated, error: updateError } = await supabase
    .from("provider_oauth_tokens")
    .update({
      property_id: propertyId,
      sync_status: "pending",
      updated_at: new Date().toISOString(),
    })
    .eq("id", tokenId)
    .eq("user_id", sub)
    .select("id")
    .single();

  if (updateError || !updated) {
    return errorResponse("Token not found or access denied", 404);
  }

  return jsonResponse({ updated: true, propertyId });
});
