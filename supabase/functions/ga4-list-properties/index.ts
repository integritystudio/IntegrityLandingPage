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

  const url = new URL(req.url);
  const tokenId = url.searchParams.get("tokenId");
  if (!tokenId) {
    return errorResponse("tokenId query parameter is required", 400);
  }

  const supabaseUrl = Deno.env.get("SUPABASE_URL")!;
  const serviceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
  const supabase = createClient(supabaseUrl, serviceRoleKey);

  // Fetch token row — verify it belongs to the caller
  const { data: tokenRow, error: tokenError } = await supabase
    .from("provider_oauth_tokens")
    .select("id, access_token, refresh_token, token_expires_at, user_id")
    .eq("id", tokenId)
    .eq("user_id", sub)
    .single();

  if (tokenError || !tokenRow) {
    return errorResponse("OAuth token not found or access denied", 404);
  }

  let accessToken = tokenRow.access_token;

  // Refresh if expired
  if (tokenRow.token_expires_at && new Date(tokenRow.token_expires_at) <= new Date()) {
    const clientId = Deno.env.get("GOOGLE_CLIENT_ID");
    const clientSecret = Deno.env.get("GOOGLE_CLIENT_SECRET");
    if (!clientId || !clientSecret) {
      return errorResponse("Server misconfigured: missing Google OAuth credentials", 500);
    }
    if (!tokenRow.refresh_token) {
      return errorResponse("No refresh token available. Re-authenticate with Google.", 400);
    }

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
    accessToken = refreshData.access_token;
    const expiresAt = new Date(Date.now() + (refreshData.expires_in ?? 3600) * 1000).toISOString();

    await supabase
      .from("provider_oauth_tokens")
      .update({ access_token: accessToken, token_expires_at: expiresAt, updated_at: new Date().toISOString() })
      .eq("id", tokenId);
  }

  // Call Google Analytics Admin API
  const gaRes = await fetch(
    "https://analyticsadmin.googleapis.com/v1beta/accountSummaries",
    { headers: { Authorization: `Bearer ${accessToken}` } }
  );

  if (!gaRes.ok) {
    const err = await gaRes.text();
    return errorResponse(`Google API error: ${err}`, gaRes.status >= 500 ? 502 : gaRes.status);
  }

  const gaData = await gaRes.json();

  // Flatten account summaries into a property list
  interface PropertySummary {
    property?: string;
    displayName?: string;
  }
  interface AccountSummary {
    displayName?: string;
    propertySummaries?: PropertySummary[];
  }
  const properties = (gaData.accountSummaries ?? []).flatMap((account: AccountSummary) =>
    (account.propertySummaries ?? []).map((prop: PropertySummary) => ({
      propertyId: prop.property?.replace("properties/", "") ?? "",
      displayName: prop.displayName ?? "",
      accountName: account.displayName ?? "",
    }))
  );

  return jsonResponse({ properties });
});
