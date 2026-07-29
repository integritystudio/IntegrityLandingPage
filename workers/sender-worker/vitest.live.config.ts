import { defineConfig } from "vitest/config";

/**
 * Live-test config — the suite makes real Auth0 Management API calls against
 * whichever tenant the injected credentials belong to. `test:live` runs it with
 * Doppler's **prd** config, because the dev credentials are deliberately
 * powerless: `integrity-dev-ropc` has no `client_credentials` grant, so it
 * cannot mint a management token at all (BACKLOG.md CR11).
 *
 * `AUTH0_TEST_EMAIL` is overridden here, and the override is load-bearing. The
 * suite's lifecycle **deletes** any existing user matching that address in
 * `beforeAll`, creates a fresh one, then deletes it again in `afterAll`. Doppler
 * `prd` sets `AUTH0_TEST_EMAIL=test@integritystudio.ai` — a real account with
 * organization memberships and a Supabase `users` row keyed to its Auth0 `sub`.
 * Running against that address would destroy the account and orphan those rows
 * against a dead `sub`. Pointing the suite at its own disposable identity keeps
 * the lifecycle self-contained, which is what it was written to assume back when
 * `dev` and `prd` were the same tenant and the distinction did not exist.
 */

/** Disposable identity owned solely by this suite; safe to delete and recreate. */
const LIVE_SUITE_TEST_EMAIL = "auth0-live-suite@integritystudio.ai";

export default defineConfig({
  test: {
    globals: true,
    environment: "node",
    include: ["src/**/*.live.test.ts"],
    // Live tests hit real Auth0 — allow more time per test
    testTimeout: 15000,
    env: {
      AUTH0_TEST_EMAIL: LIVE_SUITE_TEST_EMAIL,
    },
  },
});
