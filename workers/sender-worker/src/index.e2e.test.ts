/**
 * E2E tests for sender-worker — runs in the workerd runtime via @cloudflare/vitest-pool-workers.
 *
 * Uses SELF.fetch() to make real HTTP requests to the worker and fetchMock to
 * intercept outbound calls (Stripe; the Supabase org lookup is left unmocked and
 * fails best-effort), verifying the full request pipeline including routing,
 * CORS headers, body parsing, and error responses.
 */

import { describe, it, expect, beforeAll, afterEach } from "vitest";
import { SELF } from "cloudflare:test";
// `fetchMock` was removed from `cloudflare:test` in the pool's Vitest v4 line;
// `./e2e-fetch-mock` reimplements the slice of that API this suite uses.
import { fetchMock } from "./e2e-fetch-mock";

// Activate fetchMock once for the suite; reset mocks after each test
beforeAll(() => fetchMock.activate());
afterEach(() => fetchMock.assertNoPendingInterceptors());

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

// ─── POST /send — provision_api_key ─────────────────────────────────────────

const validSendPayload = {
  action: "provision_api_key",
  jwt: "eyJhbGciOiJSUzI1NiIsInR5cCI6IkpXVCJ9.eyJzdWIiOiJ1c2VyMTIzIn0.signature",
  name: "My API Key",
  email: "user@example.com",
  tier: "starter",
};

// POST /send uses the RECEIVER service binding (stub worker defined in vitest.e2e.config.ts),
// so no fetchMock is needed — the stub worker echoes back { ok: true, received: body }.

describe("POST /send — valid provision_api_key", () => {
  it("forwards to receiver /inbox and returns 200", async () => {
    const res = await SELF.fetch("https://worker.test/send", {
      method: "POST",
      headers: { "content-type": "application/json" },
      body: JSON.stringify(validSendPayload),
    });
    expect(res.status).toBe(200);
    const body = await res.json() as { ok: boolean };
    expect(body.ok).toBe(true);
  });

  it("defaults tier to starter when absent", async () => {
    const { tier: _t, ...noTier } = validSendPayload;
    const res = await SELF.fetch("https://worker.test/send", {
      method: "POST",
      headers: { "content-type": "application/json" },
      body: JSON.stringify(noTier),
    });
    expect(res.status).toBe(200);
  });

  it("includes org_name when provided", async () => {
    const res = await SELF.fetch("https://worker.test/send", {
      method: "POST",
      headers: { "content-type": "application/json" },
      body: JSON.stringify({ ...validSendPayload, org_name: "Acme Corp" }),
    });
    expect(res.status).toBe(200);
  });

  // CR29 step 2: the real receiver 401s a request with no x-key-id, and its rejection is
  // byte-identical to a forged signature — so a header that silently went missing would look
  // like an attack, not a bug. Asserted here rather than only in the unit tests because this
  // runs in workerd: it proves the header survives the actual service-binding subrequest.
  it("sends x-key-id on the forwarded request", async () => {
    const res = await SELF.fetch("https://worker.test/send", {
      method: "POST",
      headers: { "content-type": "application/json" },
      body: JSON.stringify(validSendPayload),
    });
    expect(res.status).toBe(200);
    const body = await res.json() as { keyId: string | null };
    expect(body.keyId).toBe("v2");
  });
});

describe("POST /send — validation", () => {
  it("returns 400 when action is missing (treated as unknown action)", async () => {
    const { action: _a, ...noAction } = validSendPayload;
    const res = await SELF.fetch("https://worker.test/send", {
      method: "POST",
      headers: { "content-type": "application/json" },
      body: JSON.stringify(noAction),
    });
    expect(res.status).toBe(400);
    expect((await res.json() as { error: string }).error).toContain("unknown action");
  });

  it("returns 400 for unknown action", async () => {
    const res = await SELF.fetch("https://worker.test/send", {
      method: "POST",
      headers: { "content-type": "application/json" },
      body: JSON.stringify({ ...validSendPayload, action: "bad_action" }),
    });
    expect(res.status).toBe(400);
    expect((await res.json() as { error: string }).error).toContain("unknown action");
  });

  it("returns 401 when jwt is missing", async () => {
    const { jwt: _j, ...noJwt } = validSendPayload;
    const res = await SELF.fetch("https://worker.test/send", {
      method: "POST",
      headers: { "content-type": "application/json" },
      body: JSON.stringify(noJwt),
    });
    expect(res.status).toBe(401);
    expect((await res.json() as { error: string }).error).toContain("jwt");
  });

  it("returns 400 when name is missing", async () => {
    const { name: _n, ...noName } = validSendPayload;
    const res = await SELF.fetch("https://worker.test/send", {
      method: "POST",
      headers: { "content-type": "application/json" },
      body: JSON.stringify(noName),
    });
    expect(res.status).toBe(400);
    expect((await res.json() as { error: string }).error).toContain("name");
  });

  it("returns 400 when email is missing", async () => {
    const { email: _e, ...noEmail } = validSendPayload;
    const res = await SELF.fetch("https://worker.test/send", {
      method: "POST",
      headers: { "content-type": "application/json" },
      body: JSON.stringify(noEmail),
    });
    expect(res.status).toBe(400);
    expect((await res.json() as { error: string }).error).toContain("email");
  });

  it("returns 400 for invalid email format", async () => {
    const res = await SELF.fetch("https://worker.test/send", {
      method: "POST",
      headers: { "content-type": "application/json" },
      body: JSON.stringify({ ...validSendPayload, email: "not-an-email" }),
    });
    expect(res.status).toBe(400);
    expect((await res.json() as { error: string }).error).toContain("email");
  });
});

// ─── CORS — preflight ────────────────────────────────────────────────────────

describe("CORS — OPTIONS preflight", () => {
  it("returns 204 with CORS headers for allowed origin", async () => {
    const res = await SELF.fetch("https://worker.test/send", {
      method: "OPTIONS",
      headers: { origin: "https://integritystudio.ai" },
    });

    expect(res.status).toBe(204);
    expect(res.headers.get("access-control-allow-origin")).toBe("https://integritystudio.ai");
    expect(res.headers.get("access-control-allow-methods")).toContain("POST");
  });

  it("returns 204 without access-control-allow-origin for disallowed origin", async () => {
    const res = await SELF.fetch("https://worker.test/send", {
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
    const res = await SELF.fetch("https://worker.test/send", {
      method: "POST",
      headers: {
        "content-type": "application/json",
        origin: "https://evil.example.com",
      },
      body: JSON.stringify(validSendPayload),
    });

    expect(res.status).toBe(403);
    const body = await res.json() as { error: string };
    expect(body.error).toBe("forbidden");
  });

  it("includes access-control-allow-origin on 200 response for allowed origin", async () => {
    const res = await SELF.fetch("https://worker.test/send", {
      method: "POST",
      headers: {
        "content-type": "application/json",
        origin: "https://integritystudio.ai",
      },
      body: JSON.stringify(validSendPayload),
    });

    expect(res.status).toBe(200);
    expect(res.headers.get("access-control-allow-origin")).toBe("https://integritystudio.ai");
  });
});
