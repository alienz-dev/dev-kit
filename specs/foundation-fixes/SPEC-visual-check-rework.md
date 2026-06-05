---
id: SPEC-012
title: "UI Visual Check — Playwright-based 3-Layer Architecture"
status: draft
version: 1
created: 2026-06-05
linked_issues: [ENH-0012]
test_files: []
---

## S1 Overview

This spec replaces the dormant `tools/ui-visual-check` submodule and unifies the visual quality system into three composable layers that live in-repo under `quality/gates/`. The goal is to make the VISUAL gate in the pipeline actually catch UI regressions — something the current Layer 1 static lint cannot do.

The architecture uses Playwright as the single browser runtime, with shell script wrappers consistent with every other gate in the toolkit.

## S2 Behavior

**AC-1: Layer 1 Static Analysis (Ubiquitous)**
THE system SHALL run `ui-visual-check.sh` on changed UI files to detect hardcoded colors, missing alt text, hardcoded breakpoints, and design token drift. This layer SHALL complete in under 5 seconds with zero false positives on token-defined values.

**AC-2: Layer 2 Visual Regression (Event-driven)**
WHEN a dev server URL is provided THE system SHALL run `visual-regression.sh` to capture Playwright screenshots and compare against git-tracked baselines. THE system SHALL produce a pixel diff image when differences exceed the configured threshold. THE system SHALL exit 0 when no regressions are found and exit 1 when regressions exceed threshold.

**AC-3: Layer 2 AI Review (Event-driven)**
WHEN visual diffs are detected AND a vision model endpoint is configured THE system SHALL send baseline + actual + diff images to the vision model and receive a structured JSON assessment. THE system SHALL classify changes as `intentional`, `regression`, or `ambiguous`.

**AC-4: Layer 3 Accessibility (Event-driven)**
WHEN a dev server URL is provided THE system SHALL run `accessibility-check.sh` using `@axe-core/playwright` to detect WCAG violations. THE system SHALL report violations with element selectors, rule IDs, and severity. THE system SHALL exit 1 when `critical` or `serious` violations are found.

**AC-5: Graceful Degradation (State-driven)**
WHEN no dev server is available THE system SHALL run Layer 1 only and skip Layers 2 and 3 without error. THE system SHALL log that Layers 2/3 were skipped.

**AC-6: VISUAL Gate Composition (Event-driven)**
WHEN the Sprint-Manager triggers the VISUAL gate THE system SHALL run Layer 1, then Layer 2 (if dev server available), then Layer 3 (if dev server available). THE system SHALL aggregate results and exit 1 if any layer reports errors. THE system SHALL allow up to 2 retries per wave.

**AC-7: Skip Condition (State-driven)**
WHEN the changeset contains no UI files (`.tsx`, `.jsx`, `.vue`, `.svelte`, `.css`, `.scss`, `.html`, `.ejs`, `.hbs`) THE system SHALL skip the VISUAL gate entirely and report "no UI files changed".

**AC-8: Baseline Management (Event-driven)**
WHEN `visual-regression.sh --update-baselines` is run THE system SHALL update the stored screenshot baselines with the current rendering. THE system SHALL store baselines as PNG files under `screenshots/baselines/` tracked in git.

**AC-9: Template Integration (Ubiquitous)**
WHEN `scaffold.sh` generates a project with UI files THE system SHALL install `@playwright/test` and `@axe-core/playwright` as dev dependencies, create a `playwright.config.ts` with visual test settings, symlink the three gate scripts to `scripts/`, and create a DESIGN.md template.

## S3 Change Specification

### Current Behavior

- `tools/ui-visual-check/` is an empty submodule directory (never initialized)
- `quality/gates/ui-visual-check.sh` implements Layer 1 only (hardcoded colors, missing alt, breakpoints, token drift)
- `quality/gates/__tests__/ui-visual-check.test.sh` has 3 test cases for Layer 1
- `tools/design-system/` has a README specifying `design-sandbox.sh`, `design-grade.sh`, `design-iterate.sh` — none implemented
- `quality/ui-visual-check/README.md` documents a 3-layer spec that doesn't exist
- `workflow/pipeline/transitions.json` includes `visual` in `gates.sprint.sequence`
- `workflow/trio/TRIO.md` documents the VISUAL gate between WIRING and HIDDEN
- `agents/roles/ROLES.md` assigns VISUAL gate to Sprint-Manager
- `templates/typescript-web/TEMPLATE.md` documents symlink and DESIGN.md generation (not wired in scaffold.sh)

### Target Behavior (Delta)

| Change | What |
|---|---|
| New file | `quality/gates/visual-regression.sh` — Layer 2 shell wrapper |
| New file | `quality/gates/accessibility-check.sh` — Layer 3 shell wrapper |
| New file | `quality/gates/__tests__/visual-regression.test.sh` — Layer 2 tests |
| New file | `quality/gates/__tests__/accessibility-check.test.sh` — Layer 3 tests |
| New dir | `templates/common/visual-testing/` — Playwright config + example test |
| Modify | `quality/ui-visual-check/README.md` — rewrite to reflect new architecture |
| Modify | `quality/gates/ui-visual-check.sh` — add `--gate` flag for composition |
| Modify | `scaffold.sh` — wire Playwright install + gate symlinks for UI projects |
| Modify | `.gitmodules` — remove `ui-visual-check` submodule entry |
| Delete | `tools/ui-visual-check/` — remove empty submodule directory |
| Delete | `tools/design-system/` — absorbed into Layer 2 |

### Invariants (Must NOT Change)

- `quality/gates/ui-visual-check.sh` existing checks (hardcoded colors, missing alt, breakpoints, token drift) SHALL remain unchanged
- `workflow/pipeline/transitions.json` gate sequence SHALL remain unchanged (VISUAL between WIRING and HIDDEN)
- `workflow/trio/TRIO.md` gate documentation SHALL be updated but the gate position in the sequence SHALL not change
- `agents/roles/ROLES.md` Sprint-Manager ownership of VISUAL gate SHALL remain
- Exit code conventions: 0 = pass, 1 = fail, consistent with all other gates

### Scope Boundary

**In scope:**
- Shell script wrappers for Playwright visual regression and axe-core accessibility
- Playwright config template for scaffolded projects
- Baseline management (update, diff, store as PNGs in git)
- Optional AI review integration (vision model via curl)
- DESIGN.md integration as reference for AI review
- Removing the dormant submodule and design-system/ directory

**Out of scope:**
- Custom pixel comparison engine (use Playwright's built-in)
- SaaS integrations (Percy, Chromatic) — documented as optional upgrades, not implemented
- Component-level testing via Storybook — too heavy for portable scaffold
- The UI-Designer agent role itself (separate concern, lives in `agents/roles/`)
- Modifying the pipeline FSM or TRIO protocol structure

### Non-Goals

- Replacing Playwright with a lighter tool — Playwright is the standard
- Building a visual review UI — the AI review layer outputs JSON, not a dashboard
- Supporting non-JS projects — the toolkit defaults to TypeScript; other languages adapt the shell wrappers

## S4 Error Handling

| Scenario | Expected | Rationale |
|---|---|---|
| No dev server running | Layer 1 only, Layers 2/3 skipped with warning | Graceful degradation — static lint still runs |
| Playwright not installed | `visual-regression.sh` exits 2 with "Playwright not installed" message | Clear error, not a silent skip |
| axe-core not installed | `accessibility-check.sh` exits 2 with "axe-core not installed" message | Clear error, not a silent skip |
| Baseline directory missing | `visual-regression.sh` creates it and captures initial baselines | First run is always a baseline capture |
| Screenshot pixel diff exceeds threshold | Exit 1 with diff image path and percentage | Actionable feedback for coder |
| axe-core finds critical violations | Exit 1 with violation list (element, rule, severity) | Actionable feedback for coder |
| Vision model API unavailable | AI review skipped, pixel diff result used directly | AI review is optional enhancement |
| Vision model returns unparseable response | Log warning, fall back to pixel diff result | Don't fail the gate on AI issues |
| No UI files in changeset | VISUAL gate skipped entirely | Existing behavior, preserve it |
| DESIGN.md missing | AI review runs without design context, logs warning | Don't block on missing optional file |

## S5 Constraints

- **Performance:** Layer 1 < 5s, Layer 2 < 30s (10 screenshots), Layer 3 < 15s. Total VISUAL gate < 60s.
- **Dependencies:** `@playwright/test` and `@axe-core/playwright` are the only required npm packages. Shell wrappers use only bash, curl, and jq.
- **Compatibility:** macOS and Linux. Windows via WSL. Playwright handles cross-platform browser binaries.
- **Storage:** Baseline PNGs tracked in git. Projects with >50 baselines should use `--threshold` to reduce noise.
- **Security:** Vision model API key passed via environment variable, never stored in config files.
- **Portability:** All gate scripts are self-contained bash with `set -euo pipefail`. No Node.js required for Layer 1.

## S6 Clarifications

**Q: Why not just initialize the submodule?**
A: The submodule adds external repo access requirements, version pinning, and update complexity. Gate scripts are shell scripts — they belong in-repo alongside `activation-gate.sh`, `entry-reachability.sh`, and every other gate.

**Q: Why Playwright over BackstopJS?**
A: Playwright's `toHaveScreenshot()` is built-in, zero extra packages, and is the 2025-2026 standard. BackstopJS is an extra dependency that does the same thing with less maintenance.

**Q: What happens to the design-system/ scoring rubric?**
A: The rubric (DQ × 0.4 + O × 0.4 + C × 0.15 + F × 0.05) becomes the prompt template for the AI review layer. The scoring concept is preserved; the separate tool directory is not.

**Q: Can projects opt out of Playwright?**
A: Yes. Projects without `@playwright/test` installed get Layer 1 only. Layers 2/3 skip gracefully. The gate always runs — it just adapts to what's available.

**Q: How do baselines work across developers?**
A: Baselines are PNGs tracked in git. `--update-baselines` regenerates them. CI uses the committed baselines. If a developer's platform renders differently, Playwright's `maxDiffPixelRatio` tolerance handles minor anti-aliasing differences.

## S7 Visual Acceptance Criteria

N/A — this is tooling, not UI. The visual acceptance criteria apply to the projects that USE this tooling, not to the tooling itself.
