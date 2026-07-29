import { cloudflareTest } from "@cloudflare/vitest-pool-workers";
import { defineConfig } from "vitest/config";

/**
 * E2E config — runs the worker in the real workerd runtime via
 * @cloudflare/vitest-pool-workers, which is what provides the `cloudflare:test`
 * module the suite imports for `SELF` and `fetchMock`. A bare `defineConfig`
 * with no plugin cannot supply it, which is why this suite previously collected
 * zero tests.
 *
 * Note the shape: in the Vitest v4 line the pool is applied as a **Vite plugin**
 * (`cloudflareTest(...)`), not via `test.poolOptions.workers`, and there is no
 * `@cloudflare/vitest-pool-workers/config` entry point to import
 * `defineWorkersConfig` from — that export belongs to the v3 API. The package
 * ships a `vitest-v3-to-v4` codemod that performs exactly this rewrite.
 *
 * Bindings are declared here rather than sourced from Doppler or wrangler.toml
 * so the suite is hermetic: every outbound call is intercepted by `fetchMock`,
 * so the values only have to match the hosts the suite mocks, and no real
 * credential or deployed service is ever contacted.
 */

/** Must match the hosts `src/index.e2e.test.ts` sets up interceptors for. */
const E2E_AUTH0_DOMAIN = "e2e.auth0.test";
const E2E_SUPABASE_URL = "https://supabase.e2e.test";

/** Compatibility settings mirror wrangler.toml so behaviour matches production. */
const COMPATIBILITY_DATE = "2026-03-19";
const COMPATIBILITY_FLAGS = ["nodejs_compat"];

const RECEIVER_STUB_NAME = "receiver-stub";

/**
 * `fetchMock` intercepts global fetch, not service bindings, so `/send`'s
 * RECEIVER hop needs a real worker to talk to. This stub echoes the request
 * body back as `{ ok: true, received: body }`, which is the contract the
 * suite's `/send` cases assert against.
 */
const RECEIVER_STUB_SCRIPT = `
export default {
  async fetch(request) {
    const received = await request.json().catch(() => ({}));
    return Response.json({ ok: true, received });
  },
};
`;

export default defineConfig({
  plugins: [
    cloudflareTest({
      main: "src/index.ts",
      miniflare: {
        compatibilityDate: COMPATIBILITY_DATE,
        compatibilityFlags: COMPATIBILITY_FLAGS,
        bindings: {
          SHARED_SECRET: "e2e-shared-secret",
          AUTH0_DOMAIN: E2E_AUTH0_DOMAIN,
          AUTH0_CLIENT_ID: "e2e-auth0-client-id",
          AUTH0_CLIENT_SECRET: "e2e-auth0-client-secret",
          AUTH0_CLI_ID: "e2e-auth0-cli-id",
          AUTH0_CLI_SECRET: "e2e-auth0-cli-secret",
          AUTH0_AUDIENCE: `https://${E2E_AUTH0_DOMAIN}/api/v2/`,
          SUPABASE_URL: E2E_SUPABASE_URL,
          SUPABASE_SERVICE_ROLE_KEY: "e2e-service-role-key",
          STRIPE_SECRET_KEY: "sk_test_e2e",
          // Must cover every tier the suite requests checkout for.
          STRIPE_PLAN_TO_PRICE_JSON: JSON.stringify({
            starter: "price_e2e_starter",
            growth: "price_e2e_growth",
            pro: "price_e2e_pro",
            enterprise: "price_e2e_enterprise",
          }),
          APP_BASE_URL: "https://app.e2e.test",
        },
        kvNamespaces: ["RATE_LIMIT_KV"],
        serviceBindings: { RECEIVER: RECEIVER_STUB_NAME },
        workers: [
          {
            name: RECEIVER_STUB_NAME,
            modules: true,
            script: RECEIVER_STUB_SCRIPT,
            compatibilityDate: COMPATIBILITY_DATE,
          },
        ],
      },
    }),
  ],
  test: {
    include: ["src/**/*.e2e.test.ts"],
  },
});
