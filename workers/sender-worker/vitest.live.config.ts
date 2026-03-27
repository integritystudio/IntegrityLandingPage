import { defineConfig } from "vitest/config";

export default defineConfig({
  test: {
    globals: true,
    environment: "node",
    include: ["src/**/*.live.test.ts"],
    // Live tests hit real Auth0 — allow more time per test
    testTimeout: 15000,
  },
});
