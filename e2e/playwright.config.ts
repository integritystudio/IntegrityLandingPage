import { defineConfig, devices } from '@playwright/test';

/**
 * Playwright E2E test configuration for IntegrityStudio.ai
 *
 * Supports two modes:
 * - Local development: `npm test` (uses Flutter dev server on localhost:3000)
 * - Production/CI: `BASE_URL=https://integritystudio.ai npm test`
 *
 * For CI, set BASE_URL environment variable to test against deployed site.
 */
const BASE_URL = process.env.BASE_URL || 'http://localhost:3000';
const isLocalDev = !process.env.BASE_URL;

export default defineConfig({
  testDir: './tests',
  fullyParallel: false,
  forbidOnly: !!process.env.CI,
  retries: process.env.CI ? 2 : 1, // Local retry reduces dev frustration
  workers: 1,
  reporter: process.env.CI ? 'html' : 'list',
  timeout: 180000, // 3 minutes per test (Flutter web is slow to load)
  expect: {
    timeout: 30000,
  },
  use: {
    baseURL: BASE_URL,
    trace: 'on-first-retry',
    screenshot: 'only-on-failure',
    actionTimeout: 60000,
    navigationTimeout: 60000,
  },
  projects: [
    {
      name: 'chromium',
      use: {
        ...devices['Desktop Chrome'],
        // Only bypass CSP in local dev - production tests should validate real CSP
        bypassCSP: isLocalDev,
      },
    },
    // Multi-browser testing for CI
    ...(process.env.CI
      ? [
          {
            name: 'firefox',
            use: {
              ...devices['Desktop Firefox'],
              bypassCSP: false,
            },
          },
          {
            name: 'webkit',
            use: {
              ...devices['Desktop Safari'],
              bypassCSP: false,
            },
          },
        ]
      : []),
  ],
  // Only start local server if not testing against production
  ...(isLocalDev
    ? {
        webServer: {
          command: 'flutter run -d chrome --web-port=3000',
          url: 'http://localhost:3000',
          reuseExistingServer: true,
          timeout: 120000,
        },
      }
    : {}),
});
