# UI Visual Quality Check

## Problem

Text-only agents can't see UI regressions. Broken layouts, misaligned elements, empty states, and accessibility issues are invisible without visual verification.

## Three-Layer Approach

### Layer 1: Static Analysis (<5s, ~0% false positives)

Regex-based lint on source files:
- Hardcoded colors (should use design tokens)
- `!important` abuse
- Missing alt text on images
- ARIA violations
- z-index wars (values > 100 without justification)
- Design token drift (using raw values instead of variables)

### Layer 2: VLM Screenshot Analysis (15-30s, ~20-30% false positives)

1. Launch headless browser (CDP connection)
2. Navigate to target URL
3. Take screenshot
4. Send to vision model with DESIGN.md as reference
5. Model identifies visual issues anchored to design system

**Requires:** Running dev server, CDP-capable browser, vision model access

### Layer 3: DOM Heuristics (<15s, ~5% false positives)

CDP-based DOM inspection:
- Empty containers (rendered but no visible content)
- Touch targets < 44px
- Horizontal overflow (content wider than viewport)
- Missing focus styles on interactive elements
- Low contrast ratios
- Orphaned absolute/fixed elements

## Usage

```bash
# Static only (fast, no server needed)
ui-visual-check.sh --files src/components/*.tsx

# Full check (requires running dev server)
ui-visual-check.sh \
  --files src/App.tsx \
  --url http://localhost:3000 \
  --design docs/DESIGN.md \
  --threshold 8

# Gate mode (sprint-manager integration)
ui-visual-check.sh --gate \
  --baseline screenshots/baselines \
  --url http://localhost:3000 \
  --files src/components/Dashboard.tsx \
  --design DESIGN.md
```

## Sprint-Manager Gate Integration

Sprint-manager runs visual QA after GREEN for waves with UI files:

### UI File Detection

Extensions that trigger visual gate: `.tsx`, `.jsx`, `.vue`, `.svelte`, `.css`, `.scss`, `.html`, `.ejs`, `.hbs`

### Gate Command

```bash
ui-visual-check.sh --gate \
  --baseline <project>/screenshots/baselines \
  --url <dev-server-url> \
  --files <changed-ui-files> \
  --design DESIGN.md
```

### Gate Outcomes

| Result | Action |
|--------|--------|
| Pass (exit 0) | `--save-baseline`, proceed to next gate |
| Fail (exit 1) | Re-dispatch coder with findings (max 2 visual retries) |
| No dev server | `--files` only (Layer 1 static lint) |

### Retry Logic

- Max 2 visual retries per wave
- On fail: sprint-manager re-dispatches coder with `## Visual Context` section containing findings
- After 2 failures: pipeline status → failed

### Graceful Degradation

When no dev server is available (backend-only project, CI environment):
- Only Layer 1 (static analysis) runs
- Layers 2 and 3 are skipped
- Gate still enforces token usage and static lint rules

### Coder Briefing Integration

Sprint-manager adds to coder briefings that touch UI:
```yaml
visual-check: true
dev-server-url: http://localhost:3000
design-doc: docs/DESIGN.md
```

On visual retry, adds `## Visual Context` section with specific findings to fix.

## TRIO Integration

The visual check runs as a named gate between GREEN and HIDDEN:

```
GREEN → WIRING → VISUAL → HIDDEN → ACTIVATION → REVIEW
```

**Skip condition:** Non-UI changes (backend-only, CLI, library) skip this gate entirely.

## DESIGN.md Template

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
