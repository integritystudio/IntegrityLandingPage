import { defineWorkersConfig } from "@cloudflare/vitest-pool-workers/config";

export default defineWorkersConfig({
  test: {
    include: ["src/**/*.e2e.test.ts"],
    poolOptions: {
      workers: {
        wrangler: { configPath: "./wrangler.toml" },
        miniflare: {
          // Inject test-time secret values so the worker bindings are populated
          bindings: {
            SHARED_SECRET: "e2e-shared-secret",
            SUPABASE_URL: "https://supabase.e2e.test",
            SUPABASE_SERVICE_ROLE_KEY: "e2e-service-role-key",
            AUTH0_DOMAIN: "e2e.auth0.test",
            AUTH0_CLIENT_ID: "e2e-client-id",
            AUTH0_CLIENT_SECRET: "e2e-client-secret",
            AUTH0_AUDIENCE: "https://api.e2e.test",
          },
          // Stub receiver worker so the RECEIVER service binding resolves
          workers: [
            {
              name: "api-provisioning-receiver",
              modules: true,
              script: `export default {
                async fetch(request) {
                  if (request.method === "POST" && new URL(request.url).pathname === "/inbox") {
                    const body = await request.json();
                    return Response.json({ ok: true, received: body });
                  }
                  return Response.json({ error: "not found" }, { status: 404 });
                }
              }`,
            },
          ],
        },
      },
    },
  },
});
