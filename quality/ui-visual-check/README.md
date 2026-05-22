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
  --auto-fix \
  --threshold 8

# Options:
#   --files       Source files to lint (Layer 1)
#   --url         Dev server URL for screenshot (Layer 2+3)
#   --design      Design system reference for VLM anchoring
#   --auto-fix    Auto-fix high-confidence findings (≥threshold)
#   --threshold   Confidence threshold for auto-fix (1-10, default 8)
```

## Integration with TRIO

In coder briefings that touch UI:
```yaml
visual-check: true
dev-server-url: http://localhost:3000
design-doc: docs/DESIGN.md
```

After implementation + tests pass, coder runs visual check automatically.

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
