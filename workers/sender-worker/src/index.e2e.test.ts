/**
 * E2E tests for sender-worker — runs in the workerd runtime via @cloudflare/vitest-pool-workers.
 *
 * Uses SELF.fetch() to make real HTTP requests to the worker and fetchMock to
 * intercept outbound calls to Auth0 and Supabase, verifying the full request
 * pipeline including routing, CORS headers, body parsing, and error responses.
 */

import { describe, it, expect, beforeAll, afterEach } from "vitest";
import { SELF, fetchMock } from "cloudflare:test";

const AUTH0_DOMAIN = "e2e.auth0.test";
const SUPABASE_URL = "https://supabase.e2e.test";

// Activate fetchMock once for the suite; reset mocks after each test
beforeAll(() => fetchMock.activate());
afterEach(() => fetchMock.assertNoPendingInterceptors());

// ─── Helpers ────────────────────────────────────────────────────────────────

function mockTokenExchange(accessToken = "test-mgmt-token"): void {
  fetchMock
    .get(`https://${AUTH0_DOMAIN}`)
    .intercept({ path: "/oauth/token", method: "POST" })
    .reply(200, JSON.stringify({ access_token: accessToken }), {
      headers: { "content-type": "application/json" },
    });
}

function mockAuth0CreateUser(auth0Sub: string): void {
  fetchMock
    .get(`https://${AUTH0_DOMAIN}`)
    .intercept({ path: "/api/v2/users", method: "POST" })
    .reply(201, JSON.stringify({ user_id: auth0Sub }), {
      headers: { "content-type": "application/json" },
    });
}

function mockSupabaseOrg(orgId: string): void {
  fetchMock
    .get(SUPABASE_URL)
    .intercept({ path: "/rest/v1/organizations", method: "POST" })
    .reply(201, JSON.stringify([{ id: orgId }]), {
      headers: { "content-type": "application/json" },
    });
}

function mockSupabaseUsersInsert(): void {
  fetchMock
    .get(SUPABASE_URL)
    .intercept({ path: "/rest/v1/users", method: "POST" })
    .reply(201, "");
}

function mockSupabaseOrgMemberships(): void {
  fetchMock
    .get(SUPABASE_URL)
    .intercept({ path: "/rest/v1/organization_memberships", method: "POST" })
    .reply(201, "");
}

function mockFullSignupFlow(auth0Sub = "auth0|e2e-user", orgId = "org-e2e-uuid"): void {
  mockTokenExchange();
  mockAuth0CreateUser(auth0Sub);
  mockSupabaseOrg(orgId);
  mockSupabaseUsersInsert();
  mockSupabaseOrgMemberships();
}

// ─── POST /signup — success path ────────────────────────────────────────────

describe("POST /signup — success", () => {
  it("returns 201 with auth0Sub, userId, and email on valid signup", async () => {
    mockFullSignupFlow("auth0|e2e-abc123", "org-uuid-e2e-1");

    const res = await SELF.fetch("https://worker.test/signup", {
      method: "POST",
      headers: { "content-type": "application/json" },
      body: JSON.stringify({ email: "e2e@example.com", password: "S3cur3!pass" }),
    });

    expect(res.status).toBe(201);
    const body = await res.json() as { auth0Sub: string; userId: string; email: string };
    expect(body.auth0Sub).toBe("auth0|e2e-abc123");
    expect(body.userId).toMatch(/^[0-9a-f-]{36}$/);
    expect(body.email).toBe("e2e@example.com");
  });

  it("auth0Sub differs from userId — Auth0 sub is stored as auth0_id, not the Supabase UUID", async () => {
    mockFullSignupFlow("auth0|distinct-sub", "org-uuid-e2e-2");

    const res = await SELF.fetch("https://worker.test/signup", {
      method: "POST",
      headers: { "content-type": "application/json" },
      body: JSON.stringify({ email: "e2e2@example.com", password: "S3cur3!pass" }),
    });

    const body = await res.json() as { auth0Sub: string; userId: string };
    expect(body.auth0Sub).not.toBe(body.userId);
    expect(body.auth0Sub).toBe("auth0|distinct-sub");
  });

  it("response content-type is application/json", async () => {
    mockFullSignupFlow("auth0|ct-test", "org-uuid-ct");

    const res = await SELF.fetch("https://worker.test/signup", {
      method: "POST",
      headers: { "content-type": "application/json" },
      body: JSON.stringify({ email: "ct@example.com", password: "S3cur3!pass" }),
    });

    expect(res.headers.get("content-type")).toContain("application/json");
  });
});

// ─── POST /signup — token exchange failure ───────────────────────────────────

describe("POST /signup — Auth0 token exchange failure", () => {
  it("returns 500 when /oauth/token call fails", async () => {
    fetchMock
      .get(`https://${AUTH0_DOMAIN}`)
      .intercept({ path: "/oauth/token", method: "POST" })
      .reply(401, JSON.stringify({ error: "unauthorized_client" }), {
        headers: { "content-type": "application/json" },
      });

    const res = await SELF.fetch("https://worker.test/signup", {
      method: "POST",
      headers: { "content-type": "application/json" },
      body: JSON.stringify({ email: "fail@example.com", password: "S3cur3!pass" }),
    });

    expect(res.status).toBe(500);
    const body = await res.json() as { error: string };
    expect(body.error).toBe("signup failed");
  });

  it("returns 500 when /oauth/token returns no access_token", async () => {
    fetchMock
      .get(`https://${AUTH0_DOMAIN}`)
      .intercept({ path: "/oauth/token", method: "POST" })
      .reply(200, JSON.stringify({}), {
        headers: { "content-type": "application/json" },
      });

    const res = await SELF.fetch("https://worker.test/signup", {
      method: "POST",
      headers: { "content-type": "application/json" },
      body: JSON.stringify({ email: "notoken@example.com", password: "S3cur3!pass" }),
    });

    expect(res.status).toBe(500);
    const body = await res.json() as { error: string };
    expect(body.error).toBe("signup failed");
  });
});

// ─── POST /signup — Auth0 user create failure ────────────────────────────────

describe("POST /signup — Auth0 user create failure", () => {
  it("returns 500 when /api/v2/users returns 409 conflict", async () => {
    mockTokenExchange();
    fetchMock
      .get(`https://${AUTH0_DOMAIN}`)
      .intercept({ path: "/api/v2/users", method: "POST" })
      .reply(409, JSON.stringify({ message: "The user already exists." }), {
        headers: { "content-type": "application/json" },
      });

    const res = await SELF.fetch("https://worker.test/signup", {
      method: "POST",
      headers: { "content-type": "application/json" },
      body: JSON.stringify({ email: "dupe@example.com", password: "S3cur3!pass" }),
    });

    expect(res.status).toBe(500);
    const body = await res.json() as { error: string };
    expect(body.error).toBe("signup failed");
  });

  it("returns 500 when /api/v2/users returns no user_id", async () => {
    mockTokenExchange();
    fetchMock
      .get(`https://${AUTH0_DOMAIN}`)
      .intercept({ path: "/api/v2/users", method: "POST" })
      .reply(201, JSON.stringify({}), {
        headers: { "content-type": "application/json" },
      });

    const res = await SELF.fetch("https://worker.test/signup", {
      method: "POST",
      headers: { "content-type": "application/json" },
      body: JSON.stringify({ email: "noid@example.com", password: "S3cur3!pass" }),
    });

    expect(res.status).toBe(500);
    const body = await res.json() as { error: string };
    expect(body.error).toBe("signup failed");
  });
});

// ─── POST /signup — request validation ──────────────────────────────────────

describe("POST /signup — validation", () => {
  it("returns 400 when email is missing", async () => {
    const res = await SELF.fetch("https://worker.test/signup", {
      method: "POST",
      headers: { "content-type": "application/json" },
      body: JSON.stringify({ password: "S3cur3!pass" }),
    });

    expect(res.status).toBe(400);
    const body = await res.json() as { error: string };
    expect(body.error).toContain("email");
  });

  it("returns 400 when password is missing", async () => {
    const res = await SELF.fetch("https://worker.test/signup", {
      method: "POST",
      headers: { "content-type": "application/json" },
      body: JSON.stringify({ email: "user@example.com" }),
    });

    expect(res.status).toBe(400);
    const body = await res.json() as { error: string };
    expect(body.error).toContain("password");
  });

  it("returns 400 for malformed email", async () => {
    const res = await SELF.fetch("https://worker.test/signup", {
      method: "POST",
      headers: { "content-type": "application/json" },
      body: JSON.stringify({ email: "not-an-email", password: "S3cur3!pass" }),
    });

    expect(res.status).toBe(400);
    const body = await res.json() as { error: string };
    expect(body.error).toContain("email");
  });

  it("returns 400 for invalid JSON body", async () => {
    const res = await SELF.fetch("https://worker.test/signup", {
      method: "POST",
      headers: { "content-type": "application/json" },
      body: "{ bad json",
    });

    expect(res.status).toBe(400);
    const body = await res.json() as { error: string };
    expect(body.error).toContain("json");
  });
});

// ─── POST /signin — not implemented ─────────────────────────────────────────

describe("POST /signin — not implemented", () => {
  it("returns 404 — sign-in is handled by Auth0 directly", async () => {
    const res = await SELF.fetch("https://worker.test/signin", {
      method: "POST",
      headers: { "content-type": "application/json" },
      body: JSON.stringify({ email: "user@example.com", password: "pass" }),
    });

    expect(res.status).toBe(404);
    const body = await res.json() as { error: string };
    expect(body.error).toContain("Auth0");
  });
});

// ─── GET /health ─────────────────────────────────────────────────────────────

describe("GET /health", () => {
  it("returns 200 with ok: true and service name", async () => {
    const res = await SELF.fetch("https://worker.test/health");
    expect(res.status).toBe(200);
    const body = await res.json() as { ok: boolean; service: string };
    expect(body.ok).toBe(true);
    expect(body.service).toBe("api-provisioning-sender");
  });
});

// ─── CORS — preflight ────────────────────────────────────────────────────────

describe("CORS — OPTIONS preflight", () => {
  it("returns 204 with CORS headers for allowed origin", async () => {
    const res = await SELF.fetch("https://worker.test/signup", {
      method: "OPTIONS",
      headers: { origin: "https://integritystudio.ai" },
    });

    expect(res.status).toBe(204);
    expect(res.headers.get("access-control-allow-origin")).toBe("https://integritystudio.ai");
    expect(res.headers.get("access-control-allow-methods")).toContain("POST");
  });

  it("returns 204 without access-control-allow-origin for disallowed origin", async () => {
    const res = await SELF.fetch("https://worker.test/signup", {
      method: "OPTIONS",
      headers: { origin: "https://evil.example.com" },
    });

    expect(res.status).toBe(204);
    expect(res.headers.get("access-control-allow-origin")).toBeNull();
  });
});

// ─── CORS — POST requests ────────────────────────────────────────────────────

describe("CORS — POST from disallowed origin", () => {
  it("returns 403 for POST from disallowed origin", async () => {
    const res = await SELF.fetch("https://worker.test/signup", {
      method: "POST",
      headers: {
        "content-type": "application/json",
        origin: "https://evil.example.com",
      },
      body: JSON.stringify({ email: "x@x.com", password: "pass" }),
    });

    expect(res.status).toBe(403);
    const body = await res.json() as { error: string };
    expect(body.error).toBe("forbidden");
  });

  it("includes access-control-allow-origin on 201 response for allowed origin", async () => {
    mockFullSignupFlow("auth0|cors-test", "org-cors-uuid");

    const res = await SELF.fetch("https://worker.test/signup", {
      method: "POST",
      headers: {
        "content-type": "application/json",
        origin: "https://integritystudio.ai",
      },
      body: JSON.stringify({ email: "cors@example.com", password: "S3cur3!pass" }),
    });

    expect(res.status).toBe(201);
    expect(res.headers.get("access-control-allow-origin")).toBe("https://integritystudio.ai");
  });
});
