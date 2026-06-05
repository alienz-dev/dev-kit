import { test, expect } from '@playwright/test';
import AxeBuilder from '@axe-core/playwright';

/**
 * Accessibility test — homepage.
 *
 * Uses axe-core to detect WCAG violations.
 * Requires: npm install -D @axe-core/playwright
 *
 * Filter by severity:
 *   .withTags(['wcag2a', 'wcag2aa'])           // WCAG level
 *   .disableRules(['duplicate-id'])             // Suppress known issues
 *   .include('#main-content')                   // Scope to element
 */

test('homepage has no accessibility violations', async ({ page }) => {
  await page.goto('/', { waitUntil: 'networkidle' });

  const results = await new AxeBuilder({ page })
    .withTags(['wcag2a', 'wcag2aa', 'wcag21a', 'wcag21aa'])
    .analyze();

  // Attach full results for debugging
  await test.info().attach('a11y-results', {
    body: JSON.stringify(results, null, 2),
    contentType: 'application/json',
  });

  expect(results.violations).toEqual([]);
});
