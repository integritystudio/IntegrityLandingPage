/**
 * Live Auth0 e2e tests — make real HTTP calls to the Auth0 Management API.
 *
 * Requires Doppler env vars injected at runtime:
 *   AUTH0_DOMAIN, AUTH0_CLIENT_ID, AUTH0_CLIENT_SECRET, VITE_AUTH0_AUDIENCE
 *   AUTH0_TEST_EMAIL, AUTH0_TEST_PASSWORD, AUTH0_TEST_ORGANIZATION_ID
 *   AUTHO_ACCESS_TOKEN_API_KEY
 *
 * Test user lifecycle:
 *   beforeAll — acquire fresh mgmt token; delete stale test user if present; create fresh one
 *   afterAll  — delete the test user to keep the tenant clean
 *
 * Run via: npm run test:live
 */

import { describe, it, expect, beforeAll, afterAll } from "vitest";
// Imported explicitly rather than relied on as a global: the package's tsconfig loads only
// @cloudflare/workers-types, so `process` is deliberately absent from the Worker source in
// src/. This suite runs under Node (npm run test:live), so it can import it by name.
import process from "node:process";

// ─── Env ─────────────────────────────────────────────────────────────────────

const AUTH0_DOMAIN = process.env["AUTH0_DOMAIN"]!;
const AUTH0_CLIENT_ID = process.env["AUTH0_CLIENT_ID"]!;
const AUTH0_CLIENT_SECRET = process.env["AUTH0_CLIENT_SECRET"]!;
const AUDIENCE = process.env["VITE_AUTH0_AUDIENCE"]!;
const TEST_EMAIL = process.env["AUTH0_TEST_EMAIL"]!;
const TEST_PASSWORD = process.env["AUTH0_TEST_PASSWORD"]!;
const TEST_ORG_ID = process.env["AUTH0_TEST_ORGANIZATION_ID"]!;
const STORED_MGMT_TOKEN = process.env["AUTHO_ACCESS_TOKEN_API_KEY"] ?? "";

const MGMT_AUDIENCE = `https://${AUTH0_DOMAIN}/api/v2/`;
const MGMT_BASE = `https://${AUTH0_DOMAIN}/api/v2`;
const CONNECTION = "Username-Password-Authentication";

// ─── Shared state ────────────────────────────────────────────────────────────

let freshMgmtToken: string;
let createdUserId: string;

// ─── Helpers ─────────────────────────────────────────────────────────────────

async function fetchMgmtToken(): Promise<string> {
  const res = await fetch(`https://${AUTH0_DOMAIN}/oauth/token`, {
    method: "POST",
    headers: { "content-type": "application/json" },
    body: JSON.stringify({
      grant_type: "client_credentials",
      client_id: AUTH0_CLIENT_ID,
      client_secret: AUTH0_CLIENT_SECRET,
      audience: MGMT_AUDIENCE,
    }),
  });
  if (!res.ok) throw new Error(`Token exchange failed: ${res.status} ${await res.text()}`);
  const data = await res.json() as { access_token: string };
  return data.access_token;
}

async function findUserByEmail(token: string, email: string): Promise<string | null> {
  const q = encodeURIComponent(`email:"${email}"`);
  const res = await fetch(`${MGMT_BASE}/users?q=${q}&search_engine=v3`, {
    headers: { authorization: `Bearer ${token}` },
  });
  if (!res.ok) return null;
  const users = await res.json() as Array<{ user_id: string }>;
  return users[0]?.user_id ?? null;
}

async function deleteUser(token: string, userId: string): Promise<void> {
  await fetch(`${MGMT_BASE}/users/${encodeURIComponent(userId)}`, {
    method: "DELETE",
    headers: { authorization: `Bearer ${token}` },
  });
}

function isJwt(token: string): boolean {
  const parts = token.split(".");
  return parts.length === 3 && parts.every((p) => p.length > 0);
}

function jwtPayload(token: string): Record<string, unknown> {
  const base64 = token.split(".")[1]!.replace(/-/g, "+").replace(/_/g, "/");
  return JSON.parse(Buffer.from(base64, "base64").toString("utf8")) as Record<string, unknown>;
}

// ─── Setup / teardown ────────────────────────────────────────────────────────

beforeAll(async () => {
  freshMgmtToken = await fetchMgmtToken();

  // Delete any stale copy of the test user from a previous run
  const staleId = await findUserByEmail(freshMgmtToken, TEST_EMAIL);
  if (staleId) await deleteUser(freshMgmtToken, staleId);

  // Create the test user with TEST_ORG_ID stored in app_metadata
  const res = await fetch(`${MGMT_BASE}/users`, {
    method: "POST",
    headers: {
      "content-type": "application/json",
      authorization: `Bearer ${freshMgmtToken}`,
    },
    body: JSON.stringify({
      email: TEST_EMAIL,
      password: TEST_PASSWORD,
      connection: CONNECTION,
      email_verified: false,
      app_metadata: { organization_id: TEST_ORG_ID },
    }),
  });
  if (!res.ok) throw new Error(`Test user create failed: ${res.status} ${await res.text()}`);
  const user = await res.json() as { user_id: string };
  createdUserId = user.user_id;
});

afterAll(async () => {
  if (createdUserId) await deleteUser(freshMgmtToken, createdUserId);
});

// ─── Client credentials token exchange ───────────────────────────────────────

describe("Auth0 client credentials token exchange", () => {
  it("returns access_token with token_type Bearer", async () => {
    const res = await fetch(`https://${AUTH0_DOMAIN}/oauth/token`, {
      method: "POST",
      headers: { "content-type": "application/json" },
      body: JSON.stringify({
        grant_type: "client_credentials",
        client_id: AUTH0_CLIENT_ID,
        client_secret: AUTH0_CLIENT_SECRET,
        audience: MGMT_AUDIENCE,
      }),
    });
    expect(res.status).toBe(200);
    const body = await res.json() as { access_token: string; token_type: string };
    expect(body.access_token).toBeTruthy();
    expect(body.token_type).toBe("Bearer");
  });

  it("access_token is a well-formed 3-part JWT", async () => {
    expect(isJwt(freshMgmtToken)).toBe(true);
  });

  it("token audience matches the Management API", () => {
    const payload = jwtPayload(freshMgmtToken);
    expect(payload["aud"]).toBe(MGMT_AUDIENCE);
  });

  it("token sub matches the M2M client ({client_id}@clients)", () => {
    const payload = jwtPayload(freshMgmtToken);
    expect(payload["sub"]).toBe(`${AUTH0_CLIENT_ID}@clients`);
  });
});

// ─── AUTHO_ACCESS_TOKEN_API_KEY ───────────────────────────────────────────────

// The slot was cleared deliberately — it held a management token expired 241
// days, issued by a *different* tenant (BACKLOG.md CR01). These assertions
// only apply if someone repopulates it; the suite gets a fresh token in
// beforeAll regardless, so nothing here is load-bearing.
describe.skipIf(!STORED_MGMT_TOKEN)("AUTHO_ACCESS_TOKEN_API_KEY (stored Doppler management token)", () => {
  it("is a well-formed JWT", () => {
    expect(isJwt(STORED_MGMT_TOKEN)).toBe(true);
  });

  it("payload has iss, sub, aud, exp, iat fields matching this tenant", () => {
    const payload = jwtPayload(STORED_MGMT_TOKEN);
    expect(payload["iss"]).toBe(`https://${AUTH0_DOMAIN}/`);
    expect((payload["sub"] as string)).toContain("@clients");
    expect(payload["aud"]).toBe(MGMT_AUDIENCE);
    expect(typeof payload["exp"]).toBe("number");
    expect(typeof payload["iat"]).toBe("number");
  });

  it("reports token validity (informational — does not fail the suite)", () => {
    const { exp } = jwtPayload(STORED_MGMT_TOKEN) as { exp: number };
    const nowSec = Math.floor(Date.now() / 1000);
    if (nowSec > exp) {
      console.info(`AUTHO_ACCESS_TOKEN_API_KEY expired ${Math.round((nowSec - exp) / 3600)}h ago — refresh in Doppler`);
    } else {
      console.info(`AUTHO_ACCESS_TOKEN_API_KEY valid for ${Math.round((exp - nowSec) / 3600)}h`);
    }
    expect(typeof exp).toBe("number");
  });
});

// ─── Management API — test user ───────────────────────────────────────────────

describe("Auth0 Management API — test user (AUTH0_TEST_EMAIL)", () => {
  it("test user exists and email matches AUTH0_TEST_EMAIL", async () => {
    const res = await fetch(`${MGMT_BASE}/users/${encodeURIComponent(createdUserId)}`, {
      headers: { authorization: `Bearer ${freshMgmtToken}` },
    });
    expect(res.status).toBe(200);
    const user = await res.json() as { email: string };
    expect(user.email).toBe(TEST_EMAIL);
  });

  it("test user is on Username-Password-Authentication connection", async () => {
    const res = await fetch(`${MGMT_BASE}/users/${encodeURIComponent(createdUserId)}`, {
      headers: { authorization: `Bearer ${freshMgmtToken}` },
    });
    const user = await res.json() as { identities: Array<{ connection: string }> };
    expect(user.identities[0]?.connection).toBe(CONNECTION);
  });

  it("test user has an auth0| sub", () => {
    expect(createdUserId).toMatch(/^auth0\|/);
  });

  it("test user app_metadata contains AUTH0_TEST_ORGANIZATION_ID", async () => {
    const res = await fetch(`${MGMT_BASE}/users/${encodeURIComponent(createdUserId)}`, {
      headers: { authorization: `Bearer ${freshMgmtToken}` },
    });
    const user = await res.json() as { app_metadata: { organization_id: string } };
    expect(user.app_metadata.organization_id).toBe(TEST_ORG_ID);
  });
});

// ─── Resource Owner Password Grant ───────────────────────────────────────────

describe("Auth0 Resource Owner Password Grant — AUTH0_TEST_EMAIL + AUTH0_TEST_PASSWORD", () => {
  it("ROPG with test credentials succeeds or is disabled on this client", async () => {
    const res = await fetch(`https://${AUTH0_DOMAIN}/oauth/token`, {
      method: "POST",
      headers: { "content-type": "application/json" },
      body: JSON.stringify({
        grant_type: "password",
        client_id: AUTH0_CLIENT_ID,
        client_secret: AUTH0_CLIENT_SECRET,
        username: TEST_EMAIL,
        password: TEST_PASSWORD,
        audience: AUDIENCE,
        scope: "openid profile email",
        connection: CONNECTION,
      }),
    });

    if (res.status === 403 || res.status === 401) {
      const body = await res.json() as { error: string; error_description?: string };
      console.info(`ROPG not enabled: ${body.error_description ?? body.error}`);
      expect(["access_denied", "unauthorized_client"]).toContain(body.error);
      return;
    }

    expect(res.status).toBe(200);
    const token = await res.json() as { access_token: string; token_type: string };
    expect(token.access_token).toBeTruthy();
    expect(token.token_type).toBe("Bearer");
  });
});
