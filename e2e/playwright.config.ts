import { defineConfig, devices } from '@playwright/test';
import {
  TEST_TIMEOUT_MS,
  EXPECT_TIMEOUT_MS,
  ACTION_TIMEOUT_MS,
  NAVIGATION_TIMEOUT_MS,
  WEB_SERVER_STARTUP_TIMEOUT_MS,
  IS_LOCAL_DEV,
} from './tests/constants';

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
const isMultiBrowser = !!process.env.MULTI_BROWSER;

export default defineConfig({
  testDir: './tests',
  fullyParallel: true,
  forbidOnly: !!process.env.CI,
  retries: process.env.CI ? 2 : 0,
  workers: process.env.CI ? 4 : 1,
  reporter: process.env.CI ? 'html' : 'list',
  timeout: TEST_TIMEOUT_MS,
  expect: {
    timeout: EXPECT_TIMEOUT_MS,
  },
  use: {
    baseURL: BASE_URL,
    trace: 'on-first-retry',
    screenshot: 'only-on-failure',
    actionTimeout: ACTION_TIMEOUT_MS,
    navigationTimeout: NAVIGATION_TIMEOUT_MS,
  },
  projects: [
    {
      name: 'chromium',
      use: {
        ...devices['Desktop Chrome'],
        bypassCSP: IS_LOCAL_DEV,
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
  ...(IS_LOCAL_DEV
    ? {
        webServer: {
          command: 'flutter run -d chrome --web-port=3000',
          url: 'http://localhost:3000',
          reuseExistingServer: true,
          timeout: WEB_SERVER_STARTUP_TIMEOUT_MS,
        },
      }
    : {}),
});
