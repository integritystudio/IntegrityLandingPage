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
  try {
    const body = await req.json();
    tokenId = body.tokenId;
  } catch {
    return errorResponse("Invalid JSON body", 400);
  }
  if (!tokenId || typeof tokenId !== "string") {
    return errorResponse("tokenId is required", 400);
  }

  const supabaseUrl = Deno.env.get("SUPABASE_URL")!;
  const serviceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
  const supabase = createClient(supabaseUrl, serviceRoleKey);

  // Fetch token — verify belongs to user
  const { data: tokenRow, error: tokenError } = await supabase
    .from("provider_oauth_tokens")
    .select("id, refresh_token")
    .eq("id", tokenId)
    .eq("user_id", sub)
    .single();

  if (tokenError || !tokenRow) {
    return errorResponse("Token not found or access denied", 404);
  }
  if (!tokenRow.refresh_token) {
    return errorResponse("No refresh token available. Re-authenticate with Google.", 400);
  }

  const clientId = Deno.env.get("GOOGLE_CLIENT_ID");
  const clientSecret = Deno.env.get("GOOGLE_CLIENT_SECRET");
  if (!clientId || !clientSecret) {
    return errorResponse("Server misconfigured: missing Google OAuth credentials", 500);
  }

  // Call Google token endpoint
  const refreshRes = await fetch("https://oauth2.googleapis.com/token", {
    method: "POST",
    headers: { "Content-Type": "application/x-www-form-urlencoded" },
    body: new URLSearchParams({
      grant_type: "refresh_token",
      client_id: clientId,
      client_secret: clientSecret,
      refresh_token: tokenRow.refresh_token,
    }),
  });

  if (!refreshRes.ok) {
    const err = await refreshRes.text();
    return errorResponse(`Token refresh failed: ${err}`, 502);
  }

  const refreshData = await refreshRes.json();
  const expiresAt = new Date(Date.now() + (refreshData.expires_in ?? 3600) * 1000).toISOString();

  // Update DB
  await supabase
    .from("provider_oauth_tokens")
    .update({
      access_token: refreshData.access_token,
      token_expires_at: expiresAt,
      updated_at: new Date().toISOString(),
    })
    .eq("id", tokenId);

  return jsonResponse({ refreshed: true, expiresAt });
});
