/**
 * api-keys-rotate — replace one of a user's active API keys with a new one, in `api_keys`
 * and in the AUTH KV, and return the new plaintext token once.
 *
 * Server-to-server only: every request must present a service-level key (same check as
 * api-keys-create), and the body names the user the caller has already authenticated:
 *   { "keyId": "<uuid>", "userId": "<public.users id>" }
 * The one caller is the quality-metrics dashboard worker (`POST /api/admin/keys/:keyId/rotate`),
 * which verifies the user's Auth0 token itself, checks the key belongs to that user and their
 * active org, and then calls this with its `dashboard_worker` sb_secret_ key.
 *
 * Until 2026-10-05 the function read the user from the caller's own JWT, decoding `sub`
 * without checking a signature and relying on `verify_jwt = true` to do that. No end-user
 * client ever called it, and the dashboard's Auth0 tokens cannot pass Supabase's JWT check
 * (the project has no third-party auth), so that path is gone.
 *
 * Order matters: the new key is created and synced to KV before the old one is revoked, so a
 * failure at any step before the revoke leaves the old key working.
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

const TOKEN_PREFIX = "obtk_";
const TOKEN_BYTES = 32;
const KEY_PREFIX_CHARS = 8;
const KV_KEY_PREFIX = "apikey:";
const HEX_RADIX = 16;

function jsonResponse(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { "Content-Type": "application/json", ...CORS_HEADERS },
  });
}

function errorResponse(message: string, status: number): Response {
  return jsonResponse({ error: message }, status);
}

function toHex(bytes: Uint8Array): string {
  return Array.from(bytes).map((b) => b.toString(HEX_RADIX).padStart(2, "0")).join("");
}

async function sha256Hex(input: string): Promise<string> {
  const hash = await crypto.subtle.digest("SHA-256", new TextEncoder().encode(input));
  return toHex(new Uint8Array(hash));
}

function generateToken(): string {
  const bytes = new Uint8Array(TOKEN_BYTES);
  crypto.getRandomValues(bytes);
  return `${TOKEN_PREFIX}${toHex(bytes)}`;
}

function bearerToken(req: Request): string | null {
  const auth = req.headers.get("authorization");
  if (!auth?.startsWith("Bearer ")) return null;
  return auth.slice("Bearer ".length).trim() || null;
}

// Same capability check as api-keys-create: only a service-level key gets a 200 from the
// Auth admin API, so equality against one env value is not needed (or possible).
async function isServiceCredential(fetchFn: typeof fetch, supabaseUrl: string, presented: string): Promise<boolean> {
  try {
    const res = await fetchFn(`${supabaseUrl}/auth/v1/admin/users?page=1&per_page=1`, {
      headers: { apikey: presented, Authorization: `Bearer ${presented}` },
    });
    return res.status === 200;
  } catch {
    return false;
  }
}

export function createApiKeysRotateHandler(deps: HandlerDeps): (req: Request) => Promise<Response> {
  return async (req: Request): Promise<Response> => {
    if (req.method === "OPTIONS") {
      return new Response(null, { status: 204, headers: CORS_HEADERS });
    }
    if (req.method !== "POST") {
      return errorResponse("Method not allowed", 405);
    }

    const supabaseUrl = deps.env("SUPABASE_URL")!;
    const serviceRoleKey = deps.env("SUPABASE_SERVICE_ROLE_KEY")!;

    // Trust boundary: supabase/config.toml sets verify_jwt = false, so the platform verifies
    // nothing and the function must.
    const presented = bearerToken(req);
    if (!presented || !(await isServiceCredential(deps.fetch, supabaseUrl, presented))) {
      return errorResponse("Unauthorized", 401);
    }

    let keyId: unknown;
    let userId: unknown;
    try {
      const body = await req.json();
      keyId = body.keyId;
      userId = body.userId;
    } catch {
      return errorResponse("Invalid JSON body", 400);
    }
    if (!keyId || typeof keyId !== "string") return errorResponse("keyId is required", 400);
    if (!userId || typeof userId !== "string") return errorResponse("userId is required", 400);

    const supabase = deps.createClient(supabaseUrl, serviceRoleKey, { global: { fetch: deps.fetch } });

    // The old key must be this user's and still active. Its organization_id is read so the
    // replacement lands in the same org, not in an arbitrary membership.
    const { data: oldKey, error: oldKeyError } = await supabase
      .from("api_keys")
      .select("id, hash, name, tier, organization_id")
      .eq("id", keyId)
      .eq("user_id", userId)
      .eq("status", "active")
      .single();
    if (oldKeyError || !oldKey) {
      return errorResponse("Key not found or already revoked", 404);
    }

    const cfAccountId = deps.env("CLOUDFLARE_ACCOUNT_ID");
    const cfApiToken = deps.env("CLOUDFLARE_API_TOKEN");
    const kvNamespaceId = deps.env("KV_NAMESPACE_ID");
    if (!cfAccountId || !cfApiToken || !kvNamespaceId) {
      return errorResponse("Server misconfigured: missing Cloudflare credentials", 500);
    }
    const kvUrl = (key: string) =>
      `https://api.cloudflare.com/client/v4/accounts/${cfAccountId}/storage/kv/namespaces/${kvNamespaceId}/values/${key}`;

    // Create the new key BEFORE revoking the old one, so any failure here leaves the old key working.
    const token = generateToken();
    const hash = await sha256Hex(token);
    const prefix = token.slice(TOKEN_PREFIX.length, TOKEN_PREFIX.length + KEY_PREFIX_CHARS);

    const { data: newKey, error: newKeyError } = await supabase
      .from("api_keys")
      .insert({
        user_id: userId,
        organization_id: oldKey.organization_id,
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

    // Sync the new key to KV, also before the revoke. Same record shape as api-keys-create:
    // obtool-ingest and obtool-api resolve the key's org from `organizationId` and reject a
    // record without it.
    const kvRes = await deps.fetch(kvUrl(`${KV_KEY_PREFIX}${hash}`), {
      method: "PUT",
      headers: { Authorization: `Bearer ${cfApiToken}`, "Content-Type": "text/plain" },
      body: JSON.stringify({
        tier: oldKey.tier,
        status: "active",
        userId,
        keyId: newKey.id,
        prefix,
        organizationId: oldKey.organization_id,
      }),
    }).catch(() => null);
    if (!kvRes?.ok) {
      // Roll back the new row; the old key is still active.
      console.error(`KV sync failed for new key: ${kvRes ? await kvRes.text() : "network error"}`);
      const { error: rollbackError } = await supabase.from("api_keys").delete().eq("id", newKey.id);
      if (rollbackError) console.error(`Failed to roll back new key ${newKey.id}: ${rollbackError.message}`);
      return errorResponse("Failed to sync new key to auth cache. Old key is unchanged.", 500);
    }

    // The new key is live. Now revoke the old one.
    const { error: revokeError } = await supabase
      .from("api_keys")
      .update({ status: "revoked", revoked_at: new Date().toISOString() })
      .eq("id", oldKey.id)
      .eq("user_id", userId);
    if (revokeError) {
      console.error(`Failed to revoke old key ${oldKey.id}: ${revokeError.message}`);
    }

    // Remove the old KV entry. Best-effort: the row is revoked above.
    const deleteRes = await deps.fetch(kvUrl(`${KV_KEY_PREFIX}${oldKey.hash}`), {
      method: "DELETE",
      headers: { Authorization: `Bearer ${cfApiToken}` },
    }).catch(() => null);
    if (!deleteRes?.ok) {
      console.error(`Failed to delete old KV entry for key ${oldKey.id}: ${deleteRes ? await deleteRes.text() : "network error"}`);
    }

    return jsonResponse({
      token,
      keyId: newKey.id,
      previousKeyId: oldKey.id,
      prefix,
      tier: oldKey.tier,
    }, 201);
  };
}
