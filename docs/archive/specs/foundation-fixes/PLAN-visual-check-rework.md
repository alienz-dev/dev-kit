# Plan: UI Visual Check — Playwright-based 3-Layer Architecture

> Derived from SPEC-012. Defines HOW + ORDER.

## Approach

Build bottom-up: first remove the dead submodule, then implement Layer 2 (Playwright visual regression) as the core value, then Layer 3 (axe-core accessibility), then wire everything into scaffold.sh and update docs. Each phase is independently testable and shippable.

## Phase 1: Cleanup — Remove Dead Submodule

### Step 1.1: Remove ui-visual-check submodule
**Files:** `.gitmodules`, `tools/ui-visual-check/`
**Action:**
- `git submodule deinit tools/ui-visual-check`
- `git rm tools/ui-visual-check`
- Remove the `[submodule "ui-visual-check"]` section from `.gitmodules`
- Verify `.gitmodules` only contains `issue-cli`

### Step 1.2: Remove design-system/ directory
**Files:** `tools/design-system/README.md`
**Action:**
- Delete `tools/design-system/` entirely
- The design iteration concept (screenshot → grade → iterate) will be absorbed into Layer 2's AI review

### Step 1.3: Update references to removed components
**Files:** `README.md`, `CLAUDE.md`
**Action:**
- Remove `tools/ui-visual-check/` from README directory structure listing
- Remove `tools/design-system/` from README directory structure listing
- Remove `ui-visual-check` from CLAUDE.md key files list
- Add `quality/gates/visual-regression.sh` and `quality/gates/accessibility-check.sh` to relevant listings

## Phase 2: Layer 2 — Playwright Visual Regression Gate

### Step 2.1: Create visual-regression.sh
**Files:** `quality/gates/visual-regression.sh`
**Action:**
Create a bash gate script with this interface:
```bash
# Usage modes:
visual-regression.sh --url <dev-server>                    # Run visual regression
visual-regression.sh --url <dev-server> --update-baselines # Update baselines
visual-regression.sh --files <ui-files> --url <dev-server> # Specific files only
visual-regression.sh --gate --url <dev-server> --design DESIGN.md  # Gate mode with AI review

# Flags:
--url <url>              # Dev server URL (required for Layers 2/3)
--files <glob>           # UI files to check (default: all)
--baseline <dir>         # Baseline directory (default: screenshots/baselines)
--threshold <0-1>        # Max diff pixel ratio (default: 0.01)
--update-baselines       # Capture new baselines instead of comparing
--gate                   # Gate mode: exit 1 on regression
--design <path>          # DESIGN.md path for AI review context
--vision-endpoint <url>  # Vision model API endpoint for AI review
```

Implementation pattern (based on research):
```bash
#!/usr/bin/env bash
set -euo pipefail

PROJECT="${VISUAL_PROJECT:-visual}"
REPORT_DIR="${REPORT_DIR:-playwright-report}"
RESULT_DIR="${RESULT_DIR:-test-results}"

CMD="npx playwright test --project=${PROJECT}"
if [[ "${UPDATE_SNAPSHOTS:-}" == "true" ]]; then
  CMD="${CMD} --update-snapshots"
fi

set +e
OUTPUT=$($CMD 2>&1)
EXIT_CODE=$?
set -e

echo "$OUTPUT"

# Parse Playwright summary: "X passed, Y failed, Z skipped"
PASSED=$(echo "$OUTPUT" | grep -oE '[0-9]+ passed' | head -1 | grep -oE '[0-9]+' || echo "0")
FAILED=$(echo "$OUTPUT" | grep -oE '[0-9]+ failed' | head -1 | grep -oE '[0-9]+' || echo "0")

# List diff images for review
find "$RESULT_DIR" -name "*-diff.png" 2>/dev/null | while read -r f; do
  echo "DIFF: $f"
done

if [[ $EXIT_CODE -ne 0 ]]; then
  echo "FAILED -- visual regressions detected"
  echo "Update baselines: npx playwright test --project=${PROJECT} --update-snapshots"
  echo "View report: npx playwright show-report ${REPORT_DIR}"
  exit 1
fi
echo "PASSED -- all visual snapshots match"
exit 0
```

If diffs found and `--vision-endpoint` set: send baseline + actual + diff images to vision model via curl, parse JSON response, classify as `intentional`/`regression`/`ambiguous`.

### Step 2.2: Create Playwright config template
**Files:** `templates/common/visual-testing/playwright.config.ts`
**Action:**
Create a Playwright config optimized for visual testing with deterministic rendering:
```typescript
import { defineConfig, devices } from '@playwright/test';

export default defineConfig({
  testDir: './tests',
  forbidOnly: !!process.env.CI,
  retries: process.env.CI ? 2 : 0,
  workers: process.env.CI ? 1 : undefined,

  reporter: [
    ['html', { outputFolder: 'playwright-report' }],
    ['junit', { outputFile: 'test-results/junit.xml' }],
  ],

  projects: [
    // Functional tests (separate from visual)
    {
      name: 'functional',
      testMatch: /.*\.functional\.spec\.ts/,
      use: { ...devices['Desktop Chrome'], trace: 'on-first-retry' },
    },

    // Visual regression tests — deterministic rendering
    {
      name: 'visual',
      testMatch: /.*\.visual\.spec\.ts/,
      use: {
        ...devices['Desktop Chrome'],
        deviceScaleFactor: 1,           // Consistent pixel density
        viewport: { width: 1280, height: 720 },  // Fixed viewport
      },
    },
  ],

  expect: {
    toHaveScreenshot: {
      maxDiffPixelRatio: 0.01,  // 1% pixel tolerance for anti-aliasing
      threshold: 0.2,           // Per-pixel color diff tolerance
      animations: 'disabled',   // Freeze CSS animations
      scale: 'css',             // CSS pixels, not device pixels
    },
  },

  webServer: {
    command: 'npm run dev',
    url: 'http://localhost:3000',
    reuseExistingServer: !process.env.CI,
  },
});
```

Key research findings applied:
- `deviceScaleFactor: 1` prevents Retina/HiDPI rendering differences
- `animations: 'disabled'` freezes CSS transitions/animations for deterministic frames
- `scale: 'css'` ensures consistent pixel measurement across displays
- Separate `visual` project via `testMatch` keeps visual and functional tests isolated
- Platform-specific baselines: snapshot filenames include `{browser}-{platform}`, so CI should use Docker (`mcr.microsoft.com/playwright:v1.60.0-noble`) for consistency
- `.gitignore`: track `*-snapshots/` (baselines), ignore `test-results/` and `playwright-report/`

### Step 2.3: Create example visual test template
**Files:** `templates/common/visual-testing/tests/visual/homepage.spec.ts`
**Action:**
```typescript
import { test, expect } from '@playwright/test';

test('homepage renders correctly', async ({ page }) => {
  await page.goto('/');
  await expect(page).toHaveScreenshot('homepage.png', {
    fullPage: true,
    maxDiffPixelRatio: 0.01,
  });
});

test('homepage is accessible', async ({ page }) => {
  await page.goto('/');
  // Layer 3: axe-core integration (add @axe-core/playwright)
  // const { AxeBuilder } = require('@axe-core/playwright');
  // const results = await new AxeBuilder({ page }).analyze();
  // expect(results.violations).toEqual([]);
});
```

### Step 2.4: Create visual-regression test suite
**Files:** `quality/gates/__tests__/visual-regression.test.sh`
**Action:**
Test cases:
- Baseline capture creates PNG files
- No-diff run exits 0
- Diff exceeding threshold exits 1 in gate mode
- `--update-baselines` overwrites existing baselines
- Missing dev server exits 2 with clear message
- `--threshold` flag adjusts tolerance

## Phase 3: Layer 3 — Accessibility Gate

### Step 3.1: Create accessibility-check.sh
**Files:** `quality/gates/accessibility-check.sh`
**Action:**
Create a bash gate script:
```bash
# Usage:
accessibility-check.sh --url <dev-server>                    # Run all pages
accessibility-check.sh --url <dev-server> --files <ui-files> # Specific pages
accessibility-check.sh --gate --url <dev-server>              # Gate mode

# Flags:
--url <url>         # Dev server URL (required)
--files <glob>      # Map UI files to routes (optional)
--severity <level>  # Minimum severity: critical, serious, moderate, minor (default: serious)
--gate              # Gate mode: exit 1 on violations
--output <path>     # JSON report output path
```

Implementation uses `@axe-core/playwright` AxeBuilder API:
```typescript
import AxeBuilder from '@axe-core/playwright';

const results = await new AxeBuilder({ page })
  .withTags(['wcag2a', 'wcag2aa', 'wcag21a', 'wcag21aa'])
  .exclude('.third-party-widget')  // Exclude known non-owned content
  .analyze();

// Results structure:
// violations[].id          — rule ID e.g. 'color-contrast'
// violations[].impact      — 'minor' | 'moderate' | 'serious' | 'critical'
// violations[].nodes[].target[]  — CSS selectors
// violations[].nodes[].failureSummary — what's wrong
// violations[].helpUrl     — axe-core docs link
```

Key rules axe-core catches (~90+ total):
- Color contrast failures (WCAG 1.4.3)
- Missing alt text, form labels, ARIA attributes
- Duplicate IDs, invalid lang attributes
- Missing button/link text, keyboard traps
- Heading hierarchy violations

Shell wrapper: create Playwright test dynamically, run it, parse JSON output, filter by `--severity`, exit 0/1.

### Step 3.2: Create accessibility-check test suite
**Files:** `quality/gates/__tests__/accessibility-check.test.sh`
**Action:**
Test cases:
- Clean page exits 0
- Page with violations exits 1 in gate mode
- `--severity serious` filters out minor violations
- Missing dev server exits 2
- JSON output format is valid

## Phase 4: Gate Composition and Integration

### Step 4.1: Update ui-visual-check.sh with --gate flag
**Files:** `quality/gates/ui-visual-check.sh`
**Action:**
Add a `--gate` flag that makes the script exit 1 on errors (currently it already does this, but formalize the flag for consistency with the other gate scripts). Add a `--files` flag to accept a file list instead of scanning all UI files.

### Step 4.2: Create visual-gate.sh — the composed gate
**Files:** `quality/gates/visual-gate.sh`
**Action:**
The Sprint-Manager calls this single script. It composes all three layers:
```bash
#!/bin/bash
# visual-gate.sh — Composed VISUAL gate (Layer 1 + 2 + 3)
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

# Layer 1: Static analysis (always runs)
"$SCRIPT_DIR/ui-visual-check.sh" --gate --files "$@"
LAYER1_EXIT=$?

# Layer 2: Visual regression (needs dev server)
if [[ -n "${DEV_SERVER_URL:-}" ]]; then
  "$SCRIPT_DIR/visual-regression.sh" --gate --url "$DEV_SERVER_URL" "$@"
  LAYER2_EXIT=$?
else
  echo "SKIP: Layer 2 (no DEV_SERVER_URL)"
  LAYER2_EXIT=0
fi

# Layer 3: Accessibility (needs dev server)
if [[ -n "${DEV_SERVER_URL:-}" ]]; then
  "$SCRIPT_DIR/accessibility-check.sh" --gate --url "$DEV_SERVER_URL" "$@"
  LAYER3_EXIT=$?
else
  echo "SKIP: Layer 3 (no DEV_SERVER_URL)"
  LAYER3_EXIT=0
fi

# Aggregate
if [[ $LAYER1_EXIT -ne 0 || $LAYER2_EXIT -ne 0 || $LAYER3_EXIT -ne 0 ]]; then
  echo "FAIL: VISUAL gate failed"
  exit 1
fi
echo "PASS: VISUAL gate passed"
exit 0
```

### Step 4.3: Update TRIO documentation
**Files:** `workflow/trio/TRIO.md`
**Action:**
Update the Visual Gate section to document the three-layer composition. Update the command syntax to show `visual-gate.sh` as the entry point. Document the `DEV_SERVER_URL` environment variable convention.

### Step 4.4: Update Sprint-Manager role documentation
**Files:** `agents/roles/ROLES.md`
**Action:**
Update the VISUAL gate ownership section to reference `visual-gate.sh` instead of `ui-visual-check.sh --gate`. Document the retry logic with the new three-layer output.

## Phase 5: Scaffold Integration

### Step 5.1: Update scaffold.sh for UI projects
**Files:** `scaffold.sh`
**Action:**
After project generation, if UI files are detected:
1. Add `@playwright/test` and `@axe-core/playwright` to `package.json` devDependencies
2. Copy `templates/common/visual-testing/playwright.config.ts` to project root
3. Copy `templates/common/visual-testing/tests/visual/` to project
4. Symlink `quality/gates/visual-gate.sh` → `scripts/visual-gate.sh`
5. Symlink `quality/gates/ui-visual-check.sh` → `scripts/ui-visual-check.sh`
6. Symlink `quality/gates/visual-regression.sh` → `scripts/visual-regression.sh`
7. Symlink `quality/gates/accessibility-check.sh` → `scripts/accessibility-check.sh`
8. Create `DESIGN.md` from template if it doesn't exist

### Step 5.2: Update typescript-web template documentation
**Files:** `templates/typescript-web/TEMPLATE.md`
**Action:**
Update the template documentation to reflect the new three-layer system. Replace references to `ui-visual-check.sh` alone with `visual-gate.sh`. Add `playwright.config.ts` and `tests/visual/` to the expected file structure.

## Phase 6: Documentation Updates

### Step 6.1: Rewrite quality/ui-visual-check/README.md
**Files:** `quality/ui-visual-check/README.md`
**Action:**
Rewrite to document the three-layer architecture. Keep the DESIGN.md template. Update all command examples. Document the composed gate, individual layer usage, and graceful degradation behavior.

### Step 6.2: Update ARCHITECTURE.md
**Files:** `docs/ARCHITECTURE.md`
**Action:**
Update the VISUAL gate entry in the quality gates table to reference the three-layer system. Add entries for the new gate scripts.

### Step 6.3: Update README.md
**Files:** `README.md`
**Action:**
Update the feature list to mention "3-layer visual QA (static + Playwright regression + axe-core accessibility)". Update the directory structure listing.

## Test Strategy

1. **Layer 1 tests:** Run existing `__tests__/ui-visual-check.test.sh` — must still pass unchanged
2. **Layer 2 tests:** Run `__tests__/visual-regression.test.sh` against a test HTML page served locally
3. **Layer 3 tests:** Run `__tests__/accessibility-check.test.sh` against a page with known violations
4. **Composition test:** Run `visual-gate.sh` with and without `DEV_SERVER_URL` set
5. **Scaffold test:** Run `scaffold.sh` for a typescript-web project, verify Playwright config and symlinks exist
6. **Integration test:** Run the full VISUAL gate sequence in a scaffolded project with a deliberate CSS regression

## Risks

- **Risk:** Playwright screenshots differ across platforms (macOS vs Linux font rendering)
  **Mitigation:** Use Docker image `mcr.microsoft.com/playwright:v1.60.0-noble` in CI for consistent rendering. Set `deviceScaleFactor: 1`, `animations: 'disabled'`, `scale: 'css'`. Platform-specific baselines are auto-named by Playwright. Single-platform CI (Docker) is the recommended approach.

- **Risk:** axe-core produces false positives on styled components or dynamic content
  **Mitigation:** Allow `--severity` filtering; use `.exclude()` for third-party widgets; gate only fails on `critical`/`serious` by default; document common false positive patterns

- **Risk:** AI review layer adds latency and requires API key
  **Mitigation:** AI review is strictly optional; pixel diff is the primary gate; AI review only runs when `--vision-endpoint` is set

- **Risk:** Playwright npm dependency increases scaffolded project size
  **Mitigation:** `@playwright/test` is a devDependency only; Playwright browser binaries are installed on-demand via `npx playwright install`

- **Risk:** Baseline PNGs bloat the git repo over time
  **Mitigation:** Use `--threshold` to reduce noise; `.gitignore` `test-results/` and `playwright-report/` (only track `*-snapshots/`); for >50 baselines consider external storage or Percy upgrade

- **Risk:** Font availability differs between dev machines and CI
  **Mitigation:** Docker image includes standard fonts; for brand fonts, embed them in the project or use `@font-face` with local files; document font requirements in DESIGN.md

## Dependencies

- Playwright (npm: `@playwright/test`) — required for Layers 2/3
- axe-core (npm: `@axe-core/playwright`) — required for Layer 3
- bash, curl, jq — already available in the toolkit
- No SaaS accounts, API keys, or cloud services required for the base flow
