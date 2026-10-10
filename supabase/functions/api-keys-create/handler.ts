
/**
 * Everything the handler reaches outside itself, passed in so the same code runs under
 * the edge runtime (index.ts) and under tests against an in-memory backend.
 * `createClient` is supabase-js's own factory; the handler passes it `fetch` so every
 * database call goes through the same injected transport as the auth check and KV sync.
 */
export interface HandlerDeps {
  env: (name: string) => string | undefined;
  fetch: typeof fetch;
  // supabase-js's client type cannot be imported here without a runtime-specific specifier
  // (jsr: under Deno, npm under Node), so the factory's return type is left open.
  // deno-lint-ignore no-explicit-any
  createClient: (url: string, key: string, options: { global: { fetch: typeof fetch } }) => any;
}

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

function bearerToken(req: Request): string | null {
  const auth = req.headers.get("authorization");
  if (!auth?.startsWith("Bearer ")) return null;
  return auth.slice("Bearer ".length).trim() || null;
}

// Is the presented credential a service-level key for THIS project? Decided by
// capability, not equality: the Auth admin API answers 200 only to the legacy
// service_role JWT or an sb_secret_ key, and 401 to anon/publishable keys, user
// JWTs and garbage (verified 2026-09-11 against production). Equality against
// one env value cannot work here — the receiver sends the sb_secret_ key held in
// Doppler as SUPABASE_PROVISIONING_KEY, the edge runtime injects the legacy JWT
// as SUPABASE_SERVICE_ROLE_KEY, and the project has more than one sb_secret_
// key in circulation.
async function isServiceCredential(
  fetchFn: typeof fetch,
  supabaseUrl: string,
  presented: string,
): Promise<boolean> {
  try {
    const res = await fetchFn(`${supabaseUrl}/auth/v1/admin/users?page=1&per_page=1`, {
      headers: { apikey: presented, Authorization: `Bearer ${presented}` },
    });
    return res.status === 200;
  } catch {
    return false;
  }
}

const VALID_TIERS = new Set(["starter", "growth", "enterprise"]);
const DEFAULT_TIER = "starter";
const UUID_PATTERN = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;
// Raised by create_api_key_for_request when abandon_api_key_request claimed the id first.
const REQUEST_ABANDONED = "api_key_request_abandoned";
// A failed membership query is an outage, not "no membership": answer 5xx so the
// receiver can retry rather than read it as a 403 (TS20).
const MEMBERSHIP_LOOKUP_FAILED = "Database error resolving membership.";

export function createApiKeysCreateHandler(deps: HandlerDeps): (req: Request) => Promise<Response> {
  return async (req: Request): Promise<Response> => {
    if (req.method === "OPTIONS") {
      return new Response(null, { status: 204, headers: CORS_HEADERS });
    }
    if (req.method !== "POST") {
      return errorResponse("Method not allowed", 405);
    }

    const supabaseUrl = deps.env("SUPABASE_URL")!;
    const serviceRoleKey = deps.env("SUPABASE_SERVICE_ROLE_KEY")!;

    // Trust boundary: this function is server-to-server ONLY. supabase/config.toml
    // sets verify_jwt = false so the provisioning receiver can call it with the
    // service key, which means the platform verifies nothing — so the function
    // must. Until 2026-09-11 it did not: a body carrying `userId` was accepted
    // with no credential at all, and the "direct user" branch decoded the JWT
    // payload without checking its signature. Both were open doors to minting a
    // key for any user in any org at any tier. The receiver is the only caller
    // (no frontend code calls this function), so the JWT branch is gone and a
    // service-level key is required on every request (see isServiceCredential).
    const presented = bearerToken(req);
    if (!presented || !(await isServiceCredential(deps.fetch, supabaseUrl, presented))) {
      return errorResponse("Unauthorized", 401);
    }

    // Parse body. `tier` is deliberately NOT read: the key's tier comes from the
    // organization's current_plan below (AUTH-PER-USER-QUOTAS gap 4). The receiver
    // still sends it for backward compatibility; it is ignored here.
    let name = "Default";
    let organizationId: string | null = null;
    let bodyUserId: string | null = null;
    // Optional per-attempt id (20261010000000_api_key_requests): with it, a caller that loses
    // the response can abandon the attempt and revoke exactly the key it created.
    let requestId: string | null = null;
    let requestIdInvalid = false;
    try {
      const body = await req.json();
      if (body.name && typeof body.name === "string") {
        const trimmed = body.name.trim().slice(0, 100);
        // A whitespace-only name trims to ""; fall back to "Default" rather
        // than storing an empty string (TS21).
        name = trimmed || "Default";
      }
      if (body.organizationId && typeof body.organizationId === "string") {
        organizationId = body.organizationId;
      }
      if (body.userId && typeof body.userId === "string") {
        bodyUserId = body.userId;
      }
      if (body.requestId !== undefined) {
        if (typeof body.requestId === "string" && UUID_PATTERN.test(body.requestId)) {
          requestId = body.requestId;
        } else {
          requestIdInvalid = true;
        }
      }
    } catch {
      // Empty body is fine — use defaults
    }
    if (!bodyUserId) {
      return errorResponse("userId is required", 400);
    }
    if (requestIdInvalid) {
      return errorResponse("requestId must be a UUID", 400);
    }

    const supabase = deps.createClient(supabaseUrl, serviceRoleKey, { global: { fetch: deps.fetch } });

    const { data: user, error: userError } = await supabase
      .from("users")
      .select("id, default_organization_id")
      .eq("id", bodyUserId)
      .single();
    if (userError) {
      // PGRST116: "JSON object requested, multiple (or no) rows returned" = not found.
      // Any other error code is a database / network failure — surface it as 5xx so
      // the receiver can distinguish an outage from a bad userId and retry.
      if (userError.code === "PGRST116") {
        return errorResponse("User not found.", 404);
      }
      return errorResponse("Database error resolving user.", 503);
    }
    const userId: string = user.id;

    // Resolve organization. A caller-supplied organizationId is honoured only if
    // the user holds an ACTIVE membership in it; otherwise it would let a caller
    // mint keys into an org the user does not belong to.
    if (organizationId) {
      const { data: membership, error: membershipError } = await supabase
        .from("organization_memberships")
        .select("organization_id")
        .eq("user_id", userId)
        .eq("organization_id", organizationId)
        .eq("status", "active")
        .limit(1)
        .maybeSingle();
      if (membershipError) return errorResponse(MEMBERSHIP_LOOKUP_FAILED, 503);
      if (!membership) {
        return errorResponse("User is not an active member of that organization.", 403);
      }
    } else {
      // Prefer users.default_organization_id (mirrors custom_access_token_hook and
      // the gateway's supabaseFindOrgIdByEmail), then fall back to the oldest active
      // membership — deterministic for multi-org users (TS21).
      const defaultOrgId: string | null = user.default_organization_id ?? null;
      if (defaultOrgId) {
        const { data: defaultMembership, error: defaultMembershipError } = await supabase
          .from("organization_memberships")
          .select("organization_id")
          .eq("user_id", userId)
          .eq("organization_id", defaultOrgId)
          .eq("status", "active")
          .limit(1)
          .maybeSingle();
        if (defaultMembershipError) return errorResponse(MEMBERSHIP_LOOKUP_FAILED, 503);
        if (defaultMembership) organizationId = defaultOrgId;
      }
      if (!organizationId) {
        const { data: membership, error: membershipError } = await supabase
          .from("organization_memberships")
          .select("organization_id")
          .eq("user_id", userId)
          .eq("status", "active")
          .order("created_at", { ascending: true })
          .limit(1)
          .maybeSingle();
        if (membershipError) return errorResponse(MEMBERSHIP_LOOKUP_FAILED, 503);
        organizationId = membership?.organization_id ?? null;
      }
    }
    if (!organizationId) {
      return errorResponse("User has no organization. Contact support.", 403);
    }

    // Resolve tier server-side, mirroring the receiver's checkOrgKeyQuota: the
    // org's current_plan is authoritative (the Stripe webhook is its writer);
    // starter if the org row is missing or the plan is not a known tier.
    // users.tier is no longer read (UA11): since UA04 it is derived from the
    // default org's plan by trigger, so as a fallback it had nothing to add.
    const { data: org, error: orgError } = await supabase
      .from("organizations")
      .select("current_plan")
      .eq("id", organizationId)
      .maybeSingle();
    if (orgError) {
      // A query error (not "no rows") means the DB is unavailable. Return 5xx so
      // the receiver can retry rather than silently downgrading the key to starter
      // — a transient error was previously indistinguishable from an org-not-found
      // result (TS20), which would mint a permanent starter-tier key.
      return errorResponse("Database error resolving plan.", 503);
    }
    // Plan comparison is case-insensitive (TS21): the UA04 trigger lower-cases before
    // writing users.tier, but current_plan is written by stripe-webhook as-is, so a
    // value like "Growth" must still produce a growth-tier key.
    const candidate = (org?.current_plan ?? DEFAULT_TIER).toLowerCase();
    const userTier: string = VALID_TIERS.has(candidate) ? candidate : DEFAULT_TIER;

    // Cloudflare KV config
    const cfAccountId = deps.env("CLOUDFLARE_ACCOUNT_ID");
    const cfApiToken = deps.env("CLOUDFLARE_API_TOKEN");
    const kvNamespaceId = deps.env("KV_NAMESPACE_ID");
    if (!cfAccountId || !cfApiToken || !kvNamespaceId) {
      return errorResponse("Server misconfigured: missing Cloudflare credentials", 500);
    }

    // Generate token and hash
    const token = generateToken();
    const hash = await sha256Hex(token);
    const prefix = token.slice(5, 13); // 8 hex chars after "obtk_"

    // Insert API key. With a requestId the insert goes through create_api_key_for_request,
    // which claims the id in the same transaction and fails if the caller abandoned it.
    let keyId: string;
    if (requestId) {
      const { data: createdId, error: rpcError } = await supabase.rpc("create_api_key_for_request", {
        p_request_id: requestId,
        p_user_id: userId,
        p_organization_id: organizationId,
        p_prefix: prefix,
        p_hash: hash,
        p_name: name,
        p_tier: userTier,
      });
      if (rpcError) {
        if (String(rpcError.message ?? "").includes(REQUEST_ABANDONED)) {
          return errorResponse("request abandoned", 409);
        }
        return errorResponse(`Failed to create API key: ${rpcError.message}`, 500);
      }
      keyId = createdId as string;
    } else {
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
      keyId = apiKey.id;
    }

    // Sync to Cloudflare KV
    const kvKey = `apikey:${hash}`;
    const kvValue = JSON.stringify({
      tier: userTier,
      status: "active",
      userId,
      keyId,
      prefix,
      // Org-scoped multi-tenancy P3: obtool-ingest resolves the telemetry
      // keyspace (org/<orgId>/...) from this field, and obtool-api scopes
      // every read to it (2026-09-17). Both hard-reject a record without it
      // (no grace-map since 2026-07-28), so api-keys-rotate must write it too.
      organizationId,
    });
    const kvUrl = `https://api.cloudflare.com/client/v4/accounts/${cfAccountId}/storage/kv/namespaces/${kvNamespaceId}/values/${kvKey}`;
    // TS19: the key row already exists, so a KV failure of either kind (HTTP error or a
    // thrown network error) must still hand the caller its token, or the row is orphaned.
    let kvFailure: string | null = null;
    try {
      const kvRes = await deps.fetch(kvUrl, {
        method: "PUT",
        headers: {
          Authorization: `Bearer ${cfApiToken}`,
          "Content-Type": "text/plain",
        },
        body: kvValue,
      });
      if (!kvRes.ok) kvFailure = await kvRes.text();
    } catch (err) {
      kvFailure = err instanceof Error ? err.message : String(err);
    }

    if (kvFailure !== null) {
      console.error(`KV sync failed: ${kvFailure}`);
      return jsonResponse({
        token,
        keyId,
        prefix,
        tier: userTier,
        name,
        warning: "API key created but KV sync failed. Key may not work immediately.",
      }, 201);
    }

    // api-keys-revoke deletes the KV record after marking the row revoked. If that ran
    // between the insert and the PUT above (the caller abandoned the attempt), the PUT just
    // brought the credential back, so re-read the row and take it down again.
    const { data: current, error: recheckError } = await supabase
      .from("api_keys")
      .select("status")
      .eq("id", keyId)
      .maybeSingle();
    if (recheckError) {
      // Unknown status: hand the token over rather than orphan a key that is probably live.
      console.error(`api-keys-create: status re-check failed for ${keyId}: ${recheckError.message}`);
    } else if (current?.status === "revoked") {
      await deleteKvRecord(deps.fetch, kvUrl, cfApiToken, keyId);
      return errorResponse("key revoked during creation", 409);
    }

    return jsonResponse({ token, keyId, prefix, tier: userTier, name }, 201);
  };
}

/** DELETE a KV record; 404 means already gone. Failure is logged: the caller has nothing to retry. */
async function deleteKvRecord(fetchFn: typeof fetch, kvUrl: string, cfApiToken: string, keyId: string): Promise<void> {
  try {
    const res = await fetchFn(kvUrl, { method: "DELETE", headers: { Authorization: `Bearer ${cfApiToken}` } });
    if (!res.ok && res.status !== 404) {
      console.error(`api-keys-create: KV delete for revoked key ${keyId} failed: ${await res.text()}`);
    }
  } catch (err) {
    console.error(`api-keys-create: KV delete for revoked key ${keyId} failed: ${err instanceof Error ? err.message : String(err)}`);
  }
}
