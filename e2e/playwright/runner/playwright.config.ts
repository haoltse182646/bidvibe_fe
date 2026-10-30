import { defineConfig } from '@playwright/test';
import path from 'node:path';

process.env.E2E_RUN_ID ??= new Date().toISOString().replace(/[:.]/g, '-');
const run = process.env.E2E_RUN_ID;
const port = Number(process.env.BIDVIBE_WEB_PORT || '8886');
export default defineConfig({
  testDir: './tests',
  timeout: 90_000,
  expect: { timeout: 20_000 },
  fullyParallel: false,
  workers: 1,
  retries: 0,
  outputDir: `reports/${run}/artifacts`,
  reporter: [
    ['list'],
    ['html', { outputFolder: `reports/${run}/html`, open: 'never' }],
    ['json', { outputFile: `reports/${run}/results.json` }],
    ['junit', { outputFile: `reports/${run}/junit.xml` }],
  ],
  use: {
    actionTimeout: 20_000,
    navigationTimeout: 30_000,
    baseURL: process.env.BIDVIBE_WEB_URL || `http://localhost:${port}`,
    channel: 'chrome',
    viewport: { width: 1440, height: 1000 },
    locale: 'vi-VN',
    timezoneId: 'Asia/Ho_Chi_Minh',
    screenshot: 'only-on-failure',
    // Traces may contain credentials/network tokens. Enable selectively after
    // login in a business test; keep raw artifacts private.
    trace: 'off',
    video: 'off',
  },
  webServer: process.env.BIDVIBE_WEB_URL ? undefined : {
    command: 'node scripts/serve-web.mjs',
    url: `http://localhost:${port}`,
    reuseExistingServer: false,
    timeout: 30_000,
    cwd: path.resolve('.'),
  },
});

