import { defineConfig, devices } from '@playwright/test';

/**
 * Playwright E2E test configuration for IntegrityStudio.ai
 *
 * Supports two modes:
 * - Local development: `npm test` (uses Flutter dev server on localhost:3000)
 * - Production/CI: `BASE_URL=https://integritystudio.ai npm test`
 *
 * For CI, set BASE_URL environment variable to test against deployed site.
 * Multi-browser testing runs on nightly schedule (MULTI_BROWSER=true).
 */
const BASE_URL = process.env.BASE_URL || 'http://localhost:3000';
const isLocalDev = !process.env.BASE_URL;
const isMultiBrowser = !!process.env.MULTI_BROWSER;

export default defineConfig({
  testDir: './tests',
  fullyParallel: true,
  forbidOnly: !!process.env.CI,
  retries: 0,
  workers: process.env.CI ? 4 : 1,
  reporter: process.env.CI ? 'html' : 'list',
  timeout: 120000,
  expect: {
    timeout: 15000,
  },
  use: {
    baseURL: BASE_URL,
    trace: 'on-first-retry',
    screenshot: 'only-on-failure',
    actionTimeout: 30000,
    navigationTimeout: 45000,
  },
  projects: [
    {
      name: 'chromium',
      use: {
        ...devices['Desktop Chrome'],
        bypassCSP: isLocalDev,
      },
    },
    // Multi-browser only on nightly schedule or explicit opt-in
    ...(isMultiBrowser
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
