---
id: ENH-0012
title: "Rework UI Visual Check — Playwright-based 3-layer architecture"
status: open
priority: high
component: tool
requested_by: ding
date: 2026-06-05
labels: [enhancement, visual-qa, playwright, gates]
---

## Problem Statement

The UI visual quality system is split across two incomplete implementations:

1. **`tools/ui-visual-check/` submodule** — dormant (never initialized, empty directory). Points to `alienz-dev/ui-visual-check` on GitHub. The three-layer spec (static analysis, VLM screenshots, DOM heuristics) is documented in `quality/ui-visual-check/README.md` but only Layer 1 exists.

2. **`quality/gates/ui-visual-check.sh`** — functional Layer 1 only (189 lines of regex linting). Checks hardcoded colors, missing alt text, hardcoded breakpoints, and design token drift. Works well but is the least valuable layer.

3. **`tools/design-system/`** — README-only directory. Specifies `design-sandbox.sh`, `design-grade.sh`, `design-iterate.sh` for the UI-Designer agent. None implemented. Solves the same problem (visual quality) from a different angle, creating conceptual duplication.

The result: the pipeline has a VISUAL gate wired into `transitions.json` and TRIO protocol, but the actual tooling behind it is either empty (submodule), trivial (static lint), or unimplemented (design-system). The high-value layers — screenshot comparison and accessibility checking — don't exist.

## Proposed Solution

Replace the submodule and consolidate into a single in-repo 3-layer architecture:

**Layer 1: Static Analysis** (exists, keep as-is)
- `quality/gates/ui-visual-check.sh` — regex lint, no browser needed, <5s

**Layer 2: Visual Regression** (new)
- `quality/gates/visual-regression.sh` — shell wrapper around Playwright's `toHaveScreenshot()`
- Pixel diff against git-tracked baselines
- Optional AI review: send diff images to vision model via curl, get structured assessment
- Replaces both the submodule's Layer 2 and `design-sandbox.sh`/`design-grade.sh`

**Layer 3: Accessibility** (new)
- `quality/gates/accessibility-check.sh` — shell wrapper around `@axe-core/playwright`
- WCAG violation detection in the same browser pass as screenshots
- Replaces the submodule's scattered DOM heuristics with a proper tool (~57% of WCAG issues auto-detected)

**Template integration:**
- `templates/common/visual-testing/` — Playwright config + example test for scaffolded projects
- `scaffold.sh` wires up Playwright + symlinks gates for UI projects

**Submodule cleanup:**
- Remove `tools/ui-visual-check` from `.gitmodules`
- Remove `tools/design-system/` (concepts absorbed into Layer 2)
- Rewrite `quality/ui-visual-check/README.md` to reflect new architecture

## Alternatives Considered

| Alternative | Why rejected |
|---|---|
| **Initialize the submodule** | Adds external repo dependency, access requirements, version pinning complexity. Shell scripts belong in-repo with other gates. |
| **BackstopJS** | Extra npm dependency when Playwright's built-in `toHaveScreenshot()` does the same thing. Playwright is already the recommended test runner. |
| **Percy/Chromatic SaaS** | Requires account signup, API keys, cloud storage. Wrong default for a portable toolkit. Can be offered as an opt-in upgrade. |
| **Custom pixel comparison engine** | Reinventing what Playwright/pixelmatch already does well. |
| **Storybook for component testing** | Too heavy for a portable scaffold. Page-level testing is the pragmatic default. |
| **Keep design-system/ separate** | Two parallel systems for visual quality creates confusion. The design iteration loop (screenshot → grade → iterate) is just Layer 2 with a scoring rubric. |

## Research Context

- Playwright `toHaveScreenshot()` is the 2025-2026 standard for visual regression in JS/TS projects — zero external deps, built into `@playwright/test`, snapshots as PNGs in git
- `@axe-core/playwright` is the standard for automated accessibility testing — catches ~57% of WCAG issues
- Lost Pixel (was an OSS alternative) is discontinued — team acquired by Figma
- AI-assisted visual review (sending screenshots to Claude/GPT-4V) is emerging as a post-processing layer on top of pixel comparison, not a replacement
- The `design-system/` scoring rubric (DQ × 0.4 + O × 0.4 + C × 0.15 + F × 0.05) can be preserved as the AI review prompt template

## Impact

- **Who benefits:** Sprint-Manager (clearer gate), Coder (actionable visual feedback), UI-Designer agent (working tools)
- **Scope:** 3 new shell scripts, 1 template directory, updates to scaffold.sh, .gitmodules, README, and quality docs
- **Effort:** Medium — 2-3 days for Phase 1 (Playwright regression), 1 day for Phase 2 (AI review), 1 day for Phase 3 (accessibility)
- **Dependencies:** Playwright must be installed in scaffolded projects (already the recommended test runner)
