import { defineConfig } from 'vitest/config';

export default defineConfig({
  test: {
    globals: true,
    environment: 'node',
    include: ['src/**/*.test.ts'],
    exclude: ['node_modules', 'src/**/*.e2e.test.ts', 'src/**/*.live.test.ts'],
  },
});
