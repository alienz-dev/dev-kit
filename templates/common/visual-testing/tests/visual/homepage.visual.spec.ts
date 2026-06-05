import { test, expect } from '@playwright/test';

/**
 * Visual regression test — homepage.
 *
 * Baseline screenshots are stored in tests/visual/homepage.visual.spec.ts-snapshots/.
 * Update baselines after intentional changes:
 *   npx playwright test --project=visual --update-snapshots
 *
 * To mask dynamic content (user avatars, timestamps, etc.):
 *   await expect(page).toHaveScreenshot('homepage.png', {
 *     mask: [page.locator('.user-avatar')],
 *     maskColor: '#C0FFEE',
 *   });
 */

test('homepage renders correctly', async ({ page }) => {
  await page.goto('/', { waitUntil: 'networkidle' });
  await expect(page).toHaveScreenshot('homepage.png', {
    fullPage: true,
  });
});

test('homepage header renders correctly', async ({ page }) => {
  await page.goto('/', { waitUntil: 'networkidle' });
  await expect(page.locator('header')).toHaveScreenshot('homepage-header.png');
});
