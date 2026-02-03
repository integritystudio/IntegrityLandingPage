import { defineConfig, devices } from '@playwright/test';

export default defineConfig({
  testDir: './tests',
  fullyParallel: false,
  forbidOnly: !!process.env.CI,
  retries: 0,
  workers: 1,
  reporter: 'list',
  timeout: 180000, // 3 minutes per test (Flutter web is slow to load)
  expect: {
    timeout: 30000,
  },
  use: {
    baseURL: 'http://localhost:3000',
    trace: 'on-first-retry',
    screenshot: 'on',
    actionTimeout: 60000,
    navigationTimeout: 60000,
  },
  projects: [
    {
      name: 'chromium',
      use: {
        ...devices['Desktop Chrome'],
        // Bypass CSP for testing - Flutter web needs inline scripts
        bypassCSP: true,
      },
    },
  ],
  webServer: {
    command: 'flutter run -d chrome --web-port=3000',
    url: 'http://localhost:3000',
    reuseExistingServer: true,
    timeout: 120000,
  },
});
