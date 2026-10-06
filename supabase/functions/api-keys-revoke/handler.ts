/**
 * api-keys-revoke handler — injectable for testing.
 *
 * Accepts server-to-server calls from the api-gateway worker. The caller
 * verifies org membership; this function verifies only that the key exists
 * and is active before revoking it and deleting its AUTH KV record.
 */

export interface HandlerDeps {
  env: (name: string) => string | undefined;
  fetch: typeof fetch;
  // deno-lint-ignore no-explicit-any
  createClient: (url: string, key: string, options: { global: { fetch: typeof fetch } }) => any;
}

const CORS_HEADERS = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

const KV_KEY_PREFIX = "apikey:";

function jsonResponse(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { "Content-Type": "application/json", ...CORS_HEADERS },
  });
}

function errorResponse(message: string, status: number): Response {
  return jsonResponse({ error: message }, status);
}

function bearerToken(req: Request): string | null {
  const auth = req.headers.get("authorization");
  if (!auth?.startsWith("Bearer ")) return null;
  return auth.slice("Bearer ".length).trim() || null;
}

// Same capability check as api-keys-create and api-keys-rotate: only a
// service-level key gets a 200 from the Auth admin API.
async function isServiceCredential(
  fetchFn: typeof fetch,
  supabaseUrl: string,
  presented: string,
): Promise<boolean> {
  try {
    const res = await fetchFn(
      `${supabaseUrl}/auth/v1/admin/users?page=1&per_page=1`,
      { headers: { apikey: presented, Authorization: `Bearer ${presented}` } },
    );
    return res.status === 200;
  } catch {
    return false;
  }
}

export function createApiKeysRevokeHandler(
  deps: HandlerDeps,
): (req: Request) => Promise<Response> {
  return async (req: Request): Promise<Response> => {
    if (req.method === "OPTIONS") {
      return new Response(null, { status: 204, headers: CORS_HEADERS });
    }
    if (req.method !== "POST") {
      return errorResponse("Method not allowed", 405);
    }

    const supabaseUrl = deps.env("SUPABASE_URL")!;
    const serviceRoleKey = deps.env("SUPABASE_SERVICE_ROLE_KEY")!;

    // Trust boundary: verify_jwt = false in config.toml; the function enforces
    // service-key authentication itself.
    const presented = bearerToken(req);
    if (!presented || !(await isServiceCredential(deps.fetch, supabaseUrl, presented))) {
      return errorResponse("Unauthorized", 401);
    }

    let keyId: unknown;
    try {
      const body = await req.json();
      keyId = body.keyId;
    } catch {
      return errorResponse("Invalid JSON body", 400);
    }
    if (!keyId || typeof keyId !== "string") {
      return errorResponse("keyId is required", 400);
    }

    const supabase = deps.createClient(supabaseUrl, serviceRoleKey, {
      global: { fetch: deps.fetch },
    });

    // Fetch the key to get its hash (needed for KV deletion).
    const { data: key, error: keyError } = await supabase
      .from("api_keys")
      .select("id, hash, status")
      .eq("id", keyId)
      .single();

    if (keyError || !key) {
      return errorResponse("Key not found", 404);
    }
    if (key.status === "revoked") {
      // Idempotent: already revoked is a success.
      return jsonResponse({ revoked: true, keyId: key.id });
    }

    // Revoke in the database.
    const { error: updateError } = await supabase
      .from("api_keys")
      .update({ status: "revoked", revoked_at: new Date().toISOString() })
      .eq("id", key.id);

    if (updateError) {
      return errorResponse("Failed to revoke key", 500);
    }

    // Delete the AUTH KV record so telemetry workers stop accepting this key immediately.
    const cfAccountId = deps.env("CLOUDFLARE_ACCOUNT_ID");
    const cfApiToken = deps.env("CLOUDFLARE_API_TOKEN");
    const kvNamespaceId = deps.env("KV_NAMESPACE_ID");

    if (!cfAccountId || !cfApiToken || !kvNamespaceId) {
      console.error("api-keys-revoke: missing Cloudflare credentials; DB revoked but KV not cleared");
      return jsonResponse({
        revoked: true,
        keyId: key.id,
        warning: "Key revoked in DB but KV credentials not configured. Key may still work briefly.",
      });
    }

    const kvKey = `${KV_KEY_PREFIX}${key.hash}`;
    const kvUrl = `https://api.cloudflare.com/client/v4/accounts/${cfAccountId}/storage/kv/namespaces/${kvNamespaceId}/values/${encodeURIComponent(kvKey)}`;
    const kvRes = await deps.fetch(kvUrl, {
      method: "DELETE",
      headers: { Authorization: `Bearer ${cfApiToken}` },
    }).catch(() => null);

    if (!kvRes?.ok) {
      const body = kvRes ? await kvRes.text().catch(() => "") : "network error";
      console.error(`api-keys-revoke: KV delete failed for ${keyId}: ${body}`);
      return jsonResponse({
        revoked: true,
        keyId: key.id,
        warning: "Key revoked in DB but KV delete failed. Key may still work briefly.",
      });
    }

    return jsonResponse({ revoked: true, keyId: key.id });
  };
}
