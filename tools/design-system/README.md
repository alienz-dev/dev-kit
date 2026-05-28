# Design System Tools

Autonomous visual feedback loop for the ui-designer agent. Multi-phase: audit → explore → critique → decide → specify → verify.

## Tools

### design-sandbox.sh — Screenshot Capture

Playwright-based screenshot capture for design iteration.

```bash
design-sandbox.sh --url http://localhost:3000 \
  --viewport 1440x900 \
  --output /tmp/screenshot-001.png
```

### design-grade.sh — LLM Scoring

Sends screenshot + DESIGN.md to vision model for scoring.

```bash
design-grade.sh --screenshot /tmp/screenshot-001.png \
  --design docs/DESIGN.md \
  --output /tmp/grade-001.json
```

**Output:**
```json
{
  "design_quality": 8.5,
  "originality": 9.0,
  "craft": 8.0,
  "functionality": 7.5,
  "token_fidelity": 9.0,
  "total": 8.6,
  "findings": ["..."]
}
```

### design-iterate.sh — Autonomous Loop

Generate → screenshot → grade loop with mandatory token enforcement.

```bash
design-iterate.sh --design docs/DESIGN.md \
  --url http://localhost:3000 \
  --max-iterations 5 \
  --accept-threshold 8.0
```

## Scoring Rubric

```
total = DQ × 0.4 + O × 0.4 + C × 0.15 + F × 0.05
```

| Dimension | Weight | What It Measures |
|-----------|--------|-----------------|
| Design Quality (DQ) | 0.40 | Layout, hierarchy, spacing, alignment |
| Originality (O) | 0.40 | Distinctiveness, avoids generic patterns |
| Craft (C) | 0.15 | Polish, attention to detail, consistency |
| Functionality (F) | 0.05 | Usability, interaction clarity |

### Thresholds

| Gate | Condition |
|------|-----------|
| Accept (ship) | total ≥ 8.0 AND originality ≥ 9 |
| Pass (proceed) | total ≥ 7.0, originality ≥ 7, token_fidelity ≥ 8 |
| Fail (iterate) | Below pass thresholds |

## Two Design Registers

### Brand Surface (Explainer)
- DESIGN.md at: `tools/explainer/DESIGN.md`
- Focus: marketing, personality, visual identity
- Higher originality bar (≥9 required)

### Product/Dashboard
- DESIGN.md at: `docs/DESIGN.md` or project-specific
- Focus: usability, information density, consistency
- Lower originality bar, higher functionality bar

## DESIGN.md Format (Google Stitch)

YAML front matter + Markdown prose:

```markdown
---
name: "Project Name"
version: "1.0"
tokens:
  colors:
    primary: "#2563eb"
    background: "#ffffff"
    text: "#1f2937"
  spacing: [4, 8, 16, 24, 32]
  typography:
    body: "16px/1.5 Inter"
    heading: "24px/1.2 Inter Bold"
---

# Design System

## Visual Language
<Prose describing the design intent, personality, constraints>

## Components
<Component specifications with token references>
```

## Design Memory

Persistent state at `.interface-design/system.md`:
- Previous iterations and scores
- Rejected approaches (with reasons)
- Token definitions that passed validation
- Brand constraints and anti-patterns

## Anti-Patterns

- ❌ Generic fonts for display text (use brand-specific)
- ❌ Purple gradients (overused, low originality score)
- ❌ CSS fallbacks that override tokens
- ❌ Hardcoded colors instead of design tokens
- ❌ Iterating without screenshot verification
