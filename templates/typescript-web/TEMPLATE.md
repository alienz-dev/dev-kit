# TypeScript Web Project Template

## Quality Gates (auto-configured by scaffold.sh)

### Pre-commit hook
```bash
#!/bin/bash
# Runs affected tests on commit (fail-closed, 60s timeout)
# See quality/pre-commit/pre-commit-test-gate.sh
```

### Visual Check (UI projects)
Projects with `src/**/public/` or `src/**/components/` get:
- `ui-visual-check.sh` symlinked to `scripts/`
- DESIGN.md template created at project root
- Visual gate added to crew-protocol between WIRING and HIDDEN

### DESIGN.md (required for VLM layer)
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
├── DESIGN.md                    ← Visual check anchors to this
├── scripts/
│   ├── entry-reachability.sh    ← Wiring gate
│   └── ui-visual-check.sh      ← Visual gate (symlink)
├── src/
│   └── dashboard/public/
│       ├── css/tokens.css       ← Design tokens
│       └── js/app.js            ← Entry point
└── tests/
    ├── dashboard/               ← Visible tests
    └── regression-prevention/   ← Contract + invariant tests
        ├── phase2/
        │   ├── css-structural-contract.test.ts
        │   ├── components-contract.test.ts
        │   └── event-bus-contract.test.ts
        └── phase3/
            └── frontend-test-map.test.ts
```
