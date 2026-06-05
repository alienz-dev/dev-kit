import { defineConfig, devices } from '@playwright/test';

/**
 * Playwright config for visual regression + accessibility testing.
 *
 * Separates visual tests (*.visual.spec.ts) from functional tests (*.functional.spec.ts)
 * so they can be run independently.
 *
 * Usage:
 *   npx playwright test --project=visual           # Run visual regression only
 *   npx playwright test --project=visual --update-snapshots  # Update baselines
 *   npx playwright test --project=a11y             # Run accessibility only
 */
export default defineConfig({
  testDir: './tests',

  // Baseline storage: use BASELINE_DIR env var if set, otherwise default
  // Note: {arg} already includes the extension (e.g. 'homepage.png'), so no {ext}
  snapshotDir: process.env.BASELINE_DIR || undefined,
  snapshotPathTemplate: process.env.BASELINE_DIR
    ? '{snapshotDir}/{testFileName}-{arg}'
    : undefined,

  forbidOnly: !!process.env.CI,
  retries: process.env.CI ? 2 : 0,
  workers: process.env.CI ? 1 : undefined,

  reporter: [
    ['html', { outputFolder: 'playwright-report' }],
    ['junit', { outputFile: 'test-results/junit.xml' }],
    ['list'],
  ],

  projects: [
    // Visual regression tests — deterministic rendering
    {
      name: 'visual',
      testMatch: /.*\.visual\.spec\.ts/,
      use: {
        ...devices['Desktop Chrome'],
        // Deterministic rendering: no Retina, fixed viewport, no animations
        deviceScaleFactor: 1,
        viewport: { width: 1280, height: 720 },
      },
    },

    // Accessibility tests
    {
      name: 'a11y',
      testMatch: /.*\.a11y\.spec\.ts/,
      use: {
        ...devices['Desktop Chrome'],
        viewport: { width: 1280, height: 720 },
      },
    },

    // Functional tests (separate from visual)
    {
      name: 'functional',
      testMatch: /.*\.functional\.spec\.ts/,
      use: {
        ...devices['Desktop Chrome'],
        trace: 'on-first-retry',
      },
    },
  ],

  expect: {
    toHaveScreenshot: {
      // maxDiffPixelRatio: % of pixels allowed to differ (0.01 = 1%)
      maxDiffPixelRatio: parseFloat(process.env.VISUAL_THRESHOLD || '0.01'),
      // threshold: per-pixel color distance tolerance (0-1, where 0 = exact match)
      threshold: parseFloat(process.env.VISUAL_PIXEL_THRESHOLD || '0.2'),
      animations: 'disabled',
      scale: 'css',
    },
  },

  // No hardcoded ports — all configurable via environment variables.
  // Set DEV_SERVER_URL to your dev server URL. Gate scripts set this automatically.
  webServer: {
    command: process.env.DEV_COMMAND || 'npm run dev',
    url: process.env.DEV_SERVER_URL || 'http://localhost:3000',
    // Reuse existing server when DEV_SERVER_URL is set (gate scripts set this)
    // or when not in CI. In CI without DEV_SERVER_URL, start our own.
    reuseExistingServer: !!process.env.DEV_SERVER_URL || !process.env.CI,
  },
});
