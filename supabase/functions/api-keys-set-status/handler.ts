/**
 * api-keys-set-status — switch an API key between 'active' and 'inactive', in `api_keys`
 * and in the key's AUTH KV record, or bring every KV record's status in line with the table.
 *
 * Operator-only: every request must present a service-level key (same check as
 * api-keys-create). Two request shapes:
 *   { "keyId": "<uuid>", "status": "active" | "inactive" }
 *       Sets the row, then mirrors `status` into `apikey:<hash>` in KV. Revoked and expired
 *       keys are permanent and refused (409).
 *   { "action": "reconcile", "dryRun": true | false }
 *       Walks every `apikey:` record in the AUTH namespace and sets its `status` from the
 *       table: 'active' only for a key with an active row (or listed in KV_ONLY_KEY_HASHES,
 *       the documented KV-only keys such as the internal home key), 'inactive' otherwise —
 *       which catches records whose row or user was deleted (BACKLOG.md UA13). `dryRun`
 *       defaults to true: it reports what would change and writes nothing.
 *
 * The table is the source of truth; KV only ever follows it. obtool-api and obtool-ingest
 * (observability-toolkit, `authorizeKvEntry`) accept a KV record only when it carries an
 * `organizationId` and its `status` is 'active', and the gateway refuses any key whose row
 * is not 'active'.
 */

export interface HandlerDeps {
  env: (name: string) => string | undefined;
  fetch: typeof fetch;
  // deno-lint-ignore no-explicit-any
  createClient: (url: string, key: string, options: { global: { fetch: typeof fetch } }) => any;
}

type SettableStatus = "active" | "inactive";
type KvSync = "updated" | "unchanged" | "missing" | "legacy" | "failed";

const SETTABLE: ReadonlySet<string> = new Set(["active", "inactive"]);
const KV_KEY_PREFIX = "apikey:";
const KV_LIST_LIMIT = 1000;
const HASH_REPORT_CHARS = 8;
const RECONCILE_ACTION = "reconcile";

function jsonResponse(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), { status, headers: { "Content-Type": "application/json" } });
}

function errorResponse(message: string, status: number): Response {
  return jsonResponse({ error: message }, status);
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

interface Kv {
  get(key: string): Promise<{ ok: true; value: string | null } | { ok: false }>;
  put(key: string, value: string): Promise<boolean>;
  list(prefix: string): Promise<string[] | null>;
}

function kvClient(fetchFn: typeof fetch, accountId: string, token: string, namespaceId: string): Kv {
  const base = `https://api.cloudflare.com/client/v4/accounts/${accountId}/storage/kv/namespaces/${namespaceId}`;
  const headers = { Authorization: `Bearer ${token}` };
  return {
    async get(key) {
      try {
        const res = await fetchFn(`${base}/values/${encodeURIComponent(key)}`, { headers });
        if (res.status === 404) return { ok: true, value: null };
        if (!res.ok) return { ok: false };
        return { ok: true, value: await res.text() };
      } catch {
        return { ok: false };
      }
    },
    async put(key, value) {
      try {
        const res = await fetchFn(`${base}/values/${encodeURIComponent(key)}`, {
          method: "PUT",
          headers: { ...headers, "Content-Type": "text/plain" },
          body: value,
        });
        return res.ok;
      } catch {
        return false;
      }
    },
    async list(prefix) {
      const names: string[] = [];
      let cursor = "";
      try {
        do {
          const params = new URLSearchParams({ prefix, limit: String(KV_LIST_LIMIT) });
          if (cursor) params.set("cursor", cursor);
          const res = await fetchFn(`${base}/keys?${params}`, { headers });
          if (!res.ok) return null;
          const body = await res.json() as { result: { name: string }[]; result_info?: { cursor?: string } };
          names.push(...body.result.map((k) => k.name));
          cursor = body.result_info?.cursor ?? "";
        } while (cursor);
        return names;
      } catch {
        return null;
      }
    },
  };
}

/** The record as a JSON object, or null for a legacy plain-string value. */
function parseRecord(value: string): Record<string, unknown> | null {
  try {
    const parsed: unknown = JSON.parse(value);
    return parsed && typeof parsed === "object" && !Array.isArray(parsed) ? parsed as Record<string, unknown> : null;
  } catch {
    return null;
  }
}

/** Mirror `status` into the key's KV record, keeping every other field. */
async function syncKvStatus(kv: Kv, hash: string, status: SettableStatus): Promise<KvSync> {
  const key = `${KV_KEY_PREFIX}${hash}`;
  const read = await kv.get(key);
  if (!read.ok) return "failed";
  if (read.value === null) return "missing";
  const record = parseRecord(read.value);
  if (!record) return "legacy";
  if (record.status === status) return "unchanged";
  return (await kv.put(key, JSON.stringify({ ...record, status }))) ? "updated" : "failed";
}

export function createApiKeysSetStatusHandler(deps: HandlerDeps): (req: Request) => Promise<Response> {
  return async (req: Request): Promise<Response> => {
    if (req.method !== "POST") return errorResponse("Method not allowed", 405);

    const supabaseUrl = deps.env("SUPABASE_URL")!;
    const presented = bearerToken(req);
    if (!presented || !(await isServiceCredential(deps.fetch, supabaseUrl, presented))) {
      return errorResponse("Unauthorized", 401);
    }

    let body: Record<string, unknown>;
    try {
      const parsed: unknown = await req.json();
      if (!parsed || typeof parsed !== "object" || Array.isArray(parsed)) return errorResponse("Body must be a JSON object", 400);
      body = parsed as Record<string, unknown>;
    } catch {
      return errorResponse("Body must be a JSON object", 400);
    }

    const cfAccountId = deps.env("CLOUDFLARE_ACCOUNT_ID");
    const cfApiToken = deps.env("CLOUDFLARE_API_TOKEN");
    const kvNamespaceId = deps.env("KV_NAMESPACE_ID");
    if (!cfAccountId || !cfApiToken || !kvNamespaceId) {
      return errorResponse("Server misconfigured: missing Cloudflare credentials", 500);
    }
    const kv = kvClient(deps.fetch, cfAccountId, cfApiToken, kvNamespaceId);
    const supabase = deps.createClient(supabaseUrl, deps.env("SUPABASE_SERVICE_ROLE_KEY")!, {
      global: { fetch: deps.fetch },
    });

    if (body.action === RECONCILE_ACTION) {
      return reconcile(kv, supabase, body.dryRun !== false, kvOnlyHashes(deps.env("KV_ONLY_KEY_HASHES")));
    }

    const { keyId, status } = body;
    if (typeof keyId !== "string" || !keyId) return errorResponse("keyId is required", 400);
    if (typeof status !== "string" || !SETTABLE.has(status)) {
      return errorResponse("status must be 'active' or 'inactive'", 400);
    }
    return setStatus(kv, supabase, keyId, status as SettableStatus);
  };
}

function kvOnlyHashes(raw: string | undefined): Set<string> {
  return new Set((raw ?? "").split(",").map((h) => h.trim().toLowerCase()).filter(Boolean));
}

// deno-lint-ignore no-explicit-any
async function setStatus(kv: Kv, supabase: any, keyId: string, status: SettableStatus): Promise<Response> {
  const { data: rows, error: readError } = await supabase
    .from("api_keys")
    .select("id,hash,status")
    .eq("id", keyId)
    .limit(1);
  if (readError) return errorResponse("Database error reading the key", 503);
  const row = rows?.[0];
  if (!row) return errorResponse("API key not found", 404);
  if (!SETTABLE.has(row.status)) {
    return errorResponse(`API key is ${row.status}; only active and inactive keys can be switched`, 409);
  }

  if (row.status !== status) {
    const { error: updateError } = await supabase.from("api_keys").update({ status }).eq("id", keyId);
    if (updateError) return errorResponse("Database error updating the key", 503);
  }

  const kvSync = await syncKvStatus(kv, row.hash, status);
  return jsonResponse({
    keyId,
    status,
    previousStatus: row.status,
    kv: kvSync,
    ...(kvSync === "failed" ? { warning: "Row updated but the KV record could not be; call again to retry." } : {}),
  });
}

interface Change {
  key: string;
  from: string | null;
  to: SettableStatus;
  reason: string;
  applied?: boolean;
}

// deno-lint-ignore no-explicit-any
async function reconcile(kv: Kv, supabase: any, dryRun: boolean, kvOnly: Set<string>): Promise<Response> {
  const names = await kv.list(KV_KEY_PREFIX);
  if (names === null) return errorResponse("Could not list the KV namespace", 502);

  const { data: rows, error } = await supabase.from("api_keys").select("hash,status");
  if (error) return errorResponse("Database error reading api_keys", 503);
  const statusByHash = new Map<string, string>((rows ?? []).map((r: { hash: string; status: string }) => [r.hash, r.status]));

  const changes: Change[] = [];
  let unchanged = 0;
  let legacy = 0;
  let failed = 0;

  for (const name of names) {
    const hash = name.slice(KV_KEY_PREFIX.length);
    const rowStatus = statusByHash.get(hash);
    const [to, reason]: [SettableStatus, string] = kvOnly.has(hash)
      ? ["active", "listed in KV_ONLY_KEY_HASHES"]
      : rowStatus === "active"
        ? ["active", "row is active"]
        : ["inactive", rowStatus ? `row is ${rowStatus}` : "no api_keys row"];

    const read = await kv.get(name);
    if (!read.ok) { failed++; continue; }
    if (read.value === null) continue; // deleted since the listing
    const record = parseRecord(read.value);
    if (!record) { legacy++; continue; }
    if (record.status === to) { unchanged++; continue; }

    const change: Change = {
      key: hash.slice(0, HASH_REPORT_CHARS),
      from: typeof record.status === "string" ? record.status : null,
      to,
      reason,
    };
    if (!dryRun) {
      change.applied = await kv.put(name, JSON.stringify({ ...record, status: to }));
      if (!change.applied) failed++;
    }
    changes.push(change);
  }

  return jsonResponse({ dryRun, scanned: names.length, unchanged, legacy, failed, changes });
}
