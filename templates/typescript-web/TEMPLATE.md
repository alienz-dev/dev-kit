# TypeScript Web Project Template

## Quality Gates (auto-configured by scaffold.sh)

### Pre-commit hook
```bash
#!/bin/bash
# Runs affected tests on commit (fail-closed, 60s timeout)
# See phases/review/gates/ for gate scripts
```

### Visual Check (UI projects)
Projects with `src/**/public/` or `src/**/components/` get:
- `visual-gate.sh`, `visual-regression.sh`, `accessibility-check.sh`, `ui-visual-check.sh` copied to `scripts/`
- `playwright.config.ts` with visual + a11y project configs
- `tests/visual/` with example visual regression and accessibility tests
- `screenshots/baselines/` for tracking visual baselines
- DESIGN.md template created at project root
- `@playwright/test` and `@axe-core/playwright` added to devDependencies
- `test:visual` and `test:a11y` scripts added to package.json
- Visual gate added to crew-protocol between WIRING and HIDDEN

### DESIGN.md (required for AI review layer)
```markdown
# Design System

## Colors
<!-- Map your CSS custom properties here -->
- Primary: var(--color-primary)
- Background: var(--surface-base)
- Text: var(--text-primary)

## Spacing
- xs: 4px, sm: 8px, md: 16px, lg: 24px, xl: 32px

## Components
- Button: min-height 44px
- Card: padding var(--space-md)
- Input: height 40px
```

### Coder Constraints (auto-injected)
Coders working on UI files are told:
- Use design tokens, not hardcoded values
- No `!important`
- Touch targets ≥ 44px
- Handle overflow with `text-overflow: ellipsis`
- z-index must use defined layers

## File Structure
```
project/
├── DESIGN.md                    ← Visual check + AI review context
├── playwright.config.ts         ← Visual + a11y test config
├── scripts/
│   ├── entry-reachability.sh    ← Wiring gate
│   ├── visual-gate.sh           ← Composed VISUAL gate (3 layers, symlink)
│   ├── visual-regression.sh     ← Layer 2: Playwright regression (copy)
│   ├── accessibility-check.sh   ← Layer 3: axe-core a11y (copy)
│   └── ui-visual-check.sh      ← Layer 1: static lint (copy)
├── screenshots/
│   └── baselines/               ← Visual regression baselines (commit these)
├── src/
│   └── dashboard/public/
│       ├── css/tokens.css       ← Design tokens
│       └── js/app.js            ← Entry point
└── tests/
    ├── visual/
    │   ├── homepage.visual.spec.ts   ← Visual regression tests
    │   └── homepage.a11y.spec.ts     ← Accessibility tests
    ├── dashboard/               ← Visible tests
    └── regression-prevention/   ← Contract + invariant tests
        ├── phase2/
        │   ├── css-structural-contract.test.ts
        │   ├── components-contract.test.ts
        │   └── event-bus-contract.test.ts
        └── phase3/
            └── frontend-test-map.test.ts
```
