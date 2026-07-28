import { defineConfig } from 'vitest/config';

const LIVE_TEST_TIMEOUT_MS = 15000;

export default defineConfig({
  test: {
    globals: true,
    environment: 'node',
    include: ['src/**/*.live.test.ts'],
    // Live tests cross the network to a deployed Worker — allow more time per test
    testTimeout: LIVE_TEST_TIMEOUT_MS,
  },
});
