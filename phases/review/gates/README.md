# Gate Scripts

This directory contains gate validation scripts for the SDD pipeline.

## Script Status

| Script | Status | Used By | Purpose |
|--------|--------|---------|---------|
| `review-precheck.sh` | **Active** | Reviewer-Lite agent | Pre-check for TODOs, console.logs, type errors before review |
| `activation-gate.sh` | **Reference** | gate.sh (proof file) | Verify feature is reachable from entry point |
| `entry-reachability.sh` | **Reference** | gate.sh (proof file) | Check for orphaned modules and dead imports |
| `visual-gate.sh` | **Reference** | gate.sh (conditional) | 3-layer UI check: static + Playwright + axe-core |
| `ui-visual-check.sh` | **Reference** | Visual gate helper | Playwright screenshot comparison |
| `visual-regression.sh` | **Reference** | Visual gate helper | Visual regression detection |
| `accessibility-check.sh` | **Reference** | Visual gate helper | axe-core accessibility audit |
| `wave-smoke.sh` | **Reference** | Wave dispatch | Quick smoke test after each wave |

## How Gates Work

The SDD pipeline uses a **proof-file model**:

1. **transitions.json** defines the gate sequence: `green → wiring → visual → hidden → alignment → activation`
2. **gate.sh** checks for `.pipeline/<gate>.passed` proof files before allowing stage transitions
3. **Workflows** run the actual checks and write proof files via `gate.sh proof <gate>`

### Active vs Reference Scripts

- **Active scripts** are called directly by agents or workflows (e.g., `review-precheck.sh`)
- **Reference scripts** are standalone implementations that can be called manually or integrated later
- **Gate proofs** are written by workflows after inline checks pass — the scripts here are optional helpers

### Visual Gate (Conditional)

The visual gate is **conditional** — it's only required when UI files are changed:
- Workflows set `.pipeline/visual.required` when UI changes are detected
- gate.sh checks for `visual.passed` only if `visual.required` exists
- This allows non-UI features to skip visual checks

## Adding a New Gate

1. Add the gate name to `transitions.json` under the appropriate stage's `sequence`
2. Add the check description to the `checks` object
3. Either:
   - Create a script here and have the workflow call it, OR
   - Have the workflow run the check inline and write proof via `gate.sh proof <gate>`
4. Update gate.sh if the gate has special requirements (e.g., conditional gates)
