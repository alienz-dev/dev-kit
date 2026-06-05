# UI Visual Quality Check

## Problem

Text-only agents can't see UI regressions. Broken layouts, misaligned elements, empty states, and accessibility issues are invisible without visual verification.

## Quick Start

### For scaffolded projects (already set up)

```bash
# 1. Start your dev server (any port)
npm run dev -- --port 5173

# 2. Run the visual gate (use YOUR dev server URL)
scripts/visual-gate.sh --gate --url http://localhost:5173

# 3. First run? Capture baselines
scripts/visual-regression.sh --url http://localhost:5173 --update-baselines
git add tests/visual/*.spec.ts-snapshots/
git commit -m "chore: add visual baselines"
```

> **No hardcoded ports.** Every URL is passed via `--url` or the `DEV_SERVER_URL` env var. The Playwright config reads `DEV_SERVER_URL` automatically — set it once and all commands use it:
> ```bash
> export DEV_SERVER_URL=http://localhost:5173
> scripts/visual-gate.sh --gate   # uses $DEV_SERVER_URL
> ```

### For existing projects (manual setup)

```bash
# 1. Install dependencies
npm install -D @playwright/test @axe-core/playwright
npx playwright install chromium

# 2. Copy gate scripts from dev-kit
cp ~/dev-kit/quality/gates/{visual-gate,visual-regression,accessibility-check,ui-visual-check}.sh scripts/
chmod +x scripts/*.sh

# 3. Copy Playwright config
cp ~/dev-kit/templates/common/visual-testing/playwright.config.ts .

# 4. Copy example tests
mkdir -p tests/visual
cp ~/dev-kit/templates/common/visual-testing/tests/visual/*.spec.ts tests/visual/

# 5. Create DESIGN.md
cp ~/dev-kit/templates/common/visual-testing/DESIGN.md docs/DESIGN.md

# 6. Run
scripts/visual-gate.sh --gate --url http://localhost:3000
```

## Three-Layer Architecture

The VISUAL gate composes three independent layers. Layer 1 always runs; Layers 2 and 3 need a dev server.

```
┌─────────────────────────────────────────────────┐
│  visual-gate.sh                                 │
│                                                 │
│  Layer 1: Static Analysis    (<5s, no deps)     │
│  ├── Hardcoded colors              [ERROR]      │
│  ├── Missing alt text              [ERROR]      │
│  ├── !important abuse              [ERROR]      │
│  ├── z-index wars (>100)           [ERROR]      │
│  ├── Missing ARIA                  [ERROR]      │
│  ├── Hardcoded breakpoints         [WARN]       │
│  └── Design token drift            [WARN]       │
│                                                 │
│  Layer 2: Visual Regression  (15-30s, Playwright)│
│  ├── Screenshot pixel diff                      │
│  ├── Baseline comparison                        │
│  └── Optional AI review                         │
│                                                 │
│  Layer 3: Accessibility      (<15s, axe-core)   │
│  ├── WCAG 2.1 AA violations                     │
│  ├── Color contrast                             │
│  ├── Missing labels/ARIA                        │
│  └── Keyboard navigation                        │
└─────────────────────────────────────────────────┘
```

## Usage Guide

### Running the composed gate

```bash
# Full 3-layer check (use your dev server URL)
visual-gate.sh --gate --url http://localhost:5173

# With file filtering (only check changed files)
visual-gate.sh --gate --url http://localhost:5173 \
  --files $'src/components/Header.tsx\nsrc/styles/main.css'

# With DESIGN.md for AI review context
visual-gate.sh --gate --url http://localhost:5173 --design docs/DESIGN.md

# Layer 1 only (no dev server needed)
visual-gate.sh --files $'src/components/Header.tsx'

# Layer 1 strict mode (warnings become errors)
ui-visual-check.sh --strict

# Or set DEV_SERVER_URL once and omit --url
export DEV_SERVER_URL=http://localhost:5173
visual-gate.sh --gate
```

### Running individual layers

```bash
# Layer 1: Static analysis (always works, no deps)
ui-visual-check.sh
ui-visual-check.sh --files $'src/styles/main.css'

# Layer 2: Visual regression (needs dev server)
visual-regression.sh --url http://localhost:5173

# Layer 2: Capture baselines (first time, or after intentional changes)
visual-regression.sh --url http://localhost:5173 --update-baselines

# Layer 3: Accessibility (needs dev server)
accessibility-check.sh --url http://localhost:5173
accessibility-check.sh --url http://localhost:5173 --severity critical
accessibility-check.sh --url http://localhost:5173 --output reports/a11y.json
```

### Updating baselines

When you intentionally change the UI:

```bash
# 1. Update baselines
scripts/visual-regression.sh --url http://localhost:5173 --update-baselines

# 2. Review the changes
git diff tests/visual/*.spec.ts-snapshots/

# 3. Commit
git add tests/visual/*.spec.ts-snapshots/
git commit -m "chore: update visual baselines for [what changed]"
```

### Viewing diff reports

When visual regression fails:

```bash
# Open the HTML report
npx playwright show-report playwright-report/

# Or check diff images directly
ls test-results/*-diff.png
```

## Gate Behavior

### Exit codes

| Code | Meaning | When |
|------|---------|------|
| 0 | Pass | All checks passed, or warnings only |
| 1 | Fail | Violations found (regression, a11y, hardcoded values) |
| 2 | Error | Bad arguments, missing dependencies |

### Graceful degradation

| Scenario | What happens |
|----------|-------------|
| No dev server URL | Layer 1 only, Layers 2+3 skipped with message |
| Playwright not installed | Layers 2+3 exit 2 with install instructions |
| axe-core not installed | Layer 3 exits 2 with install instructions |
| No DESIGN.md | Layer 1 token check skipped with warning |
| No UI files in project | All checks pass (nothing to check) |
| First run (no baselines) | Layer 2 captures baselines, exits 0 |

### Sprint-Manager integration

The VISUAL gate runs after GREEN in the pipeline:

```
GREEN → WIRING → VISUAL → HIDDEN → ACTIVATION → REVIEW
```

- **Skip condition:** Non-UI changesets skip the gate entirely
- **Retry logic:** Max 2 visual retries per wave
- **On fail:** Sprint-manager re-dispatches coder with findings
- **After 2 failures:** Pipeline status → failed

## DESIGN.md

The DESIGN.md file serves two purposes:
1. Layer 1 checks that source files use design tokens, not hardcoded values
2. AI review layer uses it as context when classifying visual changes

Create at `docs/DESIGN.md` (or project root):

```markdown
# Design System

## Colors
- Primary: var(--color-primary) = #2563eb
- Background: var(--color-bg) = #ffffff
- Text: var(--color-text) = #1f2937

## Spacing
- xs: 4px, sm: 8px, md: 16px, lg: 24px, xl: 32px

## Typography
- Body: 16px/1.5 Inter
- Heading: 24px/1.2 Inter Bold

## Components
- Button: min-height 44px, border-radius 6px
- Card: padding 16px, border 1px solid var(--color-border)
- Input: height 40px, padding 8px 12px

## Layout
- Max content width: 1200px
- Sidebar: 256px fixed
- Grid gap: 16px
```

## AI Review (Optional)

The visual regression gate can send diff images to a vision model for classification:

```bash
visual-regression.sh --url http://localhost:5173 \
  --vision-endpoint https://api.openai.com/v1/chat/completions \
  --design docs/DESIGN.md
```

The AI classifies each diff as:
- `intentional` — redesign, expected change
- `regression` — broken layout, unintended change
- `ambiguous` — needs human review

Requires: `OPENAI_API_KEY` environment variable (or compatible endpoint).

## Environment Variables

All configuration is via environment variables or flags. Nothing is hardcoded.

| Variable | Used By | Purpose | Default |
|----------|---------|---------|---------|
| `DEV_SERVER_URL` | All scripts, Playwright config | Dev server URL | `http://localhost:3000` (if not set) |
| `DEV_COMMAND` | Playwright config | Command to start dev server | `npm run dev` |
| `VISUAL_THRESHOLD` | Playwright config | Max diff pixel ratio (0-1) | `0.01` |
| `VISUAL_PIXEL_THRESHOLD` | Playwright config | Per-pixel color distance (0-1) | `0.2` |
| `BASELINE_DIR` | Playwright config | Baseline screenshot directory | `undefined` (uses default) |
| `CI` | Playwright config | Disables `reuseExistingServer` | `undefined` |

Set `DEV_SERVER_URL` once and omit `--url` from all commands:

```bash
export DEV_SERVER_URL=http://localhost:5173
visual-gate.sh --gate          # uses $DEV_SERVER_URL
visual-regression.sh --gate    # uses $DEV_SERVER_URL
accessibility-check.sh --gate  # uses $DEV_SERVER_URL
```

## Dependencies

| Layer | What's needed | Install |
|-------|--------------|---------|
| 1 (Static) | bash, grep, find | Built-in |
| 2 (Regression) | Node.js, Playwright | `npm install -D @playwright/test && npx playwright install chromium` |
| 3 (Accessibility) | Node.js, Playwright, axe-core | `npm install -D @axe-core/playwright` |
| AI review | curl, jq, vision API key | `brew install jq` (or equivalent) |

## CI Integration

### GitHub Actions

```yaml
- name: Visual Gate
  run: |
    scripts/visual-gate.sh --gate \
      --files "$CHANGED_FILES" \
      --design docs/DESIGN.md \
      --severity serious
  env:
    # Set once — all scripts use this
    DEV_SERVER_URL: http://localhost:${{ vars.DEV_PORT }}
```

### Docker (consistent rendering)

```yaml
container:
  image: mcr.microsoft.com/playwright:v1.60.0-noble
```

### CI Gotchas

- **Platform differences:** Docker ensures consistent font rendering across environments
- **Font availability:** Brand fonts must be embedded or available in the Docker image
- **Animations:** `animations: 'disabled'` in Playwright config freezes CSS transitions
- **Baselines:** Commit `*-snapshots/` directories; ignore `test-results/` and `playwright-report/`

## File Reference

```
quality/gates/
├── visual-gate.sh              ← Composed gate (entry point)
├── visual-regression.sh        ← Layer 2
├── accessibility-check.sh      ← Layer 3
├── ui-visual-check.sh          ← Layer 1
└── __tests__/
    ├── visual-regression.test.sh
    ├── accessibility-check.test.sh
    └── ui-visual-check.test.sh

templates/common/visual-testing/
├── playwright.config.ts        ← Playwright config template
└── tests/visual/
    ├── homepage.visual.spec.ts ← Visual regression test template
    └── homepage.a11y.spec.ts   ← Accessibility test template
```

## Troubleshooting

| Problem | Cause | Fix |
|---------|-------|-----|
| `Playwright not installed` | Missing dependency | `npm install -D @playwright/test && npx playwright install chromium` |
| `MODULE_NOT_FOUND: @axe-core/playwright` | Missing dependency | `npm install -D @axe-core/playwright` |
| `EADDRINUSE` in CI | Dev server already running | Set `DEV_SERVER_URL` env var so Playwright reuses it |
| Baselines differ across platforms | Font rendering differences | Use Docker for CI, or regenerate baselines in CI |
| `DESIGN.md not found` | Wrong location | Place at `docs/DESIGN.md` or project root |
| Threshold ignored | Using `--threshold` with wrong value | Must be 0-1, e.g. `--threshold 0.01` |
| All baselines regenerated | Playwright version changed | Pin Playwright version, regenerate after updates |
